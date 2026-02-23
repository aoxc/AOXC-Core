// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AOXC Sovereign Treasury V2
 * @notice Advanced vault with 6-year cliff and 6% annual rolling limits.
 * @dev Optimized with OZ v5 Transient Storage for gas efficiency and DAO alignment.
 */
contract AOXCTreasury is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // --- ROLES ---
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // --- CONSTANTS ---
    uint256 public constant INITIAL_LOCK_DURATION = 2190 days; // 6 Years
    uint256 public constant SPENDING_WINDOW = 365 days;
    uint256 public constant MAX_WITHDRAWAL_BPS = 600; // 6%
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // --- STATE ---
    uint256 public initialUnlockTimestamp;
    uint256 public currentWindowId;
    uint256 public currentWindowEnd;
    bool public emergencyMode;

    struct WindowAccounting {
        uint256 startBalance;
        uint256 withdrawn;
    }

    // Token => WindowId => Accounting
    mapping(address => mapping(uint256 => WindowAccounting)) public windowStates;

    // --- ERRORS ---
    error AOXC_Vault_Locked(uint256 current, uint256 unlockAt);
    error AOXC_Vault_WindowClosed();
    error AOXC_Vault_LimitExceeded();
    error AOXC_Vault_TransferFailed();
    error AOXC_Vault_ZeroAddress();

    event WindowOpened(uint256 indexed windowId, uint256 windowEnd);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governor) external initializer {
        if (governor == address(0)) revert AOXC_Vault_ZeroAddress();

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuardTransient_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNANCE_ROLE, governor);
        _grantRole(EMERGENCY_ROLE, governor);
        _grantRole(UPGRADER_ROLE, governor);

        initialUnlockTimestamp = block.timestamp + INITIAL_LOCK_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                            WINDOW MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Increments the window ID and resets the 1-year timer.
     * @dev Only callable after the 6-year cliff or after the previous window expires.
     */
    function openNextWindow() external onlyRole(GOVERNANCE_ROLE) {
        if (block.timestamp < initialUnlockTimestamp) {
            revert AOXC_Vault_Locked(block.timestamp, initialUnlockTimestamp);
        }

        // Ensure the previous window has actually expired
        if (block.timestamp <= currentWindowEnd) revert AOXC_Vault_WindowClosed();

        currentWindowId++;
        currentWindowEnd = block.timestamp + SPENDING_WINDOW;

        emit WindowOpened(currentWindowId, currentWindowEnd);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAWAL ENGINE
    //////////////////////////////////////////////////////////////*/

    function withdrawERC20(address token, address to, uint256 amount)
        external
        nonReentrant
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused
    {
        _processWithdrawal(token, to, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function withdrawETH(address payable to, uint256 amount)
        external
        nonReentrant
        onlyRole(GOVERNANCE_ROLE)
        whenNotPaused
    {
        _processWithdrawal(address(0), to, amount);
        (bool success,) = to.call{value: amount}("");
        if (!success) revert AOXC_Vault_TransferFailed();
    }

    function _processWithdrawal(address token, address to, uint256 amount) internal {
        if (to == address(0)) revert AOXC_Vault_ZeroAddress();
        if (emergencyMode) {
            emit FundsWithdrawn(token, to, amount);
            return;
        }

        if (block.timestamp > currentWindowEnd) revert AOXC_Vault_WindowClosed();

        WindowAccounting storage acc = windowStates[token][currentWindowId];

        // First withdrawal in this window? Take a snapshot.
        if (acc.startBalance == 0) {
            acc.startBalance = (token == address(0)) ? address(this).balance : IERC20(token).balanceOf(address(this));
        }

        uint256 maxAllowed = (acc.startBalance * MAX_WITHDRAWAL_BPS) / BPS_DENOMINATOR;
        if (acc.withdrawn + amount > maxAllowed) revert AOXC_Vault_LimitExceeded();

        acc.withdrawn += amount;
        emit FundsWithdrawn(token, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN & SAFETY
    //////////////////////////////////////////////////////////////*/

    function toggleEmergencyMode(bool status) external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = status;
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}

    receive() external payable {}
}
