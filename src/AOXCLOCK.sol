// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";
import {AOXCEvents} from "./libraries/AOXCEvents.sol";

/*//////////////////////////////////////////////////////////////
                        AOXCLOCK — SOVEREIGN
//////////////////////////////////////////////////////////////*/

/**
 * @title AOXCLOCK
 *
 * @notice
 * Enterprise-grade Timelock Controller with AI-assisted veto,
 * adaptive delay enforcement, and sovereign self-upgrade guarantees.
 *
 * @dev
 * Core extensions over OZ Timelock:
 * - AI-signed neural veto (cancel scheduled ops)
 * - Heartbeat-based safe-mode delay escalation
 * - Per-target minimum security delay tiers
 * - Self-upgrade only (Timelock can upgrade itself)
 *
 * Trust Model:
 * - DAO controls scheduling and execution
 * - AI node can only veto (cannot execute or upgrade)
 * - Loss of AI heartbeat forces conservative delays
 *
 * Upgradeability:
 * - UUPS pattern
 * - Isolated ERC-7201 storage slot
 */
contract AOXCLOCK is TimelockControllerUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Neural extension storage for timelock
     *
     * @dev
     * Stored in a fixed ERC-7201 slot to preserve upgrade safety.
     */
    struct NeuralTimelockStorage {
        address aoxcanNode; // Authorized AI signer
        uint256 anomalyThreshold; // Risk threshold reference
        uint256 neuralNonce; // Global AI nonce
        uint256 maxNeuralDelay; // Emergency max delay
        uint256 lastPulse; // Last AI heartbeat
        mapping(bytes32 => bool) neuralSignatureRegistry; // Signature replay guard
        mapping(address => uint256) targetSecurityTier; // Per-target min delay
        bool isInitialized; // One-time init guard
    }

    /**
     * @dev
     * ERC-7201 storage slot:
     * keccak256(abi.encode(uint256(keccak256("aoxcan.storage.NeuralTimelock")) - 1)) & ~0xff
     */
    bytes32 private constant TIMELOCK_STORAGE_SLOT = 0x8898951034f77c862137699d690a4833f5244510065090176d6c703126780a00;

    /// @dev Returns pointer to neural timelock storage
    function _getNeural() internal pure returns (NeuralTimelockStorage storage $) {
        assembly {
            $.slot := TIMELOCK_STORAGE_SLOT
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the neural timelock
     *
     * @param minDelay   Base minimum delay
     * @param proposers  Authorized proposers
     * @param executors  Authorized executors
     * @param admin      Admin / governance address
     * @param aiNode     Authorized AI signer
     */
    function initializeLock(
        uint256 minDelay,
        address[] calldata proposers,
        address[] calldata executors,
        address admin,
        address aiNode
    ) public initializer {
        __TimelockController_init(minDelay, proposers, executors, admin);

        NeuralTimelockStorage storage $ = _getNeural();
        if ($.isInitialized) {
            revert AOXCErrors.AOXC_AlreadyInitialized();
        }

        $.aoxcanNode = aiNode;
        $.anomalyThreshold = AOXCConstants.AI_RISK_THRESHOLD_HIGH;
        $.maxNeuralDelay = 26 days; // Hard safety ceiling
        $.lastPulse = block.timestamp;
        $.isInitialized = true;

        // Allow timelock to cancel its own operations via AI veto
        _grantRole(CANCELLER_ROLE, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                             NEURAL VETO
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Cancels a scheduled operation via AI-signed veto
     *
     * @dev
     * - Signature uniqueness enforced via hash registry
     * - AI nonce prevents replay across vetoes
     * - Successful veto updates heartbeat
     */
    function executeNeuralVeto(bytes32 id, bytes calldata signature) external {
        NeuralTimelockStorage storage $ = _getNeural();

        // Compute raw signature hash for replay protection
        bytes32 sigHash;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, signature.offset, signature.length)
            sigHash := keccak256(ptr, signature.length)
        }

        if ($.neuralSignatureRegistry[sigHash]) {
            revert AOXCErrors.AOXC_Neural_SignatureReused(sigHash);
        }

        // Construct signed message
        bytes32 msgHash =
            keccak256(abi.encode(id, $.neuralNonce, address(this), block.chainid)).toEthSignedMessageHash();

        if (msgHash.recover(signature) != $.aoxcanNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        // Persist veto state
        $.neuralSignatureRegistry[sigHash] = true;
        $.neuralNonce++;
        $.lastPulse = block.timestamp;

        // Cancel scheduled operation
        cancel(id);

        emit AOXCEvents.KarujanNeuralVeto(uint256(id), $.anomalyThreshold);
    }

    /*//////////////////////////////////////////////////////////////
                            SOVEREIGN HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates AI heartbeat without taking action
     *
     * @dev
     * Used to prevent safe-mode escalation when system is healthy.
     */
    function syncNeuralPulse() external {
        if (msg.sender != _getNeural().aoxcanNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        _getNeural().lastPulse = block.timestamp;

        emit AOXCEvents.HeartbeatSynced(block.timestamp, block.timestamp + AOXCConstants.NEURAL_HEARTBEAT_TIMEOUT);
    }

    /**
     * @notice Sets minimum enforced delay for a specific target
     */
    function setSecurityTier(address target, uint256 minDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getNeural().targetSecurityTier[target] = minDelay;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Overrides schedule to enforce adaptive delays
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        uint256 enforcedDelay = _calculateEnforcedDelay(target, value, delay);
        super.schedule(target, value, data, predecessor, salt, enforcedDelay);
    }

    /**
     * @dev Computes final enforced delay
     *
     * Delay rules:
     * - If AI heartbeat expired → maxNeuralDelay
     * - Apply per-target security tier
     * - Value transfers enforce ≥ 7 days
     */
    function _calculateEnforcedDelay(address target, uint256 value, uint256 delay) internal view returns (uint256) {
        NeuralTimelockStorage storage $ = _getNeural();
        uint256 enforced = delay;

        // Safe mode if AI is offline
        if (block.timestamp > $.lastPulse + AOXCConstants.NEURAL_HEARTBEAT_TIMEOUT) {
            return $.maxNeuralDelay;
        }

        if ($.targetSecurityTier[target] > enforced) {
            enforced = $.targetSecurityTier[target];
        }

        if (value > 0 && enforced < 7 days) {
            enforced = 7 days;
        }

        return enforced;
    }

    /**
     * @dev Upgrade authorization
     *
     * Only the Timelock itself may upgrade,
     * ensuring upgrades are always DAO-governed.
     */
    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != address(this)) {
            revert AOXCErrors.AOXC_SelfUpgradeOnly();
        }
    }

    receive() external payable override {}
}
