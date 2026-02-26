// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Sovereign Storage Infrastructure (V2.0.1)
 * @author AOXCAN AI Architect & Senior Quantum Auditor
 * @notice Deterministic storage schema for the AOXC Ecosystem.
 * @dev [V2-FIX]: Added central aoxcToken reference in MainStorage to resolve cross-contract link errors.
 */
abstract contract AOXCStorage {
    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct SubDaoPrivileges {
        bool isRegistered;
        bool canIssueAssets;
        uint256 vaultLimit;
        uint256 minReputationRequired;
        uint256 activeProposalLimit;
    }

    struct StakePosition {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        bool active;
    }

    /**
     * @dev Core protocol state, neural telemetry parameters, and security circuit breakers.
     */
    struct MainStorage {
        address aiSentinelNode; 
        address aoxcToken; // [V2-FIX]: Added missing token reference for ecosystem sync
        uint256 aiAnomalyThreshold; 
        uint256 lastNeuralPulse; 
        uint256 neuralPulseTimeout; 
        uint256 neuralNonce; 
        uint256 circuitBreakerTripTime; 
        uint256 maxLockdownDuration; 
        bool isSovereignSealed; 
        uint256 maxTransferQuantum; 
        uint256 dailyVelocityCeiling; 
        address treasury; 
        mapping(address => uint256) userReputation; 
    }

    struct StakingStorage {
        uint256 globalStakedAmount; 
        uint256 totalValueLocked; 
        uint256 minimumStakeDuration; 
        mapping(address => StakePosition[]) userStakes; 
        mapping(address => uint256) lastActionBlock; 
    }

    /*//////////////////////////////////////////////////////////////
                        DETERMINISTIC SLOTS (ERC-7201)
    //////////////////////////////////////////////////////////////*/

    // keccak256(abi.encode(uint256(keccak256("aoxc.v2.0.0.main")) - 1)) & ~0xff
    bytes32 internal constant MAIN_STORAGE_SLOT =
        0x367f33d711912e841280879f8c09a803f2560810065090176d6c703126780a00;

    // keccak256(abi.encode(uint256(keccak256("aoxc.v2.0.0.staking")) - 1)) & ~0xff
    bytes32 internal constant STAKING_STORAGE_SLOT = 
        0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00700;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL STORAGE ACCESSORS
    //////////////////////////////////////////////////////////////*/

    function _getMainStorage() internal pure returns (MainStorage storage $) {
        bytes32 slot = MAIN_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    function _getStakingStorage() internal pure returns (StakingStorage storage $) {
        bytes32 slot = STAKING_STORAGE_SLOT;
        assembly { $.slot := slot }
    }
}
