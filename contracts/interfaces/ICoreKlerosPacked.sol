/**
 *  @authors: [@shotaronowhere]
 *  @reviewers: []
 *  @auditors: []
 */

pragma solidity ^0.8.0;

/**
 *  @title ISortitionStrategy
 *  @author ShotaroNowhere - <shawtarohgn@gmail.com>
 *  @dev Strategy Interface for drawing.
 */
interface ICoreKlerosPacked{

    struct Account {
        uint184 packedStakedLockedTokens; // ~ [uint92 staked][uint92 locked]
        uint40 index; // indexing the account
        uint32 time; // The time when the juror staked
    }

    function indexToStakeID(uint40) external view returns (bytes32);
    function getStakeIDToAccounts(bytes32) external view returns (Account memory);
}
