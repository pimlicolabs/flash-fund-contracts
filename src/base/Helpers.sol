// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

/// @notice Helper struct that represents a call to make.
struct Call {
    address to;
    uint256 value;
    bytes data;
}

/// @notice This struct represents a withdrawal request.
/// @dev signed by the signer it allows to withdraw funds from the `MagicSpendWithdrawalManager` contract
struct Withdrawal {
    /// @dev Token that will be withdrawn.
    address token;
    /// @dev The requested amount to withdraw.
    uint128 amount;
    /// @dev Chain id of the network, where the withdrawal will be executed.
    uint128 chainId;
    /// @dev Address that will receive the funds.
    address recipient;
    /// @dev Calls that will be made before the funds are sent to the user.
    Call[] preCalls;
    /// @dev Calls that will be made after the funds are sent to the user.
    Call[] postCalls;
    /// @dev The time in which the withdrawal is valid until.
    uint48 validUntil;
    /// @dev The time in which this withdrawal is valid after.
    uint48 validAfter;
    /// @dev The salt of the withdrawal.
    uint48 salt;
}

/// @notice Helper struct that represents an allowance for a specific asset.
struct AssetAllowance {
    /// @dev Token that can be claimed.
    address token;
    /// @dev The amount to claim.
    uint128 amount;
    /// @dev The chain id of the network, where the claim will be made.
    uint128 chainId;
}

/// @notice Helper struct that represents an allowance.
/// @dev signed by the user it allows Pimlico to claim part of user's stake from the `MagicSpendStakeManager` contract
/// @dev on one or many chains.
struct Allowance {
    /// @dev Address which stake is allowed to be claimed.
    address account;
    /// @dev List of assets, allowed to be claimed.
    /// @dev One allowance per asset, where asset is the combination of (token,chainId)
    AssetAllowance[] assets;
    /// @dev The time in which the allowance is valid until.
    uint48 validUntil;
    /// @dev The time in which the allowance is valid after.
    uint48 validAfter;
    /// @dev The salt of the allowance.
    uint48 salt;
    /// @dev Signer which is allowed to request withdrawals on behalf of this allowance.
    address operator;
    /// @dev Metadata of the allowance.
    bytes metadata;
}

bytes32 constant ASSET_ALLOWANCE_TYPE_HASH = keccak256("AssetAllowance(address token,uint128 amount,uint128 chainId)");
bytes32 constant ALLOWANCE_TYPE_HASH = keccak256("Allowance(address account,bytes32[] assets,uint48 validUntil,uint48 validAfter,uint48 salt,address operator,bytes metadata)");
