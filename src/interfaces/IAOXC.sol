// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXC Sovereign Interface V2.6
 * @author AOXC Core Architecture Team
 * @notice Master interface defining the 26-Layer Defense Protocol and Neural Apex standards.
 * @dev Integrates ERC20, EIP-2612 (Permit), ERC-5805 (Votes), and Autonomous AI Security.
 */
interface IAOXC {
    /*//////////////////////////////////////////////////////////////
                             ERC20 & PERMIT
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /**
     * @notice Allows token approval via signature (EIP-2612).
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function nonces(address owner) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                         VOTES & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;

    /*//////////////////////////////////////////////////////////////
                        V26 NEURAL & TELEMETRY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Processes a cryptographically signed risk signal from the AI Sentinel Node.
     * @param riskScore Probability of anomaly (scaled 0-10000).
     * @param nonce Security nonce to prevent replay attacks.
     * @param signature ECDSA proof from the authorized AI Sentinel node.
     */
    function processNeuralSignal(uint256 riskScore, uint256 nonce, bytes calldata signature) external;

    /**
     * @notice Returns the status of the 26-Hour Autonomous Circuit Breaker.
     * @return isLocked Boolean indicating if the protocol-level freeze is active.
     * @return timeRemaining The remaining duration of the lockdown in seconds.
     */
    function getSovereignLockState() external view returns (bool isLocked, uint256 timeRemaining);

    /**
     * @notice Dual-Factor Asset Restitution (Clawback) for high-risk anomalies.
     * @dev Only executable via a combination of AI Verification and Compliance authorization.
     */
    function sovereignClawback(address from, address to, uint256 amount, bytes calldata aiSignature) external;

    /**
     * @notice Verifies the liveness of the Neural Pulse (Heartbeat).
     * @return active Boolean indicating if the connection to the AI Oracle is within the grace period.
     */
    function isNeuralPulseActive() external view returns (bool active);

    /*//////////////////////////////////////////////////////////////
                         SUPPLY & COMPLIANCE
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    /**
     * @notice Check if an address is restricted from protocol interactions.
     */
    function isBlacklisted(address account) external view returns (bool);

    /**
     * @notice Sets the restriction status of a specific address.
     */
    function setBlacklistStatus(address account, bool status) external;

    /**
     * @notice Retrieves the current reputation score of an actor within the ecosystem.
     * @dev Used for gated liquidity access and transaction magnitude scaling.
     */
    function getReputationScore(address account) external view returns (uint256);
}
