# DI-QRNG-Faucet

## OnChain Faucet Calling Guide

Dora Qrng Oracle Contract Address: **`0x7156e92AF2d3DEeC0F04E3e321226389D16F6e93`**

Dora Qrng Oracle Contract: [QrngCoordinator.sol](./contracts/QrngCoordinator.sol)

Dora ConsumerBase Contract: [ConsumerBase.sol](./contracts/ConsumerBase.sol)

**Introduction**

Qrng Oracle is divided into two main components, one is the random number request and the other is the random number backfill interface.

For user calls, you need to request a random number by calling the `request` request in the Dora Qrng Oracle Contract.

When the process under the chain listens to the random number request, it will backfill the corresponding number of random numbers into the specified contract.

For the content of the random number backfill, the user needs to implement our standardized fulfill method based on the `ConsumerBase` contract, and the random number processing logic inside can be customized by the user.

**Demo**

```solidity
pragma solidity ^0.8.4;

// Import the official contract
import "./QrngCoordinator.sol";
import "./ConsumerBase.sol";

contract QrngUserDemo is ConsumerBase {
    // Set the maximum gas that can be used by oracle under the chain.
    uint32 callbackGasLimit = 80_000;
    // Set the number of qrng random numbers to request
    uint32 numWords = 1;
    address owner;

    QrngCoordinator COORDINATOR;
		
    // Official QrngCoordinator's contract address
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
```

## OffChain Faucet Calling Guide

**HTTPS**: `https://qrng.dorafactory.org/faucet-api/`

**WSS**: `wss://qrng.dorafactory.org/faucet-ws/`

#### `/random/GetRandomWords`

Get Qrng random numbers.

```shell
curl --request POST \
  --url $QRNG_API/random/GetRandomWords \
  --header 'Content-Type: application/json' \
  --data '{ "number": 1 }'
```

### `/random/GetCount`

Get the number of available random numbers.

```shell
curl --request POST \
  --url $QRNG_API/api/random/GetCount \
  --header 'Content-Type: application/json' \
  --data '{ }'
```

# Support

https://github.com/dorahacksglobal/quantum-randomness-generator