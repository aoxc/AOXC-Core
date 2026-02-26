// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IAOXC } from "../../../src/interfaces/IAOXC.sol";
import { AOXCStaking } from "../../../src/AOXC.Stake.sol";

/**
 * @title StakeHandler
 * @notice Logic handler for fuzzing the staking component of the AOXC ecosystem.
 * @dev Tracks "ghost state" to verify that contract balances match internal accounting.
 */
contract StakeHandler is CommonBase, StdCheats, StdUtils {
    IAOXC public immutable aoxc;
    AOXCStaking public immutable staking;

    // --- Ghost Variables (Accounting Tracking) ---
    uint256 public ghost_totalStaked;
    mapping(address => uint256) public ghost_individualStakes;

    constructor(IAOXC _aoxc, AOXCStaking _staking) {
        aoxc = _aoxc;
        staking = _staking;
    }

    /**
     * @notice Handler function for 'stakeSovereign' with input bounding and state tracking.
     * @param amount Fuzzed amount to stake.
     * @param lockPeriod Fuzzed duration for the lock.
     */
    function stakeSovereign(uint256 amount, uint256 lockPeriod) public {
        // 1. Pre-condition: Check handler balance
        uint256 balance = aoxc.balanceOf(address(this));
        if (balance == 0) return;

        // 2. Input Bounding (Ensures valid range for protocol)
        amount = bound(amount, 1, balance);
        lockPeriod = bound(lockPeriod, 30 days, 365 days); // Example bounds

        // 3. Execution (Assuming neural identity is handled via admin role in setup)
        aoxc.approve(address(staking), amount);
        
        // Using empty proof as placeholder based on integration logs
        staking.stakeSovereign(amount, lockPeriod, "");

        // 4. Update Ghost State
        ghost_totalStaked += amount;
        ghost_individualStakes[address(this)] += amount;
    }
}
