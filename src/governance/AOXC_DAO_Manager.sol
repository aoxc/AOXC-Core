// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";

interface IAOXCRegistry {
    struct CitizenRecord {
        uint256 citizenId;
        uint256 joinedAt;
        uint256 tier;
        uint256 reputation;
        uint256 lastPulse;
        uint256 totalVoted;
        bool isBlacklisted;
    }
    function getCitizenInfo(address member) external view returns (CitizenRecord memory);
    function syncMemberTier(address member, uint256 stakedAmount) external;
}

contract AOXC_DAO_Manager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // --- IMMUTABLES ---
    IAOXCRegistry public immutable REGISTRY;
    IERC20 public immutable AOXC_TOKEN;
    bytes32 public immutable DOMAIN_SEPARATOR;

    // --- CONSTANTS ---
    bytes32 public constant CONFIRM_TYPEHASH = keccak256("Confirm(uint256 txIndex,uint256 nonce,uint256 deadline)");
    uint256 public constant PROPOSAL_LIFESPAN = 7 days;

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 totalPowerConfirmed;
        uint256 createdAt;
        bytes data;
        mapping(address => bool) isConfirmed;
    }

    uint256 public nextTxIndex;
    uint256 public minExecutionPower = 10_000 * 10 ** 18;

    mapping(uint256 => Transaction) public transactions;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastVoteTxIndex;
    mapping(address => uint256) public nonces;

    constructor(address registry_, address token_) {
        if (registry_ == address(0) || token_ == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        REGISTRY = IAOXCRegistry(registry_);
        AOXC_TOKEN = IERC20(token_);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("AOXC_DAO")),
                keccak256(bytes("2.1.9")),
                block.chainid,
                address(this)
            )
        );

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                             STAKING (CEI PATTERN)
    //////////////////////////////////////////////////////////////*/

    function joinAndStake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AOXCErrors.AOXC_CustomRevert("DAO: ZERO_AMOUNT");

        // 1. Effects: Güncellemeyi önce yap (Slither Safe)
        stakedBalances[msg.sender] += amount;

        // 2. Interactions: Dış aramayı sonra yap
        AOXC_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        REGISTRY.syncMemberTier(msg.sender, stakedBalances[msg.sender]);

        emit AOXCEvents.ComponentSynchronized(keccak256("DAO_MEMBER_STAKE"), msg.sender);
    }

    function exitStake(uint256 amount) external nonReentrant {
        if (stakedBalances[msg.sender] < amount) revert AOXCErrors.AOXC_CustomRevert("DAO: LOW_BALANCE");

        uint256 lastIdx = lastVoteTxIndex[msg.sender];
        if (lastIdx < nextTxIndex) {
            Transaction storage lastTx = transactions[lastIdx];
            if (!lastTx.executed && block.timestamp < lastTx.createdAt + PROPOSAL_LIFESPAN) {
                revert AOXCErrors.AOXC_CustomRevert("DAO: STAKE_LOCKED_BY_VOTE");
            }
        }

        // 1. Effects: Bakiyeyi düşür
        stakedBalances[msg.sender] -= amount;

        // 2. Interactions: Senkronize et ve parayı gönder
        REGISTRY.syncMemberTier(msg.sender, stakedBalances[msg.sender]);
        AOXC_TOKEN.safeTransfer(msg.sender, amount);

        emit AOXCEvents.ComponentSynchronized(keccak256("DAO_MEMBER_EXIT"), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE CORE
    //////////////////////////////////////////////////////////////*/

    function voteWithSignature(uint256 txIndex, uint256 deadline, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        if (block.timestamp > deadline) revert AOXCErrors.AOXC_CustomRevert("GOV: SIG_EXPIRED");

        bytes32 structHash;
        bytes32 typeHash = CONFIRM_TYPEHASH;
        uint256 nonce = nonces[msg.sender];

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, typeHash)
            mstore(add(ptr, 32), txIndex)
            mstore(add(ptr, 64), nonce)
            mstore(add(ptr, 96), deadline)
            structHash := keccak256(ptr, 128)
        }

        bytes32 hash = MessageHashUtils.toTypedDataHash(DOMAIN_SEPARATOR, structHash);
        address signer = hash.recover(signature);

        if (signer == address(0)) revert AOXCErrors.AOXC_CustomRevert("GOV: INVALID_SIG");
        // FIX: Relayer desteği için (signer == msg.sender) zorunluluğunu esnetebiliriz ama
        // güvenlik için burada signer'ın bizzat onay verdiğini biliyoruz.

        nonces[signer]++;

        IAOXCRegistry.CitizenRecord memory citizen = REGISTRY.getCitizenInfo(signer);
        if (citizen.tier < 2 || citizen.isBlacklisted) revert AOXCErrors.AOXC_Unauthorized("DAO_MEMBER", signer);

        Transaction storage txn = transactions[txIndex];
        if (txn.executed) revert AOXCErrors.AOXC_CustomRevert("GOV: ALREADY_EXECUTED");
        if (txn.isConfirmed[signer]) revert AOXCErrors.AOXC_CustomRevert("GOV: DUPLICATE_VOTE");
        if (block.timestamp > txn.createdAt + PROPOSAL_LIFESPAN) {
            revert AOXCErrors.AOXC_CustomRevert("GOV: PROPOSAL_EXPIRED");
        }

        uint256 power = (stakedBalances[signer] * citizen.tier) + (citizen.reputation * 1e18);

        txn.isConfirmed[signer] = true;
        txn.totalPowerConfirmed += power;
        lastVoteTxIndex[signer] = txIndex;

        emit AOXCEvents.ComponentSynchronized(keccak256("GOV_VOTE_CAST"), signer);

        if (txn.totalPowerConfirmed >= minExecutionPower) {
            _executeDecision(txIndex);
        }
    }

    function _executeDecision(uint256 txIndex) internal {
        Transaction storage txn = transactions[txIndex];

        // SECURITY FIX: Re-entrancy protection. Mark as executed BEFORE the call.
        txn.executed = true;

        (bool success,) = txn.to.call{value: txn.value}(txn.data);

        // CRITICAL FIX: Do NOT set executed = false on failure. Revert instead.
        if (!success) {
            revert AOXCErrors.AOXC_CustomRevert("GOV: EXECUTION_FAILED");
        }

        emit AOXCEvents.ComponentSynchronized(keccak256("GOV_ACTION_EXECUTED"), txn.to);
    }

    // Propose and other restricted ops...
    function proposeAction(address to, uint256 value, bytes calldata data)
        external
        whenNotPaused
        returns (uint256 txIndex)
    {
        // Governance checks here (onlyVerifiedCitizen etc.)
        txIndex = nextTxIndex++;
        Transaction storage txn = transactions[txIndex];
        txn.to = to;
        txn.value = value;
        txn.data = data;
        txn.executed = false;
        txn.createdAt = block.timestamp;

        emit AOXCEvents.ComponentSynchronized(keccak256("GOV_PROPOSAL_SUBMITTED"), to);
    }

    receive() external payable {}
}
