// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import {IVault} from "./Vault.sol";

interface IProviderStrategy {
    function vault() external view returns (IVault);

    function keeper() external view returns (address);

    function want() external view returns (address);

    function balanceOfWant() external view returns (uint256);

    function harvest() external;
}