// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title AOXC Deployment Script
 * @author AOXC Protocol Engineering
 * @notice Handles the orchestration of UUPS Proxy deployment for the AOXC Token.
 */
contract DeployAOXC is Script {
    // Structural state variables for deployment tracking
    address public implementationAddress;
    address public proxyAddress;
    address public governor;

    function run() external returns (address) {
        // --- 1. Environment Configuration ---
        // Prioritize environment variables for security and CI/CD flexibility.
        // Falls back to a default only for local testing environments.
        governor = vm.envOr("GOVERNOR_ADDRESS", 0x20c0DD8B6559912acfAC2ce061B8d5b19Db8CA84);
        
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console2.log("Initiating AOXC Protocol Deployment...");
        console2.log("Target Governor/Multisig:", governor);
        console2.log("Network Chain ID:", block.chainid);

        // --- 2. Execution ---
        vm.startBroadcast(deployerPrivateKey);

        // Phase A: Deploy Logic Infrastructure (Implementation)
        AOXC implementation = new AOXC();
        implementationAddress = address(implementation);
        
        // Phase B: Prepare Initialization Payload
        // Using the selector for type-safe interaction with the implementation
        bytes memory initData = abi.encodeWithSelector(
            AOXC.initialize.selector,
            governor
        );

        // Phase C: Deploy Programmable Proxy (ERC-1967)
        // This establishes the permanent address for the AOXC token.
        ERC1967Proxy proxy = new ERC1967Proxy(implementationAddress, initData);
        proxyAddress = address(proxy);

        vm.stopBroadcast();

        // --- 3. Deployment Validation & Logging ---
        _printDeploymentSummary();

        return proxyAddress;
    }

    /**
     * @dev Internal helper for professional console reporting.
     */
    function _printDeploymentSummary() internal view {
        console2.log("\n-----------------------------------------");
        console2.log("AOXC DEPLOYMENT SUCCESSFUL");
        console2.log("-----------------------------------------");
        console2.log("Proxy (Main Address): ", proxyAddress);
        console2.log("Implementation Logic: ", implementationAddress);
        console2.log("Governance/Admin:     ", governor);
        console2.log("Standard:             UUPS (ERC-1967)");
        console2.log("-----------------------------------------\n");
    }
}
