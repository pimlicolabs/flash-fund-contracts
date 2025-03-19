// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {FlashFundStakeManager} from "./../src/FlashFundStakeManager.sol";
import {FlashFundWithdrawalManager} from "./../src/FlashFundWithdrawalManager.sol";
import {FlashFundFactory} from "./../src/FlashFundFactory.sol";
import {ETH} from "./../src/base/Helpers.sol";

import {Upgrades} from "@openzeppelin-0.3.6/foundry-upgrades/Upgrades.sol";
import {Options} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";
import {Deploy} from "./../src/libraries/Deploy.sol";

contract DeployStakeManager is Script, FlashFundFactory {
    function setUp() public {}

    function run() public returns (address _stakeManager) {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER"));
        address owner = vm.envAddress("OWNER");
        address alice = vm.rememberKey(vm.envUint("ALICE"));
        uint256 salt = vm.envUint("SALT");

        uint128 stake = 0.000001 ether;

        vm.startBroadcast(deployer);
        Options memory opts = Deploy.getOptions(salt);
 
        FlashFundStakeManager stakeManager = deployStakeManager(owner, opts);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        stakeManager.addStake{value: stake}(ETH, stake, 86400, alice);
        vm.stopBroadcast();

        return address(stakeManager);
    }
}
