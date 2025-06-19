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

    // Initiale Pool liquidity
    uint128 public constant INITIAL_LIQUIDITY_WETH = 200 ether;
    uint128 public constant INITIAL_LIQUIDITY_OETH = 200 ether;

    // Initiale AMO boundaries
    uint256 public constant INITIAL_ALLOWED_WETH_SHARE_START = 0.05 ether; // 5%
    uint256 public constant INITIAL_ALLOWED_WETH_SHARE_END = 0.9 ether; // 95%
}

library InvariantParams {
    bool public constant LOG = true;

    int32 public constant TICK_LIMIT = 100;

    // Different between current weth share and target weth share allowed to trigger a rebalance
    uint256 public constant LIQUIDITY_TO_REMOVE_PCT = 0.98 ether; // 98%
    uint256 public constant MIN_WETH_SHARES_DIFFERENCE = 0.001 ether; // 0.1%
    uint8 public constant MIN_WETH_SHARES_FOR_REBALANCE = 3; // -> 0.03 ether
}
