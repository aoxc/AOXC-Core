// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCTimelockFullTest
 * @author AOXC Core Team
 * @notice Enterprise-grade test suite for the AOXCTimelock mechanism.
 * @dev Fully compliant with Foundry best practices, utilizing named imports and explicit error handling.
 */

import {Test} from "forge-std/Test.sol";
import {AOXCTimelock} from "../../src/AOXC.Timelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract AOXCTimelockFullTest is Test {
    using MessageHashUtils for bytes32;

    AOXCTimelock public timelock;
    address public aiNode;
    uint256 public aiPrivateKey;

    // Test Actors - Constants for Gas Efficiency and Clarity
    address public constant ADMIN = address(0xAD);
    address public constant PROPOSER = address(0xBB);
    address public constant EXECUTOR = address(0xCC);
    address public constant TEST_TARGET = address(0xDD);
    uint256 public constant MIN_DELAY = 2 days;

    /**
     * @notice System setup: Deploys implementation, proxy, and initializes roles.
     */
    function setUp() public {
        aiPrivateKey = 0xA1;
        aiNode = vm.addr(aiPrivateKey);

        AOXCTimelock implementation = new AOXCTimelock();

        address[] memory proposers = new address[](1);
        proposers[0] = PROPOSER;

        address[] memory executors = new address[](1);
        executors[0] = EXECUTOR;

        bytes memory initData = abi.encodeWithSelector(
            AOXCTimelock.initializeApex.selector, MIN_DELAY, proposers, executors, ADMIN, aiNode
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        timelock = AOXCTimelock(payable(address(proxy)));

        // Granting roles via Admin for internal test logic
        vm.startPrank(ADMIN);
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(this));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        1. NEURAL VETO (AI BRANCHES)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests the cryptographic Neural Veto functionality.
     */
    function test_NeuralVeto_Success() public {
        bytes memory data = "";
        bytes32 salt = keccak256("full_1");
        bytes32 id = timelock.hashOperation(TEST_TARGET, 0, data, bytes32(0), salt);

        vm.prank(PROPOSER);
        timelock.schedule(TEST_TARGET, 0, data, bytes32(0), salt, MIN_DELAY);

        // Generate EIP-191 Signature
        bytes32 msgHash = keccak256(abi.encode(id, 0, address(timelock), block.chainid)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiPrivateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        timelock.neuralVeto(id, signature);

        // Verify state (0 = Unset/Canceled, 4 = Canceled in some OpenZeppelin versions)
        uint256 state = uint256(timelock.getOperationState(id));
        assertTrue(state == 0 || state == 4, "Neural Veto failed to cancel operation");
    }

    /**
     * @notice Ensures signatures cannot be replayed for vetoes.
     */
    function test_RevertIf_NeuralSignatureReused() public {
        bytes32 salt = keccak256("full_2");
        bytes32 id = timelock.hashOperation(TEST_TARGET, 0, "", bytes32(0), salt);

        vm.prank(PROPOSER);
        timelock.schedule(TEST_TARGET, 0, "", bytes32(0), salt, MIN_DELAY);

        bytes32 msgHash = keccak256(abi.encode(id, 0, address(timelock), block.chainid)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiPrivateKey, msgHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        timelock.neuralVeto(id, signature);

        // Replay attempt should revert
        vm.expectRevert();
        timelock.neuralVeto(id, signature);
    }

    /*//////////////////////////////////////////////////////////////
                        2. SECURITY & DELAY BRANCHES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that value-bearing transactions enforce a 7-day minimum delay.
     */
    function test_Schedule_EnforcedDelay_Value() public {
        vm.warp(2000);
        bytes32 salt = keccak256("full_4");
        bytes32 id = timelock.hashOperation(TEST_TARGET, 1 ether, "", bytes32(0), salt);

        vm.prank(PROPOSER);
        timelock.schedule(TEST_TARGET, 1 ether, "", bytes32(0), salt, 1 days);

        // Value transfers should override user input with global security minimum (7 days)
        assertEq(timelock.getTimestamp(id), 2000 + 7 days);
    }

    /**
     * @notice Verifies specific target security tier enforcement.
     */
    function test_Schedule_SecurityTier_Enforcement() public {
        vm.warp(3000);
        vm.prank(ADMIN);
        timelock.setTargetSecurityTier(TEST_TARGET, 10 days);

        bytes32 salt = keccak256("full_5");
        bytes32 id = timelock.hashOperation(TEST_TARGET, 0, "", bytes32(0), salt);

        vm.prank(PROPOSER);
        timelock.schedule(TEST_TARGET, 0, "", bytes32(0), salt, 2 days);

        assertEq(timelock.getTimestamp(id), 3000 + 10 days);
    }

    /*//////////////////////////////////////////////////////////////
                        3. ADMIN & ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures delay updates can only be executed through the timelock itself.
     */
    function test_UpdateDelay_AdminOnly() public {
        vm.prank(address(timelock));
        timelock.updateDelay(5 days);
        assertEq(timelock.getMinDelay(), 5 days);
    }

    function test_RevertIf_NonAdmin_SetsDelay() public {
        vm.prank(PROPOSER);
        vm.expectRevert();
        timelock.updateDelay(1 days);
    }

    /*//////////////////////////////////////////////////////////////
                        4. ETHER & UPGRADES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Confirms the Timelock can receive ETH for operation execution.
     */
    function test_Receive_ETH() public {
        vm.deal(ADMIN, 10 ether);
        vm.prank(ADMIN);
        (bool success,) = address(timelock).call{value: 5 ether}("");
        assertTrue(success, "ETH transfer failed");
    }

    /**
     * @notice Ensures upgrades are restricted to the DAO/Self-execution.
     */
    function test_RevertIf_UnauthorizedUpgrade() public {
        address newImp = address(new AOXCTimelock());
        vm.prank(ADMIN);
        vm.expectRevert();
        timelock.upgradeToAndCall(newImp, "");
    }
}
