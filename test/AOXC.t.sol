// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 10000 * 1e18);
    }
}

contract AOXCTest is Test {
    AOXC public implementation;
    AOXC public proxy;

    address public admin = makeAddr("Governance_Admin");
    address public user1 = makeAddr("Audit_Entity_1");
    address public user2 = makeAddr("Audit_Entity_2");
    address public complianceOfficer = makeAddr("Compliance_Officer");
    address public treasury = makeAddr("Treasury_Vault");

    uint256 public constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;

    function setUp() public virtual {
        vm.warp(1700000000);
        vm.roll(100);

        // 1. Implementation deploy
        implementation = new AOXC();

        // 2. Proxy deploy with initialize call
        bytes memory initData = abi.encodeWithSelector(AOXC.initialize.selector, admin);
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);

        // 3. Wrap proxy with AOXC ABI
        proxy = AOXC(address(proxyContract));

        // 4. Role Assignments
        vm.startPrank(admin);
        proxy.grantRole(proxy.COMPLIANCE_ROLE(), complianceOfficer);
        vm.stopPrank();
    }

    function test_01_InitialStateVerification() public view virtual {
        assertEq(proxy.totalSupply(), INITIAL_SUPPLY);
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(proxy.decimals(), 18);
    }

    function test_02_BlacklistLogic() public virtual {
        vm.prank(admin);
        proxy.mint(user1, 1000e18);

        vm.prank(complianceOfficer);
        proxy.addToBlacklist(user1, "AML Compliance Flag");

        // Blacklisted account cannot receive tokens
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(AOXC.AOXC_AccountBlacklisted.selector, user1));
        proxy.transfer(user1, 100e18);

        // Blacklisted account cannot send tokens
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(AOXC.AOXC_AccountBlacklisted.selector, user1));
        proxy.transfer(user2, 50e18);

        // Removal from blacklist
        vm.prank(complianceOfficer);
        proxy.removeFromBlacklist(user1);

        vm.prank(user1);
        bool success = proxy.transfer(user2, 50e18);
        assertTrue(success, "Transfer after whitelist failed");
    }

    function test_03_VelocityLimits() public virtual {
        // Kontratındaki değişken ismine göre güncellendi
        uint256 maxTx = proxy.maxTransferAmount();

        vm.prank(admin);
        proxy.mint(user1, maxTx * 10);

        // Admin is exempt from limits
        vm.prank(admin);
        assertTrue(proxy.transfer(user2, maxTx + 1e18), "Admin limit bypass failed");

        // User is bound by Max Tx limit
        vm.prank(user1);
        vm.expectRevert(AOXC.AOXC_MaxTxExceeded.selector);
        proxy.transfer(user2, maxTx + 1);

        // Velocity (Daily Limit) Test
        vm.prank(admin);
        // Not: Kontratında fonksiyon ismi 'setTransferVelocity' olarak güncellenmiş olmalı
        proxy.setTransferVelocity(1000e18, 2000e18);

        vm.startPrank(user1);
        proxy.transfer(user2, 1000e18);
        proxy.transfer(user2, 1000e18);

        vm.expectRevert(AOXC.AOXC_DailyLimitExceeded.selector);
        proxy.transfer(user2, 1);
        vm.stopPrank();
    }

    function test_04_TaxRedirectionAudit() public virtual {
        vm.startPrank(admin);
        // V2 logic initialization for taxing (if applicable)
        proxy.setTreasury(treasury);
        proxy.setExclusionFromLimits(user1, false); // Tax uygulanması için limitlerden çıkarılmamalı
        proxy.mint(user1, 1000e18);
        vm.stopPrank();

        // 10% tax varsayımı ile test (AOXC.sol içindeki orana göre güncellenmeli)
        vm.prank(user1);
        bool taxTx = proxy.transfer(user2, 1000e18);
        assertTrue(taxTx, "Taxable transfer failed");

        // Treasury check (Örnek: %10 tax)
        assertEq(proxy.balanceOf(treasury), 100e18);
        assertEq(proxy.balanceOf(user2), 900e18);
    }

    function test_05_RescueMechanics() public virtual {
        MockToken dummyToken = new MockToken();
        uint256 rescueAmount = 500e18;

        // Simulate stuck tokens
        dummyToken.transfer(address(proxy), rescueAmount);

        uint256 adminInitialBalance = dummyToken.balanceOf(admin);

        vm.prank(admin);
        proxy.rescueErc20(address(dummyToken), rescueAmount);

        assertEq(dummyToken.balanceOf(admin), adminInitialBalance + rescueAmount);
    }
}
