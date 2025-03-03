// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MagicSpendStakeManager} from "./../src/MagicSpendStakeManager.sol";
import {MagicSpendWithdrawalManager} from "./../src/MagicSpendWithdrawalManager.sol";
import {MagicSpendFactory} from "./../src/MagicSpendFactory.sol";
import {ETH} from "./../src/base/Helpers.sol";

import {Upgrades} from "@openzeppelin-0.3.6/foundry-upgrades/Upgrades.sol";
import {Options} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";
import {Deploy} from "./../src/libraries/Deploy.sol";
contract MagicSpend_Deploy is Script, MagicSpendFactory {
    function setUp() public {}

    function run() public returns (address _stakeManager, address _withdrawalManager) {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER"));
        address owner = vm.rememberKey(vm.envUint("OWNER"));
        address signer = vm.rememberKey(vm.envUint("SIGNER"));
        address alice = vm.rememberKey(vm.envUint("ALICE"));
        uint256 salt = vm.envUint("SALT");

        uint128 liquidity = uint128(vm.envUint("LIQUIDITY"));
        uint128 stake = 0.000001 ether;

        vm.startBroadcast(deployer);
        Options memory opts = Deploy.getOptions(salt);
 
        MagicSpendStakeManager stakeManager = deployStakeManager(owner, opts);
        MagicSpendWithdrawalManager withdrawalManager = deployWithdrawalManager(owner, signer, opts);
        vm.stopBroadcast();

        vm.startBroadcast(owner);
        withdrawalManager.addLiquidity{value: liquidity}(ETH, liquidity);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        stakeManager.addStake{value: stake}(ETH, stake, 86400);
        vm.stopBroadcast();

        return (address(stakeManager), address(withdrawalManager));
    }
}
