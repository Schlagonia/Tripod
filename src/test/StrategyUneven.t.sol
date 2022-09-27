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

contract StrategyUnevenTest is StrategyFixture {
    using SafeERC20 for IERC20;
    // setup is run on before each test
    function setUp() public override {
        // setup vault
        super.setUp();
    }

    function depositAllVaultsUneven(uint256 _amount) public returns(uint256[3] memory deposited) {
        console.log("Depositing into vaults");

        //pick random want
        uint256 j = _amount % 3;
        console.log("j is ", j);
        
        for(uint8 i = 0; i < assetFixtures.length; ++i) {   
            AssetFixture memory _fixture = assetFixtures[i];
            IERC20 _want = _fixture.want;
            IVault _vault = _fixture.vault;
            //need to change the _amount into equal amounts dependant on the want based on oracle of 1e8
            uint256 toDeposit = _amount * 1e8 / (tokenPrices[_fixture.name] * (10 ** (18 - IERC20Extended(address(_want)).decimals())));
        
            //double the amount to deposit of a random vault
            if(j == i) {
                toDeposit = toDeposit / 2;
            }

            deposit(_vault, user, address(_want), toDeposit);
            deposited[i] = toDeposit;
            assertEq(_want.balanceOf(address(_vault)), toDeposit, "vault deposit failed");
        }

    }

    function depositAllVaultsAndHarvestUneven(uint256 _amount) public returns(uint256[3] memory deposited) {
        deposited = depositAllVaultsUneven(_amount);
        skip(1);
        harvestTripod();
    }

    /// Test Operations
    function testStrategyOperation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvestUneven(_amount);

        assertEq(tripod.invested(address(assetFixtures[0].want)), deposited[0]);
        assertEq(tripod.invested(address(assetFixtures[1].want)), deposited[1]);
        assertEq(tripod.invested(address(assetFixtures[2].want)), deposited[2]);

        skip(1 days);

        vm.prank(gov);
        tripod.setDontInvestWant(true);

        vm.prank(keeper);
        tripod.harvest();
        //Pick a random Strategy to check
        uint256 index = _amount % 3;
        AssetFixture memory fixture = assetFixtures[index];
        IERC20 _want = fixture.want;
        IVault _vault = fixture.vault;

        vm.prank(user);
        _vault.withdraw();

        assertRelApproxEq(_want.balanceOf(user), deposited[index], DELTA);
    }

    function testChangeDebt(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited =  depositAllVaultsAndHarvestUneven(_amount);

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

        depositAllVaultsAndHarvestUneven(_amount);

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

        uint256[3] memory deposited = depositAllVaultsAndHarvestUneven(_amount);

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

    function testProfitableRebalance(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        
        uint256[3] memory deposited = depositAllVaultsAndHarvestUneven(_amount);
        
        skip(1 days);
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);

        //Turn off health check to allow for profit
        setProvidersHealthCheck(false);

        vm.prank(keeper);
        tripod.harvest();
        
        uint256 aProfit = assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault));
        uint256 bProfit = assetFixtures[1].want.balanceOf(address(assetFixtures[1].vault));
        uint256 cProfit = assetFixtures[2].want.balanceOf(address(assetFixtures[2].vault));

        (uint256 aRatio, uint256 bRatio, uint256 cRatio) = tripod.getRatios(
            aProfit + deposited[0],
            bProfit + deposited[1],
            cProfit + deposited[2]
        );
        console.log("A ratio ", aRatio, " profit was ", aProfit);
        console.log("B ratio ", bRatio, " profit was ", bProfit);
        console.log("C ratio ", cRatio, " profit was ", cProfit);

        assertGt(aRatio, 1e18);        
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
        //assertTrue (false);
    }
/*
    function testQuoteRebalanceChangesWithRewards(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        skip(1);

        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();

        (uint256 aRatio, uint256 bRatio, uint256 cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);

        skip(1);
        //earn profit
        deal(cvx, address(tripod), _amount/10);
        deal(crv, address(tripod), _amount/10);
        skip(1);

        ( _a,  _b,  _c) = tripod.estimatedTotalAssetsAfterBalance();

        (uint256 aRatio2, uint256 bRatio2, uint256 cRatio2) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        assertGt(aRatio2, 1e18);
        assertRelApproxEq(aRatio2, bRatio2, DELTA);
        assertRelApproxEq(bRatio2, cRatio2, DELTA);
        assertGt(aRatio2, aRatio);
        assertGt(bRatio2, bRatio);
        assertGt(cRatio2, cRatio);
    }

    function testQuoteRebalance(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvestUneven(_amount);

        skip(1);

        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        console.log("deposited A ", deposited[0], " _a ", _a);
        assertRelApproxEq(deposited[0], _a, DELTA);
        assertRelApproxEq(deposited[1], _b, DELTA);
        assertRelApproxEq(deposited[2], _c, DELTA);

        (uint256 aRatio, uint256 bRatio, uint256 cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );
        console.log("first ratios");
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);

        skip(1);
        //earn profit
        deal(cvx, address(tripod), _amount/10);
        deal(crv, address(tripod), _amount/10);
        skip(1);

        ( _a,  _b,  _c) = tripod.estimatedTotalAssetsAfterBalance();

        ( aRatio,  bRatio,  cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        console.log("A ratio ", aRatio);
        console.log("B ratio ", bRatio);
        console.log("C ratio ", cRatio);

        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
    }

    function testQuoteRebalanceCloseToReal(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvestUneven(_amount);

        skip(1);
        //earn profit
        deal(cvx, address(tripod), _amount/10);
        deal(crv, address(tripod), _amount/10);
        skip(1);

        (uint256 _a, uint256  _b, uint256  _c) = tripod.estimatedTotalAssetsAfterBalance();

        (uint256 aRatio, uint256  bRatio, uint256  cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        console.log("A ratio ", aRatio);
        console.log("B ratio ", bRatio);
        console.log("C ratio ", cRatio);

        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);

        vm.prank(management);
        tripod.setDontInvestWant(true);

        setProvidersHealthCheck(false);

        vm.prank(keeper);
        tripod.harvest();

        //make sure the qoute was accurate. Should under report a bit
        if(assetFixtures[0].strategy.balanceOfWant() + assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault)) < _a) { 
            assertRelApproxEq(assetFixtures[0].strategy.balanceOfWant() + assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault)), _a, DELTA);
        }
        if(assetFixtures[1].strategy.balanceOfWant() + assetFixtures[1].want.balanceOf(address(assetFixtures[1].vault)) < _b) { 
            assertRelApproxEq(assetFixtures[1].strategy.balanceOfWant() + assetFixtures[1].want.balanceOf(address(assetFixtures[0].vault)), _b, DELTA);
        }
        if(assetFixtures[2].strategy.balanceOfWant() + assetFixtures[2].want.balanceOf(address(assetFixtures[2].vault)) < _c) {
            assertRelApproxEq(assetFixtures[2].strategy.balanceOfWant() + assetFixtures[2].want.balanceOf(address(assetFixtures[0].vault)), _c, DELTA);
        }
    }
*/
}
