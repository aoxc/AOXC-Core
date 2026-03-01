// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCErrors
 * @author AOXCAN AI Architect
 * @notice Centralized error library for the AOXCORE ecosystem.
 * @dev Version 2.6.0 – Optimized for Sovereign Core, Neural Sentinel, and ARS.
 */
library AOXCErrors {
    /*//////////////////////////////////////////////////////////////
                        IDENTITY & ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    error AOXC_Unauthorized(bytes32 role, address account);
    error AOXC_InvalidAddress();
    error AOXC_MandatoryAddressMissing(string componentName);
    error AOXC_AlreadyInitialized();
    error AOXC_InitializationLocked();
    error AOXC_GlobalLockActive();
    error AOXC_InsufficientReputation(address target, uint256 current, uint256 required);
    error AOXC_DormantAdminDetected(uint256 lastAction, uint256 threshold);

    /*//////////////////////////////////////////////////////////////
                        NEURAL / AI DIAGNOSTIC ERRORS
    //////////////////////////////////////////////////////////////*/

    error AOXC_Neural_IdentityForgery();
    error AOXC_Neural_StaleSignal(uint256 providedNonce, uint256 expectedNonce);
    error AOXC_Neural_HeartbeatLost(uint256 lastPulse, uint256 currentTime);
    error AOXC_NeuralPulseLost();
    error AOXC_Neural_RiskThresholdBreached(uint256 score, uint256 limit);
    error AOXC_Neural_SignatureReused(bytes32 sigHash);
    error AOXC_Neural_DomainMismatch(uint256 chainId, address contractAddr);
    error AOXC_Neural_BastionSealed(uint256 timestamp);
    error AOXC_Neural_AnomalyDetected(bytes32 alertCode);

    /*//////////////////////////////////////////////////////////////
                        CELLULAR DAO & REGISTRY
    //////////////////////////////////////////////////////////////*/

    error AOXC_Cell_AtMaxCapacity(uint256 cellId, uint256 limit);
    error AOXC_Cell_IsQuarantined(uint256 cellId, uint256 expiry);
    error AOXC_Cell_NotFound(uint256 cellId);
    error AOXC_Cell_InvalidMember(address member);
    error AOXC_Cell_AlreadyMember(address member, uint256 cellId);
    error AOXC_Cell_HashMismatch(bytes32 expected, bytes32 provided);
    error AOXC_Cell_QueueFull(uint256 currentSize, uint256 limit);
    error AOXC_Cell_MigrationFailed(address member, string reason);

    /*//////////////////////////////////////////////////////////////
                    AUTONOMOUS REPAIR ENGINE (ARS)
    //////////////////////////////////////////////////////////////*/

    error AOXC_Repair_ModeActive();
    error AOXC_Repair_ModeNotActive();
    error AOXC_Repair_ComponentAlreadyHealthy(bytes32 componentId);
    error AOXC_Repair_InvalidSequence(uint256 expected, uint256 provided);
    error AOXC_Repair_ValidationFailed(bytes32 repairId);
    error AOXC_Repair_CooldownActive(uint256 remaining);
    error AOXC_Repair_UnauthorizedRepairman(address caller);
    error AOXC_Repair_QueueEmpty();

    /*//////////////////////////////////////////////////////////////
                        FISCAL & MONETARY DEFENSE
    //////////////////////////////////////////////////////////////*/

    error AOXC_ZeroAmount();
    error AOXC_InsufficientBalance(uint256 available, uint256 required);
    error AOXC_ExceedsAllowance(uint256 available, uint256 required);
    error AOXC_Blacklisted(address account);
    error AOXC_InvalidBPS(uint256 provided, uint256 maxAllowed);
    error AOXC_TreasuryExhausted();
    error AOXC_ClawbackDenied();
    error AOXC_RewardsDepleted();
    error AOXC_InflationHardcapReached();
    error AOXC_Pulse_NotReady(uint256 lastPulse, uint256 nextPulse);

    /*//////////////////////////////////////////////////////////////
                        SOVEREIGN ASSET (AOXBUILD)
    //////////////////////////////////////////////////////////////*/

    error AOXC_Asset_InvalidType(uint8 providedType);
    error AOXC_Asset_AlreadyMinted(uint256 assetId);
    error AOXC_Asset_MetadataLocked(uint256 assetId);

    /*//////////////////////////////////////////////////////////////
                        VELOCITY & TEMPORAL BARRIERS
    //////////////////////////////////////////////////////////////*/

    error AOXC_ExceedsMaxTransfer(uint256 amount, uint256 limit);
    error AOXC_GlobalVelocityExceeded(uint256 requested, uint256 remaining);
    error AOXC_TemporalBreach(uint256 currentBlock, uint256 lastBlock);
    error AOXC_MagnitudeLimitExceeded(uint256 impactBps, uint256 maxBps);
    error AOXC_TemporalCollision();

    /*//////////////////////////////////////////////////////////////
                        STAKING & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    error AOXC_StakeNotActive();
    error AOXC_StakeStillLocked(uint256 currentTime, uint256 unlockTime);
    error AOXC_ThresholdNotMet(uint256 provided, uint256 threshold);
    error AOXC_InvalidThreshold();
    error AOXC_InvalidProposalState(uint256 proposalId, uint256 currentState);
    error AOXC_AlreadyActioned();
    error AOXC_VetoedProposal(uint256 proposalId, uint256 riskScore);
    error AOXC_EmergencyExitRestricted();
    error AOXC_InvalidLockTier();
    error AOXC_QuorumNotReached(uint256 currentVotes, uint256 requiredVotes);

    /*//////////////////////////////////////////////////////////////
                        GATEWAY & INTEROPERABILITY
    //////////////////////////////////////////////////////////////*/

    error AOXC_ChainNotSupported(uint256 chainId);
    error AOXC_BridgeLimitExceeded(uint256 amount, uint256 limit);
    error AOXC_BridgeCooldownActive(uint256 remainingTime);
    error AOXC_Gateway_MessageStale(bytes32 messageId);
    error AOXC_Gateway_InvalidSourceChain(uint16 chainId);

    /*//////////////////////////////////////////////////////////////
                        STRUCTURAL & UTILITY
    //////////////////////////////////////////////////////////////*/

    error AOXC_TransferFailed();
    error AOXC_ReentrancyIntercepted();
    error AOXC_SelfUpgradeOnly();
    error AOXC_UpgradeVerificationFailed(address implementation);
    error AOXC_LogicContractMismatch();
    error AOXC_CustomRevert(string reason);

    // --- ADDED IN V2.6.0 ---
    error AOXC_ArrayMismatch(); // Dizilerin uzunluğu uyuşmadığında (Slither FIX için kritik)
    error AOXC_ExecutionFailed(); // Dış çağrılarda revert alındığında
    error AOXC_ZeroValue(); // ETH değeri beklenen yerlerde 0 gelirse
}
