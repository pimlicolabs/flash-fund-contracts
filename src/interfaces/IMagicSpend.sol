// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface IMagicSpend {
    struct ClaimInfo {
        address account;
        uint256 amount;
        address receipient;
        uint256 nonce;
        uint48 expiration;
    }

    error InsufficientFunds();
    error InvalidNonce();
    error InvalidSignature();
    error ExpiredClaim();

    event Claim(
        address account,
        uint256 amount,
        address receipient,
        uint256 nonce
    );
}