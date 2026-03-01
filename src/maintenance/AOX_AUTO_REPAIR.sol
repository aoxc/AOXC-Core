// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INFRASTRUCTURE
import {AOXCStorage} from "../abstract/AOXCStorage.sol";
import {AOXCConstants} from "aox-libraries/AOXCConstants.sol";
import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";

// INTERFACE
import {IAOX_AUTO_REPAIR} from "aox-interfaces/IAOX_AUTO_REPAIR.sol";

/**
 * @title AOX_AUTO_REPAIR Sovereign
 * @notice Autonomous repair engine for smart contract function quarantine and patch deployment.
 * @dev V2.2.5 - Final Clean: Linting fixes and Access Control optimization.
 */
contract AOX_AUTO_REPAIR is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    AOXCStorage,
    IAOX_AUTO_REPAIR
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STATE & CONFIG
    //////////////////////////////////////////////////////////////*/

    address public nexus;
    address public aiNode;
    address public auditVoice;

    mapping(uint256 => bool) public anomalyLedger;
    mapping(bytes4 => bool) public isReserved;

    // Lint fix: naming convention changed from __gap to _gap
    uint256[44] private _gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _nexus, address _aiNode, address _auditVoice) external initializer {
        if (_admin == address(0) || _nexus == address(0) || _aiNode == address(0) || _auditVoice == address(0)) {
            revert AOXCErrors.AOXC_InvalidAddress();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, _admin);
        _grantRole(AOXCConstants.UPGRADER_ROLE, _admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, _nexus);

        nexus = _nexus;
        aiNode = _aiNode;
        auditVoice = _auditVoice;

        isReserved[this.triggerEmergencyQuarantine.selector] = true;
        isReserved[this.liftQuarantine.selector] = true;
        isReserved[this.executePatch.selector] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        REPAIR ENGINE LOGIC
    //////////////////////////////////////////////////////////////*/

    function triggerEmergencyQuarantine(bytes4 selector, address target) external override nonReentrant {
        if (msg.sender != aiNode && !hasRole(AOXCConstants.GUARDIAN_ROLE, msg.sender)) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        if (isReserved[selector]) revert AOXCErrors.AOXC_CustomRevert("REPAIR: RESERVED");
        if (target == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        RegistryStorageV2 storage s = _getRegistryV2();

        s.activePatches[selector][target] = PatchCore({
            targetContract: target,
            functionSelector: selector,
            timestamp: uint64(block.timestamp),
            candidateLogic: address(0),
            autoUnlockAt: uint64(block.timestamp + AOXCConstants.AI_MAX_FREEZE_DURATION),
            isQuarantined: true
        });

        emit AOXCEvents.SystemRepairInitiated(keccak256(abi.encodePacked(selector, target)), target);
    }

    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        bytes calldata aiAuthProof
    ) external override nonReentrant onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        if (anomalyLedger[anomalyId]) {
            revert AOXCErrors.AOXC_CustomRevert("REPAIR: DUPLICATE");
        }

        bytes32 proofHash = keccak256(abi.encode(anomalyId, selector, target, patchLogic, block.chainid, address(this)))
            .toEthSignedMessageHash();

        if (proofHash.recover(aiAuthProof) != aiNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        RegistryStorageV2 storage s = _getRegistryV2();
        s.activePatches[selector][target].isQuarantined = false;
        s.activePatches[selector][target].candidateLogic = patchLogic;

        anomalyLedger[anomalyId] = true;
        emit AOXCEvents.PatchExecuted(selector, target, patchLogic);
    }

    function liftQuarantine(bytes4 selector, address target) external override {
        if (msg.sender != auditVoice && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AOXCErrors.AOXC_CustomRevert("REPAIR: UNAUTHORIZED");
        }

        RegistryStorageV2 storage s = _getRegistryV2();
        delete s.activePatches[selector][target];

        emit AOXCEvents.GlobalLockStateChanged(false, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isOperational(bytes4 selector) external view override returns (bool) {
        RegistryStorageV2 storage s = _getRegistryV2();
        // Check current implementation state
        return !s.activePatches[selector][address(this)].isQuarantined;
    }

    function getRepairStatus() external view override returns (bool inRepairMode, uint256 expiry) {
        MainStorage storage m = _getMainStorage();
        return (m.isRepairModeActive, m.repairExpiry);
    }

    function validatePatch(uint256 anomalyId) external view override returns (bool isVerified) {
        return anomalyLedger[anomalyId];
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(AOXCConstants.UPGRADER_ROLE) {
        if (newImplementation == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
    }
}
