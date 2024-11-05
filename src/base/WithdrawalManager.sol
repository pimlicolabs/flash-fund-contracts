// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {OwnableUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ETH} from "./Helpers.sol";

abstract contract WithdrawalManager is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event LiquidityAdded(address asset, uint128 amount);

    event LiquidityRemoved(address asset, uint128 amount);

    error InsufficientLiquidity(address asset);

    function addLiquidity(address asset, uint128 amount) external payable onlyOwner nonReentrant {
        if (asset == ETH) {
            if (msg.value != amount) {
                revert InsufficientLiquidity(asset);
            }
        } else {
            SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), amount);
        }

        emit LiquidityAdded(asset, amount);
    }

    function removeLiquidity(address asset, uint128 amount) external onlyOwner nonReentrant {
        if (asset == ETH) {
            SafeTransferLib.forceSafeTransferETH(msg.sender, amount);
        } else {
            SafeTransferLib.safeTransfer(asset, msg.sender, amount);
        }

        emit LiquidityRemoved(asset, amount);
    }
}
