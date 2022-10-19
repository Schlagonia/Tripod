// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";
import {ICurveFi} from "../interfaces/Curve/IcurveFi.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeedRegistry} from "../interfaces/IFeedRegistry.sol";
import "../interfaces/IERC20Extended.sol";

interface IBalancerTripod{
    //Struct for each bb pool that makes up the main pool
    struct PoolInfo {
        address token;
        address bbPool;
        bytes32 poolId;
    }

    function poolInfo(uint256) external view returns(PoolInfo memory);
    function curveIndex(address) external view returns(int128);
    function poolId() external view returns(bytes32);
    function toSwapToIndex() external view returns(uint256); 
    function toSwapToPoolId() external view returns(bytes32);

    function balToken() external view returns(address);

    function pool() external view returns(address);
    function tokenA() external view returns (address);
    function balanceOfA() external view returns(uint256);
    function tokenB() external view returns (address);
    function balanceOfB() external view returns(uint256);
    function tokenC() external view returns (address);
    function balanceOfC() external view returns(uint256);
    function invested(address) external view returns(uint256);
    function totalLpBalance() external view returns(uint256);
    function investedWeight(address)external view returns(uint256);
    function quote(address, address, uint256) external view returns(uint256);
    function usingReference() external view returns(bool);
    function referenceToken() external view returns(address);
    function balanceOfTokensInLP() external view returns(uint256, uint256, uint256);
    function getRewardTokens() external view returns(address[] memory);
    function pendingRewards() external view returns(uint256[] memory);
}

library BalancerLP {

    //The main Balancer vault
    IBalancerVault internal constant balancerVault = 
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    //Pools we use for swapping rewards
    bytes32 internal constant balEthPoolId = 
        bytes32(0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014);
    bytes32 internal constant auraEthPoolId = 
        bytes32(0xc29562b045d80fd77c69bec09541f5c16fe20d9d000200000000000000000251);

    //Base Reward Tokens
    address internal constant auraToken = 
        0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address internal constant balToken =
        address(0xba100000625a3754423978a60c9317c58a424e3D);

    ICurveFi internal constant curvePool =
        ICurveFi(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    /*
    * @notice
    *   This will return the expected balance of each token based on our lp balance
    *       This will not take into account the invested weight so it can be used to determine how in
            or out balance the pool currently is
    */
    function balanceOfTokensInLP(address _tripod)
        public
        view
        returns (uint256 _balanceA, uint256 _balanceB, uint256 _balanceC) 
    {
        IBalancerTripod tripod = IBalancerTripod(_tripod);
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
        address _tripod,
        address _tokenFrom,
        address _tokenTo,
        uint256 _amountIn
    ) public view returns (uint256) {
        if(_amountIn == 0) {
            return 0;
        }
        IBalancerTripod tripod = IBalancerTripod(_tripod);

        require(_tokenTo == tripod.tokenA() || 
                    _tokenTo == tripod.tokenB() || 
                        _tokenTo == tripod.tokenC()); 

        if(_tokenFrom == tripod.balToken()) {
            (, int256 balPrice,,,) = IFeedRegistry(0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf).latestRoundData(
                tripod.balToken(),
                address(0x0000000000000000000000000000000000000348) // USD
            );

            //Get the latest oracle price for bal * amount of bal / (1e8 + (diff of token decimals to bal decimals)) to adjust oracle price that is 1e8
            return uint256(balPrice) * _amountIn / (10 ** (8 + (18 - IERC20Extended(_tokenTo).decimals())));
        } else if(_tokenFrom == tripod.tokenA() || _tokenFrom == tripod.tokenB() || _tokenFrom == tripod.tokenC()){

            // Call the quote function in CRV 3pool
            return curvePool.get_dy(
                tripod.curveIndex(_tokenFrom), 
                tripod.curveIndex(_tokenTo), 
                _amountIn
            );
        } else {
            return 0;
        }
    }
/*
    function tendLpInfo() public returns(IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
        IBalancerTripod tripod = IBalancerTripod(msg.sender);
        swaps = new IBalancerVault.BatchSwapStep[](2);
    
        assets = new IAsset[](3);
        limits = new int[](3);

        address _toSwapTo = tripod.toSwapTo();
        uint256 balance = IERC20(_toSwapTo).balanceOf(address(this));
        IBalancerTripod.PoolInfo memory _poolInfo = tripod.poolInfoMapping(_toSwapTo);

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

        //Match the address with the index we used above
        assets[0] = IAsset(_toSwapTo);
        assets[1] = IAsset(_poolInfo.bbPool);
        assets[2] = IAsset(tripod.pool());

        //Only need to set the toSwapTo balance goin in
        limits[0] = int(balance);

        tripod.balancerVault().batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, 
            assets, 
            getFundManagement(), 
            limits, 
            block.timestamp
        );
    }
*/
    function getRewardSwaps(address _tripod, uint256 balBalance, uint256 auraBalance) public view returns(IBalancerVault.BatchSwapStep[] memory swaps) {
        IBalancerTripod tripod = IBalancerTripod(_tripod);
        swaps = new IBalancerVault.BatchSwapStep[](4);

        //Sell bal -> weth
        swaps[0] = IBalancerVault.BatchSwapStep(
            balEthPoolId,
            0,  //Index to use for Bal
            2,  //index to use for Weth
            balBalance,
            abi.encode(0)
        );
        
        //Sell WETH -> toSwapTo token set
        swaps[1] = IBalancerVault.BatchSwapStep(
            tripod.toSwapToPoolId(),
            2,  //index to use for Weth
            3,  //Index to use for toSwapTo
            0,
            abi.encode(0)
        );

        //Sell Aura -> Weth
        swaps[2] = IBalancerVault.BatchSwapStep(
            auraEthPoolId,
            1,  //Index to use for Aura
            2,  //index to use for Weth
            auraBalance,
            abi.encode(0)
        );

        //Sell WETH -> toSwapTo
        swaps[3] = IBalancerVault.BatchSwapStep(
            tripod.toSwapToPoolId(),
            2,  //index to use for Weth
            3,  //index to use for toSwapTo
            0,
            abi.encode(0)
        );
    }
    
    function getRewardAssets(address _tripod) public view returns(IAsset[] memory) {
        IBalancerTripod tripod = IBalancerTripod(_tripod);
        IAsset[] memory assets = new IAsset[](4);
        assets[0] = IAsset(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        assets[1] = IAsset(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        assets[2] = IAsset(tripod.referenceToken());
        assets[3] = IAsset(tripod.poolInfo(tripod.toSwapToIndex()).token);
        return assets;
    }

    function swapRewardTokens(address _tripod) public {
        IBalancerTripod tripod =IBalancerTripod(_tripod);
        uint256 balBalance = IERC20(balToken).balanceOf(_tripod);
        uint256 auraBalance = IERC20(auraToken).balanceOf(_tripod);

        //Cant swap 0
        if(balBalance == 0 || auraBalance == 0) return;

        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](4);
        //Sell bal -> weth
        swaps[0] = IBalancerVault.BatchSwapStep(
            balEthPoolId,
            0,  //Index to use for Bal
            2,  //index to use for Weth
            balBalance,
            abi.encode(0)
        );
        
        //Sell WETH -> toSwapTo token set
        swaps[1] = IBalancerVault.BatchSwapStep(
            tripod.toSwapToPoolId(),
            2,  //index to use for Weth
            3,  //Index to use for toSwapTo
            0,
            abi.encode(0)
        );

        //Sell Aura -> Weth
        swaps[2] = IBalancerVault.BatchSwapStep(
            auraEthPoolId,
            1,  //Index to use for Aura
            2,  //index to use for Weth
            auraBalance,
            abi.encode(0)
        );

        //Sell WETH -> toSwapTo
        swaps[3] = IBalancerVault.BatchSwapStep(
            tripod.toSwapToPoolId(),
            2,  //index to use for Weth
            3,  //index to use for toSwapTo
            0,
            abi.encode(0)
        );

        //Match the token address with the applicable index from above for this trade
        IAsset[] memory assets = new IAsset[](4);
        assets[0] = IAsset(balToken);
        assets[1] = IAsset(auraToken);
        assets[2] = IAsset(tripod.referenceToken());
        assets[3] = IAsset(tripod.poolInfo(tripod.toSwapToIndex()).token);
        
        //Only min we need to set is for the balances going in, match with their index
        int[] memory limits = new int[](4);
        limits[0] = int(balBalance);
        limits[1] = int(auraBalance);
        
        //IBalancerVault.BatchSwapStep[] memory swaps = BalancerLP.getRewardSwaps(address(this), balBalance, auraBalance);
        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN, 
            swaps, //BalancerLP.getRewardSwaps(address(this), balBalance, auraBalance), 
            assets, //assets, 
            getFundManagement(_tripod), 
            limits, 
            block.timestamp
        );
    }

    function createTendLP(address _tripod) public {
        IBalancerTripod tripod = IBalancerTripod(_tripod);
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](2);
        
        IAsset[] memory assets = new IAsset[](3);
        int[] memory limits = new int[](3);

        //address _toSwapTo = toSwapTo;
        IBalancerTripod.PoolInfo memory _poolInfo = tripod.poolInfo(tripod.toSwapToIndex());
        uint256 balance = IERC20(_poolInfo.token).balanceOf(_tripod);
        
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

        //Match the address with the index we used above
        assets[0] = IAsset(_poolInfo.token);
        assets[1] = IAsset(_poolInfo.bbPool);
        assets[2] = IAsset(tripod.pool());

        //Only need to set the toSwapTo balance goin in
        limits[0] = int(balance);
    }

    function tendAssets(address _tripod) public view returns(IAsset[] memory) {
        IBalancerTripod tripod = IBalancerTripod(_tripod);
  
        IAsset[] memory assets = new IAsset[](3);

        //address _toSwapTo = toSwapTo;
        IBalancerTripod.PoolInfo memory _poolInfo = tripod.poolInfo(0);
        assets[0] = IAsset(_poolInfo.token);
        assets[1] = IAsset(_poolInfo.bbPool);
        assets[2] = IAsset(tripod.pool());

        return assets;
    }

    function tendLimits(address _tripod, uint256 balance) public pure returns(int[] memory limits) {
        limits = new int[](3);
        limits[0] = int(balance);
        return limits;
    }


    function getFundManagement(address _address) 
        public 
        view 
        returns (IBalancerVault.FundManagement memory fundManagement) 
    {
        fundManagement = IBalancerVault.FundManagement(
                _address,
                false,
                payable(_address),
                false
            );
    }
    
}