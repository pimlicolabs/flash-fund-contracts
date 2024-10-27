// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


/// @notice Helper struct that represents a call to make.
struct CallStruct {
    address to;
    uint256 value;
    bytes data;
}

/// @notice Request acts as a reciept
/// @dev signed by the signer it allows to withdraw funds
/// @dev signed by the user it allows to claim funds from it's stake
struct WithdrawRequest {
    /// @dev Asset that user wants to withdraw.
    address asset;
    /// @dev The requested amount to withdraw.
    uint128 amount;
    /// @dev Chain id of the network, where the request will be withdrawn.
    uint128 chainId;
    /// @dev Address that will receive the funds.
    address recipient;
    /// @dev Calls that will be made before the funds are sent to the user.
    CallStruct[] preCalls;
    /// @dev Calls that will be made after the funds are sent to the user.
    CallStruct[] postCalls;
    /// @dev The time in which the request is valid until.
    uint48 validUntil;
    /// @dev The time in which this request is valid after.
    uint48 validAfter;
    /// @dev The salt of the request.
    uint48 salt;
}

struct ClaimStruct {
    /// @dev Asset that can be claimed.
    address asset;
    /// @dev The amount to claim.
    uint128 amount;
    /// @dev The fee to claim.
    uint128 fee;
    /// @dev Chain id of the network, where the request will be claimed.
    uint128 chainId;
}

struct ClaimRequest {
    /// @dev Address which stake is claimed.
    address account;
    /// @dev List of claims, one claim per chain id
    ClaimStruct[] claims;
    /// @dev The time in which the request is valid until.
    uint48 validUntil;
    /// @dev The time in which the request is valid after.
    uint48 validAfter;
    /// @dev The salt of the request.
    uint48 salt;
}