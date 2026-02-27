// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AOXCDeepCoverageTest
 * @author AOXC Core Team
 * @notice Production-grade test suite for the AOXC ecosystem.
 * @dev Compliant with Foundry best practices and zero-warning linter requirements.
 */

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../../src/AOXC.sol";
import {AOXCConstants} from "../../src/libraries/AOXCConstants.sol";
import {AOXCErrors} from "../../src/libraries/AOXCErrors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockSentinel {
    bool public allowed = true;

    function setAllowed(bool _allowed) external {
        allowed = _allowed;
    }

    function isAllowed(address, address) external view returns (bool) {
        return allowed;
    }
}

contract AOXCDeepCoverageTest is Test {
    AOXC public aoxc;
    AOXC public implementation;
    MockSentinel public sentinel;

    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        sentinel = new MockSentinel();
        implementation = new AOXC();

        bytes memory initData = abi.encodeWithSelector(AOXC.initializeV2.selector, address(sentinel), admin);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        aoxc = AOXC(address(proxy));

        vm.prank(admin);
        assertTrue(aoxc.transfer(user1, 10_000 ether), "Setup: Initial transfer failed");
    }

    /*//////////////////////////////////////////////////////////////
                        1. DEFENSE ENGINE (SENTINEL)
    //////////////////////////////////////////////////////////////*/

    function test_Defense_TemporalBreach_Enforcement() public {
        vm.startPrank(user1);

        assertTrue(aoxc.transfer(user2, 100 ether), "Transfer 1 failed");

        vm.expectRevert(abi.encodeWithSelector(AOXCErrors.AOXC_TemporalBreach.selector, block.number, block.number));
        // FIX for Line 80: Wrapped reverting call in assertTrue to satisfy linter AST
        assertTrue(aoxc.transfer(user2, 100 ether));

        vm.stopPrank();
    }

    function test_Defense_NeuralBastion_Sealing() public {
        sentinel.setAllowed(false);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(AOXCErrors.AOXC_Neural_BastionSealed.selector, block.timestamp));
        // FIX for Line 93: Wrapped reverting call in assertTrue to satisfy linter AST
        assertTrue(aoxc.transfer(user2, 50 ether));
    }

    /*//////////////////////////////////////////////////////////////
                        2. INFLATION AND HARDCAP
    //////////////////////////////////////////////////////////////*/

    function test_Inflation_Hardcap_Enforcement(uint256 amount) public {
        uint256 maxMint = (aoxc.totalSupply() * AOXCConstants.MAX_MINT_PER_YEAR_BPS) / AOXCConstants.BPS_DENOMINATOR;
        amount = bound(amount, maxMint + 1, maxMint + 1_000_000 ether);

        vm.startPrank(admin);
        vm.expectRevert(AOXCErrors.AOXC_InflationHardcapReached.selector);
        aoxc.mint(admin, amount);

        aoxc.mint(admin, maxMint);
        assertEq(aoxc.totalSupply(), 1_000_000_000 ether + maxMint);

        skip(365 days + 1);
        aoxc.mint(admin, 100 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        3. EMERGENCY (GLOBAL LOCK)
    //////////////////////////////////////////////////////////////*/

    function test_Emergency_GlobalLock_Flow() public {
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, false);
        emit Paused(admin);
        aoxc.pause();
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(AOXCErrors.AOXC_GlobalLockActive.selector);
        // FIX for Line 129: Wrapped reverting call in assertTrue to satisfy linter AST
        assertTrue(aoxc.transfer(user2, 10 ether));

        vm.prank(admin);
        aoxc.unpause();

        vm.prank(user1);
        assertTrue(aoxc.transfer(user2, 10 ether), "Transfer failed after unlocking");
    }
}
