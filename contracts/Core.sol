/**
 *  @authors: [@shotaronowhere]
 *  @reviewers: []
 *  @auditors: []
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISortitionStrategy.sol";
import "./interfaces/ICore.sol";


/**
 *  @title Core
 *  @author ShotaroNowhere - <shawtarohgn@gmail.com>
 *  @dev Simple core stake management contract
 */
contract Core is ICore{

    IERC20 public immutable token;
    address public governor;

    constructor(IERC20 _token){
        token = _token;
        governor = msg.sender;
        freeAccountIndex = 1;
    }


    struct Pool {
        uint96 parent; // The parent sortition pool.
        uint256 minStake; // Minimum tokens needed to stake in the pool.
    }

    modifier onlyByGovernor() {
        require(governor == msg.sender, "Access not allowed: Governor only.");
        _;
    }

    struct SortitionRequest {
        uint96 subpool; // The ID of the subpool the request is in.
        address requester; // The sortition requester contract.
        uint64 numDraws;
        uint32 strategyIndex; // The index of approved strategy.
        address[] drawnAccounts; // packed selected staker indicies
    }

    Pool[] public pools; // The subpools.
    ISortitionStrategy[] public strategies;
    SortitionRequest[] public sortitionRequests;
    uint48 public freeAccountIndex;
    mapping(bytes32 => Account) public stakeIDToAccounts;
    mapping(uint48 => bytes32) public override indexToStakeID;

    function getStakeIDToAccounts(bytes32 stakeID) external view override returns (Account memory){
        return stakeIDToAccounts[stakeID];
    }

    function setStake(uint256 _stake, uint96 _subpoolID) external {
        require(_setStake(msg.sender, _stake, _subpoolID), "Staking Failed");
    }

    function _setStake(address _account, uint256 _stake, uint96 _subpoolID) internal returns (bool){
        bytes32 stakeID = accountAndSubpoolIDToStakeID(_account, _subpoolID);
        Account memory account = stakeIDToAccounts[stakeID];

        uint256 currentStake = account.stakedTokens;
        uint256 transferredAmount;

        if (_stake >= currentStake) {
            unchecked{
                transferredAmount = _stake - currentStake;
            }
            if (transferredAmount > 0) {
                if (!token.transferFrom(_account, address(this), transferredAmount)) return false;
            }
        } else if (_stake == 0) {
                if (!token.transfer(_account, _stake)) return false;
        } else {
            unchecked{
                transferredAmount = currentStake - _stake;
            }
            if (transferredAmount > 0) {
                if (!token.transfer(_account, transferredAmount)) return false;
            }
        }

        if (account.index == 0){
            uint48 _freeAccountIndex = freeAccountIndex;
            account.index = _freeAccountIndex;
            freeAccountIndex = _freeAccountIndex + 1;
        }

        account.stakedTokens = _stake; // new stake
        account.time = uint32(block.timestamp);
        stakeIDToAccounts[stakeID] = account;

        return true;
    }

    /** @dev Add a new supported sortition strategy module.
     *  @param _sortitionStrategy The address of the sortition strategy contract.
     */
    function addNewSortitionStrategy(ISortitionStrategy _sortitionStrategy) external onlyByGovernor {
        strategies.push(_sortitionStrategy);
    }

    /** @dev Creates a subpool under a specified parent pool.
     *  @param _parent The `parent` property value of the subpool.
     *  @param _minStake The min stake.
     */
    function createSubpool(
        uint96 _parent,
        uint96 _minStake
    ) external onlyByGovernor {
        require(
            pools[_parent].minStake <= _minStake,
            "A subpool cannot be a child of a subpool with a higher minimum stake."
        );

        uint96 subpoolID = uint96(pools.length);

        pools.push(
            Pool({
                parent: _parent,
                minStake: _minStake
            })
        );
    }

/** @dev Creates a Sortition Request.
     *  @param _subpool The subpool to draw from
     *  @param _numDraws Number of addresses to draw
     *  @param _strategyIndex The index of the strategy
     *  @return sortitionRequestID The ID of the created dispute.
     */
    function createSortitionRequest(uint96 _subpool, uint32 _strategyIndex, uint64 _numDraws) external payable returns (uint64 sortitionRequestID){
        uint256 sortitionRequestID = sortitionRequests.length;
        require(_numDraws > 0);
        sortitionRequests.push(SortitionRequest({
                subpool: _subpool,
                requester: msg.sender,
                numDraws: _numDraws,
                strategyIndex: _strategyIndex,
                drawnAccounts: new address[](0)
            })
        );
        //strategies[_strategyIndex].createSortitionRequest(sortitionRequestID, _numDraws);
    }

    /** @dev Draw stakers according to a strategy
     */
    function draw(uint64 _sortitionRequestID, uint256 iterations) external {
        ISortitionStrategy strategy = strategies[sortitionRequests[_sortitionRequestID].strategyIndex];
        require(strategy.isDrawing(), "Wrong phase.");

        uint256 startIndex = sortitionRequests[_sortitionRequestID].drawnAccounts.length;
        uint256 endIndex = startIndex + iterations;
        if (endIndex > sortitionRequests[_sortitionRequestID].numDraws)
            endIndex = sortitionRequests[_sortitionRequestID].numDraws;

        for (uint i = startIndex; i < endIndex; i++) {
            address drawnAccount = strategy.draw(_sortitionRequestID);
            require(drawnAccount != address(0), "Dispute Kit Draw Failed.");
            sortitionRequests[_sortitionRequestID].drawnAccounts.push(drawnAccount);
        }
    }


    /** @dev Packs an account and a subpool ID into a stake ID.
     *  @param _account The address of the juror to pack.
     *  @param _subpoolID The subpool ID to pack.
     *  @return stakePathID The stake ID.
     */
    function accountAndSubpoolIDToStakeID(address _account, uint96 _subpoolID)
        internal
        pure
        returns (bytes32 stakePathID)
    {
        assembly {
            // solium-disable-line security/no-inline-assembly
            let ptr := mload(0x40)
            for {let i := 0x00} lt(i, 0x14) {i := add(i, 0x01)} {
                mstore8(add(ptr, i), byte(add(0x0c, i), _account))
            }
            for {let i := 0x14} lt(i, 0x20) {i := add(i, 0x01)} {
                mstore8(add(ptr, i), byte(i, _subpoolID))
            }
            stakePathID := mload(ptr)
        }
    }
}