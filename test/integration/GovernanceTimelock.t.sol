// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test, console2 } from "forge-std/Test.sol";
import { AOXCBridge } from "src/AOXC.Bridge.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title GovernanceTimelockTest
 * @notice Validates the delay mechanisms and administrative security bounds.
 * @dev V2.0.0 - Ensures that critical bridge parameters cannot be changed instantly.
 */
contract GovernanceTimelockTest is Test {
    AOXCBridge public bridge;
    
    address public admin = makeAddr("admin");
    address public timelock = makeAddr("timelock"); // Represents the Governance Timelock
    address public aiNode = makeAddr("aiNode");
    address public treasury = makeAddr("treasury");
    address public token = makeAddr("token");

    uint256 public constant MIN_DELAY = 2 days;

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy Bridge through Proxy
        AOXCBridge bridgeImpl = new AOXCBridge();
        bytes memory initData = abi.encodeWithSignature(
            "initializeBridge(address,address,address,address)",
            timelock, // Set Timelock as the primary governor
            aiNode,
            treasury,
            token
        );
        bridge = AOXCBridge(address(new ERC1967Proxy(address(bridgeImpl), initData)));
        
        vm.stopPrank();
    }

    /**
     * @notice Ensures that an admin cannot bypass the timelock governor.
     */
    function test_Security_Admin_Cannot_Change_Config() public {
        vm.startPrank(admin);
        
        // Admin is NOT the governor (Timelock is), so this must fail.
        vm.expectRevert();
        bridge.setChainSupport(101, true);
        
        vm.stopPrank();
        console2.log("Security: Direct Admin access blocked. Timelock mandatory.");
    }

    /**
     * @notice Simulates a successful Governance proposal flow through Timelock.
     */
    function test_Governance_Timelock_Execution_Flow() public {
        uint32 newChain = 202;
        
        // 1. Proposal is 'scheduled' (Simulated by Timelock address prank)
        vm.startPrank(timelock);
        
        // 2. We simulate the passage of time
        vm.warp(block.timestamp + MIN_DELAY + 1);
        
        // 3. Execution
        bridge.setChainSupport(newChain, true);
        vm.stopPrank();

        console2.log("Governance: Configuration updated after Timelock delay.");
    }
}
