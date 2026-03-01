// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/**
 * @title IAOXNEXUS
 * @author AOXCAN AI Architect
 * @notice Master interface for the AOXCORE Governance Nexus (V2.6.0).
 * @dev Enforces neural risk-weighted voting and autonomous AI veto mechanisms.
 */
interface IAOXNEXUS {
    /**
     * @notice Proposal lifecycle states including Karujan-specific AI terminal states.
     */
    enum ProposalState {
        Pending, // 0
        Active, // 1
        Canceled, // 2
        Defeated, // 3
        Succeeded, // 4
        Queued, // 5
        Expired, // 6
        Executed, // 7
        NeuralVetoed, // 8 (Karujan AI Interception)
        RepairPending // 9 (Post-attack recovery mode)
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

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

    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event KarujanNeuralVeto(uint256 indexed proposalId, uint256 riskScore);

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE VIEWS
    //////////////////////////////////////////////////////////////*/

    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalRiskScore(uint256 proposalId) external view returns (uint256);
    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function quorum(uint256 timepoint) external view returns (uint256);
    function getNexusLockState() external view returns (bool isLocked, uint256 cooldownRemaining);

    /*//////////////////////////////////////////////////////////////
                         CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        external
        returns (uint256 proposalId);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @notice Intercepts a malicious proposal before execution via AI cryptographic proof.
     */
    function processNeuralVeto(uint256 proposalId, uint256 riskScore, bytes calldata aiProof) external;

    /*//////////////////////////////////////////////////////////////
                            VOTING ENGINE
    //////////////////////////////////////////////////////////////*/

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
        returns (uint256 weight);
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight);
}
