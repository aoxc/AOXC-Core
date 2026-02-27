// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {AOXC} from "../../src/AOXC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AOXCFullSpectrumTest is Test {
    AOXC public aoxc;
    AOXC public implementation;

    address admin = address(0xAD);
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        implementation = new AOXC();

        // Proxy üzerinden V2 başlatma
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(AOXC.initializeV2.selector, address(0x99), admin)
        );
        aoxc = AOXC(address(proxy));
    }

    /*//////////////////////////////////////////////////////////////
                        1. ERC20 EXTENSIONS
    //////////////////////////////////////////////////////////////*/

    function test_Full_Burn_Mechanism() public {
        vm.prank(admin);
        // Warning fix: Checked return value
        assertTrue(aoxc.transfer(user1, 1000 ether), "Transfer to user1 failed");

        vm.prank(user1);
        aoxc.burn(400 ether);
        assertEq(aoxc.balanceOf(user1), 600 ether);

        vm.prank(user1);
        vm.expectRevert();
        aoxc.burn(1000 ether);
    }

    function test_Full_Votes_And_Delegation() public {
        vm.prank(admin);
        // Warning fix: Checked return value
        assertTrue(aoxc.transfer(user1, 500 ether), "Transfer to user1 failed");

        vm.prank(user1);
        aoxc.delegate(user1);
        assertEq(aoxc.getVotes(user1), 500 ether);

        vm.prank(user1);
        // Warning fix: Checked return value
        assertTrue(aoxc.transfer(user2, 200 ether), "Transfer to user2 failed");
        assertEq(aoxc.getVotes(user1), 300 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        2. ACCESS CONTROL & LIMITS
    //////////////////////////////////////////////////////////////*/

    function test_Unauthorized_Access_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        aoxc.mint(user1, 100);

        vm.prank(user1);
        vm.expectRevert();
        aoxc.pause();
    }

    /*//////////////////////////////////////////////////////////////
                        3. UPGRADEABILITY & UPDATE BYPASS
    //////////////////////////////////////////////////////////////*/

    function test_Upgrade_Validation() public {
        address newImp = address(new AOXC());
        vm.prank(user1);
        vm.expectRevert();
        aoxc.upgradeToAndCall(newImp, "");

        vm.prank(admin);
        aoxc.upgradeToAndCall(newImp, "");
    }

    /**
     * @dev _update içindeki Mint/Burn bypass mantığını cover eder.
     */
    function test_Update_Bypass_Logic() public {
        vm.prank(admin);
        aoxc.mint(user1, 100 ether); // from == address(0)

        vm.prank(user1);
        aoxc.burn(50 ether); // to == address(0)

        assertEq(aoxc.balanceOf(user1), 50 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        4. PERMIT (EIP-2612)
    //////////////////////////////////////////////////////////////*/

    function test_Permit_Coverage() public {
        uint256 privateKey = 0xABC123;
        address owner = vm.addr(privateKey);
        address spender = user2;
        uint256 value = 1000 ether;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                aoxc.nonces(owner),
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", aoxc.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);

        aoxc.permit(owner, spender, value, deadline, v, r, s);
        assertEq(aoxc.allowance(owner, spender), value);
    }
}
