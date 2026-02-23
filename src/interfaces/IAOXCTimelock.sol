// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCTimelock
 * @author AOXC Protocol
 * @notice Interface for the AOXC Timelock controller.
 * @dev Standardized interface for Governance to queue and execute delayed transactions.
 */
interface IAOXCTimelock {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event Cancelled(bytes32 indexed id);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    /*//////////////////////////////////////////////////////////////
                            READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether an operation is pending, ready, or done.
     */
    function isOperation(bytes32 id) external view returns (bool pending);
    function isOperationPending(bytes32 id) external view returns (bool pending);
    function isOperationReady(bytes32 id) external view returns (bool ready);
    function isOperationDone(bytes32 id) external view returns (bool done);

    /**
     * @notice Returns the minimum delay (in seconds) required before an operation can be executed.
     */
    function getMinDelay() external view returns (uint256 duration);

    /**
     * @notice Returns the timestamp at which an operation becomes ready for execution.
     */
    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    /**
     * @notice Computes the unique ID of an operation.
     */
    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        pure
        returns (bytes32 hash);

    /*//////////////////////////////////////////////////////////////
                            LOGIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Schedules an operation for execution after the minimum delay.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    /**
     * @notice Executes a scheduled operation that is ready.
     */
    function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        payable;

    /**
     * @notice Cancels a scheduled operation. Restricted to Proposers/Guardians.
     */
    function cancel(bytes32 id) external;

    /**
     * @notice Updates the minimum delay. Restricted to Governance.
     */
    function updateDelay(uint256 newDelay) external;
}
