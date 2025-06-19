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
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = this.handler_swap.selector;
        selectors[1] = this.handler_setAllowedPoolWethShareInterval.selector;
        selectors[2] = this.handler_deposit.selector;
        selectors[3] = this.handler_rebalance.selector;
        selectors[4] = this.handler_withdraw.selector;
        selectors[5] = this.handler_mintPositionNft.selector;
        selectors[6] = this.handler_removeLiquidity.selector;

        // Target selectors
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
        targetSender(makeAddr("FuzzerSender"));
    }

    function invariant() public view {
        vm.assertTrue(property_C(), "Invariant property_C failed");
    }
}
