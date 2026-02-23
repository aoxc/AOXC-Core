// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title AOXC Sovereign Timelock
 * @notice The ultimate vault for AOXC DAO. Delays execution of governance proposals.
 * @dev Optimized for OpenZeppelin v5. Fully compatible with AOXC Sovereign Token V2.
 */
contract AOXCTimelock is Initializable, TimelockControllerUpgradeable, UUPSUpgradeable {
    // --- CUSTOM ERRORS ---
    error AOXC_System_Forbidden();
    error AOXC_System_ZeroAddress();
    error AOXC_System_MinDelayViolation();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Timelock Controller.
     * @param minDelay Minimum time (seconds) a proposal must wait before execution.
     * @param proposers List of addresses allowed to propose (Usually the Governor).
     * @param executors List of addresses allowed to execute (Usually address(0) for everyone).
     * @param admin Initial admin for the timelock (Usually the Timelock itself for decentralization).
     */
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        initializer
    {
        if (admin == address(0)) revert AOXC_System_ZeroAddress();
        if (minDelay < 1 hours) revert AOXC_System_MinDelayViolation();

        // TimelockControllerUpgradeable'ın kendi init fonksiyonunu çağırıyoruz
        __TimelockController_init(minDelay, proposers, executors, admin);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                            DAO ENHANCEMENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Provides the current version of the Timelock logic.
     */
    function version() public pure returns (string memory) {
        return "2.0.0-Titanium";
    }

    /**
     * @notice Check if an operation is pending.
     * @param id The operation ID.
     */
    function isOperationPending(bytes32 id) public view returns (bool) {
        return getOperationState(id) == OperationState.Pending;
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Restricts upgrading to the DAO itself.
     * In UUPS, the upgrade logic stays in the implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        // DEFAULT_ADMIN_ROLE genelde address(this) (Timelock'un kendisi) olur.
        // Bu sayede bir yükseltme ancak başarılı bir oylama ile gerçekleşebilir.
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Reserved storage slots for future version upgrades.
     * TimelockControllerUpgradeable (v5) uses namespaced storage,
     * but we keep a gap for custom state variables.
     */
    uint256[45] private __gap;
}
