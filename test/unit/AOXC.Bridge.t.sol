// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*//////////////////////////////////////////////////////////////
                        AOXC CORE IMPORTS
//////////////////////////////////////////////////////////////*/

import { AOXCBridge } from "../../src/AOXC.Bridge.sol";
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";
import { AOXCErrors } from "../../src/libraries/AOXCErrors.sol";

contract MockAOXC is ERC20 {
    constructor() ERC20("AOXC Mock", "AOXC") {
        _mint(msg.sender, AOXCConstants.INITIAL_SUPPLY);
    }
}

/**
 * @title AOXCBridgeTest V2.0.1
 * @notice Professional test suite for V2.0.1 neural bridge.
 * @dev [V2.0.1-FIXED]: Corrected revert expectations and assembly-aligned signatures.
 */
contract AOXCBridgeTest is Test {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCBridge public bridge;
    MockAOXC public token;

    address public admin = address(0xAD31);
    address public aiNode;
    address public treasury = address(0xDE4D);
    address public user = address(0xCAFE);
    
    uint256 public constant AI_PK = 0xA1B2C3;
    uint32 public constant SOURCE_CHAIN = 1;
    uint32 public constant TARGET_CHAIN = 196;

    function setUp() public {
        aiNode = vm.addr(AI_PK);
        token = new MockAOXC();
        AOXCBridge implementation = new AOXCBridge();

        bytes memory initData = abi.encodeWithSelector(
            AOXCBridge.initializeBridge.selector, 
            admin, 
            aiNode, 
            treasury, 
            address(token)
        );
        bridge = AOXCBridge(address(new ERC1967Proxy(address(implementation), initData)));

        vm.prank(admin);
        bridge.setChainSupport(TARGET_CHAIN, true);

        // Checked transfers for linting & safety
        assertTrue(token.transfer(address(bridge), 1_000_000 * 1e18), "Bridge fund fail");
        assertTrue(token.transfer(user, 100_000 * 1e18), "User fund fail");

        vm.warp(block.timestamp + 1 hours);
    }

    /**
     * @dev Internal helper for V2.0.1 Neural Proof generation.
     * Must perfectly match finalizedMigration hashing logic.
     */
    function _generateSignature(
        address _actor, 
        uint256 _amount, 
        uint32 _srcChain, 
        bytes32 _txId
    ) internal view returns (bytes memory) {
        bytes32 msgHash = keccak256(
            abi.encode(_actor, _amount, _txId, _srcChain, address(bridge), block.chainid)
        ).toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PK, msgHash);
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY VECTORS
    //////////////////////////////////////////////////////////////*/

    function test_Bridge_Lock_Mechanism() public {
        uint256 amount = 1000 * 1e18;
        vm.startPrank(user);
        token.approve(address(bridge), amount);
        
        bridge.bridgeAssets(amount, TARGET_CHAIN);
        vm.stopPrank();
        
        // 0.3% Fee check
        uint256 expectedLock = (amount * 9970) / 10000;
        assertEq(token.balanceOf(address(bridge)), (1_000_000 * 1e18) + expectedLock, "L1: Net amount lock failed");
    }

    /**
     * @dev [V2.0.1-UPDATE]: ECDSA lib in OZ v5 reverts with ECDSAInvalidSignature for malformed sigs.
     */
    function test_RevertIf_BridgeSignatureIsForged() public {
        uint256 amount = 500 * 1e18;
        bytes32 transferId = keccak256("forgery_test");
        
        // Malformed signature (all zeros)
        bytes memory malformedSig = abi.encodePacked(bytes32(0), bytes32(0), uint8(27));

        // When signature is technically invalid:
        vm.expectRevert(
            abi.encodeWithSignature("ECDSAInvalidSignature()")
        );
        bridge.finalizeMigration(user, amount, SOURCE_CHAIN, transferId, malformedSig);

        // When signature is valid but NOT from aiSentinel:
        uint256 wrongPk = 0xBADBEEF;
        bytes32 msgHash = keccak256(
            abi.encode(user, amount, transferId, SOURCE_CHAIN, address(bridge), block.chainid)
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, msgHash);
        bytes memory wrongSig = abi.encodePacked(r, s, v);

        vm.expectRevert(AOXCErrors.AOXC_Neural_IdentityForgery.selector);
        bridge.finalizeMigration(user, amount, SOURCE_CHAIN, transferId, wrongSig);
    }

    function test_RevertIf_TransferIDIsReused() public {
        uint256 amount = 500 * 1e18;
        bytes32 transferId = keccak256("unique_tx_2026");

        bytes memory validSig = _generateSignature(user, amount, SOURCE_CHAIN, transferId);

        // First use
        bridge.finalizeMigration(user, amount, SOURCE_CHAIN, transferId, validSig);

        // Second use (Replay)
        vm.expectRevert(
            abi.encodeWithSelector(AOXCErrors.AOXC_Neural_SignatureReused.selector, transferId)
        );
        bridge.finalizeMigration(user, amount, SOURCE_CHAIN, transferId, validSig);
    }
}
