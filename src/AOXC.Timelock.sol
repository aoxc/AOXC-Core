// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

/**
 * @title AOXCTimelock V2.0.1
 * @notice Temporal Governance Defense with AI-Driven Sovereign Veto.
 * @dev [V2.0.1-FIX]: Fixed calldata access in assembly to resolve Error (1397).
 */
contract AOXCTimelock is TimelockControllerUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct NeuralTimelockStorage {
        address aiOracleNode;
        uint256 aiAnomalyThreshold;
        uint256 neuralNonce;
        uint256 maxNeuralDelay;
        uint256 lastSentinelPulse;
        mapping(bytes32 => bool) neuralSignatureRegistry; 
        mapping(address => uint256) targetSecurityTier;
        bool initialized;
    }

    bytes32 private constant TIMELOCK_STORAGE_SLOT = 
        0x8898951034f77c862137699d690a4833f5244510065090176d6c703126780a00;

    function _getNeural() internal pure returns (NeuralTimelockStorage storage $) {
        assembly { $.slot := TIMELOCK_STORAGE_SLOT }
    }

    event AISovereignVeto(bytes32 indexed operationId, string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initializeApex(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin,
        address aiNode
    ) public initializer {
        __TimelockController_init(minDelay, proposers, executors, admin);

        NeuralTimelockStorage storage $ = _getNeural();
        if ($.initialized) revert AOXCErrors.AOXC_GlobalLockActive();

        $.aiOracleNode = aiNode;
        $.aiAnomalyThreshold = 8500;
        $.maxNeuralDelay = 26 days;
        $.lastSentinelPulse = block.timestamp;
        $.initialized = true;

        _grantRole(CANCELLER_ROLE, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL INTERVENTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Layer 26: AI-Signed Sovereign Veto.
     * @dev [V2.0.1]: Calldata-safe assembly hashing for zero-warning production.
     */
    function neuralVeto(bytes32 id, bytes calldata signature) external {
        NeuralTimelockStorage storage $ = _getNeural();
        
        bytes32 sigHash;
        // [V2-FIX]: Calldata elements accessed via .offset and .length
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, signature.offset, signature.length)
            sigHash := keccak256(ptr, signature.length)
        }

        if ($.neuralSignatureRegistry[sigHash]) {
            revert AOXCErrors.AOXC_Neural_SignatureReused(sigHash);
        }

        bytes32 msgHash = keccak256(
            abi.encode(id, $.neuralNonce, address(this), block.chainid)
        ).toEthSignedMessageHash();

        if (msgHash.recover(signature) != $.aiOracleNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        $.neuralSignatureRegistry[sigHash] = true;
        $.neuralNonce++;
        
        cancel(id); 
        
        emit AISovereignVeto(id, "Neural Sentinel Intervention");
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override {
        uint256 enforcedDelay = delay;
        NeuralTimelockStorage storage $ = _getNeural();

        uint256 targetTier = $.targetSecurityTier[target];
        if (targetTier > enforcedDelay) enforcedDelay = targetTier;

        if (value > 0 && enforcedDelay < 7 days) {
            enforcedDelay = 7 days;
        }

        super.schedule(target, value, data, predecessor, salt, enforcedDelay);
    }

    function setTargetSecurityTier(address target, uint256 minDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getNeural().targetSecurityTier[target] = minDelay;
    }

    function _authorizeUpgrade(address) internal override view {
        if (msg.sender != address(this)) {
            revert AOXCErrors.AOXC_Unauthorized(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
        }
    }

    receive() external payable override {}
}
