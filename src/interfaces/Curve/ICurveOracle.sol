//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;


interface ICurveOracle {

    function lp_price() external view returns(uint256);    
}
