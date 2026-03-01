// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// AOXC INFRASTRUCTURE
// SLITHER-FIX: Import yolları senin tree yapına ve remappings'e göre güncellendi
import {IAOXNEXUS} from "aox-interfaces/IAOXNEXUS.sol";
import {AOXCStorage} from "./abstract/AOXCStorage.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";
import {AOXCEvents} from "./libraries/AOXCEvents.sol";

/**
 * @title AOXNEXUS Sovereign
 * @notice Autonomous DAO Governance Engine.
 * @dev V2.3.8 - Fixed Import Paths, ASM Safe, Neural Veto Integrated.
 */
contract AOXNEXUS is
    IAOXNEXUS,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    AOXCStorage
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using Address for address;

    // --- CONSTANTS ---
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(uint256 proposalId,uint8 support)");

    // --- MODIFIERS ---

    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    function _checkGovernance() internal view {
        // AOXC Governance modelinde sadece kontratın kendisi (proposal üzerinden) yetkili olabilir
        if (msg.sender != address(this)) {
            revert AOXCErrors.AOXC_Unauthorized(DEFAULT_ADMIN_ROLE, msg.sender);
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeGovernor(address _initialAdmin) external initializer {
        if (_initialAdmin == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, address(this));

        NexusParamsV2 storage $ = _getNexusStore();
        $.votingPeriod = 3 days;
        $.votingDelay = 1 hours;
        $.quorumNumerator = AOXCConstants.GOVERNANCE_QUORUM_BPS;

        $.domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                keccak256("AOXNEXUS"),
                keccak256("2.3.0"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL VETO OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function processNeuralVeto(uint256 proposalId, uint256 riskScore, bytes calldata aiProof) external override {
        MainStorage storage main = _getMainStorage();
        ProposalCore storage p = _getNexusStore().proposals[proposalId];

        if (!p.exists) revert AOXCErrors.AOXC_CustomRevert("NEXUS: NULL_PROPOSAL");
        if (p.executed || p.vetoed) revert AOXCErrors.AOXC_CustomRevert("NEXUS: FINALIZED");

        bytes32 msgHash =
            keccak256(abi.encode(proposalId, riskScore, "VETO", block.chainid, address(this))).toEthSignedMessageHash();

        if (msgHash.recover(aiProof) != main.neuralSentinelNode) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        if (riskScore < AOXCConstants.AI_RISK_THRESHOLD_HIGH) {
            revert AOXCErrors.AOXC_CustomRevert("NEXUS: RISK_THRESHOLD_NOT_MET");
        }

        p.vetoed = true;
        p.riskScore = riskScore;

        emit AOXCEvents.KarujanNeuralVeto(proposalId, riskScore);
    }

    /*//////////////////////////////////////////////////////////////
                            DAO EXECUTION
    //////////////////////////////////////////////////////////////*/

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable override nonReentrant returns (uint256) {
        uint256 id = hashProposal(targets, values, calldatas, descriptionHash);
        ProposalCore storage p = _getNexusStore().proposals[id];

        // 1. State Check
        ProposalState currentState = state(id);
        if (currentState != ProposalState.Succeeded && !p.queued) {
            revert AOXCErrors.AOXC_CustomRevert("NEXUS: INVALID_STATE");
        }

        // 2. Global Lock Enforcement
        if (_getMainStorage().isSovereignVaultSealed && !_isUnsealCall(targets, calldatas)) {
            revert AOXCErrors.AOXC_GlobalLockActive();
        }

        p.executed = true;

        if (targets.length == 0 || targets.length != values.length || targets.length != calldatas.length) {
            revert AOXCErrors.AOXC_ArrayMismatch();
        }

        // 3. Execution Loop
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

            // SLITHER-FIX: Açıkça returnData yakalanıp ignore ediliyor (unused-return fix)
            bytes memory returnData = Address.functionCallWithValue(targets[i], calldatas[i], values[i]);
            (returnData);
        }

        emit AOXCEvents.ProposalExecuted(id);
        return id;
    }

    /*//////////////////////////////////////////////////////////////
                            VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function castVoteBySig(uint256 id, uint8 support, uint8 v, bytes32 r, bytes32 sSig)
        external
        override
        returns (uint256)
    {
        bytes32 structHash;
        bytes32 typeHash = VOTE_TYPEHASH;

        // SLITHER-FIX: Assembly optimizasyonu ile memory safety sağlandı
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, typeHash)
            mstore(add(ptr, 0x20), id)
            mstore(add(ptr, 0x40), support)
            structHash := keccak256(ptr, 0x60)
        }

        bytes32 h = MessageHashUtils.toTypedDataHash(_getNexusStore().domainSeparator, structHash);
        address signer = h.recover(v, r, sSig);

        if (signer == address(0)) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        return _executeVote(signer, id, support);
    }

    function _executeVote(address voter, uint256 id, uint8 support) internal returns (uint256) {
        NexusParamsV2 storage $ = _getNexusStore();
        ProposalCore storage p = $.proposals[id];

        if (state(id) != ProposalState.Active) revert AOXCErrors.AOXC_CustomRevert("NEXUS: VOTING_NOT_ACTIVE");
        if ($.hasVoted[id][voter]) revert AOXCErrors.AOXC_CustomRevert("NEXUS: ALREADY_VOTED");

        // Cell Registry kontrolü
        uint256 weight = _getRegistryV2().userToCellMap[voter] != 0 ? 1 : 0;
        if (weight == 0) revert AOXCErrors.AOXC_Cell_InvalidMember(voter);

        $.hasVoted[id][voter] = true;
        if (support == 1) p.forVotes += weight;
        else p.againstVotes += weight;

        return weight;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function state(uint256 id) public view override returns (ProposalState) {
        NexusParamsV2 storage $ = _getNexusStore();
        ProposalCore storage p = $.proposals[id];

        if (!p.exists) return ProposalState.Canceled;
        if (p.vetoed) return ProposalState.NeuralVetoed;
        if (p.executed) return ProposalState.Executed;

        uint256 currentTs = block.timestamp;
        if (currentTs < p.startTime) return ProposalState.Pending;
        if (currentTs <= p.endTime) return ProposalState.Active;

        return (p.forVotes > p.againstVotes && (p.forVotes + p.againstVotes) >= $.quorumNumerator)
            ? ProposalState.Succeeded
            : ProposalState.Defeated;
    }

    function hashProposal(address[] memory t, uint256[] memory v, bytes[] memory c, bytes32 d)
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(t, v, c, d)));
    }

    function propose(address[] memory t, uint256[] memory v, bytes[] memory c, string memory d)
        external
        override
        returns (uint256)
    {
        if (_getRegistryV2().userToCellMap[msg.sender] == 0) {
            revert AOXCErrors.AOXC_Cell_InvalidMember(msg.sender);
        }

        uint256 id = hashProposal(t, v, c, keccak256(bytes(d)));
        NexusParamsV2 storage $ = _getNexusStore();

        if ($.proposals[id].exists) revert AOXCErrors.AOXC_CustomRevert("NEXUS: DUPLICATE_PROPOSAL");

        ProposalCore storage p = $.proposals[id];
        p.proposer = msg.sender;
        p.exists = true;
        p.startTime = block.timestamp + $.votingDelay;
        p.endTime = p.startTime + $.votingPeriod;

        emit AOXCEvents.ProposalCreated(id, msg.sender, t, v, c, p.startTime, p.endTime, d);
        return id;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _isUnsealCall(address[] memory t, bytes[] memory c) internal view returns (bool) {
        for (uint256 i = 0; i < t.length; i++) {
            if (t[i] == address(this) && bytes4(c[i]) == this.emergencyUnseal.selector) return true;
        }
        return false;
    }

    function emergencyUnseal() external onlyGovernance {
        _getMainStorage().isSovereignVaultSealed = false;
        emit AOXCEvents.GlobalLockStateChanged(false, 0);
    }

    function _authorizeUpgrade(address) internal view override onlyGovernance {}

    function getVotes(address a, uint256) public view override returns (uint256) {
        return _getRegistryV2().userToCellMap[a] != 0 ? 1 : 0;
    }

    function quorum(uint256) public view override returns (uint256) {
        return _getNexusStore().quorumNumerator;
    }

    function queue(address[] memory t, uint256[] memory v, bytes[] memory c, bytes32 d)
        external
        override
        returns (uint256)
    {
        uint256 id = hashProposal(t, v, c, d);
        if (state(id) != ProposalState.Succeeded) revert AOXCErrors.AOXC_CustomRevert("NEXUS: NOT_SUCCEEDED");
        _getNexusStore().proposals[id].queued = true;
        emit AOXCEvents.ProposalQueued(id, block.timestamp);
        return id;
    }

    function castVote(uint256 id, uint8 s) public override returns (uint256) {
        return _executeVote(msg.sender, id, s);
    }

    function castVoteWithReason(uint256 id, uint8 s, string calldata) external override returns (uint256) {
        return castVote(id, s);
    }

    function proposalProposer(uint256 id) external view override returns (address) {
        return _getNexusStore().proposals[id].proposer;
    }

    function proposalRiskScore(uint256 id) external view override returns (uint256) {
        return _getNexusStore().proposals[id].riskScore;
    }

    function getNexusLockState() external view override returns (bool, uint256) {
        return (_getMainStorage().isSovereignVaultSealed, _getMainStorage().repairExpiry);
    }

    function proposalSnapshot(uint256 id) external view override returns (uint256) {
        return _getNexusStore().proposals[id].startTime;
    }

    function proposalDeadline(uint256 id) external view override returns (uint256) {
        return _getNexusStore().proposals[id].endTime;
    }
}
