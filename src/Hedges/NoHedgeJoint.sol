// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import "../Tripod.sol";

abstract contract NoHedgeTripod is Tripod {
    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _weth,
        address _pool
    ) Tripod(_providerA, _providerB, _providerC, _weth, _pool) {}

    function getHedgeBudget(address /*token*/)
        public
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    function getTimeToMaturity() public pure returns (uint256) {
        return 0;
    }

    function getHedgeProfit() public pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function hedgeLP()
        internal
        pure
        override
        returns (uint256 costA, uint256 costB)
    {
        // NO HEDGE
        return (0, 0);
    }

    function closeHedge() internal pure override {
        // NO HEDGE
        return;
    }

    // this function is called by Joint to see if it needs to stop initiating new epochs due to too high volatility
    function _autoProtect() internal pure override returns (bool) {
        return false;
    }
}
