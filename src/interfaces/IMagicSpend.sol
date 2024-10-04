// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface IMagicSpend {
    struct ClaimInfo {
        address account;
        uint256 amount;
        address receipient;
        uint256 nonce;
        uint256 chainId;
        uint48 expiration;
    }

    error InsufficientFunds();
    error InvalidNonce();
    error InvalidSignature();
    error ExpiredClaim();
    error InvalidChainId();

    event Claim(
        address account,
        uint256 amount,
        address receipient,
        uint256 nonce
    );

    event OperatorUpdated(address operator);

    function getOperator() external view returns (address);

    function setOperator(
        address _operator
    ) external;
}