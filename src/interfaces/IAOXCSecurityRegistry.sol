// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

/**
 * @title IAOXCSecurityRegistry
 * @notice Interface for the central access management of the AOXC ecosystem.
 */
interface IAOXCSecurityRegistry is IAccessManager {
    event GlobalEmergencyLockToggled(address indexed caller, bool status);

    function isGlobalEmergencyLocked() external view returns (bool);
    function triggerEmergencyStop() external;
    function releaseEmergencyStop() external;
}
