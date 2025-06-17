// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TargetFunction} from "../TargetFunction.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2PoolLens} from "@rooster-pool/v2-supplemental/contracts/interfaces/IMaverickV2PoolLens.sol";

contract UnitTesting is TargetFunction {
    function test_reproduce_failing() public {
        // Initial situation:
        // There is 1e16 OETH at tick -1 in the pool and that's all.

        // Swap before, to push the price in the middle of the tick -1
        IMaverickV2Pool.State memory poolState = pool.getState();
        require(poolState.activeTick == -1, "Active tick is not -1");
        IMaverickV2Pool.TickState memory tickState = pool.getTick(poolState.activeTick);
        uint256 reserveA = tickState.reserveA;
        uint256 reserveB = tickState.reserveB;
        (uint256 amountA, uint256 amountB,) = quoter.calculateSwap({
            pool: pool,
            amount: uint128(reserveB / 3),
            tokenAIn: true,
            exactOutput: true,
            tickLimit: 2
        });
        IMaverickV2Pool.SwapParams memory swapParams =
            IMaverickV2Pool.SwapParams({amount: uint128(reserveB / 3), tokenAIn: true, exactOutput: true, tickLimit: 2});

        MockERC20(address(weth)).mint(address(this), amountA);
        MockERC20(address(oeth)).mint(address(this), amountB);

        weth.transfer(address(pool), amountA);
        oeth.transfer(address(pool), amountB);
        pool.swap({recipient: address(this), params: swapParams, data: ""});

        pool.getState();
        pool.getTick(poolState.activeTick);

        // Add Liquidity
        int32[] memory tickArray = new int32[](1);
        tickArray[0] = -1;
        uint128[] memory liquidityArray = new uint128[](1);
        liquidityArray[0] = 1 ether;
        IMaverickV2PoolLens.AddParamsViewInputs memory inputs = IMaverickV2PoolLens.AddParamsViewInputs({
            pool: pool,
            kind: 0,
            ticks: tickArray,
            relativeLiquidityAmounts: liquidityArray,
            addSpec: IMaverickV2PoolLens.AddParamsSpecification({
                slippageFactorD18: 0.1 ether,
                numberOfPriceBreaksPerSide: 0,
                targetAmount: 1 ether,
                targetIsA: false
            })
        });

        (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        ) = poolLens.getAddLiquidityParams(inputs);

        (amountA, amountB, ) = quoter.calculateAddLiquidity({
            pool: pool,
            params: addParams[0]
        });

        MockERC20(address(weth)).mint(address(this), amountA);
        MockERC20(address(oeth)).mint(address(this), amountB);
        weth.approve(address(liquidityManager), amountA);
        oeth.approve(address(liquidityManager), amountB);

        liquidityManager.addLiquidity({
            pool: pool,
            recipient: address(this),
            subaccount: 0,
            packedSqrtPriceBreaks: packedSqrtPriceBreaks,
            packedArgs: packedArgs
        });
    }
}
