pragma solidity ^0.8.4;

import "./QrngCoordinator.sol";
import "./ConsumerBase.sol";

contract QrngUserDemo is ConsumerBase {
    uint32 callbackGasLimit = 21_000_000;
    uint32 numWords = 1;
    address owner;

    QrngCoordinator COORDINATOR;

    address doraCoordinatorAddr = 0x4FdF351FddDBCB26Ba69Bd32404d096e3C44a4CC;
    

    uint256 public requestId;
    uint256[] public s_randomWords;
    
    struct data {
        uint256 request_id;
        uint256[] randomes;
    }

    mapping (uint256 => data) public result;
    
    uint32 count = 0;

    constructor() ConsumerBase(doraCoordinatorAddr)  {
        COORDINATOR = QrngCoordinator(doraCoordinatorAddr);
        owner = msg.sender;
    }


    function requestRandomWords() external {
        require(msg.sender == owner);
        requestId = COORDINATOR.requestRandomWords(
            callbackGasLimit,
            numWords
        );
    }


    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        s_randomWords = randomWords;
        result[count] = data(requestId, randomWords);
        count += 1;
    }
}
