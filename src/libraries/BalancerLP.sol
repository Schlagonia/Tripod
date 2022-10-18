// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import { IBalancerVault } from "../interfaces/Balancer/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/Balancer/IBalancerPool.sol";
import { IAsset } from "../interfaces/Balancer/IAsset.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBalancerTripod{
    //Struct for each bb pool that makes up the main pool
    struct PoolInfo {
        address token;
        address bbPool;
        bytes32 poolId;
    }

    function poolInfoMapping(address _token) external view returns(PoolInfo memory);
    function poolId() external view returns(bytes32);
    function pool() external view returns(address);
    function toSwapTo() external view returns(address); 
    function balancerVault() external view returns(IBalancerVault);
}

library BalancerLP {

    function tendLpInfo() internal returns(IBalancerVault.BatchSwapStep[] memory swaps, IAsset[] memory assets, int[] memory limits) {
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
}