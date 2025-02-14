// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "@solady-0.0.259/utils/SafeTransferLib.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-5.0.2/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ETH} from "./Helpers.sol";

/* solhint-disable not-rely-on-time */

/**
 * Manages stakes.
 * Stakes are locked for a period of time.
 * Stakes can be added, claimed, and withdrawn.
 * To add stake, call `addStake` with the asset and amount.
 * Stake is claimed when `MagicSpendStakeManager.claim` is called
 * To withdraw stake, call `withdrawStake` with the asset and recipient. No partical unstakes are allowed.
 */
abstract contract StakeManager is ReentrancyGuardUpgradeable {
    /// Emitted when the unstake delay is too low or too high
    error InvalidUnstakeDelay();

    /// Emitted when the stake amount is too low
    error StakeTooLow();

    /// Emitted when the stake amount is too high
    error StakeTooHigh();

    /// Emitted when trying to unlock an already unlocked stake
    error StakeAlreadyUnlocked();

    /// Emitted when trying to lock an already locked stake
    error StakeAlreadyLocked();

    /// Emitted when trying to remove a locked stake
    error StakeIsLocked();

    /// Emitted when user tries to add more funds t
    error InsufficientFunds();

    /// Emitted when a stake is added
    event StakeLocked(address indexed account, address indexed token, uint256 amount, uint256 unstakeDelaySec);

    /// Emitted when a stake is unlocked (starts the unstake process)
    event StakeUnlocked(address indexed account, address indexed token, uint256 withdrawTime);

    /// Emitted when a stake is withdrawn
    event StakeWithdrawn(address indexed account, address indexed token, uint256 amount);

    /// Emitted when a stake is claimed
    event StakeClaimed(address indexed account, address indexed token, uint256 amount);

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

    mapping(address account => mapping(address token => StakeInfo stake)) private stakes;

    uint32 public constant ONE_DAY = 60 * 60 * 24;
    uint32 public constant THREE_DAYS = ONE_DAY * 3;
    uint32 public constant FIVE_DAYS = ONE_DAY * 5;

    function getStakeInfo(address account, address token) public view returns (StakeInfo memory info) {
        return stakes[account][token];
    }

    function stakeOf(address account, address token) public view returns (uint128) {
        return stakes[account][token].amount;
    }

    receive() external payable {
        addStake(ETH, uint128(msg.value), THREE_DAYS);
    }

    /**
     * Add to the account's stake - amount and delay
     * any pending unstake is first cancelled.
     * @param unstakeDelaySec The new lock duration before the deposit can be withdrawn.
     */
    function addStake(address token, uint128 amount, uint32 unstakeDelaySec) public payable nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];

        if (unstakeDelaySec == 0 || unstakeDelaySec > FIVE_DAYS) {
            revert InvalidUnstakeDelay();
        }

        // If asset is already staked, unstake delay must be the same
        if (stakeInfo.unstakeDelaySec > 0 && stakeInfo.unstakeDelaySec != unstakeDelaySec) {
            revert InvalidUnstakeDelay();
        }

        uint128 stake = stakeInfo.amount + amount;

        if (stake == 0) {
            revert StakeTooLow();
        }

        stakeInfo.amount += amount;
        stakeInfo.unstakeDelaySec = unstakeDelaySec;
        stakeInfo.staked = true;
        stakeInfo.withdrawTime = 0; // Reset withdraw time if unlocked

        if (token == ETH) {
            if (msg.value != amount) {
                revert InsufficientFunds();
            }
        } else {
            SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), amount);
        }

        emit StakeLocked(msg.sender, token, amount, unstakeDelaySec);
    }

    /**
     * Unlocks the stake, starting the withdrawal process.
     * Users must wait for the unstake delay to pass before withdrawing their assets.
     * @param token - The address of the asset being unstaked
     */
    function unlockStake(address token) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];

        if (stakeInfo.withdrawTime > 0 || !stakeInfo.staked) {
            revert StakeAlreadyUnlocked();
        }

        uint48 withdrawTime = uint48(block.timestamp) + stakeInfo.unstakeDelaySec;
        stakeInfo.withdrawTime = withdrawTime;
        stakeInfo.staked = false; // Mark as unstaking

        emit StakeUnlocked(msg.sender, token, withdrawTime);
    }

    /**
     * Re-locks a previously unlocked stake, canceling the withdrawal process.
     * Can only be called if the stake was previously unlocked via unlockStake().
     * @param token - The address of the token being re-locked
     */
    function lockStake(address token) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];

        if (stakeInfo.staked) {
            revert StakeAlreadyLocked();
        }

        if (stakeInfo.amount == 0) {
            revert StakeTooLow();
        }

        stakeInfo.staked = true;
        stakeInfo.withdrawTime = 0;

        emit StakeLocked(msg.sender, token, stakeInfo.amount, stakeInfo.unstakeDelaySec);
    }

    /**
     * Withdraws the staked assets after the unstake delay has passed.
     * Must first call `unlockStake` and wait for the delay to pass.
     * @param token - The address of the token being withdrawn
     * @param recipient - The address to send the withdrawn tokens
     */
    function withdrawStake(address token, address payable recipient) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender][token];

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

        _transfer(token, recipient, stake);

        emit StakeWithdrawn(msg.sender, token, stake);
    }

    function _claimStake(address account, address token, uint128 amount) internal {
        StakeInfo storage stakeInfo = stakes[account][token];

        uint128 stake = stakeInfo.amount;

        if (stake < amount) {
            revert StakeTooLow();
        }

        stakeInfo.amount = stake - amount;

        emit StakeClaimed(account, token, amount);
    }

    function _transfer(address token, address to, uint128 amount) internal {
        if (token == ETH) {
            SafeTransferLib.forceSafeTransferETH(to, amount);
        } else {
            SafeTransferLib.safeTransfer(token, to, amount);
        }
    }
}
