// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Foundry imports
import {console} from "forge-std/console.sol";

// Test imports
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

abstract contract TargetFunction is Properties {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                            ✦✦✦ AMO FUNCTIONS ✦✦✦                             ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [x] SetAllowedPoolWethShareInterval
    // [ ] Deposit
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

    using Logger for uint88;
    using Logger for uint256;
    using LibString for string;
    using SafeCastLib for uint256;
    using Views for RoosterAMOStrategy;

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

    function handler_deposit(uint88 _amount) external {
        // Max amount deposited is approx 309,485,009 ether it is huge, but this AMO can be used stable coins
        // It is still huge for stable coins, but if we use uint80, it will be approx 1,208,225, which is not enough
        _amount = _amount == 0 ? 1 : _amount; // Bound to be at least 1
        deal(address(weth), address(vault), _amount);
        (bool isExpectedRange, uint256 wethSharePct) = strategy.checkForExpectedPoolPrice();

        if (inv.LOG) {
            console.log(
                "User: Vault -> deposit() \t\t\t\t Amount\t : %s  WethShare: %s  Expect : %s",
                _amount.faa(),
                wethSharePct.faa(),
                isExpectedRange ? "Yes" : "No"
            );
        }

        vm.startPrank(address(vault));
        weth.transfer(address(strategy), _amount);
        strategy.deposit(address(weth), _amount);
        vm.stopPrank();
    }
}
