// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { AOXCSecurityRegistry } from "../../src/AOXC.Security.sol";
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";
import { AOXCErrors } from "../../src/libraries/AOXCErrors.sol";

/**
 * @title AOXCSecurityTest
 * @author AOXCAN AI Architect
 * @notice Production-grade security tests for V2.0.1 Sovereign CNS.
 * @dev Aligned with internal assembly hashing and dynamic nonce tracking.
 */
contract AOXCSecurityTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCSecurityRegistry public registry;
    address public admin = makeAddr("admin");
    address public aiSentinel;
    address public subDao = makeAddr("subDao");
    uint256 public constant AI_PRIVATE_KEY = 0xA1B2C3D4;

    function setUp() public {
        aiSentinel = vm.addr(AI_PRIVATE_KEY);
        AOXCSecurityRegistry implementation = new AOXCSecurityRegistry();
        
        bytes memory initData = abi.encodeWithSelector(
            AOXCSecurityRegistry.initializeApex.selector, admin, aiSentinel
        );
        registry = AOXCSecurityRegistry(address(new ERC1967Proxy(address(implementation), initData)));

        vm.startPrank(admin);
        // Guardian role casting for AccessManager (V2.0.0 Standard)
        uint64 roleId = uint64(uint256(AOXCConstants.GUARDIAN_ROLE));
        registry.grantRole(roleId, admin, 0); 
        vm.stopPrank();
    }

    /**
     * @dev Generates an AI signature by matching the Registry's internal Assembly logic.
     * [V2.0.1-UPDATE]: Fetches nonce directly from storage to ensure sync.
     */
    function _generateNeuralPulse(string memory action, uint256 risk, address target) 
        internal view returns (bytes memory) 
    {
        // Kontratın mevcut nonce değerini storage'dan okuyoruz (Private slot erişimi gerekirse diye)
        // Burada initializeApex sonrası ilk nonce 0'dır.
        bytes32 actionHash = keccak256(bytes(action));
        
        // Kontratın _computeNeuralHash mantığı ile %100 uyumlu
        bytes32 rawHash = keccak256(abi.encode(
            actionHash,
            risk,
            target,
            _getRegistryNonce(), 
            address(registry),
            block.chainid
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PRIVATE_KEY, rawHash.toEthSignedMessageHash());
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Helper to access private neuralNonce from the custom storage slot.
     */
    function _getRegistryNonce() internal view returns (uint256) {
        // AOXCSecurityRegistry içindeki SECURITY_STORAGE_SLOT + nonce offset (4. slot)
        bytes32 slot = 0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;
        uint256 nonceValue = uint256(vm.load(address(registry), bytes32(uint256(slot) + 4)));
        return nonceValue;
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY FLOWS
    //////////////////////////////////////////////////////////////*/

    function test_Sovereign_Heartbeat_Timeout() public {
        // V2.0.1'de neuralPulseTimeout = 2 days
        vm.warp(block.timestamp + 2 days + 1 seconds);
        
        bool allowed = registry.isAllowed(address(this), address(0xDEAD));
        assertFalse(allowed, "L5: Heartbeat expiry failed");
    }

    function test_Sovereign_GlobalEmergency_Flow() public {
        uint256 risk = 9500;
        bytes memory sig = _generateNeuralPulse("GLOBAL_LOCK", risk, address(0));

        vm.prank(admin);
        registry.triggerGlobalEmergency(risk, sig);

        assertFalse(registry.isAllowed(address(0), address(0)), "L1: Global lock failure");
    }

    function test_SubDao_Quarantine_Mechanism() public {
        uint256 risk = 6000;
        uint256 duration = 1 days;
        bytes memory sig = _generateNeuralPulse("QUARANTINE", risk, subDao);

        vm.prank(admin);
        registry.triggerSubDaoNeuralLock(subDao, risk, duration, sig);

        assertFalse(registry.isAllowed(address(0), subDao), "L23: Quarantine failed");
        // Collateral damage check
        assertTrue(registry.isAllowed(address(0), address(0x1337)), "L23: Systemic failure");
    }

    function test_RevertIf_NeuralSignatureIsReused() public {
        uint256 risk = 8500;
        bytes memory sig = _generateNeuralPulse("GLOBAL_LOCK", risk, address(0));

        vm.startPrank(admin);
        registry.triggerGlobalEmergency(risk, sig);

        // Replay attempt
        bytes32 sigHash = keccak256(sig);
        vm.expectRevert(abi.encodeWithSelector(AOXCErrors.AOXC_Neural_SignatureReused.selector, sigHash));
        registry.triggerGlobalEmergency(risk, sig);
        vm.stopPrank();
    }
}
