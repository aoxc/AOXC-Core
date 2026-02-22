// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AOXCTest} from "./AOXC.t.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC 100% Coverage Booster
 * @notice Targets only the uncovered branches (the "red lines") in AOXC.sol
 */
contract AOXCFinal100Booster is AOXCTest {
    
    /*//////////////////////////////////////////////////////////////
                        1. LOCK & COMPLIANCE BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_Branch_LockFunds_Enforcement() public {
        deal(address(proxy), user1, 1000e18);
        
        // 1 günlüğüne kilitle
        vm.prank(complianceOfficer);
        proxy.lockUserFunds(user1, 1 days);
        
        // Kilit altındayken transfer dene -> REVERT
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(AOXC.AOXC_AccountLocked.selector, user1, block.timestamp + 1 days));
        proxy.transfer(user2, 100e18);

        // Zamanı ileri al (Kilit açıldı)
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.prank(user1);
        bool ok = proxy.transfer(user2, 100e18);
        assertTrue(ok, "Transfer failed after lock expiry");
    }

    /*//////////////////////////////////////////////////////////////
                        2. MONETARY & TIME BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_Branch_YearlyLimit_Reset_Logic() public {
        uint256 limit = proxy.yearlyMintLimit();
        
        vm.startPrank(admin);
        // Bu yılın limitini bitir
        proxy.mint(user1, limit);
        
        // Aynı yıl içinde tekrar dene -> REVERT
        vm.expectRevert(AOXC.AOXC_InflationLimitReached.selector);
        proxy.mint(user1, 1e18);

        // Zamanı 1 yıldan fazla ileri sar (Limit sıfırlanmalı)
        vm.warp(block.timestamp + 366 days);
        
        // Yeni yıl, yeni limit -> SUCCESS
        proxy.mint(user1, 1e18);
        assertEq(proxy.mintedThisYear(), 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        3. EMERGENCY & RESCUE BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_Branch_RescueEth_FullFlow() public {
        // Kontrata ETH gönder (Normalde receive/fallback yok ama deal ile zorlanabilir)
        uint256 ethAmount = 2 ether;
        vm.deal(address(proxy), ethAmount);
        
        uint256 adminPre = admin.balance;
        
        vm.prank(admin);
        proxy.rescueEth();
        
        assertEq(admin.balance, adminPre + ethAmount, "ETH rescue failed");
    }

    function test_Branch_Pause_Unpause_Mint_Guard() public {
        vm.startPrank(admin);
        
        proxy.pause();
        // Pause halindeyken mint dene -> REVERT (PausableUpgradeable dalı)
        vm.expectRevert(); 
        proxy.mint(user1, 100e18);
        
        proxy.unpause();
        // Unpause sonrası -> SUCCESS
        proxy.mint(user1, 100e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        4. EDGE CASE BRANCHES (VERİMLİLİK)
    //////////////////////////////////////////////////////////////*/

    function test_Branch_SelfTransfer_Tax_Check() public {
        // initializeV2 ile vergiyi aç (Eğer açılmadıysa)
        vm.prank(admin);
        try proxy.initializeV2(500) {} catch {} // %5 vergi

        uint256 amount = 1000e18;
        deal(address(proxy), user1, amount);
        
        // Kullanıcının kendine transferi (Self transfer vergi ve limit dallarını tetikler)
        vm.prank(user1);
        bool ok = proxy.transfer(user1, amount / 2);
        assertTrue(ok);
    }

    function test_Branch_Remove_From_Blacklist() public {
        vm.startPrank(complianceOfficer);
        proxy.addToBlacklist(user1, "Temporary");
        assertTrue(proxy.isBlacklisted(user1));
        
        proxy.removeFromBlacklist(user1);
        assertFalse(proxy.isBlacklisted(user1));
        vm.stopPrank();
    }

    function test_Branch_TransferTreasuryFunds_Direct() public {
        uint256 amount = 500e18;
        // Kontratın (treasury) kendi bakiyesi olmalı
        deal(address(proxy), address(proxy), amount);
        
        vm.prank(admin);
        proxy.transferTreasuryFunds(user2, amount);
        assertEq(proxy.balanceOf(user2), amount);
    }
}
