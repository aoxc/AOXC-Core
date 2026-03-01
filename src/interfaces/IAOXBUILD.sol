// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOXBUILD {
    enum AssetType {
        IDENTITY,
        RWA_POINTER,
        SBT_BADGE,
        AI_AGENT_KEY
    }

    event AssetBuilt(address indexed to, uint256 indexed assetId, AssetType aType);
    event SystemRepairInitiated(bytes32 indexed anomalyHash, address indexed target);
    event PatchExecuted(bytes4 indexed selector, address indexed target, address patchLogic);

    function buildAsset(address to, AssetType aType, bytes32 doc, uint256 initialVal) external returns (uint256 assetId);
    function triggerEmergencyQuarantine(bytes4 selector, address target) external;
    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        bytes calldata aiAuthProof
    ) external;
    function liftQuarantine(bytes4 selector, address target) external;
}
