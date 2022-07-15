// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";

import "forge-std/console.sol";

// NOTE: if the name of the strat or file changes this needs to be updated
import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveTripod} from "../DEXes/CurveTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract TripodSetupTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    // Show that the all providers are set up properly
    function testProviderSetup() public {

        ProviderStrategy providerA = assetFixtures[0].strategy;
        ProviderStrategy providerB = assetFixtures[1].strategy;
        ProviderStrategy providerC = assetFixtures[2].strategy;

        assertEq(address(tripod.providerA()), address(providerA));
        assertEq(tripod.tokenA(), address(providerA.want()));
        assertEq(address(tripod.providerB()), address(providerB));
        assertEq(tripod.tokenB(), address(providerB.want()));
        assertEq(address(tripod.providerC()), address(providerC));
        assertEq(tripod.tokenC(), address(providerC.want()));

        assertEq(providerA.tripod(), address(tripod));
        assertEq(providerA.keeper(), address(tripod));
        assertEq(providerB.tripod(), address(tripod));
        assertEq(providerB.keeper(), address(tripod));
        assertEq(providerC.tripod(), address(tripod));
        assertEq(providerC.keeper(), address(tripod));
        
    }

    function testDeposits(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        ProviderStrategy providerA = assetFixtures[0].strategy;
        ProviderStrategy providerB = assetFixtures[1].strategy;
        ProviderStrategy providerC = assetFixtures[2].strategy;
        console.log("Depositing Funds");
        for(uint8 i = 0; i < assetFixtures.length; ++i) {
            AssetFixture memory _fixture = assetFixtures[i];
            IERC20 _want = _fixture.want;
            IVault _vault = _fixture.vault;
            //need to change the _amount into equal amounts dependant on the want based on oracle of 1e8
            uint256 toDeposit = _amount * 1e8 / (tokenPrices[_fixture.name] * (10 ** (18 - IERC20Extended(address(_want)).decimals())));
            console.log("To deposit", toDeposit);
            deposit(_vault, user, address(_want), toDeposit);
  
            assertEq(_want.balanceOf(address(_vault)), toDeposit);
        }

        skip(1);
        console.log("Harvesting");
        vm.prank(keeper);
        tripod.harvest();
        console.log("harvested");
        assertEq(tripod.balanceOfPool(), 0);
        assertGt(tripod.balanceOfStake(), 0);
        assertRelApproxEq(providerA.estimatedTotalAssets(), tripod.invested(address(providerA.want())) + tripod.balanceOfA(), DELTA);
        assertRelApproxEq(providerB.estimatedTotalAssets(), tripod.invested(address(providerB.want())) + tripod.balanceOfB(), DELTA);
        assertRelApproxEq(providerC.estimatedTotalAssets(), tripod.invested(address(providerC.want())) + tripod.balanceOfC(), DELTA);

    }
}
