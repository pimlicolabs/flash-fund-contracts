// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IMagicSpend.sol";
import "./StakeManager.sol";

import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";


contract MagicSpend is IMagicSpend, StakeManager {
    address immutable operator;

    error InsufficientFunds();
    error InvalidNonce();

    constructor(
        address _operator
    ) {
        operator = _operator;
    }

    // Used in two scenarios:
    // 1. Operator himself claims the funds from the deposits
    // - It's supposed to happen after the user has spent some of them
    // 2. User claims the funds from the deposits
    function claim(
        uint256 _amount,
        ClaimInfo calldata _claimInfo
    ) public {
        // Verify signature

        // Check that the account has enough funds
        if (deposits[_claimInfo.account] < _amount) {
            revert InsufficientFunds();
        } else {
            deposits[_claimInfo.account] -= _amount;
        }

        // Check and update nonce
        bool nonceValid = _validateAndUpdateNonce(_claimInfo.account, _claimInfo.nonce);

        if (!nonceValid) {
            revert InvalidNonce();
        }

        // Safely transfer ETH to receipient
    }

    function getHash(
        ClaimInfo memory claimInfo
    ) public view returns (bytes32) {
        return SignatureCheckerLib.toEthSignedMessageHash(
            abi.encode(
                address(this),
                account,
                block.chainid,
                claimInfo.account,
                claimInfo.amount,
                claimInfo.receipient,
                claimInfo.nonce
            )
        );
    }
}
