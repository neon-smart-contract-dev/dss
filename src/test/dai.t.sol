// SPDX-License-Identifier: AGPL-3.0-or-later

/// dai.t.sol -- tests for dai.sol

pragma solidity ^0.6.12;

import "./test.sol";
import "../dai.sol";

contract TokenUser {
    Dai  token;

    constructor(Dai token_) public {
        token = token_;
    }

    function doTransferFrom(address from, address to, uint amount)
        public
        returns (bool)
    {
        return token.transferFrom(from, to, amount);
    }

    function doApprove(address recipient, uint amount)
        public
        returns (bool)
    {
        return token.approve(recipient, amount);
    }

    function doBalanceOf(address who) public view returns (uint) {
        return token.balanceOf(who);
    }

    function doMint(uint wad) public {
        token.mint(address(this), wad);
    }
    function doBurn(uint wad) public {
        token.burn(address(this), wad);
    }
    function doMint(address guy, uint wad) public {
        token.mint(guy, wad);
    }
    function doBurn(address guy, uint wad) public {
        token.burn(guy, wad);
    }
}

contract DaiTest is DSTest {
    uint constant initialBalanceThis = 1000;
    uint constant initialBalanceCal = 100;

    Dai token;
    address user1;
    address user2;
    address self;

    uint amount = 2;
    uint fee = 1;
    uint nonce = 0;
    uint deadline = 0;
    address cal = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
    address del = 0xdd2d5D3f7f1b35b7A0601D6A00DbB7D44Af58479;
    bytes32 r = 0x8e30095d9e5439a4f4b8e4b5c94e7639756474d72aded20611464c8f002efb06;
    bytes32 s = 0x49a0ed09658bc768d6548689bcbaa430cefa57846ef83cb685673a9b9a575ff4;
    uint8 v = 27;
    bytes32 _r = 0x85da10f8af2cf512620c07d800f8e17a2a4cd2e91bf0835a34bf470abc6b66e5;
    bytes32 _s = 0x7e8e641e5e8bef932c3a55e7365e0201196fc6385d942c47d749bf76e73ee46f;
    uint8 _v = 27;

    function setUp() public {
        token = createToken();
        token.mint(address(this), initialBalanceThis);
        token.mint(cal, initialBalanceCal);
        user1 = address(new TokenUser(token));
        user2 = address(new TokenUser(token));
        self = address(this);

        failed = false;
    }

    function createToken() internal returns (Dai) {
        return new Dai(99);
    }

    function testSetupPrecondition() public {
        assertEq(token.balanceOf(self), initialBalanceThis);
    }

    function testTransferCost() public logs_gas {
        token.transfer(address(0), 10);
    }

    function testAllowanceStartsAtZero() public logs_gas {
        assertEq(token.allowance(user1, user2), 0);
    }

    function testValidTransfers() public logs_gas {
        uint sentAmount = 250;
        emit log_named_address("token11111", address(token));
        token.transfer(user2, sentAmount);
        assertEq(token.balanceOf(user2), sentAmount);
        assertEq(token.balanceOf(self), initialBalanceThis - sentAmount);
    }

    function testSelfFailWrongAccountTransfers() public logs_gas {
        uint sentAmount = 250;
        token.transferFrom(user2, self, sentAmount);
        fail();
    }

    function testSelfFailInsufficientFundsTransfers() public logs_gas {
        uint sentAmount = 250;
        token.transfer(user1, initialBalanceThis - sentAmount);
        token.transfer(user2, sentAmount + 1);
        fail();
    }

    function testApproveSetsAllowance() public logs_gas {
        emit log_named_address("Test", self);
        emit log_named_address("Token", address(token));
        emit log_named_address("Me", self);
        emit log_named_address("User 2", user2);
        token.approve(user2, 25);
        assertEq(token.allowance(self, user2), 25);
    }

    function testChargesAmountApproved() public logs_gas {
        uint amountApproved = 20;
        token.approve(user2, amountApproved);
        assertTrue(TokenUser(user2).doTransferFrom(self, user2, amountApproved));
        assertEq(token.balanceOf(self), initialBalanceThis - amountApproved);
    }

    function testSelfFailTransferWithoutApproval() public logs_gas {
        token.transfer(user1, 50);
        token.transferFrom(user1, self, 1);
        fail();
    }

    function testSelfFailChargeMoreThanApproved() public logs_gas {
        token.transfer(user1, 50);
        TokenUser(user1).doApprove(self, 20);
        token.transferFrom(user1, self, 21);
        fail();
    }
    function testTransferFromSelf() public {
        token.transferFrom(self, user1, 50);
        assertEq(token.balanceOf(user1), 50);
    }
    function testSelfFailTransferFromSelfNonArbitrarySize() public {
        // you shouldn't be able to evade balance checks by transferring
        // to yourself
        token.transferFrom(self, self, token.balanceOf(self) + 1);
        fail();
    }
    function testMintself() public {
        uint mintAmount = 10;
        token.mint(address(this), mintAmount);
        assertEq(token.balanceOf(self), initialBalanceThis + mintAmount);
    }
    function testMintGuy() public {
        uint mintAmount = 10;
        token.mint(user1, mintAmount);
        assertEq(token.balanceOf(user1), mintAmount);
    }
    function testSelfFailMintGuyNoAuth() public {
        TokenUser(user1).doMint(user2, 10);
        fail();
    }
    function testMintGuyAuth() public {
        token.rely(user1);
        TokenUser(user1).doMint(user2, 10);
    }

    function testBurn() public {
        uint burnAmount = 10;
        token.burn(address(this), burnAmount);
        assertEq(token.totalSupply(), initialBalanceThis + initialBalanceCal - burnAmount);
    }
    function testBurnself() public {
        uint burnAmount = 10;
        token.burn(address(this), burnAmount);
        assertEq(token.balanceOf(self), initialBalanceThis - burnAmount);
    }
    function testBurnGuyWithTrust() public {
        uint burnAmount = 10;
        token.transfer(user1, burnAmount);
        assertEq(token.balanceOf(user1), burnAmount);

        TokenUser(user1).doApprove(self, uint(-1));
        token.burn(user1, burnAmount);
        assertEq(token.balanceOf(user1), 0);
    }
    function testBurnAuth() public {
        token.transfer(user1, 10);
        token.rely(user1);
        TokenUser(user1).doBurn(10);
    }
    function testBurnGuyAuth() public {
        token.transfer(user2, 10);
        //        token.rely(user1);
        TokenUser(user2).doApprove(user1, uint(-1));
        TokenUser(user1).doBurn(user2, 10);
    }
    function testSelfFailUntrustedTransferFrom() public {
        assertEq(token.allowance(self, user2), 0);
        TokenUser(user1).doTransferFrom(self, user2, 200);
        fail();
    }
    function testTrusting() public {
        assertEq(token.allowance(self, user2), 0);
        token.approve(user2, uint(-1));
        assertEq(token.allowance(self, user2), uint(-1));
        token.approve(user2, 0);
        assertEq(token.allowance(self, user2), 0);
    }
    function testTrustedTransferFrom() public {
        token.approve(user1, uint(-1));
        TokenUser(user1).doTransferFrom(self, user2, 200);
        assertEq(token.balanceOf(user2), 200);
    }
    function testApproveWillModifyAllowance() public {
        assertEq(token.allowance(self, user1), 0);
        assertEq(token.balanceOf(user1), 0);
        token.approve(user1, 1000);
        assertEq(token.allowance(self, user1), 1000);
        TokenUser(user1).doTransferFrom(self, user1, 500);
        assertEq(token.balanceOf(user1), 500);
        assertEq(token.allowance(self, user1), 500);
    }
    function testApproveWillNotModifyAllowance() public {
        assertEq(token.allowance(self, user1), 0);
        assertEq(token.balanceOf(user1), 0);
        token.approve(user1, uint(-1));
        assertEq(token.allowance(self, user1), uint(-1));
        TokenUser(user1).doTransferFrom(self, user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
        assertEq(token.allowance(self, user1), uint(-1));
    }

    function testTypehash() public {
        assertEq(token.PERMIT_TYPEHASH(), 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb);
    }

    function testPermit() public {
        assertEq(token.nonces(cal), 0);
        assertEq(token.allowance(cal, del), 0);
        token.permit(cal, del, 0, 0, true, v, r, s);
        assertEq(token.allowance(cal, del), uint(-1));
        assertEq(token.nonces(cal),1);
    }

    function testSelfFailPermitAddress0() public {
        v = 0;
        token.permit(address(0), del, 0, 0, true, v, r, s);
        fail();
    }

    function testPermitWithExpiry() public {
        token.permit(cal, del, 0, now + 1 hours, true, _v, _r, _s);
        assertEq(token.allowance(cal, del), uint(-1));
        assertEq(token.nonces(cal),1);
    }

    function testSelfFailReplay() public {
        token.permit(cal, del, 0, 0, true, v, r, s);
        token.permit(cal, del, 0, 0, true, v, r, s);
        fail();
    }
}
