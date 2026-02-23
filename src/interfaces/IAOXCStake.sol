// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCStake
 * @author AOXC Protocol
 * @notice Interface for the tiered, deflationary staking system.
 * @dev Defines the interaction logic for users, governors, and external integrators.
 */
interface IAOXCStake {
    /**
     * @dev Structure representing a user's unique staking position.
     * Packed for storage efficiency (Audit-ready).
     */
    struct StakeInfo {
        uint128 amount; // Principal amount staked
        uint128 startTime; // Block timestamp when stake was initiated
        uint128 lockDuration; // Required lock period in seconds
        bool active; // True if stake is still in the pool
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Staked(address indexed user, uint256 indexed stakeIndex, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amountReturned, uint256 amountBurned, bool isEarly);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                            USER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes a specific amount of tokens for a tiered duration.
     * @param _amount The amount of AOXC tokens to lock.
     * @param _months The lock tier (3, 6, 9, or 12 months).
     */
    function stake(uint256 _amount, uint256 _months) external;

    /**
     * @notice Withdraws a specific stake. Early withdrawal triggers a burn of the principal.
     * @param _stakeIndex The index of the stake in the user's array.
     */
    function withdraw(uint256 _stakeIndex) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the current accrued reward for a specific stake.
     * @param _user The address of the staker.
     * @param _index The index of the stake.
     * @return reward Accrued reward amount with 1e12 precision factor.
     */
    function calculateReward(address _user, uint256 _index) external view returns (uint256 reward);

    /**
     * @notice Returns total number of stakes created by a user.
     */
    function getStakeCount(address _user) external view returns (uint256);

    /**
     * @notice Returns detailed information about a specific stake.
     */
    function getStakeDetails(address _user, uint256 _index) external view returns (StakeInfo memory);

    /**
     * @notice Returns the total amount of tokens currently locked in the staking contract.
     */
    function totalValueLocked() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the annual reward basis points. Restricted to Governance.
     * @param _newRateBps The new reward rate (e.g., 600 for 6%).
     */
    function updateRewardRate(uint256 _newRateBps) external;
}
