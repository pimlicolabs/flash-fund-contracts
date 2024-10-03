// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IMagicSpend.sol";
import "./StakeManager.sol";
import "./NonceManager.sol";

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";


contract MagicSpend is IMagicSpend, StakeManager, NonceManager {
    address immutable operator;

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
        ClaimInfo calldata claimInfo,
        bytes calldata signature
    ) public {
        // Verify signature
        bool signatureValid = SignatureCheckerLib.isValidSignatureNowCalldata(
            operator,
            getHash(claimInfo),
            signature
        );

        if (!signatureValid) {
            revert InvalidSignature();
        }

        // Check expiration
        if (claimInfo.expiration < block.timestamp) {
            revert ExpiredClaim();
        }

        // Check that the account has enough funds
        // TODO: simplify stake manager
        // Drop unstaked mode?
        if (deposits[claimInfo.account].deposit < claimInfo.amount) {
            revert InsufficientFunds();
        } else {
            deposits[claimInfo.account] -= claimInfo.amount;

            if (deposits[claimInfo.account].stake >= claimInfo.amount) {
                deposits[claimInfo.account].stake -= claimInfo.amount;
            }
        }

        // Check and update nonce
        bool nonceValid = _validateAndUpdateNonce(claimInfo.account, claimInfo.nonce);

        if (!nonceValid) {
            revert InvalidNonce();
        }

        // Transfer ETH to receipient
        SafeTransferLib.forceSafeTransferETH(
            claimInfo.account,
            claimInfo.amount,
            SafeTransferLib.GAS_STIPEND_NO_STORAGE_WRITES
        );

        emit Claim(
            claimInfo.account,
            claimInfo.amount,
            claimInfo.receipient,
            claimInfo.nonce
        );
    }

    function getHash(
        ClaimInfo calldata claimInfo
    ) public view returns (bytes32) {
        return SignatureCheckerLib.toEthSignedMessageHash(
            abi.encode(
                address(this),
                operator,
                block.chainid,
                claimInfo.account,
                claimInfo.amount,
                claimInfo.receipient,
                claimInfo.nonce,
                claimInfo.expiration
            )
        );
    }
}
