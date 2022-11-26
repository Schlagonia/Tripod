// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;
/*    :::::::::::       :::::::::       :::::::::::       :::::::::       ::::::::       ::::::::: 
         :+:           :+:    :+:          :+:           :+:    :+:     :+:    :+:      :+:    :+: 
        +:+           +:+    +:+          +:+           +:+    +:+     +:+    +:+      +:+    +:+  
       +#+           +#++:++#:           +#+           +#++:++#+      +#+    +:+      +#+    +:+   
      +#+           +#+    +#+          +#+           +#+            +#+    +#+      +#+    +#+    
     #+#           #+#    #+#          #+#           #+#            #+#    #+#      #+#    #+#     
    ###           ###    ###      ###########       ###             ########       #########       
.........................................,;**?????*+:...............................................
.......................................:+??*********?*:.............................................
.....................................,+??************??*,...........................................
..................................,:+???**************???+;,........................................
...........................,,:::;+*???%?**************??%???*+;::::,,,..............................
....................,:;+**??%%%%%????*%%?*************?%?*????%%%%%%???*++;:........................
...................,*?%%%%%%%%%%?*????*%%?***********?%%*????*?%%%%%%%%%%S%?,.......................
...................,%%%%%%%%%%%%*??????*?%??********?%?*??????*%%%%%%%%%%%%%,.......................
....................?%%%%%%%%%%?*???????*?????????????*???????*?%%%%%%%%%%%?,.......................
....................+%%%%%%%%??*?????????*?????????????*???????*??%%%%%%%%%*........................
....................;S%%%%???**????????*?????+;;;;;*??%?*???????**???%%%%%%:........................
....................+?**??%%*******????%%?S%*:.....:*S%?S%??????????%%??**?;........................
...................;?????%%********????%%?%%??*....*?%%%*%%??????*??*??%%%???,.......................
..................:%S%%S%??*****????*?%SS?*%%%%%%%%%%??%%SS????????*???%S%%S?,......................
.................:%%S%?*%%***?%SS??**%%SS%%%??%%%%?%??%%SS%%***?%%%??%%%%%%??*......................
................,??S%%*;%%?%?**?%S%?*?%%%SSS%??%%??%%%%S%%%%???SS%*++?S%%%%+*?;.....................
................+?%%S%+*%S%%;,,*%%S%??%%%%%%SSSSSSSSS%%%%%%???SS%%+::*%%S%S*;*?:....................
...............:?%S%%+?%%S%%?*?%%SS%%*?%%%%%%%%%%%%%%%%%%%?**?%S%%%??%%S%%S?+;?*,...................
...............:;,....,?%%%%%%%%%%%%???????%%%%%%%S%%%?????????%%%%%%%%%%%%,..,::...................
.......................+S%%%%%%%%%::?????????%%%%%%%%?????*????+;S%%%%%%SS?.........................
.......................*%%%S%%SS#*..:??????*??????????**??????:..*##%?S%%%%;........................
......................,+?%%?;,,:;,...:*??????????????????????:...,;:,.;*??+,........................
.............................:*???:,::;+*%????????????????%*++;;????*,..............................
.............................*????%SSS##SS????????????????S####S?????,..............................
...........................,;*???*?SSSSS%S%??????????????%#SSSSS*???%*+;,...........................
..........................;???%???*%S%%%?SSS%%?????????%SSS?%%S%*???????*,..........................
..........................,;*??%?%??%%%**%SS??%??????S%?SS%?*%S??%??*??+,...........................
............................,+???%%*%S%?*?S%?*%SS%%SSS?*?S%??%S?%????*:.............................
..............................:*?*%?*%S?*?S%??%%?%%?%S??%S???S%?%*??+,..............................
...............................,+??%??S%**%S???S%%%%%S??%S??%S?%???:................................
..............................+%?%??%*%S?*%S%??SS##SSS??%S%?%%?%?%%?%*,.............................
............................:%@#S%%%%??%S??SSS?%####SS*SS%%????%%%%S#@S:............................
...........................:%#SSSSSSS%*%%%??;+?%#####%?++%%%%?%SSSSSSS#%;...........................
..........................:??SSSSSS?::??+;?*..???SSS%*?,.?%;;?;:?SSSSSS??:..........................
.........................:????%SSS*...;??:??,.+?%%%%%?*.:%?,+?,..*SSS%????;.........................
........................:??**?????:....;?++?:.:?%????%;.+%;;%;...,*????????;........................
.......................,????????*,......,::?+.,?%????%:.??,+;.....,*????????:.......................
......................,????????*,..........+%;.*%???%?.+%+.........,+????????,......................
...................;%#%****?+..................*?***?:..................;?****%#%+..................
..................:%?%S%%??*,..................*???*?:....................*??%%S%?%;................
.................,?%????S?:,...................??????,....................,:*S%???%?,...............
................,????%?%;......................*%%%%?,......................:%?%???%:...............
...............*????*..........................*??*?+...........................*????*,.............
..............;????,...........................;????,............................,*???+.............
.............*%?,...............................;%%?,.............................,*%*..............
............;%%%+..............................,?%%%;.............................+%%%;.............
...........,?%%%%,.............................:%%%%?............................,%%%%?,............
...........:%%%%%+.............................+%%%%%:...........................+%%%%%;............
...........*%%%%%?.............................?%%%%%;...........................?%%%%%*............
...........?%%%%%%,...........................,?%%%%%+..........................,?%%%%%?,...........
..........,%%%%%%%:...........................,%%%%%%*..........................:%%%%%%%:...........
..........:%%%%%%%;...........................,%%%%%%?..........................;%%%%%%%:...........
..........:%%%%%%%+............................%%%%%%?..........................;%%%%%%%;...........
..........;%%%%%%%+............................+S%%%S*..........................+%%%%%%%;...........
..........:S%%%%%%*............................+S%%%S*..........................+%%%%%%S;...........
...........?S%%%%S;............................;S%%%%+..........................:%S%%%S?............
..........*S*;%%:?S+..........................+S+;S*;S*........................,%%;%%+*S+...........
..........?S;:S?.*S*..........................+S+;S*;S*........................;S?,?S;+S*...........
.........,%%::%?.+S?..........................*S;;S*:S?........................+S*.?%;:S?...........
.........:%%,:%?.;S%,.........................?S:;S*,%%,.......................*S+.?S;,%%,..........
.........:%%,,%?.:%%,........................,%%,:S*.%%........................*S+.?S:,%%,..........
.........;%?,+%%;:%%,........................,%%,:S*.%%,.......................?S;,?%+,%%:..........
.........;S?*S%%S+%%,........................,%%,:S?,?%:.......................?%+?%%%;?%:..........
.........;%%;;;;::%%,........................,%%;%SS??%:.......................?S;,,,,,%%:..........
.........;%%,....:%%:........................,%%;....+%%,......................?S+....:%%;..........
........;?%%%;..:%%%%;.......................:%SSS;.:%SSS+...................,?%S%*,.:%%%%*.........
........?%%%%*..?%%%%*.......................:;;;;,.,;;;;:....................;????*,.+???*+......*/

import "./interfaces/IERC20Extended.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TripodMath} from "./libraries/TripodMath.sol";
import {IVault} from "./interfaces/Vault.sol";
import {IProviderStrategy} from "./interfaces/IProviderStrategy.sol";

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

/// @title Tripod
/// @notice This is the base contract for a 3 token joint LP strategy to be used with @Yearn vaults
///     The contract takes tokens from 3 seperate Provider strategies each with a different token that corresponds to one of the tokens that
///     makes up the LP of "pool". Each harvest the Tripod will attempt to rebalance each token into an equal relative return percentage wise
///     irrespective of the begining weights, exchange rates or decimal differences. 
///
///     Made by Schlagania https://github.com/Schlagonia/Tripod adapted from the 2 token joint strategy https://github.com/fp-crypto/joint-strategy
///
abstract contract Tripod {
    using SafeERC20 for IERC20;
    using Address for address;

    // Constant to use in ratio calculations
    uint256 internal constant RATIO_PRECISION = 1e18;
    // Provider strategy of tokenA
    IProviderStrategy public providerA;
    // Provider strategy of tokenB
    IProviderStrategy public providerB;
    // Provider strategy of tokenC
    IProviderStrategy public providerC;

    // Address of tokenA
    address public tokenA;
    // Address of tokenB
    address public tokenB;
    // Address of tokenC
    address public tokenC;

    // Reference token to use in swaps: WETH, WFTM...
    address public referenceToken;
    // Bool repersenting if one of the tokens is == referencetoken
    bool public usingReference;
    // Array containing reward tokens
    address[] public rewardTokens;

    // Address of the pool to LP
    address public pool;

    //Mapping of the Amounts that actually go into the LP position
    mapping(address => uint256) public invested;
    //Mapping of the weights of each token that was invested to 1e18, .33e18 == 33%
    mapping(address => uint256) public investedWeight;

    //Address of the Keeper for this strategy
    address public keeper;

    //Bool manually set to determine wether we should harvest
    bool public launchHarvest;
    // Boolean values protecting against re-investing into the pool
    bool public dontInvestWant;

    // Thresholds to operate the strat
    uint256 public minAmountToSell;
    uint256 public minRewardToHarvest;
    uint256 public maxPercentageLoss;
    //Tripod version of maxReportDelay
    uint256 public maxEpochTime;

    // Modifiers needed for access control normally inherited from BaseStrategy 
    modifier onlyGovernance() {	
        checkGovernance();	
        _;	
    }	
    modifier onlyVaultManagers() {	
        checkVaultManagers();	
        _;	
    }	
    modifier onlyProviders() {	
        checkProvider();	
        _;	
    }	
    modifier onlyKeepers() {	
        checkKeepers();	
        _;	
    }	
    function checkKeepers() internal view {	
        require(isKeeper() || isGovernance() || isVaultManager(), "auth");	
    }	
    function checkGovernance() internal view {	
        require(isGovernance(), "auth");	
    }	
    function checkVaultManagers() internal view {	
        require(isGovernance() || isVaultManager(), "auth");	
    }	
    function checkProvider() internal view {	
        require(isProvider(), "auth");	
    }

    function isGovernance() internal view returns (bool) {
        return
            msg.sender == providerA.vault().governance() &&
            msg.sender == providerB.vault().governance() &&
            msg.sender == providerC.vault().governance();
    }

    function isVaultManager() internal view returns (bool) {
        return
            msg.sender == providerA.vault().management() &&
            msg.sender == providerB.vault().management() &&
            msg.sender == providerC.vault().management();
    }

    function isKeeper() internal view returns (bool) {
        return msg.sender == keeper;
    }

    function isProvider() internal view returns (bool) {
        return
            msg.sender == address(providerA) ||
            msg.sender == address(providerB) ||
            msg.sender == address(providerC);
    }

    /*
     * @notice
     *  Constructor, only called during original deploy
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, Pool to LP
     */
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool
    ) {
        _initialize(_providerA, _providerB, _providerC, _referenceToken, _pool);
    }

    /*
     * @notice
     *  Constructor equivalent for clones, initializing the tripod
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, Pool to LP
     */
    function _initialize(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool
    ) internal virtual {
        require(address(providerA) == address(0));
        providerA = IProviderStrategy(_providerA);
        providerB = IProviderStrategy(_providerB);
        providerC = IProviderStrategy(_providerC);

        //Make sure we have the same gov set for all Providers
        address vaultGov = providerA.vault().governance();
        require(vaultGov == providerB.vault().governance() && 
                    vaultGov == providerC.vault().governance());

        referenceToken = _referenceToken;
        pool = _pool;
        keeper = msg.sender;
        maxEpochTime = type(uint256).max;

        // NOTE: we let some loss to avoid getting locked in the position if something goes slightly wrong
        maxPercentageLoss = 1e15; // 0.10%

        tokenA = address(providerA.want());
        tokenB = address(providerB.want());
        tokenC = address(providerC.want());
        require(tokenA != tokenB && tokenB != tokenC && tokenA != tokenC);

        //Approve providers so they can pull during harvests
        IERC20(tokenA).safeApprove(_providerA, type(uint256).max);
        IERC20(tokenB).safeApprove(_providerB, type(uint256).max);
        IERC20(tokenC).safeApprove(_providerC, type(uint256).max);

        //Check if we are using the reference token for easier swaps from rewards
        if (tokenA == _referenceToken || tokenB == _referenceToken || tokenC == _referenceToken) {
            usingReference = true;
        }
    }

    function name() external view virtual returns (string memory);

    /* @notice
     *  Used to change `keeper`.
     *  This may only be called by Vault Gov managment or current keeper.
     * @param _keeper The new address to assign as `keeper`.
     */
    function setKeeper(address _keeper) 
        external 
        onlyVaultManagers 
    {
        keeper = _keeper;
    }

    /*
    * @notice
    * Function available to vault managers to set Tripod parameters.
    *   We combine them all to save byte code
    * @param _dontInvestWant, new booelan value to use
    * @param _minRewardToHarvest, new value to use
    * @param _minAmountToSell, new value to use
    * @param _maxEpochTime, new value to use
    * @param _maxPercentageLoss, new value to use
    * @param _newLaunchHarvest, bool to have keepers launch a harvest
    */
    function setParamaters(
        bool _dontInvestWant,
        uint256 _minRewardToHarvest,
        uint256 _minAmountToSell,
        uint256 _maxEpochTime,
        uint256 _maxPercentageLoss,
        bool _newLaunchHarvest
    ) external onlyVaultManagers {
        dontInvestWant = _dontInvestWant;
        minRewardToHarvest = _minRewardToHarvest;
        minAmountToSell = _minAmountToSell;
        maxEpochTime = _maxEpochTime;
        require(_maxPercentageLoss <= RATIO_PRECISION);
        maxPercentageLoss = _maxPercentageLoss;
        launchHarvest = _newLaunchHarvest;
    }

    /*
    * @notice
    *   External Functions for the keepers to call
    *   Will exit all positions and sell all rewards applicable attempting to rebalance profits
    *   Will then call the harvest function on each Provider to avoid redundant harvests
    *   This only sends funds back if we will not be reinvesting funds
    *   Providers have approval to pull whatever they need
    */
    function harvest() external onlyKeepers {
        if (launchHarvest) {
            launchHarvest = false;
        }

    	//Exits all positions into equal amounts
        _closeAllPositions();

        //Check if we should reopen position
        //If not return all funds
        if(dontInvestWant) {
            _returnLooseToProviders();
        }

        //Harvest all three providers
        providerA.harvest();
        providerB.harvest();
        providerC.harvest();

        //Try and open new position
        //If DontInvestWant == True we should have no funds and this will return;
        _openPosition();
    }

    /*
     * @notice internal function to be called during harvest or by a provider
     *  will pull out of all LP positions, sell all rewards and rebalance back to as even as possible
     *  Will fail if we do not get enough of each asset based on maxPercentLoss
    */
    function _closeAllPositions() internal {
        // Check that we have a position to close
        if (totalLpBalance() == 0) {
            return;
        }

        // 1. CLOSE LIQUIDITY POSITION
        // Closing the position will:
        // - Withdraw from staking contract
        // - Remove liquidity from DEX
        // - Claim pending rewards
        // - Close Hedge and receive payoff
        _closePosition();

        // 2. SELL REWARDS FOR WANT's
        _swapRewardTokens();

        // 3. REBALANCE PORTFOLIO
        // to leave the position with the initial proportions
        _rebalance();

        // Check that we have returned with no losses
        require( 
            balanceOfA() >=
                (invested[tokenA] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!A"
        );
        require(
            balanceOfB() >=
                (invested[tokenB] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!B"
        );
        require(
            balanceOfC() >=
                (invested[tokenC] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!C"
        );

        // reset invested balances
        invested[tokenA] = invested[tokenB] = invested[tokenC] = 0;
        investedWeight[tokenA] = investedWeight[tokenB] = investedWeight[tokenC] = 0;
    }

    /*
     * @notice
     *  Function available for providers to close the tripod position and can then pull funds back
     * provider strategy
     */
    function closeAllPositions() external onlyProviders {
        _closeAllPositions();
        //This is only called during liquidateAllPositions after a strat or vault is shutdown so we should not reinvest
        dontInvestWant = true;
    }
	
    /*
     * @notice
     *  Function called during harvests to open new position:
     * - open the LP position
     * - open the hedge position if necessary
     * - deposit the LPs if necessary
     */
    function _openPosition() internal {
        // No capital, nothing to do
        if (balanceOfA() == 0 || balanceOfB() == 0 || balanceOfC() == 0) {
            return;
        }

        require(
            totalLpBalance() == 0 &&
                invested[tokenA] == 0 &&
                invested[tokenB] == 0 &&
                invested[tokenC] == 0,
                "invested"
        ); // don't create LP if we are already invested

        // Open the LP position
        // Set invested amounts
        (invested[tokenA], invested[tokenB], invested[tokenC]) = _createLP();

        (investedWeight[tokenA], investedWeight[tokenB], investedWeight[tokenC]) =
            TripodMath.getWeights(
                invested[tokenA], 
                invested[tokenB], 
                invested[tokenC]
            );

        // Deposit LPs (if any)
        _depositLP();

        // If there is loose balance, return it
        _returnLooseToProviders();
    }

    /*
     * @notice
     *  Function used by keepers to assess whether to harvest the tripod and compound generated
     * fees into the existing position
     * @param callCost, call cost parameter
     * @return bool, assessing whether to harvest or not
     */
    function harvestTrigger(uint256 /*callCost*/) external view virtual returns (bool) {
        // check if the base fee gas price is higher than we allow. if it is, block harvests.
        if (!isBaseFeeAcceptable()) {
            return false;
        }

        if(launchHarvest) {
            return true;
        }

        if (shouldStartEpoch()) {
            return true;
        }

        //Check if we have assets and are past our max time
        if(totalLpBalance() > 0 &&
            block.timestamp - providerA.vault().strategies(address(providerA)).lastReport > maxEpochTime
        ) {
            return true;
        }

        return false;
    }

    /*
     * @notice
     *  Function used in harvestTrigger in providers to decide wether an epoch can be started or not:
     * - if there is an available for all three tokens but no position open, return true
     * @return wether to start a new epoch or not
     */
    function shouldStartEpoch() public view returns (bool) {
        return TripodMath.shouldStartEpoch();
    }

    /*
    * @notice 
    *  To be called inbetween harvests if applicable
    *  Default will just claim rewards and sell out of them
    *  It will not create a new LP position
    *  Can be overwritten if othe logic is preffered
    */
    function tend() external virtual onlyKeepers {
        //Claim all outstanding rewards
        _getReward();
        //Swap out of all Reward Tokens
        _swapRewardTokens();
    }

    /*
    * @notice
    *   Trigger to tell Keepers if they should call tend()
    *   Defaults to false. Can be implemented in children if needed
    */
    function tendTrigger(uint256 /*callCost*/) external view virtual returns (bool) {
        return false;
    }

    /*
    * @notice
    *   Function to be called during harvests that attempts to rebalance all 3 tokens evenly
    *   in comparision to the amounts the started with, i.e. return the same % return
    */
    function _rebalance() internal {
        (uint8 direction, address token0, address token1, address token2) = TripodMath.rebalance();
        //If direction == 1 we swap one to two
        //if direction == 2 we swap two to one
        //else if its 0 we dont need to swap anything
        if(direction == 1) {
            _swapOneToTwo(token0, token1, token2);
        } else if(direction == 2){
            _swapTwoToOne(token0, token1, token2);
        }
    }

    /*
     * @notice
     *  Function to be called during rebalancing.
     *  This will swap the extra tokens from the one that has returned the highest amount to the other two
     *  in relation to what they need attempting to make everything as equal as possible
     *  The math is all handled by the functions in TripodMath.sol
     *  All minAmountToSell checks will be handled in the swap function
     * @param toSwapToken, the token we will be swapping from to the other two
     * @param token0Address, address of one of the tokens we are swapping to
     * @param token1Address, address of the second token we are swapping to
    */
    function _swapOneToTwo(
        address toSwapToken,
        address token0Address,
        address token1Address
    ) internal {
        uint256 swapTo0;
        uint256 swapTo1;
        
        unchecked {
            uint256 precisionA = 10 ** IERC20Extended(toSwapToken).decimals();
            // n = the amount of toSwapToken to sell
            // p = the percent of n to swap to token0Address repersented as 1e18
            (uint256 n, uint256 p) = TripodMath.getNandP(
                TripodMath.RebalanceInfo({
                    precisionA : precisionA,
                    a0 : invested[toSwapToken],
                    a1 : IERC20(toSwapToken).balanceOf(address(this)),
                    b0 : invested[token0Address],
                    b1 : IERC20(token0Address).balanceOf(address(this)),
                    eOfB : quote(toSwapToken, token0Address, precisionA),
                    precisionB : 0, //Not Needed
                    c0 : invested[token1Address],
                    c1 : IERC20(token1Address).balanceOf(address(this)),
                    eOfC : quote(toSwapToken, token1Address, precisionA),
                    precisionC : 0 //not needed
                }));
            //swapTo0 = the amount to sell * The percent going to 0
            swapTo0 = n * p / RATIO_PRECISION;
            //To assure we dont sell to much 
            swapTo1 = n - swapTo0;
        }
        
        _swap(
            toSwapToken, 
            token0Address, 
            swapTo0,
            0
        );

        _swap(
            toSwapToken, 
            token1Address, 
            swapTo1, 
            0
        );
    }   

    /*
     * @notice
     *  Function to be called during rebalancing.
     *  This will swap the extra tokens from the two that returned raios higher than target return to the other one
     *  in relation to what they gained attempting to make everything as equal as possible
     *  The math is all handled by the functions in TripodMath.sol
     *  All minAmountToSell checks will be handled in the swap function
     * @param token0Address, address of one of the tokens we are swapping from
     * @param token1Address, address of the second token we are swapping from
     * @param toTokenAddress, address of the token we are swapping to
    */
    function _swapTwoToOne(
        address token0Address,
        address token1Address,
        address toTokenAddress
    ) internal {

        (uint256 toSwapFrom0, uint256 toSwapFrom1) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo({
                precisionA : 0, //not needed
                a0 : invested[toTokenAddress],
                a1 : IERC20(toTokenAddress).balanceOf(address(this)),
                b0 : invested[token0Address],
                b1 : IERC20(token0Address).balanceOf(address(this)),
                eOfB : quote(token0Address, toTokenAddress, 10 ** IERC20Extended(token0Address).decimals()),
                precisionB : 10 ** IERC20Extended(token0Address).decimals(),
                c0 : invested[token1Address],
                c1 : IERC20(token1Address).balanceOf(address(this)),
                eOfC : quote(token1Address, toTokenAddress, 10 ** IERC20Extended(token1Address).decimals()),
                precisionC : 10 ** IERC20Extended(token1Address).decimals()
            }));

        _swap(
            token0Address, 
            toTokenAddress, 
            toSwapFrom0, 
            0
        );

        _swap(
            token1Address, 
            toTokenAddress, 
            toSwapFrom1, 
            0
        );
    }

    /*
     * @notice
     *  Function estimating the current assets in the tripod, taking into account:
     * - current balance of tokens in the LP
     * - pending rewards from the LP (if any)
     * - hedge profit (if any)
     * - rebalancing of tokens to maintain token ratios
     * @return estimated tokenA tokenB and tokenC balances
     */
    function estimatedTotalAssetsAfterBalance()
        public
        view
        returns (uint256, uint256, uint256)
    {
        return TripodMath.estimatedTotalAssetsAfterBalance();
    }

    /*
     * @notice
     *  Function available publicly estimating the balance of one of the providers 
     * (one of the tokens). Re-uses the estimatedTotalAssetsAfterBalance function but only uses
     * one the 2 returned values
     * @param _provider, address of the provider of interest
     * @return _balance, balance of the requested provider
     */
    function estimatedTotalProviderAssets(address _provider)
        public
        view
        returns (uint256 _balance)
    {
        if (_provider == address(providerA)) {
            (_balance, , ) = TripodMath.estimatedTotalAssetsAfterBalance();
        } else if (_provider == address(providerB)) {
            (, _balance, ) = TripodMath.estimatedTotalAssetsAfterBalance();
        } else if (_provider == address(providerC)) {
            (, , _balance) = TripodMath.estimatedTotalAssetsAfterBalance();
        }
    }

    function _createLP() internal virtual returns (uint256, uint256, uint256);

    /*
     * @notice
     *  Function used internally to close the LP position: 
     *      - burns the LP liquidity specified amount, all mins are 0
     * @param amount, amount of liquidity to burn
     */
    function _burnLP(uint256 _amount) internal virtual;

    /*
     * @notice
     *  Function used internally to close the LP position: 
     *      - burns the LP liquidity specified amount
     *      - Assures that the min is received
     *  
     * @param amount, amount of liquidity to burn
     * @param minAOut, the min amount of Token A we should receive
     * @param minBOut, the min amount of Token B we should recieve
     * @param minCout, the min amount of Token C we should recieve
     */
    function _burnLP(
        uint256 _amount,
        uint256 minAOut, 
        uint256 minBOut, 
        uint256 minCOut
    ) internal virtual {
        _burnLP(_amount);
        require(minAOut <= balanceOfA() &&
                    minBOut <= balanceOfB() &&
                        minCOut <= balanceOfC(), "min");
    }

    function _getReward() internal virtual;

    function _depositLP() internal virtual;

    function _withdrawLP(uint256 amount) internal virtual;

    /*
     * @notice
     *  Function available internally swapping amounts necessary to swap rewards
     *  This can be overwritten in order to apply custom reward token swaps
     */
    function _swapRewardTokens() internal virtual;

    function _swap(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn,
        uint256 _minOutAmount
    ) internal virtual returns (uint256 _amountOut);

    /*
    * @notice
    *   Internal function to swap the reward tokens into one of the provider tokens
    *   Can be overwritten if different logic is required for reward tokens than provider tokens
    * @param _from, address of the reward token we are swapping from
    * @param _t0, address of the token we are swapping to
    * @param _amount, amount to swap from
    * @param _minOut, minimum out we will accept
    * @returns the amount swapped to
    */
    function _swapReward(
        address _from, 
        address _to, 
        uint256 _amountIn, 
        uint256 _minOut
    ) internal virtual returns (uint256) {
        return _swap(_from, _to, _amountIn, _minOut);
    }

    function quote(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) public view virtual returns (uint256 _amountOut);

    /*
     * @notice
     *  Function available internally closing the tripod postion:
     *  - withdraw LPs (if any)
     *  - close hedging position (if any)
     *  - close LP position 
     * @return balance of each token
     */
    function _closePosition() internal returns (uint256, uint256, uint256) {
        // Unstake LP from staking contract
        _withdrawLP(balanceOfStake());

        if (balanceOfPool() == 0) {
            return (0, 0, 0);
        }

        // **WARNING**: This call is sandwichable, care should be taken
        //              to always execute with a private relay
        // We take care of mins in the harvest logic to assure we account for swaps
        _burnLP(balanceOfPool());

        return (balanceOfA(), balanceOfB(), balanceOfC());
    }

    /*
     * @notice
     *  Function available internally sending back all funds to provuder strategies
     * @return balance of tokenA and tokenB
     */
    function _returnLooseToProviders()
        internal
        returns (uint256 balanceA, uint256 balanceB, uint256 balanceC)
    {
        balanceA = balanceOfA();
        if (balanceA > 0) {
            IERC20(tokenA).safeTransfer(address(providerA), balanceA);
        }

        balanceB = balanceOfB();
        if (balanceB > 0) {
            IERC20(tokenB).safeTransfer(address(providerB), balanceB);
        }

        balanceC = balanceOfC();
        if (balanceC > 0) {
            IERC20(tokenC).safeTransfer(address(providerC), balanceC);
        }
    }

    /*
     * @notice
     *  Function available publicly returning the tripod's balance of tokenA
     * @return balance of tokenA 
     */
    function balanceOfA() public view returns (uint256) {
        return IERC20(tokenA).balanceOf(address(this));
    }

    /*
     * @notice
     *  Function available publicly returning the tripod's balance of tokenB
     * @return balance of tokenB
     */
    function balanceOfB() public view returns (uint256) {
        return IERC20(tokenB).balanceOf(address(this));
    }

    /*
     * @notice
     *  Function available publicly returning the tripod's balance of tokenC
     * @return balance of tokenC
     */
    function balanceOfC() public view returns (uint256) {
        return IERC20(tokenC).balanceOf(address(this));
    }

    /*
    * @notice
    *   Public funtion that will return the total LP balance held by the Tripod
    * @return both the staked and unstaked balances
    */
    function totalLpBalance() public view virtual returns (uint256) {
        unchecked {
            return balanceOfPool() + balanceOfStake();
        }
    }

    /*
    * @notice
    *   Function used return the array of reward Tokens for this Tripod
    */
    function getRewardTokens() public view returns(address[] memory) {
        return rewardTokens;
    }

    function balanceOfPool() public view virtual returns (uint256);


    function balanceOfStake() public view virtual returns (uint256 _balance);

    function balanceOfTokensInLP()
        public
        view
        virtual
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC);

    function pendingRewards() public view virtual returns (uint256[] memory);

    // --- MANAGEMENT FUNCTIONS ---
	/*
     * @notice
     *  Function available to vault managers closing the tripod position manually
     *  This will attempt to rebalance properly after withdraw.
     *  Will set dontInvestWant == True so harvestTriggers dont return true
     * @param expectedBalanceA, expected balance of tokenA to receive
     * @param expectedBalanceB, expected balance of tokenB to receive
     * @param expectedBalanceC, expected balance of tokenC to receive
     */
    function liquidatePositionManually(
        uint256 expectedBalanceA,
        uint256 expectedBalanceB,
        uint256 expectedBalanceC
    ) external onlyVaultManagers {
        dontInvestWant = true;
        uint256 _a = balanceOfA();
        uint256 _b = balanceOfB();
        uint256 _c = balanceOfC();
        _closeAllPositions();
        require(expectedBalanceA <= balanceOfA() - _a &&
                    expectedBalanceB <= balanceOfB() - _b &&
                        expectedBalanceC <= balanceOfC() - _c, "min");
        // reset invested balances or we wont be able to open up a position again
        invested[tokenA] = invested[tokenB] = invested[tokenC] = 0;
        investedWeight[tokenA] = investedWeight[tokenB] = investedWeight[tokenC] = 0;
    }

    /*
     * @notice
     *  Function available to vault managers returning the funds to the providers manually
     */
    function returnLooseToProvidersManually() external onlyVaultManagers {
        _returnLooseToProviders();
    }

    /*
     * @notice
     *  Function available to vault managers closing the LP position manually
     *  Will set dontInvestWant == True so harvestTriggers dont return true
     * @param expectedBalanceA, expected balance of tokenA to receive
     * @param expectedBalanceB, expected balance of tokenB to receive
     * @param expectedBalanceC, expected balance of tokenC to receive
     */
    function removeLiquidityManually(
        uint256 expectedBalanceA,
        uint256 expectedBalanceB,
        uint256 expectedBalanceC
    ) external virtual onlyVaultManagers {
        dontInvestWant = true;
        _withdrawLP(balanceOfStake());
        //Burn lp will handle min Out checks
        _burnLP(
            balanceOfPool(),
            expectedBalanceA,
            expectedBalanceB,
            expectedBalanceC
        );

        // reset invested balances or we wont be able to open up a position again
        invested[tokenA] = invested[tokenB] = invested[tokenC] = 0;
        investedWeight[tokenA] = investedWeight[tokenB] = investedWeight[tokenC] = 0;
    }

    /*
    * @notice
    *   External function available to vault Managers to swap tokens manually
    *   This function should be implemented with at least an onlyVaultManagers modifier
    *       assuming swap logic checks the address parameters are legit, or onlyGovernance if
    *        those checks are not in place
    * @param tokenFrom, the token we will be swapping from
    * @param tokenTo, the token we will be swapping to
    * @param swapInAmount, the amount to swap from
    * @param minOutAmount, the min of tokento we will accept
    * @param core, bool repersenting if we are swapping the 3 provider tokens on both sides of the trade
    */
    function swapTokenForTokenManually(
        address tokenFrom,
        address tokenTo,
        uint256 swapInAmount,
        uint256 minOutAmount,
        bool core
    ) external virtual returns (uint256);

    /*
     * @notice
     *  Function available to governance sweeping a specified token but not tokenA B or C
     * @param _token, address of the token to sweep
     */
    function sweep(address _token) external onlyGovernance {
        require(_token != tokenA && _token != tokenB && _token != tokenC);

        SafeERC20.safeTransfer(
            IERC20(_token),
            providerA.vault().governance(),
            IERC20(_token).balanceOf(address(this))
        );
    }

    /*
     * @notice
     *  Function available to providers to change the provider addresses
     *  will decrease the allowance for old and increase for new for applicable token
     * @param _newProvider, new address of provider
     */
    function migrateProvider(address _newProvider) external onlyProviders {
        IProviderStrategy newProvider = IProviderStrategy(_newProvider);
        address providerWant = address(newProvider.want());
        if (providerWant == tokenA) {
            IERC20(tokenA).safeApprove(address(providerA), 0);
            IERC20(tokenA).safeApprove(_newProvider, type(uint256).max);
            providerA = newProvider;
        } else if (providerWant == tokenB) {
            IERC20(tokenB).safeApprove(address(providerB), 0);
            IERC20(tokenB).safeApprove(_newProvider, type(uint256).max);
            providerB = newProvider;
        } else if(providerWant == tokenC) {
            IERC20(tokenC).safeApprove(address(providerC), 0);
            IERC20(tokenC).safeApprove(_newProvider, type(uint256).max);
            providerC = newProvider;
        } else {
            revert("!token");
        }
    }

    /*
     * @notice
     *  Internal function checking if allowance is already enough for the contract
     * and if not, safely sets it to max
     * @param _contract, spender contract
     * @param _token, token to approve spend
     * @param _amount, _amoun to approve
     */
    function _checkAllowance(
        address _contract,
        IERC20 _token,
        uint256 _amount
    ) internal {
        if (_token.allowance(address(this), _contract) < _amount) {
            _token.safeApprove(_contract, 0);
            _token.safeApprove(_contract, type(uint256).max);
        }
    }

    // check if the current baseFee is below our external target
    function isBaseFeeAcceptable() internal view returns (bool) {
        return
            IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F)
                .isCurrentBaseFeeAcceptable();
    }
}