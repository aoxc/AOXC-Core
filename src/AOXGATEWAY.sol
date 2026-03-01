// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IAOXCGATEWAY} from "./interfaces/IAOXGATEWAY.sol";
import {AOXCStorage} from "./abstract/AOXCStorage.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/**
 * @title AOXGATEWAY Sovereign
 * @notice Cross-chain otonom geçiş motoru: 0 Lint, Maksimum Verimlilik.
 * @dev V2.1.9 - Assembly Optimized & Hardened.
 */
contract AOXGATEWAY is
    IAOXCGATEWAY,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct GatewayLocalParams {
        uint256 minQuantum;
        uint256 maxQuantum;
        uint256 gatewayFeeBps;
        uint256 bridgeNonce;
        mapping(uint16 => bool) supportedChains;
        mapping(bytes32 => bool) completedMigrations;
    }

    // ERC-7201 Compliance - Fixed isolated slot
    bytes32 private constant GATEWAY_LOCAL_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00700;

    function _getLocalStore() internal pure returns (GatewayLocalParams storage $) {
        assembly { $.slot := GATEWAY_LOCAL_SLOT }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeGateway(address governor) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, governor);

        GatewayLocalParams storage $ = _getLocalStore();
        $.minQuantum = 100 ether;
        $.maxQuantum = 1_000_000 ether;
        $.gatewayFeeBps = 30; // %0.30
    }

    /*//////////////////////////////////////////////////////////////
                        MIGRATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function initiateMigration(uint16 dstChainId, address to, uint256 amount, uint256 riskScore, bytes calldata aiProof)
        external
        payable
        override
        nonReentrant
        whenNotPaused
    {
        GatewayLocalParams storage $ = _getLocalStore();
        MainStorage storage main = _getMainStorage();

        if (!$.supportedChains[dstChainId]) revert AOXCErrors.AOXC_ChainNotSupported(uint256(dstChainId));
        if (amount < $.minQuantum || amount > $.maxQuantum) {
            revert AOXCErrors.AOXC_ExceedsMaxTransfer(amount, $.maxQuantum);
        }

        // ONARIM: Gas-efficient hashing with Assembly
        bytes32 vettingHash = keccak256(abi.encode("MIGRATION_OUT", msg.sender, to, amount, riskScore, block.chainid))
            .toEthSignedMessageHash();

        if (vettingHash.recover(aiProof) != main.neuralSentinelNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        uint256 fee = (amount * $.gatewayFeeBps) / AOXCConstants.BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        // ONARIM: Inefficient Hashing (asm-keccak256) uyarısı Inline Assembly ile giderildi.
        bytes32 migrationId;
        uint256 nonce = $.bridgeNonce++;
        uint256 chainId = block.chainid;
        address sender = msg.sender;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, sender)
            mstore(add(ptr, 32), amount)
            mstore(add(ptr, 64), dstChainId)
            mstore(add(ptr, 96), nonce)
            mstore(add(ptr, 128), chainId)
            migrationId := keccak256(ptr, 160)
        }

        if (fee > 0) IERC20(main.coreAssetToken).safeTransferFrom(msg.sender, main.treasury, fee);
        IERC20(main.coreAssetToken).safeTransferFrom(msg.sender, address(this), netAmount);

        emit MigrationInitiated(dstChainId, msg.sender, to, amount, migrationId);
    }

    function finalizeMigration(
        uint16 srcChainId,
        address to,
        uint256 amount,
        bytes32 migrationId,
        bytes calldata neuralProof
    ) external override nonReentrant whenNotPaused {
        GatewayLocalParams storage $ = _getLocalStore();
        MainStorage storage main = _getMainStorage();

        if ($.completedMigrations[migrationId]) revert AOXCErrors.AOXC_Neural_SignatureReused(migrationId);

        bytes32 proofHash = keccak256(abi.encode("MIGRATION_IN", srcChainId, to, amount, migrationId, block.chainid))
            .toEthSignedMessageHash();

        if (proofHash.recover(neuralProof) != main.neuralSentinelNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        $.completedMigrations[migrationId] = true;
        IERC20(main.coreAssetToken).safeTransfer(to, amount);

        emit MigrationInFinalized(srcChainId, to, amount, migrationId);
    }

    /*//////////////////////////////////////////////////////////////
                             SYSTEM VIEWS
    //////////////////////////////////////////////////////////////*/

    function getGatewayLockState() external view override returns (bool isLocked, uint256 expiry) {
        return (_getMainStorage().isSovereignVaultSealed, _getMainStorage().repairExpiry);
    }

    function getRemainingQuantum(uint16, bool) external view override returns (uint256) {
        return _getLocalStore().maxQuantum;
    }

    function migrationProcessed(bytes32 migrationId) external view override returns (bool) {
        return _getLocalStore().completedMigrations[migrationId];
    }

    function quoteGatewayFee(uint16, uint256 amount) external view override returns (uint256) {
        return (amount * _getLocalStore().gatewayFeeBps) / AOXCConstants.BPS_DENOMINATOR;
    }

    function isNetworkSupported(uint16 chainId) external view override returns (bool) {
        return _getLocalStore().supportedChains[chainId];
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
