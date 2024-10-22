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
import {MagicSpendStakeManager} from "./../src/MagicSpendStakeManager.sol";


contract MagicSpendStakeManagerTest is Test {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 withdrawChainId = 111;
    uint128 claimChainId = 999;

    uint128 amount = 5 ether;
    uint128 fee = 0;

    address signer;
    uint256 signerKey;

    address alice;
    uint256 aliceKey;

    ForceReverter forceReverter;
    MagicSpendLiquidityManager magicSpendLiquidityManager;
    MagicSpendStakeManager magicSpendStakeManager;
    TestERC20 token;

    function setUp() external {
        (signer, signerKey) = makeAddrAndKey("signer");
        (alice, aliceKey) = makeAddrAndKey("alice");

        magicSpendLiquidityManager = new MagicSpendLiquidityManager(OWNER, signer);
        magicSpendStakeManager = new MagicSpendStakeManager(OWNER);

        token = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(OWNER, 100 ether);
        vm.deal(alice, 100 ether);

        vm.prank(OWNER);
        token.sudoMint(OWNER, 100 ether);
        token.sudoMint(alice, 100 ether);

        vm.prank(OWNER);
        token.approve(address(magicSpendStakeManager), 100 ether);
        vm.prank(OWNER);
        token.approve(address(magicSpendLiquidityManager), 100 ether);

        vm.prank(alice);
        token.approve(address(magicSpendStakeManager), 100 ether);
        vm.prank(alice);
        token.approve(address(magicSpendLiquidityManager), 100 ether);
    }

    function testClaimNativeTokenSuccess() external {
        address asset = ETH;

        _addStake(asset, amount + fee);

        ClaimRequest memory request = ClaimRequest({
            claims: new ClaimStruct[](1)
        });

        request.claims[0] = ClaimStruct({
            asset: asset,
            amount: amount,
            fee: fee,
            chainId: claimChainId,
            nonce: 0
        });

        vm.chainId(claimChainId);

        bytes memory signature = signClaimRequest(request, aliceKey);

        vm.expectEmit(address(magicSpendStakeManager));
        emit MagicSpendStakeManager.RequestClaimed(
            magicSpendStakeManager.getClaimRequestHash(request),
            alice,
            asset,
            amount
        );

        magicSpendStakeManager.claim(
            request,
            signature,
            0
        );
        vm.assertEq(
            magicSpendStakeManager.stakeOf(alice, asset),
            0 ether,
            "Alice should lose her stake after claim"
        );
    }

    function testClaimERC20TokenSuccess() external {
        address asset = address(token);

        _addStake(asset, amount + fee);

        ClaimRequest memory request = ClaimRequest({
            claims: new ClaimStruct[](1)
        });

        request.claims[0] = ClaimStruct({
            asset: asset,
            amount: amount,
            fee: fee,
            chainId: claimChainId,
            nonce: 0
        });

        vm.chainId(claimChainId);

        bytes memory signature = signClaimRequest(request, aliceKey);

        vm.expectEmit(address(magicSpendStakeManager));
        emit MagicSpendStakeManager.RequestClaimed(
            magicSpendStakeManager.getClaimRequestHash(request),
            alice,
            asset,
            amount
        );

        magicSpendStakeManager.claim(
            request,
            signature,
            0
        );

        vm.assertEq(
            magicSpendStakeManager.stakeOf(alice, asset),
            0 ether,
            "Alice should lose her stake after claim"
        );
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
            MessageHashUtils.toEthSignedMessageHash(hash_)
        );

        return abi.encodePacked(r, s, v);
    }

    function signClaimRequest(ClaimRequest memory request, uint256 signingKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash_ = magicSpendStakeManager.getClaimRequestHash(request);   

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signingKey,
            MessageHashUtils.toEthSignedMessageHash(hash_)
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

    function _addStake(
        address asset,
        uint128 amount_
    ) internal {
        vm.prank(alice);

        magicSpendStakeManager.addStake{
            value: asset == ETH ? amount_ : 0
        }(asset, amount_, 1);

        vm.stopPrank();
    }
}
