// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MagicSpendStakeManager} from "./../src/MagicSpendStakeManager.sol";
import {MagicSpendWithdrawalManager} from "./../src/MagicSpendWithdrawalManager.sol";
import {ETH} from "./../src/base/Helpers.sol";

import {Upgrades} from "@openzeppelin-0.3.6/foundry-upgrades/Upgrades.sol";

contract MagicSpend_Deploy is Script {
    function setUp() public {}

    function run() public returns (address _stakeManager, address _withdrawalManager) {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER"));
        address owner = vm.rememberKey(vm.envUint("OWNER"));
        address signer = vm.rememberKey(vm.envUint("SIGNER"));
        address alice = vm.rememberKey(vm.envUint("ALICE"));

        // bytes32 salt = vm.envBytes32("SALT");

        vm.startBroadcast(deployer);
        address proxyStakeManager = Upgrades.deployTransparentProxy(
            "MagicSpendStakeManager.sol", owner, abi.encodeCall(MagicSpendStakeManager.initialize, (owner))
        );

        MagicSpendStakeManager stakeManager = MagicSpendStakeManager(payable(proxyStakeManager));

        address proxyWithdrawalManager = Upgrades.deployTransparentProxy(
            "MagicSpendWithdrawalManager.sol",
            owner,
            abi.encodeCall(MagicSpendWithdrawalManager.initialize, (owner, signer))
        );

        MagicSpendWithdrawalManager withdrawalManager = MagicSpendWithdrawalManager(payable(proxyWithdrawalManager));

        withdrawalManager.addLiquidity{value: 0.01 ether}(ETH, 0.01 ether);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        stakeManager.addStake{value: 0.01 ether}(ETH, 0.01 ether, 86400);
        vm.stopBroadcast();

        return (address(stakeManager), address(withdrawalManager));
    }
}
