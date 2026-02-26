// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCTimelock Sovereign Interface V2.6
 * @author AOXCAN AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Temporal Defense Interface with Neural Risk Scaling.
 * @dev Reaching 10,000x DeFi quality through Predictive Time-Compression and AI-Veto.
 * Enforces dynamic delay windows based on target security tiers and neural feedback.
 */
interface IAOXCTimelock {
    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    event CallExecuted(
        bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data
    );
    event Cancelled(bytes32 indexed id);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /**
     * @notice Emitted when AI Sentinel expands the delay due to anomaly detection.
     * @dev Layer 21: Autonomous reaction to high-risk proposals.
     */
    event NeuralRiskEscalation(bytes32 indexed operationId, uint256 riskScore, uint256 newDelay);

    /*//////////////////////////////////////////////////////////////
                             READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isOperation(bytes32 id) external view returns (bool pending);
    function isOperationPending(bytes32 id) external view returns (bool pending);
    function isOperationReady(bytes32 id) external view returns (bool ready);
    function isOperationDone(bytes32 id) external view returns (bool done);

    /**
     * @notice Layer 23: Returns the status of the 26-Hour Autonomous Lock.
     */
    function getSovereignTemporalState() external view returns (bool isLocked, uint256 expiry);

    /**
     * @notice Layer 5: Returns the minimum delay required for a specific target based on its Security Tier.
     * High-risk targets like Treasury require significantly longer delays.
     */
    function getMinDelayForTarget(address target) external view returns (uint256 duration);

    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32 hash);

    /*//////////////////////////////////////////////////////////////
                        NEURAL LOGIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Schedules an operation while enforcing Global Magnitude Barriers.
     * @dev Layer 1-8: Initial validation of proposal parameters.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    /**
     * @notice Expands the timelock window up to 26 days based on AI Risk Signaling.
     * @dev Layer 15-22: "Neural Dilation" mechanism to trap malicious transactions.
     * @param id The operation ID to dilate.
     * @param riskScore The score provided by the AI Sentinel (scaled 0-10000).
     * @param signature Cryptographic ECDSA proof from the AI Sentinel node.
     */
    function neuralEscalation(bytes32 id, uint256 riskScore, bytes calldata signature) external;

    /**
     * @notice Executes a scheduled operation that has cleared all neural and temporal hurdles.
     * @dev Layer 26: Final execution gateway.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    /**
     * @notice Cancels a scheduled operation. Restricted to AI-Veto or Guardian intervention.
     */
    function cancel(bytes32 id) external;

    /**
     * @notice Updates the security tier of a contract.
     * @dev E.g., setting the Treasury tier requires a 26-day delay by default.
     */
    function setTargetSecurityTier(address target, uint256 minDelay) external;
}
