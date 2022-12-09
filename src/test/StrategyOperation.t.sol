// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveV2Tripod} from "../DEXes/CurveV2Tripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVault} from "../interfaces/Vault.sol";
import {StrategyParams} from "../interfaces/Vault.sol";

contract StrategyOperationsTest is StrategyFixture {
    using SafeERC20 for IERC20;
    // setup is run on before each test
    function setUp() public override {
        // setup vault
        super.setUp();
    }

    /// Test Operations
    function testStrategyOperation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        skip(1 days);

        vm.startPrank(gov);
        tripod.setParamaters(
            true,
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        vm.prank(keeper);
        tripod.harvest();
        //Pick a random Strategy to check
        uint256 index = _amount % 3;
        AssetFixture memory fixture = assetFixtures[index];
        IERC20 _want = fixture.want;
        IVault _vault = fixture.vault;
        ProviderStrategy _strategy = fixture.strategy;

        vm.prank(user);
        _vault.withdraw();

        assertRelApproxEq(_want.balanceOf(user), deposited[index], DELTA);
    }

    function testChangeDebt(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited =  depositAllVaultsAndHarvest(_amount);

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            vm.prank(gov);
            fixture.vault.updateStrategyDebtRatio(address(fixture.strategy), 5_000);
        }

        skip(1);
        vm.prank(keeper);
        tripod.harvest();

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            assertRelApproxEq(fixture.strategy.estimatedTotalAssets(), deposited[i] / 2, DELTA);
        }
        
        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            vm.prank(gov);
            fixture.vault.updateStrategyDebtRatio(address(fixture.strategy), 10_000);
        }
        skip(1);
        vm.prank(keeper);
        tripod.harvest();

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            assertRelApproxEq(fixture.strategy.estimatedTotalAssets(), deposited[i], DELTA);
        }
    }

    function testProfitableHarvest(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        uint256[3] memory bps;
        for(uint256 i; i < assetFixtures.length; i ++) {
            bps[i] = assetFixtures[i].vault.pricePerShare();
        }

        depositAllVaultsAndHarvest(_amount);

        //skip(2 days);
        deal(crv, address(tripod), _amount/10);
        deal(cvx, address(tripod), _amount/10);
        setProvidersHealthCheck(false);
        // Harvest 2: Realize profit
        skip(1);
        vm.prank(keeper);
        tripod.harvest();

        skip(6 hours);

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            IERC20 _want = fixture.want;
            IVault _vault = fixture.vault;
            ProviderStrategy _strategy = fixture.strategy;
            //Make sure we have updated the debt and made a profit
            uint256 vaultBalance = _want.balanceOf(address(_vault));
            StrategyParams memory params = _vault.strategies(address(_strategy));
            //Make sure we got back profit + half the deposit
            assertEq(
                params.totalGain, 
                vaultBalance
            );
            assertGt(_vault.pricePerShare(), bps[i]);
        }
    }
    
    function testProfitableHarvestOnDebtChange(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        uint256[3] memory bps;
        for(uint256 i; i < assetFixtures.length; i ++) {
            bps[i] = assetFixtures[i].vault.pricePerShare();
        }

        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            vm.prank(gov);
            fixture.vault.updateStrategyDebtRatio(address(fixture.strategy), 5_000);
        }

        deal(crv, address(tripod), _amount/10);
        deal(cvx, address(tripod), _amount/10);

        setProvidersHealthCheck(false);
        // Harvest 2: Realize profit
        skip(1);
        vm.prank(keeper);
        tripod.harvest();

        //Make sure we have updated the debt ratio of the strategy
        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            assertRelApproxEq(
                fixture.strategy.estimatedTotalAssets(), 
                deposited[i] / 2, 
                DELTA
            );  
        }

        skip(6 hours);

        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            IERC20 _want = fixture.want;
            IVault _vault = fixture.vault;
            ProviderStrategy _strategy = fixture.strategy;
            //Make sure we have updated the debt and made a profit
            uint256 vaultBalance = _want.balanceOf(address(_vault));
            StrategyParams memory params = _vault.strategies(address(_strategy));
            //Make sure we got back profit + half the deposit
            assertRelApproxEq(
                deposited[i] / 2 + params.totalGain, 
                vaultBalance, 
                DELTA
            );
            assertGt(_vault.pricePerShare(), bps[i]);
        }
    }

    function testSweep(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        //depositAllVaultsAndHarvest(_amount);
        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            IERC20 want = fixture.want;
            IVault vault = fixture.vault;
            ProviderStrategy strategy = fixture.strategy;

            // Strategy want token doesn't work
            deal(address(want), user, _amount);
            vm.startPrank(user);
            want.safeTransfer(address(strategy), _amount);
            vm.stopPrank();
            assertEq(address(want), address(strategy.want()));
            assertGt(want.balanceOf(address(strategy)), 0);

            vm.prank(gov);
            vm.expectRevert("!want");
            strategy.sweep(address(want));

            // Vault share token doesn't work
            vm.prank(gov);
            vm.expectRevert("!shares");
            strategy.sweep(address(vault));

            IERC20 toSweep = IERC20(tokenAddrs["LINK"]);
            uint256 beforeBalance = toSweep.balanceOf(gov);
            uint256 amount = 1 ether;
            deal(address(toSweep), user, amount);
            vm.prank(user);
            toSweep.transfer(address(strategy), amount);
            assertNeq(address(toSweep), address(strategy.want()));
            assertEq(toSweep.balanceOf(user), 0);
            vm.prank(gov);
            strategy.sweep(address(toSweep));
            assertRelApproxEq(
                toSweep.balanceOf(gov),
                amount + beforeBalance,
                DELTA
            );
        }
    } 

    function testTripodSweep(uint256 _amount) public  {
        for(uint256 i; i < assetFixtures.length; i ++) {
            AssetFixture memory fixture = assetFixtures[i];
            IERC20 want = fixture.want;

            deal(address(want), address(tripod), _amount);
        }

        vm.startPrank(gov);
        vm.expectRevert();
        tripod.sweep(address(assetFixtures[0].want));
        vm.expectRevert();
        tripod.sweep(address(assetFixtures[1].want));
        vm.expectRevert();
        tripod.sweep(address(assetFixtures[2].want));
        vm.stopPrank();

        IERC20 toSweep = IERC20(tokenAddrs["LINK"]);
        uint256 beforeBalance = toSweep.balanceOf(gov);
        uint256 amount = 1 ether;
        deal(address(toSweep), address(tripod), amount);

        assertEq(toSweep.balanceOf(user), 0);
        vm.expectRevert(bytes("auth"));
        tripod.sweep(address(toSweep));

        vm.prank(gov);
        tripod.sweep(address(toSweep));
        assertRelApproxEq(
            toSweep.balanceOf(gov),
            amount + beforeBalance,
            DELTA
        );
    }
}
