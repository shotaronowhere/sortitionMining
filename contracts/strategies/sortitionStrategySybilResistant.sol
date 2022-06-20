/**
 *  @authors: [@shotaronowhere]
 *  @reviewers: []
 *  @auditors: []
 */

pragma solidity ^0.8.0;

import "./sortitionStrategyBase.sol";

interface IProofOfHumanity {
    /** @dev Return true if the submission is registered and not expired.
     *  @param _submissionID The address of the submission.
     *  @return Whether the submission is registered or not.
     */
    function isRegistered(address _submissionID) external view returns (bool);
}

/**
 *  @title sortitionStrategyLinear
 *  @author ShotaroNowhere - <shawtarohgn@gmail.com>
 *  @dev Strategy Interface for drawing.
 */
contract sortitionStrategyLinear is sortitionStrategyBase{

    IProofOfHumanity public poh; // The Proof of Humanity registry

    constructor(
        ICore _core,
        RNG _rng,
        uint256 _minMiningTime,
        IProofOfHumanity _poh
    ) sortitionStrategyBase (_core, _rng, _minMiningTime){ 
        poh = _poh;
    }

    function isInStrategy(uint48 _drawnAccountIndex, uint32 nonce) internal view override returns (bool){
        bool isHuman = proofOfHumanity(stakePathIDToAddress(core.indexToStakeID(_drawnAccountIndex)));
        return isHuman && ( nonce < uint32(core.getStakeIDToAccounts(core.indexToStakeID(_drawnAccountIndex)).stakedTokens/10**18) );
    }

    /** @dev Checks if an address belongs to the Proof of Humanity registry.
     *  @param _address The address to check.
     *  @return registered True if registered.
     */
    function proofOfHumanity(address _address) internal view returns (bool) {
        return poh.isRegistered(_address);
    }
}