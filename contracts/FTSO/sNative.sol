
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./IExchangeableAsset.sol";

interface ISNative{
    function getPooledFlrByShares (uint shareAmount) external view returns (uint);
    function decimals() external view returns (uint8);
}

contract sNative is IExchangeableAsset {
  /// @notice Staked native token
  ISNative public sNativeToken;
  /// @notice Staked native token decimals
  uint8 public decimals;

  constructor(ISNative _sNativeToken) {
    // sanity check
    _sNativeToken.getPooledFlrByShares(1e18);

    sNativeToken = _sNativeToken;
    decimals = _sNativeToken.decimals();

    require(decimals == 18, 'invalid token');
  }

  function getExchangeRate() external view returns (uint){
    return sNativeToken.getPooledFlrByShares(10**(uint(decimals)));
  }
}