// SPDX-License-Identifier: AGPL-3.0-or-later

/// end.sol -- global settlement engine

pragma solidity ^0.6.12;

interface VatLike {
    function dai(address) external view returns (uint256);
    function ilks(bytes32 ilk) external returns (
        uint256 Art,   // [wad]
        uint256 rate,  // [ray]
        uint256 spot,  // [ray]
        uint256 line,  // [rad]
        uint256 dust   // [rad]
    );
    function urns(bytes32 ilk, address urn) external returns (
        uint256 ink,   // [wad]
        uint256 art    // [wad]
    );
    function debt() external returns (uint256);
    function move(address src, address dst, uint256 rad) external;
    function hope(address) external;
    function flux(bytes32 ilk, address src, address dst, uint256 rad) external;
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
    function suck(address u, address v, uint256 rad) external;
    function cage() external;
}

interface CatLike {
    function ilks(bytes32) external returns (
        address flip,
        uint256 chop,  // [ray]
        uint256 lump   // [rad]
    );
    function cage() external;
}

interface DogLike {
    function ilks(bytes32) external returns (
        address clip,
        uint256 chop,
        uint256 hole,
        uint256 dirt
    );
    function cage() external;
}

interface PotLike {
    function cage() external;
}

interface VowLike {
    function cage() external;
}

interface FlipLike {
    function bids(uint256 id) external view returns (
        uint256 bid,   // [rad]
        uint256 lot,   // [wad]
        address guy,
        uint48  tic,   // [unix epoch time]
        uint48  end,   // [unix epoch time]
        address usr,
        address gal,
        uint256 tab    // [rad]
    );
    function yank(uint256 id) external;
}

interface ClipLike {
    function sales(uint256 id) external view returns (
        uint256 pos,
        uint256 tab,
        uint256 lot,
        address usr,
        uint96  tic,
        uint256 top
    );
    function yank(uint256 id) external;
}

interface PipLike {
    function read() external view returns (bytes32);
}

interface SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32) external view returns (
        PipLike pip,
        uint256 mat    // [ray]
    );
    function cage() external;
}

interface CureLike {
    function tell() external view returns (uint256);
    function cage() external;
}

contract End {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "End/not-authorized");
        _;
    }

    // --- Data ---
    VatLike  public vat;   // CDP Engine
    CatLike  public cat;
    DogLike  public dog;
    VowLike  public vow;   // Debt Engine
    PotLike  public pot;
    SpotLike public spot;
    CureLike public cure;

    uint256  public live;  // Active Flag
    uint256  public when;  // Time of cage                   [unix epoch time]
    uint256  public wait;  // Processing Cooldown Length             [seconds]
    uint256  public debt;  // Total outstanding dai following processing [rad]

    mapping (bytes32 => uint256) public tag;  // Cage price              [ray]
    mapping (bytes32 => uint256) public gap;  // Collateral shortfall    [wad]
    mapping (bytes32 => uint256) public Art;  // Total debt per ilk      [wad]
    mapping (bytes32 => uint256) public fix;  // Final cash price        [ray]

    mapping (address => uint256)                      public bag;  //    [wad]
    mapping (bytes32 => mapping (address => uint256)) public out;  //    [wad]

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    event Cage();
    event Cage(bytes32 indexed ilk);
    event Snip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skim(bytes32 indexed ilk, address indexed urn, uint256 wad, uint256 art);
    event Free(bytes32 indexed ilk, address indexed usr, uint256 ink);
    event Thaw();
    event Flow(bytes32 indexed ilk);
    event Pack(address indexed usr, uint256 wad);
    event Cash(bytes32 indexed ilk, address indexed usr, uint256 wad);

    // --- Init ---
    constructor() public {
        wards[msg.sender] = 1;
        live = 1;
        emit Rely(msg.sender);
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        require(z >= x);
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x <= y ? x : y;
    }
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, y) / RAY;
    }
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = mul(x, WAD) / y;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external auth {
        require(live == 1, "End/not-live");
        if (what == "vat")  vat = VatLike(data);
        else if (what == "cat")   cat = CatLike(data);
        else if (what == "dog")   dog = DogLike(data);
        else if (what == "vow")   vow = VowLike(data);
        else if (what == "pot")   pot = PotLike(data);
        else if (what == "spot") spot = SpotLike(data);
        else if (what == "cure") cure = CureLike(data);
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "End/not-live");
        if (what == "wait") wait = data;
        else revert("End/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Settlement ---
    function cage() external auth {
        require(live == 1, "End/not-live");
        live = 0;
        when = block.timestamp;
        vat.cage();
        cat.cage();
        dog.cage();
        vow.cage();
        spot.cage();
        pot.cage();
        cure.cage();
        emit Cage();
    }

    function cage(bytes32 ilk) external {
        require(live == 0, "End/still-live");
        require(tag[ilk] == 0, "End/tag-ilk-already-defined");
        (Art[ilk],,,,) = vat.ilks(ilk);
        (PipLike pip,) = spot.ilks(ilk);
        // par is a ray, pip returns a wad
        tag[ilk] = wdiv(spot.par(), uint256(pip.read()));
        emit Cage(ilk);
    }

    function snip(bytes32 ilk, uint256 id) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address _clip,,,) = dog.ilks(ilk);
        ClipLike clip = ClipLike(_clip);
        (, uint256 rate,,,) = vat.ilks(ilk);
        (, uint256 tab, uint256 lot, address usr,,) = clip.sales(id);

        vat.suck(address(vow), address(vow),  tab);
        clip.yank(id);

        uint256 art = tab / rate;
        Art[ilk] = add(Art[ilk], art);
        require(int256(lot) >= 0 && int256(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int256(lot), int256(art));
        emit Snip(ilk, id, usr, tab, lot, art);
    }

    function skip(bytes32 ilk, uint256 id) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");

        (address _flip,,) = cat.ilks(ilk);
        FlipLike flip = FlipLike(_flip);
        (, uint256 rate,,,) = vat.ilks(ilk);
        (uint256 bid, uint256 lot,,,, address usr,, uint256 tab) = flip.bids(id);

        vat.suck(address(vow), address(vow),  tab);
        vat.suck(address(vow), address(this), bid);
        vat.hope(address(flip));
        flip.yank(id);

        uint256 art = tab / rate;
        Art[ilk] = add(Art[ilk], art);
        require(int256(lot) >= 0 && int256(art) >= 0, "End/overflow");
        vat.grab(ilk, usr, address(this), address(vow), int256(lot), int256(art));
        emit Skip(ilk, id, usr, tab, lot, art);
    }

    function skim(bytes32 ilk, address urn) external {
        require(tag[ilk] != 0, "End/tag-ilk-not-defined");
        (, uint256 rate,,,) = vat.ilks(ilk);
        (uint256 ink, uint256 art) = vat.urns(ilk, urn);

        uint256 owe = rmul(rmul(art, rate), tag[ilk]);
        uint256 wad = min(ink, owe);
        gap[ilk] = add(gap[ilk], sub(owe, wad));

        require(wad <= 2**255 && art <= 2**255, "End/overflow");
        vat.grab(ilk, urn, address(this), address(vow), -int256(wad), -int256(art));
        emit Skim(ilk, urn, wad, art);
    }

    function free(bytes32 ilk) external {
        require(live == 0, "End/still-live");
        (uint256 ink, uint256 art) = vat.urns(ilk, msg.sender);
        require(art == 0, "End/art-not-zero");
        require(ink <= 2**255, "End/overflow");
        vat.grab(ilk, msg.sender, msg.sender, address(vow), -int256(ink), 0);
        emit Free(ilk, msg.sender, ink);
    }

    function thaw() external {
        require(live == 0, "End/still-live");
        require(debt == 0, "End/debt-not-zero");
        require(vat.dai(address(vow)) == 0, "End/surplus-not-zero");
        require(block.timestamp >= add(when, wait), "End/wait-not-finished");
        debt = sub(vat.debt(), cure.tell());
        emit Thaw();
    }
    function flow(bytes32 ilk) external {
        require(debt != 0, "End/debt-zero");
        require(fix[ilk] == 0, "End/fix-ilk-already-defined");

        (, uint256 rate,,,) = vat.ilks(ilk);
        uint256 wad = rmul(rmul(Art[ilk], rate), tag[ilk]);
        fix[ilk] = mul(sub(wad, gap[ilk]), RAY) / (debt / RAY);
        emit Flow(ilk);
    }

    function pack(uint256 wad) external {
        require(debt != 0, "End/debt-zero");
        vat.move(msg.sender, address(vow), mul(wad, RAY));
        bag[msg.sender] = add(bag[msg.sender], wad);
        emit Pack(msg.sender, wad);
    }
    function cash(bytes32 ilk, uint256 wad) external {
        require(fix[ilk] != 0, "End/fix-ilk-not-defined");
        vat.flux(ilk, address(this), msg.sender, rmul(wad, fix[ilk]));
        out[ilk][msg.sender] = add(out[ilk][msg.sender], wad);
        require(out[ilk][msg.sender] <= bag[msg.sender], "End/insufficient-bag-balance");
        emit Cash(ilk, msg.sender, wad);
    }
}
