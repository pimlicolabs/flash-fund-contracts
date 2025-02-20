// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Options, DefenderOptions, TxOverrides} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";

library Deploy {
    function getOptions(uint256 salt) internal pure returns (Options memory opts) {
        TxOverrides memory txOverrides;

        DefenderOptions memory defenderOpts = DefenderOptions({
            useDefenderDeploy: false,
            skipVerifySourceCode: false,
            relayerId: "",
            salt: bytes32(salt),
            upgradeApprovalProcessId: "",
            licenseType: "",
            skipLicenseType: false,
            txOverrides: txOverrides,
            metadata: ""
        });

        opts.defender = defenderOpts;
    }

}