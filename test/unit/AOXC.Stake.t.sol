// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*//////////////////////////////////////////////////////////////
                        AOXC CORE IMPORTS
//////////////////////////////////////////////////////////////*/

import { AOXCStaking } from "../../src/AOXC.Stake.sol";
import { AOXCErrors } from "../../src/libraries/AOXCErrors.sol";
import { AOXCConstants } from "../../src/libraries/AOXCConstants.sol";

/**
 * @title MockAOXC
 * @dev High-fidelity token mock for staking stress testing.
 */
contract MockAOXC is ERC20 {
    constructor() ERC20("AOXC Mock", "AOXC") {
        _mint(msg.sender, 1_000_000_000 * 1e18);
    }
}

/**
 * @title AOXCStakingTest
 * @author AOXCAN AI Architect
 * @notice Final production-grade test suite for the Sovereign Staking layer.
 * @dev [V2.0.1-FIX]: Resolved erc20-unchecked-transfer warnings and optimized setup.
 */
contract AOXCStakingTest is Test {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCStaking public staking;
    MockAOXC public token;

    address public admin = address(0xAD31);
    address public aiSentinel;
    address public user = address(0xCAFE);
    uint256 public constant AI_PK = 0xA1B2C3D4;

    function setUp() public {
        aiSentinel = vm.addr(AI_PK);
        token = new MockAOXC();
        
        AOXCStaking implementation = new AOXCStaking();
        bytes memory initData = abi.encodeWithSelector(
            AOXCStaking.initialize.selector, admin, aiSentinel, address(token)
        );
        staking = AOXCStaking(address(new ERC1967Proxy(address(implementation), initData)));

        // [V2-FIX]: Unchecked transfer warning resolved
        bool success = token.transfer(user, 100_000 * 1e18);
        assertTrue(success, "Setup: Initial funding failed");
        
        vm.startPrank(user);
        token.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @dev Internal helper to match ASM hashing layout.
     */
    function _getNeuralStakeSig(address actor, uint256 amt, uint256 dur, uint256 nonce) 
        internal view returns (bytes memory) 
    {
        bytes32 innerHash = keccak256(abi.encode(
            actor, amt, dur, nonce, address(staking), block.chainid
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PK, innerHash.toEthSignedMessageHash());
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY VECTORS
    //////////////////////////////////////////////////////////////*/

    function test_Sovereign_Stake_Flow() public {
        uint256 amount = 1000 * 1e18;
        uint256 duration = 30 days; 
        bytes memory sig = _getNeuralStakeSig(user, amount, duration, 0);

        vm.prank(user);
        staking.stakeSovereign(amount, duration, sig);

        assertEq(token.balanceOf(address(staking)), amount, "L1: Vault deposit mismatch");
    }

    /**
     * @notice Tests Replay Protection: Ensures a signature cannot be reused.
     */
    function test_RevertIf_StakingSignatureReused() public {
        uint256 amount = 500 * 1e18;
        uint256 duration = 30 days;
        bytes memory sig = _getNeuralStakeSig(user, amount, duration, 0);

        vm.startPrank(user);
        staking.stakeSovereign(amount, duration, sig);

        // Advance state to bypass block-level protection
        vm.roll(block.number + 1);

        // Expect revert: Nonce or signature already processed
        vm.expectRevert(); 
        staking.stakeSovereign(amount, duration, sig);
        vm.stopPrank();
    }

    /**
     * @notice Validates that early withdrawals are strictly forbidden.
     */
    function test_RevertIf_WithdrawBeforeTimelock() public {
        uint256 amount = 1000 * 1e18;
        uint256 duration = AOXCConstants.MIN_TIMELOCK_DELAY + 1 days;
        bytes memory sig = _getNeuralStakeSig(user, amount, duration, 0);

        vm.prank(user);
        staking.stakeSovereign(amount, duration, sig);

        // Attempt withdrawal just before lock expiry
        vm.warp(block.timestamp + duration - 1 hours);
        vm.prank(user);
        vm.expectRevert(); 
        staking.withdrawSovereign(0);

        // Successful withdrawal after expiry
        vm.warp(block.timestamp + 2 hours);
        vm.prank(user);
        staking.withdrawSovereign(0);
        
        assertEq(token.balanceOf(address(staking)), 0, "L5: Vault liquidation error");
    }

    /**
     * @notice Ensures minimum lock-up periods are enforced.
     */
    function test_RevertIf_InvalidDuration() public {
        uint256 amount = 100 * 1e18;
        uint256 duration = AOXCConstants.MIN_TIMELOCK_DELAY - 1;
        bytes memory sig = _getNeuralStakeSig(user, amount, duration, 0);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(AOXCErrors.AOXC_InvalidLockTier.selector, duration));
        staking.stakeSovereign(amount, duration, sig);
    }
}
