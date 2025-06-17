// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Local imports
import {Math} from "./Math.sol";
import {RegisteredTicks} from "./RegisteredTicks.sol";

// External imports
import {TickMath} from "@rooster-pool/v2-common/contracts/libraries/TickMath.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {MaverickV2Quoter} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Quoter.sol";
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";

library Views {
    using SafeCastLib for uint256;
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

    function getAmountOfTokenBetweenPrices(IMaverickV2Pool pool, RegisteredTicks register, uint256 targetPrice)
        external
        view
        returns (uint256 amountA, uint256 amountB)
    {
        return getAmountOfTokenBetweenPrices(pool, register, targetPrice, false, 0, 0);
    }

    /// @notice The objectif here is to find how many token there is between the current price and the target price
    /// With this, we can use the swap function to swap the right amount of token out, and thus reach target price
    function getAmountOfTokenBetweenPrices(
        IMaverickV2Pool pool,
        RegisteredTicks register,
        uint256 targetPrice,
        bool removeLiquidity,
        uint256 amoPositionA,
        uint256 amoPositionB
    ) public view returns (uint256 amountA, uint256 amountB) {
        uint256 currentPrice = getPoolSqrtPrice(pool);

        // Get the current tick
        int24 currentTick = int24(pool.getState().activeTick);
        int24 targetTick = int24(register.getTickForPrice(targetPrice));

        // If the current tick is above the target tick, we need to swap token A for token B, so amountA > 0 and amountB = 0
        // If the current tick is below the target tick, we need to swap token B for token A, so amountB > 0 and amountA = 0
        uint256 priceUnder = TickMath.tickSqrtPrice(1, targetTick);
        uint256 priceOver = TickMath.tickSqrtPrice(1, targetTick + 1);

        if (currentTick == targetTick) {
            SameTick memory sameTick = SameTick({
                pool: pool,
                currentTick: currentTick,
                targetTick: targetTick,
                removeLiquidity: removeLiquidity,
                amoPositionA: amoPositionA,
                amoPositionB: amoPositionB,
                currentPrice: currentPrice,
                targetPrice: targetPrice
            });
            return getAmountOfTokenBetweenPrices_SameTick(sameTick);
        }
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
            uint256 ratio = (priceOver - targetPrice).divWad(priceOver - priceUnder);

            // Calculate the amount of token A to swap in the target tick
            tickState = pool.getTick(targetTick);
            amountA += tickState.reserveA.mulWad(ratio);
        }

        if (currentTick < targetTick) {
            while (currentTick < targetTick) {
                tickState = pool.getTick(currentTick);
                amountB += tickState.reserveB;
                currentTick += 1; // Move to the next tick
            }
            // Now we are in the situation where currentTick == targetTick

            // The following calculation only works if the current tick is fully filled with B token
            // Price ratio
            uint256 ratio = (targetPrice - priceUnder).divWad(priceOver - priceUnder);

            // Calculate the amount of token B to swap in the target tick
            tickState = pool.getTick(targetTick);
            amountB += tickState.reserveB.mulWad(ratio);
        }
    }

    struct SameTick {
        IMaverickV2Pool pool;
        int24 currentTick;
        int24 targetTick;
        bool removeLiquidity;
        uint256 amoPositionA;
        uint256 amoPositionB;
        uint256 currentPrice;
        uint256 targetPrice;
    }

    function getAmountOfTokenBetweenPrices_SameTick(SameTick memory params)
        internal
        view
        returns (uint256 amountA, uint256 amountB)
    {
        IMaverickV2Pool.TickState memory tickState = params.pool.getTick(params.currentTick);

        if (params.removeLiquidity && params.currentTick == -1) {
            tickState.reserveA -= params.amoPositionA.toUint128();
            tickState.reserveB -= params.amoPositionB.toUint128();
        }

        uint256 liquidity = tickState.reserveA + tickState.reserveB;

        uint256 distance =
            TickMath.tickSqrtPrice(1, params.targetTick + 1) - TickMath.tickSqrtPrice(1, params.targetTick);
        uint256 ratio = Math.absDiff(params.currentPrice, params.targetPrice).divWad(distance);
        if (params.targetPrice < params.currentPrice) amountA = liquidity.mulWad(ratio);
        else if (params.targetPrice > params.currentPrice) amountB = liquidity.mulWad(ratio);
        else return (0, 0);
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

    function convertWethSharesIntoPrice(uint256 wethShare) public pure returns (uint256) {
        // This will be always between tick -1 and tick 0
        uint256 sqrtPriceTickLower = TickMath.tickSqrtPrice(1, -1);
        uint256 sqrtPriceTickHigher = TickMath.tickSqrtPrice(1, 0);

        // Calculate the price based on the WETH share
        return sqrtPriceTickLower + (sqrtPriceTickHigher - sqrtPriceTickLower).mulWad(wethShare);
    }

    function getAddLiquidityParams(
        IMaverickV2Pool pool,
        MaverickV2Quoter quoter,
        uint256 maxWETH,
        uint256 maxOETH,
        int32 tick,
        uint8 bin
    ) public returns (uint256 amountWETH, uint256 amountOETH, IMaverickV2Pool.AddLiquidityParams memory addParam) {
        int32[] memory ticks = new int32[](1);
        ticks[0] = tick;
        uint128[] memory amounts = new uint128[](1);
        // arbitrary LP amount
        amounts[0] = 1e24;

        // construct value for Quoter with arbitrary LP amount
        addParam = IMaverickV2Pool.AddLiquidityParams({kind: bin, ticks: ticks, amounts: amounts});
        (amountWETH, amountOETH,) = quoter.calculateAddLiquidity(pool, addParam);

        // Adjust amount of WETH, OETH and LPs needed
        amountWETH = amountWETH == 0 ? 1 : amountWETH; // ensure we always have a non-zero amount
        amountOETH = amountOETH == 0 ? 1 : amountOETH; // ensure we always have a non-zero amount
        addParam.amounts[0] = (((maxWETH - 1) * 1e24) / amountWETH).min((maxOETH - 1) * 1e24 / amountOETH).toUint128();

        // Return the amounts needed to add liquidity, with adjusted LP amount
        (amountWETH, amountOETH,) = quoter.calculateAddLiquidity(pool, addParam);
        require(amountWETH <= maxWETH, "Views: Amount of WETH exceeds maxWETH");
        require(amountOETH <= maxOETH, "Views: Amount of OETH exceeds maxOETH");

        return (amountWETH, amountOETH, addParam);
    }
}
