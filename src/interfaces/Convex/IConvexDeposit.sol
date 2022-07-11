//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

interface IConvexDeposit {
    // deposit into convex, receive a tokenized deposit.  parameter to stake immediately (we always do this).
    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _stake
    ) external returns (bool);

    // burn a tokenized deposit (Convex deposit tokens) to receive curve lp tokens back
    function withdraw(uint256 _pid, uint256 _amount) external returns (bool);

    function poolLength() external view returns (uint256);
    function crv() external view returns (address);

    // give us info about a pool based on its pid
    function poolInfo(uint256)
        external
        view
        returns (
            address,
            address,
            address,
            address,
            address,
            bool
        );
}
