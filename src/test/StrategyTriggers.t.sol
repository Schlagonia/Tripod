// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveTripod} from "../DEXes/CurveTripod.sol";
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
        depositAllVaultsAndHarvest(_amount);

        vm.prank(address(0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7));
        IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F).setMaxAcceptableBaseFee(1e18);

        //Nothings happened should be false
        assertTrue(!tripod.harvestTrigger(1), "Check 1");

        vm.prank(gov);
        tripod.setDontInvestWant(true);

        assertTrue(tripod.harvestTrigger(1), "Check 2");

        vm.prank(gov);
        tripod.setDontInvestWant(false);

        assertTrue(!tripod.harvestTrigger(1), "Check 3");

        vm.prank(gov);
        assetFixtures[0].strategy.setLaunchHarvest(true);

        assertTrue(tripod.harvestTrigger(3), "check 4");

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

        vm.prank(gov);
        tripod.setMinRewardToHarvest(100);

        assertTrue(tripod.tendTrigger(1), "check 3");

        vm.prank(gov);
        tripod.setMinRewardToHarvest(100e18);

        assertTrue(!tripod.tendTrigger(3), "Check 4");
    }

    function testTend(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        //Determining where tripod will swap to in order to compare post invested balances
        address tokenTo;
        if (tripod.referenceToken() == tripod.tokenA() ||
            tripod.referenceToken() == tripod.tokenB() ||
            tripod.referenceToken() == tripod.tokenC()
        ) {
            tokenTo = tripod.referenceToken();
        } else {
            (uint256 ratioA, uint256 ratioB, uint256 ratioC) = tripod.getRatios(
                    tripod.balanceOfA(),
                    tripod.balanceOfB(),
                    tripod.balanceOfC()
                );
       
                //If everything is equal use A   
                if(ratioA <= ratioB && ratioA <= ratioC) {
                    tokenTo = tripod.tokenA();
                } else if(ratioB <= ratioC) {
                    tokenTo = tripod.tokenB();
                } else {
                    tokenTo = tripod.tokenC();
                }
        }
        uint256 beforeBal = tripod.invested(tokenTo);
        uint256 stakedBalance = tripod.balanceOfStake();

        skip(1 days);
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);

        vm.prank(keeper);
        tripod.tend();

        assertEq(IERC20(cvx).balanceOf(address(tripod)), 0, "CVX balance");
        assertEq(IERC20(crv).balanceOf(address(tripod)), 0, "Curve balance");
        assertGt(tripod.balanceOfStake(), stakedBalance, "Staked bal");
        assertGt(tripod.invested(tokenTo), beforeBal, "invested balance");
    }
}
