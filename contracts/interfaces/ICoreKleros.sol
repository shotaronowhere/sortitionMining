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
interface ICoreKleros{

    struct Account {
        uint96 stakedTokens; // The account's total amount of tokens staked in subpools.
        uint88 lockedTokens; // The account's total amount of tokens locked.
        uint40 index; // indexing the account
        uint32 time; // The time when the juror staked
    }

    function indexToStakeID(uint48) external view returns (bytes32);
    function getStakeIDToAccounts(bytes32) external view returns (Account memory);
}