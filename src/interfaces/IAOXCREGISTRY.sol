// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

/**
 * @title IAOXCREGISTRY
 * @author AOXCAN AI Architect
 * @notice Central Nervous System for AI-driven security orchestration.
 * @dev V2.0.4 - Integrates AccessManager with mandatory cell mapping and neuralNet views.
 */
interface IAOXCREGISTRY is IAccessManager {
    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event GlobalEmergencyLockToggled(address indexed caller, bool status);
    event NeuralHeartbeatSync(uint256 timestamp, uint256 nonce);
    event AnomalyNeutralized(address indexed target, uint256 riskScore, string diagnosticCode);
    event CellQuarantined(uint256 indexed cellId, address indexed triggerer);

    /*//////////////////////////////////////////////////////////////
                            READ OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function isGlobalLockActive() external view returns (bool);
    function getRegistryLockState() external view returns (bool active, uint256 expiry);
    function isAiHeartbeatFunctional() external view returns (bool functional);

    /**
     * @notice Maps a user address to their specific AOXC Cell ID.
     */
    function userToCell(address user) external view returns (uint256);

    /**
     * @notice Returns the full status of a neural cell.
     * @dev Order: totalReputation, memberCount, riskFactor, isQuarantined, cellLead.
     */
    function neuralNet(uint256 cellId)
        external
        view
        returns (uint256 totalReputation, uint256 memberCount, uint256 riskFactor, bool isQuarantined, address cellLead);

    /*//////////////////////////////////////////////////////////////
                        NEURAL EMERGENCY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enforces a protocol-wide circuit breaker.
     */
    function triggerEmergencyStop() external;

    /**
     * @notice Isolates an address or cell based on AI risk signals.
     */
    function triggerNeuralQuarantine(address target, uint256 riskScore, bytes calldata signature) external;

    /**
     * @notice Restores normal operational state after a lockdown.
     */
    function releaseEmergencyStop() external;

    /**
     * @notice Updates the cryptographic identity of the AOXCAN AI Node.
     */
    function updateAiNode(address newNode) external;
}
