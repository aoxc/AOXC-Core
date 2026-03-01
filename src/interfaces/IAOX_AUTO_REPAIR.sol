// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOX_AUTO_REPAIR {
    // State Changing Functions (Bunlar eksikti, o yüzden override hatası alıyordun)
    function triggerEmergencyQuarantine(bytes4 selector, address target) external;
    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        bytes calldata aiAuthProof
    ) external;
    function liftQuarantine(bytes4 selector, address target) external;

    // View Functions
    function isOperational(bytes4 selector) external view returns (bool);
    function getRepairStatus() external view returns (bool inRepairMode, uint256 expiry);
    function validatePatch(uint256 anomalyId) external view returns (bool isVerified);
}
