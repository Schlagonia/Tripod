//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

interface ICurveFi {

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external;

    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 _fromIndex, 
        int128 _toIndex, 
        uint256 _from_amount
    ) external view returns (uint256);

    function balances(int128) external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function coins(uint256) external view returns (address);

}