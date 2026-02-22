// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken for Rescue Testing
 * @dev Basit bir ERC20 kontratı, initialize gerektirmez.
 */
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 10000 * 1e18);
    }
}

/**
 * @title AOXC Protocol - Audit-Grade Security Suite
 * @author AOXC Protocol Engineering
 * @notice Validates monetary policy, compliance, and core contract mechanics.
 * @dev Fully compliant with mixedCase naming and ERC20 return check standards.
 */
contract AOXCTest is Test {
    AOXC public implementation;
    AOXC public proxy;
    
    address public admin = address(0xAD);
    address public user1 = address(0x01);
    address public user2 = address(0x02);
    address public complianceOfficer = address(0x03);
    uint256 public constant INITIAL_SUPPLY = 100_000_000_000 * 1e18;

    function setUp() public virtual {
        implementation = new AOXC();
        bytes memory initData = abi.encodeWithSelector(AOXC.initialize.selector, admin);
        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = AOXC(address(proxyContract));

        vm.startPrank(admin);
        proxy.grantRole(proxy.COMPLIANCE_ROLE(), complianceOfficer);
        vm.stopPrank();

        vm.label(admin, "Governance_Admin");
        vm.label(complianceOfficer, "Compliance_Officer");
        vm.label(address(proxy), "AOXC_Proxy");
        vm.label(user1, "Audit_Entity_1");
        vm.label(user2, "Audit_Entity_2");
    }

    // --- 1. STATE INTEGRITY ---

    function test01InitialStateVerification() public view {
        assertEq(proxy.totalSupply(), INITIAL_SUPPLY, "Genesis supply mismatch");
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin), "Admin role error");
    }

    // --- 2. COMPLIANCE & LINT OPTIMIZATION ---

    function test02BlacklistLogic() public {
        vm.prank(complianceOfficer);
        proxy.addToBlacklist(user1, "AML Compliance");
        
        vm.prank(admin);
        vm.expectRevert("AOXC: BL Recipient");
        bool sRev1 = proxy.transfer(user1, 100e18); 
        assertTrue(!sRev1); 

        vm.prank(complianceOfficer);
        proxy.removeFromBlacklist(user1);
        vm.prank(admin);
        bool success = proxy.transfer(user1, 100e18); 
        assertTrue(success, "Post-blacklist transfer failed");
    }

    // --- 3. MONETARY VELOCITY ---

    function test03VelocityLimits() public {
        uint256 maxTx = proxy.maxTransferAmount();
        
        vm.prank(admin);
        bool sAdmin = proxy.transfer(user1, maxTx + 1e18);
        assertTrue(sAdmin, "Admin exclusion failed");

        vm.prank(user1);
        vm.expectRevert("AOXC: MaxTX");
        bool sRev2 = proxy.transfer(user2, maxTx + 1);
        assertTrue(!sRev2);

        vm.prank(admin);
        proxy.setTransferVelocity(1000e18, 2000e18);
        
        vm.startPrank(user1);
        bool s1 = proxy.transfer(user2, 1000e18);
        bool s2 = proxy.transfer(user2, 1000e18);
        assertTrue(s1 && s2, "Transfer within daily limit failed");
        
        vm.expectRevert("AOXC: DailyLimit");
        bool sRev3 = proxy.transfer(user2, 1);
        assertTrue(!sRev3);
        vm.stopPrank();
    }

    // --- 4. INFLATION & UPGRADES ---

    function test04InflationAndUpgrade() public {
        uint256 limit = proxy.yearlyMintLimit();
        
        vm.startPrank(admin);
        proxy.mint(user1, limit);
        vm.expectRevert("AOXC: Inflation");
        proxy.mint(user1, 1);
        
        vm.warp(block.timestamp + 366 days);
        proxy.mint(user1, 100e18); 
        vm.stopPrank();

        address next = address(new AOXC());
        vm.prank(admin);
        proxy.upgradeToAndCall(next, "");
        assertEq(_getImplementationAddress(address(proxy)), next, "UUPS upgrade failed");
    }

    // --- 5. GOVERNANCE & RESCUE (Hatasız Versiyon) ---

    function test05RescueMechanics() public {
        // AOXC yerine standart bir MockToken kullanıyoruz (Initialize gerektirmez)
        vm.startPrank(admin);
        MockToken dummyToken = new MockToken();
        
        // Yanlışlıkla Proxy'ye gönderim simülasyonu
        bool sTransfer = dummyToken.transfer(address(proxy), 1000e18);
        assertTrue(sTransfer);
        vm.stopPrank();

        uint256 balBefore = dummyToken.balanceOf(admin);
        
        // Kurtarma işlemi
        vm.prank(admin);
        proxy.rescueERC20(address(dummyToken), 1000e18);
        
        assertEq(dummyToken.balanceOf(admin), balBefore + 1000e18, "Funds rescue failed");
    }

    // --- HELPERS ---

    function _getImplementationAddress(address proxyAddr) internal view returns (address) {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxyAddr, slot))));
    }
}
