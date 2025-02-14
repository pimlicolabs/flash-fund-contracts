// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {ETH, Allowance, AssetAllowance} from "./../src/base/Helpers.sol";
import {WithdrawalManager} from "./../src/base/WithdrawalManager.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import {ForceReverter} from "./utils/ForceReverter.sol";

import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {MagicSpendStakeManager} from "./../src/MagicSpendStakeManager.sol";
import {MagicSpendFactory} from "./../src/MagicSpendFactory.sol";

contract MagicSpendStakeManagerTest is Test, MagicSpendFactory {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 chainId = 999;
    uint128 amount = 5 ether;
    uint128 fee = 0;

    address alice;
    uint256 aliceKey;

    address treasury;

    ForceReverter forceReverter;
    MagicSpendStakeManager magicSpendStakeManager;
    TestERC20 erc20;

    function setUp() external {
        (alice, aliceKey) = makeAddrAndKey("alice");
        treasury = makeAddr("treasury");

        magicSpendStakeManager = deployStakeManager(OWNER);

        erc20 = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(alice, 100 ether);

        vm.prank(OWNER);
        erc20.sudoMint(alice, 100 ether);

        vm.prank(alice);
        erc20.approve(address(magicSpendStakeManager), 100 ether);
    }

    function test_ClaimNativeTokenSuccess() external {
        address token = ETH;

        _addStake(token, amount + fee);

        Allowance memory allowance = Allowance({
            account: alice,
            assets: new AssetAllowance[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0,
            operator: alice,
            metadata: abi.encode("test")
        });

        allowance.assets[0] = AssetAllowance({token: token, amount: amount, chainId: chainId});

        vm.chainId(chainId);

        bytes memory signature = signAllowance(allowance, aliceKey);

        vm.expectEmit(address(magicSpendStakeManager));
        emit MagicSpendStakeManager.AllowanceClaimed(
            magicSpendStakeManager.getAllowanceHash(allowance), alice, token, amount
        );

        magicSpendStakeManager.claim(allowance, signature, 0, amount + fee, treasury);
        vm.assertEq(magicSpendStakeManager.stakeOf(alice, token), 0 ether, "Alice should lose her stake after claim");
    }

    function test_ClaimERC20TokenSuccess() external {
        address token = address(erc20);

        _addStake(token, amount + fee);

        Allowance memory allowance = Allowance({
            account: alice,
            assets: new AssetAllowance[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0,
            operator: alice,
            metadata: abi.encode("test")
        });

        allowance.assets[0] = AssetAllowance({token: token, amount: amount, chainId: chainId});

        vm.chainId(chainId);

        bytes memory signature = signAllowance(allowance, aliceKey);

        vm.expectEmit(address(magicSpendStakeManager));
        emit MagicSpendStakeManager.AllowanceClaimed(
            magicSpendStakeManager.getAllowanceHash(allowance), alice, token, amount
        );

        magicSpendStakeManager.claim(allowance, signature, 0, amount + fee, treasury);

        vm.assertEq(magicSpendStakeManager.stakeOf(alice, token), 0 ether, "Alice should lose her stake after claim");
    }

    // // = = = Helpers = = =

    function signAllowance(Allowance memory allowance, uint256 signingKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash_ = magicSpendStakeManager.getAllowanceHash(allowance);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, MessageHashUtils.toEthSignedMessageHash(hash_));

        return abi.encodePacked(r, s, v);
    }

    function _addStake(address token, uint128 amount_) internal {
        vm.prank(alice);

        magicSpendStakeManager.addStake{value: token == ETH ? amount_ : 0}(token, amount_, 1);

        vm.stopPrank();
    }
}
