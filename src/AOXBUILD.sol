// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCStorage} from "aox-core/abstract/AOXCStorage.sol";
import {AOXCConstants} from "aox-libraries/AOXCConstants.sol";
import {AOXCErrors} from "aox-libraries/AOXCErrors.sol";
import {AOXCEvents} from "aox-libraries/AOXCEvents.sol";
import {IAOX_AUTO_REPAIR} from "aox-interfaces/IAOX_AUTO_REPAIR.sol";

/**
 * @title AOXBUILD Sovereign
 * @dev V2.2.8 - Slither Optimized: Enhanced repair engine security and identity protection.
 */
contract AOXBUILD is
    Initializable,
    UUPSUpgradeable,
    AccessManagerUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage,
    IAOX_AUTO_REPAIR
{
    using Strings for uint256;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    enum AssetType {
        IDENTITY,
        SBT_BADGE,
        SOVEREIGN_ASSET
    }

    string public baseAssetURI;
    address public aiNode;
    address public auditVoice;
    uint256 public nextAssetId;

    mapping(uint256 => bool) public anomalyLedger;
    mapping(bytes4 => bool) public isReserved;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeBuild(address admin, string memory uri, address aiNode_, address auditVoice_)
        external
        initializer
    {
        if (admin == address(0) || aiNode_ == address(0) || auditVoice_ == address(0)) {
            revert AOXCErrors.AOXC_InvalidAddress();
        }

        __AccessManager_init(admin);
        __ERC721_init("AOXC Universal Assets", "AOX-X");
        __ReentrancyGuard_init();

        baseAssetURI = uri;
        aiNode = aiNode_;
        auditVoice = auditVoice_;

        isReserved[this.liftQuarantine.selector] = true;
        isReserved[this.executePatch.selector] = true;
        isReserved[this.upgradeToAndCall.selector] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        PRODUCTION & IDENTITY
    //////////////////////////////////////////////////////////////*/

    function buildAsset(
        address to,
        AssetType aType,
        bytes32,
        /* doc */
        uint256 initialVal
    )
        external
        nonReentrant
        returns (uint256 assetId)
    {
        _checkAoxcRole(AOXCConstants.GUARDIAN_ROLE);
        if (to == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        RegistryStorageV2 storage s = _getRegistryV2();

        if (aType == AssetType.IDENTITY && s.citizenRecords[to].citizenId != 0) {
            revert AOXCErrors.AOXC_CustomRevert("BUILD: IDENTITY_EXISTS");
        }

        assetId = 1000 + nextAssetId++;

        s.assets[assetId] = SovereignAsset({
            assetId: assetId,
            symbol: (aType == AssetType.IDENTITY) ? "ID" : "ASSET",
            tokenAddress: address(this),
            totalMinted: initialVal,
            reserveRatio: 0,
            isMintingActive: true
        });

        if (aType == AssetType.IDENTITY) {
            s.citizenRecords[to] = CitizenRecord({
                citizenId: assetId,
                joinedAt: block.timestamp,
                tier: 1,
                reputation: 100,
                lastPulse: block.timestamp,
                totalVoted: 0,
                isBlacklisted: false
            });

            _assignToCell(to);
            emit AOXCEvents.MemberOnboarded(to, assetId, true);
        }

        _safeMint(to, assetId);
    }

    /*//////////////////////////////////////////////////////////////
                            REPAIR ENGINE
    //////////////////////////////////////////////////////////////*/

    function triggerEmergencyQuarantine(bytes4 selector, address target) external override {
        if (msg.sender != aiNode && !_hasSovereignRole(AOXCConstants.GUARDIAN_ROLE, msg.sender)) {
            revert AOXCErrors.AOXC_Neural_IdentityForgery();
        }
        if (isReserved[selector]) revert AOXCErrors.AOXC_CustomRevert("REPAIR: PROTECTED");

        RegistryStorageV2 storage s = _getRegistryV2();
        s.activePatches[selector][target] = PatchCore({
            targetContract: target,
            functionSelector: selector,
            isQuarantined: true,
            timestamp: uint64(block.timestamp),
            autoUnlockAt: uint64(block.timestamp + AOXCConstants.AI_MAX_FREEZE_DURATION),
            candidateLogic: address(0)
        });

        emit AOXCEvents.SystemRepairInitiated(keccak256(abi.encodePacked(selector, target)), target);
    }

    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        bytes calldata aiAuthProof
    ) external override nonReentrant {
        _checkAoxcRole(AOXCConstants.GOVERNANCE_ROLE);
        if (patchLogic == address(0)) revert AOXCErrors.AOXC_InvalidAddress();
        if (anomalyLedger[anomalyId]) revert AOXCErrors.AOXC_CustomRevert("REPAIR: DUPLICATE");

        bytes32 proofHash =
            keccak256(abi.encode(anomalyId, selector, target, patchLogic, block.chainid)).toEthSignedMessageHash();

        if (proofHash.recover(aiAuthProof) != aiNode) revert AOXCErrors.AOXC_Neural_IdentityForgery();

        RegistryStorageV2 storage s = _getRegistryV2();
        anomalyLedger[anomalyId] = true;

        PatchCore storage patch = s.activePatches[selector][target];
        patch.isQuarantined = false;
        patch.candidateLogic = patchLogic;

        emit AOXCEvents.ComponentSynchronized(keccak256(abi.encodePacked(anomalyId)), patchLogic);
    }

    function liftQuarantine(bytes4 selector, address target) public override {
        if (msg.sender != auditVoice && !_hasSovereignRole(bytes32(0), msg.sender)) {
            revert AOXCErrors.AOXC_CustomRevert("REPAIR: ACCESS_DENIED");
        }
        RegistryStorageV2 storage s = _getRegistryV2();
        delete s.activePatches[selector][target];
    }

    /*//////////////////////////////////////////////////////////////
                        IAOX_AUTO_REPAIR VIEWS
    //////////////////////////////////////////////////////////////*/

    function isOperational(bytes4 selector) external view override returns (bool) {
        RegistryStorageV2 storage s = _getRegistryV2();
        PatchCore storage patch = s.activePatches[selector][address(this)];

        if (!patch.isQuarantined) return true;
        // Check if quarantine has expired
        return block.timestamp >= patch.autoUnlockAt;
    }

    function getRepairStatus() external view override returns (bool inRepairMode, uint256 expiry) {
        MainStorage storage m = _getMainStorage();
        return (m.isRepairModeActive, m.repairExpiry);
    }

    function validatePatch(uint256 anomalyId) external view override returns (bool isVerified) {
        return anomalyLedger[anomalyId];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assignToCell(address member) internal {
        RegistryStorageV2 storage s = _getRegistryV2();
        uint256 currentCellId = s.totalCells == 0 ? _spawnCell() : s.totalCells;

        if (s.cells[currentCellId].memberCount >= AOXCConstants.MAX_CELL_MEMBERS) {
            currentCellId = _spawnCell();
        }

        s.userToCellMap[member] = currentCellId;
        s.cells[currentCellId].memberCount++;
    }

    function _spawnCell() internal returns (uint256 id) {
        RegistryStorageV2 storage s = _getRegistryV2();
        id = ++s.totalCells;

        s.cells[id] = NeuralCellV2({
            cellId: id,
            cellHash: keccak256(abi.encodePacked(block.timestamp, id, s.lastCellHash)),
            memberCount: 0,
            isQuarantined: false,
            lockExpiry: 0
        });

        s.lastCellHash = s.cells[id].cellHash;
        emit AOXCEvents.CellSpawned(id, s.lastCellHash, s.cells[id != 0 ? id - 1 : 0].cellHash);
    }

    function _hasSovereignRole(bytes32 role, address account) internal view returns (bool) {
        (bool isMember,) = hasRole(uint64(uint256(role)), account);
        return isMember;
    }

    function _checkAoxcRole(bytes32 role) internal view {
        if (!_hasSovereignRole(role, msg.sender)) {
            revert AOXCErrors.AOXC_Unauthorized(role, msg.sender);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        // Identity assets (first 100 IDs post offset) are SBT (Soulbound)
        if (from != address(0) && to != address(0) && (tokenId < 1100)) {
            revert AOXCErrors.AOXC_CustomRevert("SBT: NON_TRANSFERABLE");
        }
        return super._update(to, tokenId, auth);
    }

    function _authorizeUpgrade(address) internal view override {
        _checkAoxcRole(AOXCConstants.UPGRADER_ROLE);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable) returns (bool) {
        return interfaceId == type(IAOX_AUTO_REPAIR).interfaceId || super.supportsInterface(interfaceId);
    }
}
