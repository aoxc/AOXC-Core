// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title MockOracle
 * @notice Simulates AOXC Neural Price Oracle for testing price-dependent defenses.
 * @dev Allows manual manipulation of consensus and TWAP prices to trigger circuit breakers.
 */
contract MockOracle {
    uint256 private consensusPrice;
    uint256 private twapPrice;
    bool private isLive = true;

    // --- Events for Audit Trace ---
    event PriceUpdated(uint256 newConsensus, uint256 newTwap);
    event LivenessToggled(bool status);

    constructor(uint256 _initialPrice) {
        consensusPrice = _initialPrice;
        twapPrice = _initialPrice;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getConsensusPrice() external view returns (uint256) {
        return consensusPrice;
    }

    function getTwapPrice(
        uint256 /* interval */
    )
        external
        view
        returns (uint256)
    {
        return twapPrice;
    }

    function getLiveness() external view returns (bool) {
        return isLive;
    }

    /*//////////////////////////////////////////////////////////////
                        MOCK CONTROL FUNCTIONS (TEST ONLY)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Manually sets the consensus price to simulate volatility or attacks.
     */
    function setConsensusPrice(uint256 _price) external {
        consensusPrice = _price;
        emit PriceUpdated(consensusPrice, twapPrice);
    }

    /**
     * @dev Manually sets the TWAP price to test price deviation logic.
     */
    function setTwapPrice(uint256 _price) external {
        twapPrice = _price;
        emit PriceUpdated(consensusPrice, twapPrice);
    }

    /**
     * @dev Toggles oracle liveness to test "ORACLE_OFFLINE" reverts.
     */
    function setLiveness(bool _status) external {
        isLive = _status;
        emit LivenessToggled(_status);
    }
}
