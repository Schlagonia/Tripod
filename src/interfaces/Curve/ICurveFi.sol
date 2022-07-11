//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

interface ICurveFi {
    function get_virtual_price() external view returns (uint256);

    function base_virtual_price() external view returns (uint256);

    function add_liquidity(
        // sBTC pool
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) external;

    function coins(uint256) external view returns (address);

    function token() external view returns (address);

    function pool() external view returns (address);

    function remove_liquidity_imbalance(uint256[5] calldata amounts, uint256 max_burn_amount) external;

    function remove_liquidity(uint256 _amount, uint256[3] calldata amounts) external;

    function calc_withdraw_one_coin(uint256 _amount, uint256 i) external view returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external;

     function remove_liquidity_one_coin(uint256 _tokenAmount, uint256 i, uint256 _min_amount) external;

    function exchange(
        uint256 from,
        uint256 to,
        uint256 _from_amount,
        uint256 _min_to_amount
    ) external payable;

    function balances(int128) external view returns (uint256);

    function get_dy(
        uint256 from,
        uint256 to,
        uint256 _from_amount
    ) external view returns (uint256);

    function calc_token_amount(uint256[3] calldata amounts, bool is_deposit) external view returns (uint256);

}
