// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test, console2 } from "forge-std/Test.sol";
import { AOXCXLayerSentinel } from "../../src/AOXCXLayerSentinel.sol";
import { AOXCSecurityRegistry } from "../../src/AOXC.Security.sol"; 
import { AOXCErrors } from "../../src/libraries/AOXCErrors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title EmergencyDefense Integration Test V2.0.8
 * @notice Complete integration suite for AI-driven security and sentinel response.
 */
contract EmergencyDefenseTest is Test {
    AOXCXLayerSentinel public sentinel;
    AOXCSecurityRegistry public security;

    // Actors & Keys
    address public admin = makeAddr("admin");
    uint256 public aiNodePk = 0xA11CE; // Synthetic Private Key for AI Node
    address public aiNode;
    address public user = makeAddr("user");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        aiNode = vm.addr(aiNodePk);
        vm.startPrank(admin);

        // 1. Setup Security Registry
        AOXCSecurityRegistry securityImpl = new AOXCSecurityRegistry();
        bytes memory securityInitData = abi.encodeWithSignature(
            "initializeApex(address,address)", 
            admin, 
            aiNode
        );
        security = AOXCSecurityRegistry(address(new ERC1967Proxy(address(securityImpl), securityInitData)));

        // 2. Setup Sentinel
        AOXCXLayerSentinel sentinelImpl = new AOXCXLayerSentinel();
        bytes memory sentinelInitData = abi.encodeWithSignature(
            "initialize(address,address)", 
            admin, 
            aiNode
        );
        sentinel = AOXCXLayerSentinel(address(new ERC1967Proxy(address(sentinelImpl), sentinelInitData)));

        vm.stopPrank();
    }

    /**
     * @notice Checks initial synchronization of the defense matrix.
     */
    function test_Audit_Initial_Sync_Status() public view {
        assertTrue(security.isAllowed(user, address(0)), "CNS: System should be open");
        assertTrue(sentinel.isAllowed(user, address(0)), "Sentinel: System should be open");
    }

    /**
     * @notice Simulates an AI Neural Signal that triggers a Sovereign Seal (Lockdown).
     * @dev Validates assembly hashing and ECDSA recovery logic in Sentinel.sol.
     */
    function test_Audit_Lockdown_Via_NeuralSignal() public {
        uint256 riskScore = 1500; // Trigger Sovereign Seal (>= 1000)
        uint256 nonce = 1;

        // Construct the hash exactly like Sentinel.sol assembly (L18-22)
        // riskScore (32b) + nonce (32b) + address (32b) + chainId (32b) = 0x80 bytes
        bytes32 innerHash = keccak256(abi.encode(
            riskScore, 
            nonce, 
            address(sentinel), 
            block.chainid
        ));
        
        // EIP-191 compliant signature
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", innerHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiNodePk, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Process Neural Signal
        sentinel.processNeuralSignal(riskScore, nonce, signature);

        // Verify System State
        assertFalse(sentinel.isAllowed(user, address(0)), "Audit: System must be sealed");
        assertTrue(sentinel.paused(), "Audit: Sentinel must be in Paused state");
        
        console2.log("Neural Defense: Sovereign Seal successfully activated.");
    }

    /**
     * @notice Verifies that stale signals (replay attacks) are rejected.
     */
    function test_Audit_Neural_Replay_Protection() public {
        uint256 riskScore = 1500;
        uint256 nonce = 1;

        bytes32 innerHash = keccak256(abi.encode(riskScore, nonce, address(sentinel), block.chainid));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", innerHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiNodePk, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First use: Success
        sentinel.processNeuralSignal(riskScore, nonce, signature);

        // Second use: Must Revert (Stale Signal)
        vm.expectRevert(); 
        sentinel.processNeuralSignal(riskScore, nonce, signature);
        
        console2.log("Security: Replay attack prevented.");
    }

    /**
     * @notice Tests the Reputation Gate logic.
     */
    function test_Audit_Reputation_Gate() public {
        address untrustedUser = makeAddr("untrusted");
        
        // Default score is 0, Sentinel requires 10 (L15)
        // Note: Check your isAllowed logic in Sentinel.sol for strictness
        vm.prank(admin);
        sentinel.updateReputation(untrustedUser, 5); // Below threshold

        // Logic test: If reputation is low, does it block? 
        // (Depends on your L15 implementation in Sentinel.sol)
        bool result = sentinel.isAllowed(untrustedUser, address(0));
        console2.log("Untrusted User Access:", result);
    }

    /**
     * @notice Verifies that Admin can restore the system after an AI Lockdown.
     */
    function test_Audit_Admin_Sovereign_Recovery() public {
        // First, trigger lockdown
        test_Audit_Lockdown_Via_NeuralSignal();
        
        // Admin Recovery
        vm.prank(admin);
        sentinel.emergencyBastionUnlock();

        assertTrue(sentinel.isAllowed(user, address(0)), "Recovery: Admin failed to restore system");
        assertFalse(sentinel.paused(), "Recovery: System still paused");
        
        console2.log("Recovery: Admin successfully restored the Bastion.");
    }
}
