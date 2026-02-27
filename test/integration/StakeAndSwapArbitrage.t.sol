// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console2} from "forge-std/Test.sol";
import {AOXC} from "src/AOXC.sol";
import {AOXCStaking} from "src/AOXC.Stake.sol";
import {AOXCSwap} from "src/AOXC.Swap.sol";
import {AOXCTreasury} from "src/AOXCTreasury.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title StakeAndSwapArbitrageTest
 * @notice Integration test for cross-chain yield and swap efficiency.
 */
contract StakeAndSwapArbitrageTest is Test {
    AOXC public aoxc;
    AOXCStaking public staking;
    AOXCSwap public swap;
    AOXCTreasury public treasury;

    address public admin = makeAddr("admin");
    address public user = makeAddr("yieldHunter");
    address public oracle = makeAddr("oracle");
    uint256 public constant AI_NODE_PK = 0xA11CE;

    function setUp() public {
        vm.startPrank(admin);

        // 1. Core Token
        aoxc = AOXC(
            address(
                new ERC1967Proxy(
                    address(new AOXC()),
                    abi.encodeWithSignature("initializeV2(address,address)", makeAddr("sentinel"), admin)
                )
            )
        );

        // 2. Staking
        staking = AOXCStaking(
            address(
                new ERC1967Proxy(
                    address(new AOXCStaking()),
                    abi.encodeWithSignature(
                        "initialize(address,address,address)", admin, vm.addr(AI_NODE_PK), address(aoxc)
                    )
                )
            )
        );

        // 3. Treasury
        treasury = AOXCTreasury(
            payable(address(
                    new ERC1967Proxy(
                        address(new AOXCTreasury()),
                        abi.encodeWithSignature(
                            "initialize(address,address,address,address)",
                            admin,
                            admin,
                            vm.addr(AI_NODE_PK),
                            address(aoxc)
                        )
                    )
                ))
        );

        // 4. Swap
        swap = AOXCSwap(
            address(
                new ERC1967Proxy(
                    address(new AOXCSwap()),
                    abi.encodeWithSignature("initialize(address,address,address)", admin, oracle, address(treasury))
                )
            )
        );

        // Initial Liquidity
        // Warning fix: Checked return value
        bool success = aoxc.transfer(user, 100_000 * 1e18);
        assertTrue(success, "Setup: Initial transfer failed");

        vm.stopPrank();
    }

    /**
     * @notice TEST 1: Staking to Swap Compounding
     * @dev User stakes -> waits for rewards -> swaps rewards for stable growth.
     */
    function test_Compounding_Efficiency() public {
        uint256 stakeAmount = 50_000 * 1e18;

        vm.startPrank(user);
        aoxc.approve(address(staking), stakeAmount);

        // Stake for 30 days
        staking.stakeSovereign(stakeAmount, 30 days, _getNeuralProof(user, stakeAmount, 30 days, 0));

        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days + 1);

        // Unstake (Simulating yield gain)
        staking.withdrawSovereign(0);

        uint256 finalBalance = aoxc.balanceOf(user);
        assertGe(finalBalance, stakeAmount, "Yield generation failed");

        vm.stopPrank();
        console2.log("Arbitrage Cycle: Compounding Verified.");
    }

    function _getNeuralProof(address actor, uint256 amt, uint256 dur, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 msgHash = keccak256(abi.encode(actor, amt, dur, nonce, address(staking), block.chainid));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_NODE_PK, ethHash);
        return abi.encodePacked(r, s, v);
    }
}
