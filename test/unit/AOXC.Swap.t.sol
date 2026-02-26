// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol"; 
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AOXCSwap } from "../../src/AOXC.Swap.sol";
import { AOXCTreasury } from "../../src/AOXCTreasury.sol";
import { AOXC } from "../../src/AOXC.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { AOXCErrors } from "../../src/libraries/AOXCErrors.sol";

contract AOXCSwapMasterclass is Test {
    AOXCSwap public swap;
    AOXCTreasury public treasury;
    AOXC public aoxc;
    MockERC20 public usdc;

    address public admin = makeAddr("admin");
    address public mockOracle = makeAddr("oracle");
    address public aiNode = makeAddr("aiNode");
    address public trader = makeAddr("trader");
    address public sentinel = makeAddr("sentinel");

    bytes32 internal constant SWAP_STORAGE_SLOT = 
        0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;

    function setUp() public {
        vm.startPrank(admin);

        // 1. Implementations
        AOXC aoxcImpl = new AOXC();
        AOXCTreasury treasuryImpl = new AOXCTreasury();
        AOXCSwap swapImpl = new AOXCSwap();

        // 2. Proxies & Inits
        aoxc = AOXC(address(new ERC1967Proxy(address(aoxcImpl), "")));
        aoxc.initializeV2(sentinel, admin);

        treasury = AOXCTreasury(payable(address(new ERC1967Proxy(address(treasuryImpl), ""))));
        treasury.initialize(admin, admin, aiNode, admin); 

        swap = AOXCSwap(address(new ERC1967Proxy(address(swapImpl), "")));
        swap.initialize(admin, mockOracle, address(treasury));

        // [V2-SENTINEL-FIX]: AOXC transferlerinin geçmesi için sentinel'i mock'la
        // isAllowed(address,address) çağrısına 'true' (bool) cevabı verilmeli
        vm.mockCall(
            sentinel,
            abi.encodeWithSignature("isAllowed(address,address)", trader, address(treasury)),
            abi.encode(true)
        );
        // Swap içindeki transfer trader -> treasury olduğu için üstteki mock yeterli.

        // 3. Infrastructure Mocks
        usdc = new MockERC20("USD Coin", "USDC");
        vm.mockCall(mockOracle, abi.encodeWithSignature("getLiveness()"), abi.encode(true));
        vm.mockCall(mockOracle, abi.encodeWithSignature("getConsensusPrice(address)"), abi.encode(1e18));
        vm.mockCall(mockOracle, abi.encodeWithSignature("getTwapPrice(address,uint256)"), abi.encode(1e18));

        // 4. Funding
        deal(address(usdc), address(treasury), 1_000_000 ether);
        deal(address(aoxc), trader, 100_000 ether);
        
        vm.stopPrank();
    }

    /**
     * @notice Test: Temporal Protection (Anti-Atomic)
     * Sentinel mocklandığı için artık transferler geçecek.
     */
    function test_Sovereign_Swap_Temporal_Protection() public {
        uint256 swapAmount = 1000 ether;

        vm.startPrank(trader);
        aoxc.approve(address(swap), swapAmount * 2);

        // İlk swap - Sentinel "Allowed" dediği için başarıyla gerçekleşir.
        swap.executeApexSwap(swapAmount, address(aoxc), address(usdc), 0);

        // Aynı blokta ikinci swap - TemporalCollision bekliyoruz (Layer 3 & 9)
        vm.expectRevert(AOXCErrors.AOXC_TemporalCollision.selector); 
        swap.executeApexSwap(swapAmount, address(aoxc), address(usdc), 0);
        vm.stopPrank();
    }

    function test_Sovereign_Swap_Neural_Defense() public {
        uint256 swapAmount = 10_000 ether;
        vm.warp(block.timestamp + 30 hours); 
        vm.startPrank(trader);
        aoxc.approve(address(swap), swapAmount);
        vm.expectRevert(); 
        swap.executeApexSwap(swapAmount, address(aoxc), address(usdc), 0);
        vm.stopPrank();
    }

    function test_Sovereign_Swap_Circuit_Breaker() public {
        uint256 swapAmount = 1000 ether;
        bytes32 circuitBreakerSlot = bytes32(uint256(SWAP_STORAGE_SLOT) + 2);
        vm.store(address(swap), circuitBreakerSlot, bytes32(uint256(1))); 
        vm.startPrank(trader);
        aoxc.approve(address(swap), swapAmount);
        vm.expectRevert(AOXCErrors.AOXC_GlobalLockActive.selector);
        swap.executeApexSwap(swapAmount, address(aoxc), address(usdc), 0);
        vm.stopPrank();
    }
}
