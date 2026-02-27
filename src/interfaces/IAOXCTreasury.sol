// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCTreasury Sovereign Interface V2.8
 * @author AOXCAN AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Financial Bastion with Neural-Pulse Withdrawal Limits.
 * @dev Enforces a 6-year initial cliff and a 6% annual linear withdrawal cap.
 * Fully optimized for Forge-Lint compliance and high-integrity financial auditing.
 */
interface IAOXCTreasury {
    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event WindowOpened(uint256 indexed windowId, uint256 windowEnd);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EmergencyModeToggled(bool status);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits Native ETH into the sovereign treasury.
     * @dev Layer 1: Open entry for protocol revenue and donations.
     */
    function deposit() external payable;

    /**
     * @notice Withdraws ERC20 tokens within the 6% annual magnitude limit.
     * @dev Layer 16-20: Requires AI-Sentinel signature if amount exceeds 1% of total TVL.
     * @param token Address of the ERC20 token to withdraw.
     * @param to Destination address.
     * @param amount Token amount to release.
     * @param aiSignature Cryptographic proof from the AI Sentinel for high-magnitude transfers.
     */
    function withdrawErc20(address token, address to, uint256 amount, bytes calldata aiSignature) external;

    /**
     * @notice Withdraws Native ETH within the sovereign 6% annual limit.
     * @dev Layer 21: Parallel logic to ERC20 with native asset security.
     */
    function withdrawEth(address payable to, uint256 amount, bytes calldata aiSignature) external;

    /**
     * @notice Opens the next 1-year spending window after the 6-year cliff or previous window expiry.
     * @dev Layer 26: Institutional lock satisfaction check.
     */
    function openNextWindow() external;

    /**
     * @notice Toggles the 26-Hour Autonomous Lockdown.
     * @dev Can be triggered by AI Registry or Guardian consensus.
     */
    function toggleEmergencyMode(bool status) external;

    /*//////////////////////////////////////////////////////////////
                        V26 DEFENSIVE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the timestamp when the 6-year institutional "Great Lock" ends.
     */
    function initialUnlockTimestamp() external view returns (uint256);

    /**
     * @notice Returns the end timestamp of the current active 1-year spending window.
     */
    function currentWindowEnd() external view returns (uint256);

    /**
     * @notice Returns the current window ID (Windows 0 to 5 represent the 6-year lock).
     */
    function currentWindowId() external view returns (uint256);

    /**
     * @notice Returns the remaining 6% withdrawal limit for a token in the current window.
     * @dev Layer 9: Prevents bank-runs by capping annual outflows.
     */
    function getRemainingLimit(address token) external view returns (uint256);

    /**
     * @notice Layer 23: Checks if the Treasury is under a 26-Hour AI Lockdown.
     */
    function isEmergencyLocked() external view returns (bool);

    /**
     * @notice Returns the total Value Locked (Tvl) in the treasury for magnitude scaling.
     * @dev Aggregates verified asset values for risk-score calculation.
     */
    function getSovereignTvl() external view returns (uint256);
}
