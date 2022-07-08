// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

// Import necessary libraries and interfaces:
// NoHedgeJoint to inherit from
import "../Hedges/NoHedgeJoint.sol";

import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {IUniswapV2Router02} from "../interfaces/uniswap/V2/IUniswapV2Router02.sol";

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
    // boolean variable deciding wether to swap in the uni v3 pool or using CRV
    // this can make sense if the pool is unbalanced and price is far from CRV or if the 
    // liquidity remaining in the pool is not enough for the rebalancing swap the strategy needs
    // to perform as the swap function from the uniV3 pool uses a while loop that would get stuck 
    // until we reach gas limit
    bool public useUniRouter;
    // CRV pool to use in case of useCRVPool = true
    address public router;

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
        // The reward tokens are the tokens provided to the pool
        rewardTokens = new address[](2);

        //Use _getCrvPoolIndex to set mappings of indexs
 
        // by default use uni pool to swap as it has lower fees
        useUniRouter = false;
        // Initialize CRV pool to 3pool
        router = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7); //Need to change

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
     *  Function returning the liquidity amount of the LP position
     * @return liquidity from positionInfo
     */
    function balanceOfPool() public view override returns (uint256 liquidity) {
        
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

    /*
     * @notice
     *  Function available for vault managers to set the Uni v3 pool to invest into
     * @param pool, new pool value to use
     */
    function setPool(address _pool) external onlyVaultManagers {
        require(invested[tokenA] == 0 && invested[tokenB] == 0 && invested[tokenC] == 0, "Invested still");
        //Sanity check, at least one should not be 0
        require(_getCRVPoolIndex(tokenA, ICurveFi(_pool)) != 0 || _getCRVPoolIndex(tokenB, ICurveFi(_pool)) != 0, "wrong pool");
        pool = _pool;
    }

    /*
     * @notice
     *  Function returning the current balance of each token in the LP position taking
     * the new level of reserves into account
     * @return _balanceA, balance of tokenA in the LP position
     * @return _balanceB, balance of tokenB in the LP position
     */
    function balanceOfTokensInLP()
        public
        view
        override
        returns (uint256 _balanceA, uint256 _balanceB)
    {
       
    }

    /*
     * @notice
     *  Function returning the amount of rewards earned until now - unclaimed
     * @return uint256 array of tokenA and tokenB earned as rewards
     */
    function pendingRewards() public view override returns (uint256[] memory) {
        // Initialize the array to same length as reward tokens
        uint256[] memory _amountPending = new uint256[](rewardTokens.length);

        
    }

    /*
     * @notice
     *  Function used internally to collect the accrued fees by burn 0 of the LP position
     * and collecting the owed tokens (only fees as no LP has been burnt)
     * @return balance of tokens in the LP (invested amounts)
     */
    function getReward() internal override {
        _burnAndCollect(0);
    }

    /*
     * @notice
     *  Function used internally to open the LP position in the uni v3 pool: 
     *      - calculates the ticks to provide liquidity into
     *      - calculates the liquidity amount to provide based on the ticks 
     *      and amounts to invest
     *      - calls the mint function in the uni v3 pool
     * @return balance of tokens in the LP (invested amounts)
     */
    function createLP() internal override returns (uint256, uint256) {
        
    }

    /*
     * @notice
     *  Function used internally to close the LP position in the uni v3 pool: 
     *      - burns the LP liquidity specified amount
     *      - collects all pending rewards
     *      - re-sets the active position min and max tick to 0
     * @param amount, amount of liquidity to burn
     */
    function burnLP(uint256 _amount) internal override {
        _burnAndCollect(_amount);
        
    }

    /*
     * @notice
     *  Function available to vault managers to burn the LP manually, if for any reason
     * the ticks have been set to 0 (or any different value from the original LP), we make 
     * sure we can always get out of the position
     * This function can be used to only collect fees by passing a 0 amount to burn
     * @param _amount, amount of liquidity to burn
     * @param _minTick, lower limit of position
     * @param _maxTick, upper limit of position
     */
    function burnLPManually(
            uint256 _amount,
            uint256 _minOutTokenA,
            uint256 _minOutTokenB
            ) external onlyVaultManagers {
        _burnAndCollect(_amount);
        require(IERC20(tokenA).balanceOf(address(this)) >= _minOutTokenA && 
                IERC20(tokenB).balanceOf(address(this)) >= _minOutTokenB);
    }

    /*
     * @notice
     *  Function available internally to burn the LP amount specified, for position
     * defined by minTick and maxTick specified and collect the owed tokens
     * @param _amount, amount of liquidity to burn
     */
    function _burnAndCollect(
        uint256 _amount
    ) internal {
        
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
    function swap(   //This needs to be changed to account for reward tokens, needs to also check for minAmountToSell
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn,
        uint256 _minOutAmount
    ) internal override returns (uint256) {
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
                _getCRVPoolIndex(_tokenFrom, _pool), 
                _getCRVPoolIndex(_tokenTo, _pool),
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
        require(_tokenTo == tokenA || _tokenTo == tokenB || _tokenTo == tokenC, "must be valid token"); 
        require(_tokenFrom == tokenA || _tokenFrom == tokenB || _tokenFrom == tokenC, "must be valid token");
        if(useUniRouter){
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
                _getCRVPoolIndex(_tokenFrom, _pool), 
                _getCRVPoolIndex(_tokenTo, _pool), 
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
    function _getCRVPoolIndex(address _token, ICurveFi _pool) internal view returns(int128) {
        uint8 i = 0; 
        int128 poolIndex = 0;
        while (i < 3) {
            if (_pool.coins(i) == _token) {
                return poolIndex;
            }
            i++;
            poolIndex++;
        }
    }

    /*
     * @notice
     *  Function used by governance to swap tokens manually if needed, can be used when closing 
     * the LP position manually and need some re-balancing before sending funds back to the 
     * providers
     * @param swapPath, path of addresses to swap, should be 2 and always tokenA <> tokenB
     * @param swapInAmount, amount of swapPath[0] to swap for swapPath[1]
     * @param minOutAmount, minimum amount of want out
     * @return swapped amount
     */
    function swapTokenForTokenManually(
        bool sellA,
        uint256 swapInAmount,
        uint256 minOutAmount
    ) external onlyGovernance override returns (uint256) {

        if(sellA) {
            return swap(
                tokenA,
                tokenB,
                swapInAmount,
                minOutAmount
                );
        } else {
            return swap(
                tokenB,
                tokenA,
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
     * fees into the existing position, checks whether both pending fee amounts (tokenA and B)
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
    function harvest() external override onlyKeepers {
        getReward();
    }
}
