// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AOXCCoverageTest} from "./AOXC_Coverage.t.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC Protocol Final Audit Suite
 * @author AOXC Protocol Engineering
 * @notice High-fidelity test suite designed to achieve 100% branch and line coverage.
 * @dev Fully compliant with Foundry linter and professional smart contract audit standards.
 */
contract AOXCFinalAuditTest is AOXCCoverageTest {

    /**
     * @notice Validates the zero address prevention during the initialization phase.
     * @dev Uses a Mock Proxy to bypass the implementation contract's initializer lockdown.
     */
    function testBranchInitializeZeroAddress() public {
        AOXC newImpl = new AOXC();
        vm.expectRevert("AOXC: Zero Addr");
        
        new AOXCProxyMock(
            address(newImpl), 
            abi.encodeWithSelector(AOXC.initialize.selector, address(0))
        );
    }

    /**
     * @notice Verifies that administrative accounts are immune to blacklisting.
     */
    function testBranchAdminBlacklistImmunity() public {
        vm.startPrank(complianceOfficer);
        vm.expectRevert("AOXC: Admin Immunity");
        proxy.addToBlacklist(admin, "Immune");
        vm.stopPrank();
    }

    /**
     * @notice Ensures the protocol prevents accidental rescue of its own token address.
     */
    function testBranchRescueNativeTokenFail() public {
        vm.prank(admin);
        vm.expectRevert("AOXC: Native");
        proxy.rescueERC20(address(proxy), 100e18);
    }

    /**
     * @notice Achieves 100% Branch Coverage for 'AOXC: Cap' and 'periods' calculation.
     * @dev Covers the branch where block.timestamp is multiple years ahead (periods > 1).
     */
    function testBranchHardCapLimit() public {
        vm.startPrank(admin);
        uint256 maxAnnual = proxy.yearlyMintLimit();
        uint256 targetSupply = INITIAL_SUPPLY * 3;
        uint256 currentTime = block.timestamp;

        // Step 1: Jump 3 years at once to cover the (periods > 1) branch in mint()
        currentTime += (365 days * 3) + 1;
        vm.warp(currentTime);
        proxy.mint(admin, maxAnnual);

        // Step 2: Progressively saturate supply to reach the absolute Hard Cap
        for (uint256 i = 1; i <= 40; i++) {
            currentTime += 365 days + 1;
            vm.warp(currentTime); 
            if (proxy.totalSupply() + maxAnnual > targetSupply) break;
            proxy.mint(admin, maxAnnual);
        }

        // Step 3: Trigger the absolute cap branch
        uint256 roomLeft = targetSupply - proxy.totalSupply();
        vm.expectRevert("AOXC: Cap");
        proxy.mint(admin, roomLeft + 1);
        vm.stopPrank();
    }

    /**
     * @notice Tests the protocol's resilience against failing ERC20 external calls.
     */
    function testBranchRescueERC20TransferFail() public {
        FailToken failToken = new FailToken();
        vm.prank(admin);
        vm.expectRevert("AOXC: Failed");
        proxy.rescueERC20(address(failToken), 100);
    }

    /**
     * @notice Validates the successful removal of an address from the blacklist.
     */
    function testBranchRemoveFromBlacklist() public {
        vm.startPrank(complianceOfficer);
        proxy.addToBlacklist(user1, "Ban");
        proxy.removeFromBlacklist(user1);
        assertFalse(proxy.isBlacklisted(user1));
        vm.stopPrank();
    }

    /**
     * @notice FULL SPECTRUM: Covers all branches in _update (Mint/Burn/Transfer/Exclusion).
     * @dev Hits the remaining branches by forcing all conditional paths in ERC20 logic.
     */
    function testFinalExhaustiveBranches() public {
        // 1. Path: Minting (from == address(0))
        vm.prank(admin);
        proxy.mint(user1, 1000e18);

        // 2. Path: Burning (to == address(0))
        vm.prank(user1);
        proxy.burn(100e18);

        // 3. Path: Normal Transfer (from != 0, to != 0, !isExcluded)
        vm.prank(user1);
        bool s1 = proxy.transfer(user2, 100e18);
        assertTrue(s1, "Transfer failed");

        // 4. Path: Excluded Transfer (admin is excluded)
        // Covers: !isExcludedFromLimits[from] being false
        vm.prank(admin);
        bool s2 = proxy.transfer(user2, 100e18);
        assertTrue(s2, "Excluded transfer failed");

        // 5. Path: Self-transfer (from == to)
        vm.prank(user2);
        bool s3 = proxy.transfer(user2, 10e18);
        assertTrue(s3, "Self-transfer failed");
    }
}

/**
 * @title AOXCProxyMock
 * @dev A minimal proxy mock for testing initialization failure states via delegatecall.
 */
contract AOXCProxyMock {
    constructor(address _logic, bytes memory _data) {
        (bool success, ) = _logic.delegatecall(_data);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}

/**
 * @title FailToken
 * @dev Helper contract simulating a non-compliant token that returns 'false' on transfer.
 */
contract FailToken {
    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }
}
