// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCGovernor Sovereign Interface V2.6
 * @author AOXC AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Neural Defense Interface for Autonomous DAO Governance.
 * @dev Enforces risk-weighted voting and autonomous AI veto mechanisms to ensure long-term solvency.
 */
interface IAOXCGovernor {
    /**
     * @notice Proposal lifecycle states including the Neural Apex terminal state.
     */
    enum ProposalState {
        Pending, // Layer 1: Waiting for vote delay
        Active, // Layer 2: Voting in progress
        Canceled, // User-retracted
        Defeated, // Quorum or votes failed
        Succeeded, // Governance passed
        Queued, // Layer 9: Entered Timelock Bastion
        Expired, // Grace period exceeded
        Executed, // Layer 26: Finalized
        NeuralVetoed // Layer 21: Terminated by AI Sentinel Intervention
    }

    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
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

    event VoteCast(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);

    /**
     * @notice Emitted when the AI Sentinel autonomously neutralizes a malicious proposal.
     */
    event NeuralProposalInterception(uint256 indexed proposalId, uint256 riskScore, string reason);

    /*//////////////////////////////////////////////////////////////
                        V26 NEURAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);

    /**
     * @notice Layer 15: Retrieves the predictive risk score assigned to a proposal by the AI.
     */
    function proposalRiskScore(uint256 proposalId) external view returns (uint256);

    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function quorum(uint256 timepoint) external view returns (uint256);

    /**
     * @notice Layer 23: Returns the status of the 26-Hour Sovereignty Lockdown.
     */
    function getGovernanceLockdownState()
        external
        view
        returns (bool isLocked, uint256 timeRemaining);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a proposal while enforcing the Reputation Gate.
     * @dev Layer 11-15: Requires minimum reputation score from the IAOXC interface.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @notice Forces an operation into the Timelock Bastion after reaching neural consensus.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);

    /**
     * @notice Finalizes execution after the 26-day neural dilation period has expired.
     * @dev Layer 26: Verifies that no NeuralVeto has been issued during the delay.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @notice [Layer 21] AI Sovereign Veto: Instantly terminates a proposal via ECDSA AI Signal.
     * @param proposalId The ID of the proposal to neutralize.
     * @param riskScore The score that triggered the veto (>= 9000).
     * @param aiSignature Cryptographic proof signed by the AI Sentinel node.
     */
    function processNeuralVeto(uint256 proposalId, uint256 riskScore, bytes calldata aiSignature)
        external;

    /*//////////////////////////////////////////////////////////////
                                VOTING ENGINE
    //////////////////////////////////////////////////////////////*/

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
        returns (uint256 weight);

    /**
     * @notice Allows gasless voting via EIP-712 signatures, verified against the Neural Pulse.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight);
}
