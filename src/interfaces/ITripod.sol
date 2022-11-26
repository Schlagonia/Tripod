// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import {IProviderStrategy} from "./IProviderStrategy.sol";

interface ITripod{
    function pool() external view returns(address);
    function tokenA() external view returns (address);
    function providerA() external view returns (IProviderStrategy);
    function balanceOfA() external view returns(uint256);
    function tokenB() external view returns (address);
    function providerB() external view returns (IProviderStrategy);
    function balanceOfB() external view returns(uint256);
    function tokenC() external view returns (address);
    function providerC() external view returns (IProviderStrategy);
    function balanceOfC() external view returns(uint256);
    function invested(address) external view returns(uint256);
    function totalLpBalance() external view returns(uint256);
    function investedWeight(address)external view returns(uint256);
    function quote(address, address, uint256) external view returns(uint256);
    function usingReference() external view returns(bool);
    function referenceToken() external view returns(address);
    function minAmountToSell() external view returns(uint256);
    function balanceOfTokensInLP() external view returns(uint256, uint256, uint256);
    function getRewardTokens() external view returns(address[] memory);
    function pendingRewards() external view returns(uint256[] memory);
    function dontInvestWant() external view returns(bool);
}

interface IBalancerTripod is ITripod{
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
}