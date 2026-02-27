// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXCXLayerSentinel} from "../../src/AOXCXLayerSentinel.sol";
import {AOXCSecurityRegistry} from "../../src/AOXC.Security.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title EmergencyDefense Integration Test
 * @notice Validates Layer-26 AI Lockdown and Manual Recovery flows.
 */
contract EmergencyDefenseTest is Test {
    AOXCXLayerSentinel public sentinel;
    AOXCSecurityRegistry public security;

    address public admin = makeAddr("admin");
    uint256 public constant AI_NODE_PRIVATE_KEY = 0xA11CE;
    address public aiNode;
    address public user = makeAddr("user");

    function setUp() public {
        aiNode = vm.addr(AI_NODE_PRIVATE_KEY);
        vm.startPrank(admin);

        // Security Registry Setup
        AOXCSecurityRegistry securityImpl = new AOXCSecurityRegistry();
        security = AOXCSecurityRegistry(
            address(
                new ERC1967Proxy(
                    address(securityImpl), abi.encodeWithSignature("initializeApex(address,address)", admin, aiNode)
                )
            )
        );

        // Sentinel Setup
        AOXCXLayerSentinel sentinelImpl = new AOXCXLayerSentinel();
        sentinel = AOXCXLayerSentinel(
            address(
                new ERC1967Proxy(
                    address(sentinelImpl), abi.encodeWithSelector(AOXCXLayerSentinel.initialize.selector, admin, aiNode)
                )
            )
        );

        vm.stopPrank();
    }

    /**
     * @notice TEST 1: Neural Signal Threshold Breach
     * @dev AI Node triggers riskScore 1500 (>1000) which must seal the bastion.
     */
    function test_Sovereign_Lockdown_Flow() public {
        uint256 riskScore = 1500; // Trigger Sovereign Seal
        uint256 nonce = 1;

        // Construct EIP-191 Neural Signal
        bytes32 innerHash = keccak256(abi.encode(riskScore, nonce, address(sentinel), block.chainid));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", innerHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_NODE_PRIVATE_KEY, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Process Signal
        vm.expectEmit(true, false, false, true);
        emit AOXCXLayerSentinel.LockdownActivated(block.timestamp, "NEURAL_CRITICAL_HALT");
        sentinel.processNeuralSignal(riskScore, nonce, signature);

        // Assertions
        assertTrue(sentinel.paused(), "Sentinel should be paused");
        assertFalse(sentinel.isAllowed(user, address(0)), "Transactions should be blocked");
    }

    /**
     * @notice TEST 2: Multi-Sig Admin Recovery
     * @dev Ensures admin can override an AI lockdown.
     */
    function test_Admin_Manual_Bypass() public {
        test_Sovereign_Lockdown_Flow(); // Start in lockdown

        vm.prank(admin);
        sentinel.emergencyBastionUnlock();

        assertFalse(sentinel.paused(), "Admin should unpause system");
        assertTrue(sentinel.isAllowed(user, address(0)), "Transactions should resume");
    }
}
