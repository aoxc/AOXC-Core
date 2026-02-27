// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXC} from "../../src/AOXC.sol";
import {AOXCConstants} from "../../src/libraries/AOXCConstants.sol";
import {AOXCErrors} from "../../src/libraries/AOXCErrors.sol";

contract MockSentinel {
    bool public allowNext = true;

    function setAllow(bool _allow) external {
        allowNext = _allow;
    }

    function isAllowed(address, address) external view returns (bool) {
        return allowNext;
    }
}

contract AOXCUnitTest is Test {
    AOXC public aoxc;
    MockSentinel public mockSentinel;

    address public admin = address(0x111);
    address public guardian = address(0x222);
    address public alice = address(0x333);
    address public bob = address(0x444);

    function setUp() public {
        mockSentinel = new MockSentinel();
        AOXC logic = new AOXC();

        bytes memory initData = abi.encodeWithSelector(AOXC.initializeV2.selector, address(mockSentinel), admin);
        aoxc = AOXC(address(new ERC1967Proxy(address(logic), initData)));

        vm.startPrank(admin);
        // [V2-FIX]: Unpause yetkisi GOVERNANCE_ROLE gerektirdiği için guardian'a bu rolü de veriyoruz
        aoxc.grantRole(AOXCConstants.GUARDIAN_ROLE, guardian);
        aoxc.grantRole(AOXCConstants.GOVERNANCE_ROLE, guardian);

        bool success = aoxc.transfer(alice, (AOXCConstants.INITIAL_SUPPLY * 100) / 10000);
        require(success, "Setup: Initial transfer failed");
        vm.stopPrank();
    }

    function _assertLowLevelRevert(bytes memory _data) internal {
        (bool success,) = address(aoxc).call(_data);
        assertTrue(!success, "Audit: Security Bypass Detected");
    }

    /**
     * @notice Ensures that the Guardian can freeze and unfreeze the protocol.
     */
    function test_SecurityPauseEffect() public {
        // Step 1: Pause (Requires GUARDIAN_ROLE)
        vm.prank(guardian);
        aoxc.pause();

        // Step 2: Verify lock
        vm.prank(alice);
        _assertLowLevelRevert(abi.encodeWithSelector(aoxc.transfer.selector, bob, 1000));

        // Step 3: Unpause (Requires GOVERNANCE_ROLE)
        vm.prank(guardian);
        aoxc.unpause();

        // Step 4: Verify resume
        vm.prank(alice);
        bool success = aoxc.transfer(bob, 1000);
        assertTrue(success, "L1: Resume failed");
    }

    // ... Diğer testler (Temporal, Sentinel, Whale, Mint) aynı kalabilir ...

    function test_TemporalBreachPrevention() public {
        vm.startPrank(alice);
        assertTrue(aoxc.transfer(bob, 100));
        _assertLowLevelRevert(abi.encodeWithSelector(aoxc.transfer.selector, bob, 100));
        vm.stopPrank();
    }

    function test_NeuralSentinelLockdown() public {
        mockSentinel.setAllow(false);
        vm.prank(alice);
        _assertLowLevelRevert(abi.encodeWithSelector(aoxc.transfer.selector, bob, 100));
    }

    function test_WhaleMagnitudeLimit() public {
        uint256 maxLimit = (AOXCConstants.INITIAL_SUPPLY * 200) / 10000;
        uint256 maliciousAmount = maxLimit + 1;
        vm.prank(admin);
        assertTrue(aoxc.transfer(alice, maliciousAmount));
        vm.prank(alice);
        _assertLowLevelRevert(abi.encodeWithSelector(aoxc.transfer.selector, bob, maliciousAmount));
    }

    function test_MonetaryMinting() public {
        vm.prank(admin);
        aoxc.mint(bob, 1000 ether);
        assertEq(aoxc.balanceOf(bob), 1000 ether);
    }

    function test_InflationHardcapEnforcement() public {
        uint256 cap =
            (AOXCConstants.INITIAL_SUPPLY * AOXCConstants.MAX_MINT_PER_YEAR_BPS) / AOXCConstants.BPS_DENOMINATOR;
        vm.prank(admin);
        vm.expectRevert(AOXCErrors.AOXC_InflationHardcapReached.selector);
        aoxc.mint(bob, cap + 1 wei);
    }
}
