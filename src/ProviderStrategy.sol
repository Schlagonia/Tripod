// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
pragma experimental ABIEncoderV2;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IERC20Extended.sol";
import {BaseStrategyInitializable} from "@yearnvaults/contracts/BaseStrategy.sol";

interface TripodAPI {
    function closeAllPositions() external;

    function providerA() external view returns (address);

    function providerB() external view returns (address);

    function providerC() external view returns (address);

    function invested(address) external view returns(uint256);

    function estimatedTotalProviderAssets(address provider)
        external
        view
        returns (uint256);

    function migrateProvider(address _newProvider) external;

    function dontInvestWant() external view returns (bool);
}

contract ProviderStrategy is BaseStrategyInitializable {
    using SafeERC20 for IERC20;
    using Address for address;

    address public tripod;

    constructor(address _vault) BaseStrategyInitializable(_vault) {
        initializeThis();
    }

    function initialize(
        address _vault,
        address _strategist,
        address _rewards,
        address _keeper
    ) external override {
        _initialize(_vault, _strategist, _rewards, _keeper);
        initializeThis();
    }

    function initializeThis() internal {
        healthCheck = 0xDDCea799fF1699e98EDF118e0629A974Df7DF012;
    }

    function name() external view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "Strategy_ProviderOf",
                    IERC20Extended(address(want)).symbol(),
                    "To",
                    IERC20Extended(address(tripod)).name()
                )
            );
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return
            balanceOfWant() +
                TripodAPI(tripod).estimatedTotalProviderAssets(address(this));
    }

    function totalDebt() public view returns (uint256) {
        return vault.strategies(address(this)).totalDebt;
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // NOTE: Harvests are all done throught the Tripod contract
        // The tripod will always close the position to realize profits then call harvest here 
        // After the positions are closed all funds are kept at the tripod and can be pulled if needed
        
        //Assure we are not invested
        require(TripodAPI(tripod).invested(address(want)) == 0, "Open Position");

        uint256 amountAvailable = balanceOfWant();
        uint256 amountAtTripod = want.balanceOf(tripod);
        uint256 _totalDebt = totalDebt();
        uint256 totalAssets = amountAvailable + amountAtTripod;

        if (_totalDebt > totalAssets) {
            // we have losses
            _loss = _totalDebt - totalAssets;
        } else {
            // we have profit
            _profit = totalAssets - _totalDebt;
        }

        uint256 amountRequired = _debtOutstanding + _profit;

        if (amountRequired > amountAvailable) {
            uint256 need = amountRequired - amountAvailable;
            if(need > amountAtTripod) {
                need = amountAtTripod;
            }
            want.safeTransferFrom(tripod, address(this), need);

            amountAvailable = balanceOfWant();
            if (_debtOutstanding > amountAvailable) {
                // available funds are lower than the repayment that we need to do
                _profit = 0;
                _debtPayment = amountAvailable;
                // we dont report losses here as the strategy might not be able to return in this harvest
                // but it will still be there for the next harvest
            } else {
                // NOTE: amountRequired is always equal or greater than _debtOutstanding
                // important to use amountAvailable just in case amountRequired is > amountAvailable
                _debtPayment = _debtOutstanding;
                _profit = amountAvailable - _debtPayment;
            }

        } else {
            _debtPayment = _debtOutstanding;
        }
    }

    //Providers should only be harvested directly if we have set Emergency exit == true
    //Otherwise we should alwasys harvest providers through the Tripod
    function harvestTrigger(uint256 /*callCost*/)
        public
        view
        override
        returns (bool)
    {
        return emergencyExit;
    }

    function dontInvestWant() public view returns (bool) {
        // Delegating decision to tripod
        return TripodAPI(tripod).dontInvestWant();
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit || dontInvestWant()) {
            return;
        }

        // Using a push approach (instead of pull)
        uint256 wantBalance = balanceOfWant();
        if (wantBalance > _debtOutstanding) {
            want.safeTransfer(tripod, wantBalance - _debtOutstanding);
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 availableAssets = balanceOfWant();
        if(_amountNeeded >= availableAssets) {
            //If the Tripod is invested we will give the vault what we have but not report a loss
            //There should not be loose want while invested
            if(TripodAPI(tripod).invested(address(want)) != 0) {
                _liquidatedAmount = availableAssets;

            } else {
                //If not invested check for any loose want still at Tripod
                uint256 amount = want.balanceOf(tripod);
            
                if(amount > 0) {
                    //If the Tripod has loose want pull it and recalculate amounts
                    want.safeTransferFrom(tripod, address(this), amount);
                    availableAssets = balanceOfWant();

                    //Check if we got enough to cover whats needed
                    if(availableAssets >= _amountNeeded) {
                        return(_amountNeeded, 0);
                    }
                }
                //This means Tripod is not invested and we need to report a loss
                _liquidatedAmount = availableAssets;
               _loss = _amountNeeded - availableAssets;
            }
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function prepareMigration(address _newStrategy) internal override {
        TripodAPI(tripod).migrateProvider(_newStrategy);
    }

    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
        // solhint-disable-next-line no-empty-blocks
    {}

    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function setTripod(address _tripod) external onlyGovernance {
        require(
            TripodAPI(_tripod).providerA() == address(this) ||
                TripodAPI(_tripod).providerB() == address(this) ||
                    TripodAPI(_tripod).providerC() == address(this),
                        "!providers"
        );
        require(healthCheck != address(0), "need healthCheck");
        tripod = _tripod;
        //Set the keeper to Tripod for the harvests
        keeper = _tripod;
    }

    function liquidateAllPositions()
        internal
        virtual
        override
        returns (uint256 _amountFreed)
    {
        //Closes any open positions and sets DontInvestWant == true
        TripodAPI(tripod).closeAllPositions();

	    uint256 amount = want.balanceOf(tripod);
        if (amount > 0) {
            want.safeTransferFrom(tripod, address(this), amount);
        }
        _amountFreed = balanceOfWant();

    }

    function ethToWant(uint256 _amtInWei)
        public
        view
        override
        returns (uint256)
    {
        // NOTE: using tripod params to avoid changing fixed values for other chains
        // gas price is not important as this will only be used in triggers (queried from off-chain)
        return _amtInWei;
    }

}