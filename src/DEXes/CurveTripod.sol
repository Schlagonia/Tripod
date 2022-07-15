// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import "forge-std/console.sol";

// Import necessary libraries and interfaces:
// NoHedgeJoint to inherit from
import "../Hedges/NoHedgeTripod.sol";

import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap/V2/IUniswapV2Router02.sol";
import {IConvexDeposit} from "../interfaces/Convex/IConvexDeposit.sol";
import {IConvexRewards} from "../interfaces/Convex/IConvexRewards.sol";

// Safe casting and math
import {SafeCast} from "../libraries/SafeCast.sol";

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

contract CurveTripod is NoHedgeTripod {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    
    // Used for cloning, will automatically be set to false for other clones
    bool public isOriginal = true;
    // boolean variable deciding wether to swap in uni or use CRV for provider tokens
    // this can make sense if the pool is unbalanced and price is far from CRV or if the 
    // liquidity remaining in the pool is not enough for the rebalancing swap the strategy needs
    bool public useUniRouter;
    //Router to use in case of useUnirouter = true
    address public router;

    //The token the Curve pool mints for LP deposits
    address public poolToken;
    mapping (address => uint256) private index;

    //Convex contracts for staking and rewwards
    IConvexDeposit public constant depositContract = 
        IConvexDeposit(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    IConvexRewards public constant rewardsContract =
        IConvexRewards(0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652);
    address private constant convexToken = 
        address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address private constant crvToken =
        address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    uint256 public pid; // this is unique to each pool
    bool public harvestExtras = true; //If we chould claim extras on harvests

    /*
     * @notice
     *  Constructor, only called during original deploy
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, Uni V3 pool to LP
     */
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool
    ) NoHedgeTripod(_providerA, _providerB, _providerC, _referenceToken, _pool) {
        _initializeCurveTripod();
    }

    /*
     * @notice
     *  Constructor equivalent for clones, initializing the joint and the specifics of the strat
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
	 * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, Uni V3 pool to LP
     */
    function initialize(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool
    ) external {
        _initialize(_providerA, _providerB, _providerC, _referenceToken, _pool);
        _initializeCurveTripod();
    }

    /*
     * @notice
     *  Initialize CurveTtripod specifics
     */
    function _initializeCurveTripod() internal {
        //Get the token we will be using
        poolToken = ICurveFi(pool).token();
        pid = rewardsContract.pid();
        // The reward tokens are the tokens provided to the pool
        //This will update them based on current rewards on convex
        updateRewardTokens();

        //Use _getCrvPoolIndex to set mappings of index's
        index[tokenA] = _getCRVPoolIndex(tokenA);
        index[tokenB] = _getCRVPoolIndex(tokenB);
        index[tokenC] = _getCRVPoolIndex(tokenC);

        // by default use crv pool to swap
        useUniRouter = false;
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
     * @param _pool, Uni V3 pool to LP
     * @return newJoint, address of newly deployed joint
     */
    function cloneCurveTripod(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool
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

        CurveTripod(newJoint).initialize(
            _providerA,
            _providerB,
            _providerC,
            _referenceToken,
            _pool
        );

        emit Cloned(newJoint);
    }

    /*
     * @notice
     *  Function returning the name of the joint in the format "NoHedgeUniV3StablesJoint(USDC-DAI)"
     * @return name of the strategy
     */
    function name() external view override returns (string memory) {
        return string(abi.encodePacked("TriCryptoJointNoHedge"));
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

    function updateRewardTokens() internal returns(address[] memory tokens) {
        delete rewardTokens; //empty the rewardsTokens and rebuild

        //We know we will be getting convex and curve at least
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
     *  Function returning the current balance of each token in the LP position taking
     * the new level of reserves into account
     * @return _balanceA, balance of tokenA in the LP position
     * @return _balanceB, balance of tokenB in the LP position
     * @return _balanceC, balance of tokenC in LP position
     */
    function balanceOfTokensInLP()
        public
        view
        override
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC) 
    {
        //User the VP to get dollar value then oracles to adjust;
        //Could use actual pool values, but that could be manipulated
        uint256 lpBalance = totalLpBalance();
        if(lpBalance == 0) return (0, 0, 0);

        ICurveFi _pool = ICurveFi(pool);
        // use calc_Withdrawone_coin for a third of each
        uint256 third = lpBalance * 3_333 / 10_000;
        _balanceA = _pool.calc_withdraw_one_coin(third, index[tokenA]);
        _balanceB = _pool.calc_withdraw_one_coin(third, index[tokenB]);
        _balanceC = _pool.calc_withdraw_one_coin(third, index[tokenC]);
        console.log("Expected A balance ", _balanceA);
        console.log("Expected B balance ", _balanceB);
        console.log("Expected C balance ", _balanceC);
    }

    /*
     * @notice
     *  Function returning the amount of rewards earned until now - unclaimed
     * @return uint256 array of tokenA and tokenB earned as rewards
     */
    function pendingRewards() public view override returns (uint256[] memory) {
        // Initialize the array to same length as reward tokens
        uint256[] memory _amountPending = new uint256[](rewardTokens.length);
        console.log("Reward tokens length ", rewardTokens.length);
        //Save the earned CrV rewards to 0 where crv will be
        _amountPending[0] = rewardsContract.earned(address(this));
        //Just place 0 for convex, avoids complex math and underestimates rewards for safety
        _amountPending[1] = 0;

        //We skipped the first two of the rewards list
        for (uint256 i; i < rewardsContract.extraRewardsLength(); i++) {
            address virtualRewardsPool = rewardsContract.extraRewards(i);
            //Spot 2 in our array will correspond with 0 in Convex's
            _amountPending[i + 2] = IConvexRewards(virtualRewardsPool).earned(address(this));
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
     *      - burns the LP liquidity specified amount
     *      - collects all pending rewards
     *  
     * @param amount, amount of liquidity to burn
     */
    function burnLP(uint256 _amount) internal override {

        uint256[3] memory amounts;

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
    function withdrawLP() internal override {
        
        rewardsContract.withdrawAndUnwrap(
            rewardsContract.balanceOf(address(this)), 
            harvestExtras
        );
    }

    /*
     * @notice
     *  Function available to vault managers to burn the LP manually,
     *  Will first unstake the amount specified, may need to adjust harvestExtras first
     * @param _amount, amount of liquidity to burn
     * @param _minOutTokenA, Min of A we should have after
     * @param _minOuttokenB, min of B we should have after
     * @param _minOutTokenC, min of C we should have after
     */
    function burnLPManually(
            uint256 _amount,
            uint256 _minOutTokenA,
            uint256 _minOutTokenB,
            uint256 _minOutTokenC
    ) external onlyVaultManagers {
        rewardsContract.withdrawAndUnwrap(_amount, harvestExtras);
        burnLP(_amount);   ///This should be implemented manually in amounts - currentBalance
        require(balanceOfA() >= _minOutTokenA && 
                balanceOfB() >= _minOutTokenB &&
                balanceOfC() >= _minOutTokenC,
                "Not enough out");
    }

    //To swap out of the reward tokens
    function swapRewardTokens() internal override {
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
    ) internal returns (uint256) {
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
            return IERC20(_tokenTo).balanceOf(address(this)) - prevBalance;

        } else {
            ICurveFi _pool = ICurveFi(pool);
        
            // Allow necessary amount for CRV pool
            _checkAllowance(pool, IERC20(_tokenFrom), _amountIn);
            // Perform swap
            _pool.exchange(
                index[_tokenFrom], 
                index[_tokenTo],
                _amountIn, 
                _minOutAmount
            );
            return IERC20(_tokenTo).balanceOf(address(this)) - prevBalance;
        }
    }

    /*
     * @notice
     *  Function used internally to quote a potential rebalancing swap without actually 
     * executing it. Same as the swap function, will simulate the trade either on the uni v3
     * pool or CRV pool based on useCRVPool
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
        if(_amountIn <= minAmountToSell) {
            return 0;
        }

        require(_tokenTo == tokenA || _tokenTo == tokenB || _tokenTo == tokenC, "must be valid token"); 

        //We should only use curve if from and to is one of the LP tokens AND useUniRouter == false
        bool useCurve = false;
        if(_tokenFrom == tokenA || _tokenFrom == tokenB || _tokenFrom == tokenC) useCurve = true;
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
     *  Function used internally to retrieve the CRV index for a token in a CRV pool, for example
     * 3Pool uses:
     * - 0 is DAI
     * - 1 is USDC
     * - 2 is USDT
     * @return in128 containing the token's pool index
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

    // check if the current baseFee is below our external target
    function isBaseFeeAcceptable() internal view returns (bool) {
        return
            IBaseFee(0xb5e1CAcB567d98faaDB60a1fD4820720141f064F)
                .isCurrentBaseFeeAcceptable();
    }

    /*
     * @notice
     *  Function used by keepers to assess whether to harvest the joint and compound generated
     * fees into the existing position
     * are greater than minRewardToHarvest
     * @param callCost, call cost parameter
     * @return bool amount assessing whether to harvest or not
     */
    function harvestTrigger(uint256 callCost) external view override returns (bool) {

        uint256 _minRewardToHarvest = minRewardToHarvest;
        if (_minRewardToHarvest == 0) {
            return false;
        }

        // check if the base fee gas price is higher than we allow. if it is, block harvests.
        if (!isBaseFeeAcceptable()) {
            return false;
        }

        uint256[] memory _pendingRewards = pendingRewards();

        if (_pendingRewards[0] >= _minRewardToHarvest * (10**IERC20Extended(rewardTokens[0]).decimals()) / RATIO_PRECISION && 
            _pendingRewards[1] >= _minRewardToHarvest * (10**IERC20Extended(rewardTokens[1]).decimals()) / RATIO_PRECISION
        ) {
            return true;
        }

    }

    /*
     * @notice
     *  Function used by harvest trigger in the providers to assess whether to harvest it as
     * the joint may have gone out of bounds. If debt ratio is kept in the vaults, the joint
     * re-centers, if debt ratio is 0, the joint is simpley closed and funds are sent back
     * to each provider
     * @return bool amount assessing whether to end the epoch or not
     */
    function shouldEndEpoch() external view override returns (bool) {
        
    }

    /*
     * @notice
     *  Function used by keepers to compound the generated feed into the existing position
     * in the joint. There may be some funds not used in the position and left idle in the 
     * joint
     */
    function tend() external override onlyKeepers {
        getReward();
    }

    /*
    * @notice
    *   Trigger to tell Keepers if they should call tend()
    *   Can be implemented with an overRide if applicable
    */
    function tendTrigger(uint256 /*callCost*/) external view override returns (bool) {
        return false;
    }

        /*
     * @notice
     *  Function available internally deciding the swapping path to follow
     * @param _token_in, address of the token to swap from
     * @param _token_to, address of the token to swap to
     * @return address array of the swap path to follow
     */
    function getTokenOutPath(address _token_in, address _token_out)
        internal
        view
        returns (address[] memory _path)
    {   
        address _tokenA = tokenA;
        address _tokenB = tokenB;
        bool isReferenceToken = _token_in == address(referenceToken) ||
            _token_out == address(referenceToken);
        bool is_internal = (_token_in == _tokenA && _token_out == _tokenB) ||
            (_token_in == _tokenB && _token_out == _tokenA);
        _path = new address[](isReferenceToken || is_internal ? 2 : 3);
        _path[0] = _token_in;
        if (isReferenceToken || is_internal) {
            _path[1] = _token_out;
        } else {
            _path[1] = address(referenceToken);
            _path[2] = _token_out;
        }
    }

    function maxApprove(address _token, address _contract) internal{
        IERC20(_token).safeApprove(_contract, type(uint256).max);
    }
}
