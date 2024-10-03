// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface IMagicSpend {
    struct ClaimInfo {
        address account;
        uint256 amount;
        address receipient;
        uint256 nonce;
    }

    event Claim();
}