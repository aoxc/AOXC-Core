// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOXVAULT {
    // Events
    event WindowOpened(uint256 indexed windowId, uint256 windowEnd);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EmergencyModeToggled(bool status);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount);

    // Treasury Operations (Kontratında olanlar)
    function deposit() external payable;
    function withdrawErc20(address token, address to, uint256 amount, bytes calldata aiProof) external;
    function withdrawEth(address payable to, uint256 amount, bytes calldata aiProof) external;
    function requestSettlement(address token, address to, uint256 amount) external;
    function requestAutomatedRefill(uint256 amount) external;

    // Safety & Recovery
    function emergencyNeuralRecovery(address token, address to, uint256 amount) external;
    function proposeSelfHealing(address newLogic) external;
    function finalizeSelfHealing() external;
    function emergencyUnseal() external;

    // Views
    function openNextWindow() external;
    function toggleEmergencyMode(bool status) external;
    function getInitialUnlockTime() external view returns (uint256);
    function getCurrentWindowEnd() external view returns (uint256);
    function getCurrentWindowId() external view returns (uint256);
    function getRemainingLimit(address token) external view returns (uint256);
    function isVaultLocked() external view returns (bool);
    function getVaultTvl() external view returns (uint256);
}
