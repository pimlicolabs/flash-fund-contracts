// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin-5.0.2/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin-5.0.2/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin-5.0.2/contracts/utils/math/Math.sol";
import {OwnableUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SignatureChecker} from "@openzeppelin-5.0.2/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712Upgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Initializable} from "@openzeppelin-5.0.2/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Signer} from "./base/Signer.sol";
import {WithdrawalManager} from "./base/WithdrawalManager.sol";
import {ETH, Withdrawal, Call} from "./base/Helpers.sol";

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";

/// @title MagicSpendWithdrawalManager
/// @author Pimlico (https://github.com/pimlicolabs/magic-spend-contracts)
/// @notice Contract that allows users to pull funds from if they provide a valid signed `Withdrawal`.
/// @dev Inherits from Ownable.
/// @custom:security-contact security@pimlico.io
contract MagicSpendWithdrawalManager is OwnableUpgradeable, Signer, WithdrawalManager, EIP712Upgradeable {
    bytes32 private constant CALL_TYPE_HASH = keccak256("Call(address to,uint256 value,bytes data)");

    bytes32 private constant WITHDRAWAL_TYPE_HASH = keccak256(
        "Withdrawal(address token,uint128 amount,uint128 chainId,address recipient,Call[] preCalls,Call[] postCalls,uint48 validUntil,uint48 validAfter,uint48 salt)"
        "Call(address to,uint256 value,bytes data)"
    );

    /// @notice Thrown when the withdrawal was submitted with an invalid chain id.
    error WithdrawalInvalidChain();

    /// @notice Thrown when the withdrawal was submitted past its validUntil.
    error WithdrawalExpired();

    /// @notice Thrown when the withdrawal was submitted before its validAfter.
    error WithdrawalNotYetValid();

    /// @notice The withdraw withdrawal was initiated with invalid signature.
    error SignatureInvalid();

    /// @notice The withdraw withdrawal was already withdrawn.
    error AlreadyUsed();

    /// @notice One of the precalls reverted.
    /// @param revertReason The revert bytes.
    error PreCallReverted(bytes revertReason);

    /// @notice One of the postcalls reverted.
    /// @param revertReason The revert bytes.
    error PostCallReverted(bytes revertReason);

    /// @notice Emitted when a withdrawal has been withdrawn.
    event WithdrawalExecuted(bytes32 indexed hash_, address indexed recipient, address indexed token, uint256 amount);

    mapping(bytes32 hash_ => bool) public requestStatuses;

    function initialize(address _owner, address _signer) external initializer {
        __Ownable_init(_owner);
        __Signer_init(_signer);
        __EIP712_init("Pimlico MagicSpend++", "1");
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Fulfills a withdrawal only if it has a valid signature and passes validation.
     */
    function withdraw(Withdrawal calldata withdrawal, bytes calldata signature) external nonReentrant {
        if (withdrawal.chainId != block.chainid) {
            revert WithdrawalInvalidChain();
        }

        if (withdrawal.validUntil != 0 && block.timestamp > withdrawal.validUntil) {
            revert WithdrawalExpired();
        }

        if (withdrawal.validAfter != 0 && block.timestamp < withdrawal.validAfter) {
            revert WithdrawalNotYetValid();
        }

        bytes32 hash_ = getWithdrawalHash(withdrawal);

        bool signatureValid = SignatureChecker.isValidSignatureNow(getSigner(), hash_, signature);

        if (!signatureValid) {
            revert SignatureInvalid();
        }

        if (requestStatuses[hash_]) {
            revert AlreadyUsed();
        }

        // run pre calls
        for (uint256 i = 0; i < withdrawal.preCalls.length; i++) {
            address to = withdrawal.preCalls[i].to;
            uint256 value = withdrawal.preCalls[i].value;
            bytes memory data = withdrawal.preCalls[i].data;

            (bool success, bytes memory result) = to.call{value: value}(data);

            if (!success) {
                revert PreCallReverted(result);
            }
        }

        address token = withdrawal.token;
        address recipient = withdrawal.recipient;
        uint128 amount = withdrawal.amount;

        if (token == ETH) {
            SafeTransferLib.forceSafeTransferETH(recipient, amount);
        } else {
            SafeTransferLib.safeTransfer(token, recipient, amount);
        }

        // run postcalls
        for (uint256 i = 0; i < withdrawal.postCalls.length; i++) {
            address to = withdrawal.postCalls[i].to;
            uint256 value = withdrawal.postCalls[i].value;
            bytes memory data = withdrawal.postCalls[i].data;

            (bool success, bytes memory result) = to.call{value: value}(data);

            if (!success) {
                revert PostCallReverted(result);
            }
        }

        requestStatuses[hash_] = true;

        emit WithdrawalExecuted(hash_, recipient, token, amount);
    }

    function getCallHash(Call calldata call) public pure returns (bytes32) {
        return keccak256(abi.encode(CALL_TYPE_HASH, call.to, call.value, keccak256(call.data)));
    }

    function getWithdrawalHash(Withdrawal calldata withdrawal) public view returns (bytes32) {
        bytes32[] memory preCallHashes = new bytes32[](withdrawal.preCalls.length);
        bytes32[] memory postCallHashes = new bytes32[](withdrawal.postCalls.length);

        for (uint256 i = 0; i < withdrawal.preCalls.length; i++) {
            preCallHashes[i] = getCallHash(withdrawal.preCalls[i]);
        }

        for (uint256 i = 0; i < withdrawal.postCalls.length; i++) {
            postCallHashes[i] = getCallHash(withdrawal.postCalls[i]);
        }

        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WITHDRAWAL_TYPE_HASH,
                    withdrawal.token,
                    withdrawal.amount,
                    withdrawal.chainId,
                    withdrawal.recipient,
                    keccak256(abi.encodePacked(preCallHashes)),
                    keccak256(abi.encodePacked(postCallHashes)),
                    withdrawal.validUntil,
                    withdrawal.validAfter,
                    withdrawal.salt
                )
            )
        );
    }
}
