// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXC (Sovereign Interface)
 * @notice Unified interface for the AOXC Token, combining ERC20, Votes, Permit, and Governance.
 * @dev Optimized for OpenZeppelin v5.x compatibility.
 */
interface IAOXC {
    /*//////////////////////////////////////////////////////////////
                                ERC20 STANDARD
    //////////////////////////////////////////////////////////////*/
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /*//////////////////////////////////////////////////////////////
                                ERC20 PERMIT (EIP-2612)
    //////////////////////////////////////////////////////////////*/
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                                ERC20 VOTES & TIMEPTS
    //////////////////////////////////////////////////////////////*/
    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    /*//////////////////////////////////////////////////////////////
                                SUPPLY CONTROL
    //////////////////////////////////////////////////////////////*/
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                                COMPLIANCE
    //////////////////////////////////////////////////////////////*/
    function isBlacklisted(address account) external view returns (bool);
    function isExcludedFromLimits(address account) external view returns (bool);
    function setExclusionFromLimits(address account, bool status) external;
    function setBlacklistStatus(address account, bool status) external;
}
