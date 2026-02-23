// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Protocol Constants
 * @author AOXC Protocol
 * @notice Centralized repository for all fixed parameters, roles, and thresholds.
 * @dev Storing constants in a library reduces deployment costs and ensures
 * mathematical consistency across the entire AOXC ecosystem.
 */
library AOXCConstants {
    /*//////////////////////////////////////////////////////////////
                            PROTOCOL VERSIONING
    //////////////////////////////////////////////////////////////*/
    string public constant PROTOCOL_VERSION = "2.0.0-Titanium";

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL ROLES
    //////////////////////////////////////////////////////////////*/
    // Roles are defined as keccak256 hashes of their string descriptors.
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE"); // DAO Executive
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE"); // Emergency Multisig
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE"); // Bridge Relayers/Operators
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); // Upgrade Authority
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // Supply Management
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE"); // AML/Blacklist Management

    /*//////////////////////////////////////////////////////////////
                            TIME CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant SIX_YEARS = 2190 days; // 6 * 365 days
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant MIN_VOTING_DELAY = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 14 days;

    /*//////////////////////////////////////////////////////////////
                            FINANCIAL LIMITS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant BPS_DENOMINATOR = 10_000; // 100% = 10,000 basis points
    uint256 public constant ANNUAL_CAP_BPS = 600; // 6% annual withdrawal limit
    uint256 public constant MAX_TAX_BPS = 1_000; // Max possible fee (10%)
    uint256 public constant QUORUM_BPS = 400; // 4% default quorum requirement

    /*//////////////////////////////////////////////////////////////
                            STAKING PARAMETERS
    //////////////////////////////////////////////////////////////*/
    // Penalty scales for early withdrawal based on lock tiers
    uint256 public constant EARLY_EXIT_PENALTY_BPS = 5_000; // 50% burn on early exit

    // Lock Tiers in Seconds
    uint256 public constant TIER_3_MONTHS = 90 days;
    uint256 public constant TIER_6_MONTHS = 180 days;
    uint256 public constant TIER_9_MONTHS = 270 days;
    uint256 public constant TIER_12_MONTHS = 360 days;

    /*//////////////////////////////////////////////////////////////
                            BRIDGE PARAMETERS
    //////////////////////////////////////////////////////////////*/
    uint16 public constant CHAIN_ID_X_LAYER = 196; // X Layer Network ID
    uint256 public constant DEFAULT_DAILY_BRIDGE_LIMIT = 1_000_000 * 1e18; // 1M Tokens

    /*//////////////////////////////////////////////////////////////
                            VOTING & GOVERNANCE
    //////////////////////////////////////////////////////////////*/
    // Proposal threshold: 0.1% of total supply required to submit a proposal
    uint256 public constant PROPOSAL_THRESHOLD_BPS = 10;
}
