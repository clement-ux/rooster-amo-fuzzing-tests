// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TickMath} from "@rooster-pool/v2-common/contracts/libraries/TickMath.sol";

contract RegisteredTicks {
    int32 public constant MIN_TICK = -100;
    int32 public constant MAX_TICK = 100;
    uint256[] public pricesByTick; // index = tick - MIN_TICK
    // Stores the tick for an explicitly registered price
    mapping(uint256 => int32) public registeredTicks;

    constructor() {
        // Pre-calculate prices for each tick
        for (int32 tick = MIN_TICK; tick <= MAX_TICK; tick++) {
            pricesByTick.push(priceForTick(tick));
        }
    }

    // To be adapted according to your actual formula
    function priceForTick(int32 tick) public pure returns (uint256) {
        return uint256(TickMath.tickSqrtPrice(1, tick));
    }

    // Register a price with its corresponding tick
    function registerPrice(uint256 price, int32 tick) external {
        registeredTicks[price] = tick;
    }

    // Returns the tick for a given price: if registered, returns directly; otherwise, finds the closest lower tick
    function getTickForPrice(uint256 price) external view returns (int32) {
        int32 registered = registeredTicks[price];
        if (registered != 0 || price == priceForTick(0)) {
            return registered;
        }
        int32 left = MIN_TICK;
        int32 right = MAX_TICK;
        while (left < right) {
            int32 mid = left + (right - left + 1) / 2;
            uint256 midPrice = pricesByTick[uint32(mid - MIN_TICK)];
            if (midPrice <= price) {
                left = mid;
            } else {
                right = mid - 1;
            }
        }
        return left;
    }
}
