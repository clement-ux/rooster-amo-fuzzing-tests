// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Test imports
import {Setup} from "./Setup.sol";

abstract contract Properties is Setup {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                         ✦✦✦ INVARIANT PROPERTIES ✦✦✦                         ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [§] After withdrawAll(): new ETH in vault + OETH burned >= checkBalance before withdrawAll()
    // [§] After deposit(): checkBalance difference (after - before) = WETH deposited + OETH minted

    uint256[] public positionIds;

    function property_C() public view returns (bool) {
        // There should have no OETH in the AMO.
        return oeth.balanceOf(address(strategy)) == 0;
    }
}
