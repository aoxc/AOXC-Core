// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { AccessManagerUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

/**
 * @title AOXCSecurityRegistry V2.0.1
 * @notice Central Nervous System (CNS) for AI-Driven Security Enforcement.
 * @dev [V2.0.1-OPTIMIZED]: Fully compliant with calldata-safe assembly hashing.
 */
contract AOXCSecurityRegistry is
    Initializable,
    AccessManagerUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct NeuralSecurityStorage {
        address aiSentinelNode;
        uint256 anomalyThreshold;
        uint256 lastNeuralPulse;
        uint256 neuralPulseTimeout;
        uint256 neuralNonce;
        bool isGlobalKillSwitchActive;
        uint256 circuitBreakerTripBlock;
        mapping(address => uint256) subDaoQuarantineExpiries;
        mapping(address => bool) subDaoEmergencyLocks;
        mapping(bytes32 => bool) processedNeuralSignals;
        mapping(address => uint256) addressRiskLevel;
        bool initialized;
    }

    bytes32 private constant SECURITY_STORAGE_SLOT =
        0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;

    function _getNeural() internal pure returns (NeuralSecurityStorage storage $) {
        assembly { $.slot := SECURITY_STORAGE_SLOT }
    }

    event GlobalKillSwitchActivated(uint256 blockNumber, uint256 riskScore);
    event GlobalSystemRestored(address by);
    event SubDaoQuarantined(address indexed target, uint256 expiry);
    event NeuralHeartbeatUpdated(uint256 timestamp);

    constructor() { _disableInitializers(); }

    function initializeApex(address initialAdmin, address aiNode) public initializer {
        if (initialAdmin == address(0) || aiNode == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        
        __AccessManager_init(initialAdmin);

        NeuralSecurityStorage storage $ = _getNeural();
        if ($.initialized) revert AOXCErrors.AOXC_GlobalLockActive();

        $.aiSentinelNode = aiNode;
        $.anomalyThreshold = 800; // 8% Risk Baseline (BPS)
        $.lastNeuralPulse = block.timestamp;
        $.neuralPulseTimeout = 2 days;
        $.initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL BASTION ENGINE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev [V2.0.1]: Optimized memory management for dynamic string hashing.
     */
    function _computeNeuralHash(string memory action, uint256 risk, address target, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        bytes32 actionHash;
        bytes memory actionBytes = bytes(action);
        assembly {
            actionHash := keccak256(add(actionBytes, 32), mload(actionBytes))
        }
        
        return keccak256(
            abi.encode(actionHash, risk, target, nonce, address(this), block.chainid)
        ).toEthSignedMessageHash();
    }

    function triggerGlobalEmergency(uint256 riskScore, bytes calldata aiSignature) external {
        NeuralSecurityStorage storage $ = _getNeural();

        bytes32 msgHash = _computeNeuralHash("GLOBAL_LOCK", riskScore, address(0), $.neuralNonce);
        _verifyAiSignature(msgHash, aiSignature);

        if (riskScore < $.anomalyThreshold) {
            _checkAoxcRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);
        }

        $.isGlobalKillSwitchActive = true;
        $.circuitBreakerTripBlock = block.number;
        $.neuralNonce++;

        emit GlobalKillSwitchActivated(block.number, riskScore);
    }

    function triggerSubDaoNeuralLock(
        address subDao,
        uint256 riskScore,
        uint256 duration,
        bytes calldata aiSignature
    ) external {
        NeuralSecurityStorage storage $ = _getNeural();
        
        if (duration > AOXCConstants.AI_MAX_FREEZE_DURATION) {
            duration = AOXCConstants.AI_MAX_FREEZE_DURATION;
        }

        bytes32 msgHash = _computeNeuralHash("QUARANTINE", riskScore, subDao, $.neuralNonce);
        _verifyAiSignature(msgHash, aiSignature);

        if (riskScore < $.anomalyThreshold) {
            _checkAoxcRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);
        }

        $.subDaoQuarantineExpiries[subDao] = block.timestamp + duration;
        $.subDaoEmergencyLocks[subDao] = true;
        $.neuralNonce++;

        emit SubDaoQuarantined(subDao, $.subDaoQuarantineExpiries[subDao]);
    }

    function emergencySystemReset() external {
        _checkAoxcRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
        NeuralSecurityStorage storage $ = _getNeural();
        
        $.isGlobalKillSwitchActive = false;
        $.lastNeuralPulse = block.timestamp; 
        
        emit GlobalSystemRestored(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verifyAiSignature(bytes32 hash, bytes calldata sig) internal {
        NeuralSecurityStorage storage $ = _getNeural();
        
        bytes32 sigId;
        // [V2.0.1]: Calldata-safe assembly for signature replay protection
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, sig.offset, sig.length)
            sigId := keccak256(ptr, sig.length)
        }
        
        if ($.processedNeuralSignals[sigId]) {
            revert AOXCErrors.AOXC_Neural_SignatureReused(sigId);
        }
        
        if (hash.recover(sig) != $.aiSentinelNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        $.processedNeuralSignals[sigId] = true;
        $.lastNeuralPulse = block.timestamp;

        emit NeuralHeartbeatUpdated(block.timestamp);
    }

    function _checkAoxcRole(bytes32 roleName, address account) internal view {
        uint64 roleId = uint64(uint256(roleName));
        (bool isMember,) = hasRole(roleId, account);
        if (!isMember) revert AOXCErrors.AOXC_Unauthorized(roleName, account);
    }

    function _authorizeUpgrade(address) internal override view {
        _checkAoxcRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
    }

    function isAllowed(address, address subDaoTarget) external view returns (bool) {
        NeuralSecurityStorage storage $ = _getNeural();

        if ($.isGlobalKillSwitchActive) return false;
        if (block.timestamp > $.lastNeuralPulse + $.neuralPulseTimeout) return false;
        
        if ($.subDaoEmergencyLocks[subDaoTarget]) {
            if (block.timestamp < $.subDaoQuarantineExpiries[subDaoTarget]) {
                return false;
            }
        }

        return true;
    }
}
