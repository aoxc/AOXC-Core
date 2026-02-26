// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AOXCTreasury } from "../../src/AOXCTreasury.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title AOXCTreasuryTest V2.0.1
 * @notice Fixed MagnitudeLimitExceeded and AI Signature forgery.
 */
contract AOXCTreasuryTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    AOXCTreasury public implementation;
    AOXCTreasury public treasury;
    MockERC20 public mockToken;

    address public governor = address(0x111);
    address public upgrader = address(0x222);
    address public aiNode;
    address public recipient = address(0xABC);
    uint256 private constant AI_PK = 0xA1B2C3;

    function setUp() public {
        aiNode = vm.addr(AI_PK);

        // 1. Deployment
        implementation = new AOXCTreasury();
        
        // 2. Mock Token Deployment (Registry adresi olarak bunu kullanacağız)
        mockToken = new MockERC20("AOXC Token", "AOXC");

        // 3. Proxy & Initialization
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        treasury = AOXCTreasury(payable(address(proxy)));

        // [V2-FIX]: mockToken'ı 4. parametre (aoxcTokenAddr) olarak veriyoruz
        treasury.initialize(
            governor, 
            upgrader, 
            aiNode, 
            address(mockToken) 
        );

        // 4. [LIMIT-FIX]: Snapshot alınmadan önce kasaya likidite koyulmalı
        deal(address(mockToken), address(treasury), 100_000 ether);

        // 5. Cliff & Window Initialization
        vm.warp(block.timestamp + 6 * 365 days + 1 hours);
        vm.prank(governor);
        treasury.openNextWindow(); 
        // Bu noktada snapshot: 100k, Yıllık Limit: 6k (600 BPS)
    }

    function _sign(address token, uint256 amount, uint256 nonce) internal view returns (bytes memory) {
        // [V2-FIX]: Signature format must match AOXCTreasury._verifyAiSignature
        bytes32 h = keccak256(
            abi.encode(token, amount, nonce, address(treasury), block.chainid)
        ).toEthSignedMessageHash();
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AI_PK, h);
        return abi.encodePacked(r, s, v);
    }

    function test_FullWithdrawalFlow() public {
        // Limit: 6000. Çekilen: 1000. (Limit altı, PASS)
        uint256 amount = 1000 ether; 
        uint256 nonce = 0; 

        bytes memory sig = _sign(address(mockToken), amount, nonce);

        uint256 balanceBefore = mockToken.balanceOf(recipient);
        
        vm.prank(governor);
        treasury.withdrawErc20(address(mockToken), recipient, amount, sig);

        assertEq(mockToken.balanceOf(recipient), balanceBefore + amount, "Recipient balance mismatch");
    }

    function test_RevertIf_ExceedsMagnitudeLimit() public {
        // Limit 6000 iken 7000 çekmeye çalışmak
        uint256 amount = 7000 ether;
        bytes memory sig = _sign(address(mockToken), amount, 0);

        vm.prank(governor);
        vm.expectRevert(); // AOXC_MagnitudeLimitExceeded dönecek
        treasury.withdrawErc20(address(mockToken), recipient, amount, sig);
    }

    function test_RevertIf_EmergencyLocked() public {
        vm.prank(governor);
        treasury.toggleEmergencyMode(true);

        vm.prank(governor);
        vm.expectRevert(); // Treasury: EMERGENCY_LOCK
        treasury.withdrawErc20(address(mockToken), recipient, 100, "");
    }

    receive() external payable {}
}
