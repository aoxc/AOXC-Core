// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";
import {AOXCEvents} from "./libraries/AOXCEvents.sol";
import {IAOXCREGISTRY} from "./interfaces/IAOXCREGISTRY.sol";

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/
interface IAutoRepair {
    function triggerEmergencyQuarantine(bytes4 selector, address target) external;
}

/**
 * @title AOXCENTINEL
 * @notice AI-driven sentinel contract for ecosystem security and neural validation.
 * @dev V2.2.5 - Production Final. Slither-silent, Replay-protected, Type-safe Tuple Handling.
 */
contract AOXCENTINEL is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    struct SentinelStorage {
        address aiNodeAddress;
        address repairEngine;
        address governanceHub;
        IAOXCREGISTRY registry;
        uint256 lastPulseTimestamp;
        bool isBastionSealed;
        mapping(address => bool) blacklist;
        mapping(address => uint256) operationalNonces;
    }

    // ERC-7201 Slot
    bytes32 private constant SENTINEL_STORAGE_LOCATION =
        0x9331003666f7d025170d9e9e6f2bc8b671d1796c739a8976136f78816f1f6c00;

    function _getStore() internal pure returns (SentinelStorage storage $) {
        assembly { $.slot := SENTINEL_STORAGE_LOCATION }
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _dao, address _aiNode, address _repair, address _registry) public initializer {
        if (_dao == address(0) || _aiNode == address(0) || _registry == address(0)) {
            revert AOXCErrors.AOXC_InvalidAddress();
        }

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _dao);
        _grantRole(AOXCConstants.SENTINEL_ROLE, _aiNode);

        SentinelStorage storage $ = _getStore();
        $.aiNodeAddress = _aiNode;
        $.repairEngine = _repair;
        $.governanceHub = _dao;
        $.registry = IAOXCREGISTRY(_registry);
        $.lastPulseTimestamp = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSION GATEWAY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Determines whether an interaction is permitted.
     * @dev Slither-silent: Captures full neuralNet tuple with correct type alignment.
     */
    function isAllowed(address from, address to) external view returns (bool) {
        SentinelStorage storage $ = _getStore();

        // 1. Governance/Hub Bypass
        if (from == $.governanceHub || to == $.governanceHub) return true;

        // 2. Global Security State
        if ($.isBastionSealed || paused()) return false;

        // 3. Static Blacklist
        if ($.blacklist[from] || $.blacklist[to]) return false;

        // 4. Liveness Check (Heartbeat)
        if (block.timestamp > $.lastPulseTimestamp + AOXCConstants.NEURAL_HEARTBEAT_TIMEOUT) {
            return false;
        }

        // 5. Neural Cell Validation
        uint256 cellId = $.registry.userToCell(from);
        if (cellId != 0) {
            // FIXED: Tuple types must match IAOXCREGISTRY.neuralNet exactly
            // Order: uint256, uint256, uint256, bool, address
            (uint256 totalReputation, uint256 memberCount, uint256 riskFactor, bool quarantined, address cellLead) =
                $.registry.neuralNet(cellId);

            // Audit Logic: Block if quarantined OR risk factor exceeds threshold
            if (quarantined || riskFactor >= AOXCConstants.AI_RISK_THRESHOLD_HIGH) {
                return false;
            }

            // Silence compiler warnings for unused variables
            (totalReputation, memberCount, cellLead);
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL SIGNAL PROCESSING
    //////////////////////////////////////////////////////////////*/

    function processNeuralSignal(
        uint256 riskScore,
        uint256 nonce,
        address target,
        bytes4 selector,
        bytes calldata signature
    ) external nonReentrant {
        SentinelStorage storage $ = _getStore();

        uint256 currentNonce = $.operationalNonces[target];
        if (nonce <= currentNonce) {
            revert AOXCErrors.AOXC_Neural_StaleSignal(nonce, currentNonce);
        }

        bytes32 hash = keccak256(abi.encode(riskScore, nonce, target, selector, address(this), block.chainid))
            .toEthSignedMessageHash();

        if (hash.recover(signature) != $.aiNodeAddress) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        $.operationalNonces[target] = nonce;
        $.lastPulseTimestamp = block.timestamp;

        if (riskScore >= AOXCConstants.AI_RISK_THRESHOLD_HIGH) {
            $.isBastionSealed = true;
            if (!paused()) _pause();

            address repair = $.repairEngine;
            if (target != address(0) && repair != address(0)) {
                IAutoRepair(repair).triggerEmergencyQuarantine(selector, target);
            }

            emit AOXCEvents.NeuralInterception(nonce, riskScore, "AI_AUTONOMOUS_HALT");
        }

        emit AOXCEvents.HeartbeatSynced(block.timestamp, block.timestamp + AOXCConstants.NEURAL_HEARTBEAT_TIMEOUT);
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE ACTIONS
    //////////////////////////////////////////////////////////////*/

    function updateAiNode(address _newNode) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newNode == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        SentinelStorage storage $ = _getStore();
        address oldNode = $.aiNodeAddress;

        _revokeRole(AOXCConstants.SENTINEL_ROLE, oldNode);
        _grantRole(AOXCConstants.SENTINEL_ROLE, _newNode);

        $.aiNodeAddress = _newNode;
    }

    function updateRepairEngine(address _newEngine) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getStore().repairEngine = _newEngine;
    }

    function updateBlacklist(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getStore().blacklist[account] = status;
        emit AOXCEvents.NeuralQuarantineTriggered(account, status ? 10000 : 0, 0);
    }

    function emergencyBastionUnlock() external onlyRole(DEFAULT_ADMIN_ROLE) {
        SentinelStorage storage $ = _getStore();
        $.isBastionSealed = false;
        if (paused()) _unpause();
        emit AOXCEvents.GlobalLockStateChanged(false, 0);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
