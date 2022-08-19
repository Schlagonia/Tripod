// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

// Import necessary libraries and interfaces:
// NoHedgetripod to inherit from
import "../Hedges/NoHedgeTripod.sol";

import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap/V2/IUniswapV2Router02.sol";
import {IConvexDeposit} from "../interfaces/Convex/IConvexDeposit.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";
import {ITradeFactory} from "../interfaces/ySwaps/ITradeFactory.sol";

// Safe casting and math
import {SafeCast} from "../libraries/SafeCast.sol";

contract CurveV2Tripod is NoHedgeTripod {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    
    // Used for cloning, will automatically be set to false for other clones
    bool public isOriginal = true;

    //Routers to use for reward swaps
    address internal constant sushiRouter =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address internal constant uniRouter =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Use sushi router due to higher liquidity for CVX
    address public router;
    //address of the trade factory to be used for extra rewards
    address public tradeFactory;

    //The token the Curve pool mints for LP deposits
    address public poolToken;
    //Index mapping provider token to its crv index 
    mapping (address => uint256) private index;

    //Convex contracts for staking and rewwards
    IConvexDeposit public constant depositContract = 
        IConvexDeposit(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    //Specific for each LP token
    IConvexRewards public rewardsContract;
    
    // this is unique to each pool
    uint256 public pid; 
    //If we chould claim extras on harvests
    bool public harvestExtras; 

    //Base Reward Tokens
    address internal constant convexToken = 
        address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address internal constant crvToken =
        address(0xD533a949740bb3306d119CC777fa900bA034cd52);

    /*
     * @notice
     *  Constructor, only called during original deploy
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Convex rewards contract specific to this LP token
     */
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) NoHedgeTripod(_providerA, _providerB, _providerC, _referenceToken, _pool) {
        _initializeCurveV2Tripod(_rewardsContract);
    }

    /*
     * @notice
     *  Constructor equivalent for clones, initializing the tripod and the specifics of the strat
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
	 * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Convex rewards contract specific to this LP token
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
        _initializeCurveV2Tripod(_rewardsContract);
    }

    /*
     * @notice
     *  Initialize CurveTripod specifics
     * @param _rewardsContract, The Convex rewards contract specific to this LP token
     */
    function _initializeCurveV2Tripod(address _rewardsContract) internal {
        rewardsContract = IConvexRewards(_rewardsContract);
        //Get the token we will be using
        poolToken = ICurveFi(pool).token();
        //UPdate the PID for the rewards pool
        pid = rewardsContract.pid();
        //Set the router to use sushi
        router = sushiRouter;
        //Default to always claim extras
        harvestExtras = true;

        // The reward tokens are the tokens provided to the pool
        //This will update them based on current rewards on convex
        _updateRewardTokens();

        //Use _getCrvPoolIndex to set mappings of index's
        index[tokenA] = _getCRVPoolIndex(tokenA); 
        index[tokenB] = _getCRVPoolIndex(tokenB);
        index[tokenC] = _getCRVPoolIndex(tokenC);

        maxApprove(tokenA, pool);
        maxApprove(tokenB, pool);
        maxApprove(tokenC, pool);
        maxApprove(poolToken, pool);
        maxApprove(poolToken, address(depositContract));
    }

    event Cloned(address indexed clone);

    /*
     * @notice
     *  Cloning function to migrate/ deploy to other pools
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Convex rewards contract specific to this LP token
     * @return newTripod, address of newly deployed tripod
     */
    function cloneCurveV2Tripod(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) external returns (address newTripod) {
        require(isOriginal, "!original");
        bytes20 addressBytes = bytes20(address(this));

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            newTripod := create(0, clone_code, 0x37)
        }

        CurveV2Tripod(newTripod).initialize(
            _providerA,
            _providerB,
            _providerC,
            _referenceToken,
            _pool,
            _rewardsContract
        );

        emit Cloned(newTripod);
    }

    /*
     * @notice
     *  Function returning the name of the tripod in the format "NoHedgeCurveV2Tripod(CurveTokenSymbol)"
     * @return name of the strategy
     */
    function name() external view override returns (string memory) {
        string memory symbol = string(
            abi.encodePacked(
                IERC20Extended(poolToken).symbol()
            )
        );

        return string(abi.encodePacked("NoHedgeCurveV2Tripod(", symbol, ")"));
    }

    /*
    * @notice
    *   internal function called during initilization and by gov to update the rewardTokens array
    *   Auto adds crv and cvx tokens, then checks the rewards contract to see if there are any "extra rewards"
    *   available for this pool
    *   Will max approve any extras to the trade factory
    */
    function _updateRewardTokens() internal {
        delete rewardTokens; //empty the rewardsTokens and rebuild

        //We know we will be getting curve and convex at least
        rewardTokens.push(crvToken);
        rewardTokens.push(convexToken);

        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            address _rewardsToken =
                IConvexRewards(virtualRewardsPool).rewardToken();

            rewardTokens.push(_rewardsToken);
            //We will use the trade factory for any extra rewards
            if(tradeFactory != address(0)) {
                _checkAllowance(tradeFactory, IERC20(_rewardsToken), type(uint256).max);
                ITradeFactory(tradeFactory).enable(_rewardsToken, usingReference ? referenceToken : tokenA);
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
        return IERC20(poolToken).balanceOf(address(this));
    }

    /*
    * @notice will return the total staked balance
    *   Staked tokens in convex are treated 1 for 1 with lp tokens
    */
    function balanceOfStake() public view override returns (uint256) {
        return rewardsContract.balanceOf(address(this));
    }

    function totalLpBalance() public view returns (uint256) {
        unchecked {
            return balanceOfPool() + balanceOfStake();
        }
    }

    /*
     * @notice
     *  Function returning the current balance of each token in the LP position
     *  This will assume tokens were deposited equally, the quoteRebalance will adjust after if that is not correct
     * @return _balanceA, balance of tokenA in the LP position
     * @return _balanceB, balance of tokenB in the LP position
     * @return _balanceC, balance of tokenC in the LP position
     */
    function balanceOfTokensInLP()
        public
        view
        override
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC) 
    {
        uint256 lpBalance = totalLpBalance();
        if(lpBalance == 0) return (0, 0, 0);

        ICurveFi _pool = ICurveFi(pool);
        // use calc_Withdrawone_coin for a third of each
        uint256 third = lpBalance * 3_333 / 10_000;
        _balanceA = _pool.calc_withdraw_one_coin(third, index[tokenA]);
        _balanceB = _pool.calc_withdraw_one_coin(third, index[tokenB]);
        _balanceC = _pool.calc_withdraw_one_coin(third, index[tokenC]);
    }

    /*
     * @notice
     *  Function returning the amount of rewards earned until now
     * @return uint256 array of amounts of expected rewards earned
     */
    function pendingRewards() public view override returns (uint256[] memory) {
        // Initialize the array to same length as reward tokens
        uint256[] memory _amountPending = new uint256[](rewardTokens.length);

        //Save the earned CrV rewards to 0 where crv will be
        _amountPending[0] = 
            rewardsContract.earned(address(this)) + 
                IERC20(crvToken).balanceOf(address(this));
        //Just place current balance for convex, avoids complex math and underestimates rewards for safety
        _amountPending[1] = IERC20(convexToken).balanceOf(address(this));

        //Dont qoute any extra rewards since ySwaps will handle them
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
     *     
     * @return the amounts actually invested for each token
     */
    function createLP() internal override returns (uint256, uint256, uint256) {
        uint256 _aBalance = balanceOfA();
        uint256 _bBalance = balanceOfB();
        uint256 _cBalance = balanceOfC();

        uint256[3] memory amounts;
        amounts[index[tokenA]] = _aBalance;
        amounts[index[tokenB]] = _bBalance;
        amounts[index[tokenC]] = _cBalance;

        ICurveFi(pool).add_liquidity(
            amounts, 
            0
        );

        unchecked {
            return (
                (_aBalance - balanceOfA()), 
                (_bBalance - balanceOfB()), 
                (_cBalance - balanceOfC())
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

        uint256[3] memory amounts;

        ICurveFi(pool).remove_liquidity(
            _amount, 
            amounts
        );
    }

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
    ) internal override {

        uint256[3] memory amounts;
        amounts[index[tokenA]] = minAOut;
        amounts[index[tokenB]] = minBOut;
        amounts[index[tokenC]] = minCOut;

        ICurveFi(pool).remove_liquidity(
            _amount,
            amounts
        );
    }

    /*
    * @notice
    *   Internal function to deposit lp tokens into Convex and stake
    */
    function depositLP() internal override {
        uint256 toStake = IERC20(poolToken).balanceOf(address(this));

        if(toStake == 0) return;

        depositContract.deposit(pid, toStake, true);
    }

    /*
    * @notice
    *   Internal function to unstake tokens from Convex
    *   harvesExtras will determine if we claim rewards, normally should be true
    */
    function withdrawLP(uint256 amount) internal override {
        
        rewardsContract.withdrawAndUnwrap(
            amount, 
            harvestExtras
        );
    }

    /*
    * @notice
    *   Internal function to swap the reward tokens into one of the provider tokens
    *   Will use a V2 router since it could be a wide array of tokens
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
    ) internal override returns (uint256) {
        if(_amountIn < minAmountToSell) return 0;
        //Dont swap extra rewarsds
        if(_from != crvToken && _from != convexToken) return 0;
        
        //Use Router for rewards
        IUniswapV2Router02 _router = IUniswapV2Router02(router);

        uint256 prevBalance = IERC20(_to).balanceOf(address(this));
        
        // Allow necessary amount for router
        _checkAllowance(router, IERC20(_from), _amountIn);

        _router.swapExactTokensForTokens(
            _amountIn, 
            _minOut, 
            getTokenOutPath(_from, _to), 
            address(this), 
            block.timestamp
        );

        return IERC20(_to).balanceOf(address(this)) - prevBalance;
    }

    /*
     * @notice
     *  Function used internally to swap tokens during rebalancing. Depending on the useCRVPool
     * state variable it will either use the uniV2Router to swap or a CRV pool specified in 
     * crvPool state variable
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

        require(_tokenTo == tokenA || _tokenTo == tokenB || _tokenTo == tokenC, "must be valid _to"); 
        require(_tokenFrom == tokenA || _tokenFrom == tokenB || _tokenFrom == tokenC, "must be valid _from");
        uint256 prevBalance = IERC20(_tokenTo).balanceOf(address(this));

        ICurveFi _pool = ICurveFi(pool);
        
        // Perform swap
        _pool.exchange(
            index[_tokenFrom], 
            index[_tokenTo],
            _amountIn, 
            _minOutAmount
        );

        return IERC20(_tokenTo).balanceOf(address(this)) - prevBalance;
    }

    /*
     * @notice
     *  Function used internally to quote a potential rebalancing swap without actually 
     * executing it. Same as the swap function, will simulate the trade either on the UniV2
     * pool or CRV pool based on the tokens being swapped
     * @param _tokenFrom, adress of token to swap from
     * @param _tokenTo, address of token to swap to
     * @param _amountIn, amount of _tokenIn to swap for _tokenTo
     * @return simulated swapped amount
     */
    function quote(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) internal view override returns (uint256) {
        if(_amountIn == 0) {
            return 0;
        }

        require(_tokenTo == tokenA || 
                    _tokenTo == tokenB || 
                        _tokenTo == tokenC, 
                            "must be valid token"); 

        //We should only use curve if _from AND _to is one of the LP tokens
        bool useCurve;
        if(_tokenFrom == tokenA 
            || _tokenFrom == tokenB 
                || _tokenFrom == tokenC) useCurve = true;

        if(!useCurve) {
            // Do NOT use crv pool use V2 router
            IUniswapV2Router02 _router = IUniswapV2Router02(router);

            // Call the quote function in CRV pool
            uint256[] memory amounts = _router.getAmountsOut(
                _amountIn, 
                getTokenOutPath(_tokenFrom, _tokenTo)
            );

            return amounts[amounts.length - 1];
        } else {
            ICurveFi _pool = ICurveFi(pool);

            // Call the quote function in CRV pool
            return _pool.get_dy(
                index[_tokenFrom], 
                index[_tokenTo], 
                _amountIn
            );
        }
    }

    /*
     * @notice
     *  Function used internally to retrieve the CRV index for a token in a CRV pool
     * @return the token's pool index
     */
    function _getCRVPoolIndex(address _token) internal view returns(uint256) {
        uint256 i = 0;
        ICurveFi _pool = ICurveFi(pool);
        while (i < 3) {
            if (_pool.coins(i) == _token) {
                return i;
            }
            i++;
        }

        //If we get here we do not have the correct pool
        revert("No pool index");
    }

    /*
     * @notice
     *  Function used by governance to swap tokens manually if needed, can be used when closing 
     * the LP position manually and need some re-balancing before sending funds back to the 
     * providers
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
        require(swapInAmount > 0, "cant swap 0");
        require(IERC20(tokenFrom).balanceOf(address(this)) >= swapInAmount, "Not enough tokens");
        
        if(core) {
            return swap(
                tokenFrom,
                tokenTo,
                swapInAmount,
                minOutAmount
                );
        } else {
            return swapReward(
                tokenFrom,
                tokenTo,
                swapInAmount,
                minOutAmount
                );
        }
    }

    /*
     * @notice
     *  Function used by harvest trigger to assess whether to harvest it as
     * the tripod may have gone out of bounds. If debt ratio is kept in the vaults, the tripod
     * re-centers, if debt ratio is 0, the tripod is simpley closed and funds are sent back
     * to each provider
     * @return bool assessing whether to end the epoch or not
     */
    function shouldEndEpoch() public view override returns (bool) {}

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
        createLP();
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

        if (rewardsContract.earned(address(this)) + IERC20(crvToken).balanceOf(address(this)) >= _minRewardToHarvest) {
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
    *   Function available to management to change which UniV2 router we are using
    */
    function changeRouter() external onlyVaultManagers {
        router = router == sushiRouter ? uniRouter : sushiRouter;
    }

        /*
     * @notice
     *  Function available internally deciding the swapping path to follow
     * @param _tokenIn, address of the token to swap from
     * @param _tokenOut, address of the token to swap to
     * @return address array of the swap path to follow
     */
    function getTokenOutPath(address _tokenIn, address _tokenOut)
        internal
        view
        returns (address[] memory _path)
    {   
        bool isReferenceToken = _tokenIn == address(referenceToken) ||
            _tokenOut == address(referenceToken);
        _path = new address[](isReferenceToken ? 2 : 3);
        _path[0] = _tokenIn;
        if (isReferenceToken) {
            _path[1] = _tokenOut;
        } else {
            _path[1] = address(referenceToken);
            _path[2] = _tokenOut;
        }
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
        address swapTo = usingReference ? referenceToken : tokenA;
        //We only need to set trade factory for non CVX/CRV tokens
        for(uint256 i = 2; i < _rewardTokens.length; i ++) {
            address token = rewardTokens[i];
        
            IERC20(token).safeApprove(_tradeFactory, type(uint256).max);

            //Default to token A or reference
            tf.enable(token, swapTo);
        }
        tradeFactory = _tradeFactory;
    }

    function removeTradeFactoryPermissions() external onlyVaultManagers {
        _removeTradeFactoryPermissions();
    }

    function _removeTradeFactoryPermissions() internal {
        address[] memory _rewardTokens = rewardTokens;
        for(uint256 i = 2; i < _rewardTokens.length; i ++) {
        
            IERC20(_rewardTokens[i]).safeApprove(tradeFactory, 0);
        }
        
        tradeFactory = address(0);
    }
}
