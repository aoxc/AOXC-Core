// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/**
 * @title AOXCXLayerSentinel
 * @notice Autonomous AI-driven security nexus for the X Layer ecosystem.
 * @dev Implements a namespaced storage pattern to prevent upgrade collisions.
 */
contract AOXCXLayerSentinel is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct SentinelStorage {
        address aiSentinelNode; // Layer 1: Authorized AI signer
        uint256 aiAnomalyThreshold; // Layer 2: Risk sensitivity (BPS)
        uint256 lastNeuralPulse; // Layer 11: Liveness heartbeat
        uint256 neuralNonce; // Layer 17: Sequence for replay protection
        uint256 circuitBreakerTime; // Layer 10: Temporary lockdown timestamp
        bool isSovereignSealed; // Layer 23: Permanent lockdown flag
        bool initialized; // Internal: Setup guard
        mapping(address => bool) blacklisted;
        mapping(address => bool) whitelisted;
        mapping(address => uint256) reputationScore;
    }

    // EIP-7201 Style Storage Slot
    bytes32 private constant STORAGE_SLOT = 0x8a7f909192518e932e49c95d97f9c733f5244510065090176d6c703126780c00;

    function _getStore() internal pure returns (SentinelStorage storage $) {
        assembly { $.slot := STORAGE_SLOT }
    }

    /*--- TELEMETRY EVENTS ---*/
    event NeuralPulseSync(uint256 indexed timestamp, uint256 nonce, uint256 riskScore);
    event LockdownActivated(uint256 startTime, string reason);
    event ReputationAdjusted(address indexed actor, uint256 oldScore, uint256 newScore);
    event SentinelNodeMigrated(address indexed oldNode, address indexed newNode);
    event SecurityBypassGranted(address indexed account, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Sentinel with governor and AI Node.
     */
    function initialize(address _admin, address _aiNode) public reinitializer(2) {
        if (_admin == address(0) || _aiNode == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, _admin);

        SentinelStorage storage $ = _getStore();
        if ($.initialized) revert AOXCErrors.AOXC_GlobalLockActive();

        $.aiSentinelNode = _aiNode;
        $.aiAnomalyThreshold = 500; // Default 5%
        $.lastNeuralPulse = block.timestamp;
        $.whitelisted[_admin] = true;
        $.initialized = true;
    }

    /**
     * @notice core check for transaction validity.
     * @dev Optimized Priority: Whitelist > Lockdown > Blacklist > Temporal.
     */
    function isAllowed(address from, address to) external view returns (bool) {
        SentinelStorage storage $ = _getStore();

        // 1. Whitelist & Admin Bypass (Highest priority to prevent deadlock)
        if ($.whitelisted[from] || $.whitelisted[to]) return true;

        // 2. Sovereign Lockdown & Pause Control
        if ($.isSovereignSealed || paused()) return false;

        // 3. Global Blacklist Check
        if ($.blacklisted[from] || $.blacklisted[to]) return false;

        // 4. Temporal Circuit Breaker (Temporary freeze logic)
        if ($.circuitBreakerTime != 0) {
            if (block.timestamp <= $.circuitBreakerTime + AOXCConstants.AI_MAX_FREEZE_DURATION) {
                return false;
            }
        }

        // 5. Reputation Gate (Audit Placeholder)
        if ($.reputationScore[from] < 10 && from != address(0)) {
            // Logic for trusted liquidity access could be placed here
        }

        return true;
    }

    /**
     * @notice Processes cryptographically signed risk signals from the AI Node.
     */
    function processNeuralSignal(uint256 riskScore, uint256 nonce, bytes calldata signature)
        external
        nonReentrant
        whenNotPaused
    {
        SentinelStorage storage $ = _getStore();

        if (nonce <= $.neuralNonce) {
            revert AOXCErrors.AOXC_Neural_StaleSignal(nonce, $.neuralNonce);
        }

        bytes32 innerHash;
        address thisAddr = address(this);
        uint256 cId = block.chainid;

        // Layer 18: ASM Optimized cryptographic preparation
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, riskScore)
            mstore(add(ptr, 0x20), nonce)
            mstore(add(ptr, 0x40), thisAddr)
            mstore(add(ptr, 0x60), cId)
            innerHash := keccak256(ptr, 0x80)
            // Memory is not updated as no further allocations follow in this scope
        }

        if (innerHash.toEthSignedMessageHash().recover(signature) != $.aiSentinelNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        $.neuralNonce = nonce;
        $.lastNeuralPulse = block.timestamp;

        // Adaptive response logic
        if (riskScore >= 1000) {
            // Critical: 10% Risk
            $.isSovereignSealed = true;
            _pause();
            emit LockdownActivated(block.timestamp, "NEURAL_CRITICAL_HALT");
        } else if (riskScore >= $.aiAnomalyThreshold) {
            $.circuitBreakerTime = block.timestamp;
            emit LockdownActivated(block.timestamp, "TEMPORAL_BREAKER_TRIPPED");
        } else {
            $.circuitBreakerTime = 0;
        }

        emit NeuralPulseSync(block.timestamp, nonce, riskScore);
    }

    /*--- COMPLIANCE & GOVERNANCE ---*/

    /**
     * @notice Aligns with IAOXC interface for automated handler whitelisting.
     */
    function setBlacklistStatus(address account, bool status) external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        _getStore().blacklisted[account] = status;
    }

    function setWhitelist(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getStore().whitelisted[account] = status;
        emit SecurityBypassGranted(account, status);
    }

    function updateReputation(address target, uint256 score) external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        SentinelStorage storage $ = _getStore();
        uint256 old = $.reputationScore[target];
        $.reputationScore[target] = score;
        emit ReputationAdjusted(target, old, score);
    }

    function emergencyBastionUnlock() external onlyRole(DEFAULT_ADMIN_ROLE) {
        SentinelStorage storage $ = _getStore();
        $.isSovereignSealed = false;
        $.circuitBreakerTime = 0;
        if (paused()) _unpause();
    }

    function migrateSentinelNode(address newNode) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newNode == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        SentinelStorage storage $ = _getStore();
        address old = $.aiSentinelNode;
        $.aiSentinelNode = newNode;
        emit SentinelNodeMigrated(old, newNode);
    }
}
