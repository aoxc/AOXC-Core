// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/**
 * @title AOXC Security Registry
 * @author AOXC Protocol
 * @notice Centralized access control and circuit breaker for the entire AOXC ecosystem.
 * @dev Inherits OpenZeppelin's AccessManager for fine-grained, target-based permissions.
 * Standardizes role management across Token, Treasury, Staking, and Bridge modules.
 */
contract AOXCSecurityRegistry is Initializable, AccessManagerUpgradeable, UUPSUpgradeable {
    /**
     * @notice Global flag to pause non-critical ecosystem operations during a crisis.
     */
    bool public isGlobalEmergencyLocked;

    /**
     * @dev Emitted when the global emergency state is changed.
     */
    event GlobalEmergencyLockToggled(address indexed caller, bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Security Registry with a primary administrator.
     * @param _admin The initial authority (typically the AOXC DAO Timelock).
     */
    function initialize(address _admin) public initializer {
        if (_admin == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __AccessManager_init(_admin);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                            CIRCUIT BREAKER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Activates the global emergency lock.
     * @dev Restricted to the EMERGENCY_COMMITTEE role.
     */
    function triggerEmergencyStop() external {
        _checkRole(AOXCConstants.GUARDIAN_ROLE, msg.sender);
        if (isGlobalEmergencyLocked) revert AOXCErrors.AOXC_AlreadyProcessed();

        isGlobalEmergencyLocked = true;
        emit GlobalEmergencyLockToggled(msg.sender, true);
    }

    /**
     * @notice Deactivates the global emergency lock.
     * @dev Restricted to the GOVERNANCE_ROLE (DAO Executive) to ensure decentralized recovery.
     */
    function releaseEmergencyStop() external {
        _checkRole(AOXCConstants.GOVERNANCE_ROLE, msg.sender);
        if (!isGlobalEmergencyLocked) revert AOXCErrors.AOXC_AlreadyProcessed();

        isGlobalEmergencyLocked = false;
        emit GlobalEmergencyLockToggled(msg.sender, false);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal check to verify if an account holds a specific role.
     * Uses AccessManager's native role checking logic.
     */
    function _checkRole(bytes32 roleName, address account) internal view {
        // Converting bytes32 role to uint64 for AccessManager compatibility
        uint64 roleId = uint64(uint256(roleName));
        (bool isMember,) = hasRole(roleId, account);
        if (!isMember) revert AOXCErrors.AOXC_Unauthorized();
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Restricted to the UPGRADER_ROLE via the central AccessManager logic.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        _checkRole(AOXCConstants.UPGRADER_ROLE, msg.sender);
    }

    /**
     * @dev Storage gap to allow for future state variable additions without
     * compromising the proxy storage layout.
     */
    uint256[49] private __gap;
}
