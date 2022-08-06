//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

interface ICurveFi {

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 min_mint_amount,
        bool _use_underlying
    ) external payable returns (uint256);

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) external payable;

    function remove_liquidity(
        uint256 _amount, 
        uint256[3] calldata amounts
    ) external;

    function remove_liquidity(
        uint256 _amount, 
        uint256[3] calldata amounts,
        bool use_underlying
    ) external;

    function remove_liquidity_imbalance(
        uint256[3] calldata amounts, 
        uint256 max_burn_amount
    ) external;

    function remove_liquidity_imbalance(
        uint256[3] calldata amount, 
        uint256 max_burn_amount,
        bool use_underlying
    ) external;

    function calc_withdraw_one_coin(
        uint256 _token_amount,
        int128 _index
    ) external view returns (uint256);

    function calc_withdraw_one_coin(
        uint256 _amount,
        int128 i,
        bool use_underlying
    ) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount,
        bool use_underlying
    ) external;

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