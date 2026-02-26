// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Sovereign Constants
 * @notice Provides an immutable computational framework for the AOXC Protocol.
 */
library AOXCConstants {
    /*//////////////////////////////////////////////////////////////
                    PROTOCOL METADATA & ONTOLOGY
    //////////////////////////////////////////////////////////////*/

    string internal constant PROTOCOL_VERSION = "2.6.0-Sovereign-Apex";
    string internal constant DAO_NAME = "AOXC Sovereign Assembly";
    string internal constant AI_SENTINEL_ID = "AOXC-SENTINEL-ALPHA";

    /*//////////////////////////////////////////////////////////////
                    ACCREDITATION & ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 internal constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 internal constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 internal constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /*//////////////////////////////////////////////////////////////
                    CORE INFRASTRUCTURE ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice [FIX]: Checksum verified address to satisfy Solc 0.8.33 requirements.
     */
    address internal constant AOXC_TOKEN_ADDRESS = 0x58B688313A7DeA87570417937a092A9587428410;

    /*//////////////////////////////////////////////////////////////
                    GOVERNANCE & TEMPORAL CONSTRAINTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant GOVERNANCE_QUORUM_BPS = 400;
    uint256 internal constant PROPOSAL_THRESHOLD = 100_000_000 * 1e18;

    uint256 internal constant MIN_TIMELOCK_DELAY = 2 days;
    uint256 internal constant MAX_TIMELOCK_DELAY = 30 days;
    uint256 internal constant GRACE_PERIOD = 14 days;

    /*//////////////////////////////////////////////////////////////
                    FISCAL PYLONS & MONETARY POLICY
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant ABSOLUTE_MAX_TAX_BPS = 1500;
    uint256 internal constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;
    uint256 internal constant MAX_MINT_PER_YEAR_BPS = 200;

    /*//////////////////////////////////////////////////////////////
                NEURAL SENTINEL & AUTONOMOUS PARAMETERS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant AI_MAX_FREEZE_DURATION = 26 hours;
    uint256 internal constant AI_RISK_THRESHOLD_LOW = 2500;
    uint256 internal constant AI_RISK_THRESHOLD_MEDIUM = 5000;
    uint256 internal constant AI_RISK_THRESHOLD_HIGH = 8500;

    /*//////////////////////////////////////////////////////////////
                NETWORK ARCHITECTURE & INTEROPERABILITY
    //////////////////////////////////////////////////////////////*/

    uint16 internal constant CHAIN_ID_X_LAYER = 196;
    uint24 internal constant LP_FEE_TIER_BASE = 3000;
    uint256 internal constant DORMANT_ADMIN_THRESHOLD = 180 days;
}
