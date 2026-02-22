// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AOXCCoverageTest} from "./AOXC_Coverage.t.sol";
import {AOXC} from "../src/AOXC.sol";

/**
 * @title AOXC Coverage Surgery
 * @notice AOXC.sol içindeki %100 kapsama giden yoldaki son engelleri temizler.
 */
contract AOXCSurgeryTest is AOXCCoverageTest {
    
    // 1. Hedef: _authorizeUpgrade içindeki yetki kontrolü dalı
    function testSurgeryUpgradePermissionBranch() public {
        vm.startPrank(user1); // Yetkisiz bir adres (UPGRADER_ROLE yok)
        address newImpl = address(new AOXC());
        
        // Bu çağrı _authorizeUpgrade içindeki 'onlyRole' kontrolünü tetikler ve revert eder
        vm.expectRevert(); 
        proxy.upgradeToAndCall(newImpl, "");
        vm.stopPrank();
    }

    // 2. Hedef: _update içindeki limit muafiyet dalları
    function testSurgeryUpdateExclusionBranches() public {
        // Path A: Limitlere tabi normal transfer (User1 -> User2)
        vm.prank(admin);
        proxy.mint(user1, 1000e18);
        vm.prank(user1);
        proxy.transfer(user2, 100e18);

        // Path B: Limitlerden muaf adresin transferi (setExclusionFromLimits kullanımı)
        vm.startPrank(admin);
        proxy.setExclusionFromLimits(user2, true); // User2 muaf edildi
        vm.stopPrank();

        vm.prank(user2);
        proxy.transfer(user1, 100e18); // Bu transfer limit kontrol dallarını 'false' olarak geçer
    }

    // 3. Hedef: mint() içindeki 'periods == 0' ve 'periods > 0' dalları
    function testSurgeryMintTemporalBranches() public {
        vm.startPrank(admin);
        
        // Dal 1: Aynı yıl içinde ikinci mint (periods == 0 durumunu kapsar)
        proxy.mint(user1, 100e18);
        proxy.mint(user1, 100e18);

        // Dal 2: Tam olarak 1 yıl sonra mint (periods = 1 durumunu kapsar)
        vm.warp(block.timestamp + 365 days);
        proxy.mint(user1, 100e18);
        
        vm.stopPrank();
    }

    // 4. Hedef: _update içindeki günlük limit sıfırlama (day change) dalı
    function testSurgeryDailyLimitReset() public {
        vm.prank(admin);
        proxy.mint(user1, 1000e18);

        // İlk transfer (günlük harcama başlar)
        vm.prank(user1);
        proxy.transfer(user2, 100e18);

        // 1 gün sonraya atla (if (lastTransferDay[from] != day) dalını tetikler)
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.prank(user1);
        proxy.transfer(user2, 100e18);
    }
}
