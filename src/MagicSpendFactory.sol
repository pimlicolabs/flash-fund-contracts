// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Create2} from "@openzeppelin-v5.0.0/contracts/utils/Create2.sol";
import "./MagicSpend.sol";
import "./../interfaces/IMagicSpendFactory.sol";


contract MagicSpendFactory is IMagicSpendFactory {
    function deployMagicSpend(
        address operator
    ) external {
        bytes memory constructorData = abi.encode(operator);
        bytes memory bytecode = type(MagicSpend).creationCode;

        address contractAddress = Create2.deploy(
            0,
            0,
            abi.encodePacked(
                bytecode,
                constructorData
            )
        );

        emit MagicSpendDeployed(operator, contractAddress);
    }
}