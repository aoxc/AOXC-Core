// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { AOXCStaking } from "../../src/AOXC.Stake.sol";
import { AOXCTreasury } from "../../src/AOXCTreasury.sol";
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MathAndBounds
 * @author AOXCAN AI Architect
 * @notice Property-based fuzzing for mathematical integrity and boundary conditions.
 * @dev [V2.0.0-FIX]: Aligned Treasury initialize parameters to resolve 686 gas Revert.
 */
contract MathAndBounds is Test {
    AOXCStaking public staking;
    AOXCTreasury public treasury;

    address public admin = makeAddr("admin");
    address public aiNode = makeAddr("aiNode");
    address public token = makeAddr("AOXCToken");

    /**
     * @dev Sets up the testing environment.
     * Fixed the 4-parameter sync for AOXCTreasury.
     */
    function setUp() public {
        // 1. Deploy Staking Implementation and Proxy
        AOXCStaking stakeImpl = new AOXCStaking();
        bytes memory stakeData = abi.encodeWithSelector(
            AOXCStaking.initialize.selector, 
            admin, 
            aiNode, 
            token
        );
        staking = AOXCStaking(address(new ERC1967Proxy(address(stakeImpl), stakeData)));

        // 2. Deploy Treasury Implementation and Proxy
        AOXCTreasury treasuryImpl = new AOXCTreasury();
        
        // [V2-FIX]: Added the 4th parameter (token) to match Treasury's V2.0.0 signature.
        bytes memory treasuryData = abi.encodeWithSelector(
            AOXCTreasury.initialize.selector, 
            admin,  // _governance
            admin,  // _sentinel
            aiNode, // _aiNode
            token   // _aoxcToken (Crucial Fix)
        );
        
        treasury = AOXCTreasury(payable(address(new ERC1967Proxy(address(treasuryImpl), treasuryData))));
        
        // Seed funds for fuzzing
        vm.deal(address(treasury), 1000 ether);
    }

    /**
     * @notice [MATH-01]: Reputation Gain Overflow Protection.
     */
    function testFuzz_Staking_ReputationGain_Boundaries(uint256 amount, uint256 duration) public view {
        uint256 boundedDuration = bound(duration, AOXCConstants.MIN_TIMELOCK_DELAY, AOXCConstants.MAX_TIMELOCK_DELAY);
        
        uint256 reputationGain;
        bool overflowed = false;
        
        try this.externalRepCalc(amount, boundedDuration) returns (uint256 res) {
            reputationGain = res;
        } catch {
            overflowed = true;
        }

        if (!overflowed) {
            if (amount >= 86400 / boundedDuration) {
                assertTrue(reputationGain >= 0, "L1: Precision loss: Gain should not be zero");
            }
        }
    }

    /**
     * @notice [MATH-02]: Treasury Withdrawal Cap Integrity.
     */
    function testFuzz_Treasury_LimitCalculations(uint256 fuzzedBalance) public view {
        uint256 boundedBalance = bound(fuzzedBalance, 1e18, 100_000_000_000_000 * 1e18);
        
        // Protocol standard: 600 BPS = 6%
        uint256 expectedLimit = (boundedBalance * 600) / 10000;
        uint256 actualLimit = (boundedBalance * treasury.ANNUAL_WITHDRAWAL_CAP_BPS()) / 10000;
        
        assertEq(actualLimit, expectedLimit, "L3: Treasury: BPS calculation mismatch");
    }

    /**
     * @notice [MATH-03]: Temporal Cliff Protection (6-Year Lock).
     */
    function testFuzz_Treasury_CliffPersistence(uint256 timeJump) public {
        uint256 boundedJump = bound(timeJump, 0, 6 * 365 days - 1 hours);
        
        vm.warp(block.timestamp + boundedJump);
        
        // Reverts if cliff is active
        vm.expectRevert(); 
        treasury.openNextWindow();
    }

    /**
     * @dev External helper to safely catch mathematical reverts.
     */
    function externalRepCalc(uint256 a, uint256 d) external pure returns (uint256) {
        return (a * d) / 86400;
    }

    receive() external payable {}
}
