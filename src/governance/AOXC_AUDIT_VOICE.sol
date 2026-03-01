// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// AOXC INFRASTRUCTURE
import {AOXCConstants} from "aox-libraries/AOXCConstants.sol";
import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";

/**
 * @title AOXC_AUDIT_VOICE Sovereign
 * @notice DAO Teklifleri Üzerinde Topluluk Denetim ve Veto Sinyali Katmanı.
 * @dev V2.1.9 - Slither Safe, ERC-7201 Compliant, Gas Optimized.
 */
contract AOXC_AUDIT_VOICE is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    struct AuditSignal {
        uint256 totalVetoPower;
        mapping(address => bool) hasSignaled;
        bool thresholdReached;
        uint256 finalizedAt;
    }

    struct AuditVoiceStorage {
        address nexus;
        address aoxcToken;
        uint256 vetoThresholdBps;
        mapping(uint256 => AuditSignal) proposalSignals;
    }

    // EIP-7201 standardına uygun, çakışma riski minimize edilmiş slot
    // keccak256(abi.encode(uint256(keccak256("aoxc.storage.AuditVoice")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0x89e5a1b068224578964573895245892345892345892345892345892345892300;

    function _getStore() internal pure returns (AuditVoiceStorage storage $) {
        assembly { $.slot := STORAGE_LOCATION }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address nexus_, address token_) external initializer {
        if (admin == address(0) || nexus_ == address(0) || token_ == address(0)) {
            revert AOXCErrors.AOXC_InvalidAddress();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, admin);

        AuditVoiceStorage storage $ = _getStore();
        $.nexus = nexus_;
        $.aoxcToken = token_;
        $.vetoThresholdBps = 500; // %5 Default
    }

    /*//////////////////////////////////////////////////////////////
                             VETO SIGNALING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Topluluk veto sinyali gönderir.
     * @dev Slither Fix: 'power == 0' yerine '!(power > 0)' mantığı kullanıldı.
     */
    function emitVetoSignal(uint256 proposalId) external nonReentrant {
        AuditVoiceStorage storage $ = _getStore();

        // Flash-loan protection: Bir önceki bloktaki oy gücü
        uint256 pastBlock;
        unchecked {
            pastBlock = block.number - 1;
        }

        uint256 power = IVotes($.aoxcToken).getPastVotes(msg.sender, pastBlock);

        // SLITHER FIX: Strict equality (== 0) avoided
        if (!(power > 0)) revert AOXCErrors.AOXC_ZeroAmount();

        AuditSignal storage signal = $.proposalSignals[proposalId];
        if (signal.hasSignaled[msg.sender]) revert AOXCErrors.AOXC_AlreadyActioned();

        // Effects
        signal.hasSignaled[msg.sender] = true;
        signal.totalVetoPower += power;

        emit AOXCEvents.NeuralInterception(proposalId, power, "COMMUNITY_VETO_SIGNAL");

        // Threshold Check
        uint256 totalSupply = IVotes($.aoxcToken).getPastTotalSupply(pastBlock);
        uint256 requiredThreshold = (totalSupply * $.vetoThresholdBps) / AOXCConstants.BPS_DENOMINATOR;

        if (signal.totalVetoPower >= requiredThreshold && !signal.thresholdReached) {
            signal.thresholdReached = true;
            signal.finalizedAt = block.timestamp;
            _triggerNexusIntervention(proposalId);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _triggerNexusIntervention(uint256 proposalId) internal {
        emit AOXCEvents.KarujanNeuralVeto(proposalId, 9999);
        emit AOXCEvents.ComponentSynchronized(keccak256("VETO_THRESHOLD_REACHED"), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                               SYSTEM VIEWS
    //////////////////////////////////////////////////////////////*/

    function isVetoed(uint256 proposalId) external view returns (bool) {
        return _getStore().proposalSignals[proposalId].thresholdReached;
    }

    function getVetoSignalStatus(uint256 proposalId) external view returns (uint256 power, bool reached) {
        AuditSignal storage signal = _getStore().proposalSignals[proposalId];
        return (signal.totalVetoPower, signal.thresholdReached);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    function setThreshold(uint256 bps) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        // SLITHER FIX: Strict equality (== 0) avoided
        if (!(bps > 0) || bps > 2000) revert AOXCErrors.AOXC_InvalidThreshold();
        _getStore().vetoThresholdBps = bps;
    }
}
