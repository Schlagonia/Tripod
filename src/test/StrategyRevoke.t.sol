// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";

contract StrategyRevokeTest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testRevokeStrategyFromVault(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        uint256[3] memory deposited = depositAllVaultsAndHarvest(_amount);

        //Pick a random Strategy to shutdown
        uint256 i = _amount % 3;
        skip(1);
        deal(cvx, address(tripod), _amount/100);
        deal(crv, address(tripod), _amount/100);

        //Turn off health check to allow for profit
        setProvidersHealthCheck(false);
        // In order to pass these tests, you will need to implement prepareReturn.
        // TODO: uncomment the following lines.
        vm.prank(gov);
        assetFixtures[i].vault.revokeStrategy(address(assetFixtures[i].strategy));
        skip(1);
        //uint256 preBalance = assetFixtures[i].strategy.estimatedTotalAssets();
        vm.prank(keeper);
        tripod.harvest();
        assertGe(assetFixtures[i].want.balanceOf(address(assetFixtures[i].vault)), deposited[i]);
    }

}
