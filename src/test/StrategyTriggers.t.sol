// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

interface IBaseFee {
    function setMaxAcceptableBaseFee(uint256) external;
}

contract StrategyTriggerTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testHarvestTrigger(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaults(_amount);

        vm.prank(address(0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7));
        IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F).setMaxAcceptableBaseFee(1e18);
        skip(1);

        //Providers have credit available so it should harvest
        assertTrue(tripod.harvestTrigger(1), "Check 0");

        vm.prank(address(0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7));
        IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F).setMaxAcceptableBaseFee(1);
        skip(1);

        //Base fee should make it false
        assertTrue(!tripod.harvestTrigger(1), "Check 1");

        vm.prank(address(0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7));
        IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F).setMaxAcceptableBaseFee(1e18);
        skip(1);

        vm.prank(keeper);
        tripod.harvest();

        assertTrue(!tripod.harvestTrigger(1), "Check 2");
        skip(1);

        vm.startPrank(gov);
        tripod.setParameters(
            tripod.dontInvestWant(),
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            true
        ); 
        vm.stopPrank();

        assertTrue(tripod.harvestTrigger(3), "check 3");
        
        vm.startPrank(gov);
        tripod.setParameters(
            tripod.dontInvestWant(),
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            false
        ); 
        vm.stopPrank();
        skip(1);

        assertTrue(!tripod.harvestTrigger(1), "Check 4");

        vm.startPrank(gov);
        tripod.setParameters(
            tripod.dontInvestWant(),
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            1 days,
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();
        skip(tripod.maxEpochTime() + 1);

        assertTrue(tripod.harvestTrigger(3), "check 5");

        vm.startPrank(gov);
        tripod.setParameters(
            true,
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        skip(1);
        vm.prank(keeper);
        tripod.harvest();

        skip(1);
        //Should have credit available but dontInvestWant should stop it 
        assertTrue(!tripod.harvestTrigger(1), "Check 6");

        vm.startPrank(gov);
        tripod.setParameters(
            false,
            tripod.minRewardToHarvest(),
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        assertTrue(tripod.harvestTrigger(1), "Check 7");

    }

    function testTendTrigger(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        vm.prank(address(0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7));
        IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F).setMaxAcceptableBaseFee(1e18);

        assertTrue(!tripod.tendTrigger(1), "Check 1");

        deal(crv, address(tripod), 1e18);

        //Should still be false since minReward is still not set
        assertTrue(!tripod.tendTrigger(1), "Check 2");

        vm.startPrank(gov);
        tripod.setParameters(
            tripod.dontInvestWant(),
            100,
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        assertTrue(tripod.tendTrigger(1), "check 3");

        vm.startPrank(gov);
        tripod.setParameters(
            tripod.dontInvestWant(),
            100e18,
            tripod.minAmountToSell(),
            tripod.maxEpochTime(),
            //tripod.autoProtectionDisabled(),
            tripod.maxPercentageLoss(),
            tripod.launchHarvest()
        ); 
        vm.stopPrank();

        assertTrue(!tripod.tendTrigger(3), "Check 4");
    }

    function testTend(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);
        
        uint256 stakedBalance = tripod.balanceOfStake();

        skip(1 days);
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);

        vm.prank(keeper);
        tripod.tend();

        assertEq(IERC20(cvx).balanceOf(address(tripod)), 0, "CVX balance");
        assertEq(IERC20(crv).balanceOf(address(tripod)), 0, "Curve balance");
        assertGt(tripod.balanceOfStake(), stakedBalance, "Staked bal");
    }

}
