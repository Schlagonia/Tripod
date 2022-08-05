// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveV1Tripod} from "../DEXes/CurveV1Tripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract RebalanceTest is StrategyFixture {
    using SafeERC20 for IERC20;
    function setUp() public override {
        super.setUp();
    }

    function testProfitableRebalance(uint256 _amount) public {
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

        assertGt(aRatio, 1e18);        
        assertRelApproxEq(aRatio, bRatio, DELTA);
        assertRelApproxEq(bRatio, cRatio, DELTA);
    }

    function testRebalanceOnLoss(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        uint256 _a = tripod.invested(address(assetFixtures[0].want));
        uint256 _b = tripod.invested(address(assetFixtures[1].want));
        uint256 _c = tripod.invested(address(assetFixtures[2].want));

        skip(2 hours);

        vm.startPrank(gov);
        tripod.removeLiquidityManually(
            tripod.totalLpBalance() / 10,
            _a / 11,
            _b / 15,
            _c / 20
        );
        vm.stopPrank();

        vm.startPrank(address(tripod));
        assetFixtures[0].want.safeTransfer(address(gov), tripod.balanceOfA());
        assetFixtures[1].want.safeTransfer(address(gov), tripod.balanceOfB());
        assetFixtures[2].want.safeTransfer(address(gov), tripod.balanceOfC());
        vm.stopPrank();
        //Turn off health check to allow for loss
        setProvidersHealthCheck(false);
        vm.prank(gov);
        tripod.setMaxPercentageLoss(1e17);

        vm.prank(gov);
        tripod.setDontInvestWant(true);

        vm.prank(keeper);
        tripod.harvest();

        uint256 aRatio = (assetFixtures[0].strategy.estimatedTotalAssets() * 1e18) / _a;
        uint256 bRatio = (assetFixtures[1].strategy.estimatedTotalAssets() * 1e18) / _b;
        uint256 cRatio = (assetFixtures[2].strategy.estimatedTotalAssets() * 1e18) / _c;
      
        console.log("A ratio ", aRatio);
        console.log("B ratio ", bRatio);
        console.log("C ratio ", cRatio);

        assertGt(1e18, aRatio);
        assertRelApproxEq(aRatio, bRatio, 10);
        assertRelApproxEq(bRatio, cRatio, 10);
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

}
