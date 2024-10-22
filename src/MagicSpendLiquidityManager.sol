// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import {IERC20} from "@openzeppelin-5.0.2/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin-5.0.2/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin-5.0.2/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin-5.0.2/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin-5.0.2/contracts/utils/ReentrancyGuard.sol";

import {Signer} from "./base/Signer.sol";
import {LiquidityManager} from "./base/LiquidityManager.sol";
import {ETH, WithdrawRequest} from "./base/Helpers.sol";

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";


/// @title MagicSpendLiquidityManager
/// @author Pimlico (https://github.com/pimlicolabs/magic-spend)
/// @notice Contract that allows users to pull funds from if they provide a valid signed request.
/// @dev Inherits from Ownable.
/// @custom:security-contact security@pimlico.io
contract MagicSpendLiquidityManager is Ownable, Signer, LiquidityManager {
    /// @notice Thrown when the request was submitted past its validUntil.
    error RequestExpired();

    /// @notice Thrown when the request was submitted with an invalid chain id.
    error RequestInvalidChain();

    /// @notice Thrown when the request was submitted before its validAfter.
    error RequestNotYetValid();

    /// @notice The withdraw request was initiated with a invalid nonce.
    error SignatureInvalid();

    /// @notice The withdraw request was already withdrawn.
    error AlreadyUsed();

    /// @notice One of the precalls reverted.
    /// @param revertReason The revert bytes.
    error PreCallReverted(bytes revertReason);

    /// @notice One of the postcalls reverted.
    /// @param revertReason The revert bytes.
    error PostCallReverted(bytes revertReason);

    /// @notice Emitted when a request has been withdrawn.
    event RequestWithdrawn(
        bytes32 indexed hash_,
        address indexed recipient,
        address indexed asset,
        uint256 amount
    );

    mapping(bytes32 hash_ => bool) public requestStatuses;

    constructor(
        address _owner,
        address _signer
    ) Ownable(_owner) Signer(_signer) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Fulfills a withdraw request only if it has a valid signature and passes validation.
     * The signature should be signed by the signer.
     */
    function withdraw(
        WithdrawRequest calldata request,
        bytes calldata signature
    ) external nonReentrant {
        if (request.chainId != block.chainid) {
            revert RequestInvalidChain();
        }

        if (request.validUntil != 0 && block.timestamp > request.validUntil) {
            revert RequestExpired();
        }

        if (request.validAfter != 0 && block.timestamp < request.validAfter) {
            revert RequestNotYetValid();
        }

        bytes32 hash_ = getWithdrawRequestHash(request);

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(hash_),
            signature
        );

        if (!_isSigner(signer)) {
            revert SignatureInvalid();
        }

        // check withdraw request params
        if (requestStatuses[hash_]) {
            revert AlreadyUsed();
        }

        // run pre calls
        for (uint256 i = 0; i < request.preCalls.length; i++) {
            address to = request.preCalls[i].to;
            uint256 value = request.preCalls[i].value;
            bytes memory data = request.preCalls[i].data;

            (bool success, bytes memory result) = to.call{value: value}(data);

            if (!success) {
                revert PreCallReverted(result);
            }
        }

        if (request.asset == ETH) {
            SafeTransferLib.forceSafeTransferETH(request.recipient, request.amount);
        } else {
            SafeTransferLib.safeTransfer(request.asset, request.recipient, request.amount);
        }

        // run postcalls
        for (uint256 i = 0; i < request.postCalls.length; i++) {
            address to = request.postCalls[i].to;
            uint256 value = request.postCalls[i].value;
            bytes memory data = request.postCalls[i].data;

            (bool success, bytes memory result) = to.call{value: value}(data);

            if (!success) {
                revert PostCallReverted(result);
            }
        }

        requestStatuses[hash_] = true;

        emit RequestWithdrawn(
            hash_,
            request.recipient,
            request.asset,
            request.amount
        );
    }

    /**
     * @notice Allows the caller to withdraw funds if a valid signature is passed.
     * @dev At time of call, recipient will be equal to msg.sender.
     * @param request The withdraw request to get the hash of.
     * @return The hashed withdraw request.
     */
    function getWithdrawRequestHash(
        WithdrawRequest calldata request
    ) public view returns (bytes32) {
        bytes32 validityDigest = keccak256(
            abi.encode(
                request.validUntil,
                request.validAfter
            )
        );

        bytes32 callsDigest = keccak256(
            abi.encode(
                request.preCalls,
                request.postCalls
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                address(this),
                request.asset,
                request.amount,
                request.chainId,
                request.recipient,
                callsDigest,
                validityDigest,
                request.nonce
            )
        );

        return digest;
    }
}
