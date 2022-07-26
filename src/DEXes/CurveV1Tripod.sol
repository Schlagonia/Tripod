// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

// Import necessary libraries and interfaces:
// NoHedgeJoint to inherit from
import "../Hedges/NoHedgeTripod.sol";

import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap/V2/IUniswapV2Router02.sol";
import {IConvexDeposit} from "../interfaces/Convex/IConvexDeposit.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";

// Safe casting and math
import {SafeCast} from "../libraries/SafeCast.sol";

contract CurveV1Tripod is NoHedgeTripod {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    
    // Used for cloning, will automatically be set to false for other clones
    bool public isOriginal = true;
    // boolean variable deciding wether to swap in uni or use CRV for provider tokens
    // this can make sense if the pool is unbalanced and price is far from UNI or if the 
    // liquidity remaining in the pool is not enough for the rebalancing swap the strategy needs
    bool public useUniRouter;
    //Router to use for reward swaps and in case of useUnirouter = true
    address public router;

    //The token the Curve pool mints for LP deposits
    address public poolToken;
    //Index mapping provider token to its crv index 
    mapping (address => int128) private index;

    //Convex contracts for staking and rewwards
    IConvexDeposit public constant depositContract = 
        IConvexDeposit(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    //Specific for each LP token
    IConvexRewards public rewardsContract;
    
    // this is unique to each pool
    uint256 public pid; 
    //If we chould claim extras on harvests
    bool public harvestExtras = true; 

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
     * @param _pool, Curve pool to LP
     * @Param _poolToken, Token the Curve Pool issues
     * @param _rewardsContract The Convex rewards contract specific to this LP token
     */
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _poolToken,
        address _rewardsContract
    ) NoHedgeTripod(_providerA, _providerB, _providerC, _referenceToken, _pool) {
        _initializeCurveV1Tripod(_poolToken, _rewardsContract);
    }

    /*
     * @notice
     *  Constructor equivalent for clones, initializing the joint and the specifics of the strat
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
	 * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, Curve pool to LP
     * @Param _poolToken, Token the Curve Pool issues
     * @param _rewardsContract The Convex rewards contract specific to this LP token
     */
    function initialize(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _poolToken,
        address _rewardsContract
    ) external {
        _initialize(_providerA, _providerB, _providerC, _referenceToken, _pool);
        _initializeCurveV1Tripod(_poolToken, _rewardsContract);
    }

    /*
     * @notice
     *  Initialize CurveTtripod specifics
     * @param _poolToken, Token the Curve pool issues
     * @param _rewardsContract, The Convex rewards contract specific to this LP token
     */
    function _initializeCurveV1Tripod(address _poolToken, address _rewardsContract) internal {
        rewardsContract = IConvexRewards(_rewardsContract);
        //Get the token we will be using
        poolToken = _poolToken;
        //UPdate the PID for the rewards pool
        pid = rewardsContract.pid();

        // The reward tokens are the tokens provided to the pool
        //This will update them based on current rewards on convex
        updateRewardTokens();

        //Use _getCrvPoolIndex to set mappings of index's
        index[tokenA] = _getCRVPoolIndex(tokenA); 
        index[tokenB] = _getCRVPoolIndex(tokenB);
        index[tokenC] = _getCRVPoolIndex(tokenC);

        // Use sushi router due to higher liquidity for CVX
        router = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

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
     * @param _pool, Curve pool to LP
     * @Param _poolToken, Token the Curve Pool issues
     * @param _rewardsContract The Convex rewards contract specific to this LP token
     * @return newJoint, address of newly deployed joint
     */
    function cloneCurveV1Tripod(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _poolToken,
        address _rewardsContract
    ) external returns (address newJoint) {
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
            newJoint := create(0, clone_code, 0x37)
        }

        CurveV1Tripod(newJoint).initialize(
            _providerA,
            _providerB,
            _providerC,
            _referenceToken,
            _pool,
            _poolToken,
            _rewardsContract
        );

        emit Cloned(newJoint);
    }

    /*
     * @notice
     *  Function returning the name of the joint in the format "NoHedgeUniV3StablesJoint(USDC-DAI)"
     * @return name of the strategy
     */
    function name() external view override returns (string memory) {
        string memory symbol = string(
            abi.encodePacked(
                IERC20Extended(poolToken).symbol()
            )
        );

        return string(abi.encodePacked("NoHedgeCurveV1Tripod(", symbol, ")"));
    }

    /*
     * @notice
     *  Function available for vault managers to set the boolean value deciding wether
     * to use the uni router for swaps or a CRV pool
     * @param _useUniRouter, new boolean value to use
     */
    function setUseUniRouter(bool _useUniRouter) external onlyVaultManagers {
        useUniRouter = _useUniRouter;
    }

    function updateRewardTokens() internal {
        delete rewardTokens; //empty the rewardsTokens and rebuild

        //We know we will be getting curve and convex at least
        rewardTokens.push(crvToken);
        rewardTokens.push(convexToken);

        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            address _rewardsToken =
                IConvexRewards(virtualRewardsPool).rewardToken();

            rewardTokens.push(_rewardsToken);
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
    function pendingRewards() public view override returns (uint256[] memory _amountPending) {
        // Initialize the array to same length as reward tokens
        _amountPending = new uint256[](rewardTokens.length);

        //Save the earned CrV rewards to 0 where crv will be
        _amountPending[0] = 
            rewardsContract.earned(address(this)) + 
                IERC20(crvToken).balanceOf(address(this));
        //Just place current balance for convex, avoids complex math and underestimates rewards for safety
        _amountPending[1] = IERC20(convexToken).balanceOf(address(this));

        //We skipped the first two of the rewards list
        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            //Spot 2 in our array will correspond with 0 in Convex's
            _amountPending[i + 2] = 
                IConvexRewards(virtualRewardsPool).earned(address(this)) + 
                    IERC20(rewardTokens[i+2]).balanceOf(address(this));
        }
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
        amounts[uint256(int256(index[tokenA]))] = _aBalance;
        amounts[uint256(int256(index[tokenB]))] = _bBalance;
        amounts[uint256(int256(index[tokenC]))] = _cBalance;

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
        amounts[uint256(int256(index[tokenA]))] = minAOut;
        amounts[uint256(int256(index[tokenB]))] = minBOut;
        amounts[uint256(int256(index[tokenC]))] = minCOut;

        ICurveFi(pool).remove_liquidity_imbalance(
            amounts,
            _amount 
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
        
        // Do NOT use Crv pool
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
     * state variable it will either use the uni v3 pool to swap or a CRV pool specified in 
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

        require(_tokenTo == tokenA || _tokenTo == tokenB || _tokenTo == tokenC, "must be valid token"); 
        require(_tokenFrom == tokenA || _tokenFrom == tokenB || _tokenFrom == tokenC, "must be valid token");
        uint256 prevBalance = IERC20(_tokenTo).balanceOf(address(this));
        if (useUniRouter) {
            // Do NOT use Crv pool
            IUniswapV2Router02 _router = IUniswapV2Router02(router);
        
            // Allow necessary amount for CRV pool
            _checkAllowance(router, IERC20(_tokenFrom), _amountIn);
            // Perform swap
            _router.swapExactTokensForTokens(
                _amountIn,
                _minOutAmount,
                getTokenOutPath(_tokenFrom, _tokenTo),
                address(this),
                block.timestamp
            );

        } else {
            ICurveFi _pool = ICurveFi(pool);

            // Perform swap
            _pool.exchange(
                index[_tokenFrom], 
                index[_tokenTo],
                _amountIn, 
                _minOutAmount
            );
        }

        return IERC20(_tokenTo).balanceOf(address(this)) - prevBalance;
    }

    /*
     * @notice
     *  Function used internally to quote a potential rebalancing swap without actually 
     * executing it. Same as the swap function, will simulate the trade either on the uni
     * pool or CRV pool based on useUniRouter as well as the tokens being swapped
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

        //We should only use curve if from and to is one of the LP tokens AND useUniRouter == false
        bool useCurve;
        if(_tokenFrom == tokenA 
            || _tokenFrom == tokenB 
                || _tokenFrom == tokenC) useCurve = true;

        if(useUniRouter) useCurve = false;

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
    function _getCRVPoolIndex(address _token) internal view returns(int128) {
        ICurveFi _pool = ICurveFi(pool);
        uint256 i = 0; 
        int128 poolIndex = 0;
        while (i < 3) {
            if (_pool.coins(i) == _token) {
                return poolIndex;
            }
            i++;
            poolIndex++;
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
     * the joint may have gone out of bounds. If debt ratio is kept in the vaults, the joint
     * re-centers, if debt ratio is 0, the joint is simpley closed and funds are sent back
     * to each provider
     * @return bool assessing whether to end the epoch or not
     */
    function shouldEndEpoch() public view override returns (bool) {}

    /*
    * @notice 
    *  To be called inbetween harvests if applicable
    *  This will claim and sell rewards and create an LP with all available funds
    */
    function tend() external override onlyKeepers {
        //Claim all outstanding rewards
        getReward();
        //Swap out of all Reward Tokens
        swapRewardTokens();
        //Create LP tokens
        (uint256 aDeposited, uint256 bDeposited, uint256 cDeposited) = createLP();
        //Stake LP tokens
        depositLP();
        //add to invested Amounts
        unchecked {
            invested[tokenA] += aDeposited;
            invested[tokenB] += bDeposited;
            invested[tokenC] += cDeposited;
        }
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

        if (rewardsContract.earned(address(this)) + IERC20(crvToken).balanceOf(address(this)) >= 
            _minRewardToHarvest * (10**IERC20Extended(crvToken).decimals()) / RATIO_PRECISION
        ) {
            return true;
        }

        return false;
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
}
