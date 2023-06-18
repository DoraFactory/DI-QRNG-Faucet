pragma solidity ^0.8.4;

import "./ConsumerBase.sol";

contract QrngCoordinator {
  address public admin;
  // We need to maintain a list of consuming addresses.
  // This bound ensures we are able to loop over them as needed.
  // Should a user require more consumers, they can use multiple subscriptions.
  error NotEnoughRandomNumber();

  address public oracle_node;
  // Note a nonce of 0 indicates an the consumer is not assigned to that subscription.
  mapping(address => uint64) /* consumer */ /* subId */ /* nonce */
    private s_consumers;
  event Log(string);
  event Log(uint256);
  uint32 public constant MAX_NUM_WORDS = 8;
  // 5k is plenty for an EXTCODESIZE call (2600) + warm CALL (100)
  // and some arithmetic operations.
  uint256 private constant GAS_FOR_CALL_EXACT_CHECK = 5_000;
  error GasLimitTooBig(uint32 have, uint32 want);
  error NumWordsTooBig(uint32 have, uint32 want);
  error Reentrant();
  struct RequestCommitment {
    uint32 callbackGasLimit;
    address sender;
  }
  // mapping(bytes32 => address) /* keyHash */ /* oracle */
  //   private s_provingKeys;

  mapping(uint256 => bytes32) /* requestID */ /* commitment */
    private s_requestCommitments;
  // event ProvingKeyRegistered(bytes32 keyHash, address indexed oracle);
  // event ProvingKeyDeregistered(bytes32 keyHash, address indexed oracle);
  event RandomWordsRequested(
    uint256 requestId,
    uint32 callbackGasLimit,
    uint32 numWords,
    address indexed sender
  );
  event RandomWordsFulfilled(uint256 indexed requestId, bool success);

  struct Config {
    uint32 maxGasLimit;
    bool reentrancyLock;
  }

  uint256 public current_available_random_nums;
  Config private s_config;
  event ConfigSet(
    uint32 maxGasLimit
  );
  

  constructor() {
    admin = msg.sender;

    current_available_random_nums = 0;
  }


  function setConfig(
    uint32 maxGasLimit,
    address oracleNode
  ) external onlyOwner {
    s_config = Config({
      maxGasLimit: maxGasLimit,
      reentrancyLock: false
    });
    oracle_node = oracleNode;
    emit ConfigSet(
      maxGasLimit
    );
  }

  function addCurrentRandNum(uint256 nums, bool isAdd) external onlyOwner {
    if (isAdd == true) {
      current_available_random_nums = current_available_random_nums + nums;
    } else {
      current_available_random_nums = nums;
    }
  }

  function getConfig()
    external
    view
    returns (
      uint32 maxGasLimit
    )
  {
    return (
      s_config.maxGasLimit
    );
  }

  function requestRandomWords(
    uint32 callbackGasLimit,
    uint32 numWords
  ) external nonReentrant returns (uint256) {

    // are, otherwise they could use someone else's subscription balance.
    // A nonce of 0 indicates consumer is not allocated to the sub.
    uint64 currentNonce = s_consumers[msg.sender];


    // No lower bound on the requested gas limit. A user could request 0
    // and they would simply be billed for the proof verification and wouldn't be
    // able to do anything with the random value.
    if (callbackGasLimit > s_config.maxGasLimit) {
      revert GasLimitTooBig(callbackGasLimit, s_config.maxGasLimit);
    }
    
    if (numWords > MAX_NUM_WORDS) {
      revert NumWordsTooBig(numWords, MAX_NUM_WORDS);
    }
    
    if (current_available_random_nums < numWords) {
      revert NotEnoughRandomNumber();
    }

    // Note we do not check whether the keyHash is valid to save gas.
    // The consequence for users is that they can send requests
    // for invalid keyHashes which will simply not be fulfilled.
    uint64 nonce = currentNonce + 1;
    uint256 requestId = computeRequestId(msg.sender, nonce);

    s_requestCommitments[requestId] = keccak256(
      abi.encode(requestId, block.number, callbackGasLimit, numWords, msg.sender)
    );
    emit RandomWordsRequested(
      requestId,
      callbackGasLimit,
      numWords,
      msg.sender
    );
    s_consumers[msg.sender] = nonce;
    current_available_random_nums -= numWords;

    return requestId;
  }

  /**
   * @notice Get request commitment
   * @param requestId id of request
   * @dev used to determine if a request is fulfilled or not
   */
  function getCommitment(uint256 requestId) external view returns (bytes32) {
    return s_requestCommitments[requestId];
  }

  function computeRequestId(
    address sender,
    uint64 nonce
  ) private pure returns (uint256) {
    return (uint256(keccak256(abi.encode(sender, nonce))));
  }

  /**
   * @dev calls target address with exactly gasAmount gas and data as calldata
   * or reverts if at least gasAmount gas is not available.
   */
  function callWithExactGas(
    uint256 gasAmount,
    address target,
    bytes memory data
  ) private returns (bool success) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let g := gas()
      // Compute g -= GAS_FOR_CALL_EXACT_CHECK and check for underflow
      // The gas actually passed to the callee is min(gasAmount, 63//64*gas available).
      // We want to ensure that we revert if gasAmount >  63//64*gas available
      // as we do not want to provide them with less, however that check itself costs
      // gas.  GAS_FOR_CALL_EXACT_CHECK ensures we have at least enough gas to be able
      // to revert if gasAmount >  63//64*gas available.

      if lt(g, GAS_FOR_CALL_EXACT_CHECK) {
        revert(0, 0)
      }

      g := sub(g, GAS_FOR_CALL_EXACT_CHECK)

      // if g - g//64 <= gasAmount, revert
      // (we subtract g//64 because of EIP-150)
      if iszero(gt(sub(g, div(g, 64)), gasAmount)) {
        revert(0, 0)
      }

      // solidity calls check that a contract actually exists at the destination, so we do the same
      if iszero(extcodesize(target)) {
        revert(0, 0)
      }

      // call and return whether we succeeded. ignore return data
      // call(gas,addr,value,argsOffset,argsLength,retOffset,retLength)
      success := call(gasAmount, target, 0, add(data, 0x20), mload(data), 0, 0)
    }

    return success;
  }

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords, RequestCommitment memory rc) external nonReentrant returns (bool) {
    require(oracle_node == msg.sender, "Caller is not oracle node.");
    delete s_requestCommitments[requestId];
    ConsumerBase v;

    bytes memory resp = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, requestId, randomWords);

    // Call with explicitly the amount of callback gas requested
    // Important to not let them exhaust the gas budget and avoid oracle payment.
    // Do not allow any non-view/non-pure coordinator functions to be called
    // during the consumers callback code via reentrancyLock.
    // Note that callWithExactGas will revert if we do not have sufficient gas
    // to give the callee their requested amount.
    s_config.reentrancyLock = true;
    bool success = callWithExactGas(rc.callbackGasLimit, rc.sender, resp);
    s_config.reentrancyLock = false;

    emit RandomWordsFulfilled(requestId, success);
    return success;
  }

  modifier nonReentrant() {
    if (s_config.reentrancyLock) {
      revert Reentrant();
    }
    _;
  }

  modifier onlyOwner {
    require(msg.sender == admin, "Only the contract owner can call this function.");
    _;
  }

  /**
   * @notice The type and version of this contract
   * @return Type and version string
   */
  function typeAndVersion() external pure virtual returns (string memory) {
    return "QrngCoordinator 0.0.1";
  }
}
