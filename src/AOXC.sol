// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AOXC Sovereign Token V2
 * @author AOXC Core Team
 * @notice Professional-grade UUPS Token with Integrated Governance, Compliance, and Tax logic.
 * @dev Optimized for X Layer. All critical state changes are intended for DAO Timelock execution.
 */
contract AOXC is
    Initializable,
    ContextUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    UUPSUpgradeable
{
    // --- ROLES (DAO Managed) ---
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // --- IMMUTABLE CONSTANTS ---
    uint256 public constant GLOBAL_CAP = 300_000_000_000 * 1e18;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    // --- STRUCTURED STATE ---
    struct ProtocolState {
        uint256 yearlyMintLimit;
        uint256 mintedThisYear;
        uint256 lastMintTimestamp;
        uint256 maxTransferAmount;
        uint256 dailyTransferLimit;
        uint256 taxBps;
        address treasury;
        bool taxEnabled;
        bool emergencyBypass; // Master switch for DAO to disable all restrictions
    }

    ProtocolState public state;

    mapping(address => bool) private _blacklisted;
    mapping(address => string) public blacklistReason;
    mapping(address => uint256) public userLockUntil;
    mapping(address => bool) public isExempt; // Exempt from Tax & Velocity limits
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastTransferDay;

    // --- CUSTOM ERRORS (Audit Optimized) ---
    error AOXC_ZeroAddress();
    error AOXC_GlobalCapExceeded();
    error AOXC_InflationLimitReached();
    error AOXC_TransferRestricted(address account);
    error AOXC_VelocityLimitReached();
    error AOXC_UnauthorizedAction();
    error AOXC_TaxRateTooHigh();

    // --- EVENTS ---
    event ComplianceAction(address indexed account, bool blacklisted, uint256 lockedUntil);
    event ProtocolStateUpdated(uint256 taxBps, bool taxEnabled, address treasury);
    event ExemptionUpdated(address indexed account, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Proxy initializer
     * @param governor The address of the DAO Timelock or Multisig
     */
    function initialize(address governor) external initializer {
        if (governor == address(0)) revert AOXC_ZeroAddress();

        __ERC20_init("AOXC Token", "AOXC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("AOXC Token");
        __ERC20Votes_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNANCE_ROLE, governor);
        _grantRole(MINTER_ROLE, governor);
        _grantRole(PAUSER_ROLE, governor);
        _grantRole(UPGRADER_ROLE, governor);
        _grantRole(COMPLIANCE_ROLE, governor);

        // Initial Configuration
        state.maxTransferAmount = 1_000_000_000 * 1e18;
        state.dailyTransferLimit = 2_000_000_000 * 1e18;
        state.lastMintTimestamp = block.timestamp;
        state.treasury = governor;
        state.yearlyMintLimit = (100_000_000_000 * 1e18 * 600) / BPS_DENOMINATOR; // 6%

        isExempt[governor] = true;
        isExempt[address(this)] = true;

        _mint(governor, 100_000_000_000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL ENGINE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Core transfer logic with hooks for security and tax.
     */
    function _update(address from, address to, uint256 val)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        // 1. IMMUNITY SYSTEM: Bypass all logic for Mint/Burn/Exempt/Emergency
        if (from == address(0) || to == address(0) || isExempt[from] || state.emergencyBypass) {
            super._update(from, to, val);
            return;
        }

        // 2. COMPLIANCE CHECK
        if (_blacklisted[from] || block.timestamp < userLockUntil[from]) revert AOXC_TransferRestricted(from);
        if (_blacklisted[to]) revert AOXC_TransferRestricted(to);

        // 3. VELOCITY LIMITS (Anti-Whale / Anti-Bot)
        if (val > state.maxTransferAmount) revert AOXC_VelocityLimitReached();

        uint256 day = block.timestamp / 1 days;
        if (lastTransferDay[from] != day) {
            lastTransferDay[from] = day;
            dailySpent[from] = 0;
        }
        if (dailySpent[from] + val > state.dailyTransferLimit) revert AOXC_VelocityLimitReached();
        dailySpent[from] += val;

        // 4. TAX MOTOR
        uint256 finalAmount = val;
        if (state.taxEnabled && state.taxBps > 0) {
            uint256 tax = (val * state.taxBps) / BPS_DENOMINATOR;
            if (tax > 0) {
                finalAmount = val - tax;
                // Direct update to treasury to avoid recursive hook triggers
                super._update(from, state.treasury, tax);
            }
        }

        super._update(from, to, finalAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            MONETARY POLICY
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert AOXC_ZeroAddress();
        if (totalSupply() + amount > GLOBAL_CAP) revert AOXC_GlobalCapExceeded();

        // Dynamic Inflation Adjustment (Yearly reset)
        if (block.timestamp >= state.lastMintTimestamp + 365 days) {
            state.mintedThisYear = 0;
            state.lastMintTimestamp = block.timestamp;
            // Yearly limit is 6% of the current supply
            state.yearlyMintLimit = (totalSupply() * 600) / BPS_DENOMINATOR;
        }

        if (state.mintedThisYear + amount > state.yearlyMintLimit) revert AOXC_InflationLimitReached();

        state.mintedThisYear += amount;
        _mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    function updateProtocolConfig(uint256 _tax, bool _taxEnabled, address _treasury, bool _bypass)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (_tax > 1000) revert AOXC_TaxRateTooHigh(); // Hard cap 10%
        if (_treasury == address(0)) revert AOXC_ZeroAddress();

        state.taxBps = _tax;
        state.taxEnabled = _taxEnabled;
        state.treasury = _treasury;
        state.emergencyBypass = _bypass;

        emit ProtocolStateUpdated(_tax, _taxEnabled, _treasury);
    }

    function updateCompliance(address user, bool blacklisted, string calldata reason, uint256 lockDuration)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (hasRole(DEFAULT_ADMIN_ROLE, user)) revert AOXC_UnauthorizedAction();

        _blacklisted[user] = blacklisted;
        blacklistReason[user] = reason;

        if (lockDuration > 0) {
            userLockUntil[user] = block.timestamp + lockDuration;
        } else {
            userLockUntil[user] = 0;
        }

        emit ComplianceAction(user, blacklisted, userLockUntil[user]);
    }

    function setExemption(address account, bool status) external onlyRole(GOVERNANCE_ROLE) {
        isExempt[account] = status;
        emit ExemptionUpdated(account, status);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}

    // Governance/Voting Overrides
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    // Storage Gap for 100% safe future upgrades
    uint256[42] private __gap;
}
