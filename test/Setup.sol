// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Test imports
import {Base_Test} from "./Base.sol";
import {RegisteredTicks} from "./helpers/RegisteredTicks.sol";
import {InvariantParams as inv} from "./helpers/Constants.sol";
import {DeploymentParams as deploy} from "./helpers/Constants.sol";

// AMO
import {RoosterAMOStrategy} from "@rooster-amo/strategies/plume/RoosterAMOStrategy.sol";
import {RoosterAMOStrategyProxy} from "@rooster-amo/proxies/PlumeProxies.sol";
import {InitializableAbstractStrategy} from "@rooster-amo/utils/InitializableAbstractStrategy.sol";

// Maverick contracts
import {LpReward} from "@rooster-pool/ve33/contracts/LpReward.sol";
import {MaverickV2Pool} from "@rooster-pool/v2-amm/contracts/MaverickV2Pool.sol";
import {MaverickV2Quoter} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Quoter.sol";
import {MaverickV2Factory} from "@rooster-pool/v2-amm/contracts/MaverickV2Factory.sol";
import {MaverickV2Position} from "@rooster-pool/v2-supplemental/contracts/MaverickV2Position.sol";
import {MaverickV2PoolLens} from "@rooster-pool/v2-supplemental/contracts/MaverickV2PoolLens.sol";
import {MaverickV2LiquidityManager} from "@rooster-pool/v2-supplemental/contracts/MaverickV2LiquidityManager.sol";

// Maverick interfaces
import {IFeeRegistry} from "@rooster-pool/v2-common/contracts/interfaces/IFeeRegistry.sol";
import {IMaverickV2Pool} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Pool.sol";
import {ILiquidityRegistry} from "@rooster-pool/v2-common/contracts/interfaces/ILiquidityRegistry.sol";
import {IMaverickV2Factory} from "@rooster-pool/v2-common/contracts/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2BoostedPositionFactory} from
    "@rooster-pool/v2-supplemental/contracts/interfaces/IMaverickV2BoostedPositionFactory.sol";

// Mocks
import {IVault} from "./mocks/IVault.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IWETH9} from "@rooster-pool/v2-supplemental/contracts/paymentbase/IWETH9.sol";
import {MockVault} from "./mocks/MockVault.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

// Solmate and Solady
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";

abstract contract Setup is Base_Test {
    using SafeCastLib for uint16;

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
        _deployContracts();

        // 5. Initialize users and contracts.
        _initalize();
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
        plateform = makeAddr("Plateform");
        poolDistributor = makeAddr("Pool Distributor");
        votingDistributor = makeAddr("Voting Distributor");
        boostedPositionFactory = makeAddr("Boosted Position Factory");
    }

    //////////////////////////////////////////////////////
    /// --- EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////
    function _deployExternal() private {
        vm.startPrank(deployer);

        // Deploy WETH
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        // Deploy OETH
        oeth = new MockERC20("Optimism Ether", "OETH", 18);

        // ---
        // --- Deploy Maverick V2 Related Contracts ---
        // ---
        // Maverick V2 Factory
        factory = new MaverickV2Factory(governor);

        // Maverick V2 Position
        position = new MaverickV2Position(IMaverickV2Factory(address(factory)));

        // Maverick V2 Liquidity Manager
        liquidityManager = new MaverickV2LiquidityManager({
            _factory: IMaverickV2Factory(address(factory)),
            _weth: IWETH9(address(weth)),
            _position: position,
            _boostedPositionFactory: IMaverickV2BoostedPositionFactory(boostedPositionFactory)
        });

        // WETH/OETH Maverick V2 Pool
        pool = MaverickV2Pool(
            address(
                factory.create({
                    fee: deploy.POOL_FEE,
                    tickSpacing: deploy.TICK_SPACING,
                    lookback: deploy.LOOK_BACK_PERIOD,
                    tokenA: IERC20(address(weth)),
                    tokenB: IERC20(address(oeth)),
                    activeTick: deploy.ACTIVE_TICK,
                    kinds: deploy.KINDS
                })
            )
        );

        // Pool Lens
        poolLens = new MaverickV2PoolLens();

        // Quoter
        quoter = new MaverickV2Quoter();

        // LpReward
        lpReward = new LpReward({_authorizedNotifier: address(position)});

        // Register ticks
        registeredTicks = new RegisteredTicks();

        // ---
        // --- End of Maverick V2 Related Contracts ---
        // ---

        // Deploy AMO Strategy Proxy
        strategyProxy = new RoosterAMOStrategyProxy();

        // Deploy Vault
        vault = IVault(
            new MockVault({
                _weth: MockERC20(address(weth)),
                _oeth: MockERC20(address(oeth)),
                _strategy: RoosterAMOStrategy(address(strategyProxy))
            })
        );

        vm.stopPrank();

        // Set the LpReward in the Maverick V2 Position contract
        vm.startPrank(governor);
        position.setLpReward(ILiquidityRegistry(address(lpReward)));
        factory.setProtocolFeeRegistry(IFeeRegistry(address(lpReward)));
        vm.stopPrank();

        // Label all freshly deployed external contracts
        vm.label(address(weth), "WETH");
        vm.label(address(oeth), "OETH");
        vm.label(address(factory), "Maverick V2 Factory");
        vm.label(address(position), "Maverick V2 Position");
        vm.label(address(liquidityManager), "Maverick V2 Liquidity Manager");
        vm.label(address(pool), "WETH/OETH Maverick V2 Pool");
        vm.label(address(poolLens), "Maverick V2 Pool Lens");
        vm.label(address(quoter), "Maverick V2 Quoter");
        vm.label(address(lpReward), "Maverick LpReward");
        vm.label(address(registeredTicks), "Registered Ticks");
        vm.label(address(strategyProxy), "RoosterAMOStrategy Proxy");
        vm.label(address(vault), "OETH Vault");
    }

    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    function _deployContracts() private {
        vm.startPrank(deployer);

        // Deploy AMO Strategy Implementation
        strategy = new RoosterAMOStrategy({
            _stratConfig: InitializableAbstractStrategy.BaseStrategyConfig(plateform, address(vault)),
            _wethAddress: address(weth),
            _oethAddress: address(oeth),
            _liquidityManager: address(liquidityManager),
            _poolLens: address(poolLens),
            _maverickPosition: address(position),
            _maverickQuoter: address(quoter),
            _mPool: address(pool),
            _upperTickAtParity: deploy.UPPER_TICK_AT_PARITY,
            _votingDistributor: votingDistributor,
            _poolDistributor: poolDistributor
        });

        // Initialize the proxy with the strategy address
        strategyProxy.initialize({_logic: address(strategy), _initGovernor: governor, _data: ""});

        vm.stopPrank();

        // Cast the proxy to the strategy type
        strategy = RoosterAMOStrategy(address(strategyProxy));

        // Label all freshly deployed contracts
        vm.label(address(strategy), "RoosterAMOStrategy");
    }

    //////////////////////////////////////////////////////
    /// --- USER ROLE ASSIGNMENT & INITIAL POOL SEEDING
    //////////////////////////////////////////////////////
    function _initalize() private {
        // We will need only one single external user that will LP and swap in the pool.
        // This user will be Alice.

        // ---
        // --- Mint initial AMO's position NFT
        // ---
        // Give the strategy some WETH to mint the initial position, even if not used.
        MockERC20(address(weth)).mint(address(strategy), 1e16); // 0.01 WETH
        vm.prank(governor);
        strategy.mintInitialPosition();

        // ---
        // Set the initial allowed WETH share
        // ---
        vm.prank(governor);
        strategy.setAllowedPoolWethShareInterval({
            _allowedWethShareStart: deploy.INITIAL_ALLOWED_WETH_SHARE_START,
            _allowedWethShareEnd: deploy.INITIAL_ALLOWED_WETH_SHARE_END
        });
    }
}
