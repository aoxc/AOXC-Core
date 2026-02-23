// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Global Error Library
 * @author AOXC Protocol
 * @notice Centralized library for all protocol-wide custom errors.
 * @dev Using custom errors instead of strings saves significant gas and provides
 * clear failure categories for off-chain tools.
 */
library AOXCErrors {
    /*//////////////////////////////////////////////////////////////
                            GENERAL ERRORS
    //////////////////////////////////////////////////////////////*/
    error AOXC_Unauthorized(); // Generic access denial
    error AOXC_InvalidAddress(); // Zero address or blacklisted
    error AOXC_ZeroAmount(); // Input value is 0
    error AOXC_AlreadyInitialized(); // Initializer called twice
    error AOXC_AlreadyProcessed(); // Message or action repeat
    error AOXC_GlobalLockActive(); // Circuit breaker is engaged

    /*//////////////////////////////////////////////////////////////
                            TOKEN & FINANCE
    //////////////////////////////////////////////////////////////*/
    error AOXC_InsufficientBalance(); // Not enough funds
    error AOXC_TransferFailed(); // Low-level call failure
    error AOXC_ExceedsAllowance(); // ERC20 approval issue
    error AOXC_Blacklisted(); // Account restricted from transfer
    error AOXC_InvalidBPS(); // Basis points > 10,000

    /*//////////////////////////////////////////////////////////////
                            TREASURY & LOCKS
    //////////////////////////////////////////////////////////////*/
    error AOXC_CliffNotReached(); // 6-year lock still active
    error AOXC_LimitExceeded(); // 6% annual withdrawal cap hit
    error AOXC_WindowExpired(); // Annual spending window closed
    error AOXC_ForbiddenDuringLock(); // Permanent LP lock active

    /*//////////////////////////////////////////////////////////////
                            STAKING ENGINE
    //////////////////////////////////////////////////////////////*/
    error AOXC_InvalidLockTier(); // Duration not 3,6,9,12 months
    error AOXC_StakeNotActive(); // Position already withdrawn
    error AOXC_EarlyWithdrawalBlocked(); // Policy-based exit restriction
    error AOXC_NoRewardsToClaim(); // Yield balance is 0

    /*//////////////////////////////////////////////////////////////
                            BRIDGE & OMNICHAIN
    //////////////////////////////////////////////////////////////*/
    error AOXC_ChainNotSupported(); // Destination chain not white-listed
    error AOXC_BridgeDailyLimitHit(); // Cross-chain volume cap reached
    error AOXC_InsufficientCollateral(); // Bridge vault lacks backing
    error AOXC_MessageIDConflict(); // Nonce already used (Double Spend)

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE
    //////////////////////////////////////////////////////////////*/
    error AOXC_InvalidProposalState(); // Voting not active or expired
    error AOXC_ThresholdNotMet(); // Proposer lacks sufficient votes
    error AOXC_QuorumNotReached(); // Not enough total participation
    error AOXC_ActionNotQueued(); // Timelock delay not respected
}
