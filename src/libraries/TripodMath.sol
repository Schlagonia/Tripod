// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

/// @title Tripod Math
/// @notice Contains the Rebalancing Math for the Tripod. Used during both the rebalance and quote rebalance functions
library TripodMath {

    /*
    * @notice
    *   The rebalancing math aims to have each tokens relative return be equal after the rebalance irregardless of the strating weights or exchange rates
    *   These functions are called during swapOneToTwo() or swapTwoToOne() in the Tripod.sol https://github.com/Schlagonia/Tripod/blob/master/src/Tripod.sol
    *   All math was adopted from the original joint strategies https://github.com/fp-crypto/joint-strategy

        All equations will use the following variables:
            a0 = The invested balance of the first token
            a1 = The ending balance of the first token
            b0 = The invested balance of the second token
            b1 = The ending balance of the second token
            c0 = the invested balance of the third token
            c1 = The ending balance of the third token
            eOfB = The exchange rate of either a => b or b => a depending on which way we are swapping
            eOfC = The exchange rate of either a => c or c => a depending on which way we are swapping
            precision = 10 ** first token decimals
            precisionB = 10 ** second token decimals
            precisionC = 10 ** third token decimals

            Variables specific to swapOneToTwo()
            n = The amount of a token we will be selling
            p = The % of n we will be selling from a => b

            Variables specific to swapTwoToOne()
            nb = The amount of b we will be swapping to a
            nc = The amount of c we will be swapping to a 

        The starting equations that all of the following are derived from is:

         a1 - n       b1 + eOfB*n*p      c1 + eOfC*n*(1-p) 
        --------  =  --------------  =  -------------------
           a0              b0                   c0

    */

    struct RebalanceInfo {
        uint256 precision;
        uint256 a0;
        uint256 a1;
        uint256 b0;
        uint256 b1;
        uint256 eOfB;
        uint256 precisionB;
        uint256 c0;
        uint256 c1;
        uint256 eOfC;
        uint256 precisionC;
    }   
    
    uint256 private constant RATIO_PRECISION = 1e18;
    /*
    * @notice
    *   Internal function to be called during swapOneToTwo to return n: the amount of a to sell and p: the % of n to sell to b
    * @param info, Rebalance info struct with all needed variables
    * @return n, The amount of a to sell
    * @return p, The percent of a we will sell to b repersented as 1e18. i.e. 50% == .5e18
    */
    function getNandP(RebalanceInfo memory info) internal pure returns(uint256 n, uint256 p) {
        p = getP(info);
        n = getN(info, p);
    }

    /*
    * @notice
    *   Internal function used to calculate the percent of n that will be sold to b
    *   p is repersented as 1e18
    * @param info, RebalanceInfo stuct
    * @return the percent of a to sell to b as 1e18
    */
    function getP(RebalanceInfo memory info) internal pure returns (uint256 p) {
        /*
        *             a1*b0*eOfC + b0c1 - b1c0 - a0*b1*eOfC
        *   p = ----------------------------------------------------
        *        a1*c0*eOfB + a1*b0*eOfC - a0*c1*eOfB - a0*b1*eOfC
        */
        unchecked {
            //pre-calculate a couple of parts that are used twice
            //var1 = a0*b1*eOfC
            uint256 var1 = info.a0 * info.b1 * info.eOfC / info.precision;
            //var2 = a1*b0*eOfC
            uint256 var2 = info.a1 * info.b0 * info.eOfC / info.precision;

            uint256 numerator = var2 + (info.b0 * info.c1) - (info.b1 * info.c0) - var1;

            uint256 denominator = 
                (info.a1 * info.c0 * info.eOfB / info.precision) + 
                    var2 - 
                        (info.a0 * info.c1 * info.eOfB / info.precision) - 
                            var1;
    
            p = numerator * 1e18 / denominator;
        }
    }

    /*
    * @notice
    *   Internal function used to calculate the amount of a to sell once p has been calculated
    *   Converts all uint's to int's because the numerator will be negative
    * @param info, RebalanceInfo stuct
    * @param p, % calculated to of b to sell to a in 1e18
    * @return The amount of a to sell
    */
    function getN(RebalanceInfo memory info, uint256 p) internal pure returns(uint256) {
        /*
        *          (a1*b0) - (a0*b1)  
        *    n = -------------------- 
        *           b0 + eOfB*a0*P
        */
        unchecked{
            uint256 numerator = 
                (info.a1 * info.b0) -
                    (info.a0 * info.b1);

            uint256 denominator = 
                (info.b0 * 1e18) + 
                    (info.eOfB * info.a0 / info.precision * p);

            return numerator * 1e18 / denominator;
        }
    }

    /*
    * @notice
    *   Internal function used to calculate the _nb: the amount of b to sell to a
    *       and nc : the amount of c to sell to a. For the swapTwoToOne() function.
    *   The calculations for both b and c use the same denominator and the numerator is the same consturction but the variables for b or c are swapped 
    * @param info, RebalanceInfo stuct
    * @return _nb, the amount of b to sell to a in terms of b
    * @return nc, the amount of c to sell to a in terms of c 
    */
    function getNbAndNc(RebalanceInfo memory info) internal pure returns(uint256 nb, uint256 nc) {
        /*
        *          a0*x1 + y0*eOfy*x1 - a1*x0 - y1*eOfy*x0
        *   nx = ------------------------------------------
        *               a0 + eOfc*c0 + b0*eOfb
        */
        unchecked {
            uint256 numeratorB = 
                (info.a0 * info.b1) + 
                    (info.c0 * info.eOfC * info.b1 / info.precisionC) - 
                        (info.a1 * info.b0) - 
                            (info.c1 * info.eOfC * info.b0 / info.precisionC);

            uint256 numeratorC = 
                (info.a0 * info.c1) + 
                    (info.b0 * info.eOfB * info.c1 / info.precisionB) - 
                        (info.a1 * info.c0) - 
                            (info.b1 * info.eOfB * info.c0 / info.precisionB);

            uint256 denominator = 
                info.a0 + 
                    (info.eOfC * info.c0 / info.precisionC) + 
                        (info.b0 * info.eOfB / info.precisionB);

            nb = numeratorB / denominator;
            nc = numeratorC / denominator;
        }
    }

    /*
    * @notice 
    *   Internal function called when a new position has been opened to store the relative weights of each token invested
    *   uses the most recent oracle price to get the dollar value of the amount invested. This is so the rebalance function
    *   can work with different dollar amounts invested upon lp creation
    * @param investedA, the amount of tokenA that was invested
    * @param investedB, the amount of tokenB that was invested
    * @param investedC, the amoun of tokenC that was invested
    * @return, the relative weight for each token expressed as 1e18
    */
    function getWeights(
        uint256 adjustedA,
        uint256 adjustedB,
        uint256 adjustedC
    ) internal pure returns (uint256 wA, uint256 wB, uint256 wC) {
        unchecked {
            uint256 total = adjustedA + adjustedB + adjustedC; 
                        
            wA = adjustedA * RATIO_PRECISION / total;
            wB = adjustedB * RATIO_PRECISION / total;
            wC = adjustedC * RATIO_PRECISION / total;
        }
    }
}