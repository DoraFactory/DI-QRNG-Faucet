// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

abstract contract ConsumerBase {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable qrngCoordinator;

  /**
   * @param _qrngCoordinator address of QRNGCoordinator contract
   */
  constructor(address _qrngCoordinator) {
    qrngCoordinator = _qrngCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the QRNG response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords fulfilled qrng random numbers
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by QRNGCoordinator.
  // rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != qrngCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, qrngCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}