// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.23;

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@openzeppelin-5.0.2/contracts/utils/ReentrancyGuard.sol";
import {ETH} from "./Helpers.sol";

/* solhint-disable avoid-low-level-calls */
/* solhint-disable not-rely-on-time */


/**
 * Manages stakes.
 * Stakes are locked for a period of time.
 * Stakes can be added, claimed, and removed.
 * - To add stake, call `addStake` with the asset and amount.
 * - Stake is claimed every time `MagicSpendPlusMinusHalf.claim` is called
 * - To remove stake, call `removeStake` with the asset and recipient. No partical unstakes are allowed.
 */
abstract contract StakeManager is ReentrancyGuard {
    error InvalidUnstakeDelay();
    error StakeTooLow();
    error StakeTooHigh();
    error StakeAlreadyUnlocked();
    error StakeIsLocked();
    error InsufficientFunds();

    /// Emitted when a stake is added
    event StakeLocked(address indexed account, address indexed asset, uint256 amount, uint256 unstakeDelaySec);

    /// Emitted when a stake is unlocked (starts the unstake process)
    event StakeUnlocked(address indexed account, address indexed asset, uint256 withdrawTime);

    /// Emitted when a stake is withdrawn
    event StakeWithdrawn(address indexed account, address indexed asset, uint256 amount);

    /// Emitted when a stake is claimed
    event StakeClaimed(address indexed account, address indexed asset, uint256 amount);

    /**
     * @param stake           - Actual amount of ether staked for this entity.
     * @param unstakeTime    - First block timestamp where 'unstake' will be callable.
     */
    struct StakeInfo {
        uint128 amount; // The amount of staked asset
        uint32 unstakeDelaySec; // The delay required before the stake can be withdrawn
        uint48 withdrawTime; // Timestamp when the user can withdraw their assets (after unlocking)
        bool staked; // Indicates if the asset is currently staked
    }

    /// maps account to asset to stake
    mapping(address => mapping(address => StakeInfo)) private stakes;

    uint32 public constant ONE_DAY = 60 * 60 * 24;

    function getStakeInfo(
        address account,
        address asset
    ) public view returns (StakeInfo memory info) {
        return stakes[account][asset];
    }

    function stakeOf(address account, address asset) public view returns (uint128) {
        return stakes[account][asset].amount;
    }

    receive() external payable {
        addStake(ETH, uint128(msg.value), ONE_DAY);
    }

    /**
     * Add to the account's stake - amount and delay
     * any pending unstake is first cancelled.
     * @param unstakeDelaySec The new lock duration before the deposit can be withdrawn.
     */
    function addStake(
        address asset,
        uint128 amount,
        uint32 unstakeDelaySec
    ) public nonReentrant payable {
        StakeInfo storage stakeInfo = stakes[msg.sender][asset];

        if (unstakeDelaySec == 0 || unstakeDelaySec > ONE_DAY) {
            revert InvalidUnstakeDelay();
        }

        uint128 stake = stakeInfo.amount + amount;

        if (stake == 0) {
            revert StakeTooLow();
        }

        stakeInfo.amount += amount;
        stakeInfo.unstakeDelaySec = unstakeDelaySec;
        stakeInfo.staked = true;
        stakeInfo.withdrawTime = 0; // Reset withdraw time if already staking

        if (asset == ETH) {
            if (msg.value != amount) {
                revert InsufficientFunds();
            }
        } else {
            SafeTransferLib.safeTransferFrom(asset, msg.sender, address(this), amount);
        }

        emit StakeLocked(
            msg.sender,
            asset,
            amount,
            unstakeDelaySec
        );
    }

    /**
     * Unlocks the stake, starting the withdrawal process.
     * Users must wait for the unstake delay to pass before withdrawing their assets.
     * @param asset - The address of the asset being unstaked
     */
    function unlockStake(address asset) external {
        StakeInfo storage stakeInfo = stakes[msg.sender][asset];

        if (stakeInfo.withdrawTime > 0) {
            revert StakeAlreadyUnlocked();
        }

        // require(stakeInfo.staked, "No active stake");

        uint48 withdrawTime = uint48(block.timestamp) + stakeInfo.unstakeDelaySec;
        stakeInfo.withdrawTime = withdrawTime;
        stakeInfo.staked = false; // Mark as unstaking

        emit StakeUnlocked(msg.sender, asset, withdrawTime);
    }

    /**
     * Withdraws the staked assets after the unstake delay has passed.
     * Must first call `unlockStake` and wait for the delay to pass.
     * @param asset - The address of the asset being withdrawn
     * @param recipient - The address to send the withdrawn assets
     */
    function withdrawStake(
        address asset,
        address payable recipient
    ) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender][asset];

        if (stakeInfo.staked || stakeInfo.withdrawTime == 0 || stakeInfo.withdrawTime > block.timestamp) {
            revert StakeIsLocked();
        }

        uint128 stake = stakeInfo.amount;

        if (stake == 0) {
            revert StakeTooLow();
        }

        // Reset stake information
        stakeInfo.amount = 0;
        stakeInfo.withdrawTime = 0;
        stakeInfo.staked = false;
        stakeInfo.unstakeDelaySec = 0;

        if (asset == ETH) {
            SafeTransferLib.safeTransferETH(recipient, stake);
        } else {
            SafeTransferLib.safeTransfer(asset, recipient, stake);
        }

        emit StakeWithdrawn(msg.sender, asset, stake);
    }


    function _claimStake(
        address account,
        address asset,
        uint128 amount
    ) internal {
        StakeInfo storage stakeInfo = stakes[account][asset];

        uint128 stake = stakeInfo.amount;

        if (stake < amount) {
            revert StakeTooLow();
        }

        stakeInfo.amount = stake - amount;

        emit StakeClaimed(account, asset, amount);
    }
}
