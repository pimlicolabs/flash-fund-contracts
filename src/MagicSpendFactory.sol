// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MagicSpendStakeManager} from "./MagicSpendStakeManager.sol";
import {MagicSpendWithdrawalManager} from "./MagicSpendWithdrawalManager.sol";

import {Upgrades} from "@openzeppelin-0.3.6/foundry-upgrades/Upgrades.sol";

abstract contract MagicSpendFactory {
    function deployStakeManager(address owner) internal returns (MagicSpendStakeManager) {
        address proxy = Upgrades.deployTransparentProxy(
            "MagicSpendStakeManager.sol", owner, abi.encodeCall(MagicSpendStakeManager.initialize, (owner))
        );

        return MagicSpendStakeManager(payable(proxy));
    }

    function deployWithdrawalManager(address owner, address signer) internal returns (MagicSpendWithdrawalManager) {
        address proxy = Upgrades.deployTransparentProxy(
            "MagicSpendWithdrawalManager.sol",
            owner,
            abi.encodeCall(MagicSpendWithdrawalManager.initialize, (owner, signer))
        );

        return MagicSpendWithdrawalManager(payable(proxy));
    }
}
