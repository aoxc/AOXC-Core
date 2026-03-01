// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INFRASTRUCTURE - REMAPPING COMPLIANT
import {AOXCConstants} from "./libraries/AOXCConstants.sol";
import {AOXCErrors} from "./libraries/AOXCErrors.sol";

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

interface IVault {
    function requestSettlement(address token, address to, uint256 amount) external;
    function requestAutomatedRefill(uint256 amount) external;
}

interface IAOXCOracle {
    function getPriceData(address tIn, address tOut) external view returns (uint256 price, uint256 timestamp);
}

/**
 * @title AOXCHANGE_SUPREME
 * @notice Drawer tabanlı likidite ve Oracle destekli otonom takas motoru.
 * @dev V2.1.8 - 0 Lint, Hardened settlement logic.
 */
contract AOXCHANGE_SUPREME is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Drawer {
        uint256 aoxcStock;
        uint256 refillThreshold;
        uint256 refillAmount;
        bool isEnabled;
    }

    struct ExchangeStorage {
        address vault;
        address aoxc;
        address oracle;
        mapping(address => Drawer) drawers;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE SLOT
    //////////////////////////////////////////////////////////////*/

    // ERC-7201 Compliance - Fixed isolated slot
    bytes32 private constant EXCHANGE_STORAGE_LOCATION =
        0x6e8a379103c861f778393e9e6f2bc8b671d1796c739a8976136f78816f1f6c00;

    function _getStore() internal pure returns (ExchangeStorage storage $) {
        assembly { $.slot := EXCHANGE_STORAGE_LOCATION }
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event SwapExecuted(address indexed user, address tIn, address tOut, uint256 amountIn, uint256 amountOut);
    event DrawerSynchronized(address indexed asset, uint256 newStock);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Exchange V2 Sovereign Başlatıcı
     */
    function initialize(address dao, address vault, address aoxc, address oracle) external initializer {
        if (dao == address(0) || vault == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, dao);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, dao);
        _grantRole(AOXCConstants.UPGRADER_ROLE, dao);

        ExchangeStorage storage $ = _getStore();
        $.vault = vault;
        $.aoxc = aoxc;
        $.oracle = oracle;
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION
    //////////////////////////////////////////////////////////////*/

    function executeSwap(address tIn, address tOut, uint256 amountIn, uint256 minAmountOut) external nonReentrant {
        ExchangeStorage storage $ = _getStore();
        if (tIn == address(0) || tOut == address(0)) revert AOXCErrors.AOXC_InvalidAddress();

        uint256 amountOut = _calculatePrice(tIn, tOut, amountIn);
        if (amountOut < minAmountOut) revert AOXCErrors.AOXC_CustomRevert("EXCHANGE: SLIPPAGE");

        // AOXC Drawer (Çekmece) Kontrolü
        if (tOut == $.aoxc) {
            _processDrawerRefill($, tIn, amountOut);
        }

        // Atomik Transfer ve Yerleşim (Settlement)
        IERC20(tIn).safeTransferFrom(msg.sender, $.vault, amountIn);
        IVault($.vault).requestSettlement(tOut, msg.sender, amountOut);

        emit SwapExecuted(msg.sender, tIn, tOut, amountIn, amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _processDrawerRefill(ExchangeStorage storage $, address tIn, uint256 amountOut) internal {
        Drawer storage drawer = $.drawers[tIn];
        if (!drawer.isEnabled) revert AOXCErrors.AOXC_CustomRevert("EXCHANGE: PAIR_DISABLED");
        if (drawer.aoxcStock < amountOut) revert AOXCErrors.AOXC_CustomRevert("EXCHANGE: DRAWER_INSUFFICIENT");

        drawer.aoxcStock -= amountOut;

        if (drawer.aoxcStock < drawer.refillThreshold && drawer.refillAmount > 0) {
            IVault($.vault).requestAutomatedRefill(drawer.refillAmount);
            drawer.aoxcStock += drawer.refillAmount;
            emit DrawerSynchronized(tIn, drawer.aoxcStock);
        }
    }

    function _calculatePrice(address tIn, address tOut, uint256 amountIn) internal view returns (uint256) {
        ExchangeStorage storage $ = _getStore();
        (uint256 price, uint256 ts) = IAOXCOracle($.oracle).getPriceData(tIn, tOut);

        // Veri tazelik kontrolü (1 Saat)
        if (block.timestamp > ts + 1 hours) revert AOXCErrors.AOXC_CustomRevert("EXCHANGE: STALE_PRICE");

        return (amountIn * price) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    function configureDrawer(address asset, uint256 threshold, uint256 refill, bool status)
        external
        onlyRole(AOXCConstants.GOVERNANCE_ROLE)
    {
        Drawer storage drawer = _getStore().drawers[asset];
        drawer.refillThreshold = threshold;
        drawer.refillAmount = refill;
        drawer.isEnabled = status;
    }

    function syncDrawerStock(address asset, uint256 actualStock) external onlyRole(AOXCConstants.GOVERNANCE_ROLE) {
        _getStore().drawers[asset].aoxcStock = actualStock;
    }

    function _authorizeUpgrade(address) internal override onlyRole(AOXCConstants.UPGRADER_ROLE) {}
}
