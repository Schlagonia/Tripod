// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

// Import necessary libraries and interfaces:
// NoHedgetripod to inherit from
import "../Hedges/NoHedgeTripod.sol";
import "forge-std/console.sol";
import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap/V2/IUniswapV2Router02.sol";
import {IConvexDeposit} from "../interfaces/Convex/IConvexDeposit.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";
import {ICurveFi} from "../interfaces/Curve/IcurveFi.sol";
import {ITradeFactory} from "../interfaces/ySwaps/ITradeFactory.sol";
// Safe casting and math
import {SafeCast} from "../libraries/SafeCast.sol";

//Pool 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2
contract BalancerTripod is NoHedgeTripod {
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
    address public router = sushiRouter;
    address internal constant usdcAddress =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    //address of the trade factory to be used for extra rewards
    address public tradeFactory;

    //Curve 3 Pool for easy quoting of stable coin swaps
    ICurveFi internal constant curvePool =
        ICurveFi(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    //Array of the provider tokens to use during lp functions
    address[3] internal tokens;

    /***
        Balancer specific variables
    ***/
    //The main Balancer vault
    IBalancerVault internal constant balancerVault = 
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address internal constant balEthPool =
        0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56;
    address internal constant auraEthPool =
        0xc29562b045D80fD77c69Bec09541F5c16fe20d9d;
    address internal constant ethUsdcPool =
        0x96646936b91d6B9D7D0c47C496AfBF3D6ec7B6f8;
    //The specific Balancer Pool Id
    bytes32 internal poolId;
    //mapping of the provider tokens to their bb-a-pool
    mapping (address => bytes32) internal poolIds;
    //Mapping from provider token to its base bb-a-pool
    mapping (address => address) internal poolAddress;

    /***
        Aura specific variables for staking
    ***/
    //Convex contracts for staking and rewwards
    IConvexDeposit public constant depositContract = 
        IConvexDeposit(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
    //Specific for each LP token
    IConvexRewards public rewardsContract; 
    // this is unique to each pool
    uint256 public pid; 
    //If we chould claim extras on harvests
    bool public harvestExtras = true; 

    //Base Reward Tokens
    address internal constant auraToken = 
        address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    address internal constant balToken =
        address(0xba100000625a3754423978a60c9317c58a424e3D);

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
        _initializeBalancerTripod(_rewardsContract);
    }

    /*
     * @notice
     *  Initialize CurveTripod specifics
     * @param _rewardsContract, The Convex rewards contract specific to this LP token
     */
    function _initializeBalancerTripod(address _rewardsContract) internal {
        rewardsContract = IConvexRewards(_rewardsContract);
        //UPdate the PID for the rewards pool
        pid = rewardsContract.pid();

        //Main balancer PoolId
        poolId = IBalancerPool(pool).getPoolId();

        // The reward tokens are the tokens provided to the pool
        //This will update them based on current rewards on convex
        _updateRewardTokens();

        //Set mapping of poolId's
        poolAddress[tokenA] = getBalancerPool(tokenA);
        poolAddress[tokenB] = getBalancerPool(tokenB);
        poolAddress[tokenC] = getBalancerPool(tokenC);

        tokens[0] = tokenA;
        tokens[1] = tokenB;
        tokens[2] = tokenC;

        maxApprove(tokenA, address(balancerVault));
        maxApprove(tokenB, address(balancerVault));
        maxApprove(tokenC, address(balancerVault));
        maxApprove(pool, address(depositContract));
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
    function cloneBalancerTripod(
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

        BalancerTripod(newTripod).initialize(
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
     *  Function returning the name of the tripod in the format "NoHedgeBalancerTripod(CurveTokenSymbol)"
     * @return name of the strategy
     */
    function name() external view override returns (string memory) {
        string memory symbol = string(
            abi.encodePacked(
                IERC20Extended(pool).symbol()
            )
        );

        return string(abi.encodePacked("NoHedgeBalancerTripod(", symbol, ")"));
    }

    function _updateRewardTokens() internal {
        delete rewardTokens; //empty the rewardsTokens and rebuild

        //We know we will be getting curve and convex at least
        rewardTokens.push(balToken);
        maxApprove(balToken, address(balancerVault));
        rewardTokens.push(auraToken);
        maxApprove(auraToken, address(balancerVault));

        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            address _rewardsToken =
                IConvexRewards(virtualRewardsPool).rewardToken();

            rewardTokens.push(_rewardsToken);
            //We will use the trade factory for any extra rewards
            IERC20(_rewardsToken).safeApprove(tradeFactory, type(uint256).max);
            ITradeFactory(tradeFactory).enable(_rewardsToken, usdcAddress);
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

        //get the virtual price .getRate()
        uint256 virtualPrice = IBalancerPool(pool).getRate();
 
        //Calculate vp -> dollars
        uint256 lpDollarValue = lpBalance * virtualPrice / (10 ** IERC20Extended(pool).decimals());
    
        //div by 3
        uint256 third = lpDollarValue * 3_333 / 10_000;
        
        //Probably want to get an oracle price and use that to calulatete the percent
        unchecked {
            _balanceA = third / (10 ** (18 - IERC20Extended(tokenA).decimals()));
            _balanceB = third / (10 ** (18 - IERC20Extended(tokenB).decimals()));
            _balanceC = third / (10 ** (18 - IERC20Extended(tokenC).decimals()));
        }
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
                IERC20(balToken).balanceOf(address(this));
        //Just place current balance for convex, avoids complex math and underestimates rewards for safety
        _amountPending[1] = IERC20(auraToken).balanceOf(address(this));

        //We skipped the first two of the rewards list
        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            //Spot 2 in our array will correspond with 0 in Convex's
            _amountPending[i + 2] = 
                IConvexRewards(virtualRewardsPool).earned(address(this)) + 
                    IERC20(rewardTokens[i+2]).balanceOf(address(this));
        }
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
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](6);
        //Match the token address with the desired index for this trade
        IAsset[] memory assets = new IAsset[](7);
        int[] memory limits = new int[](7);

        for (uint256 i; i < 3; i ++) {
            address token = tokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            address bbPool = poolAddress[token];
            uint256 j = i * 2;
            swaps[j] = IBalancerVault.BatchSwapStep(
                IBalancerPool(bbPool).getPoolId(),
                j,
                j + 1,
                balance,
                abi.encode(0)
            );

            swaps[j+1] = IBalancerVault.BatchSwapStep(
                poolId,
                j + 1,
                6,
                0,
                abi.encode(0)
            );

            assets[j] = IAsset(token);
            assets[j+1] = IAsset(bbPool);
            limits[j] = int(balance);
        }
        
        assets[6] = IAsset(pool);

        //Create this contract as the fund manager
        //Set "use internal balance" vars to false since it is a traditional swap
        IBalancerVault.FundManagement memory fundManagement =
            IBalancerVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );
        
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            fundManagement, 
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
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](6);
        //Match the token address with the desired index for this trade
        IAsset[] memory assets = new IAsset[](7);
        int[] memory limits = new int[](7);
        uint256 toBurn = _amount * 3_333 / 10_000;

        for (uint256 i; i < 3; i ++) {
            address token = tokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            address bbPool = poolAddress[token];
            uint256 j = i * 2;
            swaps[j] = IBalancerVault.BatchSwapStep(
                IBalancerPool(bbPool).getPoolId(),
                0,
                j,
                toBurn,
                abi.encode(0)
            );

            swaps[j+1] = IBalancerVault.BatchSwapStep(
                poolId,
                j,
                j + 1,
                0,
                abi.encode(0)
            );

            assets[j] = IAsset(token);
            assets[j+1] = IAsset(bbPool);
            limits[j] = int(balance);
        }
        
        assets[0] = IAsset(pool);

        //Create this contract as the fund manager
        //Set "use internal balance" vars to false since it is a traditional swap
        IBalancerVault.FundManagement memory fundManagement =
            IBalancerVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );
        
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            fundManagement, 
            limits, 
            block.timestamp
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
        
        rewardsContract.withdrawAndUnwrap(
            amount, 
            harvestExtras
        );
    }

    /*
    * @notice
    *   Overwritten main function to sell bal and aura with on batchSwap
    */
    function swapRewardTokens() internal override {
        //Sell Aura and Bal tokens to usdc
        sellRewrds();
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

        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](3);

        //Sell tokenFrom -> bb-tokenFrom
        swaps[0] = IBalancerVault.BatchSwapStep(
            IBalancerPool(poolAddress[_tokenFrom]).getPoolId(),
            0,
            1,
            _amountIn,
            abi.encode(0)
        );
        
        //bb-tokenFrom -> bb-tokenTo
        swaps[1] = IBalancerVault.BatchSwapStep(
            poolId,
            1,
            2,
            0,
            abi.encode(0)
        );

        //bb-tokenTo -> tokneTo
        swaps[2] = IBalancerVault.BatchSwapStep(
            IBalancerPool(poolAddress[_tokenTo]).getPoolId(),
            2,
            3,
            0,
            abi.encode(0)
        );

        //Match the token address with the desired index for this trade
        IAsset[] memory assets = new IAsset[](4);
        assets[0] = IAsset(_tokenFrom);
        assets[1] = IAsset(poolAddress[_tokenFrom]);
        assets[2] = IAsset(poolAddress[_tokenTo]);
        assets[3] = IAsset(_tokenTo);

        //Create this contract as the fund manager
        //Set "use internal balance" vars to false since it is a traditional swap
        IBalancerVault.FundManagement memory fundManagement =
            IBalancerVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );
        
        //Only min we need to set is for the Weth balance going in
        int[] memory limits = new int[](4);
        limits[0] = int(_amountIn);
        limits[3] = int(_minOutAmount);
            
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            fundManagement, 
            limits, 
            block.timestamp
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

            // Call the quote function in CRV pool
            return curvePool.get_dy(
                _getCRVPoolIndex(_tokenFrom), 
                _getCRVPoolIndex(_tokenTo), 
                _amountIn
            );
        }
    }

    /*
    * @notice
    *   function used internally to sell the available Bal tokens
    * @param _to, the token to sell bal to
    * @param _amountIn, the amount of bal to sell
    * @param _amouontOut, the min amount to get out
    */
    function sellRewrds() internal {
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](4);
        
        uint256 balBalance = IERC20(balToken).balanceOf(address(this));
        uint256 auraBalance = IERC20(auraToken).balanceOf(address(this));

        //Sell bal -> weth
        swaps[0] = IBalancerVault.BatchSwapStep(
            IBalancerPool(balEthPool).getPoolId(),
            0,
            2,
            balBalance,
            abi.encode(0)
        );
        
        //Sell WETH -> USDC due to higher liquidity
        swaps[1] = IBalancerVault.BatchSwapStep(
            IBalancerPool(ethUsdcPool).getPoolId(),
            2,
            3,
            0,
            abi.encode(0)
        );

        //Sell Aura -> Weth
        swaps[2] = IBalancerVault.BatchSwapStep(
            IBalancerPool(auraEthPool).getPoolId(),
            1,
            2,
            auraBalance,
            abi.encode(0)
        );

        //Sell WETH -> USDC due to higher liquidity
        swaps[3] = IBalancerVault.BatchSwapStep(
            IBalancerPool(ethUsdcPool).getPoolId(),
            2,
            3,
            0,
            abi.encode(0)
        );

        //Match the token address with the desired index for this trade
        IAsset[] memory assets = new IAsset[](4);
        assets[0] = IAsset(balToken);
        assets[1] = IAsset(auraToken);
        assets[2] = IAsset(referenceToken);
        assets[3] = IAsset(usdcAddress);

        //Create this contract as the fund manager
        //Set "use internal balance" vars to false since it is a traditional swap
        IBalancerVault.FundManagement memory fundManagement =
            IBalancerVault.FundManagement(
                address(this),
                false,
                payable(address(this)),
                false
            );
        
        //Only min we need to set is for the Weth balance going in
        int[] memory limits = new int[](4);
        limits[0] = int(balBalance);
        limits[1] = int(auraBalance);
            
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            fundManagement, 
            limits, 
            block.timestamp
        );
    }

    /*
    * @internal
    *   Function used internally to get the poolId based on the address of a provider token
    * @param _token, The address of providers want
    * @return poolId of the bb-a pool
    */
    function getBalancerPool(address _token) internal returns(address) {
        (IERC20[] memory _tokens, , ) = balancerVault.getPoolTokens(poolId);
        for(uint256 i; i < _tokens.length; i ++) {
            IBalancerPool _pool = IBalancerPool(address(_tokens[i]));
            
            //We cant call getMainToken on the main pool
            if(pool == address(_pool)) continue;
            
            if(_token == _pool.getMainToken()) {
                return address(_pool);
            }
        }
    }

    /*
     * @notice
     *  Function used internally to retrieve the CRV index for a token in a CRV pool
     * @return the token's pool index
     */
    function _getCRVPoolIndex(address _token) internal view returns(int128) {
        uint256 i = 0; 
        int128 poolIndex = 0;
        while (i < 3) {
            if (curvePool.coins(i) == _token) {
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

        if (rewardsContract.earned(address(this)) + IERC20(balToken).balanceOf(address(this)) >= 
            _minRewardToHarvest * (10**IERC20Extended(balToken).decimals()) / RATIO_PRECISION
        ) {
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
        //We only need to set trade factory for non aura/bal tokens
        for(uint256 i = 2; i < _rewardTokens.length; i ++) {
            address token = rewardTokens[i];
        
            IERC20(token).safeApprove(_tradeFactory, type(uint256).max);

            tf.enable(token, usdcAddress);
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
