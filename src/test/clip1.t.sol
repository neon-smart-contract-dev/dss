// SPDX-License-Identifier: AGPL-3.0-or-later

// clip.t.sol -- tests for clip.sol

pragma solidity ^0.6.12;

import "./test.sol";

interface IVat {
    function dai(address u) external returns (uint256); // [rad]
    function gem(bytes32 ilk, address usr) external view returns (uint); // [wad]
    function urns(bytes32 ilk, address usr) external view returns (uint256, uint256);
    function ilks(bytes32 ilk) external returns (uint256, uint256, uint256, uint256, uint256);

    function slip(bytes32 ilk, address usr, int256 wad) external;
    function hope(address usr) external;
    function init(bytes32 ilk) external;
    function suck(address u, address v, uint rad) external;
    function file(bytes32 what, uint data) external;
    function file(bytes32 ilk, bytes32 what, uint data) external;
    function rely(address usr) external;
    function frob(bytes32 i, address u, address v, address w, int dink, int dart) external;
    function fold(bytes32 i, address u, int rate) external;
}

interface ISpotter {
    function file(bytes32 ilk, bytes32 what, address pip_) external;
    function file(bytes32 what, uint data) external;
    function file(bytes32 ilk, bytes32 what, uint data) external;
    function poke(bytes32 ilk) external;
}

interface IVow {
    function rely(address usr) external;
}

interface IToken {
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function approve(address guy) external returns (bool);
    function mint(uint wad) external;
    function transfer(address dst, uint wad) external returns (bool);
    function setOwner(address owner_) external;
    function balanceOf(address user) external returns (uint256);
}

interface IGemJoin {
    function exit(address usr, uint wad) external;
}

interface IDaiJoin {
    function join(address usr, uint wad) external;
}

interface IExchange {
    function sellGold(uint256 goldAmt) external;
}

interface IDog {
    function bark(bytes32 ilk, address urn, address kpr) external returns (uint256 id);
    function file(bytes32 what, address data) external;
    function file(bytes32 what, uint256 data) external;
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function file(bytes32 ilk, bytes32 what, address clip) external;
    function rely(address usr) external;
    function chop(bytes32 ilk) external view returns (uint256);
    function ilks(bytes32 ilk) external returns (address, uint256, uint256, uint256);
    function Dirt() external returns (uint256);
}

interface IValue {
    function poke(bytes32 wut) external;
}

interface IClipper {
    function take(uint256 id, uint256 amt, uint256 max, address who, bytes calldata data) external;
    function redo(uint256 id, address kpr) external;
    function kick(uint256 tab, uint256 lot, address usr, address kpr) external returns (uint256);
    function vat() external returns (address);
    function dog() external returns (address);
    function file(bytes32 what, uint256 data) external;
    function file(bytes32 what, address data) external;
    function yank(uint256 id) external;
    function kicks() external returns (uint256);
    function sales(uint256 id) external returns (uint256, uint256, uint256, address, uint96, uint256);
    function upchost() external;
    function rely(address usr) external;
    function getStatus(uint256 id) external view returns (bool, uint256, uint256, uint256);
    function chost() external returns (uint256);
    function chip() external returns (uint64);
    function tip() external returns (uint192);
    function stopped() external returns (uint256);
}

interface IGuy {
    function hope(address usr) external;
    function take(uint256 id, uint256 amt, uint256 max, address who, bytes calldata data) external;
}

contract ClipperTest1 is DSTest {
    IVat     vat;
    IDog     dog;
    ISpotter spot;
    IVow     vow;
    IValue pip;
    IToken gold;
    IGemJoin goldJoin;
    IToken dai;
    IDaiJoin daiJoin;
    IClipper clip;
    
    address me;
    IExchange exchange;

    address ali;
    address bob;

    uint256 WAD = 10 ** 18;
    uint256 RAY = 10 ** 27;
    uint256 RAD = 10 ** 45;

    bytes32 constant ilk = "gold";
    uint256 constant goldPrice = 5 ether;

    uint256 constant startTime = 604411200; // Used to avoid issues with `now`

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function _ink(bytes32 ilk_, address urn_) internal view returns (uint256) {
        (uint256 ink_,) = vat.urns(ilk_, urn_);
        return ink_;
    }
    function _art(bytes32 ilk_, address urn_) internal view returns (uint256) {
        (,uint256 art_) = vat.urns(ilk_, urn_);
        return art_;
    }

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }
    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function setUp1(address _vat, address _spot, address _vow, address _gold, address _goldJoin, address _dai, address _daiJoin, address _exchange) public {
        me = address(this);

        vat = IVat(_vat);
        spot = ISpotter(_spot);
        vat.rely(address(spot));

        vow = IVow(_vow);        
        gold = IToken(_gold);
        goldJoin = IGemJoin(_goldJoin);
        vat.rely(address(goldJoin));

        dai = IToken(_dai);
        daiJoin = IDaiJoin(_daiJoin);
        vat.suck(address(0), address(daiJoin), rad(1000 ether));
        exchange = IExchange(_exchange);

        dai.mint(1000 ether);
        dai.transfer(address(exchange), 1000 ether);
        dai.setOwner(address(daiJoin));
        gold.mint(1000 ether);
        gold.transfer(address(goldJoin), 1000 ether);

        failed = false;
    }

    function setUp2(address _dog, address _pip, address _clip, address _ali, address _bob) public {
        dog = IDog(_dog);
        dog.file("vow", address(vow));
        vat.rely(address(dog));
        vow.rely(address(dog));

        vat.init(ilk);

        vat.slip(ilk, me, 1000 ether);

        pip = IValue(_pip);
        pip.poke(bytes32(goldPrice)); // Spot = $2.5

        spot.file(ilk, "pip", address(pip));
        spot.file(ilk, "mat", ray(2 ether)); // 200% liquidation ratio for easier test calcs
        spot.poke(ilk);

        vat.file(ilk, "dust", rad(20 ether)); // $20 dust
        vat.file(ilk, "line", rad(10000 ether));
        vat.file("Line",      rad(10000 ether));

        dog.file(ilk, "chop", 1.1 ether); // 10% chop
        dog.file(ilk, "hole", rad(1000 ether));
        dog.file("Hole", rad(1000 ether));

        // dust and chop filed previously so clip.chost will be set correctly
        clip = IClipper(_clip);
        clip.upchost();
        clip.rely(address(dog));

        dog.file(ilk, "clip", address(clip));
        dog.rely(address(clip));
        vat.rely(address(clip));

        assertEq(vat.gem(ilk, me), 1000 ether);
        assertEq(vat.dai(me), 0);
        vat.frob(ilk, me, me, me, 40 ether, 100 ether);
        assertEq(vat.gem(ilk, me), 960 ether);
        assertEq(vat.dai(me), rad(100 ether));

        pip.poke(bytes32(uint256(4 ether))); // Spot = $2
        spot.poke(ilk);          // Now unsafe

        ali = _ali;
        bob = _bob;

        vat.hope(address(clip));
        IGuy(ali).hope(address(clip));
        IGuy(bob).hope(address(clip));

        vat.suck(address(0), address(this), rad(1000 ether));
        vat.suck(address(0), ali,  rad(1000 ether));
        vat.suck(address(0), bob,  rad(1000 ether));

        failed = false;
    }

    function test_change_dog() public {
        assertTrue(clip.dog() != address(123));
        clip.file("dog", address(123));
        assertEq(clip.dog(), address(123));
    }

    function test_get_chop() public {
        uint256 chop = dog.chop(ilk);
        (, uint256 chop2,,) = dog.ilks(ilk);
        assertEq(chop, chop2);
    }

    function testSelfFail_kick_zero_price() public {
        pip.poke(bytes32(0));
        dog.bark(ilk, me, address(this));
        fail();
    }

    function try_kick(uint256 tab, uint256 lot, address usr, address kpr) internal returns (bool ok) {
        string memory sig = "kick(uint256,uint256,address,address)";
        (ok,) = address(clip).call(abi.encodeWithSignature(sig, tab, lot, usr, kpr));
    }

    function test_kick_basic() public {
        assertTrue(try_kick(1 ether, 2 ether, address(1), address(this)));
    }

    function test_kick_zero_tab() public {
        assertTrue(!try_kick(0, 2 ether, address(1), address(this)));
    }

    function test_kick_zero_lot() public {
        assertTrue(!try_kick(1 ether, 0, address(1), address(this)));
    }

    function test_kick_zero_usr() public {
        assertTrue(!try_kick(1 ether, 2 ether, address(0), address(this)));
    }
}
