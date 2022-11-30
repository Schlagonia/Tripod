// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {StrategyFixture} from "./utils/StrategyFixture.sol";
import "forge-std/console.sol";

import {ProviderStrategy} from "../ProviderStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Extended} from "../interfaces/IERC20Extended.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";
import {IVault} from "../interfaces/Vault.sol";
import {TripodMath} from "../libraries/TripodMath.sol";
import "forge-std/Test.sol";

contract TripodMathTest is StrategyFixture {
    using SafeERC20 for IERC20;
    function setUp() public override {
        super.setUp();
    }

    function testRatios(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        //should return 0 if ending value is 0
        (uint256 aRatio, uint256 bRatio, uint256 cRatio) = TripodMath.getRatios(
            _amount,
            0,
            _amount,
            0,
            _amount,
            0
        );

        assertEq(aRatio, 0, "a ==0");
        assertEq(bRatio, 0, "b==0");
        assertEq(cRatio, 0, "c==0");

        //Expected when growth is positive
        uint256 divider = _amount % 98;
        //We dont want it to ever be 0 or 1
        divider = divider + 2;
        console.log("Divider is ", divider);
        uint256 expected = 1e18 + (1e18 / divider);
        console.log("Expected is ", expected);

        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            _amount,
            _amount + (_amount / divider),
            _amount / 2,
            _amount / 2 + (_amount / 2 / divider),
            _amount * 3,
            _amount * 3 + (_amount * 3 / divider)
        );

        assertApproxEq(aRatio, expected, 1);
        assertApproxEq(bRatio, expected, 1);
        assertApproxEq(cRatio, expected, 1);

        //Expeted when growth is negative
        uint256 expected1 = 1e18 - (1e18 / divider);
        console.log("Expected 1 is ", expected1);

        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            _amount,
            _amount - (_amount / divider),
            _amount / 2,
            _amount / 2 - (_amount / 2 / divider),
            _amount * 3,
            _amount * 3 - (_amount * 3 / divider)
        );

        //WE give one degree of change for rounding diffs
        assertApproxEq(aRatio, expected1, 1);
        assertApproxEq(bRatio, expected1, 1);
        assertApproxEq(cRatio, expected1, 1);

        //should revert when starting amount == 0 because its dividing by 0
        vm.expectRevert(stdError.divisionError);
        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            0,
            _amount,
            _amount,
            _amount,
            _amount,
            _amount
        );
        
        //Depositing in should not effect anything. Do it all again
        depositAllVaultsAndHarvest(_amount);

        //should return 0 if ending value is 0
        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            _amount,
            0,
            _amount,
            0,
            _amount,
            0
        );

        assertEq(aRatio, 0, "a ==0");
        assertEq(bRatio, 0, "b==0");
        assertEq(cRatio, 0, "c==0");

        //Expected when growth is positive

        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            _amount,
            _amount + (_amount / divider),
            _amount / 2,
            _amount / 2 + (_amount / 2 / divider),
            _amount * 3,
            _amount * 3 + (_amount * 3 / divider)
        );

        assertApproxEq(aRatio, expected, 1);
        assertApproxEq(bRatio, expected, 1);
        assertApproxEq(cRatio, expected, 1);

        //Expeted when growth is negative

        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            _amount,
            _amount - (_amount / divider),
            _amount / 2,
            _amount / 2 - (_amount / 2 / divider),
            _amount * 3,
            _amount * 3 - (_amount * 3 / divider)
        );

        assertApproxEq(aRatio, expected1, 1);
        assertApproxEq(bRatio, expected1, 1);
        assertApproxEq(cRatio, expected1, 1);

        //should revert when starting amount == 0 because its dividing by 0
        vm.expectRevert(stdError.divisionError);
        (aRatio, bRatio, cRatio) = TripodMath.getRatios(
            0,
            _amount,
            _amount,
            _amount,
            _amount,
            _amount
        );
    }

    function testSwapOneToTwoMath(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        //depositAllVaultsAndHarvest(_amount);
        uint256 delta = 10 ** 7;
        uint256 n;
        uint256 p;
        //If everything is equal it should revert based on dividing by 0
        vm.expectRevert(stdError.divisionError);
        (n, p) = TripodMath.getNandP(
            TripodMath.RebalanceInfo({
                precisionA : 1e18,
                a0 : _amount,
                a1 : _amount *2,
                b0 : _amount,
                b1 : _amount *2,
                eOfB : 1e18,
                precisionB : 1e18,
                c0 : _amount,
                c1 : _amount * 2,
                eOfC : 1e18,
                precisionC : 1e18 
        }));

        //If both are equal then it should split 50-50
        (n,  p) = TripodMath.getNandP(
            TripodMath.RebalanceInfo({
                precisionA : 1e18,
                a0 : _amount,
                a1 : _amount *2,
                b0 : _amount,
                b1 : _amount,
                eOfB : 1e18,
                precisionB : 1e18,
                c0 : _amount,
                c1 : _amount,
                eOfC : 1e18,
                precisionC : 1e18 
        }));

        //A doubled so we should be selling 2/3 of amount gained 50-50
        assertRelApproxEq(n, _amount * 2 / 3, 1e10);
        assertRelApproxEq(p, 5e17, 1e10);

        //Same test with different precisions for each
        uint256 aAmount = _amount * (10 **(25 - 18));
        uint256 bAmount = _amount / (10 **(18 - 3));
        uint256 cAmount = _amount / (10 **(18 - 13));
        (n,  p) = TripodMath.getNandP(
            TripodMath.RebalanceInfo({
                precisionA : 1e25,
                a0 : aAmount,
                a1 : aAmount *2,
                b0 : bAmount,
                b1 : bAmount,
                eOfB : 1e3,
                precisionB : 1e3,
                c0 : cAmount,
                c1 : cAmount,
                eOfC : 1e13,
                precisionC : 1e13 
        }));

        //A doubled so we should be selling 2/3 of amount gained 50-50
        //Give more rounding buffer due to decimal changes adjusting the amount
        assertRelApproxEq(n, aAmount * 2 / 3, 1e4);
        assertRelApproxEq(p, 5e17, 1e4);
    }

    function testSwapTwoToOneMath(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);

        uint256 nb;
        uint256 nc;

        //If everything is equal it should revert based on dividing by 0
        (nb, nc) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo({
                precisionA : 1e18,
                a0 : _amount,
                a1 : _amount *2,
                b0 : _amount,
                b1 : _amount *2,
                eOfB : 1e18,
                precisionB : 1e18,
                c0 : _amount,
                c1 : _amount * 2,
                eOfC : 1e18,
                precisionC : 1e18 
        }));
        
        assertEq(nb, 0);
        assertEq(nb, 0);


        (nb, nc) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo({
                precisionA : 0,
                a0 : _amount,
                a1 : _amount / 2,
                b0 : _amount,
                b1 : _amount,
                eOfB : 1e18,
                precisionB : 1e18,
                c0 : _amount,
                c1 : _amount,
                eOfC : 1e18,
                precisionC : 1e18 
            }));
        
        assertEq(nb, nc);

        //Test with uneven amounts
        uint256 aAmount = _amount * 3;
        (nb, nc) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo({
                precisionA : 0,
                a0 : aAmount,
                a1 : aAmount / 2,
                b0 : _amount,
                b1 : _amount,
                eOfB : 1e18,
                precisionB : 1e18,
                c0 : _amount,
                c1 : _amount,
                eOfC : 1e18,
                precisionC : 1e18 
            }));
        
        assertEq(nb, nc);

        //Test with uneven decimals an amounts
        aAmount = _amount * 4 * (10 ** 6);
        uint256 bAmount = _amount * (10 ** 4);
        uint256 cAmount = _amount / (10 ** 12);
        (nb, nc) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo({
                precisionA : 0,
                a0 : aAmount,
                a1 : aAmount / 2,
                b0 : bAmount,
                b1 : bAmount,
                eOfB : 1e24,
                precisionB : 1e18,
                c0 : cAmount,
                c1 : cAmount,
                eOfC : 1e24,
                precisionC : 1e18 
            }));
        
        //Need to give a buffer with decimal changes
        assertRelApproxEq(nb / 1e4, nc * 1e12, DELTA);
    }

    function testExtremes(uint256 _amount) public {
        TripodMath.RebalanceInfo memory info = 
            TripodMath.RebalanceInfo({
                precisionA : 0,
                a0 : 0,
                a1 : 0,
                b0 : 0,
                b1 : 0,
                eOfB : 0,
                precisionB : 0,
                c0 : 0,
                c1 : 0,
                eOfC : 0,
                precisionC : 0 
        });

        uint256 n;
        uint256 p;
        uint256 nb;
        uint256 nc;

        // WE should revert when all values are 0
        vm.expectRevert(stdError.divisionError);
        (n, p) = TripodMath.getNandP(info);

        vm.expectRevert(stdError.divisionError);
        (nb, nc) =  TripodMath.getNbAndNc(info);

        info = TripodMath.RebalanceInfo({
            precisionA : type(uint256).max,
            a0 : type(uint256).max,
            a1 : type(uint256).max,
            b0 : type(uint256).max,
            b1 : type(uint256).max,
            eOfB : type(uint256).max,
            precisionB : type(uint256).max,
            c0 : type(uint256).max,
            c1 : type(uint256).max,
            eOfC : type(uint256).max,
            precisionC : type(uint256).max 
        });

        vm.expectRevert(stdError.divisionError);
        (n, p) = TripodMath.getNandP(info);

        (nb, nc) = TripodMath.getNbAndNc(info);

        assertEq(nc, 0);
        assertEq(nb, 0);
    }
}