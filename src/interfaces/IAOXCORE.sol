// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/**
 * @title IAOXCORE (Primary Asset Protocol)
 * @author AOXCAN AI Architect
 * @notice Central interface defining core asset logic and AI security standards.
 * @dev Combines ERC20, EIP-2612 (Permit), ERC-5805 (Votes), and Neural-Link Defense.
 */
interface IAOXCORE {
    /*//////////////////////////////////////////////////////////////
                            EVENTS (TELEMETRY)
    //////////////////////////////////////////////////////////////*/
    event CoreLockStateChanged(bool indexed isLocked, uint256 timestamp);
    event NeuralSignalProcessed(uint256 riskScore, uint256 nonce);
    event AssetRecovered(address indexed from, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                         PAGE 1: ASSET & PERMIT
    //////////////////////////////////////////////////////////////*/

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                         PAGE 2: GOVERNANCE & VOTING
    //////////////////////////////////////////////////////////////*/

    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;
    // EIP-712 Governance support
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    /*//////////////////////////////////////////////////////////////
                         PAGE 3: DEFENSE & NEURAL LINK
    //////////////////////////////////////////////////////////////*/

    function unlockCore() external;
    function lockCore() external;
    function isCoreLocked() external view returns (bool);

    /**
     * @notice Processes cryptographically signed risk signals from AOXCAN AI node.
     */
    function processNeuralSignal(uint256 riskScore, uint256 nonce, bytes calldata signature) external;

    function getSecurityState() external view returns (bool isActive, uint256 cooldownRemaining);

    /**
     * @notice AI-Validated recovery for assets involved in verified anomalies.
     */
    function executeRecovery(address from, address to, uint256 amount, bytes calldata aiProof) external;

    function isAiActive() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                         PAGE 4: REPUTATION & ACCESS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    function isRestricted(address account) external view returns (bool);
    function setRestrictionStatus(address account, bool status) external;

    /**
     * @notice Returns the risk-weighted reputation score from the storage matrix.
     */
    function getReputationMatrix(address account) external view returns (uint256);
}
