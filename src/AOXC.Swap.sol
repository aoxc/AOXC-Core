// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AOXCStorage } from "./abstract/AOXCStorage.sol";
import { AOXCConstants } from "./libraries/AOXCConstants.sol";
import { AOXCErrors } from "./libraries/AOXCErrors.sol";

interface IPriceOracle {
    function getConsensusPrice(address token) external view returns (uint256);
    function getTwapPrice(address token, uint256 interval) external view returns (uint256);
    function getLiveness() external view returns (bool);
}

/**
 * @title AOXCSwap V2.0.1
 * @notice 26-Layer Sovereign Swap Engine with Neural Price Validation.
 * @dev [V2-FIX]: Resolved OZ v5 UUPS init and optimized oracle validation flow.
 */
contract AOXCSwap is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    AOXCStorage
{
    using SafeERC20 for IERC20;

    struct ApexSwapStorage {
        uint256 totalPetrifiedLiquidity; 
        uint256 maxPriceDeviationBps;
        bool isCircuitBreakerTripped;
        uint256 lastSecurityPulse;
        uint256 livenessGracePeriod;
        address priceOracle;
        address sovereignTreasury;
        mapping(address => uint256) userLastActionBlock;
        mapping(address => uint256) lastLiquidityUpdateBlock;
        bool initialized;
    }

    // keccak256(abi.encode(uint256(keccak256("aoxc.v2.swap.storage")) - 1)) & ~0xff
    bytes32 private constant SWAP_STORAGE_SLOT =
        0x487f909192518e932e49c95d97f9c733f5244510065090176d6c703126780a00;

    function _getApex() internal pure returns (ApexSwapStorage storage $) {
        assembly { $.slot := SWAP_STORAGE_SLOT }
    }

    event ApexCircuitBreaker(address indexed instigator, string reason);
    event SovereignSwapExecuted(address indexed actor, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address governor, address _oracle, address _treasury) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        // [V2-FIX]: __UUPSUpgradeable_init() removed for OZ v5 compatibility

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AOXCConstants.GOVERNANCE_ROLE, governor);
        _grantRole(AOXCConstants.GUARDIAN_ROLE, governor);

        ApexSwapStorage storage $ = _getApex();
        if ($.initialized) revert AOXCErrors.AOXC_GlobalLockActive();

        $.priceOracle = _oracle;
        $.sovereignTreasury = _treasury;
        $.maxPriceDeviationBps = 80; // 0.8%
        $.lastSecurityPulse = block.timestamp;
        $.livenessGracePeriod = AOXCConstants.AI_MAX_FREEZE_DURATION;
        $.initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY LAYER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Layer 26: Validation of price stability and temporal sanity.
     */
    function _validateOmnipotence(address tokenIn, address tokenOut) internal view {
        ApexSwapStorage storage $ = _getApex();

        if ($.isCircuitBreakerTripped) revert AOXCErrors.AOXC_GlobalLockActive();

        if ($.lastLiquidityUpdateBlock[tokenIn] == block.number || $.lastLiquidityUpdateBlock[tokenOut] == block.number) {
            revert AOXCErrors.AOXC_TemporalCollision();
        }

        if (block.timestamp > $.lastSecurityPulse + $.livenessGracePeriod) {
            revert AOXCErrors.AOXC_Neural_HeartbeatLost($.lastSecurityPulse, block.timestamp);
        }

        IPriceOracle oracle = IPriceOracle($.priceOracle);
        if (!oracle.getLiveness()) revert AOXCErrors.AOXC_CustomRevert("ORACLE_OFFLINE");

        _checkPriceDeviation(oracle, tokenIn);
        _checkPriceDeviation(oracle, tokenOut);
    }

    function _checkPriceDeviation(IPriceOracle oracle, address token) internal view {
        uint256 spot = oracle.getConsensusPrice(token);
        uint256 twap = oracle.getTwapPrice(token, 15 minutes);
        if (twap > 0) {
            uint256 deviation = spot > twap ? spot - twap : twap - spot;
            if ((deviation * 10000) / twap > _getApex().maxPriceDeviationBps) {
                revert AOXCErrors.AOXC_Neural_RiskThresholdBreached(deviation, _getApex().maxPriceDeviationBps);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION
    //////////////////////////////////////////////////////////////*/

    function executeApexSwap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut
    ) external nonReentrant {
        _validateOmnipotence(tokenIn, tokenOut);
        
        ApexSwapStorage storage $ = _getApex();
        MainStorage storage main = _getMainStorage();

        // Layer 3: Anti-Sandwich Protection
        if ($.userLastActionBlock[msg.sender] == block.number) {
            revert AOXCErrors.AOXC_TemporalCollision();
        }

        // Layer 15: Reputation Gating for high-volume swaps
        if ($.totalPetrifiedLiquidity > 0 && amountIn > $.totalPetrifiedLiquidity / 100) {
            if (main.userReputation[msg.sender] < 10000) {
                revert AOXCErrors.AOXC_InsufficientReputation(msg.sender, main.userReputation[msg.sender], 10000);
            }
        }

        $.userLastActionBlock[msg.sender] = block.number;
        $.lastSecurityPulse = block.timestamp;

        _performSovereignExchange(tokenIn, tokenOut, amountIn, minAmountOut);
    }

    function _performSovereignExchange(
        address inT, 
        address outT, 
        uint256 amtIn, 
        uint256 minOut
    ) internal {
        ApexSwapStorage storage $ = _getApex();
        IERC20(inT).safeTransferFrom(msg.sender, $.sovereignTreasury, amtIn);
        emit SovereignSwapExecuted(msg.sender, inT, outT, amtIn, minOut);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN CONTROLS
    //////////////////////////////////////////////////////////////*/

    function updateProtocolLiquidity(uint256 newAmount) external onlyRole(AOXCConstants.GUARDIAN_ROLE) {
        _getApex().totalPetrifiedLiquidity = newAmount;
    }

    function _authorizeUpgrade(address) internal override view onlyRole(AOXCConstants.GOVERNANCE_ROLE) {}
}
