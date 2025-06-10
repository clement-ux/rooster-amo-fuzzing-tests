// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library DeploymentParams {
    // MaverickV2Pool
    uint64 public constant POOL_FEE = 100000000000000; // 0.01%
    uint16 public constant TICK_SPACING = 1;
    uint32 public constant LOOK_BACK_PERIOD = 300;
    int32 public constant ACTIVE_TICK = -1;
    uint8 public constant KINDS = 1;

    // AMO
    bool public constant UPPER_TICK_AT_PARITY = true;
}
