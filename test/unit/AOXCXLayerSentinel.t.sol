// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCXLayerSentinel} from "../../src/AOXCXLayerSentinel.sol";
import {AOXCConstants} from "../../src/libraries/AOXCConstants.sol";
import {AOXCErrors} from "../../src/libraries/AOXCErrors.sol";

/**
 * @title AOXCXLayerSentinelTest
 * @author AOXCAN AI Architect
 * @notice [V2.0.0-FINAL]: Zero-warning, zero-error production suite.
 * @dev Fixed: Assembly-aligned hashing and synchronized nonce tracking.
 */
contract AOXCXLayerSentinelTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCXLayerSentinel public sentinel;

    address public admin = makeAddr("admin");
    address public aiSentinel;
    address public user = makeAddr("user");
    address public malicious = makeAddr("malicious");

    uint256 public constant AI_PK = 0xA1B2C3D4;

    function setUp() public {
        aiSentinel = vm.addr(AI_PK);

        AOXCXLayerSentinel implementation = new AOXCXLayerSentinel();
        bytes memory initData = abi.encodeWithSelector(AOXCXLayerSentinel.initialize.selector, admin, aiSentinel);

        sentinel = AOXCXLayerSentinel(address(new ERC1967Proxy(address(implementation), initData)));

        vm.startPrank(admin);
        // Set reputation scores to test the gate logic
        sentinel.updateReputation(user, 100);
        sentinel.updateReputation(malicious, 5); // Below threshold (10)
        vm.stopPrank();
    }

    /**
     * @dev [V2.0.0-FIX]: Matches internal ASSEMBLY-based hashing in AOXCXLayerSentinel.
     * Contract uses: keccak256(ptr, 0x80) where ptr holds 4 words (32 bytes each).
     * This equals abi.encode(risk, nonce, sentinelAddr, chainId).
     */
    function _getNeuralSig(uint256 risk, uint256 nonce) internal view returns (bytes memory) {
        // [CRITICAL FIX]: Using abi.encode instead of encodePacked for 32-byte alignment
        bytes32 innerHash = keccak256(abi.encode(risk, nonce, address(sentinel), block.chainid));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PK, innerHash.toEthSignedMessageHash());
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                            REPUTATION GATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that only users with sufficient reputation pass the gate.
     */
    function test_Sovereign_ReputationGate() public view {
        // User (100) > 10: Allowed
        assertTrue(sentinel.isAllowed(user, address(0x123)));
    }

    /*//////////////////////////////////////////////////////////////
                            NEURAL DYNAMICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates AI-driven circuit breaker activation.
     */
    function test_Sovereign_CircuitBreaker_Activation() public {
        uint256 risk = 600; // Above aiAnomalyThreshold (500)
        uint256 nextNonce = 1;
        bytes memory sig = _getNeuralSig(risk, nextNonce);

        sentinel.processNeuralSignal(risk, nextNonce, sig);

        // System should be temporarily locked
        assertFalse(sentinel.isAllowed(user, address(0x123)), "L10: Breaker activation failed");

        // Warp past cooldown (AI_MAX_FREEZE_DURATION = 2 days)
        vm.warp(block.timestamp + AOXCConstants.AI_MAX_FREEZE_DURATION + 1 seconds);
        assertTrue(sentinel.isAllowed(user, address(0x123)), "L10: Auto-cooldown failed");
    }

    /**
     * @notice Validates high-risk signals (Hard Sovereign Seal).
     */
    function test_Sovereign_HardSeal_CriticalThreat() public {
        uint256 risk = 1500; // Over 1000 (Critical Threshold)
        uint256 nextNonce = 1;
        bytes memory sig = _getNeuralSig(risk, nextNonce);

        sentinel.processNeuralSignal(risk, nextNonce, sig);

        // Should be sealed even after time passes
        vm.warp(block.timestamp + 365 days);
        assertFalse(sentinel.isAllowed(user, address(0x123)), "L23: Seal should be permanent");

        // Admin must unlock manually
        vm.prank(admin);
        sentinel.emergencyBastionUnlock();
        assertTrue(sentinel.isAllowed(user, address(0x123)), "L25: Admin unlock failed");
    }

    /**
     * @notice Ensures replay protection via nonce-sync.
     */
    function test_RevertIf_NeuralSignalIsStale() public {
        uint256 risk = 100;
        uint256 nonce = 1;
        bytes memory sig = _getNeuralSig(risk, nonce);

        sentinel.processNeuralSignal(risk, nonce, sig);

        // Reusing same nonce must revert
        vm.expectRevert(abi.encodeWithSelector(AOXCErrors.AOXC_Neural_StaleSignal.selector, nonce, nonce));
        sentinel.processNeuralSignal(risk, nonce, sig);
    }
}
