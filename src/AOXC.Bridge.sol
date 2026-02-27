// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/**
 * @title AOXC Sovereign Bridge Infrastructure V2.0.1
 * @notice Cross-chain migration engine with Neural Proof verification.
 * @dev [V2.0.1-OPTIMIZED]: Assembly hashing for zero-warning production.
 */
contract AOXCBridge is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct BridgeStorage {
        address aiSentinel;
        address aoxcToken;
        uint256 minBridgeQuantum;
        uint256 maxBridgeQuantum;
        uint256 bridgeFeeBps;
        address treasury;
        mapping(uint32 => bool) supportedChains;
        mapping(bytes32 => bool) processedTransfers;
        uint256 bridgeNonce;
        bool initialized;
    }

    bytes32 private constant BRIDGE_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00700;

    function _getBridgeStorage() internal pure returns (BridgeStorage storage $) {
        assembly { $.slot := BRIDGE_STORAGE_SLOT }
    }

    event AssetMigrationInitiated(
        address indexed actor, uint256 amount, uint32 indexed targetChainId, bytes32 indexed transferId
    );
    event AssetMigrationFinalized(address indexed actor, uint256 amount, bytes32 indexed transferId);

    constructor() {
        _disableInitializers();
    }

    function initializeBridge(address governor, address aiNode, address treasuryAddr, address tokenAddr)
        external
        initializer
    {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        BridgeStorage storage $ = _getBridgeStorage();
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, governor);

        $.aiSentinel = aiNode;
        $.aoxcToken = tokenAddr;
        $.treasury = treasuryAddr;
        $.minBridgeQuantum = 100 * 1e18; // Min 100 AOXC
        $.maxBridgeQuantum = 1_000_000 * 1e18; // Max 1M AOXC
        $.bridgeFeeBps = 30; // 0.3%
        $.initialized = true;
    }

    /**
     * @notice Initiates asset migration with assembly-optimized transferId generation.
     */
    function bridgeAssets(uint256 amount, uint32 targetChainId) external nonReentrant whenNotPaused {
        BridgeStorage storage $ = _getBridgeStorage();

        if (!$.supportedChains[targetChainId]) revert AOXCErrors.AOXC_ChainNotSupported(targetChainId);
        if (amount < $.minBridgeQuantum || amount > $.maxBridgeQuantum) {
            revert AOXCErrors.AOXC_ExceedsMaxTransfer(amount, $.maxBridgeQuantum);
        }

        uint256 nonce = $.bridgeNonce++;

        // [V2.0.1-OPTIMIZATION]: Memory-efficient assembly hashing
        bytes32 transferId;
        bytes memory data = abi.encode(msg.sender, amount, targetChainId, nonce, block.chainid);
        assembly {
            transferId := keccak256(add(data, 32), mload(data))
        }

        uint256 fee = (amount * $.bridgeFeeBps) / 10000;
        uint256 netAmount = amount - fee;

        if (fee > 0) IERC20($.aoxcToken).safeTransferFrom(msg.sender, $.treasury, fee);
        IERC20($.aoxcToken).safeTransferFrom(msg.sender, address(this), netAmount);

        emit AssetMigrationInitiated(msg.sender, amount, targetChainId, transferId);
    }

    /**
     * @notice Finalizes migration using Neural Proof (AI Signature)
     */
    function finalizeMigration(
        address actor,
        uint256 amount,
        uint32 sourceChainId,
        bytes32 transferId,
        bytes calldata neuralProof
    ) external nonReentrant whenNotPaused {
        BridgeStorage storage $ = _getBridgeStorage();

        if ($.processedTransfers[transferId]) revert AOXCErrors.AOXC_Neural_SignatureReused(transferId);

        bytes32 msgHash = keccak256(abi.encode(actor, amount, transferId, sourceChainId, address(this), block.chainid))
            .toEthSignedMessageHash();

        if (msgHash.recover(neuralProof) != $.aiSentinel) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }

        $.processedTransfers[transferId] = true;

        uint256 balance = IERC20($.aoxcToken).balanceOf(address(this));
        if (balance < amount) revert AOXCErrors.AOXC_InsufficientBalance(balance, amount);

        IERC20($.aoxcToken).safeTransfer(actor, amount);
        emit AssetMigrationFinalized(actor, amount, transferId);
    }

    function setChainSupport(uint32 chainId, bool status) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _getBridgeStorage().supportedChains[chainId] = status;
    }

    function pause() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
