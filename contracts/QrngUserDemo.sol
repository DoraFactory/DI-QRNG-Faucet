pragma solidity ^0.8.4;

import "./QrngCoordinator.sol";
import "./ConsumerBase.sol";

contract QrngUserDemo is ConsumerBase {
    uint32 callbackGasLimit = 80_000;
    uint32 numWords = 1;
    address owner;

    QrngCoordinator COORDINATOR;
		
    address doraCoordinatorAddr = 0x7156e92AF2d3DEeC0F04E3e321226389D16F6e93;
    

    uint256 public requestId;
    uint256[] public s_randomWords;
    
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
    }
}
