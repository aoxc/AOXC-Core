// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {AOXCStorage} from "./abstract/AOXCStorage.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";
import {AOXCEvents} from "./libraries/AOXCEvents.sol";

/**
 * @title AOXCREGISTRY Surgical Sovereign
 * @notice Web4 Otonom Kayıt ve İtibar Sistemi.
 * @dev V2.5.7 - Final Stability & Zero Warning Casts.
 */
contract AOXCREGISTRY is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage
{
    bytes32 private constant GENESIS_SEED = keccak256("AOXC_CORE_V2.5.7");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeRegistry(address dao, address admin) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, dao);

        RegistryStorageV2 storage $ = _getRegistryV2();
        if ($.totalCells != 0) revert AOXCErrors.AOXC_CustomRevert("ALREADY_INIT");

        bytes32 seed = GENESIS_SEED;
        uint256 ts = block.timestamp;
        bytes32 genesisHash;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, seed)
            mstore(add(ptr, 32), ts)
            mstore(add(ptr, 64), admin)
            genesisHash := keccak256(ptr, 96)
        }

        $.totalCells = 1;
        $.activeCellPointer = 1;
        $.cells[1] =
            NeuralCellV2({cellId: 1, cellHash: genesisHash, memberCount: 0, isQuarantined: false, lockExpiry: 0});
        $.lastCellHash = genesisHash;

        emit AOXCEvents.CellSpawned(1, genesisHash, genesisHash);
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL REPUTATION ENGINE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Üyenin itibarını günceller ve gerekirse karantinaya alır.
     * @dev Surgical cast applied to eliminate compiler warnings.
     */
    function adjustReputation(address member, int256 adjustment) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        RegistryStorageV2 storage $ = _getRegistryV2();
        CitizenRecord storage citizen = $.citizenRecords[member];
        if (citizen.joinedAt == 0) revert AOXCErrors.AOXC_Cell_NotFound(0);

        uint256 oldRep = citizen.reputation;
        int256 newRep;

        // Casting is safe as oldRep is uint256 but bounded by protocol limits (0-200)
        // forge-lint: disable-next-line(unsafe-typecast)
        newRep = int256(oldRep) + adjustment;

        if (newRep < 0) newRep = 0;
        if (newRep > 200) newRep = 200;

        // Casting back to uint256 is safe after bounds check above
        // forge-lint: disable-next-line(unsafe-typecast)
        citizen.reputation = uint256(newRep);
        citizen.lastPulse = block.timestamp;

        // Noktasal İzolasyon Tetikleyici
        if (citizen.reputation < 20 && !citizen.isBlacklisted) {
            citizen.isBlacklisted = true;
            emit AOXCEvents.NeuralQuarantineTriggered(member, citizen.reputation, $.userToCellMap[member]);
        } else if (citizen.isBlacklisted && citizen.reputation >= 50) {
            citizen.isBlacklisted = false;
        }

        emit AOXCEvents.ReputationUpdated(member, oldRep, citizen.reputation);
    }

    /*//////////////////////////////////////////////////////////////
                        CITIZEN ONBOARDING
    //////////////////////////////////////////////////////////////*/

    function onboardMember(address member) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) nonReentrant {
        if (member == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        RegistryStorageV2 storage $ = _getRegistryV2();
        if ($.userToCellMap[member] != 0) {
            revert AOXCErrors.AOXC_Cell_AlreadyMember(member, $.userToCellMap[member]);
        }

        uint256 targetCell = $.activeCellPointer;
        if ($.cells[targetCell].isQuarantined || $.cells[targetCell].memberCount >= AOXCConstants.MAX_CELL_MEMBERS) {
            targetCell = _spawnNewCell($);
            $.activeCellPointer = targetCell;
        }

        $.userToCellMap[member] = targetCell;
        unchecked {
            $.cells[targetCell].memberCount++;
        }

        $.citizenRecords[member] = CitizenRecord({
            citizenId: $.totalOps++,
            joinedAt: block.timestamp,
            tier: 1,
            reputation: 100,
            lastPulse: block.timestamp,
            totalVoted: 0,
            isBlacklisted: false
        });

        emit AOXCEvents.MemberOnboarded(member, targetCell, false);
    }

    /*//////////////////////////////////////////////////////////////
                         CELLULAR MAINTENANCE
    //////////////////////////////////////////////////////////////*/

    function setCellQuarantine(uint256 cellId, bool status, uint256 duration) external {
        _checkRepairAuthority();
        RegistryStorageV2 storage $ = _getRegistryV2();
        if (cellId == 0 || cellId > $.totalCells) revert AOXCErrors.AOXC_Cell_NotFound(cellId);

        NeuralCellV2 storage cell = $.cells[cellId];
        cell.isQuarantined = status;
        cell.lockExpiry = status ? block.timestamp + duration : 0;

        if (status && cellId == $.activeCellPointer) {
            $.activeCellPointer = _spawnNewCell($);
        }

        emit AOXCEvents.CellQuarantineStatus(cellId, status, cell.lockExpiry);
    }

    // --- INTERNAL HELPERS ---

    function _checkRepairAuthority() internal view {
        if (
            !hasRole(AOXCConstants.SENTINEL_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
                && !hasRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender)
        ) {
            revert AOXCErrors.AOXC_Repair_UnauthorizedRepairman(msg.sender);
        }
    }

    function _spawnNewCell(RegistryStorageV2 storage $) internal returns (uint256) {
        uint256 newId = ++$.totalCells;
        bytes32 prevHash = $.lastCellHash;
        uint256 ts = block.timestamp;
        bytes32 newHash;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, prevHash)
            mstore(add(ptr, 32), ts)
            mstore(add(ptr, 64), newId)
            newHash := keccak256(ptr, 96)
        }

        $.cells[newId] =
            NeuralCellV2({cellId: newId, cellHash: newHash, memberCount: 0, isQuarantined: false, lockExpiry: 0});

        $.lastCellHash = newHash;
        emit AOXCEvents.CellSpawned(newId, newHash, prevHash);
        return newId;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function neuralNet(uint256 cellId)
        external
        view
        returns (uint256 id, bytes32 hash, uint256 members, bool quarantined, uint256 expiry)
    {
        NeuralCellV2 storage c = _getRegistryV2().cells[cellId];
        return (c.cellId, c.cellHash, c.memberCount, c.isQuarantined, c.lockExpiry);
    }

    function getCitizenData(address member) external view returns (CitizenRecord memory) {
        return _getRegistryV2().citizenRecords[member];
    }

    function userToCellMap(address user) external view returns (uint256) {
        return _getRegistryV2().userToCellMap[user];
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
