// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCStake Sovereign Interface V2.6
 * @author AOXC AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Reputation & Staking Interface with Neural-Pulse Boosting.
 * @dev Enforces Time-Weighted Meritocracy and AI-Validated Yield Scaling to prevent sybil attacks and reward loyalty.
 */
interface IAOXCStake {
    /**
     * @dev Structure representing a user's unique staking position.
     * [Layer 1-5] Optimized storage packing (Slot Isolation) for audit-ready alignment.
     */
    struct StakeInfo {
        uint128 amount; // Principal amount of AOXC tokens staked
        uint128 startTime; // Block timestamp when stake was initiated
        uint128 lockDuration; // Mandatory lock period in seconds (e.g., 26 months)
        uint64 neuralBoost; // [Layer 6] AI-assigned reputation multiplier (scaled)
        bool active; // Operational status of the staking position
    }

    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event Staked(address indexed user, uint256 indexed stakeIndex, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amountReturned, uint256 amountBurned, bool isEarly);
    event NeuralBoostApplied(address indexed user, uint256 boostFactor);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a staking position with a Mandatory Neural Handshake.
     * @dev Layer 17-22: AI Sentinel must sign the entry to verify user's non-malicious history.
     * @param _amount Total AOXC tokens to be locked in the bastion.
     * @param _months Lock-up tier (validated against AOXCConstants: 3, 6, 9, 12, or 26).
     * @param _aiSignature Cryptographic proof from the AI Sentinel Node for risk validation.
     */
    function stake(uint256 _amount, uint256 _months, bytes calldata _aiSignature) external;

    /**
     * @notice Finalizes a staking position and releases funds/rewards.
     * @dev Layer 16-20: If withdrawal is pre-mature, a "Slashing" mechanism burns a portion of the principal.
     * @param _stakeIndex The specific index of the user's staking array.
     */
    function withdraw(uint256 _stakeIndex) external;

    /*//////////////////////////////////////////////////////////////
                        V26 DEFENSIVE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Layer 9: Calculates algorithmic rewards using the Neural Multiplier.
     * Formula: f(amount, time, neuralBoost) = reward.
     */
    function calculateReward(address _user, uint256 _index) external view returns (uint256 reward);

    /**
     * @notice Layer 15: Returns the total Reputation Points (Merit) earned by the user.
     * This score directly influences the user's voting power in IAOXCGovernor.
     */
    function getUserReputation(address _user) external view returns (uint256 merit);

    /**
     * @notice Layer 23: Checks if the Staking Bastion is under an Autonomous 26-Hour Lockdown.
     */
    function getStakingLockState() external view returns (bool isLocked, uint256 timeRemaining);

    /**
     * @notice Retrieves detailed storage data for a specific staking position.
     */
    function getStakeDetails(address _user, uint256 _index) external view returns (StakeInfo memory);

    /**
     * @notice Layer 24: Returns the Total Value Locked (TVL) specifically within the Staking module.
     */
    function totalValueLocked() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE & AUDIT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adjusts the global reward basis points. Restricted to the Governance Role.
     * @param _newRateBps The new annual yield rate in Basis Points (1/10000).
     */
    function updateRewardRate(uint256 _newRateBps) external;

    /**
     * @notice Updates the AI Sentinel node address for cryptographic entry verification.
     * @param _newNode The new authorized AI Oracle identity.
     */
    function updateNeuralNode(address _newNode) external;
}
