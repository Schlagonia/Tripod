// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveV2Tripod} from "../DEXes/CurveV2Tripod.sol";
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
        //(uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.startPrank(gov);
        tripod.removeLiquidityManually(
            tripod.invested(tripod.tokenA()) * 9_800 / 10_000,
            tripod.invested(tripod.tokenB()) * 9_800 / 10_000,
            tripod.invested(tripod.tokenC()) * 9_800 / 10_000
        );
        vm.stopPrank();

        assertEq(tripod.balanceOfPool(), 0, "balance of pool off");
        assertEq(tripod.balanceOfStake(), 0);
        assertGt(tripod.balanceOfA(), 0, "A balance");
        assertGt(tripod.balanceOfC(), 0, "c balance");
        assertGt(tripod.balanceOfB(), 0, "b balance");
        assertEq(tripod.invested(tripod.tokenA()), 0, "still invested");
    }

    function testManualLiquidateFail(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        assertGt(tripod.balanceOfStake(), 0);

        skip(7 hours);

        //uint256 lpBalance = tripod.totalLpBalance(); 
        (uint256 _a, uint256 _b, uint256 _c) = tripod.estimatedTotalAssetsAfterBalance();
        vm.prank(gov);
        vm.expectRevert();
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

        uint256 beforeWeth = weth.balanceOf(address(tripod));
        vm.startPrank(management);
        tripod.swapTokenForTokenManually(
            cvx,
            address(weth),
            4e18,
            0,
            false
        );

        assertGt(weth.balanceOf(address(tripod)), beforeWeth);
        //vm.prank(management);
        tripod.swapTokenForTokenManually(
            address(weth),
            tokenAddrs["USDT"],
            weth.balanceOf(address(tripod)),
            0,
            true
        );

        assertEq(weth.balanceOf(address(tripod)), 0);
        assertGt(IERC20(tokenAddrs["USDT"]).balanceOf(address(tripod)), 0);
    }

    function testReturnFundsManually(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

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
    }
    
    function testSetKeeper(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        vm.prank(gov);
        tripod.setKeeper(address(69));

        skip(1 days);

        vm.prank(keeper);
        vm.expectRevert("!authorized");
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
        
        assertEq(tripod.getRewardTokensLength(), 2);

    }
}
