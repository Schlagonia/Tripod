// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IERC20Extended.sol";

import "./ySwapper.sol";

import {VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";

interface ProviderStrategy {
    function vault() external view returns (VaultAPI);

    function strategist() external view returns (address);

    function keeper() external view returns (address);

    function want() external view returns (address);

    function totalDebt() external view returns (uint256);

    function harvest() external;
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
    bool private usingReference;
    // Array containing reward tokens
    address[] public rewardTokens;

    // Address of the pool to LP
    address public pool;

    //Mapping of the Amounts that actually go into the LP position
    mapping(address => uint256) public invested;

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
            msg.sender == providerB.vault().governance();
    }

    function isVaultManager() internal view returns (bool) {
        return
            msg.sender == providerA.vault().management() ||
            msg.sender == providerB.vault().management();
    }

    function isKeeper() internal view returns (bool) {
        return
            (msg.sender == providerA.keeper()) ||
            (msg.sender == providerB.keeper());
    }

    function isProvider() internal view returns (bool) {
        return
            msg.sender == address(providerA) ||
            msg.sender == address(providerB);
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

        //Check if we are using the reference token for easier swaps for rewards
        if (tokenA == referenceToken || tokenB == referenceToken || tokenC == referenceToken) {
            usingReference = true;
        } else {
            usingReference = false;
        }
    }

    function name() external view virtual returns (string memory);

    function shouldEndEpoch() external view virtual returns (bool);

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
    function shouldStartEpoch() external view returns (bool) {
        // return true if we have balance of A or balance of B while the position is closed
        return
            (balanceOfA() > 0 || balanceOfB() > 0 || balanceOfC() > 0) &&
            invested[tokenA] == 0 &&
            invested[tokenB] == 0 &&
            invested[tokenC] == 0;
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
     *  Function available for providers to close the joint position and return the funds to each 
     * provider strategy
     */
    function closePositionReturnFunds() external onlyProviders {
        // Check if it needs to stop starting new epochs after finishing this one.
        // _autoProtect is implemented in children
        if (_autoProtect() && !autoProtectionDisabled) {
            dontInvestWant = true;
        }

        // Check that we have a position to close
        if (invested[tokenA] == 0 || invested[tokenB] == 0 || invested[tokenC] == 0) {
            return;
        }

        // 1. CLOSE LIQUIDITY POSITION
        // Closing the position will:
        // - Remove liquidity from DEX
        // - Claim pending rewards
        // - Close Hedge and receive payoff
        // and returns current balance of tokenA and tokenB
        _closePosition();

        // 2. SELL REWARDS FOR WANT
        swapRewardTokens();

        // 3. REBALANCE PORTFOLIO
        // Calculate rebalance operation
        // to leave the position with the initial proportions
        rebalance();

        // reset invested balances
        invested[tokenA] = invested[tokenB] = invested[tokenC] = 0;

        // Check that we have returned with no losses
        require(  //////////May want to add unchecked for all the math
            balanceOfA() >=
                (providerA.totalDebt() *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceA"
        );
        require(
            balanceOfB() >=
                (providerB.totalDebt() *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceB"
        );
        require(
            balanceOfC() >=
                (providerC.totalDebt() *
                    (RATIO_PRECISION - maxPercentageLoss)) /
                    RATIO_PRECISION,
            "!wrong-balanceB"
        );

        //Harvest all three providers
        providerA.harvest();
        providerB.harvest();
        providerC.harvest();

        //Check if we should reopen position
        if(dontInvestWant) {
            _returnLooseToProviders();
        } else {
            _openPosition();
        }
    }
    
    /*
     * @notice
     *  Function available for providers to open the joint position:
     * - open the LP position
     * - open the hedginf position if necessary
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
        (uint256 amountA, uint256 amountB) = createLP();
        // Open hedge
        (uint256 costHedgeA, uint256 costHedgeB) = hedgeLP();

        // Set invested amounts
        invested[tokenA] = amountA + costHedgeA;
        invested[tokenB] = amountB + costHedgeB;

        // Deposit LPs (if any)
        depositLP();

        // If there is loose balance, return it
        if (balanceOfStake() != 0 || balanceOfPool() != 0) { ////Why Are we doing this?
            _returnLooseToProviders();
        }
    }

    // Keepers will claim and sell rewards mid-epoch (otherwise we sell only in the end)
    function harvest() external virtual onlyKeepers {
        getReward();
    }

    function harvestTrigger(uint256 /*callCost*/) external view virtual returns (bool) {
        return balanceOfRewardToken()[0] > minRewardToHarvest;
    }

    function getHedgeProfit() public view virtual returns (uint256, uint256);

    /*
     * @notice
     *  Function estimating the current assets in the joint, taking into account:
     * - current balance of tokens in the LP
     * - pending rewards from the LP (if any)
     * - hedge profit (if any)
     * - rebalancing of tokens to maintain token ratios
     * @return _aBalance, _bBalance, estimated tokenA and tokenB balances
     */
    function estimatedTotalAssetsAfterBalance()
        public
        view
        returns (uint256 _aBalance, uint256 _bBalance)
    {
        // Current status of tokens in LP (includes potential IL)
        (_aBalance, _bBalance) = balanceOfTokensInLP();
        // Include hedge payoffs
        (uint256 callProfit, uint256 putProfit) = getHedgeProfit();

        // Add remaining balance in joint (if any)
        unchecked{
            _aBalance += balanceOfA() + callProfit;
            _bBalance += balanceOfB() + putProfit;
        }

        // Include rewards (swapping them if not tokenA or tokenB)
        uint256[] memory _rewardsPending = pendingRewards();
        address[] memory _rewardTokens = rewardTokens;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            address reward = _rewardTokens[i];
            if (reward == tokenA) {
                _aBalance = _aBalance + _rewardsPending[i];
            } else if (reward == tokenB) {
                _bBalance = _bBalance + _rewardsPending[i];
            } else if (_rewardsPending[i] != 0) {     /////Will need to add an extra if statement here
                address swapTo = findSwapTo(reward);
                uint256 outAmount = quote(
                    reward,
                    swapTo,
                    _rewardsPending[i] + IERC20(reward).balanceOf(address(this))
                );
                if (swapTo == tokenA) {   /////Addd a third option here
                    _aBalance += outAmount;
                } else if (swapTo == tokenB) {
                    _bBalance += outAmount;
                }
            }
        }

        // Calculate rebalancing operation needed
        (address sellToken, uint256 sellAmount) = calculateSellToBalance(
            _aBalance,
            _bBalance,
            invested[tokenA],
            invested[tokenB]
        );

        // Update amounts with rebalancing operation
        if (sellToken == tokenA) {
            uint256 buyAmount = quote(sellToken, tokenB, sellAmount);
            _aBalance -= sellAmount;
            _bBalance += buyAmount;
        } else if (sellToken == tokenB) {
            uint256 buyAmount = quote(sellToken, tokenA, sellAmount);
            _bBalance -= sellAmount;
            _aBalance += buyAmount;
        }
    }

    /*
     * @notice
     *  Function available internally calculating the necessary operation to rebalance
     * the tokenA and tokenB balances to initial ratios
     * @param currentA, current balance of tokenA
     * @param currentB, current balance of tokenB
     * @param startingA, initial balance of tokenA
     * @param startingB, initial balance of tokenB
     * @return _sellToken, address of the token needed to sell
     * @return _sellAmount, amount needed to sell
     */
    function calculateSellToBalance(
        uint256 currentA,
        uint256 currentB,
        uint256 startingA,
        uint256 startingB
    ) internal view returns (address _sellToken, uint256 _sellAmount) {
        // If no position, no calculation needed
        if (startingA == 0 || startingB == 0) return (address(0), 0);

        // Get the current ratio between current and starting balance for each token
        (uint256 ratioA, uint256 ratioB,) = getRatios(
            currentA,
            currentB,
            startingA,
            startingB,
            0,
            0
        );

        //  if already balanced, no action needed
        if (ratioA == ratioB) return (address(0), 0);

        // If ratioA is higher, there is excess of tokenA
        if (ratioA > ratioB) {
            _sellToken = tokenA;
            // Simulate the swap and assess the received amount
            _sellAmount = _calculateSellToBalance(
                _sellToken,
                currentA,
                currentB,
                startingA,
                startingB,
                10**uint256(IERC20Extended(tokenA).decimals())
            );
        } else {
            // ratioB is higher, excess of tokenB
            _sellToken = tokenB;
            // Simulate the swap and assess the received amount
            _sellAmount = _calculateSellToBalance(
                _sellToken,
                currentB,
                currentA,
                startingB,
                startingA,
                10**uint256(IERC20Extended(tokenB).decimals())
            );
        }
    }

    /*
     * @notice
     *  Function available internally calculating and simulating the necessary swap to 
     * rebalance the tokens
     * @param sellToken, address of the token to sell
     * @param current0, current balance of token
     * @param current1, current balance of other token
     * @param starting0, initial balance of token
     * @param starting1, initial balance of other token     
     * @param precision, constant value ensuring precision is preserved
     * @return _sellAmount, amount needed to sell
     */
    function _calculateSellToBalance(
        address sellToken,
        uint256 current0,
        uint256 current1,
        uint256 starting0,
        uint256 starting1,
        uint256 precision
    ) internal view returns (uint256 _sellAmount) {
        uint256 numerator = (current0 - ((starting0 * current1) / starting1)) *
            precision;
        uint256 exchangeRate = quote(
            sellToken,
            sellToken == tokenA ? tokenB : tokenA,
            precision
        );

        // First time to approximate
        _sellAmount =
            numerator /
            (precision + ((starting0 * exchangeRate) / starting1));
        // Shortcut to avoid Uniswap amountIn == 0 revert
        if (_sellAmount == 0) {
            return 0;
        }

        // Second time to account for price impact
        exchangeRate =
            (quote(
                sellToken,
                sellToken == tokenA ? tokenB : tokenA,
                _sellAmount
            ) * precision) /
            _sellAmount;
        _sellAmount =
            numerator /
            (precision + ((starting0 * exchangeRate) / starting1));
    }

    /*
    * @notice
    *   Function to be called during harvests that attempts to rebalance all 3 tokens evenly
    *   in comparision to the amounts the started with, i.e. return the same %
    */
    function rebalance() internal {
        (uint256 ratioA, uint256 ratioB, uint256 ratioC) = getRatios(
                    balanceOfA(),
                    balanceOfB(),
                    balanceOfC(),
                    invested[tokenA],
                    invested[tokenB],
                    invested[tokenC]
                );
        
        //If they are all the same we dont need to do anything
        if( ratioA == ratioB && ratioB == ratioC) return;

        // Calculate the average ratio. Could be at a loss does not matter here
        uint256 avgRatio;
        unchecked{
            avgRatio = (ratioA + ratioB + ratioC) / 3;
        }

        //If only one is higher than the average ratio, then ratio - avgRatio is split between the other two in relation to their diffs
        //If two are higher than the average each has its diff traded to the third
        //We know all three cannot be above the avg
        //This flow allows us to keep track of exactly what tokens need to be swapped from and to 
        // as well as how much with little extra memory used and a max of 3 if() checks
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
     *  This will swap the extra tokens from the two that returned the higher than target return to the other one
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
            (_balance, ) = estimatedTotalAssetsAfterBalance();
        } else if (_provider == address(providerB)) {
            (, _balance) = estimatedTotalAssetsAfterBalance();
        }
    }

    function getHedgeBudget(address token)
        public
        view
        virtual
        returns (uint256);

    function hedgeLP() internal virtual returns (uint256, uint256);

    function closeHedge() internal virtual;

    /*
     * @notice
     *  Function available publicly estimating the balancing ratios for the 2 tokens in the form:
     * ratio = currentBalance / invested Balance
     * @param currentA, current balance of tokenA
     * @param currentB, current balance of tokenB
     * @param currentC, current balance of tokenC
     * @param startingA, initial balance of tokenA
     * @param startingB, initial balance of tokenB
     * @param startingC, initial balance of tokenC
     * @return _a, _b _c, ratios for tokenA tokenB and tokenC
     */
    function getRatios(
        uint256 currentA,
        uint256 currentB,
        uint256 currentC,
        uint256 startingA,
        uint256 startingB,
        uint256 startingC
    ) public pure returns (uint256 _a, uint256 _b, uint256 _c) {
        unchecked {
            _a = (currentA * RATIO_PRECISION) / startingA;
            _b = (currentB * RATIO_PRECISION) / startingB;
            _c = (currentC * RATIO_PRECISION) / startingC;
        }
    }

    function createLP() internal virtual returns (uint256, uint256);

    function burnLP(uint256 amount) internal virtual;

    /*
     * @notice
     *  Function available internally deciding what to swap agaisnt the requested token:
     * - if token is either tokenA or B, swap to the other
     * - if token is not A or B but is a reward, swap to the reference token if it's 
     * either A or B, if not, swap to tokenA
     * @param token, address of the token to swap from
     * @return address of the token to swap to
     */
    function findSwapTo(address fromToken) internal view returns (address) {
        if (tokenA == fromToken) {
            return tokenB;
        } else if (tokenB == fromToken) {
            return tokenA;
        }
        if (tokenA == referenceToken || tokenB == referenceToken) {   ///Will need to add new if statement and option here. Also change this statement to be first logic check
            return referenceToken;
        }
        return tokenA;
    }

    /*
     * @notice
     *  Function available internally deciding the swapping path to follow
     * @param _tokenIn, address of the token to swap from
     * @param _token_to, address of the token to swap to
     * @return address array of the swap path to follow
     */
    function getTokenOutPath(address _tokenIn, address _tokenOut)  //This should get moved to the dex specific integration. Isnt applicable curve/Univ3 or Balancer
        internal
        view
        returns (address[] memory _path)
    {   
        address _tokenA = tokenA;
        address _tokenB = tokenB;
        bool isReferenceToken = _tokenIn == address(referenceToken) ||
            _tokenOut == address(referenceToken);
        bool isInternal = (_tokenIn == _tokenA && _tokenOut == _tokenB) ||
            (_tokenIn == _tokenB && _tokenOut == _tokenA);
        _path = new address[](isReferenceToken || isInternal ? 2 : 3);
        _path[0] = _tokenIn;
        if (isReferenceToken || isInternal) {
            _path[1] = _tokenOut;
        } else {
            _path[1] = address(referenceToken);
            _path[2] = _tokenOut;
        }
    }

    function getReward() internal virtual;

    function depositLP() internal virtual {}

    function withdrawLP() internal virtual {}

    /*
     * @notice
     *  Function available internally swapping amounts necessary to swap rewards
     */
    function swapRewardTokens()
        internal
        virtual
    {
        address _tokenA = tokenA;
        address _tokenB = tokenB;
        address _tokenC = tokenC;
        address[] memory _rewardTokens = rewardTokens;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            address reward = _rewardTokens[i];
            uint256 _rewardBal = IERC20(reward).balanceOf(address(this));
            // If the reward token is either A or B, don't swap
            if (reward == _tokenA || reward == _tokenB || reward == _tokenC || _rewardBal == 0) {
                continue;
            // If the referenceToken is either A B or C, swap rewards against it 
            } else if (usingReference) {
                    swap(reward, referenceToken, _rewardBal, 0); 
            } else {
                // Assume that position has already been liquidated
                //Instead this should just return the token with the lowest ratio
                (uint256 ratioA, uint256 ratioB, uint256 ratioC) = getRatios(   //Can create a new function that is swapRewardToken() that can either implement this logic or pick a token to swap to based on liquidity
                    balanceOfA(),
                    balanceOfB(),
                    balanceOfC(),
                    invested[tokenA],
                    invested[tokenB],
                    invested[tokenC]
                );
       
                //If everything is equal use A   
                if(ratioA <= ratioB && ratioA <= ratioC) {
                    swap(reward, _tokenA, _rewardBal, 0);
                } else if(ratioB < ratioA && ratioB <= ratioC) {
                    swap(reward, _tokenB, _rewardBal, 0);
                } else {
                    swap(reward, _tokenC, _rewardBal, 0);
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
        withdrawLP();

        // Close the hedge
        closeHedge();

        if (balanceOfPool() == 0) {
            return (0, 0, 0);
        }

        // **WARNING**: This call is sandwichable, care should be taken
        //              to always execute with a private relay
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
        uint256[] memory _balances = new uint256[](_rewardTokens.length);
        for (uint8 i = 0; i < _rewardTokens.length; i++) {
            _balances[i] = IERC20(_rewardTokens[i]).balanceOf(address(this));
        }
        return _balances;
    }

    function balanceOfStake() public view virtual returns (uint256 _balance) {}

    function balanceOfTokensInLP()
        public
        view
        virtual
        returns (uint256 _balanceA, uint256 _balanceB);

    function pendingRewards() public view virtual returns (uint256[] memory);

    // --- MANAGEMENT FUNCTIONS ---
    /*
     * @notice
     *  Function available to vault managers closing the joint position manually
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
        require(expectedBalanceA <= balanceA, "!sandwidched");
        require(expectedBalanceB <= balanceB, "!sandwidched");
        require(expectedBalanceC <= balanceC, "!sandwidched");
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
     */
    function removeLiquidityManually(
        uint256 amount,
        uint256 expectedBalanceA,
        uint256 expectedBalanceB
    ) external virtual onlyVaultManagers {
        burnLP(amount);
        require(expectedBalanceA <= balanceOfA(), "!sandwidched");
        require(expectedBalanceB <= balanceOfB(), "!sandwidched");
    }

    function swapTokenForTokenManually(
        bool sellA,
        uint256 swapInAmount,
        uint256 minOutAmount
    ) external virtual returns (uint256);

    /*
     * @notice
     *  Function available to governance sweeping a specified token but tokenA and B
     * @param _token, address of the token to sweep
     */
    function sweep(address _token) external onlyGovernance {
        require(_token != tokenA, "TokenA");
        require(_token != tokenB, "TokenB");

        SafeERC20.safeTransfer(
            IERC20(_token),
            providerA.vault().governance(),
            IERC20(_token).balanceOf(address(this))
        );
    }

    /*
     * @notice
     *  Function available to providers to change the provider addresses
     * @param _newProvider, new address of provider
     */
    function migrateProvider(address _newProvider) external onlyProviders {
        ProviderStrategy newProvider = ProviderStrategy(_newProvider);
        if (address(newProvider.want()) == tokenA) {
            providerA = newProvider;
        } else if (address(newProvider.want()) == tokenB) {
            providerB = newProvider;
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
}
