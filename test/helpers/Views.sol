// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";

library Views {
    function checkForExpectedPoolPrice(RoosterAMOStrategy strategy)
        external
        view
        returns (bool _isExpectedRange, uint256 _wethSharePct)
    {
        uint256 currentPrice = strategy.getPoolSqrtPrice();

        uint256 sqrtPriceTickLower = strategy.sqrtPriceTickLower();
        uint256 sqrtPriceTickHigher = strategy.sqrtPriceTickHigher();

        // If current price is outside the expected
        // - below lower bound ->   0% WETH / 100% OETH
        // - above upper bound -> 100% WETH /   0% OETH
        // return false and the current WETH share (0% or 100%)
        if (currentPrice < sqrtPriceTickLower) return (false, 0);
        if (currentPrice > sqrtPriceTickHigher) return (false, 1 ether);

        uint256 wethShare = strategy.getWETHShare();
        uint256 allowedWethShareStart = strategy.allowedWethShareStart();
        uint256 allowedWethShareEnd = strategy.allowedWethShareEnd();

        // If WETH share is outside the allowed range
        // return false and the current WETH share
        if (wethShare < allowedWethShareStart || wethShare > allowedWethShareEnd) return (false, wethShare);

        // If WETH share is within the allowed range
        // return true and the current WETH share
        return (true, wethShare);
    }
}
