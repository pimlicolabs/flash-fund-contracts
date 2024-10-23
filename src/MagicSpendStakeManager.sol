// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin-5.0.2/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin-5.0.2/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin-5.0.2/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin-5.0.2/contracts/access/Ownable.sol";

import {StakeManager} from "./base/StakeManager.sol";
import {ETH, ClaimRequest, ClaimStruct} from "./base/Helpers.sol";

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";


/// @title MagicSpendStakeManager
/// @author Pimlico (https://github.com/pimlicolabs/magic-spend)
/// @notice Contract that allows users to stake their funds.
/// @dev Inherits from Ownable.
/// @custom:security-contact security@pimlico.io
contract MagicSpendStakeManager is Ownable, StakeManager {
    /// @notice Thrown when the request was submitted with an invalid chain id.
    error RequestInvalidChain();

    /// @notice Thrown when the request was submitted past its validUntil.
    error RequestExpired();

    /// @notice Thrown when the request was submitted before its validAfter.
    error RequestNotYetValid();

    /// @notice The claim request was submitted with an invalid claim id.
    error InvalidClaimId();

    /// @notice The withdraw request was already withdrawn.
    error AlreadyUsed();

    error AmountTooLow();

    error AmountTooHigh();

    /// @notice Emitted when a request has been withdrawn.
    event RequestClaimed(
        bytes32 indexed hash_,
        address indexed account,
        address indexed asset,
        uint256 amount
    );

    event AssetSkimmed(
        address indexed asset,
        uint256 amount
    );

    mapping(bytes32 hash_ => bool) public requestStatuses;
    mapping(address asset => uint128) public claimed;

    constructor(
        address _owner
    ) Ownable(_owner) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function claim(
        ClaimRequest calldata request,
        bytes calldata signature,
        uint8 claimId,
        uint128 amount
    ) external nonReentrant {
        bytes32 hash_ = getClaimRequestHash(request);

        if (requestStatuses[hash_]) {
            revert AlreadyUsed();
        }

        if (request.validUntil != 0 && block.timestamp > request.validUntil) {
            revert RequestExpired();
        }

        if (request.validAfter != 0 && block.timestamp < request.validAfter) {
            revert RequestNotYetValid();
        }

        // Derive the particular claim
        if (request.claims.length <= claimId) {
            revert InvalidClaimId();
        }

        ClaimStruct memory claim_ = request.claims[claimId];

        if (claim_.chainId != block.chainid) {
            revert RequestInvalidChain();
        }

        address account = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(hash_),
            signature
        );

        if (amount > claim_.amount + claim_.fee) {
            revert AmountTooHigh();
        }

        if (amount == 0) {
            revert AmountTooLow();
        }

        _claimStake(
            account,
            claim_.asset,
            amount
        );

        claimed[claim_.asset] += amount;
        requestStatuses[hash_] = true;

        emit RequestClaimed(
            hash_,
            account,
            claim_.asset,
            amount
        );
    }

    function skim(
        address asset
    ) external onlyOwner nonReentrant {
        uint128 amount = claimed[asset];

        if (amount == 0) {
            revert AmountTooLow();
        }

        if (asset == ETH) {
            SafeTransferLib.forceSafeTransferETH(owner(), amount);
        } else {
            SafeTransferLib.safeTransfer(asset, owner(), amount);
        }

        claimed[asset] = 0;

        emit AssetSkimmed(
            asset,
            amount
        );
    }

    function getClaimStructHash(
        ClaimStruct memory claim_
    ) public view returns (bytes32) {
        bytes32 digest = keccak256(
            abi.encode(
                address(this),
                claim_.asset,
                claim_.amount,
                claim_.fee,
                claim_.chainId
            )
        );

        return digest;
    }

    function getClaimRequestHash(
        ClaimRequest memory request
    ) public view returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](request.claims.length);

        for (uint256 i = 0; i < request.claims.length; i++) {
            hashes[i] = getClaimStructHash(request.claims[i]);
        }

        return keccak256(
            abi.encodePacked(
                hashes,
                request.salt,
                request.validUntil,
                request.validAfter
            )
        );
    }
}