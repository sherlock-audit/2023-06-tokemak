// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

import { IStakeTracking } from "src/interfaces/rewarders/IStakeTracking.sol";
import { IBaseRewarder } from "src/interfaces/rewarders/IBaseRewarder.sol";

import { IGPToke } from "src/interfaces/staking/IGPToke.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @dev An abstract contract that serves as the base for rewarder contracts.
 * It implements common functionalities for reward distribution, including calculating rewards per token,
 * tracking user rewards, and handling stake-related operations.
 * Inherited by rewarder contracts, such as MainRewarder and ExtraRewarder.
 * The contract is inspired by the Convex contract but uses block-based duration instead of timestamp-based duration.
 * Unlike Convex, it does not own the LP token but it interacts with an external LP token contract.
 */

abstract contract AbstractRewarder is IBaseRewarder, SecurityBase {
    using SafeERC20 for IERC20;

    /// @notice The duration of the reward period in blocks.
    uint256 public durationInBlock;

    ///  @notice It is used to determine if the new rewards should be distributed immediately or queued for later. If
    /// the ratio of current rewards to the sum of new and queued rewards is less than newRewardRatio, the new rewards
    /// are distributed immediately; otherwise, they are added to the queue.
    uint256 public newRewardRatio;

    /// @notice An instance of the system registry contract.
    ISystemRegistry internal immutable systemRegistry;

    /// @notice The address of the token to be distributed as rewards.
    address public immutable rewardToken;

    /// @notice An instance of the stake tracking contract, for managing staked tokens.
    IStakeTracking public immutable stakeTracker;

    /// @notice The block number when the current reward period ends.
    uint256 public periodInBlockFinish;

    /// @notice The rate of reward distribution per block.
    uint256 public rewardRate;

    /// @notice The block number when rewards were last updated.
    uint256 public lastUpdateBlock;

    /// @notice The amount of rewards distributed per staked token stored.
    uint256 public rewardPerTokenStored;

    /// @notice The amount of rewards waiting in the queue to be distributed.
    uint256 public queuedRewards;

    /// @notice The amount of current rewards being distributed.
    uint256 public currentRewards;

    /// @notice The total amount of rewards distributed historically.
    uint256 public historicalRewards;

    /// @notice The amount of reward per token paid to each user.
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice The amount of rewards for each user.
    mapping(address => uint256) public rewards;

    /// @notice The duration for locking the Toke token rewards.
    uint256 public tokeLockDuration;

    /// @notice Whitelisted addresses for queuing new rewards.
    mapping(address => bool) public whitelistedAddresses;

    /**
     * @param _systemRegistry Address of the system registry.
     * @param _stakeTracker Address of the stake tracker.
     * @param _rewardToken Address of the reward token.
     * @param _newRewardRate The new reward rate.
     * @param _durationInBlock The duration of the reward period in blocks.
     */
    constructor(
        ISystemRegistry _systemRegistry,
        address _stakeTracker,
        address _rewardToken,
        uint256 _newRewardRate,
        uint256 _durationInBlock
    ) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(_stakeTracker, "_stakeTracker");
        Errors.verifyNotZero(_rewardToken, "_rewardToken");

        systemRegistry = _systemRegistry;
        if (!systemRegistry.isRewardToken(_rewardToken)) {
            revert Errors.InvalidParam("_rewardToken");
        }
        rewardToken = _rewardToken;
        stakeTracker = IStakeTracking(_stakeTracker);
        newRewardRatio = _newRewardRate;
        durationInBlock = _durationInBlock;
    }

    /// @notice Restricts access to the stake tracker only.
    modifier onlyStakeTracker() {
        if (msg.sender != address(stakeTracker)) {
            revert Errors.AccessDenied();
        }
        _;
    }

    /// @notice Restricts access to whitelisted addresses or holders of the liquidator role.
    modifier onlyWhitelisted() {
        if (!whitelistedAddresses[msg.sender] && !_hasRole(Roles.LIQUIDATOR_ROLE, msg.sender)) {
            revert Errors.AccessDenied();
        }
        _;
    }

    /**
     * @notice Internal function that updates the user's rewards.
     * @param account The address of the user to update the rewards for.
     */
    function _updateReward(address account) internal {
        uint256 earnedRewards = 0;
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = lastBlockRewardApplicable();

        if (account != address(0)) {
            earnedRewards = earned(account);
            rewards[account] = earnedRewards;
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }

        emit UserRewardUpdated(account, earnedRewards, rewardPerTokenStored, lastUpdateBlock);
    }

    /**
     * @notice Retrieves the total supply of staked tokens.
     * @return The total supply of staked tokens.
     */
    function totalSupply() public view returns (uint256) {
        return stakeTracker.totalSupply();
    }

    /**
     * @notice Retrieves the balance of staked tokens for a specific account.
     * @param account The address of the account to retrieve the balance for.
     * @return The balance of staked tokens for the specified account.
     */
    function balanceOf(address account) public view returns (uint256) {
        return stakeTracker.balanceOf(account);
    }

    /**
     * @notice Determines the last block number applicable for rewards calculation.
     * @return The block number used for rewards calculation.
     * @dev If the current block number is less than the period finish => current block number,
     *      Else => the period finish block number.
     */
    function lastBlockRewardApplicable() public view returns (uint256) {
        return block.number < periodInBlockFinish ? block.number : periodInBlockFinish;
    }

    /**
     * @notice Calculates the current reward per token value.
     * @return The reward per token value.
     * @dev It takes into account the total supply, reward rate, and duration of the reward period.
     */
    function rewardPerToken() public view returns (uint256) {
        uint256 total = totalSupply();
        if (total == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + ((lastBlockRewardApplicable() - lastUpdateBlock) * rewardRate * 1e18 / total);
    }

    /**
     * @notice Calculates the amount of rewards earned by an account.
     * @dev
     * The function calculates the earned rewards based on the balance of the account,
     * the total supply of the staked tokens, the rewards per token and the last reward rate
     * the user has been paid at. The reward rate is determined by the `rewardPerToken`
     * function and is a measure of the amount of rewards distributed per staked token
     * per block.
     *
     * The amount of earned rewards is calculated as follows:
     * - First, it calculates the difference between the current reward per token and
     *   the last reward rate the user was paid at, which gives the reward rate per token
     *   since the user last claimed rewards.
     * - This difference is multiplied by the balance of the account to find the total
     *   amount of rewards the account has earned since it last claimed rewards.
     * - Finally, the function adds the rewards that have not yet been claimed by the
     *   user to find the total amount of earned rewards.
     *
     * @param account The address of the account to calculate the earned rewards for.
     * @return The total amount of rewards that the account has earned.
     */
    function earned(address account) public view returns (uint256) {
        return (balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    /**
     * @notice Updates the duration of the reward period in blocks.
     * @param _durationInBlock The new duration of the reward period in blocks.
     */
    function setDurationInBlock(uint256 _durationInBlock) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        durationInBlock = _durationInBlock;
        emit RewardDurationUpdated(_durationInBlock);
    }

    /**
     * @notice Updates the new reward ratio.
     * @param _newRewardRate The new reward ratio to determine the distribution of rewards.
     */
    function setNewRewardRate(uint256 _newRewardRate) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        newRewardRatio = _newRewardRate;
        emit NewRewardRateUpdated(_newRewardRate);
    }

    /**
     * @notice Queues the specified amount of new rewards for distribution to stakers.
     * @param newRewards The amount of new rewards.
     * @dev First, the function transfers the new rewards from the caller to this contract,
     *      ensuring that the deposited amount matches the declared rewards.
     *      Then, irrespective of whether we're near the start or the end of a reward period, if the accrued rewards
     *      are too large relative to the new rewards (i.e., queuedRatio is greater than newRewardRatio), the new
     *      rewards will be added to the queue rather than being immediately distributed.
     */
    function queueNewRewards(uint256 newRewards) external onlyWhitelisted {
        uint256 startingQueuedRewards = queuedRewards;
        uint256 startingNewRewards = newRewards;

        newRewards += startingQueuedRewards;

        if (block.number >= periodInBlockFinish) {
            notifyRewardAmount(newRewards);
            queuedRewards = 0;
        } else {
            uint256 elapsedBlock = block.number - (periodInBlockFinish - durationInBlock);
            uint256 currentAtNow = rewardRate * elapsedBlock;
            uint256 queuedRatio = currentAtNow * 1000 / newRewards;

            if (queuedRatio < newRewardRatio) {
                notifyRewardAmount(newRewards);
                queuedRewards = 0;
            } else {
                queuedRewards = newRewards;
            }
        }

        emit QueuedRewardsUpdated(startingQueuedRewards, startingNewRewards, queuedRewards);

        // Transfer the new rewards from the caller to this contract.
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), newRewards);
    }

    /**
     * @notice Notifies the contract about the amount of reward tokens to be distributed.
     * @param reward The amount of reward tokens to be distributed.
     * @dev The function updates the rewardRate, lastUpdateBlock, periodInBlockFinish, and historicalRewards.
     *      It calculates the remaining reward based on the current block number and adjusts the reward rate
     *      accordingly.
     *
     *      If the current block number is within the reward period, the remaining reward is added to the reward queue
     *      and will be distributed gradually over the remaining duration.
     *      If the current block number exceeds the reward period, the remaining reward is distributed immediately.
     */
    function notifyRewardAmount(uint256 reward) internal {
        _updateReward(address(0));
        historicalRewards += reward;

        if (block.number < periodInBlockFinish) {
            uint256 remaining = periodInBlockFinish - block.number;
            // slither-disable-next-line divide-before-multiply
            uint256 leftover = remaining * rewardRate;
            reward += leftover;
        }

        rewardRate = reward / durationInBlock;
        currentRewards = reward;
        lastUpdateBlock = block.number;
        periodInBlockFinish = block.number + durationInBlock;

        emit RewardAdded(reward, rewardRate, lastUpdateBlock, periodInBlockFinish, historicalRewards);
    }

    /**
     * @notice Sets the lock duration for staked Toke tokens.
     * @dev If the lock duration is set to 0, it turns off the staking functionality for Toke tokens.
     * @dev If the lock duration is greater than 0, it should be long enough to satisfy the minimum staking duration
     * requirement of the gpToke contract.
     * @param _tokeLockDuration The lock duration for staked Toke tokens.
     */
    function setTokeLockDuration(uint256 _tokeLockDuration) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        // if duration is not set to 0 (that would turn off functionality), make sure it's long enough for gpToke
        if (_tokeLockDuration > 0) {
            Errors.verifyNotZero(address(systemRegistry.gpToke()), "gpToke");
            if (_tokeLockDuration < systemRegistry.gpToke().minStakeDuration()) {
                revert IGPToke.StakingDurationTooShort();
            }
        }

        tokeLockDuration = _tokeLockDuration;
        emit TokeLockDurationUpdated(_tokeLockDuration);
    }

    /**
     * @notice Add an address to the whitelist.
     * @param wallet The address to be added to the whitelist.
     */
    function addToWhitelist(address wallet) external override hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        Errors.verifyNotZero(wallet, "wallet");
        if (whitelistedAddresses[wallet]) {
            revert Errors.ItemExists();
        }
        whitelistedAddresses[wallet] = true;

        emit AddedToWhitelist(wallet);
    }

    /**
     * @notice Remove an address from the whitelist.
     * @param wallet The address to be removed from the whitelist.
     */
    function removeFromWhitelist(address wallet) external override hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        if (!whitelistedAddresses[wallet]) {
            revert Errors.ItemNotFound();
        }

        whitelistedAddresses[wallet] = false;

        emit RemovedFromWhitelist(wallet);
    }

    /**
     * @notice Check if an address is whitelisted.
     * @param wallet The address to be checked.
     * @return bool indicating if the address is whitelisted.
     */
    function isWhitelisted(address wallet) external view override returns (bool) {
        return whitelistedAddresses[wallet];
    }

    /**
     * @notice Internal function to distribute rewards to a specific account.
     * @param account The address of the user to distribute rewards to.
     */
    function _getReward(address account) internal {
        Errors.verifyNotZero(account, "account");

        uint256 reward = earned(account);
        (IGPToke gpToke, address tokeAddress) = (systemRegistry.gpToke(), address(systemRegistry.toke()));

        // slither-disable-next-line incorrect-equality
        if (reward == 0) return;

        rewards[account] = 0;
        emit RewardPaid(account, reward);

        // if NOT toke, or staking is turned off (by duration = 0), just send reward back
        if (rewardToken != tokeAddress || tokeLockDuration == 0) {
            IERC20(rewardToken).safeTransfer(account, reward);
        } else {
            // authorize gpToke to get our reward Toke
            // slither-disable-next-line unused-return
            IERC20(address(tokeAddress)).approve(address(gpToke), reward);

            // stake Toke
            gpToke.stake(reward, tokeLockDuration, account);
        }
    }

    /**
     * @notice Internal function to handle withdrawals.
     * @param account The address of the user to handle withdrawal.
     * @dev This function primarily checks for valid parameters and emits an event.
     *      It adopts a pattern established by Convex. It helps with:
     *      - Identifying system errors (if a revert happens here, there is an issue within our system).
     *      - Enhancing system monitoring capabilities through emitted events.
     * @param amount The amount to be withdrawn.
     */
    function _withdraw(address account, uint256 amount) internal {
        Errors.verifyNotZero(account, "account");
        Errors.verifyNotZero(amount, "amount");

        emit Withdrawn(account, amount);
    }

    /**
     * @notice Internal function to handle staking.
     * @dev This function primarily checks for valid parameters and emits an event.
     *      It adopts a pattern established by Convex. It helps with:
     *      - Identifying system errors (if a revert happens here, there is an issue within our system).
     *      - Enhancing system monitoring capabilities through emitted events.
     * @param account The address of the user to handle staking.
     * @param amount The amount to be staked.
     */
    function _stake(address account, uint256 amount) internal {
        Errors.verifyNotZero(account, "account");
        Errors.verifyNotZero(amount, "amount");

        emit Staked(account, amount);
    }
}
