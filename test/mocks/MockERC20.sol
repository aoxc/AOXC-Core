// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Standard ERC20 for simulation of external assets (USDC, USDT, etc.)
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    /**
     * @dev External mint function to prime test scenarios with liquidity.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
