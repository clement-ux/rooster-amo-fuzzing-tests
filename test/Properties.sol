// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Test imports
import {Setup} from "./Setup.sol";

abstract contract Properties is Setup {
    uint256[] public positionIds;
}
