// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Foundry imports
import {console} from "forge-std/console.sol";

// Test imports
import {Logger} from "./helpers/Logger.sol";
import {Properties} from "./Properties.sol";
import {InvariantParams as inv} from "./helpers/Constants.sol";

abstract contract TargetFunction is Properties {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                            ✦✦✦ AMO FUNCTIONS ✦✦✦                             ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [ ] SetAllowedPoolWethShareInterval
    // [ ] Deposit
    // [ ] Withdraw
    // [ ] Rebalance

    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                      ✦✦✦ MAVERICK V2 POOL FUNCTIONS ✦✦✦                      ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [ ] MigrateBinUpStack (not sure if this is needed)
    // [ ] Swap (Pool)
    // [ ] MintPositionNft (Liquidity Manager)
    // [ ] AddPositionLiquidityToSenderByTokenIndex (Liquidity Manager)
    // [ ] RemoveLiquidityToSender (Position Manager)

    function handler_setAllowedPoolWethShareInterval(uint8 _start, uint8 _end) external {
        uint256 start = _bound(_start, 1, 45); // ]1, 45]
        uint256 end = _bound(_end, 60, 95); // [0.60, 0.95[
        uint256 allowedWethShareStart = start == 1 ? 0.01001 ether : start * 0.01 ether;
        uint256 allowedWethShareEnd = end == 95 ? 0.94999 ether : end * 0.01 ether;

        if (inv.LOG) {
            console.log(
                "User: %s -> setAllowedPoolWethShareInterval()\t Start: %s End: %s",
                "gover",
                Logger.uintToFixedString(allowedWethShareStart),
                Logger.uintToFixedString(allowedWethShareEnd)
            );
        }
    }
}
