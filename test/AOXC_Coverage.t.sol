// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AOXCTest} from "./AOXC.t.sol";

contract AOXCCoverageTest is AOXCTest {
    
    /**
     * @notice Covers 'pause' and 'unpause' functions and their impact on 'mint'.
     */
    function testCoveragePauseMechanics() public {
        vm.startPrank(admin);
        proxy.pause();
        assertTrue(proxy.paused());

        // Mint should fail when paused
        vm.expectRevert(); 
        proxy.mint(user1, 100);

        proxy.unpause();
        assertFalse(proxy.paused());
        vm.stopPrank();
    }

    /**
     * @notice Covers 'isBlacklisted' and public mappings.
     */
    function testCoverageGetters() public {
        vm.prank(complianceOfficer);
        proxy.addToBlacklist(user2, "Test");
        
        assertTrue(proxy.isBlacklisted(user2));
        assertEq(proxy.blacklistReason(user2), "Test");
        
        // Nonces coverage
        uint256 currentNonce = proxy.nonces(user1);
        assertEq(currentNonce, 0);
    }

    /**
     * @notice Covers multi-year jumps in inflation logic (periods > 1).
     */
    function testCoverageMultiYearMint() public {
        vm.startPrank(admin);
        // 3 yıl ileri atla (mint fonksiyonundaki 'periods' hesaplamasını tetikler)
        vm.warp(block.timestamp + (3 * 365 days) + 1 days);
        proxy.mint(user1, 1000e18);
        vm.stopPrank();
    }

    /**
     * @notice Covers setExclusionFromLimits.
     */
    function testCoverageExclusions() public {
        vm.prank(admin);
        proxy.setExclusionFromLimits(user2, true);
        assertTrue(proxy.isExcludedFromLimits(user2));
    }
}
