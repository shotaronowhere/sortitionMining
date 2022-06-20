/**
 *  @authors: [@shotaronowhere]
 *  @reviewers: []
 *  @auditors: []
 */

pragma solidity ^0.8.0;

import "../interfaces/ICore.sol";
import "../interfaces/ISortitionStrategy.sol";
import "../rng/RNG.sol";

/**
 *  @title sortitionStrategyBase
 *  @author ShotaroNowhere - <shawtarohgn@gmail.com>
 *  @dev Strategy Interface for drawing.
 */
abstract contract sortitionStrategyBase is ISortitionStrategy{
    
    enum Phase {
        resolving, // No disputed need drawing
        generating, // Waiting for a random number. Pass as soon as it is ready.
        mining, // Waiting sufficient time for mining.
        drawing // core can call draw
    }

    struct SortitionRequest {
        uint96 subpool; // The ID of the subpool the request is in.
        uint64 numDraws;
        uint64 coreDrawnIndex;
        mapping(uint256 => uint256) packedDrawnAccountIndexNonce; // 3x [uint48][uint32] 
    }

    SortitionRequest[] sortitionRequests;
    Phase public phase; // Current phase of this dispute kit.
    uint256 public resolvedSortitionRequests; // The number of disputes that have not finished drawing jurors.
    ICore public core;
    RNG public rng; // The random number generator
    uint256 public RNBlock; // The block number when the random number was requested.
    uint256 public RN;
    uint256 public immutable minMiningTime; // must be > 20 min. several hours is safe.
    uint256 public miningPhaseTimestamp; // must be > 20 min. several hours is safe.

    constructor(ICore _core, RNG _rng, uint256 _minMiningTime){
        core = _core;
        rng = _rng;
        minMiningTime = _minMiningTime;
    }

    /** @dev Passes the phase.
     */
    function passPhase() external {
        if (phase == Phase.resolving) {
            require(resolvedSortitionRequests == sortitionRequests.length, "All the requests have draws");
            RNBlock = block.number;
            rng.requestRN(block.number);
            phase = Phase.generating;
        } else if (phase == Phase.generating) {
            RN = rng.getRN(RNBlock);
            require(RN != 0, "Random number is not ready yet");
            miningPhaseTimestamp = block.timestamp;
            phase = Phase.mining;
            } 
        else if (phase == Phase.mining){
            require(block.timestamp > minMiningTime + miningPhaseTimestamp);
            phase = Phase.drawing;
        } else if (phase == Phase.drawing) {
            require(resolvedSortitionRequests == sortitionRequests.length, "Not ready for Resolving phase");
            phase = Phase.resolving;
        }
    }

    function isResolving() external view override returns (bool){
        return phase == Phase.resolving;
    } 

    function isDrawing() external view override returns (bool){
        return phase == Phase.drawing;
    } 

    function createSortitionRequest(uint96 _subpool, uint64 _numDraws) external override{
        require(msg.sender == address(core), "Only core.");
        uint256 sortitionRequestID = sortitionRequests.length;
        sortitionRequests.push();
        sortitionRequests[sortitionRequestID].subpool = _subpool;
        sortitionRequests[sortitionRequestID].numDraws = _numDraws;
    }

    // note the first argument is highly compressible.
    // an alternate can be formulated in nitro is not yet released.
    function claim(uint64 startSortitionRequestIndex, uint32 startDrawIndex, uint80[] memory _proposedPackedAccountIndexNonce) external{
        require(phase == Phase.mining, "Only mining phase.");
        require(startSortitionRequestIndex >= resolvedSortitionRequests, "Invalid start index.");

        uint64 cursorRequest = startSortitionRequestIndex;
        uint32 cursorDraw = startDrawIndex;
        uint256 cursorProposal = 0;
        uint256 proposalLength = _proposedPackedAccountIndexNonce.length;
        uint256 currentPackedAccountIndexNonce;
        SortitionRequest storage sortitionRequest = sortitionRequests[cursorRequest];
        uint256 numDraws = sortitionRequest.numDraws;
        while (cursorProposal < proposalLength){
            if (cursorDraw % 3 == 0)
                currentPackedAccountIndexNonce = sortitionRequest.packedDrawnAccountIndexNonce[cursorDraw / 3];

            (uint48 accountIndex, uint32 nonce) = unpackDrawnAccountIndexNonce(_proposedPackedAccountIndexNonce[cursorProposal]);
            if (isInStrategy(accountIndex, nonce)){
                    uint80 currentAccountIndexNonce = uint80(currentPackedAccountIndexNonce >> (80 * (cursorDraw % 3)));
                    if (currentAccountIndexNonce == 0)
                        currentPackedAccountIndexNonce += uint256(_proposedPackedAccountIndexNonce[cursorProposal]) << ( 80 * (cursorDraw % 3) );
                    (uint48 currentAccountIndex, uint32 currentNonce) = unpackDrawnAccountIndexNonce(_proposedPackedAccountIndexNonce[cursorProposal]);
                    uint256 currentMetric = objectiveFunction(cursorRequest, cursorDraw, currentAccountIndex, currentNonce);
                    uint256 proposedMetric = objectiveFunction(cursorRequest, cursorDraw, currentAccountIndex, currentNonce);
                    if (proposedMetric > currentMetric){
                        if (cursorDraw % 3 == 0)
                            currentPackedAccountIndexNonce = currentPackedAccountIndexNonce & 0x0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000;
                        if (cursorDraw % 3 == 1)
                            currentPackedAccountIndexNonce = currentPackedAccountIndexNonce & 0x0000FFFFFFFFFFFFFFFFFFFF00000000000000000000FFFFFFFFFFFFFFFFFFFF;
                        if (cursorDraw % 3 == 2)
                            currentPackedAccountIndexNonce = currentPackedAccountIndexNonce & 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                        currentPackedAccountIndexNonce += uint256(_proposedPackedAccountIndexNonce[cursorProposal]) << ( 80 * (cursorDraw % 3) );
                    }
                }
                cursorDraw++;
                cursorProposal++;                
                if (cursorDraw % 3 == 0)
                    sortitionRequest.packedDrawnAccountIndexNonce[cursorDraw/3] = currentPackedAccountIndexNonce;
                if (cursorDraw == numDraws){
                    cursorProposal++;
                    sortitionRequest.packedDrawnAccountIndexNonce[cursorDraw/3] = currentPackedAccountIndexNonce;
                }
        }
    }

    function objectiveFunction(uint64 sortitionRequestID, uint32 voteIndex, uint48 _drawnAccountIndex, uint32 nonce) internal view returns (uint256){

        uint256 winningNumber = uint256(keccak256(abi.encodePacked(RN, sortitionRequestID, voteIndex)));
        uint256 lotteryTicket = uint256(keccak256(abi.encodePacked(_drawnAccountIndex, nonce)));

        if (lotteryTicket > winningNumber) 
            return lotteryTicket - winningNumber;
        else 
            return winningNumber - lotteryTicket;
    }

    function unpackDrawnAccountIndexNonce(uint80 _packedDrawnAccountIndexNonce) internal pure returns (uint48 drawnAccountIndex, uint32 nonce){
        nonce = uint32(_packedDrawnAccountIndexNonce);
        drawnAccountIndex = uint48(_packedDrawnAccountIndexNonce >> 32);
    }

    function isInStrategy(uint48 _drawnAccountIndex, uint32 nonce) internal virtual view returns (bool);

    function draw(uint256 _sortitionRequestID) external override returns (address drawnAccount){
        if (phase != Phase.drawing) return address(0);
        uint256 coreDrawnIndex = sortitionRequests[_sortitionRequestID].coreDrawnIndex;
        uint256 packedDrawnAccountIndexNonce = sortitionRequests[_sortitionRequestID].packedDrawnAccountIndexNonce[coreDrawnIndex];
        uint80 drawnAccountIndexNonce = uint80( packedDrawnAccountIndexNonce >> (80 * coreDrawnIndex % 3) );
        (uint48 drawnAccountIndex, ) = unpackDrawnAccountIndexNonce(drawnAccountIndexNonce);
        drawnAccount = stakePathIDToAddress(core.indexToStakeID(drawnAccountIndex));
    }


    /** @dev Retrieves a juror's address from the stake path ID.
     *  @param _stakePathID The stake path ID to unpack.
     *  @return account The account.
     */
    function stakePathIDToAddress(bytes32 _stakePathID) internal pure returns (address account) {
        assembly {
            // solium-disable-line security/no-inline-assembly
            let ptr := mload(0x40)
            for {
                let i := 0x00
            } lt(i, 0x14) {
                i := add(i, 0x01)
            } {
                mstore8(add(add(ptr, 0x0c), i), byte(i, _stakePathID))
            }
            account := mload(ptr)
        }
    }
}