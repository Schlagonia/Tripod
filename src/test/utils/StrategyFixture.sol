// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma abicoder v2;

import "forge-std/console.sol";
import {IERC20Extended} from "../../interfaces/IERC20Extended.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExtendedTest} from "./ExtendedTest.sol";
import {Vm} from "forge-std/Vm.sol";
import {IVault} from "../../interfaces/Vault.sol";
import {BalancerTripod} from "../../DEXes/BalancerTripod.sol";
import {BalancerTripodCloner} from "../../DEXes/BalancerTripodCloner.sol";
import {ProviderStrategy} from "../../ProviderStrategy.sol";
import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";

// Artifact paths for deploying from the deps folder, assumes that the command is run from
// the project root.
string constant vaultArtifact = "artifacts/Vault.json";

// Base fixture deploying Vault
contract StrategyFixture is ExtendedTest {
    using SafeERC20 for IERC20;

    struct AssetFixture { // To test multiple assets
        IVault vault;
        ProviderStrategy strategy;
        IERC20 want;
        string name;
    }

    struct Pool {
        address pool;
        address poolToken;
        address rewardsContract;
        string[3] wantTokens;
    }

    Pool public poolUsing;

    BalancerTripodCloner public cloner;
    BalancerTripod public tripod;
    IERC20 public weth;

    address public crv = 0xba100000625a3754423978a60c9317c58a424e3D;
    address public cvx = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;

    string[] public wantTokens;
    AssetFixture[] public assetFixtures;
    Pool[] public pools;
    mapping(address => AssetFixture) public fixture;

    mapping(string => address) public tokenAddrs;
    mapping(string => uint256) public tokenPrices;

    address public gov = 0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52;
    address public user = address(1337);
    address public whale = address(2);
    address public rewards = address(3);
    address public guardian = address(4);
    address public management = address(5);
    address public strategist = address(6);
    address public keeper = address(7);

    address public constant yearnTreasuryVault = 0x93A62dA5a14C80f265DAbC077fCEE437B1a0Efde;

    uint256 public minFuzzAmt = 10 ether; // 10 cents
    // @dev maximum amount of want tokens deposited based on @maxDollarNotional
    uint256 public maxFuzzAmt = 1_000_000 ether; // $1m for each token
    // Used for integer approximation 10**2 == 1%
    uint256 public constant DELTA = 10**2;

    function setUp() public virtual {
        _setTokenPrices();
        _setTokenAddrs();
        //Creates the pools list to choose from what to test
        createPools();

        //Note this index needs to be updated to change what pool we are testing with
        poolUsing = pools[2];

        weth = IERC20(tokenAddrs["WETH"]);
        //console.log("Deploying vaults and providers");
        for (uint8 i = 0; i < poolUsing.wantTokens.length; ++i) {
            string memory _tokenToTest = poolUsing.wantTokens[i];
            IERC20 _want = IERC20(tokenAddrs[_tokenToTest]);

            (address _vault, address _strategy) = deployVaultAndStrategy(
                address(_want),
                gov,
                rewards,
                "",
                "",
                guardian,
                management,
                keeper,
                strategist
            );

            assetFixtures.push(AssetFixture(IVault(_vault), ProviderStrategy(_strategy), _want, _tokenToTest));
            fixture[address(_want)] = assetFixtures[i];

            vm.label(address(_vault), string(abi.encodePacked(_tokenToTest, "Vault")));
            vm.label(address(_strategy), string(abi.encodePacked(_tokenToTest, "Strategy")));
            vm.label(address(_want), _tokenToTest);
        }
        //console.log("Deploying tripod");
        //Deploye Tripod Strategy
        deployTripod(
            address(assetFixtures[0].strategy),
            address(assetFixtures[1].strategy),
            address(assetFixtures[2].strategy),
            address(weth),
            poolUsing.pool,
            poolUsing.poolToken,
            poolUsing.rewardsContract
        );

        //console.log("Setting tripod");
        //Add the tripod to each providor strategy
        setTripod();

        // add more labels to make your traces readable
        vm.label(gov, "Gov");
        vm.label(user, "User");
        vm.label(whale, "Whale");
        vm.label(rewards, "Rewards");
        vm.label(guardian, "Guardian");
        vm.label(management, "Management");
        vm.label(strategist, "Strategist");
        vm.label(keeper, "Keeper");
        vm.label(poolUsing.pool, "Balancer Pool");
        vm.label(poolUsing.rewardsContract, "Aura pool");
    }

    // Deploys a vault
    function deployVault(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management
    ) public returns (address) {
        vm.startPrank(_gov);
        address _vaultAddress = deployCode(vaultArtifact);
        IVault _vault = IVault(_vaultAddress);

        //vm.prank(_gov);
        _vault.initialize(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );

        //vm.prank(_gov);
        _vault.setDepositLimit(type(uint256).max);
        vm.stopPrank();

        return address(_vault);
    }

    function deployTripod(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _poolToken,
        address _rewardsContract
    ) internal {
        cloner = new BalancerTripodCloner(
            _providerA,
            _providerB,
            _providerC,
            _referenceToken,
            _pool,
            _rewardsContract
        );
        tripod = BalancerTripod(cloner.original());
        //console.log("New tripod  created");
        vm.prank(gov);
        tripod.setKeeper(keeper);
    }

    function setTripod() internal {
        for (uint8 i = 0; i < assetFixtures.length; ++i) {
            ProviderStrategy _provider = assetFixtures[i].strategy;

            vm.startPrank(gov);
            _provider.setTripod(address(tripod));
            vm.stopPrank();
        }
    }

    // Deploys a strategy
    function deployStrategy(
        address _vault
    ) public returns (address) {
        ProviderStrategy _strategy = new ProviderStrategy(
            _vault
        );

        return address(_strategy);
    }

    // Deploys a vault and strategy attached to vault
    function deployVaultAndStrategy(
        address _token,
        address _gov,
        address _rewards,
        string memory _name,
        string memory _symbol,
        address _guardian,
        address _management,
        address _keeper,
        address _strategist
    ) public returns (address _vaultAddr, address _strategyAddr) {
        _vaultAddr = deployVault(
            _token,
            _gov,
            _rewards,
            _name,
            _symbol,
            _guardian,
            _management
        );
        IVault _vault = IVault(_vaultAddr);

        vm.prank(_strategist);
        _strategyAddr = deployStrategy(
            _vaultAddr
        );
        ProviderStrategy _strategy = ProviderStrategy(_strategyAddr);

        vm.startPrank(_gov);
        _vault.addStrategy(_strategyAddr, 10_000, 0, type(uint256).max, 1_000);
        vm.stopPrank();

        return (address(_vault), address(_strategy));
    }

    function deposit(
        IVault _vault, 
        address depositer, 
        address _want,
        uint256 amount
    ) internal {
        deal(_want, depositer, amount);

        vm.startPrank(depositer);
        IERC20(_want).safeApprove(address(_vault), amount);
        //skip(1);
        _vault.deposit(amount);
        vm.stopPrank();
    }

    function depositAllVaults(uint256 _amount) public returns(uint256[3] memory deposited) {
        console.log("Depositing into vaults");
        
        for(uint8 i = 0; i < assetFixtures.length; ++i) {   
            AssetFixture memory _fixture = assetFixtures[i];
            IERC20 _want = _fixture.want;
            IVault _vault = _fixture.vault;
            //need to change the _amount into equal amounts dependant on the want based on oracle of 1e8
            uint256 toDeposit = _amount * 1e8 / (tokenPrices[_fixture.name] * (10 ** (18 - IERC20Extended(address(_want)).decimals())));
        
            deposit(_vault, user, address(_want), toDeposit);
            deposited[i] = toDeposit;
            assertEq(_want.balanceOf(address(_vault)), toDeposit, "vault deposit failed");
        }

    }

    function harvestTripod() public {
        //Harvest the Tripod to harvest the providers
        vm.prank(keeper);
        tripod.harvest();
        assertGt(tripod.balanceOfStake(), 0, "HarvestFailed");
    }

    function depositAllVaultsAndHarvest(uint256 _amount) public returns(uint256[3] memory deposited) {
        deposited = depositAllVaults(_amount);
        skip(1);
        harvestTripod();
    }

    function setProvidersHealthCheck(bool check) public {
        for(uint8 i = 0; i < assetFixtures.length; ++i) {
            vm.prank(gov);
            assetFixtures[i].strategy.setDoHealthCheck(check);
        }  
    }

    function createPools() public {
        //TriCrypto
        pools.push(Pool(
            0xD51a44d3FaE010294C616388b506AcdA1bfAAE46,
            0xc4AD29ba4B3c580e6D59105FFf484999997675Ff,
            0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652,
            ["USDT", "WETH", "WBTC"]
        ));
        //3 Pool
        pools.push(Pool(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
            0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490,
            0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8,
            ["USDC", "DAI", "USDT"]
        ));
        // migrated aura contract
        pools.push(Pool(
            0xA13a9247ea42D743238089903570127DdA72fE44,
            address(0),
            0xFb6b1c1A1eA5618b3CfC20F81a11A97E930fA46B,
            ["USDC", "DAI", "USDT"]
        ));
        //new Balancer aa-bb-pool
        pools.push(Pool(
            0xA13a9247ea42D743238089903570127DdA72fE44,
            address(0),
            0x1e9F147241dA9009417811ad5858f22Ed1F9F9fd,
            ["USDC", "DAI", "USDT"]
        ));
        //Old Balancer aa-bb-pool
        pools.push(Pool(
            0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2,
            address(0),
            0xCC2F52b57247f2bC58FeC182b9a60dAC5963D010,
            ["USDC", "DAI", "USDT"]
        ));
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    function _setTokenPrices() internal {
        tokenPrices["WBTC"] = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c).latestAnswer();
        tokenPrices["WETH"] = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestAnswer();
        tokenPrices["YFI"] = 5_000;
        tokenPrices["USDT"] = AggregatorV3Interface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D).latestAnswer();
        tokenPrices["USDC"] = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6).latestAnswer();
        tokenPrices["DAI"] = AggregatorV3Interface(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9).latestAnswer();
    }

}   