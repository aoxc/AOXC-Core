// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console2} from "forge-std/Script.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title AOXC Sovereign Infrastructure Deployment
 * @notice Formal deployment of V1 Core using ERC1967 Proxy standards.
 * @dev Full compliance with Solc 0.8.33 EIP-55 checksum requirements.
 */
contract XLayerDeploy is Script {
    /**
     * @dev MULTISIG_COUNCIL address - EXACT CHECKSUM REQUIRED BY SOLC 0.8.33
     * This address is the ultimate authority of the system.
     */
    address public constant MULTISIG_COUNCIL = 0x20c0DD8B6559912acfAC2ce061B8d5b19Db8CA84;

    function run() external {
        // --- 1. ENVIRONMENT INITIALIZATION ---
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("----------------------------------------------------");
        console2.log("AOXC SYSTEM ARCHITECTURE: DEPLOYMENT LOG");
        console2.log("----------------------------------------------------");
        console2.log("TARGET NETWORK : X-Layer Testnet");
        console2.log("OPERATOR       :", deployer);
        console2.log("COUNCIL (OWNER):", MULTISIG_COUNCIL);
        console2.log("EVM VERSION    : Cancun (0.8.33)");
        console2.log("----------------------------------------------------");

        vm.startBroadcast(deployerPrivateKey);

        // --- 2. LOGIC IMPLEMENTATION DEPLOYMENT ---
        console2.log("[STAGE 1/2] Deploying V1 Core Logic Implementation...");
        AOXC v1Logic = new AOXC();
        console2.log("LOGIC ADDRESS  :", address(v1Logic));

        // --- 3. PROXY INITIALIZATION & OWNERSHIP TRANSFER ---
        // Atomic transaction: Proxy links to Logic and transfers power to Multi-sig.
        console2.log("[STAGE 2/2] Constructing ERC1967 Proxy...");

        ERC1967Proxy proxy =
            new ERC1967Proxy(address(v1Logic), abi.encodeWithSignature("initialize(address)", MULTISIG_COUNCIL));

        vm.stopBroadcast();

        // --- 4. FINAL AUDIT SUMMARY ---
        console2.log("----------------------------------------------------");
        console2.log("STATUS: SUCCESSFUL DEPLOYMENT");
        console2.log("----------------------------------------------------");
        console2.log("CONTRACT (PROXY) :", address(proxy));
        console2.log("LOGIC ADDRESS    :", address(v1Logic));
        console2.log("FINAL AUTHORITY  :", MULTISIG_COUNCIL);
        console2.log("GOVERNANCE TYPE  : Multi-Signature Sovereign");
        console2.log("----------------------------------------------------");
    }
}
