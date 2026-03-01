// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/**
 * @title IAOXCHANGE
 * @author AOXCAN AI Architect
 * @notice Interface for the AOXCORE Autonomous Exchange & Market Defense Engine.
 * @dev V2.1.0 - Optimized for Petrified Liquidity, Autonomic Floor Support, and Neural Vetting.
 */
interface IAOXCHANGE {
    /**
     * @dev Metrics governing the health of the exchange market.
     * English: Captures the state of the sovereign floor and locked liquidity.
     */
    struct MarketMetrics {
        uint256 floorPrice; // Price baseline supported by AOXVAULT
        uint256 totalPetrified; // Permanently locked Protocol-Owned Liquidity (POL)
        bool selfHealingActive; // Autonomous defense status
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event AutonomicDefenseTriggered(uint256 indexed currentPrice, uint256 injectionAmount);
    event FloorPriceUpdated(uint256 newFloor);
    event LiquidityPetrified(address indexed sender, uint256 amount);
    event StrategyLinked(bytes32 indexed key, address indexed target);
    event NeuralSwapExecuted(address indexed actor, uint256 amountIn, uint256 riskScore);

    /*//////////////////////////////////////////////////////////////
                         CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes an exchange with Mandatory Neural Risk Vetting.
     * @dev Blocks predatory MEV and sandwich attacks via AOXCAN AI signatures.
     * @param amountIn Amount of tokens to swap.
     * @param tokenIn Source token address.
     * @param tokenOut Destination token address.
     * @param aiProof Cryptographic proof from the Neural Sentinel.
     */
    function executeSwap(uint256 amountIn, address tokenIn, address tokenOut, bytes calldata aiProof) external;

    /**
     * @notice Petrifies liquidity to strengthen the market floor.
     * @dev Irreversibly converts LP tokens into Protocol-Owned Liquidity (POL).
     * @param lpToken The address of the liquidity provider token (e.g., Uniswap V2 Pair).
     * @param amount The amount of LP tokens to lock forever.
     */
    function petrifyLiquidity(address lpToken, uint256 amount) external;

    /**
     * @notice Triggers the Autonomic Defense mechanism to stabilize the price.
     * @dev Executes buy-backs via AOXVAULT if a Floor Price breach is detected.
     * @param stableToken The currency used for the defense injection (e.g., USDT/USDC).
     * @param aiProof Evidence of market anomaly signed by the AI Node.
     */
    function triggerAutonomicDefense(address stableToken, bytes calldata aiProof) external;

    /*//////////////////////////////////////////////////////////////
                            DEFENSIVE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns real-time market health metrics.
     */
    function getMarketMetrics() external view returns (MarketMetrics memory);

    /**
     * @notice Returns the AI-integrated price oracle.
     */
    function getPriceOracle() external view returns (address);

    /**
     * @notice Returns the lockdown state of the exchange engine.
     * @return isLocked Boolean status of the circuit breaker.
     * @return expiry Timestamp when the current lock expires.
     */
    function getExchangeLockState() external view returns (bool isLocked, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                         STRATEGY & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the absolute floor price supported by protocol reserves.
     * @param _newFloor The new price baseline in 18 decimals.
     */
    function setFloorPrice(uint256 _newFloor) external;

    /**
     * @notice Links an external strategy for automated market defense.
     * @param key Strategy identifier (keccak256).
     * @param target Contract address of the strategy.
     */
    function linkStrategy(bytes32 key, address target) external;

    /**
     * @notice Enables or disables the autonomous self-healing protocol.
     * @param status True to activate, False to hibernate.
     */
    function toggleSelfHealing(bool status) external;
}
