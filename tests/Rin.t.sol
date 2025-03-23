// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { RinSwap } from "../src/Rin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/src/console2.sol";

contract RinTest is Test {
    RinSwap public rinSwap;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;

    address public owner;
    address public user1;
    address public user2;
    uint256 public initialFeeRate = 100; // 1%

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork("mainnet");

        // Setup test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        vm.prank(owner);

        // Deploy RinSwap
        rinSwap = new RinSwap(UNISWAP_V2_ROUTER, WETH, initialFeeRate);

        // Fund test accounts with ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_Constructor() public view {
        assertEq(address(rinSwap.UNISWAPV2_ROUTER()), UNISWAP_V2_ROUTER);
        assertEq(rinSwap.WETH(), WETH);
        assertEq(rinSwap.feeBps(), initialFeeRate);
    }

    function test_SetFeeRate() public {
        uint256 newFeeRate = 200; // 2%

        console2.log("Owner: ", rinSwap.owner());
        console2.log("User1: ", user1);

        // Should fail if not owner
        vm.prank(user1);
        vm.expectRevert();
        rinSwap.setFeeRate(newFeeRate);

        // Should succeed if owner
        vm.expectEmit(true, true, true, true);
        emit RinSwap.FeeRateChanged(initialFeeRate, newFeeRate);
        rinSwap.setFeeRate(newFeeRate);

        assertEq(rinSwap.feeBps(), newFeeRate);
    }

    function test_SetFeeRateExceedsMax() public {
        uint256 invalidFeeRate = 10_001;
        vm.expectRevert(RinSwap.InvalidFeeRate.selector);
        rinSwap.setFeeRate(invalidFeeRate);
    }

    function test_ExecuteBuyOrder() public {
        uint256 amount = 1 ether;
        uint256 fee = (amount * rinSwap.feeBps()) / rinSwap.FEE_DENOMINATOR();

        RinSwap.SwapOrder memory order = RinSwap.SwapOrder({
            tokenAddress: PEPE,
            amount: amount,
            amountOutMin: 0,
            deadline: block.timestamp + 1 hours
        });

        vm.startPrank(user1);

        // Should fail if not enough ETH sent
        vm.expectRevert(RinSwap.InsufficientETH.selector);
        rinSwap.executeBuyOrder{ value: 0.5 ether }(order);

        uint256 nativeBalanceBefore = user1.balance;
        uint256 balanceBefore = IERC20(PEPE).balanceOf(user1);
        uint256 contractBalanceBefore = address(rinSwap).balance;

        rinSwap.executeBuyOrder{ value: amount }(order);

        uint256 nativeBalanceAfter = user1.balance;
        uint256 balanceAfter = IERC20(PEPE).balanceOf(user1);
        uint256 contractBalanceAfter = address(rinSwap).balance;

        vm.stopPrank();

        assertTrue(balanceAfter > balanceBefore, "Should receive PEPE tokens");
        assertEq(nativeBalanceBefore - nativeBalanceAfter, amount, "Should spend ETH");
        assertEq(contractBalanceAfter - contractBalanceBefore, fee, "Contract should collect fee");
    }

    function test_ExecuteSellOrder() public {
        // First buy some PEPE to sell
        test_ExecuteBuyOrder();

        vm.startPrank(user1);

        uint256 pepeBalance = IERC20(PEPE).balanceOf(user1);

        RinSwap.SwapOrder memory order = RinSwap.SwapOrder({
            tokenAddress: PEPE,
            amount: pepeBalance,
            amountOutMin: 0,
            deadline: block.timestamp + 1 hours
        });

        // Approve tokens to contract
        IERC20(PEPE).approve(address(rinSwap), pepeBalance);

        uint256 ethBalanceBefore = user1.balance;
        uint256 contractBalanceBefore = address(rinSwap).balance;

        // Execute sell order
        rinSwap.executeSellOrder(order);

        uint256 ethBalanceAfter = user1.balance;
        uint256 contractBalanceAfter = address(rinSwap).balance;

        vm.stopPrank();

        // User should receive ETH
        assertTrue(ethBalanceAfter > ethBalanceBefore, "Should receive ETH");

        // Contract fee balance should increase
        assertTrue(contractBalanceAfter > contractBalanceBefore, "Contract should collect fee");

        // User should have no PEPE left
        assertEq(IERC20(PEPE).balanceOf(user1), 0, "Should have no PEPE tokens left");

        console2.log("PEPE balance before selling: ", pepeBalance);
        console2.log("ETH balance before: ", ethBalanceBefore);
        console2.log("ETH balance: ", ethBalanceAfter);
        console2.log("Contract balance before: ", contractBalanceBefore);
        console2.log("Contract balance: ", contractBalanceAfter);
    }

    function test_ExecuteBuyOrder_ExcessETH() public {
        uint256 amount = 1 ether;
        uint256 excessAmount = 0.5 ether;

        RinSwap.SwapOrder memory order = RinSwap.SwapOrder({
            tokenAddress: PEPE,
            amount: amount,
            amountOutMin: 0,
            deadline: block.timestamp + 1 hours
        });

        vm.startPrank(user1);

        uint256 balanceBefore = user1.balance;
        rinSwap.executeBuyOrder{ value: amount + excessAmount }(order);
        uint256 balanceAfter = user1.balance;

        vm.stopPrank();

        // Should have refunded excess ETH (minus gas costs)
        assertApproxEqAbs(balanceBefore - balanceAfter, amount, 0.01 ether, "Should refund excess ETH");
    }

    function test_WithdrawFees() public {
        test_ExecuteBuyOrder();

        // Transfer ownership to new owner

        uint256 contractBalance = address(rinSwap).balance;
        assertTrue(contractBalance > 0, "Should have fees collected");
        console2.log("Contract balance: ", contractBalance);

        // Call withdrawFees as the new owner
        vm.prank(owner);
        uint256 ownerBalanceBefore = owner.balance;
        rinSwap.withdrawFees();
        uint256 ownerBalanceAfter = owner.balance;

        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalance);
        assertEq(address(rinSwap).balance, 0);
        console2.log("Owner balance: ", ownerBalanceAfter);
    }
}
