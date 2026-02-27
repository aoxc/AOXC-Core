// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "src/AOXC.sol";
import {AOXCTimelock} from "src/AOXC.Timelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXCConstants} from "src/libraries/AOXCConstants.sol";

/**
 * @title GovernanceTimelockTest V2.1.4
 * @notice Production-grade Governance integration suite.
 * @dev Removed unused imports (console2) and optimized state checks.
 */
contract GovernanceTimelockTest is Test {
    AOXC public aoxc;
    AOXCTimelock public timelock;

    address public admin = makeAddr("admin");
    uint256 public constant AI_NODE_PRIVATE_KEY = 0xA11CE;
    address public aiNode;
    address public proposer = makeAddr("proposer");
    address public executor = makeAddr("executor");
    address public newGovernor = makeAddr("newGovernor");

    function setUp() public {
        aiNode = vm.addr(AI_NODE_PRIVATE_KEY);
        vm.startPrank(admin);

        // 1. Deploy AOXC via Proxy
        aoxc = AOXC(
            address(
                new ERC1967Proxy(
                    address(new AOXC()),
                    abi.encodeWithSignature("initializeV2(address,address)", makeAddr("sentinel"), admin)
                )
            )
        );

        // 2. Setup Timelock
        address timelockImpl = address(new AOXCTimelock());
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        timelock = AOXCTimelock(
            payable(address(
                    new ERC1967Proxy(
                        timelockImpl,
                        abi.encodeWithSelector(
                            AOXCTimelock.initializeApex.selector,
                            AOXCConstants.MIN_TIMELOCK_DELAY,
                            proposers,
                            executors,
                            admin,
                            aiNode
                        )
                    )
                ))
        );

        // 3. RBAC Linkage (Timelock becomes a high-privilege actor)
        aoxc.grantRole(bytes32(0), address(timelock));

        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        timelock.grantRole(cancellerRole, address(this));
        timelock.grantRole(cancellerRole, address(timelock));

        vm.stopPrank();
    }

    /**
     * @notice Test standard execution flow through the timelock.
     */
    function test_Governance_Timelock_Execution_Flow() public {
        bytes memory data =
            abi.encodeWithSignature("grantRole(bytes32,address)", AOXCConstants.GOVERNANCE_ROLE, newGovernor);
        uint256 delay = AOXCConstants.MIN_TIMELOCK_DELAY;

        vm.prank(proposer);
        timelock.schedule(address(aoxc), 0, data, bytes32(0), bytes32(0), delay);

        vm.warp(block.timestamp + delay + 1);

        vm.prank(executor);
        timelock.execute(address(aoxc), 0, data, bytes32(0), bytes32(0));

        assertTrue(aoxc.hasRole(AOXCConstants.GOVERNANCE_ROLE, newGovernor));
    }

    /**
     * @notice TEST: AI-Driven Sovereign Veto
     * @dev Layer 26: AI cancels operation. Verified via Log Emission and State Deletion.
     */
    function test_Sovereign_Neural_Veto() public {
        bytes memory data =
            abi.encodeWithSignature("grantRole(bytes32,address)", AOXCConstants.GOVERNANCE_ROLE, newGovernor);

        vm.prank(proposer);
        timelock.schedule(address(aoxc), 0, data, bytes32(0), bytes32(0), AOXCConstants.MIN_TIMELOCK_DELAY);

        bytes32 id = timelock.hashOperation(address(aoxc), 0, data, bytes32(0), bytes32(0));

        // Neural Signature Preparation
        bytes32 msgHash = keccak256(abi.encode(id, 0, address(timelock), block.chainid));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_NODE_PRIVATE_KEY, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Action: AI Intervention
        vm.expectEmit(true, false, false, true);
        emit AOXCTimelock.AISovereignVeto(id, "Neural Sentinel Intervention");
        timelock.neuralVeto(id, signature);

        // OZ cancel() behavior check: State 0 means Unset/Deleted
        assertEq(uint8(timelock.getOperationState(id)), 0, "Neural Veto failed: Operation not deleted");
        assertFalse(timelock.isOperation(id), "Neural Veto failed: Operation still exists");
    }
}
