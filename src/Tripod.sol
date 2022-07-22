// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IERC20Extended.sol";

import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";

interface ProviderStrategy {
    function vault() external view returns (VaultAPI);

    function strategist() external view returns (address);

    function keeper() external view returns (address);

    function want() external view returns (address);

    function totalDebt() external view returns (uint256);

    function harvest() external;

    function launchHarvest() external view returns (bool);
}

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

abstract contract Tripod {
    using SafeERC20 for IERC20;
    using Address for address;
    // Constant to use in ratio calculations
    uint256 internal constant RATIO_PRECISION = 1e18;
    // Provider strategy of tokenA
    ProviderStrategy public providerA;
    // Provider strategy of tokenB
    ProviderStrategy public providerB;
    // Provider strategy of TokenC
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
     *  Constructor equivalent for clones, initializing the joint and the specifics of UniV3Joint
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
        require(address(providerA) == address(0), "Joint already initialized");
        providerA = ProviderStrategy(_providerA);
        providerB = ProviderStrategy(_providerB);
        providerC = ProviderStrategy(_providerC);
        referenceToken = _referenceToken;
        pool = _pool;
        keeper = msg.sender;

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

    /*
     * @notice
     *  Function used in harvestTrigger in providers to decide wether an epoch can be started or not:
     * - if there is balance of tokens but no position open, return true
     * @return wether to start a new epoch or not
     */
    function shouldStartEpoch() public view returns (bool) {
        // return true if we have balance of A B and C while the position is closed
        return
            (balanceOfA() > 0 && balanceOfB() > 0 && balanceOfC() > 0) &&
            (invested[tokenA] == 0 &&
            invested[tokenB] == 0 &&
            invested[tokenC] == 0);
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
        require(_maxPercentageLoss <= RATIO_PRECISION, "To Big");
        maxPercentageLoss = _maxPercentageLoss;
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
        if (balanceOfPool() == 0 && balanceOfStake() == 0) {
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
    }

    /*
     * @notice
     *  Function available for providers to close the joint position and can then pull funds back
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
            balanceOfStake() == 0 &&
                balanceOfPool() == 0 &&
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

        // Deposit LPs (if any)
        depositLP();

        // If there is loose balance, return it
        _returnLooseToProviders();
    }

    /*
    * @notice
    * External function for vault managers to set launchHarvest
    */
    function setLaunchHarvest(bool _newLaunchHarvest) external onlyVaultManagers {
        launchHarvest = _newLaunchHarvest;
    }

    /*
     * @notice
     *  Function used by keepers to assess whether to harvest the joint and compound generated
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

        if (dontInvestWant) {
            return true;
        }

        if (shouldStartEpoch()) {
            return true;
        }
        
        if (shouldEndEpoch()) {
            return true;
        }

        return false;
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

    function getHedgeProfit() public view virtual returns (uint256, uint256);

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
        
        //If they are all the same we dont need to do anything
        if( ratioA == ratioB && ratioB == ratioC) return;

        // Calculate the average ratio. Could be at a loss does not matter here
        uint256 avgRatio;
        unchecked{
            avgRatio = (ratioA + ratioB + ratioC) / 3;
        }

        //If only one is higher than the average ratio, then ratioX - avgRatio is split between the other two in relation to their diffs
        //If two are higher than the average each has its diff traded to the third
        //We know all three cannot be above the avg
        //This flow allows us to keep track of exactly what tokens need to be swapped from and to 
        //as well as how much with little extra memory/storage used and a max of 3 if() checks
        if(ratioA > avgRatio) {

            if (ratioB > avgRatio) {
                //Swapping A and B -> C
                swapTwoToOne(avgRatio, tokenA, ratioA, tokenB, ratioB, tokenC);
            } else if (ratioC > avgRatio) {
                //swapping A and C -> B
                swapTwoToOne(avgRatio, tokenA, ratioA, tokenC, ratioC, tokenB);
            } else {
                //Swapping A -> B and C
                swapOneToTwo(avgRatio, tokenA, ratioA, tokenB, ratioB, tokenC, ratioC);
            }
            
        } else if (ratioB > avgRatio) {
            //We know A is below avg so we just need to check C
            if (ratioC > avgRatio) {
                //Swap B and C -> A
                swapTwoToOne(avgRatio, tokenB, ratioB, tokenC, ratioC, tokenA);
            } else {
                //swapping B -> C and A
                swapOneToTwo(avgRatio, tokenB, ratioB, tokenA, ratioA, tokenC, ratioC);
            }

        } else {
            //We know A and B are below so C has to be the only one above the avg
            //swap C -> A and B
            swapOneToTwo(avgRatio, tokenC, ratioC, tokenA, ratioA, tokenB, ratioB);

        }
    }

    /*
     * @notice
     *  Function to be called during rebalancing.
     *  This will swap the extra tokens from the one that has returned the highest amount to the other two
     *  in relation to what they need attempting to make everything as equal as possible
     *  All minAmountToSell checks will be handled in the swap function
     * @param avgRatio, The average Ratio from their start we want to end all tokens as close to as possible
     * @param toSwapToken, the token we will be swapping from to the other two
     * @param toSwapRatio, The current ratio for the token we are swapping from
     * @param token0Address, address of one of the tokens we are swapping to
     * @param token0Ratio, the current ratio for the first token we are swapping to
     * @param token1Address, address of the second token we are swapping to
     * @param token1Ratio, the current ratio of the second token we are swapping to
    */
    function swapOneToTwo(
        uint256 avgRatio,
        address toSwapToken,
        uint256 toSwapRatio,
        address token0Address,
        uint256 token0Ratio,
        address token1Address,
        uint256 token1Ratio
    ) internal {
        uint256 amountToSell;
        uint256 totalDiff;
        uint256 swapTo0;
        uint256 swapTo1;

        unchecked {
            //Calculates the difference between current amount and desired amount in token terms
            amountToSell = (toSwapRatio - avgRatio) * invested[toSwapToken] / RATIO_PRECISION;
            //Used for % calcs
            totalDiff = (avgRatio - token0Ratio) + (avgRatio - token1Ratio);
            //How much of the amount to be swapped is owed to token0
            swapTo0 = amountToSell * (avgRatio - token0Ratio) / totalDiff;
            //To assure we dont sell to much 
            swapTo1 = amountToSell - swapTo0;
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
     *  All minAmountToSell checks will be handled in the swap function
     * @param avgRatio, The average Ratio from their start we want to end all tokens as close to as possible
     * @param token0Address, address of one of the tokens we are swapping from
     * @param token0Ratio, the current ratio for the first token we are swapping from
     * @param token1Address, address of the second token we are swapping from
     * @param token1Ratio, the current ratio of the second token we are swapping from
     * @param toTokenAddress, address of the token we are swapping to
    */
    function swapTwoToOne(
        uint256 avgRatio,
        address token0Address,
        uint256 token0Ratio,
        address token1Address,
        uint256 token1Ratio,
        address toTokenAddress
    ) internal {
        uint256 toSwapFrom0;
        uint256 toSwapFrom1;

        unchecked {
            //Calculates the difference between current amount and desired amount in token terms
            toSwapFrom0 = (token0Ratio - avgRatio) * invested[token0Address] / RATIO_PRECISION;
            toSwapFrom1 = (token1Ratio - avgRatio) * invested[token1Address] / RATIO_PRECISION;
        }

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
     *  Function estimating the current assets in the joint, taking into account:
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
        (uint256 callProfit, uint256 putProfit) = getHedgeProfit();

        // Add remaining balance in joint (if any)
        unchecked{
            _aBalance += balanceOfA() + callProfit;
            _bBalance += balanceOfB() + putProfit;
            _cBalance += balanceOfC();
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
    *    But it wokks...
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
        
        //If they are all the same we dont need to do anything
        if(ratioA == ratioB && ratioB == ratioC) {
            return(startingA, startingB, startingC);
        }
        // Calculate the average ratio. Could be at a loss does not matter here
        uint256 avgRatio;
        unchecked{
            avgRatio = (ratioA + ratioB + ratioC) / 3;
        }
        
        uint256 change0;
        uint256 change1;
        uint256 change2;
        //See Rebalance() for explanation
        if(ratioA > avgRatio) {
            if (ratioB > avgRatio) {
                //Swapping A and B -> C
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(avgRatio, tokenA, ratioA, tokenB, ratioB, tokenC);
                return ((startingA - change0), 
                            (startingB - change1), 
                                (startingC + change2));
            } else if (ratioC > avgRatio) {
                //swapping A and C -> B
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(avgRatio, tokenA, ratioA, tokenC, ratioC, tokenB);
                return ((startingA - change0), 
                            (startingB + change2), 
                                (startingC - change1));
            } else {
                //Swapping A -> B and C
                (change0, change1, change2) = 
                    quoteSwapOneToTwo(avgRatio, tokenA, ratioA, tokenB, ratioB, tokenC, ratioC);
                return ((startingA - change0), 
                            (startingB + change1), 
                                (startingC + change2));
            }
        } else if (ratioB > avgRatio) {
            //We know A is below avg so we just need to check C
            if (ratioC > avgRatio) {
                //Swap B and C -> A
                (change0, change1, change2) = 
                    quoteSwapTwoToOne(avgRatio, tokenB, ratioB, tokenC, ratioC, tokenA);
                return ((startingA + change2), 
                            (startingB - change0), 
                                (startingC - change1));
            } else {
                //swapping B -> A and C
                (change0, change1, change2) = 
                    quoteSwapOneToTwo(avgRatio, tokenB, ratioB, tokenA, ratioA, tokenC, ratioC);
                return ((startingA + change1), 
                            (startingB - change0), 
                                (startingC + change2));
            }
        } else {
            //We know A and B are below so C has to be the only one above the avg
            //swap C -> A and B
            (change0, change1, change2) = 
                quoteSwapOneToTwo(avgRatio, tokenC, ratioC, tokenA, ratioA, tokenB, ratioB);
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
     * @param avgRatio, The average Ratio from their start we want to end all tokens as close to as possible
     * @param toSwapToken, the token we will be swapping from to the other two
     * @param toSwapRatio, The current ratio for the token we are swapping from
     * @param token0Address, address of one of the tokens we are swapping to
     * @param token0Ratio, the current ratio for the first token we are swapping to
     * @param token1Address, address of the second token we are swapping to
     * @param token1Ratio, the current ratio of the second token we are swapping to
     * @return negative change in toSwapToken, positive change for token0, positive change for token1
    */
    function quoteSwapOneToTwo(
        uint256 avgRatio,
        address toSwapToken,
        uint256 toSwapRatio,
        address token0Address,
        uint256 token0Ratio,
        address token1Address,
        uint256 token1Ratio
    ) internal view returns(uint256, uint256, uint256) {
        uint256 amountToSell;
        uint256 totalDiff;
        uint256 swapTo0;
        uint256 swapTo1;

        unchecked {
            //Calculates the difference between current amount and desired amount in token terms
            amountToSell = (toSwapRatio - avgRatio) * invested[toSwapToken] / RATIO_PRECISION;
            //Used for % calcs
            totalDiff = (avgRatio - token0Ratio) + (avgRatio - token1Ratio);
            //How much of the amount to be swapped is owed to token0
            swapTo0 = amountToSell * (avgRatio - token0Ratio) / totalDiff;
            //To assure we dont sell to much 
            swapTo1 = amountToSell - swapTo0;
        }

        uint256 amountOut = quote(
            toSwapToken, 
            token0Address, 
            swapTo0
        );

        uint256 amountOut2 = quote(
            toSwapToken, 
            token1Address, 
            swapTo1
        );

        return (amountToSell, amountOut, amountOut2);
    }   

    /*
     * @notice
     *  Function to be called during rebalancing.
     *  This will swap the extra tokens from the two that returned raios higher than target return to the other one
     *  in relation to what they gained attempting to make everything as equal as possible
     *  will return the absolute changes expected for each token, accounting will take place in parent function
     * @param avgRatio, The average Ratio from their start we want to end all tokens as close to as possible
     * @param token0Address, address of one of the tokens we are swapping from
     * @param token0Ratio, the current ratio for the first token we are swapping from
     * @param token1Address, address of the second token we are swapping from
     * @param token1Ratio, the current ratio of the second token we are swapping from
     * @param toTokenAddress, address of the token we are swapping to
     * @return negative change for token0, negative change for token1, positive change for toTokenAddress
    */
    function quoteSwapTwoToOne(
        uint256 avgRatio,
        address token0Address,
        uint256 token0Ratio,
        address token1Address,
        uint256 token1Ratio,
        address toTokenAddress
    ) internal view returns(uint256, uint256, uint256) {
        uint256 toSwapFrom0;
        uint256 toSwapFrom1;

        unchecked {
            //Calculates the difference between current amount and desired amount in token terms
            toSwapFrom0 = (token0Ratio - avgRatio) * invested[token0Address] / RATIO_PRECISION;
            toSwapFrom1 = (token1Ratio - avgRatio) * invested[token1Address] / RATIO_PRECISION;
        }

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

    function createLP() internal virtual returns (uint256, uint256, uint256);

    function burnLP(
        uint256 amount, 
        uint256 minAOut, 
        uint256 minBOut, 
        uint256 minCOut
    ) internal virtual;

    function getReward() internal virtual;

    function depositLP() internal virtual {}

    function withdrawLP(uint256 amount) internal virtual {}

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
     *  Function available internally closing the joint postion:
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
        burnLP(
            balanceOfPool(), 
            0, 
            0, 
            0
        );

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
     *  Function available publicly returning the joint's balance of tokenA
     * @return balance of tokenA 
     */
    function balanceOfA() public view returns (uint256) {
        return IERC20(tokenA).balanceOf(address(this));
    }

    /*
     * @notice
     *  Function available publicly returning the joint's balance of tokenB
     * @return balance of tokenB
     */
    function balanceOfB() public view returns (uint256) {
        return IERC20(tokenB).balanceOf(address(this));
    }

    /*
     * @notice
     *  Function available publicly returning the joint's balance of tokenC
     * @return balance of tokenC
     */
    function balanceOfC() public view returns (uint256) {
        return IERC20(tokenC).balanceOf(address(this));
    }

    function balanceOfPool() public view virtual returns (uint256);

    /*
     * @notice
     *  Function available publicly returning the joint's balance of rewards
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

    function balanceOfStake() public view virtual returns (uint256 _balance) {}

    function balanceOfTokensInLP()
        public
        view
        virtual
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC);

    function pendingRewards() public view virtual returns (uint256[] memory);

    // --- MANAGEMENT FUNCTIONS ---
    /*
     * @notice
     *  Function available to vault managers closing the joint position manually
     *  This may not work when pool is not equally balanced. In those cases different manual function
     *  should be implemented in children for specific strategies or use removeLiquidityManually to just burn LP token
     * @param expectedBalanceA, expected balance of tokenA to receive
     * @param expectedBalanceB, expected balance of tokenB to receive
     * @param expectedBalanceC, expected balance of tokenC to receive
     */
    function liquidatePositionManually(
        uint256 expectedBalanceA,
        uint256 expectedBalanceB,
        uint256 expectedBalanceC
    ) external onlyVaultManagers {
        (uint256 balanceA, uint256 balanceB, uint256 balanceC) = _closePosition();
        require(expectedBalanceA <= balanceA, "!sandwiched");
        require(expectedBalanceB <= balanceB, "!sandwiched");
        require(expectedBalanceC <= balanceC, "!sandwiched");
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
     * @param expectedBalanceA, expected balance of tokenA to receive
     * @param expectedBalanceB, expected balance of tokenB to receive
     * @param expectedBalanceC, expected balance of tokenC to receive
     */
    function removeLiquidityManually(
        uint256 amount,
        uint256 expectedBalanceA,
        uint256 expectedBalanceB,
        uint256 expectedBalanceC
    ) external virtual onlyVaultManagers {
        withdrawLP(amount);
        uint256 _a = balanceOfA();
        uint256 _b = balanceOfB();
        uint256 _c = balanceOfC();
        burnLP(
            amount,
            expectedBalanceA,
            expectedBalanceB,
            expectedBalanceC
        );

        //Need to update the invested balances based on how much we pulled out
        unchecked {
            uint256 aDiff = balanceOfA() - _a;
            uint256 bDiff = balanceOfB() - _b;
            uint256 cDiff = balanceOfC() - _c;
            invested[tokenA] = invested[tokenA] > aDiff ? invested[tokenA] - aDiff : 0;
            invested[tokenB] = invested[tokenB] > bDiff ? invested[tokenB] - bDiff : 0;
            invested[tokenC] = invested[tokenC] > cDiff ? invested[tokenC] - cDiff : 0;
        }
    }

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
