// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";
import {IVault} from "../interfaces/Vault.sol";

contract RebalanceTest is StrategyFixture {
    using SafeERC20 for IERC20;
    function setUp() public override {
        super.setUp();
    }

    function testProfitableRebalanceOneTwo(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);
        
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

        assertGt(aProfit, 0);
        assertGt(aRatio, 1e18);        
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
    }

    function testProfitableRebalanceTwoToOne(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);
        
        skip(1 days);
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);

        //Turn off health check to allow for profit
        setProvidersHealthCheck(false);
        uint256 j = _amount % 3;
        uint256 k = (_amount + 1) % 3;

        console.log(" j is ", j, "k is ", k);
        //Tip two of the tokens to the tripod to make sure we are using swapTwoToOne
        deal(address(assetFixtures[j].want), address(tripod), deposited[j] / 10);
        deal(address(assetFixtures[k].want), address(tripod), deposited[k] / 10);

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
    }

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
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        skip(1);
        //earn profit
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);
        skip(1);

        (uint256 _a, uint256  _b, uint256  _c) = tripod.estimatedTotalAssetsAfterBalance();

        (uint256 aRatio, uint256  bRatio, uint256  cRatio) = tripod.getRatios(
            _a,
            _b,
            _c
        );

        console.log("A ratio ", aRatio, "_a ", _a);
        console.log("A deposited ", deposited[0]);
        console.log("B ratio ", bRatio, "_b", _b);
        console.log("B deposited ", deposited[1]);
        console.log("C ratio ", cRatio, "_c ", _c);
        console.log("C Deposited ", deposited[2]);
        console.log("avg Ratio ", (aRatio + bRatio + cRatio) / 3);
     
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);

        vm.startPrank(gov);
        tripod.setParamaters(
            true,
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        setProvidersHealthCheck(false);

        vm.prank(keeper);
        tripod.harvest();

        //make sure the qoute was accurate. Should under report a bit
        if(assetFixtures[0].strategy.balanceOfWant() + assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault)) < _a) { 
            assertRelApproxEq(assetFixtures[0].strategy.balanceOfWant() + assetFixtures[0].want.balanceOf(address(assetFixtures[0].vault)), _a, DELTA);
        }
        if(assetFixtures[1].strategy.balanceOfWant() + assetFixtures[1].want.balanceOf(address(assetFixtures[1].vault)) < _b) { 
            assertRelApproxEq(assetFixtures[1].strategy.balanceOfWant() + assetFixtures[1].want.balanceOf(address(assetFixtures[1].vault)), _b, DELTA);
        }
        if(assetFixtures[2].strategy.balanceOfWant() + assetFixtures[2].want.balanceOf(address(assetFixtures[2].vault)) < _c) {
            assertRelApproxEq(assetFixtures[2].strategy.balanceOfWant() + assetFixtures[2].want.balanceOf(address(assetFixtures[2].vault)), _c, DELTA);
        }
        
    }

    function testCloseEnough(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        //Should be true if they are equal
        bool closeEnough = tripod.isCloseEnough(1e18, 1e18);
        assertTrue(closeEnough, "even");
        //should be false if 90% off
        closeEnough = tripod.isCloseEnough(1e18, 1e17);
        assertTrue(!closeEnough, "90%");
        //Should be false if the are 10% off
        closeEnough = tripod.isCloseEnough(11e17, 1e18);
        assertTrue(!closeEnough, "10%");
        //should still be false at .1% off since it is < not  <=
        closeEnough = tripod.isCloseEnough(1e18, 1e18 * 999 / 1_000);
        assertTrue(!closeEnough, ".1%");
        //Should be false if just under .1% since its based on the second input
        closeEnough = tripod.isCloseEnough(1e18, 1e18 * 9_999 / 10_000 + 1);
        assertTrue(!closeEnough, ".1% + 1");
        //should still be false at .1% off since it is < not  <=
        closeEnough = tripod.isCloseEnough(1e18 * 9_999 / 10_000, 1e18);
        assertTrue(!closeEnough, ".1% #2");
        //Should be true if just uner .1%
        closeEnough = tripod.isCloseEnough(1e18 * 9_999 / 10_000 + 1, 1e18);
        assertTrue(closeEnough, ".1% + 1 #2");
        //Should be true if both 0
        closeEnough = tripod.isCloseEnough(0, 0);
        assertTrue(closeEnough, "0's");
        //should be fale if only one is 0
        closeEnough = tripod.isCloseEnough(1e18, 0);
        assertTrue(!closeEnough, "b=0");
        closeEnough = tripod.isCloseEnough(0, 1e18);
        assertTrue(!closeEnough, "a=0");
    }
}