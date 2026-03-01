// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                        IMPORTS
//////////////////////////////////////////////////////////////*/
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// AOXC LIBRARIES
import {AOXCConstants} from "aox-libraries/AOXCConstants.sol";
import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";

/**
 * @title AOXCORE Sovereign
 * @notice Central AOXC token contract and autonomous enforcement engine.
 * @dev V2.3.2 - Hardened: All Slither low-level call warnings resolved.
 */
contract AOXCORE is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                        V2 NAMESPACED STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:aoxc.core.storage
    struct CoreStorage {
        address aoxcanAi;
        address repairEngine;
        address nexusHub;
        uint256 lastPulse;
        uint256 mintedSincePulse;
        uint256 anchorSupply;
        bool isCoreInitialized;
        mapping(address => uint256) lastActionBlock;
        mapping(address => bool) blacklisted;
        mapping(address => string) blacklistReason;
    }

    // Keccak256("aoxc.core.storage") - 1
    bytes32 private constant CORE_STORAGE_SLOT = 0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;

    function _getStore() internal pure returns (CoreStorage storage $) {
        assembly { $.slot := CORE_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeV2(address _nexus, address _sentinel, address _repair, address _admin)
        external
        reinitializer(2)
    {
        if (_nexus == address(0) || _sentinel == address(0) || _repair == address(0) || _admin == address(0)) {
            revert AOXCErrors.AOXC_InvalidAddress();
        }

        CoreStorage storage $ = _getStore();

        if (!$.isCoreInitialized) {
            __ERC20_init("AOXCORE", "AOX");
            __ReentrancyGuard_init();
            __ERC20Permit_init("AOXCORE");
            __ERC20Votes_init();
            $.isCoreInitialized = true;
        }

        $.nexusHub = _nexus;
        $.aoxcanAi = _sentinel;
        $.repairEngine = _repair;
        $.lastPulse = block.timestamp;
        $.anchorSupply = totalSupply() > 0 ? totalSupply() : 1e24;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, _nexus);
        _grantRole(AOXCConstants.SENTINEL_ROLE, _sentinel);

        emit AOXCEvents.ComponentSynchronized(keccak256("CORE_V2_GENESIS"), _nexus);
    }

    /*//////////////////////////////////////////////////////////////
                        ENFORCEMENT ENGINE
    //////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        if (paused()) revert AOXCErrors.AOXC_GlobalLockActive();

        CoreStorage storage $ = _getStore();

        // Blacklist check
        if (from != address(0) && $.blacklisted[from]) revert AOXCErrors.AOXC_Blacklisted(from);
        if (to != address(0) && $.blacklisted[to]) revert AOXCErrors.AOXC_Blacklisted(to);

        // Sovereign Transfer Rules
        if (from != address(0) && to != address(0)) {
            _checkRepairStatus($.repairEngine);

            // SLITHER FIX: MEV Protection with safety check
            if ($.lastActionBlock[from] >= block.number) {
                revert AOXCErrors.AOXC_TemporalCollision();
            }
            $.lastActionBlock[from] = block.number;

            _checkAiSentinel($.aoxcanAi, from, to);

            // Transfer Cap Enforcement
            if (!hasRole(DEFAULT_ADMIN_ROLE, from) && from != $.nexusHub) {
                uint256 limit = (totalSupply() * AOXCConstants.MAX_TRANSFER_BPS) / AOXCConstants.BPS_DENOMINATOR;
                if (amount > limit) revert AOXCErrors.AOXC_ExceedsMaxTransfer(amount, limit);
            }
        }

        super._update(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SOVEREIGN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) nonReentrant {
        CoreStorage storage $ = _getStore();

        if (block.timestamp >= $.lastPulse + 365 days) {
            $.lastPulse = block.timestamp;
            $.mintedSincePulse = 0;
            $.anchorSupply = totalSupply();
        }

        uint256 cap = ($.anchorSupply * AOXCConstants.MAX_MINT_PER_YEAR_BPS) / AOXCConstants.BPS_DENOMINATOR;
        if ($.mintedSincePulse + amount > cap) revert AOXCErrors.AOXC_InflationHardcapReached();

        $.mintedSincePulse += amount;
        _mint(to, amount);
    }

    function setBlacklist(address target, bool status, string calldata reason)
        external
        onlyRole(AOXCConstants.SENTINEL_ROLE)
    {
        CoreStorage storage $ = _getStore();
        $.blacklisted[target] = status;
        $.blacklistReason[target] = reason;
        emit AOXCEvents.NeuralSignalProcessed(keccak256("BLACKLIST_UPDATE"), abi.encode(target, status));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Checks if the target function is in quarantine.
     * SLITHER FIX: Added explicit return value and data length validation.
     */
    function _checkRepairStatus(address repair) internal view {
        if (repair == address(0)) return;

        (bool success, bytes memory data) = repair.staticcall(abi.encodeWithSignature("isOperational(bytes4)", msg.sig));

        // SLITHER FIX: data.length check is crucial for staticcall safety
        if (!success || data.length < 32 || !abi.decode(data, (bool))) {
            revert AOXCErrors.AOXC_Repair_ModeActive();
        }
    }

    /**
     * @dev AI Bastion check for illegal transfer patterns.
     * SLITHER FIX: Added explicit return value and data length validation.
     */
    function _checkAiSentinel(address ai, address from, address to) internal view {
        if (ai == address(0)) return;

        (bool success, bytes memory data) =
            ai.staticcall(abi.encodeWithSignature("isAllowed(address,address)", from, to));

        if (!success || data.length < 32 || !abi.decode(data, (bool))) {
            revert AOXCErrors.AOXC_Neural_BastionSealed(block.timestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDES & AUTH
    //////////////////////////////////////////////////////////////*/

    function pause() external {
        if (!hasRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender) && !hasRole(AOXCConstants.SENTINEL_ROLE, msg.sender)) {
            revert AOXCErrors.AOXC_Unauthorized(AOXCConstants.SENTINEL_ROLE, msg.sender);
        }
        _pause();
    }

    function unpause() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address) internal view override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}
