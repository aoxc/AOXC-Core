// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAOXCSwap Sovereign Interface V2.6
 * @author AOXC AI Architect & Senior Quantum Auditor
 * @notice 26-Layer Autonomous Swap & Market Defense Interface.
 * @dev Reaching 10,000x DeFi quality through Petrified Liquidity and Autonomic Floor Support.
 * Designed to eliminate predatory MEV and maintain algorithmic price stability.
 */
interface IAOXCSwap {
    /**
     * @dev Core metrics governing the Sovereign Market health.
     * [Layer 1-3] Real-time tracking of the price floor and liquidity permanence.
     */
    struct SovereignMetrics {
        uint256 floorPrice; // [Layer 1] Absolute price baseline supported by Treasury
        uint256 totalPetrified; // [Layer 2] Permanently locked protocol-owned liquidity
        bool selfHealingActive; // [Layer 3] Status of autonomous market support mechanisms
    }

    /*//////////////////////////////////////////////////////////////
                                TELEMETRY
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
     * @notice Executes a token swap with Mandatory Neural Risk Vetting.
     * @dev Layer 16-20: Blocks predatory sandwich attacks, front-running, and JIT liquidity exploits via AI signatures.
     * @param amountIn Amount of source tokens.
     * @param tokenIn Source token address.
     * @param tokenOut Destination token address.
     * @param aiSignature Cryptographic proof from AI Sentinel verifying the trade's legitimacy.
     */
    function sovereignSwap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bytes calldata aiSignature
    ) external;

    /**
     * @notice Petrifies (permanently locks) liquidity to strengthen the Sovereign Floor.
     * @dev Layer 21-23: Irreversibly converts LP tokens into protocol-owned liquidity (POL).
     * This creates a "black hole" for liquidity that prevents rug-pulls and exit drains.
     */
    function petrifyLiquidity(address lpToken, uint256 amount) external;

    /**
     * @notice Triggers the Autonomic Defense mechanism to stabilize the price.
     * @dev Layer 24-26: Executes buy-backs or stablecoin injections if AI detects a Floor Price breach.
     * @param stableToken The reserve currency used for the defense operation.
     * @param aiProof Evidence of market deviation verified by the AI Sentinel.
     */
    function triggerAutonomicDefense(address stableToken, bytes calldata aiProof) external;

    /*//////////////////////////////////////////////////////////////
                        V26 DEFENSIVE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the real-time health metrics of the AOXC sovereign market.
     */
    function metrics()
        external
        view
        returns (uint256 floorPrice, uint256 totalPetrified, bool selfHealingActive);

    /**
     * @notice Layer 12: Returns the AI-integrated price oracle responsible for market feed.
     */
    function priceOracle() external view returns (address);

    /**
     * @notice Layer 23: Returns the 26-Hour Lockdown state of the Swap Engine.
     */
    function getSwapBastionState() external view returns (bool isLocked, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                         STRATEGY & GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the absolute floor price supported by protocol reserves.
     */
    function setFloorPrice(uint256 _newFloor) external;

    /**
     * @notice Links an external vault or strategy to the swap engine for automated yield/defense.
     */
    function linkStrategy(bytes32 key, address target) external;

    /**
     * @notice Enables or disables the autonomous self-healing defense protocol.
     */
    function toggleSelfHealing(bool status) external;
}
