// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";
import {ICurveFi} from "../interfaces/Curve/ICurveFi.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeedRegistry} from "../interfaces/IFeedRegistry.sol";
import "../interfaces/IERC20Extended.sol";

import {IBalancerTripod} from "../interfaces/ITripod.sol";

library BalancerHelper {

    //The main Balancer vault
    IBalancerVault internal constant balancerVault = 
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ICurveFi internal constant curvePool =
        ICurveFi(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address internal constant balToken =
        0xba100000625a3754423978a60c9317c58a424e3D;
    uint256 internal constant RATIO_PRECISION = 1e18;

    /*
    * @notice
    *   This will return the expected balance of each token based on our lp balance
    *       This will not take into account the invested weight so it can be used to determine how in
            or out balance the pool currently is
    */
    function balanceOfTokensInLP()
        public
        view
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC) 
    {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        uint256 lpBalance = tripod.totalLpBalance();
     
        if(lpBalance == 0) return (0, 0, 0);

        //Get the total tokens in the lp and the relative portion for each provider token
        uint256 total;
        (IERC20[] memory tokens, uint256[] memory balances, ) = balancerVault.getPoolTokens(tripod.poolId());
        for(uint256 i; i < tokens.length; ++i) {
            address token = address(tokens[i]);
   
            if(token == tripod.pool()) continue;
            uint256 balance = balances[i];
     
            if(token == tripod.poolInfo(0).bbPool) {
                _balanceA = balance;
            } else if(token == tripod.poolInfo(1).bbPool) {
                _balanceB = balance;
            } else if(token == tripod.poolInfo(2).bbPool){
                _balanceC = balance;
            }

            total += balance;
        }

        unchecked {
            uint256 lpDollarValue = lpBalance * IBalancerPool(tripod.pool()).getRate() / 1e18;

            //Adjust for decimals and pool balance
            _balanceA = (lpDollarValue * _balanceA) / (total * (10 ** (18 - IERC20Extended(tripod.tokenA()).decimals())));
            _balanceB = (lpDollarValue * _balanceB) / (total * (10 ** (18 - IERC20Extended(tripod.tokenB()).decimals())));
            _balanceC = (lpDollarValue * _balanceC) / (total * (10 ** (18 - IERC20Extended(tripod.tokenC()).decimals())));
        }
    }

    function quote(
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) public view returns(uint256 amountOut) {
        if(_amountIn == 0) {
            return 0;
        }

        IBalancerTripod tripod = IBalancerTripod(address(this));

        require(_tokenTo == tripod.tokenA() || 
                    _tokenTo == tripod.tokenB() || 
                        _tokenTo == tripod.tokenC()); 

        if(_tokenFrom == balToken) {
            (, int256 balPrice,,,) = IFeedRegistry(0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf).latestRoundData(
                balToken,
                address(0x0000000000000000000000000000000000000348) // USD
            );

            //Get the latest oracle price for bal * amount of bal / (1e8 + (diff of token decimals to bal decimals)) to adjust oracle price that is 1e8
            amountOut = uint256(balPrice) * _amountIn / (10 ** (8 + (18 - IERC20Extended(_tokenTo).decimals())));
        } else if(_tokenFrom == tripod.tokenA() || _tokenFrom == tripod.tokenB() || _tokenFrom == tripod.tokenC()){

            // Call the quote function in CRV 3pool
            amountOut = curvePool.get_dy(
                tripod.curveIndex(_tokenFrom), 
                tripod.curveIndex(_tokenTo), 
                _amountIn
            );
        } else {
            amountOut = 0;
        }
    }

    function getCreateLPVariables() public view returns(IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        swaps = new IBalancerVault.BatchSwapStep[](6);
        assets = new IAsset[](7);
        limits = new int[](7);
        bytes32 poolId = tripod.poolId();

        //Need two trades for each provider token to create the LP
        //Each trade goes token -> bb-token -> mainPool
        IBalancerTripod.PoolInfo memory _poolInfo;
        for (uint256 i; i < 3; ++i) {
            _poolInfo = tripod.poolInfo(i);
            address token = _poolInfo.token;
            uint256 balance = IERC20(token).balanceOf(address(this));
            //Used to offset the array to the correct index
            uint256 j = i * 2;
            //Swap fromt token -> bb-token
            swaps[j] = IBalancerVault.BatchSwapStep(
                _poolInfo.poolId,
                j,  //index for token
                j + 1,  //index for bb-token
                balance,
                abi.encode(0)
            );

            //swap from bb-token -> main pool
            swaps[j+1] = IBalancerVault.BatchSwapStep(
                poolId,
                j + 1,  //index for bb-token
                6,  //index for main pool
                0,
                abi.encode(0)
            );

            //Match the index used with the correct address and balance
            assets[j] = IAsset(token);
            assets[j+1] = IAsset(_poolInfo.bbPool);
            limits[j] = int(balance);
        }
        //Set the main lp token as the last in the array
        assets[6] = IAsset(tripod.pool());
    }

    function getBurnLPVariables(
        uint256 _amount
    ) public view returns(IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        swaps = new IBalancerVault.BatchSwapStep[](6);
        assets = new IAsset[](7);
        limits = new int[](7);
        //Burn a third for each token
        uint256 burnt;
        bytes32 poolId = tripod.poolId();

        //Need seperate swaps for each provider token
        //Each swap goes mainPool -> bb-token -> token
        IBalancerTripod.PoolInfo memory _poolInfo;
        for (uint256 i; i < 3; ++i) {
            _poolInfo = tripod.poolInfo(i);
            uint256 weightedToBurn = _amount * tripod.investedWeight(_poolInfo.token) / RATIO_PRECISION;
            uint256 j = i * 2;
            //Swap from main pool -> bb-token
            swaps[j] = IBalancerVault.BatchSwapStep(
                poolId,
                6,  //Index used for main pool
                j,  //Index for bb-token pool
                i == 2 ? _amount - burnt : weightedToBurn, //To make sure we burn all of the LP
                abi.encode(0)
            );

            //swap from bb-token -> token
            swaps[j+1] = IBalancerVault.BatchSwapStep(
                _poolInfo.poolId,
                j,  //Index used for bb-token pool
                j + 1,  //Index used for token
                0,
                abi.encode(0)
            );

            //adjust the already burnt LP amount
            burnt += weightedToBurn;
            //Match the index used with the applicable address
            assets[j] = IAsset(_poolInfo.bbPool);
            assets[j+1] = IAsset(_poolInfo.token);
        }
        //Set the lp token as asset 6
        assets[6] = IAsset(tripod.pool());
        limits[6] = int(_amount);
    }


    function getRewardVariables(
        uint256 balBalance, 
        uint256 auraBalance
    ) public view returns (IBalancerVault.BatchSwapStep[] memory _swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        _swaps = new IBalancerVault.BatchSwapStep[](4);
        assets = new IAsset[](4);
        limits = new int[](4);
        
        bytes32 toSwapToPoolId = tripod.toSwapToPoolId();
        _swaps[0] = IBalancerVault.BatchSwapStep(
            0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014, //bal-eth pool id
            0,  //Index to use for Bal
            2,  //index to use for Weth
            balBalance,
            abi.encode(0)
        );
        
        //Sell WETH -> toSwapTo token set
        _swaps[1] = IBalancerVault.BatchSwapStep(
            toSwapToPoolId,
            2,  //index to use for Weth
            3,  //Index to use for toSwapTo
            0,
            abi.encode(0)
        );

        //Sell Aura -> Weth
        _swaps[2] = IBalancerVault.BatchSwapStep(
            0xc29562b045d80fd77c69bec09541f5c16fe20d9d000200000000000000000251, //aura eth pool id
            1,  //Index to use for Aura
            2,  //index to use for Weth
            auraBalance,
            abi.encode(0)
        );

        //Sell WETH -> toSwapTo
        _swaps[3] = IBalancerVault.BatchSwapStep(
            toSwapToPoolId,
            2,  //index to use for Weth
            3,  //index to use for toSwapTo
            0,
            abi.encode(0)
        );

        assets[0] = IAsset(0xba100000625a3754423978a60c9317c58a424e3D); //bal token
        assets[1] = IAsset(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF); //Aura token
        assets[2] = IAsset(tripod.referenceToken()); //weth
        assets[3] = IAsset(tripod.poolInfo(tripod.toSwapToIndex()).token); //to Swap to token

        limits[0] = int(balBalance);
        limits[1] = int(auraBalance);
    }

    function getTendVariables(
        IBalancerTripod.PoolInfo memory _poolInfo,
        uint256 balance
    ) public view returns(IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        swaps = new IBalancerVault.BatchSwapStep[](2);
        assets = new IAsset[](3);
        limits = new int[](3);

        swaps[0] = IBalancerVault.BatchSwapStep(
            _poolInfo.poolId,
            0,  //Index to use for toSwapTo
            1,  //Index to use for bb-toSwapTo
            balance,
            abi.encode(0)
        );

        swaps[1] = IBalancerVault.BatchSwapStep(
            tripod.poolId(),
            1,  //Index to use for bb-toSwapTo
            2,  //Index to use for the main lp token
            0, 
            abi.encode(0)
        );

        assets[0] = IAsset(_poolInfo.token);
        assets[1] = IAsset(_poolInfo.bbPool);
        assets[2] = IAsset(tripod.pool());

        //Only need to set the toSwapTo balance goin in
        limits[0] = int(balance);
    }

    function getWithdrawToOneTokenVariables(
        uint256 _amount, 
        IBalancerTripod.PoolInfo memory _poolInfo
    ) public view returns (IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(address(this));
        swaps = new IBalancerVault.BatchSwapStep[](2);
        assets = new IAsset[](3);
        limits = new int[](3);

        swaps[0] = IBalancerVault.BatchSwapStep(
            tripod.poolId(),
            0,  //Index to use for toSwapTo
            1,  //Index to use for bb-toSwapTo
            _amount,
            abi.encode(0)
        );

        swaps[1] = IBalancerVault.BatchSwapStep(
            _poolInfo.poolId,
            1,  //Index to use for bb-toSwapTo
            2,  //Index to use for the main lp token
            0, 
            abi.encode(0)
        );

        assets[0] = IAsset(tripod.pool());
        assets[1] = IAsset(_poolInfo.bbPool);
        assets[2] = IAsset(_poolInfo.token);

        //Only need to set the toSwapTo balance goin in
        limits[0] = int(_amount);
    }

}