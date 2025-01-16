// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IRedeemBurnRateCalculator{
  function shouldSkipBurnRate(address user, uint256 amount) external returns (bool);
}