// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TargetFunction} from "../TargetFunction.sol";

contract UnitTesting is TargetFunction {
    function test_reproduce_failing() public {
        handler_swap(true, 6025270723882241898);
        handler_deposit(4950982763834371);
        handler_withdraw(2, 1072034846464928);
    }
}
