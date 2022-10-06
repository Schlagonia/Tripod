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

interface ProviderStrategy {
    function vault() external view returns (IVault);

    function keeper() external view returns (address);

    function want() external view returns (address);

    function balanceOfWant() external view returns (uint256);

    function harvest() external;
}

interface IFeedRegistry {
    function getFeed(address, address) external view returns (address);
    function latestRoundData(address, address) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

/// @title Tripod
/// @notice This is the base contract for a 3 token joint LP strategy to be used with @Yearn vaults
///     The contract takes tokens from 3 seperate Provider strategies each with a different token that corresponds to one of the tokens that
///     makes up the LP of "pool". Each harvest the Tripod will attempt to rebalance each token into an equal relative return percentage wise
///     irrespecative of the begining weights, exchange rates or decimal differences. 
///
///     Made by Schlagania https://github.com/Schlagonia/Tripod adapted from the 2 token joint strategy https://github.com/fp-crypto/joint-strategy
///
abstract contract Tripod {
    using SafeERC20 for IERC20;
    using Address for address;

    // Constant to use in ratio calculations
    uint256 internal constant RATIO_PRECISION = 1e18;
    // Provider strategy of tokenA
    ProviderStrategy public providerA;
    // Provider strategy of tokenB
    ProviderStrategy public providerB;
    // Provider strategy of tokenC
    ProviderStrategy public providerC;

    // Address of tokenA
    address public tokenA;
    // Address of tokenB
    address public tokenB;
    // Address of tokenC
    address public tokenC;

    // Reference token to use in swaps: WETH, WFTM...
    address public referenceToken;
    // Bool repersenting if one of the tokens is == referencetoken
    bool internal usingReference;
    // Array containing reward tokens
    address[] public rewardTokens;

    // Address of the pool to LP
    address public pool;

    //Mapping of the Amounts that actually go into the LP position
    mapping(address => uint256) public invested;
    //Mapping og the weights of each token when it goes in to 1e18
    mapping(address => uint256) public investedWeight;

    //Address of the Keeper for this strategy
    address public keeper;

    //Bool manually set to determine wether we should harvest
    bool public launchHarvest;
    // Boolean values protecting against re-investing into the pool
    bool public dontInvestWant;
    bool public autoProtectionDisabled;

    // Thresholds to operate the strat
    uint256 public minAmountToSell;
    uint256 public maxPercentageLoss;
    uint256 public minRewardToHarvest;
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
        require(isKeeper() || isGovernance() || isVaultManager(), "!authorized");
    }

    function checkGovernance() internal view {
        require(isGovernance(), "!authorized");
    }

    function checkVaultManagers() internal view {
        require(isGovernance() || isVaultManager(), "!authorized");
    }

    function checkProvider() internal view {
        require(isProvider(), "!authorized");
    }

    function isGovernance() internal view returns (bool) {
        return
            msg.sender == providerA.vault().governance() ||
            msg.sender == providerB.vault().governance() ||
            msg.sender == providerC.vault().governance();
    }

    function isVaultManager() internal view returns (bool) {
        return
            msg.sender == providerA.vault().management() ||
            msg.sender == providerB.vault().management() ||
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
        require(address(providerA) == address(0), "tripod already initialized");
        providerA = ProviderStrategy(_providerA);
        providerB = ProviderStrategy(_providerB);
        providerC = ProviderStrategy(_providerC);

        referenceToken = _referenceToken;
        pool = _pool;
        keeper = msg.sender;
        maxEpochTime = type(uint256).max;

        // NOTE: we let some loss to avoid getting locked in the position if something goes slightly wrong
        maxPercentageLoss = RATIO_PRECISION / 1_000; // 0.10%

        tokenA = address(providerA.want());
        tokenB = address(providerB.want());
        tokenC = address(providerC.want());
        require(tokenA != tokenB && tokenB != tokenC && tokenA != tokenC, "!same-want");

        //Approve providers so they can pull during harvests
        IERC20(tokenA).safeApprove(_providerA, type(uint256).max);
        IERC20(tokenB).safeApprove(_providerB, type(uint256).max);
        IERC20(tokenC).safeApprove(_providerC, type(uint256).max);

        //Check if we are using the reference token for easier swaps from rewards
        if (tokenA == referenceToken || tokenB == referenceToken || tokenC == referenceToken) {
            usingReference = true;
        } else {
            usingReference = false;
        }
    }

    function name() external view virtual returns (string memory);

    function shouldEndEpoch() public view virtual returns (bool);

    function _autoProtect() internal view virtual returns (bool);

    /*
     * @notice
     *  Check wether a token address is part of rewards or not
     * @param token, token address to check
     * @return wether the provided token address is a reward for the strat or not
     */
    function _isReward(address token) internal view returns (bool) {
        address[] memory _rewardTokens = rewardTokens;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            if (_rewardTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

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
     *  Function available for vault managers to set the boolean value deciding wether
     * to re-invest into the LP or not
     * @param _dontInvestWant, new booelan value to use
     */
    function setDontInvestWant(bool _dontInvestWant)
        external
        onlyVaultManagers
    {
        dontInvestWant = _dontInvestWant;
    }

    /*
     * @notice
     *  Function available for vault managers to set the minimum reward to harvest
     * @param _minRewardToHarvest, new value to use
     */
    function setMinRewardToHarvest(uint256 _minRewardToHarvest)
        external
        onlyVaultManagers
    {
        minRewardToHarvest = _minRewardToHarvest;
    }

    /*
     * @notice
     *  Function available for vault managers to set the minimum amount to sell
     * @param _minAmountToSell, new value to use
     */
    function setMinAmountToSell(uint256 _minAmountToSell)
        external
        onlyVaultManagers
    {
        minAmountToSell = _minAmountToSell;
    }

    /*
     * @notice
     *  Function available for vault managers to set the max time between harvests
     * @param _maxEpochTime, new value to use
     */
    function setMaxEpochTime(uint256 _maxEpochTime)
        external
        onlyVaultManagers
    {
        maxEpochTime = _maxEpochTime;
    }

    /*
     * @notice
     *  Function available for vault managers to set the auto protection
     * @param _autoProtectionDisabled, new value to use
     */
    function setAutoProtectionDisabled(bool _autoProtectionDisabled)
        external
        onlyVaultManagers
    {
        autoProtectionDisabled = _autoProtectionDisabled;
    }

    /*
     * @notice
     *  Function available for vault managers to set the maximum allowed loss
     * @param _maxPercentageLoss, new value to use
     */
    function setMaxPercentageLoss(uint256 _maxPercentageLoss)
        external
        onlyVaultManagers
    {
        require(_maxPercentageLoss <= RATIO_PRECISION, "too Big");
        maxPercentageLoss = _maxPercentageLoss;
    }

    /*
    * @notice
    * External function for vault managers to set launchHarvest
    */
    function setLaunchHarvest(bool _newLaunchHarvest) 
        external 
        onlyVaultManagers 
    {
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
        // Check if it needs to stop starting new epochs after finishing this one.
        // _autoProtect is implemented in children
        if (_autoProtect() && !autoProtectionDisabled) {
            dontInvestWant = true;
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
        swapRewardTokens();

        // 3. REBALANCE PORTFOLIO
        // to leave the position with the initial proportions
        rebalance();

        // Check that we have returned with no losses
        require( 
            balanceOfA() >=
                (invested[tokenA] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceA"
        );
        require(
            balanceOfB() >=
                (invested[tokenB] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceB"
        );
        require(
            balanceOfC() >=
                (invested[tokenC] *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceC"
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
                "already invested"
        ); // don't create LP if we are already invested

        // Open the LP position
        (uint256 amountA, uint256 amountB, uint256 amountC) = createLP();
        // Open hedge
        (uint256 costHedgeA, uint256 costHedgeB, uint256 costHedgeC) = hedgeLP();

        // Set invested amounts
        invested[tokenA] = amountA + costHedgeA;
        invested[tokenB] = amountB + costHedgeB;
        invested[tokenC] = amountC + costHedgeC;

        (investedWeight[tokenA], investedWeight[tokenB], investedWeight[tokenC]) =
            getWeights(invested[tokenA], invested[tokenB], invested[tokenC]);

        // Deposit LPs (if any)
        depositLP();

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
        
        if (shouldEndEpoch()) {
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
    *   function used internally to determine if a provider has funds available to deposit
    *   Checks the providers want balance of the Tripod, the provider and the credit available to it
    * @param _provider, the provider to check
    */  
    function hasAvailableBalance(ProviderStrategy _provider) 
        internal 
        view 
        returns (bool) 
    {
        return 
            _provider.balanceOfWant() > minAmountToSell ||
                IERC20(_provider.want()).balanceOf(address(this)) > minAmountToSell ||
                    _provider.vault().creditAvailable(address(_provider)) > minAmountToSell;
    }

    /*
     * @notice
     *  Function used in harvestTrigger in providers to decide wether an epoch can be started or not:
     * - if there is an available for all three tokens but no position open, return true
     * @return wether to start a new epoch or not
     */
    function shouldStartEpoch() public view returns (bool) {
        //If we are currently invested return false
        if(invested[tokenA] != 0 ||
            invested[tokenB] != 0 || 
                invested[tokenC] != 0) return false;
        
        if(dontInvestWant) return false;

        return
            hasAvailableBalance(providerA) && 
                hasAvailableBalance(providerB) && 
                    hasAvailableBalance(providerC);
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
        getReward();
        //Swap out of all Reward Tokens
        swapRewardTokens();
    }

    /*
    * @notice
    *   Trigger to tell Keepers if they should call tend()
    *   Defaults to false. Can be implemented in children if needed
    */
    function tendTrigger(uint256 /*callCost*/) external view virtual returns (bool) {
        return false;
    }

    function getHedgeProfit() public view virtual returns (uint256, uint256, uint256);

    /*
    * @notice
    *   Function to be called during harvests that attempts to rebalance all 3 tokens evenly
    *   in comparision to the amounts the started with, i.e. return the same % return
    */
    function rebalance() internal {
        (uint256 ratioA, uint256 ratioB, uint256 ratioC) = getRatios(
                    balanceOfA(),
                    balanceOfB(),
                    balanceOfC()
                );
    
        //If they are all the same or very close we dont need to do anything
        if(isCloseEnough(ratioA, ratioB) && isCloseEnough(ratioB, ratioC)) return;

        // Calculate the weighted average ratio. Could be at a loss does not matter here
        uint256 avgRatio;
        unchecked{
            avgRatio = (ratioA * investedWeight[tokenA] + ratioB * investedWeight[tokenB] + ratioC * investedWeight[tokenC]) / RATIO_PRECISION;
        }

        //If only one is higher than the average ratio, then ratioX - avgRatio is split between the other two in relation to their diffs
        //If two are higher than the average each has its diff traded to the third
        //We know all three cannot be above the avg
        //This flow allows us to keep track of exactly what tokens need to be swapped from and to 
        //as well as how much with little extra memory/storage used and a max of 3 if() checks
        if(ratioA > avgRatio) {

            if (ratioB > avgRatio) {
                //Swapping A and B -> C
                swapTwoToOne(tokenA, tokenB, tokenC);
            } else if (ratioC > avgRatio) {
                //swapping A and C -> B
                swapTwoToOne(tokenA, tokenC, tokenB);
            } else {
                //Swapping A -> B and C
                swapOneToTwo(tokenA, tokenB, tokenC);
            }
            
        } else if (ratioB > avgRatio) {
            //We know A is below avg so we just need to check C
            if (ratioC > avgRatio) {
                //Swap B and C -> A
                swapTwoToOne(tokenB, tokenC, tokenA);
            } else {
                //swapping B -> C and A
                swapOneToTwo(tokenB, tokenA, tokenC);
            }

        } else {
            //We know A and B are below so C has to be the only one above the avg
            //swap C -> A and B
            swapOneToTwo(tokenC, tokenA, tokenB);
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
    function swapOneToTwo(
        address toSwapToken,
        address token0Address,
        address token1Address
    ) internal {
        uint256 swapTo0;
        uint256 swapTo1;
        
        unchecked {
            uint256 precision = 10 ** IERC20Extended(toSwapToken).decimals();
            // n = the amount of toSwapToken to sell
            // p = the percent of n to swap to token0Address repersented as 1e18
            (uint256 n, uint256 p) = TripodMath.getNandP(
                TripodMath.RebalanceInfo(
                    precision,
                    invested[toSwapToken],
                    IERC20(toSwapToken).balanceOf(address(this)),
                    invested[token0Address],
                    IERC20(token0Address).balanceOf(address(this)),
                    quote(toSwapToken, token0Address, precision),
                    0,
                    invested[token1Address],
                    IERC20(token1Address).balanceOf(address(this)),
                    quote(toSwapToken, token1Address, precision),
                    0
                ));
            //swapTo0 = the amount to sell * The percent going to 0
            swapTo0 = n * p / RATIO_PRECISION;
            //To assure we dont sell to much 
            swapTo1 = n - swapTo0;
        }
        
        swap(
            toSwapToken, 
            token0Address, 
            swapTo0,
            0
        );

        swap(
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
    function swapTwoToOne(
        address token0Address,
        address token1Address,
        address toTokenAddress
    ) internal {

        (uint256 toSwapFrom0, uint256 toSwapFrom1) = TripodMath.getNbAndNc(
            TripodMath.RebalanceInfo(
                0,
                invested[toTokenAddress],
                IERC20(toTokenAddress).balanceOf(address(this)),
                invested[token0Address],
                IERC20(token0Address).balanceOf(address(this)),
                quote(token0Address, toTokenAddress, 10 ** IERC20Extended(token0Address).decimals()),
                10 ** IERC20Extended(token0Address).decimals(),
                invested[token1Address],
                IERC20(token1Address).balanceOf(address(this)),
                quote(token1Address, toTokenAddress, 10 ** IERC20Extended(token1Address).decimals()),
                10 ** IERC20Extended(token1Address).decimals()
        ));

        swap(
            token0Address, 
            toTokenAddress, 
            toSwapFrom0, 
            0
        );

        swap(
            token1Address, 
            toTokenAddress, 
            toSwapFrom1, 
            0
        );
    }

    /*
    * @notice
    *   Function used to determine wether or not the ratios between the 3 tokens are close enough 
    *       that it is not worth the cost to do any rebalancing
    * @param ratio0, the current ratio of the first token to check
    * @param ratio1, the current ratio of the second token to check
    * @return boolean repersenting true if the ratios are withen the range to not need to rebalance 
    */
    function isCloseEnough(uint256 ratio0, uint256 ratio1) public view returns(bool) {
        if(ratio0 == 0 && ratio1 ==0) return true;

        uint256 delta = ratio0 > ratio1 ? ratio0 - ratio1 : ratio1 - ratio0;
        //We use one lower decimal than our maxPercent loss. So if maxPercentLoss == .1 we wont rebalance withen .01
        uint256 maxRelDelta = ratio1 / (RATIO_PRECISION / (maxPercentageLoss / 10));

        if (delta < maxRelDelta) return true;
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
        // Current status of tokens in LP (includes potential IL)
        (uint256 _aBalance, uint256 _bBalance, uint256 _cBalance) = balanceOfTokensInLP();
        // Include hedge payoffs
        (uint256 aProfit, uint256 bProfit, uint256 cProfit) = getHedgeProfit();

        // Add remaining balance in tripod (if any)
        unchecked{
            _aBalance += balanceOfA() + aProfit;
            _bBalance += balanceOfB() + bProfit;
            _cBalance += balanceOfC() + cProfit;
        }

        // Include rewards (swapping them if not tokenA or tokenB)
        uint256[] memory _rewardsPending = pendingRewards();
        address[] memory _rewardTokens = rewardTokens;
        address reward;
        for (uint256 i = 0; i < _rewardsPending.length; i++) {
            reward = _rewardTokens[i];
            if (reward == tokenA) {
                _aBalance += _rewardsPending[i];
            } else if (reward == tokenB) {
                _bBalance += _rewardsPending[i];
            } else if (reward == tokenC) {
                _cBalance += _rewardsPending[i];
            } else if (_rewardsPending[i] != 0) {
                //If we are using the reference token swap to that otherwise use A
                address swapTo = usingReference ? referenceToken : tokenA;
                uint256 outAmount = quote(
                    reward,
                    swapTo,
                    _rewardsPending[i]
                );

                if (swapTo == tokenA) { 
                    _aBalance += outAmount;
                } else if (swapTo == tokenB) {
                    _bBalance += outAmount;
                } else if (swapTo == tokenC) {
                    _cBalance += outAmount;
                }
            }
        }
        return quoteRebalance(_aBalance, _bBalance, _cBalance);
    }

    /*
    * @notice 
    *    This function is a fucking disaster.
    *    But it works...
    */
    function quoteRebalance(
        uint256 startingA,
        uint256 startingB,
        uint256 startingC
    ) internal view returns(uint256, uint256, uint256) {
        //We cannot rebalance with a 0 starting position, should only be applicable if called when everything is 0 so just return
        if(invested[tokenA] == 0 || invested[tokenB] == 0 || invested[tokenC] == 0) {
            return (startingA, startingB, startingC);
        }

        (uint256 ratioA, uint256 ratioB, uint256 ratioC) = getRatios(
                    startingA,
                    startingB,
                    startingC
                );
        
        //If they are all the same or very close we dont need to do anything
        if(isCloseEnough(ratioA, ratioB) && isCloseEnough(ratioB, ratioC)) {
            return(startingA, startingB, startingC);
        }
        // Calculate the average ratio. Could be at a loss does not matter here
        uint256 avgRatio;
        unchecked{
            avgRatio = (ratioA * investedWeight[tokenA] + ratioB * investedWeight[tokenB] + ratioC * investedWeight[tokenC]) / RATIO_PRECISION;
        }

        uint256 change0;
        uint256 change1;
        uint256 change2;
        TripodMath.RebalanceInfo memory info;
        //See Rebalance() for explanation
        if(ratioA > avgRatio) {
            if (ratioB > avgRatio) {
                //Swapping A and B -> C
                info = TripodMath.RebalanceInfo(0, 0, startingC, 0, startingA, 0, 0, 0, startingB, 0, 0);
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(info, tokenA, tokenB, tokenC);
                return ((startingA - change0), 
                            (startingB - change1), 
                                (startingC + change2));
            } else if (ratioC > avgRatio) {
                //swapping A and C -> B
                info = TripodMath.RebalanceInfo(0, 0, startingB, 0, startingA, 0, 0, 0, startingC, 0, 0);
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(info, tokenA, tokenC, tokenB);
                return ((startingA - change0), 
                            (startingB + change2), 
                                (startingC - change1));
            } else {
                //Swapping A -> B and C
                info = TripodMath.RebalanceInfo(0, 0, startingA, 0, startingB, 0, 0, 0, startingC, 0, 0);
                (change0, change1, change2) = 
                    quoteSwapOneToTwo(info, tokenA, tokenB, tokenC);
                return ((startingA - change0), 
                            (startingB + change1), 
                                (startingC + change2));
            }
        } else if (ratioB > avgRatio) {
            //We know A is below avg so we just need to check C
            if (ratioC > avgRatio) {
                //Swap B and C -> A
                info = TripodMath.RebalanceInfo(0, 0, startingA, 0, startingB, 0, 0, 0, startingC, 0, 0);
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(info, tokenB, tokenC, tokenA);
                return ((startingA + change2), 
                            (startingB - change0), 
                                (startingC - change1));
            } else {
                //swapping B -> A and C
                info = TripodMath.RebalanceInfo(0, 0, startingB, 0, startingA, 0, 0, 0, startingC, 0, 0);
                (change0, change1, change2) = 
                    quoteSwapOneToTwo(info, tokenB, tokenA, tokenC);
                return ((startingA + change1), 
                            (startingB - change0), 
                                (startingC + change2));
            }
        } else {
            //We know A and B are below so C has to be the only one above the avg
            //swap C -> A and B
            info = TripodMath.RebalanceInfo(0, 0, startingC, 0, startingA, 0, 0, 0, startingB, 0, 0);
            (change0, change1, change2) = 
                quoteSwapOneToTwo(info, tokenC, tokenA, tokenB);
            return ((startingA + change1), 
                        (startingB + change2), 
                            (startingC - change0));
        }   
    }

    /*
     * @notice
     *  Function to be called during mock rebalancing.
     *  This will quote swapping the extra tokens from the one that has returned the highest amount to the other two
     *  in relation to what they need attempting to make everything as equal as possible
     *  will return the absolute changes expected for each token, accounting will take place in parent function
     * @param info, struct of all needed info OF token addresses and amounts
     * @param toSwapToken, the token we will be swapping from to the other two
     * @param token0Address, address of one of the tokens we are swapping to
     * @param token1Address, address of the second token we are swapping to
     * @return negative change in toSwapToken, positive change for token0, positive change for token1
    */
    function quoteSwapOneToTwo(
        TripodMath.RebalanceInfo memory info, 
        address toSwapFrom, 
        address toSwapTo0, 
        address toSwapTo1
    ) internal view returns (uint256 n, uint256 amountOut, uint256 amountOut2) {
        uint256 swapTo0;
        uint256 swapTo1;

        unchecked {
            uint256 precision = 10 ** IERC20Extended(toSwapFrom).decimals();
            
            info = TripodMath.RebalanceInfo(
                precision,
                invested[toSwapFrom],
                info.a1,
                invested[toSwapTo0],
                info.b1,
                quote(toSwapFrom, toSwapTo0, precision),
                0,
                invested[toSwapTo1],
                info.c1,
                quote(toSwapFrom, toSwapTo1, precision),
                0
            );

            uint256 p;

            (n, p) = TripodMath.getNandP(info);

            swapTo0 = n * p / RATIO_PRECISION;
            //To assure we dont sell to much 
            swapTo1 = n - swapTo0;
        }

        amountOut = quote(
            toSwapFrom, 
            toSwapTo0, 
            swapTo0
        );

        amountOut2 = quote(
            toSwapFrom, 
            toSwapTo1, 
            swapTo1
        );
    }   

    /*
     * @notice
     *  Function to be called during rebalancing.
     *  This will swap the extra tokens from the two that returned raios higher than target return to the other one
     *  in relation to what they gained attempting to make everything as equal as possible
     *  will return the absolute changes expected for each token, accounting will take place in parent function
     * @param info, struct of all needed info OF token addresses and amounts
     * @param token0Address, address of one of the tokens we are swapping from
     * @param token1Address, address of the second token we are swapping from
     * @param toTokenAddress, address of the token we are swapping to
     * @return negative change for token0, negative change for token1, positive change for toTokenAddress
    */
    function quoteSwapTwoToOne(
        TripodMath.RebalanceInfo memory info,
        address token0Address,
        address token1Address,
        address toTokenAddress
    ) internal view returns(uint256, uint256, uint256) {

        info = TripodMath.RebalanceInfo(
            0,
            invested[toTokenAddress],
            info.a1,
            invested[token0Address],
            info.b1,
            quote(token0Address, toTokenAddress, 10 ** IERC20Extended(token0Address).decimals()),
            10 ** IERC20Extended(token0Address).decimals(),
            invested[token1Address],
            info.c1,
            quote(token1Address, toTokenAddress, 10 ** IERC20Extended(token1Address).decimals()),
            10 ** IERC20Extended(token1Address).decimals()
        );

        (uint256 toSwapFrom0, uint256 toSwapFrom1) = TripodMath.getNbAndNc(info);

        uint256 amountOut = quote(
            token0Address, 
            toTokenAddress, 
            toSwapFrom0
        );

        uint256 amountOut2 = quote(
            token1Address, 
            toTokenAddress, 
            toSwapFrom1
        );

        return (toSwapFrom0, toSwapFrom1, (amountOut + amountOut2));
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
            (_balance, , ) = estimatedTotalAssetsAfterBalance();
        } else if (_provider == address(providerB)) {
            (, _balance, ) = estimatedTotalAssetsAfterBalance();
        } else if (_provider == address(providerC)) {
            (, , _balance) = estimatedTotalAssetsAfterBalance();
        }
    }

    function getHedgeBudget(address token)
        public
        view
        virtual
        returns (uint256);

    function hedgeLP() internal virtual returns (uint256, uint256, uint256);

    function closeHedge() internal virtual;

    /*
     * @notice
     *  Function available publicly estimating the balancing ratios for the tokens in the form:
     * ratio = currentBalance / invested Balance
     * @param currentA, current balance of tokenA
     * @param currentB, current balance of tokenB
     * @param currentC, current balance of tokenC
     * @return _a, _b _c, ratios for tokenA tokenB and tokenC. Will return 0's if there is nothing invested
     */
    function getRatios(
        uint256 currentA,
        uint256 currentB,
        uint256 currentC
    ) public view returns (uint256 _a, uint256 _b, uint256 _c) {
        if(invested[tokenA] == 0 || invested[tokenB] == 0 || invested[tokenC] == 0) {
            return (0, 0, 0);
        }
        unchecked {
            _a = (currentA * RATIO_PRECISION) / invested[tokenA];
            _b = (currentB * RATIO_PRECISION) / invested[tokenB];
            _c = (currentC * RATIO_PRECISION) / invested[tokenC];
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
        uint256 investedA,
        uint256 investedB,
        uint256 investedC
    ) internal view returns (uint256 wA, uint256 wB, uint256 wC) {
        unchecked {
            uint256 adjustedA = getOraclePrice(tokenA, investedA);
            uint256 adjustedB = getOraclePrice(tokenB, investedB);
            uint256 adjustedC = getOraclePrice(tokenC, investedC);
            uint256 total = adjustedA + adjustedB + adjustedC; 
                        
            wA = adjustedA * RATIO_PRECISION / total;
            wB = adjustedB * RATIO_PRECISION / total;
            wC = adjustedC * RATIO_PRECISION / total;
        }
    }

    /*
    * @notice
    *   Returns the oracle adjusted price for a specific token and amount expressed in the oracle terms of 1e8
    *   This uses the chainlink feed Registry and returns in terms of the USD
    * @param _token, the address of the token to get the price for
    * @param _amount, the amount of the token we have
    * @return USD price of the _amount of the token as 1e8
    */
    function getOraclePrice(address _token, uint256 _amount) public view returns(uint256) {
        address token = _token;
        //Adjust if we are using WETH of WBTC for chainlink to work
        if(_token == referenceToken) token = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        if(_token == 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) token = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

        (uint80 roundId, int256 price,, uint256 updateTime, uint80 answeredInRound) = IFeedRegistry(0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf).latestRoundData(
                token,
                address(0x0000000000000000000000000000000000000348) // USD
            );

        require(price > 0, "Chainlink price <= 0");
        require(updateTime != 0, "Incomplete round");
        require(answeredInRound >= roundId, "Stale price");
        //return the dollar amount to 1e8
        return uint256(price) * _amount / (10 ** IERC20Extended(_token).decimals());
    }

    function createLP() internal virtual returns (uint256, uint256, uint256);

    /*
     * @notice
     *  Function used internally to close the LP position: 
     *      - burns the LP liquidity specified amount, all mins are 0
     * @param amount, amount of liquidity to burn
     */
    function burnLP(uint256 _amount) internal virtual;

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
    function burnLP(
        uint256 _amount,
        uint256 minAOut, 
        uint256 minBOut, 
        uint256 minCOut
    ) internal virtual {
        burnLP(_amount);
        require(minAOut <= balanceOfA(), "!sandwiched");
        require(minBOut <= balanceOfB(), "!sandwiched");
        require(minCOut <= balanceOfC(), "!sandwiched");
    }

    function getReward() internal virtual;

    function depositLP() internal virtual;

    function withdrawLP(uint256 amount) internal virtual;

    /*
     * @notice
     *  Function available internally swapping amounts necessary to swap rewards
     *  This can be overwritten in order to apply custom reward token swaps
     */
    function swapRewardTokens() internal virtual {
        address _tokenA = tokenA;
        address _tokenB = tokenB;
        address _tokenC = tokenC;
        address[] memory _rewardTokens = rewardTokens;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            address reward = _rewardTokens[i];
            uint256 _rewardBal = IERC20(reward).balanceOf(address(this));
            // If the reward token is either A B or C, don't swap
            if (reward == _tokenA || reward == _tokenB || reward == _tokenC || _rewardBal == 0) {
                continue;
            // If the referenceToken is either A B or C, swap rewards against it 
            } else if (usingReference) {
                    swapReward(reward, referenceToken, _rewardBal, 0); 
            } else {
                // Assume that position has already been liquidated
                //Instead this should just return the token with the lowest ratio
                (uint256 ratioA, uint256 ratioB, uint256 ratioC) = getRatios(
                    balanceOfA(),
                    balanceOfB(),
                    balanceOfC()
                );
       
                //If everything is equal use A   
                if(ratioA <= ratioB && ratioA <= ratioC) {
                    swapReward(reward, _tokenA, _rewardBal, 0);
                } else if(ratioB <= ratioC) {
                    swapReward(reward, _tokenB, _rewardBal, 0);
                } else {
                    swapReward(reward, _tokenC, _rewardBal, 0);
                }
            }
        }
    }

    function swap(
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
    function swapReward(
        address _from, 
        address _to, 
        uint256 _amountIn, 
        uint256 _minOut
    ) internal virtual returns (uint256) {
        return swap(_from, _to, _amountIn, _minOut);
    }

    function quote(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) internal view virtual returns (uint256 _amountOut);

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
        withdrawLP(balanceOfStake());

        // Close the hedge
        closeHedge();

        if (balanceOfPool() == 0) {
            return (0, 0, 0);
        }

        // **WARNING**: This call is sandwichable, care should be taken
        //              to always execute with a private relay
        // We take care of mins in the harvest logic to assure we account for swaps
        burnLP(balanceOfPool());

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

    /*
    * @notice
    *   Public function return the amount of reward tokens we currently have
    */
    function getRewardTokensLength() public view returns(uint256) {
        return rewardTokens.length;
    }

    function balanceOfPool() public view virtual returns (uint256);

    /*
     * @notice
     *  Function available publicly returning the tripod's balance of rewards
     * @return array of balances
     */
    function balanceOfRewardToken() public view returns (uint256[] memory) {
        address[] memory _rewardTokens = rewardTokens;
        uint256 length = _rewardTokens.length;
        uint256[] memory _balances = new uint256[](length);
        for (uint8 i = 0; i < length; i++) {
            _balances[i] = IERC20(_rewardTokens[i]).balanceOf(address(this));
        }
        return _balances;
    }

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
        require(expectedBalanceA <= balanceOfA() - _a, "!sandwiched");
        require(expectedBalanceB <= balanceOfB() - _b, "!sandwiched");
        require(expectedBalanceC <= balanceOfC() - _c, "!sandwiched");
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
        withdrawLP(balanceOfStake());
        //Burn lp will handle min Out checks
        burnLP(
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
        require(_token != tokenA, "TokenA");
        require(_token != tokenB, "TokenB");
        require(_token != tokenC, "TokenC");

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
        ProviderStrategy newProvider = ProviderStrategy(_newProvider);
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
            revert("Unsupported token");
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