// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveV1Tripod} from "../DEXes/CurveV1Tripod.sol";
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
            _a * 9_800 / 10_000,
            _b * 9_800 / 10_000,
            _c * 9_800 / 10_000
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
            lpBalance/ 2,
            (_a / 2) * 9_800 / 10_000,
            (_b / 2) * 9_800 / 10_000,
            (_c / 2) * 9_800 / 10_000
        );

        assertRelApproxEq(tripod.balanceOfStake(), lpBalance / 2, DELTA);
        assertGt(tripod.balanceOfA(), 0, "A balance");
        assertGt(tripod.balanceOfC(), 0, "c balance");
        assertGt(tripod.balanceOfB(), 0, "b balance");
    }

    function testManualLiquidateFail(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);

        uint256 lpBalance = tripod.totalLpBalance(); 
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        vm.expectRevert("Slippage screwed you");
        tripod.removeLiquidityManually(
            lpBalance/ 2,
            (_a /2) * 11_000 / 10_000,
            (_b / 2) * 11_000 / 10_000,
            (_c / 2) * 11_000 / 10_000
        );
    }

    function testManualRewardSell(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);
        skip(1);
        deal(cvx, address(tripod), 4e18);
        assertEq(IERC20(cvx).balanceOf(address(tripod)), 4e18);

        IERC20 swapTo = assetFixtures[_amount % 3].want;

        uint256 beforeBal = swapTo.balanceOf(address(tripod));
        vm.startPrank(management);
        tripod.swapTokenForTokenManually(
            cvx,
            address(swapTo),
            4e18,
            0,
            false
        );

        IERC20 next = assetFixtures[(_amount + 1) % 3].want;

        assertGt(swapTo.balanceOf(address(tripod)), beforeBal);
        //vm.prank(management);
        tripod.swapTokenForTokenManually(
            address(swapTo),
            address(next),
            swapTo.balanceOf(address(tripod)),
            0,
            true
        );

        assertEq(swapTo.balanceOf(address(tripod)), 0);
        assertGt(next.balanceOf(address(tripod)), 0);
    }

    function testReturnFundsManually(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        skip(7 hours);
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        tripod.liquidatePositionManually(
            0,
            0,
            0
        );

        vm.prank(gov);
        tripod.returnLooseToProvidersManually();

        assertEq(tripod.balanceOfA(), 0, "A balance");
        assertEq(tripod.balanceOfB(), 0, "b balance");
        assertEq(tripod.balanceOfC(), 0, "c balance");
    }
    
}
