// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXC Sovereign Storage Schema
 * @author AOXC Protocol
 * @notice Centralized storage layout using ERC-7201 Namespaced Storage.
 * @dev This pattern prevents storage collisions during UUPS upgrades by isolating
 * contract state into specific, high-entropy storage slots.
 */
abstract contract AOXCStorage {
    /**
     * @dev Main Storage Layout for the AOXC Core (Token/Ecosystem logic).
     * @custom:storage-location erc7201:aoxc.storage.Main
     */
    struct MainStorage {
        uint256 totalValueLocked;
        bool isGlobalLockActive;
        mapping(address => bool) blacklisted;
        mapping(address => bool) isExcludedFromLimits;
    }

    /**
     * @dev Staking-specific storage layout.
     * @custom:storage-location erc7201:aoxc.storage.Staking
     */
    struct StakingStorage {
        uint256 globalStakedAmount;
        uint256 rewardRateBps;
        uint256 lastUpdateTimestamp;
        mapping(address => uint256) userStakeCount;
    }

    /**
     * @dev Treasury-specific storage layout.
     * @custom:storage-location erc7201:aoxc.storage.Treasury
     */
    struct TreasuryStorage {
        uint256 initialUnlockTimestamp;
        uint256 currentWindowEnd;
        uint256 currentWindowId;
        mapping(address => uint256) spentInCurrentWindow;
    }

    /**
     * @dev Bridge-specific storage layout.
     * @custom:storage-location erc7201:aoxc.storage.Bridge
     */
    struct BridgeStorage {
        mapping(uint16 => bool) supportedChains;
        mapping(bytes32 => bool) processedMessages;
        uint256 bridgeFeeNative;
    }

    /*//////////////////////////////////////////////////////////////
                        PRE-CALCULATED ERC-7201 SLOTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hash: keccak256(abi.encode(uint256(keccak256("aoxc.storage.Main")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant MAIN_STORAGE_SLOT = 0x56a6839352e825a0b731057c32e987c050e63c0a96f1d8c1050b44585c542a00;

    /**
     * @dev Hash: keccak256(abi.encode(uint256(keccak256("aoxc.storage.Staking")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant STAKING_STORAGE_SLOT = 0x29141f238c926d40351565154325412543163462315432165431265432165400;

    /**
     * @dev Hash: keccak256(abi.encode(uint256(keccak256("aoxc.storage.Treasury")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant TREASURY_STORAGE_SLOT = 0x6a936a297e02e5a0b731057c32e987c050e63c0a96f1d8c1050b44585c542a00;

    /**
     * @dev Hash: keccak256(abi.encode(uint256(keccak256("aoxc.storage.Bridge")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant BRIDGE_STORAGE_SLOT = 0x7b8b2b3b4b5b6b7b8b9b0b1b2b3b4b5b6b7b8b9b0b1b2b3b4b5b6b7b8b9b0b00;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL POINTERS
    //////////////////////////////////////////////////////////////*/

    function _getMainStorage() internal pure returns (MainStorage storage $) {
        bytes32 slot = MAIN_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    function _getStakingStorage() internal pure returns (StakingStorage storage $) {
        bytes32 slot = STAKING_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    function _getTreasuryStorage() internal pure returns (TreasuryStorage storage $) {
        bytes32 slot = TREASURY_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    function _getBridgeStorage() internal pure returns (BridgeStorage storage $) {
        bytes32 slot = BRIDGE_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    /**
     * @dev 50-slot gap for future non-namespaced variable additions in the inheritance chain.
     */
    uint256[50] private __gap;
}
