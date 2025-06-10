// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Foundry
import {Test} from "forge-std/Test.sol";

// AMO
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";
import {RoosterAMOStrategyProxy} from "@rooster-amo/proxies/PlumeProxies.sol";

// Maverick
import {MaverickV2Pool} from "@rooster-pool/v2-amm/contracts/MaverickV2Pool.sol";
import {MaverickV2Quoter} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Quoter.sol";
import {MaverickV2Factory} from "@rooster-pool/v2-amm/contracts/MaverickV2Factory.sol";
import {MaverickV2Position} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Position.sol";
import {MaverickV2PoolLens} from "@rooster-pool/v2-supplemental/contracts/MaverickV2PoolLens.sol";
import {MaverickV2LiquidityManager} from "@rooster-pool/v2-supplemental/contracts/MaverickV2LiquidityManager.sol";

// ERC
import {ERC20} from "@solmate/tokens/ERC20.sol";

abstract contract Base_Test is Test {
    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    // ERC20 tokens
    ERC20 public weth;
    ERC20 public oeth;

    // Maverick contracts
    MaverickV2Pool public pool;
    MaverickV2Quoter public quoter;
    MaverickV2Factory public factory;
    MaverickV2Position public position;
    MaverickV2PoolLens public poolLens;
    MaverickV2LiquidityManager public liquidityManager;

    // AMO contracts
    RoosterAMOStrategy public strategy;
    RoosterAMOStrategyProxy public strategyProxy;

    address public vault;
    address public plateform;
    address public poolDistributor;
    address public votingDistributor;
    address public boostedPositionFactory;

    //////////////////////////////////////////////////////
    /// --- Governance, multisigs and EOAs
    //////////////////////////////////////////////////////
    address[] public lps;
    address[] public users;
    address[] public swappers;

    address public alice;
    address public bobby;
    address public clark;
    address public david;
    address public elsie;
    address public glenn;
    address public henry;
    address public irene;
    address public jenny;
    address public kevin;

    address public deployer;
    address public governor;
    address public operator;
}
