// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {ETH, Withdrawal, Call} from "./../src/base/Helpers.sol";
import {WithdrawalManager} from "./../src/base/WithdrawalManager.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import {ForceReverter} from "./utils/ForceReverter.sol";

import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {FlashFundWithdrawalManager} from "./../src/FlashFundWithdrawalManager.sol";
import {FlashFundFactory} from "./../src/FlashFundFactory.sol";
import {Options} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";
import {Deploy} from "./../src/libraries/Deploy.sol";

contract FlashFundLiquidityManagerTest is Test, FlashFundFactory {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 chainId = 111;
    uint128 amount = 5 ether;
    uint128 fee = 0;

    address signer;
    uint256 signerKey;

    ForceReverter forceReverter;
    FlashFundWithdrawalManager flashFundWithdrawalManager;
    TestERC20 erc20;

    function setUp() external {
        (signer, signerKey) = makeAddrAndKey("signer");

        Options memory opts = Deploy.getOptions(0);

        flashFundWithdrawalManager = deployWithdrawalManager(OWNER, signer, opts);

        erc20 = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(OWNER, 100 ether);

        vm.prank(OWNER);
        erc20.sudoMint(OWNER, 100 ether);
        vm.prank(OWNER);
        erc20.approve(address(flashFundWithdrawalManager), 100 ether);
    }

    function testWithdrawNativeTokenSuccess() external {
        address token = ETH;

        _addLiquidity(token, amount);

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        vm.chainId(chainId);

        vm.expectEmit(address(flashFundWithdrawalManager));
        emit FlashFundWithdrawalManager.WithdrawalExecuted(
            flashFundWithdrawalManager.getWithdrawalHash(withdrawal),
            withdrawal.recipient,
            withdrawal.token,
            withdrawal.amount
        );

        flashFundWithdrawalManager.withdraw(withdrawal, signWithdrawal(withdrawal, signerKey));
        vm.assertEq(RECIPIENT.balance, 5 ether, "Withdrawn funds should go to recipient");
    }

    function testWithdrawERC20TokenSuccess() external {
        address token = address(erc20);

        _addLiquidity(token, amount);

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        vm.chainId(chainId);

        vm.expectEmit(address(flashFundWithdrawalManager));
        emit FlashFundWithdrawalManager.WithdrawalExecuted(
            flashFundWithdrawalManager.getWithdrawalHash(withdrawal),
            withdrawal.recipient,
            withdrawal.token,
            withdrawal.amount
        );

        flashFundWithdrawalManager.withdraw(withdrawal, signWithdrawal(withdrawal, signerKey));
        vm.assertEq(erc20.balanceOf(RECIPIENT), 5 ether, "Withdrawn funds should go to recipient");
    }

    function test_RevertWhen_ValidUntilInvalid() external {
        address token = ETH;

        _addLiquidity(token, amount);

        uint48 testValidUntil = uint48(block.timestamp + 5);

        vm.warp(500);
        vm.chainId(chainId);

        Withdrawal memory withdrawal = Withdrawal({
            validUntil: testValidUntil,
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        // should throw if withdrawal was sent pass expiry.
        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.WithdrawalExpired.selector));

        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_ValidAfterInvalid() external {
        address token = ETH;

        _addLiquidity(token, amount);

        uint48 testValidAfter = 4096;

        vm.warp(500);
        vm.chainId(chainId);

        Withdrawal memory withdrawal = Withdrawal({
            validAfter: testValidAfter,
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        // should throw if withdrawal was sent too early.
        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.WithdrawalNotYetValid.selector));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_AccountSignatureInvalid() external {
        address token = ETH;

        _addLiquidity(token, amount);

        (, uint256 unauthorizedSingerKey) = makeAddrAndKey("unauthorizedSinger");

        vm.chainId(chainId);

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, unauthorizedSingerKey);

        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.SignatureInvalid.selector));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_RequestWithdrawnTwice() external {
        address token = ETH;

        _addLiquidity(token, amount);

        vm.chainId(chainId);

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        vm.expectEmit(address(flashFundWithdrawalManager));

        emit FlashFundWithdrawalManager.WithdrawalExecuted(
            flashFundWithdrawalManager.getWithdrawalHash(withdrawal),
            withdrawal.recipient,
            withdrawal.token,
            withdrawal.amount
        );

        flashFundWithdrawalManager.withdraw(withdrawal, signature);

        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.AlreadyUsed.selector));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_WithdrawalTransferFailed() external {
        address token = ETH;

        vm.chainId(chainId);

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        // should throw when withdrawal ETH could not be fulfilled due to insufficient funds.
        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);

        // should throw when withdrawal ERC20 could not be fulfilled due to insufficient funds.
        withdrawal.token = address(erc20);
        signature = signWithdrawal(withdrawal, signerKey);

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.TransferFailed.selector));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_PreCallReverts() external {
        address token = ETH;

        _addLiquidity(token, amount);
        vm.chainId(chainId);

        string memory revertMessage = "MAGIC";

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](1),
            postCalls: new Call[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        // force a revert by calling non existant function
        withdrawal.preCalls[0] = Call({
            to: address(forceReverter),
            data: abi.encodeWithSignature("forceRevertWithMessage(string)", revertMessage),
            value: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        bytes memory revertBytes = abi.encodeWithSelector(ForceReverter.RevertWithMsg.selector, revertMessage);
        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.PreCallReverted.selector, revertBytes));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    function test_RevertWhen_PostCallReverts() external {
        address token = ETH;

        _addLiquidity(token, amount);

        vm.chainId(chainId);

        string memory revertMessage = "MAGIC";

        Withdrawal memory withdrawal = Withdrawal({
            chainId: chainId,
            amount: amount,
            token: token,
            recipient: RECIPIENT,
            preCalls: new Call[](0),
            postCalls: new Call[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        // force a revert by calling non existant function
        withdrawal.postCalls[0] = Call({
            to: address(forceReverter),
            data: abi.encodeWithSignature("forceRevertWithMessage(string)", revertMessage),
            value: 0
        });

        bytes memory signature = signWithdrawal(withdrawal, signerKey);

        bytes memory revertBytes = abi.encodeWithSelector(ForceReverter.RevertWithMsg.selector, revertMessage);
        vm.expectRevert(abi.encodeWithSelector(FlashFundWithdrawalManager.PostCallReverted.selector, revertBytes));
        flashFundWithdrawalManager.withdraw(withdrawal, signature);
    }

    // // = = = Helpers = = =

    function signWithdrawal(Withdrawal memory withdrawal, uint256 signingKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash_ = flashFundWithdrawalManager.getWithdrawalHash(withdrawal);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, hash_);

        return abi.encodePacked(r, s, v);
    }

    function _addLiquidity(address token, uint128 amount_) internal {
        vm.prank(OWNER);

        flashFundWithdrawalManager.addLiquidity{value: token == ETH ? amount_ : 0}(token, amount_);

        vm.stopPrank();
    }
}
