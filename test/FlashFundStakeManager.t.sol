// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";

import {ETH, Allowance, AssetAllowance} from "./../src/base/Helpers.sol";
import {WithdrawalManager} from "./../src/base/WithdrawalManager.sol";
import {TestERC20} from "./utils/TestERC20.sol";
import {ForceReverter} from "./utils/ForceReverter.sol";

import {MessageHashUtils} from "@openzeppelin-5.0.2/contracts/utils/cryptography/MessageHashUtils.sol";
import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {FlashFundStakeManager} from "./../src/FlashFundStakeManager.sol";
import {FlashFundFactory} from "./../src/FlashFundFactory.sol";

import {Options} from "@openzeppelin-0.3.6/foundry-upgrades/Options.sol";
import {Deploy} from "./../src/libraries/Deploy.sol";
contract FlashFundStakeManagerTest is Test, FlashFundFactory {
    address immutable OWNER = makeAddr("owner");
    address immutable RECIPIENT = makeAddr("recipient");

    uint128 chainId = 999;
    uint128 amount = 5 ether;
    uint128 fee = 0;

    address alice;
    uint256 aliceKey;

    address treasury;

    ForceReverter forceReverter;
    FlashFundStakeManager flashFundStakeManager;
    TestERC20 erc20;

    function setUp() external {
        (alice, aliceKey) = makeAddrAndKey("alice");
        treasury = makeAddr("treasury");

        Options memory opts = Deploy.getOptions(0);

        flashFundStakeManager = deployStakeManager(OWNER, opts);

        erc20 = new TestERC20(18);
        forceReverter = new ForceReverter();

        vm.deal(alice, 100 ether);

        vm.prank(OWNER);
        erc20.sudoMint(alice, 100 ether);

        vm.prank(alice);
        erc20.approve(address(flashFundStakeManager), 100 ether);
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
            version: 0,
            metadata: abi.encode("test")
        });

        allowance.assets[0] = AssetAllowance({token: token, amount: amount, chainId: chainId});

        vm.chainId(chainId);

        bytes memory signature = signAllowance(allowance, aliceKey);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.expectEmit(address(flashFundStakeManager));
        emit FlashFundStakeManager.AssetClaimed(
            flashFundStakeManager.getAllowanceHash(allowance), 0, amount
        );

        uint8[] memory assetIds = new uint8[](1);
        assetIds[0] = 0;

        uint128[] memory amounts = new uint128[](1);
        amounts[0] = amount + fee;

        vm.prank(OWNER);
        flashFundStakeManager.claim(
            allowance,
            signature,
            assetIds,
            amounts,
            treasury
        );

        vm.assertEq(flashFundStakeManager.stakeOf(alice, token), 0 ether, "Alice should lose her stake after claim");
        vm.assertEq(treasury.balance, treasuryBalanceBefore + amount + fee, "Treasury should receive the claimed amount");
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
            version: 0,
            metadata: abi.encode("test")
        });

        allowance.assets[0] = AssetAllowance({token: token, amount: amount, chainId: chainId});

        vm.chainId(chainId);

        bytes memory signature = signAllowance(allowance, aliceKey);

        uint256 treasuryBalanceBefore = erc20.balanceOf(treasury);

        vm.expectEmit(address(flashFundStakeManager));
        emit FlashFundStakeManager.AssetClaimed(
            flashFundStakeManager.getAllowanceHash(allowance), 0, amount
        );

        uint8[] memory assetIds = new uint8[](1);
        assetIds[0] = 0;

        uint128[] memory amounts = new uint128[](1);
        amounts[0] = amount + fee;

        vm.prank(OWNER);
        flashFundStakeManager.claim(
            allowance,
            signature,
            assetIds,
            amounts,
            treasury
        );

        vm.assertEq(flashFundStakeManager.stakeOf(alice, token), 0 ether, "Alice should lose her stake after claim");
        vm.assertEq(erc20.balanceOf(treasury), treasuryBalanceBefore + amount + fee, "Treasury should receive the claimed amount");
    }

    function test_AllowanceHashChainAgnostic() external {
        Allowance memory allowance = Allowance({
            account: alice,
            assets: new AssetAllowance[](1),
            validUntil: 0,
            validAfter: 0,
            salt: 0,
            version: 0,
            metadata: abi.encode("test")
        });

        vm.chainId(1);
        bytes32 hash_1 = flashFundStakeManager.getAllowanceHash(allowance);

        vm.chainId(2);
        bytes32 hash_2 = flashFundStakeManager.getAllowanceHash(allowance);

        vm.assertEq(hash_1, hash_2, "Hash should be the same for different chainId");
    }

    // // = = = Helpers = = =

    function signAllowance(Allowance memory allowance, uint256 signingKey)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 hash_ = flashFundStakeManager.getAllowanceHash(allowance);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, hash_);

        return abi.encodePacked(r, s, v);
    }

    function _addStake(address token, uint128 amount_) internal {
        vm.prank(alice);

        flashFundStakeManager.addStake{value: token == ETH ? amount_ : 0}(token, amount_, 1, alice);

        vm.stopPrank();
    }
}
