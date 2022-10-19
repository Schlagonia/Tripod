// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

import "./BalancerTripod.sol";

contract BalancerTripodCloner {
    address public immutable original;

    event Cloned(address indexed clone);
    event Deployed(address indexed original);

    constructor(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) {
        BalancerTripod _original = new BalancerTripod(_providerA, _providerB, _providerC, _referenceToken, _pool, _rewardsContract);
        emit Deployed(address(_original));

        original = address(_original);
    }

    function name() external pure returns (string memory) {
        return "Yearn-BalanacerTripodCloner@0.4.3";
    }

    /*
     * @notice
     *  Cloning function to migrate/ deploy to other pools
     * @param _providerA, provider strategy of tokenA
     * @param _providerB, provider strategy of tokenB
     * @param _providerC, provider strrategy of tokenC
     * @param _referenceToken, token to use as reference, for pricing oracles and paying hedging costs (if any)
     * @param _pool, pool to LP
     * @param _rewardsContract The Aura rewards contract specific to this LP token
     * @return newTripod, address of newly deployed tripod
     */
    function cloneBalancerTripod(
        address _providerA,
        address _providerB,
        address _providerC,
        address _referenceToken,
        address _pool,
        address _rewardsContract
    ) external returns (address newTripod) {
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(original);

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            newTripod := create(0, clone_code, 0x37)
        }

        BalancerTripod(newTripod).initialize(
            _providerA,
            _providerB,
            _providerC,
            _referenceToken,
            _pool,
            _rewardsContract
        );

        emit Cloned(newTripod);
    }
}