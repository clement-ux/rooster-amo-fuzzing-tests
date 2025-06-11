// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Test imports
import {TargetFunction} from "./TargetFunction.sol";

contract FuzzerFoundry is TargetFunction {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public override {
        super.setUp();

        // --- Setup Fuzzer target ---
        // Setup target
        targetContract(address(this));

        // Add selectors
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = this.handler_swap.selector;
        selectors[1] = this.handler_setAllowedPoolWethShareInterval.selector;
        selectors[2] = this.handler_deposit.selector;

        // Target selectors
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function invariant() public view {}
}
