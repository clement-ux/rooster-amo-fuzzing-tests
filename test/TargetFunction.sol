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
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

abstract contract TargetFunction is Properties {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                            ✦✦✦ AMO FUNCTIONS ✦✦✦                             ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [x] SetAllowedPoolWethShareInterval
    // [x] Deposit
    // [x] Withdraw
    // [x] Rebalance

    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                      ✦✦✦ MAVERICK V2 POOL FUNCTIONS ✦✦✦                      ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [x] Swap (Pool)
    // [x] MintPositionNft (Liquidity Manager)
    // [x] RemoveLiquidityToSender (Position Manager)

    using Math for uint256;
    using Views for RoosterAMOStrategy;
    using Logger for uint80;
    using Logger for uint96;
    using Logger for int32[];
    using Logger for uint256;
    using LibString for int32;
    using LibString for string;
    using SafeCastLib for int256;
    using SafeCastLib for uint96;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint16;
    using FixedPointMathLib for uint256;

    function handler_setAllowedPoolWethShareInterval(uint96 _start, uint96 _end) public {
        // We don't want to call this too often, because deposit is sensitive to the allowed WETH share range.
        // So after we rebalance we should be able to deposit. But if we call this too often, we might
        // end up with a range that is too small to deposit and thus deposit will happen less often.
        // The allowed share is not expected to change often, so we can reduce the number of calls to this function.
        vm.assume(_start % 100 >= 80); // 25% chance to call the function

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

    function handler_swap(bool _wethIn, uint96 _amount) public {
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
        (uint256 amountIn, uint256 _amountOut,) = quoter.calculateSwap({
            pool: IMaverickV2Pool(address(pool)),
            amount: amountOut.toUint128(),
            tokenAIn: _wethIn,
            exactOutput: true,
            tickLimit: _wethIn ? inv.TICK_LIMIT : -inv.TICK_LIMIT
        });
        amountOut = _amountOut; // Use the amountOut from the quote

        // If tokenIn is WETH, we need to deal it to the swapper.
        // If tokenIn is OETH, we assume that the swapper has enough OETH to swap.
        // Because minting OETH is against the logic of the AMO.
        if (tokenIn == weth) {
            MockERC20(address(weth)).mint(swapper, amountIn);
        } else {
            amountIn = Math.min(amountIn, oeth.balanceOf(swapper));
        }

        string memory log = LibString.concat("User: ", vm.getLabel(swapper)).concat(
            " -> swap() \t\t\t\t AmountIn: %s  AmountOut: %s  TokenIn: %s"
        );
        if (inv.LOG) {
            console.log(log, amountIn.faa(), amountOut.faa(), _wethIn ? "WETH" : "OETH");
        }

        vm.assume(amountIn > 0);

        vm.startPrank(swapper);
        // Swapper send token to the pool and swap
        tokenIn.transfer(address(pool), amountIn);
        pool.swap({
            recipient: swapper,
            params: IMaverickV2Pool.SwapParams({
                amount: amountIn.toUint128(),
                tokenAIn: _wethIn,
                exactOutput: false,
                tickLimit: _wethIn ? inv.TICK_LIMIT : -inv.TICK_LIMIT
            }),
            data: hex""
        });
        vm.stopPrank();
    }

    function handler_deposit(uint80 _amount) public {
        _amount = _amount == 0 ? 1 : _amount; // Bound to be at least 1

        // Check if the pool price is in the expected range
        (bool isExpectedRange, uint256 wethSharePct) = strategy.checkForExpectedPoolPrice();
        // Depositing when the pool price is not in the expected range does not make sense.
        // As we will only send WETH to the strategy and do nothing with it, waiting for the
        // next deposit call is in expected range.
        vm.assume(isExpectedRange);

        uint256 balance = weth.balanceOf(address(vault));

        // Give WETH to the vault
        if (balance < _amount) {
            // Mint WETH to the vault
            MockERC20(address(weth)).mint(address(vault), _amount - balance);
        }
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

    function handler_rebalance(uint16 _targetWethShare) public {
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
        // - Calcul how many token there is between the current price and the targeted price.
        // - We swap OETH for WETH until the price is equal to the targeted price.
        // - Add liquidity to the pool with the WETH received from the swap.
        // ---
        // Scenario 2:
        // If the price is below the targeted price:
        // - Calcul how many token there is between the current price and the targeted price.
        // - We remove liquidity from the pool
        // - Swap WETH for OETH until the price is equal to the targeted price.
        // - Add liquidity to the pool with the remaining WETH.

        // Get current range
        (, uint256 wethSharePct) = strategy.checkForExpectedPoolPrice();
        // Get allowed WETH share range
        uint256 allowedWethShareStart = strategy.allowedWethShareStart();
        uint256 allowedWethShareEnd = strategy.allowedWethShareEnd();
        // Get targeted WETH share rounded
        // Note: allowedWethShareStart ∈ [0.01001, 0.45000]
        //       allowedWethShareEnd   ∈ [0.60000, 0.94999]
        uint16 lowerBound = (allowedWethShareStart / 0.01 ether).toUint16(); // ∈ [1, 45]
        uint16 upperBound = (allowedWethShareEnd / 0.01 ether).toUint16() - 1; // ∈ [60, 94]
        _targetWethShare = _bound(_targetWethShare, lowerBound, upperBound).toUint16(); // ∈ [1, 94]
        uint256 targetWethShare = _targetWethShare; // Convert to uint256 to avoid overflow
        targetWethShare = (targetWethShare == 1 ? 0.01001 ether : targetWethShare * 0.01 ether);
        // Because `getAmountOfTokenBetweenPrices()` expects price a bit too low, the rebalance can be a bit too low too.
        // If the targted share is too close from allowedWethShareStart or allowedWethShareEnd, rebalance might fail.
        // So if the diff between targetWethShare and allowedWethShareStart is below 0.1% (0.001 ether),
        // we add a bit to the targetWethShare to avoid too low rebalances.
        // And if the diff betweallowedWethShareEnd and targetWethShare is below 0.1% (0.001 ether),
        // we subtract a bit to the targetWethShare to avoid too high rebalances.
        // Adjust targetWethShare if it's too close to the allowed bounds
        targetWethShare = targetWethShare < allowedWethShareStart + inv.MIN_WETH_SHARES_DIFFERENCE
            ? targetWethShare + inv.MIN_WETH_SHARES_DIFFERENCE
            : (
                targetWethShare > allowedWethShareEnd - inv.MIN_WETH_SHARES_DIFFERENCE
                    ? targetWethShare - inv.MIN_WETH_SHARES_DIFFERENCE
                    : targetWethShare
            );

        // To avoid too small rebalances, we only rebalance if abs(targetWethShare - wethSharePct) > 0.03 ether
        // i.e. 3% target share difference
        vm.assume(targetWethShare.absDiff(wethSharePct) > inv.MIN_WETH_SHARES_FOR_REBALANCE * 0.01 ether);

        //console.log("Current WETH share: %s", wethSharePct);
        //console.log("Target WETH share : %s", targetWethShare);

        uint256 targetPrice = Views.convertWethSharesIntoPrice(targetWethShare);
        // Scenario 1: Price is above the targeted price
        if (wethSharePct > targetWethShare) {
            // Calcul the amount of WETH between the current price and the targeted price
            (uint256 amountA, uint256 amountB) = Views.getAmountOfTokenBetweenPrices(pool, registeredTicks, targetPrice);
            require(amountA > 0, "WETH should be swapped");
            require(amountB == 0, "No OETH to swap");

            // Quote amountIn needed to swap for amountOut
            (uint256 amountIn,,) = quoter.calculateSwap({
                pool: IMaverickV2Pool(address(pool)),
                amount: amountA.toUint128(),
                tokenAIn: false,
                exactOutput: true,
                tickLimit: -100
            });

            console.log(
                "User: Vault -> rebalance() \t\t\t\t AmountTo: %s  Current  : %s  Target : %s ",
                amountA.faa(),
                wethSharePct.faa(),
                targetWethShare.faa()
            );

            // Main call
            vm.prank(governor);
            try strategy.rebalance({
                _amountToSwap: amountIn,
                _swapWeth: false, // Swap OETH for WETH
                _minTokenReceived: 0, // No min token received as we are swapping OETH for WETH
                _liquidityToRemovePct: 0 // No liquidity to remove
            }) {} catch Error(string memory reason) {
                // In some scenarios, the rebalance can be unprofitable to the AMO, which can lead to insolvency.
                // In this case, we assume that the rebalance is not possible and we revert.
                console.log("Rebalance failed, reason: %s", reason);
                if (!reason.eq("Protocol insolvent")) {
                    console.log("Rebalance failed with reason: %s", reason);
                    revert("Rebalance failed but not due to insolvency");
                }
            }
        } else {
            // As we will remove 95% of our liquidity, we need to account how much OETH less we will have to extract.
            (uint256 amoReserveA, uint256 amoReserveB) = strategy.getPositionPrincipal();
            uint256 removeLiquidityPct = inv.LIQUIDITY_TO_REMOVE_PCT;
            (amoReserveA, amoReserveB) =
                (amoReserveA.mulWad(removeLiquidityPct), amoReserveB.mulWad(removeLiquidityPct));

            // Calcul the amount of OETH between the current price and the targeted price (AMO position included)
            (uint256 amountA, uint256 amountB) =
                Views.getAmountOfTokenBetweenPrices(pool, registeredTicks, targetPrice, true, amoReserveA, amoReserveB);
            require(amountA == 0, "No WETH to swap");
            require(amountB > 0, "OETH should be swapped");

            // Quote amountIn needed to swap for amountOut
            (uint256 amountIn,,) = quoter.calculateSwap({
                pool: IMaverickV2Pool(address(pool)),
                amount: amountB.toUint128(),
                tokenAIn: true,
                exactOutput: true,
                tickLimit: 100
            });

            // Log data
            console.log(
                "User: Vault -> rebalance() \t\t\t\t AmountTo: %s  Current  : %s  Target : %s ",
                amountB.faa(),
                wethSharePct.faa(),
                targetWethShare.faa()
            );

            // Ensure that we have enough WETH to swap
            vm.assume(amoReserveA.mulWad(removeLiquidityPct) >= amountIn);

            // Main call
            vm.prank(governor);
            try strategy.rebalance({
                _amountToSwap: amountIn,
                _swapWeth: true, // Swap WETH for OETH
                _minTokenReceived: 0, // No min token received as we are swapping WETH for OETH
                _liquidityToRemovePct: removeLiquidityPct // Remove 95% of our liquidity
            }) {} catch Error(string memory reason) {
                // In some scenarios, the rebalance can be unprofitable to the AMO, which can lead to insolvency.
                // In this case, we assume that the rebalance is not possible and we revert.
                console.log("Rebalance failed, reason: %s", reason);
                if (!reason.eq("Protocol insolvent")) {
                    console.log("Rebalance failed with reason: %s", reason);
                    revert("Rebalance failed but not due to insolvency");
                }
            }
        }
    }

    function handler_withdraw(uint8 withdrawAll, uint96 amountToWithdraw) public {
        // As withdrawAll do a lot of thing and remove all the liquidity, we should not call it too often.
        // So we will only call it 20% of the time.
        if (withdrawAll % 10 >= 8) {
            // Withdraw all
            console.log("User: Vault -> withdrawAll()");

            vm.prank(address(vault));
            strategy.withdrawAll();
        } else {
            (uint256 amount,) = strategy.getPositionPrincipal();
            // Bound amount to withdraw between 0 and the amount of OETH in the AMO position

            vm.assume(amount != 0);
            amountToWithdraw = _bound(amountToWithdraw, 1, amount.toUint96()).toUint96();

            if (inv.LOG) {
                console.log("User: Vault -> withdraw() \t\t\t\t AmountTo: %s", uint256(amountToWithdraw).faa());
            }

            // Main call
            vm.prank(address(vault));
            strategy.withdraw({_recipient: address(vault), _asset: address(weth), _amount: amountToWithdraw});
        }
    }

    function handler_mintPositionNft(int32 tick, uint96 wethAmount, uint96 oethAmount) public {
        // ---
        // Mint position NFT
        // ---

        // Get random ticks
        int32[] memory ticks = new int32[](1);
        ticks[0] = _bound(tick, -10, 10).toInt32();

        wethAmount = _bound(wethAmount, 1e10, 1e21).toUint96(); // Bound between 0.01 and 1M WETH

        int32 activeTick = pool.getState().activeTick;
        IMaverickV2Pool.AddLiquidityParams[] memory addParams = new IMaverickV2Pool.AddLiquidityParams[](ticks.length);

        uint256 amountA;
        uint256 amountB;
        IMaverickV2Pool.AddLiquidityParams memory addParam;
        // It is better to splt it between when we have to add OETH or not.
        // Because if we don't need to add OETH, we can just mint enough WETH.
        if (ticks[0] < activeTick) {
            // In this situation, the tick can receive only WETH.
            (amountA,, addParam) = Views.getAddLiquidityParams(
                Views.AddLiquidityParams({
                    pool: pool,
                    quoter: quoter,
                    maxWETH: wethAmount,
                    maxOETH: 2,
                    tick: ticks[0],
                    bin: 0
                })
            );
        } else if (ticks[0] >= activeTick) {
            uint256 balance = oeth.balanceOf(swappers[0]).toUint96();
            vm.assume(balance > 1e10);
            oethAmount = _bound(oethAmount, 1e10, balance).toUint96(); // Bound between 0.01 and balance OETH
            // In this situation, the tick can receive only OETH.
            (amountA, amountB, addParam) = Views.getAddLiquidityParams(
                Views.AddLiquidityParams({
                    pool: pool,
                    quoter: quoter,
                    maxWETH: wethAmount,
                    maxOETH: oethAmount,
                    tick: ticks[0],
                    bin: 0
                })
            );
        }
        MockERC20(address(weth)).mint(swappers[0], amountA);
        require(amountB <= oethAmount, "Amount B should be less than or equal to oethAmount");
        addParams[0] = addParam;

        if (inv.LOG) {
            console.log(
                "User: Clark -> mintPositionNft() \t\t\t AmountA : %s  AmountB  : %s  AtTick: %s",
                amountA.faa(),
                amountB.faa(),
                ticks[0].toString()
            );
        }

        vm.startPrank(swappers[0]);
        weth.approve(address(liquidityManager), type(uint256).max);
        oeth.approve(address(liquidityManager), type(uint256).max);
        (,,, uint256 positionId) = liquidityManager.mintPositionNft(
            pool,
            swappers[0],
            liquidityManager.packUint88Array(new uint88[](1)),
            liquidityManager.packAddLiquidityArgsArray(addParams)
        );
        positionIds.push(positionId);
        vm.stopPrank();
    }

    function handler_removeLiquidity(uint16 index, bool removeHalf) public {
        // First we get the id of the position NFT we want to remove liquidity from.
        // If there are no position NFTs, return early.
        uint256 positions = positionIds.length;
        vm.assume(positions > 0);
        index = _bound(index, 0, positions - 1).toUint16(); // Bound id to be between 0 and positions - 1
        uint256 positionId = positionIds[index];

        // Find a random percentage to remove liquidity
        uint256 pctToRemoveWad = removeHalf ? 0.5 ether : 1 ether;

        if (inv.LOG) {
            console.log(
                "User: Clark -> removeLiquidity() \t\t\t PctToRem: %s  Id       : %s  ",
                pctToRemoveWad.faa(),
                positionId
            );
        }

        // Remove liquidity from the position NFT
        vm.startPrank(swappers[0]);
        //position.approve(address(position), positionId);
        position.removeLiquidityToSender(positionId, pool, position.getRemoveParams(positionId, 0, pctToRemoveWad));
        vm.stopPrank();

        if (!removeHalf) Views.removeFromList(positionIds, positionId);
    }
}
