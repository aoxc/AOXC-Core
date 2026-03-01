// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCConstants
 * @author AOXCAN AI Architect & Governance Engine
 * @notice Immutable constants for AOXCORE Sovereign DAO.
 * @dev Version 2.2.0 – Restored legacy vault parameters and added future-proof extensions.
 */
library AOXCConstants {
    /*//////////////////////////////////////////////////////////////
                        PROTOCOL METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Genesis protocol version for V2 migration tracking
    bytes32 internal constant PROTOCOL_VERSION = "2.2.0-SOVEREIGN";

    /// @notice Top-level autonomous assembly identifier
    bytes32 internal constant DAO_NAME = "AOXCORE Sovereign Assembly";

    /// @notice Cryptographic tag for neural integrity verification modules
    bytes32 internal constant SYSTEM_INTEGRITY = "Neural-Bastion-V2.2";

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Governance role hash for DAO proposals and execution
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("AOXC.ROLE.GOVERNANCE");

    /// @notice Multi-sig guardian oversight role
    bytes32 internal constant GUARDIAN_ROLE = keccak256("AOXC.ROLE.GUARDIAN");

    /// @notice Automated repair & cellular reconstruction role
    bytes32 internal constant REPAIR_ROLE = keccak256("AOXC.ROLE.REPAIR_MASTER");

    /// @notice Circuit-breaker role for emergency events
    bytes32 internal constant EMERGENCY_ROLE = keccak256("AOXC.ROLE.EMERGENCY");

    /// @notice Role restricted to UUPS upgrade authorization
    bytes32 internal constant UPGRADER_ROLE = keccak256("AOXC.ROLE.UPGRADER");

    /// @notice AI Node (Neural Sentinel) verification role
    bytes32 internal constant SENTINEL_ROLE = keccak256("AOXC.ROLE.SENTINEL");

    /// @notice Treasury allocation & asset outflow management
    bytes32 internal constant TREASURY_ROLE = keccak256("AOXC.ROLE.TREASURY");

    /// @notice Swap engine & liquidity routing role
    bytes32 internal constant SWAP_ENGINE_ROLE = keccak256("AOXC.ROLE.SWAP_ENGINE");

    /// @notice Role for automated asset minting in AOXBUILD
    bytes32 internal constant MINTER_ROLE = keccak256("AOXC.ROLE.MINTER");

    /*//////////////////////////////////////////////////////////////
                        AI / NEURAL SENTINEL PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice AI risk thresholds scaled to Basis Points (BPS)
    uint256 internal constant AI_RISK_THRESHOLD_LOW = 2500;
    uint256 internal constant AI_RISK_THRESHOLD_MEDIUM = 5000;
    uint256 internal constant AI_RISK_THRESHOLD_HIGH = 8500;
    uint256 internal constant AI_RISK_THRESHOLD_TERMINAL = 9000;

    /// @notice Maximum duration for AI-triggered temporary freezes
    uint256 internal constant AI_MAX_FREEZE_DURATION = 26 hours;

    /// @notice Neural node heartbeat tolerance before flagged as non-responsive
    uint256 internal constant NEURAL_HEARTBEAT_TIMEOUT = 3 days;

    /// @notice Minimum deviation in BPS to trigger anomaly detection (5.00%)
    uint256 internal constant ANOMALY_SENSITIVITY_BPS = 500;

    /// @notice Maximum asset percentage AI can freeze autonomously (25.00%)
    uint256 internal constant AI_MAX_INTERCEPTION_BPS = 2500;

    /*//////////////////////////////////////////////////////////////
                        VAULT / TREASURY CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum interval between automated liquidity refills
    uint256 internal constant REFILL_COOLDOWN = 1 hours;

    /// @notice Maximum refill capacity per cycle as BPS of TVL
    uint256 internal constant MAX_REFILL_BPS = 500;

    /// @notice Mandatory delay for critical repair execution
    uint256 internal constant REPAIR_TIMELOCK = 24 hours;

    /// @notice Cooldown period between consecutive repairs
    uint256 internal constant REPAIR_COOLDOWN = 12 hours;

    /// @notice Reports required before a component is flagged as faulty
    uint256 internal constant REPAIR_THRESHOLD_COUNT = 3;

    /*//////////////////////////////////////////////////////////////
                        CELLULAR DAO & REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum members per Neural Cell to prevent governance bloat
    uint256 internal constant MAX_CELL_MEMBERS = 99;

    /// @notice Quarantine duration for newly migrated or created entities
    uint256 internal constant QUARANTINE_DURATION = 48 hours;

    /// @notice Maximum entities processed per batch to optimize gas
    uint256 internal constant MIGRATION_BATCH_SIZE = 50;

    /*//////////////////////////////////////////////////////////////
                        FISCAL & MONETARY LIMITS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard denominator for percentage arithmetic (100.00%)
    uint256 internal constant BPS_DENOMINATOR = 10000;

    /// @notice Maximum percentage of total supply per transfer (2.00%)
    uint256 internal constant MAX_TRANSFER_BPS = 200;

    /// @notice Maximum annual minting cap (3.00%)
    uint256 internal constant MAX_MINT_PER_YEAR_BPS = 300;

    /// @notice Global outflow velocity limit (15.00%)
    uint256 internal constant GLOBAL_VELOCITY_LIMIT_BPS = 1500;

    /// @notice Minimum interval between reward distribution cycles
    uint256 internal constant MIN_MINT_INTERVAL = 365 days;

    /// @notice Grace period for annual pulse execution
    uint256 internal constant PULSE_GRACE_PERIOD = 7 days;

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE ENGINE
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum voting power threshold for proposal validity (4.00%)
    uint256 internal constant GOVERNANCE_QUORUM_BPS = 400;

    /// @notice Minimum timelock for proposal execution
    uint256 internal constant MIN_TIMELOCK_DELAY = 3 days;

    /// @notice Maximum timelock for proposal execution
    uint256 internal constant MAX_TIMELOCK_DELAY = 30 days;

    /*//////////////////////////////////////////////////////////////
                        STAKING / PEX POLICY
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimal stake duration for eligibility
    uint256 internal constant MIN_STAKE_DURATION = 90 days;

    /// @notice Maximum stake duration / reward multiplier cap
    uint256 internal constant MAX_STAKE_DURATION = 1095 days;

    /// @notice Base Annual Percentage Rate (APR) in BPS (6.00%)
    uint256 internal constant STAKING_REWARD_APR_BPS = 600;

    /// @notice Early withdrawal slashing penalty (10.00%)
    uint256 internal constant ATTRITION_PENALTY_BPS = 1000;

    /// @notice Reputation-based yield multiplier (15.00%)
    uint256 internal constant REPUTATION_MULTIPLIER_BPS = 1500;

    /// @notice Minimum reputation to produce sovereign assets
    uint256 internal constant MINTING_REPUTATION_THRESHOLD = 500;

    /*//////////////////////////////////////////////////////////////
                        NETWORK / DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Target chain ID for X-Layer deployments
    uint256 internal constant CHAIN_ID_X_LAYER = 196;

    /// @notice Minimum balance considered significant for processing
    uint256 internal constant DUST_THRESHOLD = 1e15;
}
