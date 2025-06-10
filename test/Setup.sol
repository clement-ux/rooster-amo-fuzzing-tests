// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Test imports
import {Base_Test} from "./Base.sol";
import {DeploymentParams as deploy} from "./helpers/Constants.sol";

// Maverick contracts
import {MaverickV2Pool} from "@rooster-pool/v2-amm/contracts/MaverickV2Pool.sol";
import {MaverickV2Quoter} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Quoter.sol";
import {MaverickV2Factory} from "@rooster-pool/v2-amm/contracts/MaverickV2Factory.sol";
import {MaverickV2Position} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Position.sol";
import {MaverickV2PoolLens} from "@rooster-pool/v2-supplemental/contracts/MaverickV2PoolLens.sol";
import {MaverickV2LiquidityManager} from "@rooster-pool/v2-supplemental/contracts/MaverickV2LiquidityManager.sol";

// Maverick interfaces
import {IMaverickV2Factory} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2BoostedPositionFactory} from
    "@rooster-pool/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPositionFactory.sol";

// Mocks
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IWETH9} from "@rooster-pool/v2-supplemental/contracts/paymentbase/IWETH9.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract Setup is Base_Test {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual {
        // 1. Setup a realistic test environnement.
        _setUpRealisticEnvironnement();

        // 2. Create user.
        _createUsers();

        // 3. Deploy external contracts.
        _deployExternal();

        // 4. Deploy contracts.
        //_deployContracts();

        // 5. Initialize users and contracts.
        //_initiliaze();
    }

    //////////////////////////////////////////////////////
    /// --- ENVIRONMENT
    //////////////////////////////////////////////////////
    function _setUpRealisticEnvironnement() private {
        vm.warp(1750000000);
        vm.roll(23000000);
    }

    //////////////////////////////////////////////////////
    /// --- USERS
    //////////////////////////////////////////////////////
    function _createUsers() private {
        // Random users
        users.push(alice = makeAddr("Alice"));
        users.push(bobby = makeAddr("Bobby"));
        users.push(clark = makeAddr("Clark"));
        users.push(david = makeAddr("David"));
        users.push(elsie = makeAddr("Elsie"));
        users.push(glenn = makeAddr("Glenn"));
        users.push(henry = makeAddr("Henry"));
        users.push(irene = makeAddr("Irene"));
        users.push(jenny = makeAddr("Jenny"));
        users.push(kevin = makeAddr("Kevin"));

        // Permissionned users
        deployer = makeAddr("Deployer");
        governor = makeAddr("Governor");
        operator = makeAddr("Operator");

        // Mocked addresses
        poolDistributor = makeAddr("Pool Distributor");
        votingDistributor = makeAddr("Voting Distributor");
        boostedPositionFactory = makeAddr("Boosted Position Factory");
    }

    //////////////////////////////////////////////////////
    /// --- EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////
    function _deployExternal() private {
        // Deploy OETH
        oeth = new MockERC20("Optimism Ether", "OETH", 18);
        // Deploy WETH
        weth = new MockERC20("Wrapped Ether", "WETH", 18);

        // ---
        // --- Deploy Maverick V2 Related Contracts ---
        // ---
        // Maverick V2 Factory
        factory = new MaverickV2Factory(governor);

        // Maverick V2 Position
        position = new MaverickV2Position(IMaverickV2Factory(address(factory)));

        // Maverick V2 Liquidity Manager
        liquidityManager = new MaverickV2LiquidityManager(
            IMaverickV2Factory(address(factory)),
            IWETH9(address(weth)),
            position,
            IMaverickV2BoostedPositionFactory(boostedPositionFactory)
        );

        // WETH/OETH Maverick V2 Pool
        pool = MaverickV2Pool(
            address(
                factory.create(
                    deploy.POOL_FEE,
                    deploy.TICK_SPACING,
                    deploy.LOOK_BACK_PERIOD,
                    IERC20(address(weth)),
                    IERC20(address(oeth)),
                    deploy.ACTIVE_TICK,
                    deploy.KINDS
                )
            )
        );

        // Pool Lens
        poolLens = new MaverickV2PoolLens();

        // Quoter
        quoter = new MaverickV2Quoter();

        // Label all freshly deployed external contracts
        vm.label(address(oeth), "OETH");
        vm.label(address(weth), "WETH");
        vm.label(address(factory), "Maverick V2 Factory");
        vm.label(address(position), "Maverick V2 Position");
        vm.label(address(liquidityManager), "Maverick V2 Liquidity Manager");
        vm.label(address(pool), "WETH/OETH Maverick V2 Pool");
    }

    function test() public {}
}
