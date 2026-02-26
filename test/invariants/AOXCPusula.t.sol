// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AOXC } from "../../src/AOXC.sol";
import { AOXCStaking } from "../../src/AOXC.Stake.sol";
import { AOXCSwap } from "../../src/AOXC.Swap.sol";
import { AOXCTreasury } from "../../src/AOXCTreasury.sol";
import { AOXCHandler } from "./handlers/AOXCHandler.sol";
import { StakeHandler } from "./handlers/StakeHandler.sol"; // Added
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";

/**
 * @title AOXCPusula V2.1.0 (Audit-Grade Suite)
 * @notice Invariant test suite for Sovereign AOXC Ecosystem.
 */
contract AOXCPusula is StdInvariant, Test {
    using SafeERC20 for AOXC;

    AOXC public aoxc;
    AOXCStaking public staking;
    AOXCSwap public swap;
    AOXCTreasury public treasury;
    AOXCHandler public handler;
    StakeHandler public stakeHandler; // Added

    address private admin = makeAddr("admin");
    address private sentinel = makeAddr("sentinel");
    address private aiNode = makeAddr("aiNode");
    address private oracle = makeAddr("oracle");

    function setUp() public {
        // 1. Core Deployments (V2 Standard)
        aoxc = AOXC(_deploy(address(new AOXC()), abi.encodeWithSelector(AOXC.initializeV2.selector, sentinel, admin)));
        staking = AOXCStaking(_deploy(address(new AOXCStaking()), abi.encodeWithSelector(AOXCStaking.initialize.selector, admin, aiNode, address(aoxc))));
        treasury = AOXCTreasury(payable(_deploy(address(new AOXCTreasury()), abi.encodeWithSelector(AOXCTreasury.initialize.selector, admin, sentinel, aiNode, address(aoxc)))));
        swap = AOXCSwap(_deploy(address(new AOXCSwap()), abi.encodeWithSelector(AOXCSwap.initialize.selector, admin, oracle, address(treasury))));

        // 2. Handler Setup
        handler = new AOXCHandler(address(aoxc), address(staking), address(swap), payable(address(treasury)));
        stakeHandler = new StakeHandler(aoxc, staking); // Initialize New Handler

        // 3. Permissions & Seeding
        _finalizeSetup();

        // 4. Define Invariant Targets
        targetContract(address(handler));
        targetContract(address(stakeHandler)); // Target multiple handlers
    }

    function _deploy(address logic, bytes memory data) internal returns (address) {
        return address(new ERC1967Proxy(logic, data));
    }

    function _finalizeSetup() internal {
        vm.startPrank(admin);
        aoxc.grantRole(AOXCConstants.GOVERNANCE_ROLE, address(handler));
        aoxc.grantRole(AOXCConstants.GOVERNANCE_ROLE, address(stakeHandler)); // Grant to StakeHandler
        
        // Initial Seed: 2% to General Handler, 1% to StakeHandler
        uint256 seedGeneral = (AOXCConstants.INITIAL_SUPPLY * 200) / 10000;
        uint256 seedStake = (AOXCConstants.INITIAL_SUPPLY * 100) / 10000;
        
        aoxc.transfer(address(handler), seedGeneral);
        aoxc.transfer(address(stakeHandler), seedStake);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function invariant_A_SupplyFloor() public view {
        assertGe(aoxc.totalSupply(), AOXCConstants.INITIAL_SUPPLY, "L1: Total supply below floor");
    }

    function invariant_B_InflationCap() public view {
        uint256 max = AOXCConstants.INITIAL_SUPPLY + (AOXCConstants.INITIAL_SUPPLY * AOXCConstants.MAX_MINT_PER_YEAR_BPS / 10000);
        assertLe(aoxc.totalSupply(), max, "L2: Inflation cap breached");
    }

    /**
     * @notice DEEP AUDIT INVARIANT: Verifies that staking contract balance 
     * matches the sum of individual fuzzed stakes.
     */
    function invariant_D_StakingAccountingIntegrity() public view {
        assertEq(
            aoxc.balanceOf(address(staking)), 
            stakeHandler.ghost_totalStaked(), 
            "L4: Staking balance mismatch with ghost tracking"
        );
    }
}
