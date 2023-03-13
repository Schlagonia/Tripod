// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract UnwindTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testWithdrawLpManually(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);
        assertEq(tripod.balanceOfPool(), 0);

        skip(7 hours);

        uint256 lpBalance = tripod.totalLpBalance(); 
        
        vm.prank(gov);
        tripod.manualWithdraw(lpBalance / 2);

        assertEq(tripod.totalLpBalance(), lpBalance);
        assertEq(tripod.balanceOfPool(), lpBalance / 2);

    }

    function testManualLiquidate(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);

        uint256 lpBalance = tripod.totalLpBalance(); 

        vm.prank(gov);
        tripod.manualWithdraw(lpBalance / 2);

        vm.prank(gov);
        tripod.burnLiquidityManually(
            lpBalance / 2,
            (deposited[0] /2) * 9_900 / 10_000,
            (deposited[1] / 2) * 9_900 / 10_000,
            (deposited[2] / 2) * 9_900 / 10_000
        );

        assertEq(tripod.balanceOfPool(), 0, "balance of pool off");
        assertGt(tripod.balanceOfStake(), 0);
        assertEq(tripod.balanceOfStake(), tripod.totalLpBalance());
        assertGt(tripod.balanceOfA(), 0, "A balance");
        assertGt(tripod.balanceOfC(), 0, "c balance");
        assertGt(tripod.balanceOfB(), 0, "b balance");

        // Make sure we can still harvest after
        vm.prank(keeper);
        tripod.harvest();

        assertEq(tripod.balanceOfA(), 0, "A balance");
        assertEq(tripod.balanceOfB(), 0, "b balance");
        assertEq(tripod.balanceOfC(), 0, "c balance");
        assertRelApproxEq(assetFixtures[0].strategy.balanceOfWant(), deposited[0], DELTA);
        assertRelApproxEq(assetFixtures[1].strategy.balanceOfWant(), deposited[1], DELTA);
        assertRelApproxEq(assetFixtures[2].strategy.balanceOfWant(), deposited[2], DELTA);
    }


    function testTripodSweepLPToken(uint256 _amount) public  {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        IERC20 toSweep = IERC20(tripod.pool());
        uint256 beforeBalance = toSweep.balanceOf(gov);
        
        uint256 lpBalance = tripod.totalLpBalance(); 
        uint256 amount = lpBalance / 2;
        vm.prank(gov);
        tripod.manualWithdraw(amount);

        vm.prank(gov);
        tripod.sweep(address(toSweep));
        assertEq(
            toSweep.balanceOf(gov),
            amount + beforeBalance
            );
    }

}