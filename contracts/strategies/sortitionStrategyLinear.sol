/**
 *  @authors: [@shotaronowhere]
 *  @reviewers: []
 *  @auditors: []
 */

pragma solidity ^0.8.0;

import "./sortitionStrategyBase.sol";

/**
 *  @title sortitionStrategyLinear
 *  @author ShotaroNowhere - <shawtarohgn@gmail.com>
 *  @dev Strategy Interface for drawing.
 */
contract sortitionStrategyLinear is sortitionStrategyBase{

    constructor(
        ICore _core,
        RNG _rng,
        uint256 _minMiningTime
    ) sortitionStrategyBase (_core, _rng, _minMiningTime){ }

    function isInStrategy(uint48 _drawnAccountIndex, uint32 nonce) internal view override returns (bool){
        return nonce < uint32(core.getStakeIDToAccounts(core.indexToStakeID(_drawnAccountIndex)).stakedTokens/10**18);
    }
}