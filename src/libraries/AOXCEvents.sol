// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCEvents
 * @notice Canonical event registry for the entire AOXCAN ecosystem.
 * @dev Version: 2.2.8 - Full Sync: Added VaultWithdrawal and missing repair events.
 */
library AOXCEvents {
    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & VESTING
    //////////////////////////////////////////////////////////////*/

    event GovernorInitialized(address indexed aiNode, uint256 initialRiskScore, address admin);
    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /*//////////////////////////////////////////////////////////////
                    NEURAL & AI SENTINEL (CORE REPAIRS)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a neural signal (AI logic) is processed.
     */
    event NeuralSignalProcessed(bytes32 indexed signalType, bytes data);

    event KarujanNeuralVeto(uint256 indexed proposalId, uint256 riskScore);
    event NeuralInterception(uint256 indexed serialNo, uint256 riskScore, string diagnosticCode);
    event HeartbeatSynced(uint256 timestamp, uint256 nextExpected);
    event NeuralQuarantineTriggered(address indexed target, uint256 riskScore, uint256 cellId);
    event GlobalLockStateChanged(bool active, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                CELLULAR REGISTRY & ASSET PRODUCTION
    //////////////////////////////////////////////////////////////*/

    event CellSpawned(uint256 indexed cellId, bytes32 cellHash, bytes32 prevHash);
    event MemberOnboarded(address indexed member, uint256 indexed cellId, bool isMigration);
    event MemberExited(address indexed member, uint256 indexed cellId);
    event CellHealed(uint256 indexed cellId, address newMember, uint256 remainingVacancies);
    event CellQuarantineStatus(uint256 indexed cellId, bool isQuarantined, uint256 expiry);
    event MigrationBatchExecuted(uint256 startIdx, uint256 count, uint256 targetCellId);

    /**
     * @notice Emitted when a Sovereign Asset (Identity, RWA, etc) is minted.
     */
    event AssetProduced(address indexed owner, uint256 indexed assetId, uint8 assetType);

    /*//////////////////////////////////////////////////////////////
                        SYSTEM & REPAIR ENGINE
    //////////////////////////////////////////////////////////////*/

    event ComponentSynchronized(bytes32 indexed id, address addr);
    event SystemRepairInitiated(bytes32 indexed componentId, address indexed targetRepair);
    event PatchExecuted(bytes4 indexed selector, address indexed target, address logic);
    event AutonomousCorrectionFailed(bytes32 indexed componentId, string errorCode, uint256 retryCount);
    event RepairQueueUpdated(uint256 queueLength, uint256 headPointer);
    event EmergencyLogicTriggered(address indexed actor, bytes32 reason);
    event StateBackupSerialized(uint256 indexed serialNo, bytes32 stateHash, address indexed operator);

    /*//////////////////////////////////////////////////////////////
                        FISCAL & STAKING FLOW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when funds are deposited into the AOXVAULT.
     */
    event VaultFunded(address indexed sender, uint256 amount);

    /**
     * @notice Emitted on any treasury withdrawal (ETH or ERC20).
     * @dev Added in V2.2.8 to fix Slither synchronization issues.
     */
    event VaultWithdrawal(address indexed token, address indexed to, uint256 amount);

    event StakeDeposited(address indexed user, uint256 amount, uint256 lockPeriod);
    event StakeWithdrawn(address indexed user, uint256 principal, uint256 penalty);
    event PositionClosed(address indexed user, uint256 principal, uint256 yield);
    event ReputationUpdated(address indexed user, uint256 oldScore, uint256 newScore);
    event TreasuryInflow(address indexed source, uint256 amount, bytes32 tag);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        BRIDGE & GATEWAY (V2-SPEC)
    //////////////////////////////////////////////////////////////*/

    event MigrationInitiated(
        uint16 indexed dstChainId, address indexed from, address indexed to, uint256 amount, bytes32 migrationId
    );
    event MigrationInFinalized(uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 migrationId);
    event NeuralAnomalyNeutralized(bytes32 indexed migrationId, uint256 riskScore, string diagnosticCode);
}
