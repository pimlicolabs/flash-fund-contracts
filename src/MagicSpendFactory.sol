// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "./MagicSpend.sol";
import "./interfaces/IMagicSpendFactory.sol";


contract MagicSpendFactory is IMagicSpendFactory {
    function deployMagicSpend(
        address operator
    ) external returns (address) {
        address owner = msg.sender;

        bytes memory constructorData = abi.encode(operator);
        bytes memory bytecode = type(MagicSpend).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(owner));

        address contractAddress = Create2.deploy(
            0,
            salt,
            abi.encodePacked(
                bytecode,
                constructorData
            )
        );

        emit MagicSpendDeployed(operator, contractAddress);

        return contractAddress;
    }
}