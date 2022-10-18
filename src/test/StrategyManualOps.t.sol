// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract ManualOpsTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testManuallClosePosition(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        tripod.liquidatePositionManually(
            _a * 9_900 / 10_000,
            _b * 9_900 / 10_000,
            _c * 9_900 / 10_000
        );
        

        assertEq(tripod.balanceOfPool(), 0, "Pool balance not 0");
        assertEq(tripod.balanceOfStake(), 0, "staked balance not 0");
        assertGt(tripod.balanceOfA(), 0, "A balance is 0");
        assertGt(tripod.balanceOfC(), 0, "C balance is 0");
        assertGt(tripod.balanceOfB(), 0, "B balance is 0");
    }

    function testManualLiquidate(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);

        uint256 lpBalance = tripod.totalLpBalance(); 
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        tripod.removeLiquidityManually(
            (_a /2) * 9_900 / 10_000,
            (_b / 2) * 9_900 / 10_000,
            (_c / 2) * 9_900 / 10_000
        );

        assertEq(tripod.balanceOfPool(), 0, "balance of pool off");
        assertEq(tripod.balanceOfStake(), 0);
        assertGt(tripod.balanceOfA(), 0, "A balance");
        assertGt(tripod.balanceOfC(), 0, "c balance");
        assertGt(tripod.balanceOfB(), 0, "b balance");
        assertEq(tripod.invested(tripod.tokenA()), 0, "invested not resset");
    }

    function testManualLiquidateFail(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);

        uint256 lpBalance = tripod.totalLpBalance(); 
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        vm.expectRevert(bytes("min"));
        tripod.removeLiquidityManually(
            _a * 11_000 / 10_000,
            _b * 11_000 / 10_000,
            _c * 11_000 / 10_000
        );
    }

    function testManualRewardSell(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);
        skip(1);
        deal(cvx, address(tripod), 4e18);
        assertEq(IERC20(cvx).balanceOf(address(tripod)), 4e18);

        IERC20 token = IERC20(tokenAddrs["USDC"]);
        uint256 before = token.balanceOf(address(tripod));
        vm.startPrank(management);
        tripod.swapTokenForTokenManually(
            cvx,
            address(token),
            4e18,
            0,
            false
        );

        assertGt(token.balanceOf(address(tripod)), before);
        assertEq(IERC20(cvx).balanceOf(address(tripod)), 0);
    }

    function testReturnFundsManually(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        skip(7 hours);
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        tripod.liquidatePositionManually(
            _a * 9_900 / 10_000,
            _b * 9_900 / 10_000,
            _c * 9_900 / 10_000
        );

        vm.prank(gov);
        tripod.returnLooseToProvidersManually();

        assertEq(tripod.balanceOfA(), 0, "A balance");
        assertEq(tripod.balanceOfB(), 0, "b balance");
        assertEq(tripod.balanceOfC(), 0, "c balance");
        assertRelApproxEq(assetFixtures[0].strategy.balanceOfWant(), deposited[0], DELTA);
        assertRelApproxEq(assetFixtures[1].strategy.balanceOfWant(), deposited[1], DELTA);
        assertRelApproxEq(assetFixtures[2].strategy.balanceOfWant(), deposited[2], DELTA);
    }
    
    function testSetKeeper(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        vm.prank(gov);
        tripod.setKeeper(address(69));

        skip(1);
        setProvidersHealthCheck(false);
        
        vm.prank(keeper);
        vm.expectRevert(bytes("auth"));
        tripod.harvest();

        vm.prank(address(69));
        tripod.harvest();
    }

    function testUpdateRewards(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        skip(1);

        vm.prank(management);
        tripod.updateRewardTokens();
        
        assertEq(tripod.getRewardTokens().length, 2);

    }

    function testChangeToSwapTo(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);
        skip(1);
        deal(cvx, address(tripod), 4e18);
        assertEq(IERC20(cvx).balanceOf(address(tripod)), 4e18);

        vm.prank(address(666));
        vm.expectRevert(bytes("auth"));
        tripod.changeToSwapTo();

        vm.prank(management);
        tripod.changeToSwapTo();

        IERC20 token = IERC20(tokenAddrs["DAI"]);
        uint256 before = token.balanceOf(address(tripod));
        //Swap reward token and make sure it went to dai not usdc
        vm.startPrank(management);
        tripod.swapTokenForTokenManually(
            cvx,
            address(0),
            4e18,
            0,
            false
        );
        vm.stopPrank();

        assertGt(token.balanceOf(address(tripod)), before);
        assertEq(IERC20(cvx).balanceOf(address(tripod)), 0);

        //make sure we can add the dai into an lp token
        uint256 beforeBal = tripod.totalLpBalance();
        vm.prank(management);
        tripod.tend();

        assertGt(tripod.totalLpBalance(), beforeBal);

        //Earn interest
        skip(1 days);
        setProvidersHealthCheck(false);
        //Make sure a normal harvest works
        vm.prank(keeper);
        tripod.harvest();
    }
}