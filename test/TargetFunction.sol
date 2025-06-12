// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Foundry imports
import {console} from "forge-std/console.sol";

// Test imports
import {Math} from "./helpers/Math.sol";
import {Views} from "./helpers/Views.sol";
import {Logger} from "./helpers/Logger.sol";
import {Properties} from "./Properties.sol";
import {InvariantParams as inv} from "./helpers/Constants.sol";

// ERC
import {ERC20} from "@solmate/tokens/ERC20.sol";

// AMO imports
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";

// Maverick interfaces
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";

// Solmate and Solady imports
import {LibString} from "@solady/utils/LibString.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

abstract contract TargetFunction is Properties {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                            ✦✦✦ AMO FUNCTIONS ✦✦✦                             ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [x] SetAllowedPoolWethShareInterval
    // [x] Deposit
    // [ ] Withdraw
    // [ ] Rebalance

    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                      ✦✦✦ MAVERICK V2 POOL FUNCTIONS ✦✦✦                      ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [ ] MigrateBinUpStack (not sure if this is needed)
    // [x] Swap (Pool)
    // [ ] MintPositionNft (Liquidity Manager)
    // [ ] AddPositionLiquidityToSenderByTokenIndex (Liquidity Manager)
    // [ ] RemoveLiquidityToSender (Position Manager)

    using Math for uint256;
    using Views for RoosterAMOStrategy;
    using Logger for uint80;
    using Logger for uint256;
    using LibString for string;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    function handler_setAllowedPoolWethShareInterval(uint96 _start, uint96 _end) external {
        uint256 start = _bound(_start, 1, 45); // ]1, 45]
        uint256 end = _bound(_end, 60, 95); // [0.60, 0.95[
        uint256 allowedWethShareStart = start == 1 ? 0.01001 ether : start * 0.01 ether;
        uint256 allowedWethShareEnd = end == 95 ? 0.94999 ether : end * 0.01 ether;

        if (inv.LOG) {
            console.log(
                "User: %s -> setAllowedPoolWethShareInterval()\t Start\t : %s  End      : %s",
                "Gover",
                allowedWethShareStart.faa(),
                allowedWethShareEnd.faa()
            );
        }

        // Main call
        vm.prank(governor);
        strategy.setAllowedPoolWethShareInterval(allowedWethShareStart, allowedWethShareEnd);
    }

    function handler_swap(bool _wethIn, uint256 _amount) external {
        // Todo: reduce the type of _amount (to uint96 or smth)
        // As there is only one swapper, we can use the first one.
        address swapper = swappers[0];

        //_wethIn = true;
        (ERC20 tokenIn, ERC20 tokenOut) = _wethIn ? (weth, oeth) : (oeth, weth);

        // Reserve of tokenOut held by the pool
        uint256 poolBalance = tokenOut.balanceOf(address(pool));

        // Bound amount expected to be received between 0 and poolBalance
        uint256 amountOut = _bound(_amount, 0, poolBalance);

        // Quote amountIn needed to swap for amountOut
        (uint256 amountIn,,) = quoter.calculateSwap({
            pool: IMaverickV2Pool(address(pool)),
            amount: amountOut.toUint128(),
            tokenAIn: _wethIn,
            exactOutput: true,
            tickLimit: _wethIn ? inv.TICK_LIMIT : -inv.TICK_LIMIT
        });

        string memory log = LibString.concat("User: ", vm.getLabel(swapper)).concat(
            " -> swap() \t\t\t\t AmountIn: %s  AmountOut: %s  TokenIn: %s"
        );
        if (inv.LOG) {
            console.log(log, amountIn.faa(), amountOut.faa(), _wethIn ? "WETH" : "OETH");
        }

        // Give enough tokenIn to the swapper
        deal(address(tokenIn), swapper, amountIn);

        vm.startPrank(swapper);
        // Swapper send token to the pool and swap
        tokenIn.transfer(address(pool), amountIn);
        pool.swap({
            recipient: swapper,
            params: IMaverickV2Pool.SwapParams({
                amount: amountOut.toUint128(),
                tokenAIn: _wethIn,
                exactOutput: true,
                tickLimit: _wethIn ? inv.TICK_LIMIT : -inv.TICK_LIMIT
            }),
            data: hex""
        });
        vm.stopPrank();
    }

    function handler_deposit(uint80 _amount) external {
        _amount = _amount == 0 ? 1 : _amount; // Bound to be at least 1

        // Check if the pool price is in the expected range
        (bool isExpectedRange, uint256 wethSharePct) = strategy.checkForExpectedPoolPrice();
        // Depositing when the pool price is not in the expected range does not make sense.
        // As we will only send WETH to the strategy and do nothing with it, waiting for the
        // next deposit call is in expected range.
        vm.assume(isExpectedRange);

        // Give WETH to the vault
        deal(address(weth), address(vault), _amount);
        // Vault transfer it to the strategy
        // Note: The vault is the only one allowed to call deposit()
        // Note: We don't deal directly to the strategy, otherwise it will mess up the accounting.
        vm.prank(address(vault));
        weth.transfer(address(strategy), _amount);

        uint256 wethBalance = weth.balanceOf(address(strategy));

        // Log data
        if (inv.LOG) {
            console.log(
                "User: Vault -> deposit() \t\t\t\t Amount\t : %s  WethShare: %s  Expect : %s",
                wethBalance.faa(),
                wethSharePct.faa(),
                isExpectedRange ? "Yes" : "No"
            );
        }

        // Main call
        vm.prank(address(vault));
        strategy.deposit(address(weth), _amount);
    }

    function handler_rebalance(uint16 _targetWethShare) external {
        // There is two possible scenarios for rebalance:
        // 1. The current price is above the targeted price
        // 2. The current price is below the targeted price
        // ---
        // How to determine the targeted price?
        // We will take a random rounded value between the allowedWethShareStart and allowedWethShareEnd
        // This will determine the targeted price as follows.
        // ---
        // Scenario 1:
        // If the price is above the targeted price:
        // - We swap OETH for WETH until the price is equal to the targeted price.
        // - Add liquidity to the pool with the WETH received from the swap.
        // ---
        // Scenario 2:
        // If the price is below the targeted price:
        // - We remove liquidity from the pool
        // - Swap WETH for OETH until the price is equal to the targeted price.
        // - Add liquidity to the pool with the remaining WETH.

        // Get current pool price
        uint256 currentPrice = strategy.getPoolSqrtPrice();
        // Get current range
        (bool isExpectedRange, uint256 wethSharePct) = strategy.checkForExpectedPoolPrice();
        // Get allowed WETH share range
        uint256 allowedWethShareStart = strategy.allowedWethShareStart();
        uint256 allowedWethShareEnd = strategy.allowedWethShareEnd();
        // Get targeted WETH share rounded
        // Note: allowedWethShareStart ∈ [0.01001, 0.45000]
        //       allowedWethShareEnd   ∈ [0.60000, 0.94999]
        uint16 lowerBound = (allowedWethShareStart / 0.01 ether).toUint16(); // ∈ [1, 45]
        uint16 upperBound = (allowedWethShareEnd / 0.01 ether).toUint16() - 1; // ∈ [60, 94]
        _targetWethShare = _bound(_targetWethShare, lowerBound, upperBound).toUint16(); // ∈ [1, 94]
        uint256 targetWethShare = _targetWethShare;
        targetWethShare = (targetWethShare == 1 ? 0.01001 ether : targetWethShare * 0.01 ether);
        // To avoid too small rebalances, we only rebalance if abs(targetWethShare - wethSharePct) > 0.03 ether
        // i.e. 3% target share difference
        vm.assume(targetWethShare.absDiff(wethSharePct) > inv.MIN_WETH_SHARES_FOR_REBALANCE * 0.01 ether);

        // Get current active tick
        int32 activeTick = pool.getState().activeTick;
        vm.assume(activeTick == -1);
        // Get liquidity in active tick
        uint256 reserveA = pool.getTick(activeTick).reserveA;
        uint256 reserveB = pool.getTick(activeTick).reserveB;
        console.log("Current WETH share: %s", wethSharePct);
        console.log("Target WETH share : %s", targetWethShare);

        // Scenario 1: Price is above the targeted price
        if (wethSharePct > targetWethShare) {
            // We need to swap OETH for WETH
            // At the targeted price we have A / (A + B) = targetWethShare
            // We need calculate the amount of OETH to swap to reach the targeted price
            // i.e. (A - x) / ((A - x) + (B + x)) = targetWethShare (assuming 1:1 swap)
            // Rearranging gives us:
            // x = A - targetWethShare * (A + B)
            // Note: as we mint OETH, there should be no situation where reserveA are too big.
            uint256 amountToSwap = reserveA - targetWethShare.mulWad(reserveA + reserveB);
            console.log(
                "User: Vault -> rebalance() \t\t\t AmountToSwap: %s  CurrentWethShare: %s  TargetWethShare: %s ",
                amountToSwap,
                wethSharePct,
                targetWethShare
            );

            vm.prank(governor);
            strategy.rebalance({
                _amountToSwap: amountToSwap,
                _swapWeth: false,
                _minTokenReceived: 0,
                _liquidityToRemovePct: 0
            });

            pool.getTick(activeTick).reserveA;

            // Swap OETH for WETH
        } else {
            (uint256 wethPosition, uint256 oethPosition) = strategy.getPositionPrincipal();
            vm.assume(wethPosition > 1e12);
            // We need to remove liquidity from the pool before swapping WETH for OETH
            // For the sake of simplicity, we will 99% of the liquidity in the active tick
            uint256 p = 0.95 ether; // 99%

            // Calculate how big we are on this tick
            uint256 s = (wethPosition + oethPosition).divWad(reserveA + reserveB);
            uint256 r = targetWethShare;
            console.log("S: %s  R: %s", s, r);

            vm.assume(r * (reserveA + reserveB) >= reserveA);
            uint256 x = ((1 ether ** 2 - (s * p)) / 1e18).mulWad(r * (reserveA + reserveB) - reserveA) / 1e18;

            console.log("Check: ", p * s * reserveA / 1e36, " <= ", x.faa());
            revert("gnegne");
            vm.assume(x <= p * s * reserveA / 1e36);

            console.log(
                "User: Vault -> rebalance() \t\t\t AmountToSwap: %s  CurrentWethShare: %s  TargetWethShare: %s ",
                x,
                wethSharePct,
                targetWethShare
            );

            vm.prank(governor);
            strategy.rebalance({_amountToSwap: x, _swapWeth: true, _minTokenReceived: 0, _liquidityToRemovePct: p});
            pool.getTick(activeTick);
            revert("jjj");
        }
    }
}
