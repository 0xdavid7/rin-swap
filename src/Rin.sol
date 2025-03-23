// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Router } from "./interfaces/IUniswapV2Router.sol";

contract RinSwap is Ownable {
    using SafeERC20 for IERC20;

    struct SwapOrder {
        address tokenAddress;
        uint256 amount;
        uint256 amountOutMin;
        uint256 deadline;
    }

    IUniswapV2Router public immutable UNISWAPV2_ROUTER;
    address public immutable WETH;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    uint256 public feeBps; // 1% = 100 basis points

    error InsufficientETH();
    error SwapFailed();
    error InvalidOrder();
    error EmptyOrders();
    error InvalidFeeRate();
    error TransferETHFailed();
    error NoFeesToWithdraw();

    event SwapExecuted(
        address indexed user, address indexed tokenAddress, bool isBuy, uint256 amountIn, uint256 amountOut
    );

    event FeeRateChanged(uint256 oldRate, uint256 newRate);

    modifier validFee(uint256 _feeBps) {
        if (_feeBps > FEE_DENOMINATOR) {
            revert InvalidFeeRate();
        }
        _;
    }

    constructor(address _router, address _wrappedETH, uint256 _feeBps) Ownable(msg.sender) validFee(_feeBps) {
        UNISWAPV2_ROUTER = IUniswapV2Router(_router);
        WETH = _wrappedETH;
        feeBps = _feeBps;
    }

    function setFeeRate(uint256 _feeBps) external onlyOwner validFee(_feeBps) {
        uint256 oldRate = feeBps;
        feeBps = _feeBps;
        emit FeeRateChanged(oldRate, _feeBps);
    }

    function executeBuyOrder(SwapOrder calldata order) external payable {
        if (order.amount == 0) {
            revert InvalidOrder();
        }

        if (msg.value < order.amount) {
            revert InsufficientETH();
        }

        uint256 fee = _calculateFee(order.amount);
        uint256 swapAmount = order.amount - fee;

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = order.tokenAddress;

        try UNISWAPV2_ROUTER.swapExactETHForTokens{ value: swapAmount }(
            order.amountOutMin, path, msg.sender, order.deadline
        ) returns (uint256[] memory amounts) {
            emit SwapExecuted(msg.sender, order.tokenAddress, true, swapAmount, amounts[1]);
        } catch {
            revert SwapFailed();
        }

        if (msg.value > order.amount) {
            // Return excess ETH
            (bool success,) = msg.sender.call{ value: msg.value - order.amount }("");
            if (!success) {
                revert TransferETHFailed();
            }
        }
    }

    function executeSellOrder(SwapOrder calldata order) external {
        if (order.amount == 0) {
            revert InvalidOrder();
        }

        address[] memory path = new address[](2);
        path[0] = order.tokenAddress;
        path[1] = WETH;

        // Transfer tokens from user
        IERC20(order.tokenAddress).safeTransferFrom(msg.sender, address(this), order.amount);

        // Approve router
        IERC20(order.tokenAddress).approve(address(UNISWAPV2_ROUTER), order.amount);

        try UNISWAPV2_ROUTER.swapExactTokensForETH(
            order.amount, order.amountOutMin, path, address(this), order.deadline
        ) returns (uint256[] memory amounts) {
            uint256 fee = _calculateFee(amounts[1]);
            uint256 amountToReturn = amounts[1] - fee;

            // Return ETH minus fee
            (bool success,) = msg.sender.call{ value: amountToReturn }("");
            if (!success) {
                revert TransferETHFailed();
            }
            emit SwapExecuted(msg.sender, order.tokenAddress, false, order.amount, amounts[1]);
        } catch {
            revert SwapFailed();
        }
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeBps) / FEE_DENOMINATOR;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert NoFeesToWithdraw();
        }

        (bool success,) = msg.sender.call{ value: balance }("");
        if (!success) {
            revert TransferETHFailed();
        }
    }

    receive() external payable { }
}
