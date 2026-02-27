// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAOXC} from "../../../src/interfaces/IAOXC.sol";
import {AOXCStaking} from "../../../src/AOXC.Stake.sol";
import {AOXCConstants} from "../../../src/libraries/AOXCConstants.sol";

/**
 * @title StakeHandler
 * @author AOXC Core Architecture Team
 * @notice Production-ready handler with Temporal Advance and Neural Proof generation.
 * @dev Fixed: AOXC_TemporalCollision by rolling blocks forward per fuzz call.
 */
contract StakeHandler is CommonBase, StdCheats, StdUtils {
    using MessageHashUtils for bytes32;

    // --- Immutable Infrastructure ---
    IAOXC public immutable AOXC_TOKEN;
    AOXCStaking public immutable STAKING;
    uint256 internal immutable AI_NODE_KEY;

    // --- Ghost Accounting (Telemetry) ---
    uint256 public ghostTotalStaked;
    uint256 public ghostNeuralNonce;

    constructor(IAOXC _aoxc, AOXCStaking _staking, uint256 _aiNodeKey) {
        AOXC_TOKEN = _aoxc;
        STAKING = _staking;
        AI_NODE_KEY = _aiNodeKey;
    }

    /**
     * @notice Simulates an algorithmic sovereign staking operation.
     * @param amount Fuzzed amount of AOXC tokens.
     * @param tierIndex Fuzzed index for temporal lock durations.
     */
    function stakeSovereign(uint256 amount, uint256 tierIndex) public {
        // --- Layer 26: Temporal Advance (CRITICAL FIX) ---
        // Forces the blockchain forward to bypass 'AOXC_TemporalCollision'
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 15);

        uint256 balance = AOXC_TOKEN.balanceOf(address(this));
        if (balance == 0) return;

        // Layer 1: Monetary Bounding
        amount = bound(amount, 1, balance);

        // Layer 2: Temporal Boundary Synchronization
        // Strictly aligned with AOXCConstants: 2 days (MIN) to 30 days (MAX)
        uint256[4] memory validTiers = [
            AOXCConstants.MIN_TIMELOCK_DELAY, // 2 days
            7 days,
            15 days,
            AOXCConstants.MAX_TIMELOCK_DELAY // 30 days
        ];
        uint256 duration = validTiers[tierIndex % 4];

        // Layer 3: Neural Proof Synthesis (EIP-191)
        bytes32 msgHash = keccak256(
                abi.encode(address(this), amount, duration, ghostNeuralNonce, address(STAKING), block.chainid)
            ).toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_NODE_KEY, msgHash);
        bytes memory neuralProof = abi.encodePacked(r, s, v);

        // Layer 4: Execution Flow with Prank Isolation
        vm.startPrank(address(this));
        AOXC_TOKEN.approve(address(STAKING), amount);
        STAKING.stakeSovereign(amount, duration, neuralProof);
        vm.stopPrank();

        // --- Post-Action Telemetry ---
        ghostTotalStaked += amount;
        ghostNeuralNonce++;
    }

    /**
     * @dev Simple sink for initial liquidity seeding from the Pusula suite.
     */
    function receiveSeed(uint256 amount) external {}
}
