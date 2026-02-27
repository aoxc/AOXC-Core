// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXCTreasury} from "../../src/AOXCTreasury.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXCConstants} from "../../src/libraries/AOXCConstants.sol";
import {AOXCErrors} from "../../src/libraries/AOXCErrors.sol";

contract FinalAuditSniper is Test {
    AOXCTreasury public treasury;
    MockERC20 public aoxc;

    address public admin = makeAddr("admin");
    address public upgrader = makeAddr("upgrader");
    address public stranger = makeAddr("stranger");

    uint256 public constant AI_NODE_KEY = 0x1337;
    uint256 public constant BAD_NODE_KEY = 0xdead;
    address public aiNode;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        aiNode = vm.addr(AI_NODE_KEY);

        aoxc = new MockERC20("AOXC Token", "AOXC");

        address impl = address(new AOXCTreasury());

        treasury = AOXCTreasury(
            payable(address(
                    new ERC1967Proxy(
                        impl,
                        abi.encodeWithSignature(
                            "initialize(address,address,address,address)", admin, upgrader, aiNode, address(aoxc)
                        )
                    )
                ))
        );

        // Role doğrulama
        assertTrue(treasury.hasRole(AOXCConstants.GOVERNANCE_ROLE, upgrader));

        assertTrue(treasury.hasRole(0x00, admin));
    }

    /*//////////////////////////////////////////////////////////////
                        FULL COVERAGE TEST
    //////////////////////////////////////////////////////////////*/

    function test_Full_Treasury_Complete_Coverage() public {
        /* ---------------- CLIFF ---------------- */

        vm.expectRevert();
        vm.prank(upgrader);
        treasury.openNextWindow(); // cliff active

        vm.warp(block.timestamp + 6 * 365 days + 1);

        /* ---------------- FUNDING ---------------- */

        aoxc.mint(address(treasury), 1_000_000 ether);

        vm.deal(admin, 2 ether);

        vm.prank(admin);
        treasury.deposit{value: 1 ether}();

        vm.prank(admin);
        (bool ok,) = address(treasury).call{value: 0.5 ether}("");
        assertTrue(ok);

        treasury.getSovereignTvl();
        treasury.initialUnlockTimestamp();

        /* ---------------- OPEN WINDOW ---------------- */

        vm.startPrank(upgrader);
        treasury.openNextWindow();
        vm.stopPrank();

        /* ---------------- GOVERNANCE RESTRICT ---------------- */

        vm.expectRevert();
        vm.prank(stranger);
        treasury.openNextWindow();

        /* ---------------- ERC20 WITHDRAW ---------------- */

        uint256 amount = 15_000 ether;

        bytes32 rawHash = keccak256(abi.encode(address(aoxc), amount, 0, address(treasury), block.chainid));

        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_NODE_KEY, ethHash);

        bytes memory validSig = abi.encodePacked(r, s, v);

        vm.startPrank(admin);
        treasury.withdrawErc20(address(aoxc), admin, amount, validSig);
        vm.stopPrank();

        /* ---------------- FORGERY ---------------- */

        (uint8 bv, bytes32 br, bytes32 bs) = vm.sign(BAD_NODE_KEY, ethHash);

        bytes memory badSig = abi.encodePacked(br, bs, bv);

        vm.startPrank(admin);
        vm.expectRevert(AOXCErrors.AOXC_Neural_IdentityForgery.selector);

        treasury.withdrawErc20(address(aoxc), admin, amount, badSig);
        vm.stopPrank();

        /* ---------------- LIMIT EXCEEDED ---------------- */

        vm.startPrank(admin);
        vm.expectRevert();
        treasury.withdrawErc20(address(aoxc), admin, 1_000_000 ether, validSig);
        vm.stopPrank();

        /* ---------------- ETH WITHDRAW ---------------- */

        uint256 ethAmount = 0.01 ether;

        bytes32 ethRaw = keccak256(abi.encode(address(0), ethAmount, 1, address(treasury), block.chainid));

        bytes32 ethMsg = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", ethRaw));

        (uint8 ev, bytes32 er, bytes32 es) = vm.sign(AI_NODE_KEY, ethMsg);

        bytes memory ethSig = abi.encodePacked(er, es, ev);

        vm.startPrank(admin);
        treasury.withdrawEth(payable(admin), ethAmount, ethSig);
        vm.stopPrank();

        /* ---------------- EMERGENCY MODE ---------------- */

        vm.startPrank(admin);
        treasury.toggleEmergencyMode(true);

        vm.expectRevert();
        treasury.withdrawErc20(address(aoxc), admin, 1 ether, validSig);

        treasury.toggleEmergencyMode(false);
        vm.stopPrank();

        /* ---------------- WINDOW EXPIRED ---------------- */

        vm.warp(block.timestamp + 366 days);

        vm.startPrank(admin);
        vm.expectRevert();
        treasury.withdrawErc20(address(aoxc), admin, 1 ether, validSig);
        vm.stopPrank();

        /* ---------------- UPGRADE ---------------- */

        vm.startPrank(upgrader);

        address newImpl = address(new AOXCTreasury());
        treasury.upgradeToAndCall(newImpl, "");

        vm.stopPrank();
    }
}
