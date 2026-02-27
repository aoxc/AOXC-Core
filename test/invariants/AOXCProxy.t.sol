// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXC} from "../../src/AOXC.sol";
import {AOXCConstants} from "../../src/libraries/AOXCConstants.sol";

/**
 * @title AOXCProxyTest
 * @notice Validates UUPS Proxy integrity and initialization security.
 */
contract AOXCProxyTest is Test {
    AOXC public implementation;
    AOXC public proxy;
    address public admin = address(0x1);
    address public sentinel = address(0x2);

    function setUp() public {
        // 1. Deploy logic implementation
        implementation = new AOXC();

        // 2. Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(AOXC.initializeV2.selector, sentinel, admin);

        // 3. Deploy Proxy (pointing to implementation)
        ERC1967Proxy rawProxy = new ERC1967Proxy(address(implementation), initData);

        // 4. Wrap proxy address in AOXC interface
        proxy = AOXC(address(rawProxy));
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialSupply() public view {
        assertEq(proxy.totalSupply(), AOXCConstants.INITIAL_SUPPLY);
        assertEq(proxy.balanceOf(admin), AOXCConstants.INITIAL_SUPPLY);
    }

    function test_SentinelAddress() public view {
        assertEq(proxy.getSentinel(), sentinel);
    }

    /**
     * @notice CRITICAL: Ensures implementation contract is initialized/locked.
     */
    function test_ImplementationIsLocked() public {
        // Implementation constructor calls _disableInitializers()
        vm.expectRevert();
        implementation.initializeV2(address(0xdead), address(0xbeef));
    }

    /**
     * @notice Validates role assignment during proxy setup.
     * @dev Fixed: Accessing constant from AOXCConstants instead of calling as function.
     */
    function test_AdminHasGovernanceRole() public view {
        // Access the constant directly from your library
        bytes32 govRole = AOXCConstants.GOVERNANCE_ROLE;
        assertTrue(proxy.hasRole(govRole, admin));
    }
}
