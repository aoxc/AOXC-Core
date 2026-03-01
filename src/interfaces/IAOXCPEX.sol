// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/**
 * @title IAOXCPEX (Staking & Merit Protocol)
 * @author AOXCAN AI Architect
 * @notice Enterprise-grade yield engine with Neural-Pulse Reputation Scaling.
 * @dev Enforces Time-Weighted Meritocracy and AI-Validated Yield Scaling.
 */
interface IAOXCPEX {
    /**
     * @dev User's unique staking position metadata.
     * Packed for Gas Efficiency: [principal(128) | entryTime(64) | lockPeriod(64)] = 256 bits (1 Slot)
     */
    struct PositionInfo {
        uint128 principal; // Amount of AOXCORE tokens locked
        uint64 entryTime; // Block timestamp at initiation (Safe for 500+ years)
        uint64 lockPeriod; // Mandatory duration in seconds
        uint64 neuralBoost; // AI-assigned multiplier (Basis Points)
        bool isActive; // Operational status
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(address indexed user, uint256 indexed index, uint256 amount, uint256 duration);
    event PositionClosed(address indexed user, uint256 returned, uint256 burned, bool isEarly);
    event NeuralBoostApplied(address indexed user, uint256 boostFactor);
    event YieldRateUpdated(uint256 oldRate, uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a staking position with a Mandatory Neural Handshake.
     * @param _amount Amount of AOXCORE tokens to lock.
     * @param _duration Lockdown duration.
     * @param _aiProof Cryptographic signature from the AOXCAN AI Node.
     */
    function openPosition(uint256 _amount, uint256 _duration, bytes calldata _aiProof) external;

    /**
     * @notice Finalizes a position and releases principal/yield.
     */
    function closePosition(uint256 _index) external;

    /*//////////////////////////////////////////////////////////////
                        DEFENSIVE & ANALYTIC VIEWS
    //////////////////////////////////////////////////////////////*/

    function calculateYield(address _user, uint256 _index) external view returns (uint256 yield);
    function getAccountMerit(address _user) external view returns (uint256 merit);
    function getPexLockState() external view returns (bool isLocked, uint256 expiry);
    function getPositionDetails(address _user, uint256 _index) external view returns (PositionInfo memory);
    function getModuleTvl() external view returns (uint256);

    /**
     * @notice Returns the number of positions for a specific user.
     * Required for iterative UI/External scanning.
     */
    function getPositionCount(address _user) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE & SYSTEM OPS
    //////////////////////////////////////////////////////////////*/

    function updateBaseYield(uint256 _newRateBps) external;
    function updateAiNode(address _newNode) external;
}
