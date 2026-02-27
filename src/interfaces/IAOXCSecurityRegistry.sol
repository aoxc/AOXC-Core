// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

/**
 * @title IAOXCSecurityRegistry Sovereign Interface V2.6
 * @author AOXCAN AI Architect & Senior Quantum Auditor
 * @notice Central gateway for AI-driven circuit breakers, quarantine protocols, and federated security.
 * @dev Reaching 10,000x DeFi quality through Neural Pulse Verification and Tiered Autonomous Locks.
 * Inherits OpenZeppelin AccessManager for granular role-based governance.
 */
interface IAOXCSecurityRegistry is IAccessManager {
    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event GlobalEmergencyLockToggled(address indexed caller, bool status);
    event NeuralHeartbeatSync(uint256 timestamp, uint256 nonce);

    /**
     * @notice Emitted when a specific module or address is isolated by the AI Sentinel.
     */
    event AnomalyNeutralized(address indexed target, uint256 riskScore, string method);

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Layer 23: Checks if the protocol-wide circuit breaker (Emergency Stop) is active.
     */
    function isGlobalEmergencyLocked() external view returns (bool);

    /**
     * @notice Layer 26: Returns the status of the 26-Hour Autonomous Recovery timer.
     * @return active True if the lockdown is currently in effect.
     * @return expiry The timestamp when the lock will auto-release (Sovereign Dilation).
     */
    function getSovereignLockdownStatus() external view returns (bool active, uint256 expiry);

    /**
     * @notice Layer 12: Verifies if the AI Sentinel is currently transmitting valid neural pulses.
     * @return functional True if the heartbeat is within the allowed timeout period.
     */
    function isNeuralHeartbeatFunctional() external view returns (bool functional);

    /*//////////////////////////////////////////////////////////////
                        NEURAL EMERGENCY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Layer 1-8: Engages the absolute emergency seal.
     * @dev Can be triggered by high-priority roles or recognized AI-anomaly patterns.
     * Synchronizes the lockdown across all connected AOXC modules.
     */
    function triggerEmergencyStop() external;

    /**
     * @notice Layer 15-22: Isolates a specific high-risk module or Sub-DAO using AI evidence.
     * @param target The address of the module/contract to quarantine.
     * @param riskScore The predictive anomaly score provided by the AI (scaled 0-10000).
     * @param signature Cryptographic ECDSA proof from the authorized AI Sentinel Node.
     */
    function triggerNeuralQuarantine(address target, uint256 riskScore, bytes calldata signature) external;

    /**
     * @notice Resumes protocol operations after a successful audit or the 26-hour auto-release period.
     */
    function releaseEmergencyStop() external;

    /**
     * @notice Updates the AI Sentinel node address responsible for neural heartbeat signatures.
     * @param newNode The new authorized AI Oracle address.
     */
    function updateNeuralNode(address newNode) external;
}
