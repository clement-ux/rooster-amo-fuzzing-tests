// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Local imports
import {Math} from "./Math.sol";
import {RegisteredTicks} from "./RegisteredTicks.sol";

// External imports
import {TickMath} from "@rooster-pool/v2-common/contracts/libraries/TickMath.sol";
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";

library Views {
    using FixedPointMathLib for uint128;
    using FixedPointMathLib for uint256;

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

    /// @notice The objectif here is to find how many token there is between the current price and the target price
    /// With this, we can use the swap function to swap the right amount of token out, and thus reach target price
    function getAmountOfTokenBetweenPrices(IMaverickV2Pool pool, RegisteredTicks register, uint256 targetPrice)
        external
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 currentPrice = getPoolSqrtPrice(pool);

        // Get the current tick
        int24 currentTick = int24(pool.getState().activeTick);
        int24 targetTick = int24(register.getTickForPrice(targetPrice));

        // If the current tick is above the target tick, we need to swap token A for token B, so amountA > 0 and amountB = 0
        // If the current tick is below the target tick, we need to swap token B for token A, so amountB > 0 and amountA = 0
        uint256 priceUnder = TickMath.tickSqrtPrice(1, targetTick);
        uint256 priceOver = TickMath.tickSqrtPrice(1, targetTick + 1);
        uint256 distance = priceOver - priceUnder;
        // Cross-tick logic
        IMaverickV2Pool.TickState memory tickState;
        if (currentTick > targetTick) {
            while (currentTick > targetTick) {
                tickState = pool.getTick(currentTick);
                amountA += tickState.reserveA;
                currentTick -= 1; // Move to the previous tick
            }
            // Now we are in the situation where currentTick == targetTick
            // The following calculation only works if the current tick is fully filled with A token
            // Price ratio
            uint256 ratio = (priceOver - targetPrice).divWad(distance);

            // Calculate the amount of token A to swap in the target tick
            tickState = pool.getTick(targetTick);
            require(tickState.reserveB == 0, "Current tick must be fully filled with A token");
            amountA += tickState.reserveA.mulWad(ratio);
        } else if (currentTick < targetTick) {
            while (currentTick < targetTick) {
                tickState = pool.getTick(currentTick);
                amountB += tickState.reserveB;
                currentTick += 1; // Move to the next tick
            }
            // Now we are in the situation where currentTick == targetTick

            // The following calculation only works if the current tick is fully filled with B token
            // Price ratio
            uint256 ratio = (targetPrice - priceUnder).divWad(distance);

            // Calculate the amount of token B to swap in the target tick
            tickState = pool.getTick(targetTick);
            require(tickState.reserveA == 0, "Current tick must be fully filled with B token");
            amountB += tickState.reserveB.mulWad(ratio);
        } else {
            // In this situation, the current price is in the same tick as the target price
            // So there is 2 tokens in the current tick
            tickState = pool.getTick(currentTick);
            uint256 liquidity = tickState.reserveA + tickState.reserveB;

            uint256 ratio = Math.absDiff(currentPrice, targetPrice).divWad(distance);
            if (targetPrice < currentPrice) amountA = liquidity.mulWad(ratio);
            else if (targetPrice > currentPrice) amountB = liquidity.mulWad(ratio);
            else return (0, 0);
        }
    }

    /// @notice Copied from MaverickV2Position
    function getPoolSqrtPrice(IMaverickV2Pool pool) public view returns (uint256 sqrtPrice) {
        int32 tick = pool.getState().activeTick;
        (sqrtPrice,) = getTickSqrtPriceAndL(pool, tick);
    }

    /// @notice Copied from MaverickV2Position
    function getTickSqrtPriceAndL(IMaverickV2Pool pool, int32 tick)
        public
        view
        returns (uint256 sqrtPrice, uint256 liquidity)
    {
        uint256 tickSpacing = pool.tickSpacing();
        (uint256 sqrtLowerTickPrice, uint256 sqrtUpperTickPrice) = TickMath.tickSqrtPrices(tickSpacing, tick);
        IMaverickV2Pool.TickState memory tickState = pool.getTick(tick);

        (sqrtPrice, liquidity) = TickMath.getTickSqrtPriceAndL(
            tickState.reserveA, tickState.reserveB, sqrtLowerTickPrice, sqrtUpperTickPrice
        );
    }
}
