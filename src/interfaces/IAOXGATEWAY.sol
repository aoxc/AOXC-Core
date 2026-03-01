// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IAOXCGATEWAY {
    event MigrationInitiated(
        uint16 indexed dstChainId, address indexed from, address indexed to, uint256 amount, bytes32 migrationId
    );
    event MigrationInFinalized(uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 migrationId);
    event NeuralAnomalyNeutralized(bytes32 indexed migrationId, uint256 riskScore, string diagnosticCode);

    function initiateMigration(
        uint16 _dstChainId,
        address _to,
        uint256 _amount,
        uint256 _riskScore,
        bytes calldata _aiProof
    ) external payable;

    // ONARIM: Arayüz ve Implementation parametreleri eşitlendi
    function finalizeMigration(
        uint16 _srcChainId,
        address _to,
        uint256 _amount,
        bytes32 _migrationId,
        bytes calldata _neuralProof
    ) external;

    function getGatewayLockState() external view returns (bool isLocked, uint256 expiry);
    function quoteGatewayFee(uint16 _dstChainId, uint256 _amount) external view returns (uint256 nativeFee);
    function getRemainingQuantum(uint16 _chainId, bool isOutbound) external view returns (uint256 remaining);
    function isNetworkSupported(uint16 _chainId) external view returns (bool);
    function migrationProcessed(bytes32 _migrationId) external view returns (bool);
}
