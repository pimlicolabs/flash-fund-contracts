// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashFundStakeManager} from "./FlashFundStakeManager.sol";
import {FlashFundWithdrawalManager} from "./FlashFundWithdrawalManager.sol";
import {Vm} from "forge-std/Vm.sol";
import {Options} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";
import {Core} from "@openzeppelin-0.3.6/foundry-upgrades/internal/Core.sol";
import {Upgrades} from "@openzeppelin-0.3.6/foundry-upgrades/Upgrades.sol";
import {Utils} from "@openzeppelin-0.3.6/foundry-upgrades/internal/Utils.sol";


abstract contract FlashFundFactory {
    address constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function deployStakeManager(address owner, Options memory opts) internal returns (FlashFundStakeManager) {
        address proxy = deployTransparentProxy(
            "FlashFundStakeManager.sol",
            owner,
            abi.encodeCall(FlashFundStakeManager.initialize, (owner)),
            opts
        );

        return FlashFundStakeManager(payable(proxy));
    }

    function deployWithdrawalManager(address owner, address signer, Options memory opts) internal returns (FlashFundWithdrawalManager) {
        address proxy = deployTransparentProxy(
            "FlashFundWithdrawalManager.sol",
            owner,
            abi.encodeCall(FlashFundWithdrawalManager.initialize, (owner, signer)),
            opts
        );

        return FlashFundWithdrawalManager(payable(proxy));
    }

    function deployTransparentProxy(
        string memory contractName,
        address initialOwner,
        bytes memory initializerData,
        Options memory opts
    ) private returns(address) {
        if (!opts.unsafeSkipAllChecks && !opts.unsafeSkipProxyAdminCheck && Core.inferProxyAdmin(initialOwner)) {
            revert(
                string.concat(
                    "`initialOwner` must not be a ProxyAdmin contract. If the contract at address ",
                    Vm(Utils.CHEATCODE_ADDRESS).toString(initialOwner),
                    " is not a ProxyAdmin contract and you are sure that this contract is able to call functions on an actual ProxyAdmin, skip this check with the `unsafeSkipProxyAdminCheck` option."
                )
            );
        }

        Core.validateImplementation(contractName, opts);

        address impl = _deploy(
            contractName,
            opts.constructorData,
            opts.defender.salt
        );

        return _deploy(
            "TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
            abi.encode(impl, initialOwner, initializerData),
            opts.defender.salt
        );
    }

    function _deploy(
        string memory contractName,
        bytes memory constructorData,
        bytes32 salt
    ) private returns (address) {
        bytes memory creationCode = Vm(Utils.CHEATCODE_ADDRESS).getCode(contractName);
        address deployedAddress = _deployDeterminisitc(
            abi.encodePacked(creationCode, constructorData),
            salt
        );

        if (deployedAddress == address(0)) {
            revert(
                string(
                    abi.encodePacked(
                        "Failed to deploy contract ",
                        contractName,
                        ' using constructor data "',
                        string(constructorData),
                        '"'
                    )
                )
            );
        }
        return deployedAddress;
    }

    function _deployDeterminisitc(bytes memory bytecode, bytes32 salt) private returns (address) {
        (bool success, bytes memory data) = DETERMINISTIC_DEPLOYER.call(
            abi.encodePacked(salt, bytecode)
        );

        if (!success) {
            revert (
                string(
                    abi.encodePacked(
                        "Failed to deploy contract using deterministic deployment with salt ",
                        salt,
                        ". Error: ",
                        data
                    )
                )
            );
        }

        return address(uint160(bytes20(data)));
    }
}
