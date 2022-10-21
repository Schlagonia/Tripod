// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

// Import necessary libraries and interfaces:
import "../Tripod.sol";
import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";
import {IConvexDeposit} from "../interfaces/Convex/IConvexDeposit.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";
import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {ITradeFactory} from "../interfaces/ySwaps/ITradeFactory.sol";
// Safe casting and math
import {SafeCast} from "../libraries/SafeCast.sol";
import {IBalancerTripod} from "../interfaces/ITripod.sol";
import {BalancerHelper} from "../libraries/BalancerHelper.sol";

contract BalancerTripod is Tripod {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    
    //Used for swaps. We default to swap rewards to usdc
    address internal constant usdcAddress =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant daiAddress =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    //address of the trade factory to be used for extra rewards
    address public tradeFactory;

    //Curve 3 Pool is used for rebalancing and quoting of stable coin swaps
    //  due to easy getAmountOut functionality
    ICurveFi internal constant curvePool =
        ICurveFi(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    //Index mapping provider token to its crv index 
    mapping (address => int128) public curveIndex;

    /***
        Balancer specific variables
    ***/
    //Array of all 3 provider tokens structs
    IBalancerTripod.PoolInfo[3] public poolInfo;

    //The main Balancer vault
    IBalancerVault internal constant balancerVault = 
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    //Pools we use for swapping rewards
    bytes32 internal constant ethUsdcPoolId =
        bytes32(0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
    bytes32 internal constant ethDaiPoolId = 
        bytes32(0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a);
    //The pool Id for the pool we will swap eth through to a provider token
    bytes32 public toSwapToPoolId;
    //Index of the token for the poolInfo array we are currently swapping to from eth
    uint256 public toSwapToIndex;
    //The main Balancer Pool Id
    bytes32 public poolId;

    /***
        Aura specific variables for staking
    ***/
    //Main contracts for staking and rewwards
    IConvexDeposit public constant depositContract = 
        IConvexDeposit(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
    //Specific for each LP token
    IConvexRewards public rewardsContract; 
    // this is unique to each pool
    uint256 public pid; 
    //If we chould claim extras on harvests. Usually true
    bool public harvestExtras; 

    //Base Reward Tokens
    address internal constant auraToken = 
        0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address internal constant balToken =
        0xba100000625a3754423978a60c9317c58a424e3D;

    /*
     * @notice
     *  Constructor, only called during original deploy
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Aura rewards contract specific to this LP token
     */
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) Tripod(_providerA, _providerB, _providerC, _referenceToken, _pool) {
        _initializeBalancerTripod(_rewardsContract);
    }

    /*
     * @notice
     *  Constructor equivalent for clones, initializing the tripod and the specifics of the strat
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
	 * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Aura rewards contract specific to this LP token
     */
    function initialize(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) external {
        _initialize(_providerA, _providerB, _providerC, _referenceToken, _pool);
        _initializeBalancerTripod(_rewardsContract);
    }

    /*
     * @notice
     *  Initialize BalancerTripod specifics
     * @param _rewardsContract, The Aura rewards contract specific to this LP token
     */
    function _initializeBalancerTripod(address _rewardsContract) internal {
        rewardsContract = IConvexRewards(_rewardsContract);
        //Update the PID for the rewards pool
        pid = rewardsContract.pid();
        //Default to always claim extras
        harvestExtras = true;

        //Main balancer PoolId
        poolId = IBalancerPool(pool).getPoolId();

        //Default to usdcEth pool ID.
        //If USDC was not set as Token A we will need to set the index after deployment
        toSwapToPoolId = ethUsdcPoolId;

        //Set array of pool Infos's for each token
        setBalancerPoolInfos();

        //Set mapping of curve index's
        setCRVPoolIndexs();

        // The reward tokens are the tokens provided to the pool
        //This will update them based on current rewards on Aura
        _updateRewardTokens();

        maxApprove(tokenA, address(balancerVault));
        maxApprove(tokenB, address(balancerVault));
        maxApprove(tokenC, address(balancerVault));
        maxApprove(pool, address(depositContract));
        
        //Max approve the curvePool as well for swaps during rebalnce
        maxApprove(tokenA, address(curvePool));
        maxApprove(tokenB, address(curvePool));
        maxApprove(tokenC, address(curvePool));
    }

    /*
     * @notice
     *  Function returning the name of the tripod in the format "BalancerTripod(TokenSymbol)"
     * @return name of the strategy
     */
    function name() external view override returns (string memory) {

        return string(abi.encodePacked("NoHedgeBalancerTripod(", string(
            abi.encodePacked(
                IERC20Extended(pool).symbol()
            )
        ), ")"));
    }

    /*
    * @notice
    *   internal function called during initilization and by gov to update the rewardTokens array
    *   Auto adds Bal and Aura tokens, then checks the rewards contract to see if there are any "extra rewards"
    *   available for this pool
    *   Will max approve bal and aura to the balancer vault and any extras to the trade factory
    */
    function _updateRewardTokens() internal {
        delete rewardTokens; //empty the rewardsTokens and rebuild

        //We know we will be getting bal and Aura at least
        rewardTokens.push(balToken);
        _checkAllowance(address(balancerVault), IERC20(balToken), type(uint256).max);

        rewardTokens.push(auraToken);
        _checkAllowance(address(balancerVault), IERC20(auraToken), type(uint256).max);

        for (uint256 i; i < rewardsContract.extraRewardsLength(); ++i) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            address _rewardsToken =
                IConvexRewards(virtualRewardsPool).rewardToken();

            rewardTokens.push(_rewardsToken);
            //We will use the trade factory for any extra rewards
            if(tradeFactory != address(0)) {
                _checkAllowance(tradeFactory, IERC20(_rewardsToken), type(uint256).max);
                ITradeFactory(tradeFactory).enable(_rewardsToken, poolInfo[toSwapToIndex].token);
            }
        }
    }

    /*
     * @notice
     *  Function returning the liquidity amount of the LP position
     *  This is just the non-staked balance
     * @return balance of LP token
     */
    function balanceOfPool() public view override returns (uint256) {
        return IERC20(pool).balanceOf(address(this));
    }

    /*
    * @notice will return the total staked balance
    *   Staked tokens in convex are treated 1 for 1 with lp tokens
    */
    function balanceOfStake() public view override returns (uint256) {
        return rewardsContract.balanceOf(address(this));
    }

    /*
    * @notice
    *   This will return the expected balance of each token based on our lp balance
    *       This will not take into account the invested weight so it can be used to determine how in
            or out balance the pool currently is
    */
    function balanceOfTokensInLP()
        public
        view
        override
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC) 
    {
        return BalancerHelper.balanceOfTokensInLP();
    }

    /*
     * @notice
     *  Function returning the amount of rewards earned until now
     * @return uint256 array of amounts of expected rewards earned
     */
    function pendingRewards() public view override returns (uint256[] memory) {
        // Initialize the array to same length as reward tokens
        uint256[] memory _amountPending = new uint256[](rewardTokens.length);

        //Save the earned Bal rewards to 0 where bal will be
        _amountPending[0] = 
            rewardsContract.earned(address(this)) + 
                IERC20(balToken).balanceOf(address(this));

        //Dont qoute any extra rewards since ySwaps will handle them, or Aura since there is no oracle
        return _amountPending;
    }

    /*
     * @notice
     *  Function used internally to collect the accrued rewards mid epoch
     */
    function getReward() internal override {
        rewardsContract.getReward(address(this), harvestExtras);
    }

    /*
     * @notice
     *  Function used internally to open the LP position: 
     *  Creates a batchSwap for each provider token
     * @return the amounts actually invested for each token
     */
    function createLP() internal override returns (uint256, uint256, uint256) {
    
        (IBalancerVault.BatchSwapStep[] memory swaps, 
            IAsset[] memory assets, 
                int[] memory limits) = 
                    BalancerHelper.getCreateLPVariables();

        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            getFundManagement(), 
            limits, 
            block.timestamp
        );

        unchecked {
            return (
                (uint256(limits[0]) - balanceOfA()), 
                (uint256(limits[2]) - balanceOfB()), 
                (uint256(limits[4]) - balanceOfC())
            );
        }
    }

    /*
     * @notice
     *  Function used internally to close the LP position: 
     *      - burns the LP liquidity specified amount, all mins are 0
     * @param amount, amount of liquidity to burn
     */
    function burnLP(
        uint256 _amount
    ) internal override {

        (IBalancerVault.BatchSwapStep[] memory swaps, 
            IAsset[] memory assets, 
                int[] memory limits) = 
                    BalancerHelper.getBurnLPVariables(_amount);

        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            getFundManagement(), 
            limits, 
            block.timestamp
        );
    }

    /*
    * @notice
    *   Internal function to deposit lp tokens into Convex and stake
    */
    function depositLP() internal override {
        uint256 toStake = IERC20(pool).balanceOf(address(this));

        if(toStake == 0) return;

        depositContract.deposit(pid, toStake, true);
    }

    /*
    * @notice
    *   Internal function to unstake tokens from Convex
    *   harvesExtras will determine if we claim rewards, normally should be true
    */
    function withdrawLP(uint256 amount) internal override {
        if(amount == 0) return;

        rewardsContract.withdrawAndUnwrap(
            amount, 
            harvestExtras
        );
    }

    /*
     * @notice
     *  Function used internally to swap core lp tokens during rebalancing.
     * @param _tokenFrom, adress of token to swap from
     * @param _tokenTo, address of token to swap to
     * @param _amountIn, amount of _tokenIn to swap for _tokenTo
     * @return swapped amount
     */
    function swap(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn,
        uint256 _minOutAmount
    ) internal override returns (uint256) {
        if(_amountIn <= minAmountToSell) {
            return 0;
        }

        require(_tokenTo == tokenA || _tokenTo == tokenB || _tokenTo == tokenC); 
        require(_tokenFrom == tokenA || _tokenFrom == tokenB || _tokenFrom == tokenC);
        uint256 prevBalance = IERC20(_tokenTo).balanceOf(address(this));

        // Perform swap through curve since thats what rebalance quote are off of
        curvePool.exchange(
            curveIndex[_tokenFrom], 
            curveIndex[_tokenTo],
            _amountIn, 
            _minOutAmount
        );

        uint256 diff = IERC20(_tokenTo).balanceOf(address(this)) - prevBalance;
        require(diff >= _minOutAmount);
        return diff;
    }

    /*
     * @notice
     *  Function used internally to quote a potential rebalancing swap without actually 
     * executing it. 
     *  Will only quote bal reward token or a core token swap
     *  Uses a chainlink oracle for the balToken and the curve 3Pool for the core swaps
     * We are using the curve pool due to easier get Amount out ability for core coins
     * @param _tokenFrom, adress of token to swap from
     * @param _tokenTo, address of token to swap to
     * @param _amountIn, amount of _tokenIn to swap for _tokenTo
     * @return simulated swapped amount
     */
    function quote(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) public view override returns (uint256) {
        return BalancerHelper.quote(_tokenFrom, _tokenTo, _amountIn);
    }

    /*
    * @notice
    *   Overwritten main function to sell bal and aura with batchSwap
    *   function used internally to sell the available Bal and Aura tokens
    *   We sell bal/Aura -> WETH -> toSwapTo
    */
    function swapRewardTokens() internal override {
        uint256 balBalance = IERC20(balToken).balanceOf(address(this));
        uint256 auraBalance = IERC20(auraToken).balanceOf(address(this));

        //Cant swap 0
        if(balBalance == 0 || auraBalance == 0) return;

        (IBalancerVault.BatchSwapStep[] memory swaps,
            IAsset[] memory assets, 
                int[] memory limits) = 
                    BalancerHelper.getRewardVariables(balBalance, auraBalance);

        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps,
            assets,
            getFundManagement(), 
            limits, 
            block.timestamp
        );   
    }

    /*
    * @internal
    *   Function used internally to set all of a bb-pool info for each provider token
    *   Will set the poolInfoMapping based on the underlying token
    *   Will set the poolInfo array in order of A, B, C for createLP() accounting
    */
    function setBalancerPoolInfos() internal {
        (IERC20[] memory _tokens, , ) = balancerVault.getPoolTokens(poolId);
        IBalancerTripod.PoolInfo memory _poolInfo;
        for(uint256 i; i < _tokens.length; ++i) {
            IBalancerPool _pool = IBalancerPool(address(_tokens[i]));
            
            //We cant call getMainToken on the main pool
            if(pool == address(_pool)) continue;
            
            address _token = _pool.getMainToken();
            _poolInfo = IBalancerTripod.PoolInfo(
                    _token,
                    address(_pool),
                    _pool.getPoolId()
                );

            if(_token == tokenA) {
                poolInfo[0] = _poolInfo;
            } else if(_token == tokenB) {
                poolInfo[1] = _poolInfo;
            } else if(_token == tokenC) {
                poolInfo[2] = _poolInfo;
            } 
        }
    }

    /*
     * @notice
     *  Function used internally to set the index for each token in the 3Pool
     */
    function setCRVPoolIndexs() internal {
        uint256 i = 0; 
        int128 poolIndex = 0;
        while (i < 3) {
            address _token = curvePool.coins(i);
            curveIndex[_token] = poolIndex;
            i++;
            poolIndex++;
        }
    }

    /*
     * @notice
     *  Function used by governance to swap tokens manually if needed, can be used when closing 
     * the LP position manually and need some re-balancing before sending funds back to the 
     * providers. Should mainly be used for provider tokens but can be used for bal and aura if need be.
     * @param tokenFrom, address of token we are swapping from
     * @param tokenTo, address of token we are swapping to
     * @param swapInAmount, amount of swapPath[0] to swap for swapPath[1]
     * @param minOutAmount, minimum amount of want out
     * @param core, bool repersenting if this is a swap from LP -> LP token or if one is a none LP token
     * @return swapped amount
     */
    function swapTokenForTokenManually(
        address tokenFrom,
        address tokenTo,
        uint256 swapInAmount,
        uint256 minOutAmount,
        bool core
    ) external override onlyVaultManagers returns (uint256) {
        require(swapInAmount > 0 && IERC20(tokenFrom).balanceOf(address(this)) >= swapInAmount, "!amount");
        
        if(core) {
            return swap(
                tokenFrom,
                tokenTo,
                swapInAmount,
                minOutAmount
                );
        } else {
            swapRewardTokens();
            return IERC20(tokenTo).balanceOf(address(this));
        }
    }

    /*
    * @notice
    *   Function available internally to create an lp during tend
    *   Will only use toSwapTo since that is what is swapped to during tend
    */
    function createTendLP() internal {
        IBalancerTripod.PoolInfo memory _poolInfo = poolInfo[toSwapToIndex];
        uint256 balance = IERC20(_poolInfo.token).balanceOf(address(this));

        (IBalancerVault.BatchSwapStep[] memory swaps, 
            IAsset[] memory assets, 
                int[] memory limits) = 
                    BalancerHelper.getTendVariables(_poolInfo, balance);
        
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps,
            assets,
            getFundManagement(),
            limits, 
            block.timestamp
        );
    }

    /*
    * @notice 
    *  To be called inbetween harvests if applicable
    *  This will claim and sell rewards and create an LP with all available funds
    *  This will not adjust invested amounts, since it is all profit and is likely to be
    *       denominated in one token used to swap to i.e. WETH
    */
    function tend() external override onlyKeepers {
        //Claim all outstanding rewards
        getReward();
        //Swap out of all Reward Tokens
        swapRewardTokens();
        //Create LP tokens
        createTendLP();
        //Stake LP tokens
        depositLP();
    }

    /*
    * @notice
    *   Trigger to tell Keepers if they should call tend()
    */
    function tendTrigger(uint256 /*callCost*/) external view override returns (bool) {

        uint256 _minRewardToHarvest = minRewardToHarvest;
        if (_minRewardToHarvest == 0) {
            return false;
        }

        if (totalLpBalance() == 0) {
            return false;
        }

        // check if the base fee gas price is higher than we allow. if it is, block harvests.
        if (!isBaseFeeAcceptable()) {
            return false;
        }

        if (rewardsContract.earned(address(this)) + IERC20(balToken).balanceOf(address(this)) >= _minRewardToHarvest) {
            return true;
        }

        return false;
    }

    /*
    * @notice
    *   External function for management to call that updates our rewardTokens array
    *   Should be called if the convex contract adds or removes any extra rewards
    */
    function updateRewardTokens() external onlyVaultManagers {
        _updateRewardTokens();
    }

    /*
    * @notice 
    *   Function available from management to change wether or not we harvest extra rewards
    * @param _harvestExtras, bool of new harvestExtras status
    */
    function setHarvestExtras(bool _harvestExtras) external onlyVaultManagers {
        harvestExtras = _harvestExtras;
    }

        /*
    * @notice
    *   Function available to management to change which token we swap to from rewards
    *   will only be usdc or DAI
    */
    function changeToSwapTo(uint256 newIndex) external onlyVaultManagers {
        if(poolInfo[newIndex].token == usdcAddress) {
            toSwapToPoolId = ethUsdcPoolId;
        } else if(poolInfo[newIndex].token == daiAddress) {
            toSwapToPoolId = ethDaiPoolId;
        } else revert();
        toSwapToIndex = newIndex;
    }

    function getFundManagement() 
        internal 
        view 
        returns (IBalancerVault.FundManagement memory fundManagement) 
    {
        fundManagement = IBalancerVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );
    }

    function maxApprove(address _token, address _contract) internal {
        IERC20(_token).safeApprove(_contract, type(uint256).max);
    }

    // ---------------------- YSWAPS FUNCTIONS ----------------------
    function setTradeFactory(address _tradeFactory) external onlyGovernance {
        if (tradeFactory != address(0)) {
            _removeTradeFactoryPermissions();
        }

        address[] memory _rewardTokens = rewardTokens;
        ITradeFactory tf = ITradeFactory(_tradeFactory);
        //We only need to set trade factory for non aura/bal tokens
        for(uint256 i = 2; i < _rewardTokens.length; ++i) {
            address token = rewardTokens[i];
        
            IERC20(token).safeApprove(_tradeFactory, type(uint256).max);

            tf.enable(token, poolInfo[toSwapToIndex].token);
        }
        tradeFactory = _tradeFactory;
    }

    function removeTradeFactoryPermissions() external onlyVaultManagers {
        _removeTradeFactoryPermissions();
    }

    function _removeTradeFactoryPermissions() internal {
        address[] memory _rewardTokens = rewardTokens;
        for(uint256 i = 2; i < _rewardTokens.length; ++i) {
        
            IERC20(_rewardTokens[i]).safeApprove(tradeFactory, 0);
        }
        
        tradeFactory = address(0);
    }
}