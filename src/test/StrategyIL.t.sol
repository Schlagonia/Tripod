// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../interfaces/Vault.sol";
import {StrategyParams} from "../interfaces/Vault.sol";

import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";

contract StrategyILTest is StrategyFixture {
    using SafeERC20 for IERC20;

    IBalancerVault internal constant balancerVault = 
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    
    //Struct for each bb pool that makes up the main pool
    struct PoolInfo {
        address token;
        address bbPool;
        bytes32 poolId;
    }
    //Array of all 3 provider tokens structs
    PoolInfo[3] internal poolInfo;
    //Mapping of provider token to PoolInfo struct
    mapping(address => PoolInfo) internal poolInfoMapping;
    //The main Balancer Pool Id
    bytes32 internal poolId;
    address pool;


    // setup is run on before each test
    function setUp() public override {
        // setup vault
        super.setUp();
    }

    function setUpBalancer() internal {
        pool = tripod.pool();
        poolId = IBalancerPool(pool).getPoolId();
        //Set array of pool Infos's for each token
        poolInfo[0] = getBalancerPoolInfo(tripod.tokenA());
        poolInfo[1] = getBalancerPoolInfo(tripod.tokenB());
        poolInfo[2] = getBalancerPoolInfo(tripod.tokenC());
    }

    function getBalancerPoolInfo(address _token) internal returns (PoolInfo memory _poolInfo) {
        (IERC20[] memory _tokens, , ) = balancerVault.getPoolTokens(poolId);
        for(uint256 i; i < _tokens.length; i ++) {
            IBalancerPool _pool = IBalancerPool(address(_tokens[i]));
            
            //We cant call getMainToken on the main pool
            if(pool == address(_pool)) continue;
            
            if(_token == _pool.getMainToken()) {
                _poolInfo = PoolInfo(
                    _token,
                    address(_pool),
                    _pool.getPoolId()
                );
                poolInfoMapping[_token] = _poolInfo;
                return _poolInfo;
            }
        }

        //If we get here we do not have the correct pool
        revert("No pool index");
    }

    function getFundManagement() internal view returns (IBalancerVault.FundManagement memory fundManagement) {
        fundManagement = IBalancerVault.FundManagement(
                user,
                false,
                payable(user),
                false
            );
    }

    /// Test Operations
    function testSwaps(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < 1_000_000e18);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);
        
        setUpBalancer();
        skip(1);
        vm.startPrank(user);
        uint256 index = _amount % 3;
        address _want = address(assetFixtures[index].want);
        IERC20(_want).safeApprove(address(balancerVault), type(uint256).max);
        _amount = _amount / 6 / (10 **(18 - IERC20Extended(_want).decimals()));
        //Make 10 swaps to simulate IL caused by swaps
        for( uint256 i; i < 5; ++i) {
            uint256 j = _amount % 2 + 1;
            address _tokenTo = address(assetFixtures[(index + j) % 3].want);
            assertTrue(_want != _tokenTo);
            deal(_want, user, _amount);

            IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](3);
            PoolInfo memory _fromPoolInfo = poolInfoMapping[_want];
            PoolInfo memory _toPoolInfo = poolInfoMapping[_tokenTo];
            //Sell tokenFrom -> bb-tokenFrom
            swaps[0] = IBalancerVault.BatchSwapStep(
                _fromPoolInfo.poolId,
                0,
                1,
                _amount,
                abi.encode(0)
            );
        
            //bb-tokenFrom -> bb-tokenTo
            swaps[1] = IBalancerVault.BatchSwapStep(
                poolId,
                1,
                2,
                0,
                abi.encode(0)
            );

            //bb-tokenTo -> tokenTo
            swaps[2] = IBalancerVault.BatchSwapStep(
                _toPoolInfo.poolId,
                2,
                3,
                0,
                abi.encode(0)
            );

            //Match the token address with the desired index for this trade
            IAsset[] memory assets = new IAsset[](4);
            assets[0] = IAsset(_want);
            assets[1] = IAsset(_fromPoolInfo.bbPool);
            assets[2] = IAsset(_toPoolInfo.bbPool);
            assets[3] = IAsset(_tokenTo);
        
            //Only min we need to set is for the balance going in
            int[] memory limits = new int[](4);
            limits[0] = int(_amount);
            
            balancerVault.batchSwap(
                IBalancerVault.SwapKind.GIVEN_IN, 
                swaps, 
                assets, 
                getFundManagement(), 
                limits, 
                block.timestamp
            );
            skip(1);
            
        }
        vm.stopPrank();

        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();

        (uint256 aRatio, uint256 bRatio, uint256 cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
        //vm.prank(gov);
        //tripod.setDontInvestWant(true);

        //Make sure exess IL didnt have major impacts and the rebalance quote works
        assertRelApproxEq( _a, deposited[0], DELTA);
        assertRelApproxEq(_b, deposited[1], DELTA);
        assertRelApproxEq( _c, deposited[2], DELTA);

        vm.prank(keeper);
        tripod.harvest();

        uint256 aProfit = assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault));
        uint256 bProfit = assetFixtures[1].want.balanceOf(address(assetFixtures[1].vault));
        uint256 cProfit = assetFixtures[2].want.balanceOf(address(assetFixtures[2].vault));

        ( aRatio, bRatio, cRatio) = tripod.getRatios(
            aProfit + deposited[0],
            bProfit + deposited[1],
            cProfit + deposited[2]
        );
        console.log("A ratio ", aRatio, " profit was ", aProfit);
        console.log("B ratio ", bRatio, " profit was ", bProfit);
        console.log("C ratio ", cRatio, " profit was ", cProfit);
  
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
    }
}
