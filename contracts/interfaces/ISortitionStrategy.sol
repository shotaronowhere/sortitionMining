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
interface ISortitionStrategy{
    
    function isResolving() external view returns (bool); // Current phase of this dispute kit.
    function isDrawing() external view returns (bool); // Current phase of this dispute kit.
    function draw(uint256 _sortitionRequestID) external returns (address);
    function createSortitionRequest(uint96 _subpool, uint64 _numDraws) external;
}