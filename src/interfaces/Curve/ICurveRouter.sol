//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

interface ICurveRouter {

    function exchange(address _pool, address _from, address _to, uint256 _amount, uint256 _expected) external returns (uint256);

    function exchange_multiple(
        address[9] memory  _route,
        uint256[3][4] memory _swap_params,
        uint256 _amount,
        uint256 _expected
    ) external returns(uint256);

    function get_exchange_amount(address _pool, address _from, address _to, uint256 _amount) external view returns (uint256);

    function get_input_amount(address _pool, address _from, address _to, uint256 _amount) external view returns (uint256);

    function get_exchange_multiple_amount(
        address[9] memory  _route,
        uint256[3][4] memory _swap_params,
        uint256 _amount
    ) external view returns (uint256);
}