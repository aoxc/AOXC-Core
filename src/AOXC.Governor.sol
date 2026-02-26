// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

/**
 * @title AOXCGovernor V2.0.1
 * @notice 26-Layer Neural Governance Engine.
 * @dev [V2.0.1-OPTIMIZED]: Optimized with calldata-safe assembly hashing to resolve forge-lint notes.
 */
contract AOXCGovernor is
    Initializable,
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct GovernorStorage {
        address aiOracleNode;
        uint256 anomalyScoreLimit;
        uint256 lastNeuralPulse;
        uint256 neuralPulseTimeout;
        bool isNeuralLockActive;
        uint256 neuralNonce;
        uint256 lastGlobalActionBlock;
        uint256 globalAnomalyThreshold;
        mapping(uint256 => uint256) proposalRiskScores;
        mapping(bytes32 => bool) neuralSignatureRegistry;
        mapping(uint256 => bool) vetoedProposals;
        mapping(uint256 => bool) executedProposals;
        mapping(address => uint256) actorLastActionBlock;
        mapping(uint256 => bool) proposalExists;
        bool initialized;
    }

    // keccak256(abi.encode(uint256(keccak256("aoxc.governor.storage.v26")) - 1)) & ~0xff
    bytes32 private constant GOVERNOR_STORAGE_SLOT =
        0x5a17684526017462615a17684526017462615a17684526017462615a17684500;

    function _getGovernorStorage() internal pure returns (GovernorStorage storage $) {
        assembly { $.slot := GOVERNOR_STORAGE_SLOT }
    }

    event NeuralPulseSynchronized(uint256 indexed nonce, uint256 timestamp);
    event AnomalyIntercepted(uint256 indexed proposalId, uint256 riskLevel, string action);
    event ProposalExecuted(uint256 indexed proposalId);
    event SystemSecurityStateChanged(bytes32 indexed reason, bool lockActive);
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initializeGovernor(address _aiNode, uint256 _scoreLimit, address _admin)
        external
        initializer
    {
        if (_admin == address(0) || _aiNode == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        
        __Context_init();
        __ReentrancyGuard_init();
        __AccessControl_init();

        GovernorStorage storage $ = _getGovernorStorage();
        if ($.initialized) revert AOXCErrors.AOXC_GlobalLockActive();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, _admin);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, _admin);

        $.aiOracleNode = _aiNode;
        $.anomalyScoreLimit = _scoreLimit;
        $.lastNeuralPulse = block.timestamp;
        $.neuralPulseTimeout = 26 hours;
        $.globalAnomalyThreshold = 9500; 
        $.initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE DEFENSE
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual nonReentrant returns (uint256) {
        GovernorStorage storage $ = _getGovernorStorage();

        if (block.timestamp > $.lastNeuralPulse + $.neuralPulseTimeout) {
            revert AOXCErrors.AOXC_Neural_HeartbeatLost($.lastNeuralPulse, block.timestamp);
        }
        if ($.isNeuralLockActive) revert AOXCErrors.AOXC_GlobalLockActive();
        if ($.actorLastActionBlock[_msgSender()] == block.number) {
            revert AOXCErrors.AOXC_TemporalCollision();
        }

        uint256 proposalId = uint256(keccak256(abi.encode(targets, values, calldatas, description)));
        if ($.proposalExists[proposalId]) revert AOXCErrors.AOXC_CustomRevert("Governor: EXISTS");

        $.proposalExists[proposalId] = true;
        $.actorLastActionBlock[_msgSender()] = block.number;
        $.lastGlobalActionBlock = block.number;

        emit ProposalCreated(proposalId, _msgSender(), description);
        return proposalId;
    }

    function syncGovernorPulse(
        uint256 proposalId,
        uint256 riskScore,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant {
        GovernorStorage storage $ = _getGovernorStorage();

        if (!$.proposalExists[proposalId]) revert AOXCErrors.AOXC_CustomRevert("Governor: NON_EXISTENT");
        if (nonce <= $.neuralNonce) revert AOXCErrors.AOXC_Neural_StaleSignal(nonce, $.neuralNonce);

        bytes32 msgHash = keccak256(
            abi.encodePacked(proposalId, riskScore, nonce, address(this), block.chainid)
        ).toEthSignedMessageHash();

        if (msgHash.recover(signature) != $.aiOracleNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        bytes32 sigHash;
        // [V2-OPTIMIZATION]: Calldata-safe assembly hashing for zero-warning production
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, signature.offset, signature.length)
            sigHash := keccak256(ptr, signature.length)
        }

        if ($.neuralSignatureRegistry[sigHash]) revert AOXCErrors.AOXC_Neural_SignatureReused(sigHash);

        $.neuralSignatureRegistry[sigHash] = true;
        $.neuralNonce = nonce;
        $.lastNeuralPulse = block.timestamp;
        $.proposalRiskScores[proposalId] = riskScore;

        if (riskScore >= $.anomalyScoreLimit) {
            $.vetoedProposals[proposalId] = true;
            emit AnomalyIntercepted(proposalId, riskScore, "GOVERNOR_VETO");
        }

        if (riskScore >= $.globalAnomalyThreshold) {
            $.isNeuralLockActive = true;
            emit SystemSecurityStateChanged("CRITICAL_ANOMALY", true);
        }

        emit NeuralPulseSynchronized(nonce, block.timestamp);
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external payable nonReentrant onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        GovernorStorage storage $ = _getGovernorStorage();
        uint256 proposalId = uint256(keccak256(abi.encode(targets, values, calldatas, description)));

        if ($.isNeuralLockActive) revert AOXCErrors.AOXC_GlobalLockActive();
        if (!$.proposalExists[proposalId]) revert AOXCErrors.AOXC_CustomRevert("Governor: NULL_PROPOSAL");
        if ($.vetoedProposals[proposalId]) revert AOXCErrors.AOXC_CustomRevert("Governor: VETO_ACTIVE");
        if ($.executedProposals[proposalId]) revert AOXCErrors.AOXC_CustomRevert("Governor: ALREADY_EXECUTED");
        
        if ($.proposalRiskScores[proposalId] == 0) {
            revert AOXCErrors.AOXC_Neural_BastionSealed(block.timestamp);
        }

        $.executedProposals[proposalId] = true;

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{ value: values[i] }(calldatas[i]);
            if (!success) {
                if (result.length > 0) {
                    assembly {
                        let returndata_size := mload(result)
                        revert(add(32, result), returndata_size)
                    }
                } else {
                    revert AOXCErrors.AOXC_CustomRevert("Governor: CALL_FAILED");
                }
            }
        }

        emit ProposalExecuted(proposalId);
    }

    function resetGovernorLock() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        GovernorStorage storage $ = _getGovernorStorage();
        $.isNeuralLockActive = false;
        $.lastNeuralPulse = block.timestamp;
        emit SystemSecurityStateChanged("ADMIN_RESET", false);
    }

    function _authorizeUpgrade(address) internal override view onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
