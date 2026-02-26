// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test, console2 } from "forge-std/Test.sol";
import { AOXCBridge } from "src/AOXC.Bridge.sol";
import { AOXCErrors } from "src/libraries/AOXCErrors.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockAOXC
 * @notice Standard ERC20 for AOXC Ecosystem testing.
 */
contract MockAOXC is ERC20 {
    constructor() ERC20("AOXC Token", "AOXC") { 
        _mint(msg.sender, 1_000_000 * 1e18); 
    }
}

/**
 * @title BridgeWorkflowTest
 * @author AOXC Core Team
 * @notice Formal integration tests for the Sovereign Bridge Infrastructure.
 * @dev Version 2.0.0 - Focused on Neural Proof validation and security bounds.
 */
contract BridgeWorkflowTest is Test {
    AOXCBridge public bridge;
    MockAOXC public token;

    // Infrastructure Actors
    address public governor = makeAddr("governor");
    uint256 public aiNodePk = 0xA11CE; 
    address public aiNode;
    address public treasury = makeAddr("treasury");
    address public user = makeAddr("user");

    // Environmental Parameters
    uint32 public targetChainId = 101;

    /**
     * @notice Set up the testing environment with Proxy-Implementation pattern.
     */
    function setUp() public {
        aiNode = vm.addr(aiNodePk);
        
        vm.startPrank(governor);
        
        // Deploy Mock Token and Bridge Logic
        token = new MockAOXC();
        AOXCBridge bridgeImpl = new AOXCBridge();
        
        // Initialize via ERC1967 Proxy
        bytes memory initData = abi.encodeWithSignature(
            "initializeBridge(address,address,address,address)",
            governor, aiNode, treasury, address(token)
        );
        
        bridge = AOXCBridge(address(new ERC1967Proxy(address(bridgeImpl), initData)));
        
        // Post-Deployment Configuration
        bridge.setChainSupport(targetChainId, true);
        
        // Distribute initial liquidity to User
        token.transfer(user, 10_000 * 1e18);
        
        vm.stopPrank();
    }

    /**
     * @notice Validates the complete outbound migration flow.
     * @dev Checks: Token locking, Fee deduction (30 BPS), and Event emission readiness.
     */
    function test_Bridge_Outbound_Workflow() public {
        uint256 amount = 1000 * 1e18;
        
        vm.startPrank(user);
        token.approve(address(bridge), amount);
        
        // Action: Initiate Migration
        bridge.bridgeAssets(amount, targetChainId);
        vm.stopPrank();

        // Verification: 30 BPS = 0.3% -> 3 tokens fee
        assertEq(token.balanceOf(treasury), 3 * 1e18, "AUDIT: Treasury fee mismatch");
        assertEq(token.balanceOf(address(bridge)), 997 * 1e18, "AUDIT: Bridge vault lock failed");
        
        console2.log("Status: Outbound Workflow Verified.");
    }

    /**
     * @notice Validates inbound finalization via Neural Proof (AI Signature).
     * @dev Checks: Cryptographic identity recovery and fund release integrity.
     */
    function test_Bridge_Inbound_Neural_Finalization() public {
        uint256 amount = 500 * 1e18;
        bytes32 transferId = keccak256("TRANSFER_001");
        uint32 sourceChainId = 202;

        // Provide bridge liquidity for release
        vm.prank(governor);
        token.transfer(address(bridge), amount);

        // Simulate Neural Signature (AI Node Output)
        bytes32 msgHash = keccak256(abi.encode(
            user, amount, transferId, sourceChainId, address(bridge), block.chainid
        ));
        
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiNodePk, ethHash);
        bytes memory neuralProof = abi.encodePacked(r, s, v);

        // Action: Finalize with Proof
        bridge.finalizeMigration(user, amount, sourceChainId, transferId, neuralProof);
        
        // Verification
        assertEq(token.balanceOf(user), 10_500 * 1e18, "AUDIT: User release balance mismatch");
        console2.log("Status: Neural Proof Identity Verified via ECRECOVER.");
    }

    /**
     * @notice Security: Ensures bridge rejects unauthorized or fake AI signatures.
     */
    function test_Security_Reject_Fake_Neural_Proof() public {
        uint256 amount = 500 * 1e18;
        bytes32 transferId = keccak256("FAKE_TRANSFER");
        
        // Sign with a random malicious key instead of aiNodePk
        uint256 maliciousPk = 0xBAD;
        bytes32 msgHash = keccak256(abi.encode(user, amount, transferId, 202, address(bridge), block.chainid));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(maliciousPk, ethHash);
        bytes memory fakeProof = abi.encodePacked(r, s, v);

        // Action & Verification: Must revert with IdentityForgery
        vm.expectRevert(abi.encodeWithSignature("AOXC_Neural_IdentityForgery()"));
        bridge.finalizeMigration(user, amount, 202, transferId, fakeProof);
        
        console2.log("Security: Malicious Neural Proof blocked successfully.");
    }
}
