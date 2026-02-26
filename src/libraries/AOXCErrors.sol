// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Global Error Library (Apex V26 Edition)
 * @author AOXCAN AI Architect & Senior Quantum Auditor
 * @notice Centralized gateway for protocol-wide parameterized custom errors.
 */
library AOXCErrors {
    /*//////////////////////////////////////////////////////////////
                IDENTITY & ACCESS CONTROL JURISDICTION
    //////////////////////////////////////////////////////////////*/

    error AOXC_Unauthorized(bytes32 role, address account);
    error AOXC_InvalidAddress();
    error AOXC_AlreadyInitialized();
    error AOXC_GlobalLockActive();
    error AOXC_InsufficientReputation(address target, uint256 current, uint256 required);

    /*//////////////////////////////////////////////////////////////
                    NEURAL & AI DIAGNOSTIC ERRORS
    //////////////////////////////////////////////////////////////*/

    error AOXC_Neural_IdentityForgery();
    error AOXC_Neural_StaleSignal(uint256 providedNonce, uint256 expectedNonce);
    error AOXC_Neural_HeartbeatLost(uint256 lastPulse, uint256 currentTime);
    error AOXC_Neural_RiskThresholdBreached(uint256 score, uint256 limit);
    error AOXC_Neural_SignatureReused(bytes32 sigHash);
    error AOXC_Neural_DomainMismatch(uint256 chainId, address contractAddr);
    error AOXC_Neural_BastionSealed(uint256 lockdownEnd);

    /*//////////////////////////////////////////////////////////////
                    MONETARY & FISCAL DEFENSE
    //////////////////////////////////////////////////////////////*/

    error AOXC_ZeroAmount();
    error AOXC_InsufficientBalance(uint256 available, uint256 required);
    error AOXC_ExceedsAllowance(uint256 available, uint256 required);
    error AOXC_Blacklisted(address account);
    error AOXC_InvalidBPS(uint256 provided, uint256 maxAllowed);
    error AOXC_ClawbackDenied();

    /*//////////////////////////////////////////////////////////////
                    VELOCITY & TEMPORAL BARRIERS
    //////////////////////////////////////////////////////////////*/

    error AOXC_ExceedsMaxTransfer(uint256 amount, uint256 limit);
    error AOXC_ExceedsDailyLimit(uint256 dailySpent, uint256 limit);
    error AOXC_InflationHardcapReached();
    error AOXC_TemporalBreach(uint256 currentBlock, uint256 lastBlock);
    error AOXC_MagnitudeLimitExceeded(uint256 impactBps, uint256 maxBps);

    /*//////////////////////////////////////////////////////////////
                    STAKING & GOVERNANCE SECURITY
    //////////////////////////////////////////////////////////////*/

    error AOXC_StakeNotActive();
    error AOXC_StakeStillLocked(uint256 currentTime, uint256 unlockTime);
    error AOXC_ThresholdNotMet(uint256 provided, uint256 threshold);
    error AOXC_InvalidProposalState(uint256 proposalId, uint256 currentState);
    error AOXC_VetoedProposal(uint256 proposalId, string reason);

    // EK SAVUNMA: Stake katmanı için özel eklenenler
    error AOXC_InvalidLockTier(uint256 providedDuration);
    error AOXC_TemporalCollision();

    /*//////////////////////////////////////////////////////////////
                    BRIDGE & INTEROPERABILITY ERRORS
    //////////////////////////////////////////////////////////////*/

    error AOXC_ChainNotSupported(uint256 chainId);
    error AOXC_BridgeLimitExceeded(uint256 amount, uint256 limit);

    /*//////////////////////////////////////////////////////////////
                        STRUCTURAL UTILITY
    //////////////////////////////////////////////////////////////*/

    error AOXC_TransferFailed();
    error AOXC_ReentrancyIntercepted();
    error AOXC_SelfUpgradeOnly();
    error AOXC_CustomRevert(string reason);
}
