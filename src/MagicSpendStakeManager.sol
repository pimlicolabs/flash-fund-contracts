// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin-5.0.2/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin-5.0.2/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin-5.0.2/contracts/utils/math/Math.sol";
import {SignatureChecker} from "@openzeppelin-5.0.2/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712Upgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StakeManager} from "./base/StakeManager.sol";
import {ETH, Allowance, AssetAllowance, ASSET_ALLOWANCE_TYPE_HASH, ALLOWANCE_TYPE_HASH} from "./base/Helpers.sol";

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";

/// @title MagicSpendStakeManager
/// @author Pimlico (https://github.com/pimlicolabs/magic-spend-contracts)
/// @notice Contract that allows users to stake their funds.
/// @custom:security-contact security@pimlico.io
contract MagicSpendStakeManager is StakeManager, OwnableUpgradeable, EIP712Upgradeable {
    /// @notice Thrown when the asset chain id does not match the.
    error AssetAllowanceInvalidChain();

    /// @notice Thrown when the allowance was submitted past its validUntil.
    error AllowanceExpired();

    /// @notice Thrown when the allowance was submitted before its validAfter.
    error AllowanceNotYetValid();

    /// @notice The claim was submitted with an invalid claim id.
    error InvalidAssetAllowanceId();

    /// @notice The allowance was already withdrawn.
    error AlreadyUsed();

    /// @notice The claim or skim was initiated with an amount of 0.
    error AmountTooLow();

    /// @notice The claim was initiated with an amount higher than the allowance.
    error AmountTooHigh();

    /// @notice The claim was initiated with invalid signature (checked against `Allowance.account`).
    error SignatureInvalid();

    /// @notice The claim was initiated with invalid asset ids.
    error InvalidAssetIds();

    /// @notice Emitted when an asset is claimed.
    event AssetClaimed(bytes32 indexed hash_, uint8 indexed assetId, uint256 amount);

    event FeeSkimmed(address indexed token, uint256 amount);

    mapping(bytes32 hash_ => bool) public requestStatuses;
    mapping(address token => uint128) public claimed;

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __EIP712_init("Pimlico Lock", "1");
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function claim(
        Allowance calldata allowance,
        bytes calldata signature,
        uint8[] calldata assetIds,
        uint128[] calldata amounts,
        address treasury
    ) external nonReentrant() {
        if (assetIds.length != amounts.length) {
            revert InvalidAssetIds();
        }

        bytes32 hash_ = getAllowanceHash(allowance);

        if (requestStatuses[hash_]) {
            revert AlreadyUsed();
        }

        if (allowance.validUntil != 0 && block.timestamp > allowance.validUntil) {
            revert AllowanceExpired();
        }

        if (allowance.validAfter != 0 && block.timestamp < allowance.validAfter) {
            revert AllowanceNotYetValid();
        }

        bool signatureValid = SignatureChecker.isValidSignatureNow(
            allowance.account,
            MessageHashUtils.toEthSignedMessageHash(hash_),
            signature
        );

        if (!signatureValid) {
            revert SignatureInvalid();
        }

        for (uint256 i = 0; i < assetIds.length; i++) {
            if (allowance.assets.length <= assetIds[i]) {
                revert InvalidAssetAllowanceId();
            }

            uint128 amount = amounts[i];
            uint8 assetId = assetIds[i];

            AssetAllowance memory asset = allowance.assets[assetId];

            claimAsset(
                asset,
                allowance.account,
                amount,
                treasury
            );

            emit AssetClaimed(
                hash_,
                assetId,
                amount
            );
        }

        requestStatuses[hash_] = true;
    }

    function claimAsset(
        AssetAllowance memory asset,
        address account,
        uint128 amount,
        address treasury
    ) internal {
        if (asset.chainId != block.chainid) {
            revert AssetAllowanceInvalidChain();
        }

        if (amount > asset.amount) {
            revert AmountTooHigh();
        }

        if (amount == 0) {
            revert AmountTooLow();
        }

        address token = asset.token;

        _claimStake(account, token, amount);
        _transfer(token, treasury, amount);
    }

    function getAssetAllowanceHash(AssetAllowance memory asset) public pure returns (bytes32) {
        return keccak256(abi.encode(ASSET_ALLOWANCE_TYPE_HASH, asset.token, asset.amount, asset.chainId));
    }

    function getAllowanceHash(Allowance memory allowance) public view returns (bytes32) {
        bytes32[] memory assetsHashes = new bytes32[](allowance.assets.length);

        for (uint256 i = 0; i < allowance.assets.length; i++) {
            assetsHashes[i] = getAssetAllowanceHash(allowance.assets[i]);
        }

        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ALLOWANCE_TYPE_HASH,
                    allowance.account,
                    keccak256(abi.encodePacked(assetsHashes)),
                    allowance.validUntil,
                    allowance.validAfter,
                    allowance.salt,
                    allowance.operator,
                    allowance.metadata
                )
            )
        );
    }
}
