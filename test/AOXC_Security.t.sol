// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AOXCTest} from "./AOXC.t.sol";

/**
 * @title AOXC Security & RBAC Enforcement
 * @notice Validates that access control and compliance rules are strictly enforced.
 */
contract AOXCSecurityTest is AOXCTest {
    
    /**
     * @notice Ensures that the Compliance Officer role is isolated from Minter privileges.
     */
    function testSecurityPrivilegeEscalationComplianceCannotMint() public {
        vm.startPrank(complianceOfficer);
        vm.expectRevert(); 
        proxy.mint(user1, 1_000_000e18);
        vm.stopPrank();
    }

    /**
     * @notice Validates that non-admin users can be blacklisted and blocked from transactions.
     * @dev Note: Admin accounts possess 'Admin Immunity' in the implementation.
     */
    function testSecurityComplianceEnforcementOnUsers() public {
        vm.prank(complianceOfficer);
        proxy.addToBlacklist(user2, "Compliance Risk");

        assertTrue(proxy.isBlacklisted(user2));

        vm.prank(user2);
        vm.expectRevert("AOXC: BL Sender");
        bool success = proxy.transfer(user1, 1e18);
        assertTrue(!success); // Final validation for the linter
    }

    /**
     * @notice Prevents unauthorized re-initialization of the proxy.
     */
    function testSecurityExploitReinitializationAttempt() public {
        vm.expectRevert();
        proxy.initialize(user2);
    }

    /**
     * @notice Verifies that the logic contract (implementation) is locked and cannot be hijacked.
     */
    function testSecurityImplementationContractLockdown() public {
        vm.expectRevert();
        implementation.initialize(user2);
    }
}
