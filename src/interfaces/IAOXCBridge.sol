// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCBridge Sovereign Interface V2.6
 * @author AOXC AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Neural Defense Interface for Cross-Chain Migrations.
 * @dev Enforces predictive risk scoring and economic magnitude barriers to eliminate bridge exploits.
 */
interface IAOXCBridge {
    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event CrossChainSent(
        uint16 indexed dstChainId, address indexed from, address indexed to, uint256 amount, bytes32 messageId
    );

    event CrossChainReceived(uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 messageId);

    /**
     * @notice Emitted when the AI Sentinel detects and blocks a suspicious bridge attempt.
     */
    event BridgeAnomalyNeutralized(bytes32 indexed messageId, uint256 riskScore, string action);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a cross-chain transfer with Mandatory AI Vetting.
     * @dev Layer 17-22: Cryptographic signature verification and risk threshold check.
     * @param _dstChainId Destination chain identifier (Sovereign Mesh ID).
     * @param _to Recipient address on the destination chain.
     * @param _amount Amount of AOXC tokens to bridge.
     * @param _aiRiskScore Anomaly score (0-10000) assigned by AI Sentinel.
     * @param _aiSignature Cryptographic proof signed by the AI Sentinel Node.
     */
    function bridgeOut(
        uint16 _dstChainId,
        address _to,
        uint256 _amount,
        uint256 _aiRiskScore,
        bytes calldata _aiSignature
    ) external payable;

    /**
     * @notice Finalizes a cross-chain transfer with Inbound Solvency Verification.
     * @dev Layer 9-16: Verifies the source proof and ensures the destination liquidity is solvent.
     * @param _srcChainId Source chain identifier.
     * @param _to Recipient address on this chain.
     * @param _amount Amount received.
     * @param _messageId Unique identifier for the cross-chain message to prevent replay.
     */
    function bridgeIn(uint16 _srcChainId, address _to, uint256 _amount, bytes32 _messageId) external;

    /*//////////////////////////////////////////////////////////////
                        V26 NEURAL DEFENSE & VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Layer 23-26: Checks the status of the 26-Hour Autonomous Lock for the Bridge.
     * @return isLocked True if the bridge is in a defensive freeze state.
     * @return expiry The timestamp when the lockdown automatically expires.
     */
    function getBridgeLockdownState() external view returns (bool isLocked, uint256 expiry);

    /**
     * @notice Layer 12: Estimates the gas fee required for bridgeOut.
     */
    function quoteBridgeFee(uint16 _dstChainId, uint256 _amount) external view returns (uint256 nativeFee);

    /**
     * @notice Layer 9: Magnitude Barrier enforcement.
     * @dev Prevents total liquidity drain by limiting daily cross-chain volume per chain.
     * @return remaining The remaining token amount allowed to be bridged today.
     */
    function getRemainingLimit(uint16 _chainId, bool isOut) external view returns (uint256 remaining);

    /**
     * @notice Layer 5: Checks if a specific chain ID is whitelisted within the Sovereign Mesh.
     */
    function isChainSupported(uint16 _chainId) external view returns (bool);

    /**
     * @notice Layer 18: Replay Attack Protection.
     * @return processed True if the message ID has already been executed.
     */
    function processedMessages(bytes32 _messageId) external view returns (bool processed);
}
