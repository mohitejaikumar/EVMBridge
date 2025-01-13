// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/BridgeSepolia.sol";
import "../src/BridgeHolesky.sol";
import "../src/BJCOIN.sol";
import "../src/KJCOIN.sol";

contract TestBridgeContract is Test {
    BridgeContract c1;
    Bridge c2;
    BJCOIN bridgeToken;
    KJCOIN token;

    address user = address(1);

    function setUp() public {
        bridgeToken = new BJCOIN();
        token = new KJCOIN();
        c1 = new BridgeContract(address(token));
        c2 = new Bridge(address(bridgeToken));
        // transfer ownership to the BridgeGoerli contract
        bridgeToken.transferOwnership(address(c2));
    }


    /// @dev Test the successful Bridge Sepolia -> Goerli
    function test_Bridge_JKCOIN_to_BJKCOIN() public {
        // mint JKCOIN token to the user
        token.mint(user, 1000 * 10 ** token.decimals());
        vm.startPrank(user);
        // approve the BridgeSepolia contract to spend the JKCOIN token
        token.approve(address(c1), 100 * 10 ** token.decimals());
        // deposit the JKCOIN token to the BridgeSepolia contract
        c1.deposit(address(token), 100 * 10 ** token.decimals());
        assertEq(token.balanceOf(user), 900 * 10 ** token.decimals());
        assertEq(c1.pendingBalances(user), 100 * 10 ** token.decimals());
        vm.stopPrank();

        // mint BJKCOIN token to the user
        c2.mint(address(bridgeToken), user, 100 * 10 ** bridgeToken.decimals(),1);
        assertEq(c2.pendingBalances(user), 100 * 10 ** bridgeToken.decimals());
    }

    function test_Successful_Redeem_JKCOIN() public {
         // mint JKCOIN token to the user
        token.mint(user, 1000 * 10 ** token.decimals());
        vm.startPrank(user);
        // approve the BridgeSepolia contract to spend the JKCOIN token
        token.approve(address(c1), 100 * 10 ** token.decimals());
        // deposit the JKCOIN token to the BridgeSepolia contract
        c1.deposit(address(token), 100 * 10 ** token.decimals());
        vm.stopPrank();

        // mint BJKCOIN token to the user
        c2.mint(address(bridgeToken), user, 100 * 10 ** bridgeToken.decimals(),1);
        assertEq(c2.pendingBalances(user), 100 * 10 ** bridgeToken.decimals());
        // burn the BJKCOIN token from the user
        vm.startPrank(user);
        c2.burn(address(bridgeToken), 100 * 10 ** bridgeToken.decimals());
        assertEq(c2.pendingBalances(user), 0);
        vm.stopPrank();
        // redeem the JKCOIN
        c1.redeem(address(token), user, 100 * 10 ** token.decimals(),1);
        assertEq(c1.pendingBalances(user), 0);
        assertEq(token.balanceOf(user), 1000 * 10 ** token.decimals());
    }

    function testFail_Bridge_JKCOIN_Insufficient_Allowance() public {
        // mint JKCOIN token to the user
        token.mint(user, 1000 * 10 ** token.decimals());
        
        vm.prank(user);
        vm.expectRevert(BridgeContract.BridgeToken_Insufficient_Allowance.selector);
        c1.deposit(address(token), 200 * 10 ** token.decimals());
        
    }


}
