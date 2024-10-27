// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {ETH, WithdrawRequest, ClaimRequest, ClaimStruct, CallStruct} from "./../src/base/Helpers.sol";
import {LiquidityManager} from "./../src/base/LiquidityManager.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import {ForceReverter} from "./utils/ForceReverter.sol";

import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {MagicSpendLiquidityManager} from "./../src/MagicSpendLiquidityManager.sol";


contract MagicSpendLiquidityManagerTest is Test {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 chainId = 111;
    uint128 amount = 5 ether;
    uint128 fee = 0;

    address signer;
    uint256 signerKey;

    ForceReverter forceReverter;
    MagicSpendLiquidityManager magicSpendLiquidityManager;
    TestERC20 token;

    function setUp() external {
        (signer, signerKey) = makeAddrAndKey("signer");

        magicSpendLiquidityManager = new MagicSpendLiquidityManager(OWNER, signer);

        token = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(OWNER, 100 ether);

        vm.prank(OWNER);
        token.sudoMint(OWNER, 100 ether);
        vm.prank(OWNER);
        token.approve(address(magicSpendLiquidityManager), 100 ether);
    }

    function testWithdrawNativeTokenSuccess() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        vm.chainId(chainId);

        vm.expectEmit(address(magicSpendLiquidityManager));
        emit MagicSpendLiquidityManager.RequestWithdrawn(
            magicSpendLiquidityManager.getWithdrawRequestHash(request),
            request.recipient,
            request.asset,
            request.amount
        );

        magicSpendLiquidityManager.withdraw(
            request,
            signWithdrawRequest(request, signerKey)
        );
        vm.assertEq(RECIPIENT.balance, 5 ether, "Withdrawn funds should go to recipient");
    }

    function testWithdrawERC20TokenSuccess() external {
        address asset = address(token);

        _addLiquidity(asset, amount);

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        vm.chainId(chainId);

        vm.expectEmit(address(magicSpendLiquidityManager));
        emit MagicSpendLiquidityManager.RequestWithdrawn(
            magicSpendLiquidityManager.getWithdrawRequestHash(request),
            request.recipient,
            request.asset,
            request.amount
        );

        magicSpendLiquidityManager.withdraw(
            request,
            signWithdrawRequest(request, signerKey)
        );
        vm.assertEq(token.balanceOf(RECIPIENT), 5 ether, "Withdrawn funds should go to recipient");
    }

    function test_RevertWhen_ValidUntilInvalid() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        uint48 testValidUntil = uint48(block.timestamp + 5);

        vm.warp(500);
        vm.chainId(chainId);

        WithdrawRequest memory request = WithdrawRequest({
            validUntil: testValidUntil,

            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        // should throw if withdraw request was sent pass expiry.
        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.RequestExpired.selector));

        magicSpendLiquidityManager.withdraw(
            request,
            signature
        );
    }

    function test_RevertWhen_ValidAfterInvalid() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        uint48 testValidAfter = 4096;

        vm.warp(500);
        vm.chainId(chainId);

        WithdrawRequest memory request = WithdrawRequest({
            validAfter: testValidAfter,

            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        // should throw if withdraw request was sent too early.
        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.RequestNotYetValid.selector));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    function test_RevertWhen_AccountSignatureInvalid() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        (, uint256 unauthorizedSingerKey) = makeAddrAndKey("unauthorizedSinger");

        vm.chainId(chainId);

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawRequest(request, unauthorizedSingerKey);

        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.SignatureInvalid.selector));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    function test_RevertWhen_RequestWithdrawnTwice() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        vm.chainId(chainId);

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        vm.expectEmit(address(magicSpendLiquidityManager));

        emit MagicSpendLiquidityManager.RequestWithdrawn(
            magicSpendLiquidityManager.getWithdrawRequestHash(request),
            request.recipient,
            request.asset,
            request.amount
        );

        magicSpendLiquidityManager.withdraw(request, signature);

        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.AlreadyUsed.selector));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    function test_RevertWhen_WithdrawRequestTransferFailed() external {
        address asset = ETH;

        vm.chainId(chainId);

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        // should throw when ETH withdraw request could not be fulfilled due to insufficient funds.
        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.ETHTransferFailed.selector));
        magicSpendLiquidityManager.withdraw(request, signature);

        // should throw when ERC20 withdraw request could not be fulfilled due to insufficient funds.
        request.asset = address(token);
        signature = signWithdrawRequest(request, signerKey);

        vm.expectRevert(abi.encodeWithSelector(SafeTransferLib.TransferFailed.selector));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    function test_RevertWhen_PreCallReverts() external {
        address asset = ETH;

        _addLiquidity(asset, amount);
        vm.chainId(chainId);

        string memory revertMessage = "MAGIC";

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](1),
            postCalls: new CallStruct[](0),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        // force a revert by calling non existant function
        request.preCalls[0] = CallStruct({
            to: address(forceReverter),
            data: abi.encodeWithSignature("forceRevertWithMessage(string)", revertMessage),
            value: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        bytes memory revertBytes = abi.encodeWithSelector(ForceReverter.RevertWithMsg.selector, revertMessage);
        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.PreCallReverted.selector, revertBytes));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    function test_RevertWhen_PostCallReverts() external {
        address asset = ETH;

        _addLiquidity(asset, amount);

        vm.chainId(chainId);

        string memory revertMessage = "MAGIC";

        WithdrawRequest memory request = WithdrawRequest({
            chainId: chainId,
            amount: amount,
            asset: asset,
            recipient: RECIPIENT,
            preCalls: new CallStruct[](0),
            postCalls: new CallStruct[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        // force a revert by calling non existant function
        request.postCalls[0] = CallStruct({
            to: address(forceReverter),
            data: abi.encodeWithSignature("forceRevertWithMessage(string)", revertMessage),
            value: 0
        });

        bytes memory signature = signWithdrawRequest(request, signerKey);

        bytes memory revertBytes = abi.encodeWithSelector(ForceReverter.RevertWithMsg.selector, revertMessage);
        vm.expectRevert(abi.encodeWithSelector(MagicSpendLiquidityManager.PostCallReverted.selector, revertBytes));
        magicSpendLiquidityManager.withdraw(request, signature);
    }

    // // = = = Helpers = = =

    function signWithdrawRequest(WithdrawRequest memory request, uint256 signingKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash_ = magicSpendLiquidityManager.getWithdrawRequestHash(request);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signingKey,
            hash_
        );

        return abi.encodePacked(r, s, v);
    }

    function _addLiquidity(
        address asset,
        uint128 amount_
    ) internal {
        vm.prank(OWNER);

        magicSpendLiquidityManager.addLiquidity{
            value: asset == ETH ? amount_ : 0
        }(asset, amount_);

        vm.stopPrank();
    }
}
