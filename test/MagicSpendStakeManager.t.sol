// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {ETH, WithdrawRequest, ClaimRequest, ClaimStruct, CallStruct} from "./../src/base/Helpers.sol";
import {LiquidityManager} from "./../src/base/LiquidityManager.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import {ForceReverter} from "./utils/ForceReverter.sol";

import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {MagicSpendStakeManager} from "./../src/MagicSpendStakeManager.sol";


contract MagicSpendStakeManagerTest is Test {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 chainId = 999;
    uint128 amount = 5 ether;
    uint128 fee = 0;

    address alice;
    uint256 aliceKey;

    ForceReverter forceReverter;
    MagicSpendStakeManager magicSpendStakeManager;
    TestERC20 token;

    function setUp() external {
        (alice, aliceKey) = makeAddrAndKey("alice");

        magicSpendStakeManager = new MagicSpendStakeManager(OWNER);

        token = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(alice, 100 ether);

        vm.prank(OWNER);
        token.sudoMint(alice, 100 ether);

        vm.prank(alice);
        token.approve(address(magicSpendStakeManager), 100 ether);
    }

    function test_ClaimNativeTokenSuccess() external {
        address asset = ETH;

        _addStake(asset, amount + fee);

        ClaimRequest memory request = ClaimRequest({
            claims: new ClaimStruct[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        request.claims[0] = ClaimStruct({
            asset: asset,
            amount: amount,
            fee: fee,
            chainId: chainId
        });

        vm.chainId(chainId);

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
            0,
            amount + fee
        );
        vm.assertEq(
            magicSpendStakeManager.stakeOf(alice, asset),
            0 ether,
            "Alice should lose her stake after claim"
        );
    }

    function test_ClaimERC20TokenSuccess() external {
        address asset = address(token);

        _addStake(asset, amount + fee);

        ClaimRequest memory request = ClaimRequest({
            claims: new ClaimStruct[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0
        });

        request.claims[0] = ClaimStruct({
            asset: asset,
            amount: amount,
            fee: fee,
            chainId: chainId
        });

        vm.chainId(chainId);

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
            0,
            amount + fee
        );

        vm.assertEq(
            magicSpendStakeManager.stakeOf(alice, asset),
            0 ether,
            "Alice should lose her stake after claim"
        );
    }

    // // = = = Helpers = = =

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
