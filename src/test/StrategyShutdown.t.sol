// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {BalancerTripod} from "../DEXes/BalancerTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract StrategyShutdownTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testVaultShutdownCanWithdraw(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        //Pick a random vault to shutdown
        uint256 index = _amount % 3;
        console.log("Index ", index);

        AssetFixture memory _fixture = assetFixtures[index];
        IVault _vault = _fixture.vault;
        ProviderStrategy _provider = _fixture.strategy;
        IERC20 _want = _fixture.want;


        uint256 bal = _want.balanceOf(user);
        if (bal > 0) {
            vm.prank(user);
            _want.transfer(address(0), bal);
        }

        skip(7 hours);
        //uint256 preBalance = _provider.estimatedTotalAssets();
        // Set Emergency
        vm.prank(gov);
        _vault.setEmergencyShutdown(true);

        vm.prank(gov);
        tripod.setDontInvestWant(true);

        //Have to harvest first or it will report a loss
        //Testing harvesting the provider directly
        vm.prank(keeper);
        tripod.harvest();

        // Withdraw (does it work, do you get what you expect)
        vm.prank(user);
        _vault.withdraw();
        console.log("Withdrew ", _want.balanceOf(user));
        assertGe(_want.balanceOf(user), deposited[index]);
    }

    function testBasicShutdown(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        // Earn interest
        skip(2 days);

        //Pick a random Strategy to shutdown
        uint256 index = _amount % 3;
        console.log("Index ", index);

        AssetFixture memory _fixture = assetFixtures[index];
        IVault _vault = _fixture.vault;
        ProviderStrategy _provider = _fixture.strategy;
        IERC20 _want = _fixture.want;

        // Set emergency
        vm.prank(strategist);
        _provider.setEmergencyExit();

        //uint256 preBalance = _provider.estimatedTotalAssets();

        vm.prank(strategist);
        _provider.harvest(); // Remove funds from strategy

        assertEq(_want.balanceOf(address(_provider)), 0);
        assertGe(_want.balanceOf(address(_vault)), deposited[index]); // The vault has all funds
    }

    function testDontInvestWant(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        skip(1 days);

        vm.prank(gov);
        tripod.setDontInvestWant(true);

        vm.prank(keeper);
        tripod.harvest();

        for(uint8 i = 0; i < assetFixtures.length; ++i) {
            assertEq(assetFixtures[i].want.balanceOf(address(assetFixtures[i].strategy)), assetFixtures[i].strategy.estimatedTotalAssets());
        }
    }
}
