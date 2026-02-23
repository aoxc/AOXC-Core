// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCTreasury (Sovereign Finance Standard)
 * @notice Interface for the AOXC DAO Treasury with 6-year cliff and 6% annual caps.
 * @dev Standardized for interaction with Governor and Security Registry.
 */
interface IAOXCTreasury {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event WindowOpened(uint256 indexed windowId, uint256 windowEnd);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EmergencyModeToggled(bool status);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits Native ETH into the treasury.
     */
    function deposit() external payable;

    /**
     * @notice Withdraws ERC20 tokens within the 6% annual limit.
     */
    function withdrawERC20(address token, address to, uint256 amount) external;

    /**
     * @notice Withdraws Native ETH within the 6% annual limit.
     */
    function withdrawETH(address payable to, uint256 amount) external;

    /**
     * @notice Opens the next 1-year spending window after cliff or expiry.
     */
    function openNextWindow() external;

    /**
     * @notice Toggles emergency mode to bypass limits or pause operations.
     */
    function toggleEmergencyMode(bool status) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the timestamp when the 6-year initial lock ends.
     */
    function initialUnlockTimestamp() external view returns (uint256);

    /**
     * @notice Returns the end timestamp of the current active spending window.
     */
    function currentWindowEnd() external view returns (uint256);

    /**
     * @notice Returns current window ID.
     */
    function currentWindowId() external view returns (uint256);

    /**
     * @notice Returns available withdrawal limit for a specific token in current window.
     */
    function getRemainingLimit(address token) external view returns (uint256);

    /**
     * @notice Checks if the treasury is in emergency mode.
     */
    function emergencyMode() external view returns (bool);
}
