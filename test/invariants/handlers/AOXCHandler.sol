// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../../../src/AOXC.sol";
import {AOXCStaking} from "../../../src/AOXC.Stake.sol";
import {AOXCSwap} from "../../../src/AOXC.Swap.sol";
import {AOXCTreasury} from "../../../src/AOXCTreasury.sol";
import {AOXCConstants} from "../../../src/libraries/AOXCConstants.sol";

/**
 * @title AOXCHandler
 * @notice Logic wrapper to facilitate stateful fuzzing within protocol constraints.
 * @dev Aligned with V2.8 Bastion (6% Cap & 6-Year Cliff logic).
 */
contract AOXCHandler is Test {
    AOXC public aoxc;
    AOXCStaking public staking;
    AOXCSwap public swap;
    AOXCTreasury public treasury;

    // --- State Management ---
    uint256 public totalMinted;
    uint256 public totalWithdrawn;

    constructor(
        address _aoxc,
        address _staking,
        address _swap,
        address payable _treasury // [FIX]: Explicitly payable for V2.8
    ) {
        aoxc = AOXC(_aoxc);
        staking = AOXCStaking(_staking);
        swap = AOXCSwap(_swap);
        treasury = AOXCTreasury(_treasury);
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exercises the inflation hardcap by simulating periodic mints.
     */
    function mint(uint256 amount) public {
        uint256 txLimit = (AOXCConstants.INITIAL_SUPPLY * 200) / 10000; // 2% per tx
        amount = bound(amount, 0, txLimit);

        vm.prank(address(this));
        try aoxc.mint(address(this), amount) {
            totalMinted += amount;
        } catch {}
    }

    /**
     * @notice Exercises the transfer logic and magnitude guards.
     */
    function transfer(address to, uint256 amount) public {
        if (to == address(0) || to == address(this)) to = address(0xDEAD);

        uint256 balance = aoxc.balanceOf(address(this));
        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(address(this));
        try aoxc.transfer(to, amount) {} catch {}
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY FUZZING (V2.8)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stress-tests the 6% annual withdrawal limit of the Treasury.
     * @dev Attempts to breach the Sovereign Cap via rapid withdrawals.
     */
    function treasuryWithdrawErc20(uint256 amount) public {
        uint256 remainingLimit = treasury.getRemainingLimit(address(aoxc));
        if (remainingLimit == 0) return;

        // Bound to remaining limit to focus on success cases, or exceed it to test reverts
        amount = bound(amount, 0, remainingLimit + 1e18);

        vm.prank(address(this));
        // Note: In real scenarios, aiSignature is required for > 1%
        // We use empty bytes to test internal revert or success logic
        try treasury.withdrawErc20(address(aoxc), address(this), amount, hex"00") {
            totalWithdrawn += amount;
        } catch {}
    }

    /*//////////////////////////////////////////////////////////////
                        STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Simulates sovereign staking with valid durations.
     */
    function stakeSovereign(uint256 amount, uint256 duration) public {
        uint256 balance = aoxc.balanceOf(address(this));
        if (balance < 1e18) return;

        amount = bound(amount, 1e18, balance);
        duration = bound(duration, AOXCConstants.MIN_TIMELOCK_DELAY, AOXCConstants.MAX_TIMELOCK_DELAY);

        vm.startPrank(address(this));
        aoxc.approve(address(staking), amount);
        try staking.stakeSovereign(amount, duration, hex"00") {} catch {}
        vm.stopPrank();
    }

    /**
     * @notice Facilitates native ETH deposits into the Treasury.
     */
    function depositEth(uint256 amount) public {
        amount = bound(amount, 0, address(this).balance);
        if (amount == 0) return;

        (bool success,) = address(treasury).call{value: amount}(abi.encodeWithSignature("deposit()"));
        require(success, "Deposit failed");
    }
}
