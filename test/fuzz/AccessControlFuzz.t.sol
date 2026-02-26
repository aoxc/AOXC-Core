// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/*//////////////////////////////////////////////////////////////
                        AOXC CORE IMPORTS
//////////////////////////////////////////////////////////////*/

// [FIX]: Updated paths to match the actual file names in AOXC-Core/src
import { AOXCXLayerSentinel } from "../../src/AOXCXLayerSentinel.sol";
import { AOXCStaking } from "../../src/AOXC.Stake.sol"; 
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";

/**
 * @title AccessControlFuzz
 * @author AOXCAN AI Architect
 * @notice High-fidelity security fuzzing. Verified zero-warning logic.
 */
contract AccessControlFuzz is Test {
    AOXCXLayerSentinel public sentinel;
    AOXCStaking public staking;

    address public admin = address(0xAD31);
    address public aiNode = address(0xA1);
    address public token = AOXCConstants.AOXC_TOKEN_ADDRESS;

    function setUp() public {
        // Sentinel Deployment
        AOXCXLayerSentinel sentinelImpl = new AOXCXLayerSentinel();
        bytes memory sentinelData = abi.encodeWithSelector(
            AOXCXLayerSentinel.initialize.selector, admin, aiNode
        );
        sentinel = AOXCXLayerSentinel(address(new ERC1967Proxy(address(sentinelImpl), sentinelData)));

        // Staking Deployment
        AOXCStaking stakingImpl = new AOXCStaking();
        bytes memory stakingData = abi.encodeWithSelector(
            AOXCStaking.initialize.selector, admin, aiNode, token
        );
        staking = AOXCStaking(address(new ERC1967Proxy(address(stakingImpl), stakingData)));
    }

    /**
     * @notice Proves that unauthorized users cannot trigger the Emergency Bastion Unlock.
     */
    function testFuzz_RBAC_Sentinel_Emergency_Access(address attacker) public {
        vm.assume(attacker != admin);

        vm.startPrank(attacker);
        (bool success, ) = address(sentinel).call(
            abi.encodeWithSelector(sentinel.emergencyBastionUnlock.selector)
        );
        
        assertFalse(success, "RBAC-01: Unauthorized Emergency Unlock possible");
        vm.stopPrank();
    }

    /**
     * @notice Verifies that reputation gating cannot be tampered with.
     */
    function testFuzz_RBAC_Sentinel_Reputation_Defense(address attacker, address victim, uint256 score) public {
        vm.assume(attacker != admin);

        vm.startPrank(attacker);
        (bool success, ) = address(sentinel).call(
            abi.encodeWithSelector(sentinel.updateReputation.selector, victim, score)
        );
        
        assertFalse(success, "RBAC-02: Reputation adjustment leakage");
        vm.stopPrank();
    }

    /**
     * @notice UUPS Upgrade protection fuzzing.
     */
    function testFuzz_RBAC_Staking_Upgrade_Defense(address attacker, address newImpl) public {
        vm.assume(attacker != admin && newImpl != address(0));

        vm.startPrank(attacker);
        (bool success, ) = address(staking).call(
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImpl, "")
        );
        
        assertFalse(success, "RBAC-03: Unauthorized Upgrade detected");
        vm.stopPrank();
    }
}
