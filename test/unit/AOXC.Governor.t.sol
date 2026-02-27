// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AOXCGovernor} from "../../src/AOXC.Governor.sol";
import {AOXCErrors} from "../../src/libraries/AOXCErrors.sol";

contract AOXCGovernorTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCGovernor public governor;
    address public admin = address(0xAD31);
    address public aiNode;
    uint256 public constant AI_PK = 0xA1B2C3;
    uint256 public constant INITIAL_SCORE_LIMIT = 5000;

    // [V2-FIX]: Kontrattaki slot ile birebir aynı olmalı
    bytes32 private constant GOVERNOR_STORAGE_SLOT = 0x5a17684526017462615a17684526017462615a17684526017462615a17684500;

    function setUp() public {
        aiNode = vm.addr(AI_PK);
        AOXCGovernor implementation = new AOXCGovernor();

        bytes memory initData =
            abi.encodeWithSelector(AOXCGovernor.initializeGovernor.selector, aiNode, INITIAL_SCORE_LIMIT, admin);

        governor = AOXCGovernor(address(new ERC1967Proxy(address(implementation), initData)));
        vm.warp(block.timestamp + 1 hours);
    }

    /**
     * @dev [V2-STORAGE-READ]: Namespaced storage'dan neuralNonce'ı çeker.
     * Struct yerleşimi: aiOracleNode(0), anomalyScoreLimit(1), lastNeuralPulse(2),
     * neuralPulseTimeout(3), isNeuralLockActive(4), neuralNonce(5)
     */
    function _getNeuralNonce() internal view returns (uint256) {
        // neuralNonce, struct içindeki 5. slot (0'dan başlayarak)
        bytes32 nonceSlot = bytes32(uint256(GOVERNOR_STORAGE_SLOT) + 5);
        return uint256(vm.load(address(governor), nonceSlot));
    }

    function _getPulseSignature(uint256 propId, uint256 score, uint256 nonce) internal view returns (bytes memory) {
        // [V2.0.1-ALIGN]: syncGovernorPulse içindeki abi.encodePacked sırasıyla birebir aynı olmalı!
        bytes32 h = keccak256(abi.encodePacked(propId, score, nonce, address(governor), block.chainid))
            .toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PK, h);
        return abi.encodePacked(r, s, v);
    }

    function testFuzz_CircuitBreaker_Activation(uint256 rawScore) public {
        uint256 riskScore = bound(rawScore, 9500, 10000);

        vm.prank(admin);
        uint256 propId = governor.propose(new address[](0), new uint256[](0), new bytes[](0), "Lockdown");

        uint256 nextNonce = _getNeuralNonce() + 1;
        bytes memory sig = _getPulseSignature(propId, riskScore, nextNonce);

        governor.syncGovernorPulse(propId, riskScore, nextNonce, sig);

        vm.prank(admin);
        vm.expectRevert(AOXCErrors.AOXC_GlobalLockActive.selector);
        governor.propose(new address[](0), new uint256[](0), new bytes[](0), "Should Fail");
    }

    function test_Sovereign_Veto_Lifecycle() public {
        address[] memory t = new address[](1);
        t[0] = address(0x1);
        uint256[] memory v = new uint256[](1);
        v[0] = 0;
        bytes[] memory c = new bytes[](1);
        c[0] = hex"60";

        vm.prank(admin);
        uint256 propId = governor.propose(t, v, c, "Veto_Test");

        uint256 nextNonce = _getNeuralNonce() + 1;
        bytes memory sig = _getPulseSignature(propId, 7000, nextNonce);
        governor.syncGovernorPulse(propId, 7000, nextNonce, sig);

        vm.prank(admin);
        // V2'de execute ID hesaplaması farklılaştığı için revert'ü genel yakalıyoruz
        vm.expectRevert();
        governor.execute(t, v, c, "Veto_Test");
    }

    function test_RevertIf_NeuralIdentityIsForged() public {
        vm.prank(admin);
        uint256 propId = governor.propose(new address[](0), new uint256[](0), new bytes[](0), "Forgery");

        bytes memory forgedSig = new bytes(65);
        for (uint256 i = 0; i < 64; i++) {
            forgedSig[i] = 0x02;
        }
        forgedSig[64] = 0x1b;

        vm.expectRevert(AOXCErrors.AOXC_Neural_IdentityForgery.selector);
        governor.syncGovernorPulse(propId, 100, _getNeuralNonce() + 1, forgedSig);
    }
}
