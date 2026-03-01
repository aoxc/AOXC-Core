// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCStorage
 * @author AOXCAN AI Architect
 * @notice Centralized storage architecture using ERC-7201 Namespaced Storage.
 * @dev Version 2.6.1 - Fix: PatchCore & SovereignAsset added for full system sync.
 */
abstract contract AOXCStorage {
    // --- SYSTEM IMMUTABLES ---
    uint256 public constant PROTOCOL_VERSION = 2;
    uint256 public constant MAX_CELL_MEMBERS = 99;
    uint256 public constant QUARANTINE_PERIOD = 48 hours;

    /*//////////////////////////////////////////////////////////////
                            DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev FIX: PatchCore merkezi yapıya taşındı.
     * Bu sayede hem BUILD hem REPAIR kontratları bu struct'ı tanır.
     */
    struct PatchCore {
        address targetContract; // 20 bytes | Slot 1
        bytes4 functionSelector; // 4 bytes  | Slot 1
        uint64 timestamp; // 8 bytes  | Slot 1

        address candidateLogic; // 20 bytes | Slot 2
        uint64 autoUnlockAt; // 8 bytes  | Slot 2
        bool isQuarantined; // 1 byte   | Slot 2
    }

    /**
     * @dev AOXBUILD için gerekli Asset yapısı merkezi storage'a eklendi.
     */
    struct SovereignAsset {
        uint256 assetId;
        string symbol;
        address tokenAddress;
        uint256 totalMinted;
        uint256 reserveRatio; // BPS
        bool isMintingActive;
    }

    struct CitizenRecord {
        uint256 citizenId;
        uint256 joinedAt;
        uint256 tier;
        uint256 reputation;
        uint256 lastPulse;
        uint256 totalVoted;
        bool isBlacklisted;
    }

    struct NeuralCellV2 {
        uint256 cellId;
        bytes32 cellHash;
        uint256 memberCount;
        bool isQuarantined;
        uint256 lockExpiry;
    }

    struct BackupRecord {
        uint256 serialNo;
        uint256 timestamp;
        bytes32 previousHash;
        bytes32 stateHash;
        address operator;
        string context;
    }

    struct ProposalCore {
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 riskScore;
        bool executed;
        bool vetoed;
        bool queued;
        bool exists;
    }

    struct StakePosition {
        uint256 principal;
        uint256 entryTimestamp;
        uint256 lockPeriod;
        bool isActive;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE BLOCKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @custom:storage-location erc7201:aoxc.main.storage.v2
     */
    struct MainStorage {
        address neuralSentinelNode;
        uint256 operationalNonce;
        uint256 lastPulseTimestamp;
        bool isSovereignVaultSealed;
        uint256 repairExpiry;
        address coreAssetToken;
        address treasury;
        bool isRepairModeActive;
        uint256 totalVaultBalance;
        uint256[42] _gap;
    }

    /**
     * @custom:storage-location erc7201:aoxc.registry.storage.v2
     */
    struct RegistryStorageV2 {
        uint256 totalOps;
        uint256 totalCells;
        uint256 activeCellPointer;
        bytes32 lastCellHash;
        mapping(uint256 => NeuralCellV2) cells;
        mapping(address => uint256) userToCellMap;
        mapping(address => CitizenRecord) citizenRecords;

        // BUILD/REPAIR Sync: AOXBUILD ve REPAIR'in ortak kullandığı alanlar
        mapping(bytes4 => mapping(address => PatchCore)) activePatches;
        mapping(uint256 => SovereignAsset) assets; // <-- FIX: AOXBUILD hatasını çözen satır

        uint256[] vacantCells;
        uint256 queueHead;
        mapping(uint256 => bool) isQueued;
        uint256[39] _gap; // Asset mapping eklendiği için gap 1 daha azaltıldı (40 -> 39)
    }

    /**
     * @custom:storage-location erc7201:aoxc.staking.storage.v2
     */
    struct StakingStorage {
        uint256 totalValueLocked;
        uint256 baseYieldRateBps;
        uint256 attritionPenaltyBps;
        uint256 minLockdownDuration;
        mapping(address => StakePosition[]) accountPositions;
        mapping(address => uint256) userReputation;
        uint256[45] _gap;
    }

    /**
     * @custom:storage-location erc7201:aoxc.nexus.storage.v2
     */
    struct NexusParamsV2 {
        mapping(uint256 => ProposalCore) proposals;
        mapping(uint256 => mapping(address => bool)) hasVoted;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumNumerator;
        bytes32 domainSeparator;
        uint256 backupCount;
        mapping(uint256 => BackupRecord) backups;
        uint256[40] _gap;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE SLOTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant MAIN_STORAGE_SLOT = 0x367f33d711912e841280879f8c09a803f2560810065090176d6c703126780a00;
    bytes32 internal constant REGISTRY_V2_SLOT = 0x78a44487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d01100;
    bytes32 internal constant NEXUS_V2_SLOT = 0x82a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00900;
    bytes32 internal constant STAKING_STORAGE_SLOT = 0x13d8e3d0929283f3e1898517228308873265789123456789abcdef1234567890;

    /*//////////////////////////////////////////////////////////////
                            STORAGE ACCESSORS
    //////////////////////////////////////////////////////////////*/

    function _getMainStorage() internal pure returns (MainStorage storage $) {
        bytes32 slot = MAIN_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    function _getRegistryV2() internal pure returns (RegistryStorageV2 storage $) {
        bytes32 slot = REGISTRY_V2_SLOT;
        assembly { $.slot := slot }
    }

    function _getNexusStore() internal pure returns (NexusParamsV2 storage $) {
        bytes32 slot = NEXUS_V2_SLOT;
        assembly { $.slot := slot }
    }

    function _getStakingStorage() internal pure returns (StakingStorage storage $) {
        bytes32 slot = STAKING_STORAGE_SLOT;
        assembly { $.slot := slot }
    }
}
