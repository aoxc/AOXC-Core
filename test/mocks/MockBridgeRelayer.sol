// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title MockBridgeRelayer
 * @notice Simulates an off-chain relayer for cross-chain message passing.
 * @dev Used to test Bridge lockdowns and message verification logic.
 */
contract MockBridgeRelayer {
    struct BridgeMessage {
        address sender;
        address recipient;
        uint256 amount;
        uint256 nonce;
        uint256 sourceChainId;
        bool processed;
    }

    mapping(bytes32 => bool) public processedMessages;
    uint256 public totalRelayed;

    event MessageRelayed(bytes32 indexed messageHash, address indexed recipient, uint256 amount);

    /**
     * @dev Simulates the validation of a cross-chain message.
     * @return bool Returns true if the message is "cryptographically" valid in this simulation.
     */
    function validateProof(
        bytes32 messageHash,
        bytes calldata /* proof */
    )
        external
        returns (bool)
    {
        if (processedMessages[messageHash]) {
            return false; // Replay attack prevention simulation
        }

        processedMessages[messageHash] = true;
        totalRelayed++;

        emit MessageRelayed(messageHash, msg.sender, 0); // Simplified for mock
        return true;
    }

    /**
     * @dev Helper to generate a message hash for testing.
     */
    function computeMessageHash(address sender, address recipient, uint256 amount, uint256 nonce, uint256 sourceChainId)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(sender, recipient, amount, nonce, sourceChainId));
    }
}
