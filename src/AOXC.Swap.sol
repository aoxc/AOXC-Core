// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AOXC Sovereign Liquidity & Bridge Vault
 * @notice Manages locked LP positions and backs cross-chain synthetic supply.
 * @dev Optimized with Transient Storage for professional asset management.
 */
contract AOXCLiquidityManager is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // --- ROLES ---
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // --- STATE ---
    address public aoxcToken;
    address public currentLpToken;
    bool public isLiquidityPermanentlyLocked;

    // --- ERRORS ---
    error AOXC_Bridge_LockedForever();
    error AOXC_Bridge_ZeroAddress();
    error AOXC_Bridge_InsufficientCollateral();

    // --- EVENTS ---
    event LiquidityLockedPermanently(address indexed lpToken, uint256 amount);
    event BridgeOut(uint16 indexed dstChainId, address indexed to, uint256 amount);
    event BridgeIn(uint16 indexed srcChainId, address indexed to, uint256 amount);
    event LPTokenUpdated(address indexed oldLp, address indexed newLp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _governor, address _aoxcToken, address _lpToken) public initializer {
        if (_governor == address(0) || _aoxcToken == address(0) || _lpToken == address(0)) {
            revert AOXC_Bridge_ZeroAddress();
        }

        __AccessControl_init();
        __ReentrancyGuardTransient_init();
        __UUPSUpgradeable_init();

        aoxcToken = _aoxcToken;
        currentLpToken = _lpToken;

        _grantRole(DEFAULT_ADMIN_ROLE, _governor);
        _grantRole(GOVERNANCE_ROLE, _governor);
        _grantRole(UPGRADER_ROLE, _governor);
        _grantRole(BRIDGE_ROLE, _governor);
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY ENGINE
    //////////////////////////////////////////////////////////////*/

    function updateLpToken(address _newLp) external onlyRole(GOVERNANCE_ROLE) {
        if (isLiquidityPermanentlyLocked) revert AOXC_Bridge_LockedForever();
        if (_newLp == address(0)) revert AOXC_Bridge_ZeroAddress();

        address oldLp = currentLpToken;
        currentLpToken = _newLp;
        emit LPTokenUpdated(oldLp, _newLp);
    }

    function setPermanentLock() external onlyRole(GOVERNANCE_ROLE) {
        isLiquidityPermanentlyLocked = true;
        emit LiquidityLockedPermanently(currentLpToken, IERC20(currentLpToken).balanceOf(address(this)));
    }

    function migrateLiquidity(address _to, uint256 _amount) external onlyRole(GOVERNANCE_ROLE) nonReentrant {
        if (isLiquidityPermanentlyLocked) revert AOXC_Bridge_LockedForever();
        IERC20(currentLpToken).safeTransfer(_to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            BRIDGE VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks tokens in this vault to enable minting on another chain.
     */
    function bridgeOut(uint16 _dstChainId, address _from, uint256 _amount) external onlyRole(BRIDGE_ROLE) nonReentrant {
        if (_from == address(0)) revert AOXC_Bridge_ZeroAddress();
        IERC20(aoxcToken).safeTransferFrom(_from, address(this), _amount);
        emit BridgeOut(_dstChainId, _from, _amount);
    }

    /**
     * @notice Releases tokens from this vault when tokens are burned on another chain.
     */
    function bridgeIn(uint16 _srcChainId, address _to, uint256 _amount) external onlyRole(BRIDGE_ROLE) nonReentrant {
        if (_to == address(0)) revert AOXC_Bridge_ZeroAddress();
        if (IERC20(aoxcToken).balanceOf(address(this)) < _amount) revert AOXC_Bridge_InsufficientCollateral();

        IERC20(aoxcToken).safeTransfer(_to, _amount);
        emit BridgeIn(_srcChainId, _to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImpl) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[47] private __gap;
}
