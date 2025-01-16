
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./IExchangeableAsset.sol";

interface ILiquidStakingToken{
    /**
     * @notice Returns the amount of LiquidStakingToken assets that corresponds to 1 WrappedLiquidStakedToken share.
     * @return assets The amount of LiquidStakingToken assets.
     */
    function LSTPerToken() external view returns (uint256);

    function decimals() external view returns (uint8);
}

contract sETH is IExchangeableAsset {
  /// @notice Liquid Staking Token
  ILiquidStakingToken public sEth;
  /// @notice Liquid Staking Token decimals
  uint8 public decimals;

  constructor(ILiquidStakingToken _sETHToken) {
    // sanity check
    _sETHToken.LSTPerToken();

    sEth = _sETHToken;
    decimals = _sETHToken.decimals();

    require(decimals == 18, 'invalid token');
  }

  function getExchangeRate() external view returns (uint){
    return sEth.LSTPerToken();
  }
}