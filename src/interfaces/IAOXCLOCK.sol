// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/**
 * @title IAOXCLOCK
 * @author AOXCAN AI Architect
 * @notice Temporal defense interface for AOXCORE V2.0.0.
 * @dev Optimized for AI-Veto and Predictive Neural Escalation (Time Dilation).
 */
interface IAOXCLOCK {
    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event OperationScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    event OperationExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event OperationCancelled(bytes32 indexed id);
    event MinDelayUpdated(uint256 oldDuration, uint256 newDuration);

    /**
     * @notice Emitted when AOXCAN AI expands the delay due to anomaly detection.
     */
    event NeuralRiskEscalation(bytes32 indexed operationId, uint256 riskScore, uint256 newDelay);

    /*//////////////////////////////////////////////////////////////
                            READ OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function isOperation(bytes32 id) external view returns (bool registered);
    function isOperationPending(bytes32 id) external view returns (bool pending);
    function isOperationReady(bytes32 id) external view returns (bool ready);
    function isOperationDone(bytes32 id) external view returns (bool done);

    /**
     * @notice Returns the status of the temporal circuit breaker.
     */
    function getClockLockState() external view returns (bool isLocked, uint256 expiry);

    /**
     * @notice Returns the minimum delay for a target based on its Security Tier.
     */
    function getMinDelayForTarget(address target) external view returns (uint256 duration);

    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        pure
        returns (bytes32 hash);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Schedules an operation while enforcing Global Magnitude Barriers.
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
     * @dev Known as "Neural Dilation" to trap malicious transactions.
     */
    function neuralEscalation(bytes32 id, uint256 riskScore, bytes calldata signature) external;

    /**
     * @notice Executes a scheduled operation that has cleared all hurdles.
     */
    function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        payable;

    /**
     * @notice Cancels an operation. Restricted to AI-Veto or Guardian.
     */
    function cancel(bytes32 id) external;

    /**
     * @notice Sets the security tier for a specific contract.
     */
    function setTargetSecurityTier(address target, uint256 minDelay) external;
}
