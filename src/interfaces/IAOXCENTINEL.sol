// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOXCENTINEL {
    event NeuralValidation(bytes32 indexed operationHash, uint256 riskScore, bool approved);

    function verifyNeuralSignature(bytes32 hash, bytes calldata signature) external view returns (bool);
    function getRiskScore(uint256 operationId) external view returns (uint256);
    function isSentinelActive() external view returns (bool);
}
