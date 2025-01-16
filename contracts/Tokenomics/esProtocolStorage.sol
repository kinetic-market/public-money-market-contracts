// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IRedeemBurnRateCalculator.sol";

contract esProtocolStorageV1 {
  struct RedeemInfo {
    uint256 protocolAmount; // PROTOCOL amount to receive when vesting has ended
    uint256 esProtocolAmount; // esProtocol amount to redeem
    uint256 endTime;    
  }

  IERC20 public protocolToken; // Protocol token to convert to/from 
  IRedeemBurnRateCalculator public burnRateCalculator; // burnRateCalculator address

  EnumerableSet.AddressSet internal _transferWhitelist; // addresses allowed to send/receive esProtocol
  
  uint256 public constant MAX_FIXED_RATIO = 100; // 100%

  // Redeeming min/max settings
  uint256 public minRedeemRatio;
  uint256 public maxRedeemRatio;
  uint256 public minRedeemDuration;
  uint256 public maxRedeemDuration;
  
  mapping(address => uint256) public esProtocolBalances; // User's esProtocol balances
  mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances

  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/
  
  event Convert(address indexed from, address to, uint256 amount);  
  event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration);    
  event SetTransferWhitelist(address account, bool add);
  event Redeem(address indexed userAddress, uint256 esProtocolAmount, uint256 protocolAmount, uint256 duration);
  event FinalizeRedeem(address indexed userAddress, uint256 esProtocolAmount, uint256 protocolAmount);
  event CancelRedeem(address indexed userAddress, uint256 esProtocolAmount);    
  event RedeemBurnRateCalculatorChanged(address indexed oldCalculator, address indexed newCalculator);
}
