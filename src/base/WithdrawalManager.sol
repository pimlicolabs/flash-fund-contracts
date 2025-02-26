// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {OwnableUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-5.0.2/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ETH} from "./Helpers.sol";

/**
 * Manages liquidity.
 * Liquidity (ETH or ERC20 tokens) can be added only by owner.
 * Liquidity can be removed only by owner at any time.
 * Liquidity can also be removed by calling the `MagicSpendWithdrawalManager.withdraw`
 */
abstract contract WithdrawalManager is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event LiquidityAdded(address token, uint128 amount);

    event LiquidityRemoved(address token, uint128 amount);

    error InsufficientLiquidity(address token);

    receive() external payable {
        emit LiquidityAdded(ETH, uint128(msg.value));
    }

    function addLiquidity(address token, uint128 amount) external payable onlyOwner nonReentrant {
        if (token == ETH) {
            if (msg.value != amount) {
                revert InsufficientLiquidity(token);
            }
        } else {
            SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), amount);
        }

        emit LiquidityAdded(token, amount);
    }

    function removeLiquidity(address token, uint128 amount) external onlyOwner nonReentrant {
        if (token == ETH) {
            SafeTransferLib.forceSafeTransferETH(msg.sender, amount);
        } else {
            SafeTransferLib.safeTransfer(token, msg.sender, amount);
        }

        emit LiquidityRemoved(token, amount);
    }
}
