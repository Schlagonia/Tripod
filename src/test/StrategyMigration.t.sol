// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {CurveTripod} from "../DEXes/CurveTripod.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IVault} from "../interfaces/Vault.sol";

contract StrategyMigrationTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testCloneTripod() public {
        address newTripod = tripod.cloneCurveTripod(
            address(assetFixtures[0].strategy),
            address(assetFixtures[1].strategy),
            address(assetFixtures[2].strategy),
            address(weth),
            pool,
            rewardsContract
        );

        CurveTripod _newTripod = CurveTripod(newTripod);

        assertEq(pool, _newTripod.pool());
        assertTrue(!_newTripod.isOriginal());

        vm.expectRevert(bytes("!original"));

        _newTripod.cloneCurveTripod(
            address(assetFixtures[0].strategy),
            address(assetFixtures[1].strategy),
            address(assetFixtures[2].strategy),
            address(weth),
            pool,
            rewardsContract
        );

        vm.expectRevert(bytes("Joint already initialized"));

        _newTripod.initialize(
            address(assetFixtures[0].strategy),
            address(assetFixtures[1].strategy),
            address(assetFixtures[2].strategy),
            address(weth),
            pool,
            rewardsContract
        );
    }

    function testMigrateProvider(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        depositAllVaultsAndHarvest(_amount);

        skip(3600);

        console.log("Setting dont Invest and harvesting 2");
        //Set dont Invest to true so funds will be returned to provider on next harvest
        vm.prank(gov);
        tripod.setDontInvestWant(true);
       
        //Turn off health checks for potentiall losses
        setProvidersHealthCheck(false);

        vm.prank(keeper);
        tripod.harvest();

        skip(1);

        assertEq(tripod.totalLpBalance(), 0, "Still has lp balance"); 

        console.log("Migrating strategies");
        //clone each provider
        for(uint8 i = 0; i < assetFixtures.length; ++i) {
            AssetFixture memory _fixture = assetFixtures[i];
            IVault _vault = _fixture.vault;
            ProviderStrategy _provider = _fixture.strategy;
            IERC20 _want = _fixture.want;

            uint256 bal = _want.balanceOf(address(_provider));
            assertGt(bal, 0, "Provider doesnt have tokens");

            address _newProvider = _provider.clone(address(_vault));
            ProviderStrategy newProvider = ProviderStrategy(_newProvider);
            //Migrate to new strategy
            vm.prank(gov);
            _vault.migrateStrategy(address(_provider), _newProvider);

            //vm.prank(gov);
            //newProvider.setHealthCheck(0xDDCea799fF1699e98EDF118e0629A974Df7DF012);

            vm.prank(gov);
            newProvider.setJoint(address(tripod));

            //Make sure all funds got moved
            assertEq(_want.balanceOf(address(_provider)), 0, "Old provider");
            assertEq(_want.balanceOf(_newProvider), bal, "Not enough in new provider");
            assertEq(newProvider.tripod(), address(tripod), "Tripod not set");
        }
        console.log("Harvestingt 3");
        skip(1);
        vm.prank(gov);
        tripod.setDontInvestWant(false);

        harvestTripod();

        skip(1);

        assertGt(tripod.totalLpBalance(), 0, "No lp balance"); 
    }


}
