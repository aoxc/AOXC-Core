// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console2} from "forge-std/Test.sol"; // console2 eklendi
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXCTimelock} from "../../src/AOXC.Timelock.sol";

contract AOXCTimelockTest is Test {
    AOXCTimelock public timelock;

    address public admin = makeAddr("admin");
    address public proposer = makeAddr("proposer");
    address public executor = makeAddr("executor");
    address public target = makeAddr("target");

    uint256 public constant MIN_DELAY = 2 days;

    function setUp() public {
        AOXCTimelock implementation = new AOXCTimelock();

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory initData = abi.encodeWithSelector(
            AOXCTimelock.initializeApex.selector, MIN_DELAY, proposers, executors, admin, address(0xDEAD)
        );

        timelock = AOXCTimelock(payable(address(new ERC1967Proxy(address(implementation), initData))));
        vm.deal(address(timelock), 10 ether);
    }

    /**
     * @notice [V2.0.1-FIX]: Fixed the 'State 4' logic and logging.
     */
    function test_Sovereign_Delay_Enforcement() public {
        uint256 val = 1 ether;
        bytes32 salt = keccak256("FINAL_SALT");
        bytes memory data = "";
        bytes32 pred = bytes32(0);

        // 1. Planla
        vm.prank(proposer);
        timelock.schedule(target, val, data, pred, salt, MIN_DELAY);

        bytes32 opId = timelock.hashOperation(target, val, data, pred, salt);

        // [LOGGING]: Eğer bu iki sayı aynıysa minDelay çalışmıyor demektir.
        uint256 readyTime = timelock.getTimestamp(opId);
        console2.log("Operation Ready Time:", readyTime);
        console2.log("Current Block Time: ", block.timestamp);

        // 2. Erken deneme: (Sadece 1 saat ileri git, Ready olmamalı)
        vm.warp(block.timestamp + 1 hours);

        vm.prank(executor);
        // Burada revert bekliyoruz. Eğer 'State 4' hatası alıyorsan,
        // kontrat readyTime'ı yanlış hesaplıyor demektir.
        vm.expectRevert();
        timelock.execute(target, val, data, pred, salt);

        // 3. Zamanı asıl olması gereken yere (2 gün sonrasına) uçur
        vm.warp(readyTime + 1 seconds);

        vm.prank(executor);
        timelock.execute(target, val, data, pred, salt);

        assertEq(target.balance, val, "L5: Value transfer failed");
    }
}
