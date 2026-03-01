// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOXC_AUDIT_VOICE {
    event CommunityVetoSignaled(uint256 indexed proposalId, uint256 totalVetoPower);

    function isVetoed(uint256 proposalId) external view returns (bool);
    function getVetoSignalStatus(uint256 proposalId) external view returns (uint256 power, bool reached);
    function emitVetoSignal(uint256 proposalId) external;
}
