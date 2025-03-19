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

contract DeployWithdrawalManager is Script, FlashFundFactory {
    function setUp() public {}

    function run() public returns (address _withdrawalManager) {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER"));
        address owner = vm.envAddress("OWNER");
        address signer = vm.rememberKey(vm.envUint("SIGNER"));
        uint256 salt = vm.envUint("SALT");

        uint128 liquidity = uint128(vm.envUint("LIQUIDITY"));

        vm.startBroadcast(deployer);
        Options memory opts = Deploy.getOptions(salt);
 
        FlashFundWithdrawalManager withdrawalManager = deployWithdrawalManager(owner, signer, opts);
        vm.stopBroadcast();

        vm.startBroadcast(owner);
        withdrawalManager.addLiquidity{value: liquidity}(ETH, liquidity);
        vm.stopBroadcast();

        return address(withdrawalManager);
    }
}
