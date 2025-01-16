// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./esProtocolStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

/*
 * esProtocol is Protocol's escrowed token obtainable by converting Protocol to it
 * It's non-transferable, except from/to whitelisted addresses
 * It can be converted back to Protocol through a vesting process 
 */
contract esProtocol is ReentrancyGuardUpgradeable, Ownable2StepUpgradeable, esProtocolStorageV1, ERC20VotesUpgradeable{
  using Address for address;
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;
  
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
      _disableInitializers();
  }

  function initialize(IERC20 protocolToken_, string memory name_, string memory symbol_) public initializer {  
    protocolToken = protocolToken_;
    _transferWhitelist.add(address(this));

    minRedeemRatio = 65; // 1:0.65
    maxRedeemRatio = 100; // 1:1
    minRedeemDuration = 1; // Instant
    maxRedeemDuration = 90 days; // 7776000s

    __ERC20_init(name_, symbol_);
    __ERC20Permit_init(name_);
    __ReentrancyGuard_init();
    __Ownable_init();
  }

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Check if a redeem entry exists
   */
  modifier validateRedeem(address userAddress, uint256 redeemIndex) {
    require(redeemIndex < userRedeems[userAddress].length, "validateRedeem: redeem entry does not exist");
    _;
  }

  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /*
   * @dev Returns user's esProtocol balances
   */
  function getESProtocolBalance(address userAddress) external view returns (uint256 redeemingAmount) {
    redeemingAmount = esProtocolBalances[userAddress];    
  }

  /**
   * @dev returns quantity of "userAddress" pending redeems
   */
  function getUserRedeemsLength(address userAddress) external view returns (uint256) {
    return userRedeems[userAddress].length;
  }

  /**
   * @dev returns "userAddress" info for a pending redeem identified by "redeemIndex"
   */
  function getUserRedeem(address userAddress, uint256 redeemIndex) external view validateRedeem(userAddress, redeemIndex) returns (uint256 protocolAmount, uint256 esProtocolAmount, uint256 endTime) {
    RedeemInfo storage _redeem = userRedeems[userAddress][redeemIndex];
    return (_redeem.protocolAmount, _redeem.esProtocolAmount, _redeem.endTime);
  }

  /**
   * @dev returns length of transferWhitelist array
   */
  function transferWhitelistLength() external view returns (uint256) {
    return _transferWhitelist.length();
  }

  /**
   * @dev returns transferWhitelist array item's address for "index"
   */
  function transferWhitelist(uint256 index) external view returns (address) {
    return _transferWhitelist.at(index);
  }

  /**
   * @dev returns if "account" is allowed to send/receive esPrtocol
   */
  function isTransferWhitelisted(address account) external view returns (bool) {
    return _transferWhitelist.contains(account);
  }

  /*******************************************************/
  /****************** OWNABLE FUNCTIONS ******************/
  /*******************************************************/

  /**
   * @dev Updates all redeem ratios and durations
   *
   * Must only be called by owner
   */
  function updateRedeemSettings(uint256 minRedeemRatio_, uint256 maxRedeemRatio_, uint256 minRedeemDuration_, uint256 maxRedeemDuration_) external onlyOwner {
    require(minRedeemRatio_ <= maxRedeemRatio_, "updateRedeemSettings: wrong ratio values");
    require(minRedeemDuration_ < maxRedeemDuration_, "updateRedeemSettings: wrong duration values");
    require(minRedeemDuration_ > 0, "updateRedeemSettings: invalid minRedeemDuration");
    // should never exceed 100%
    require(maxRedeemRatio_ <= MAX_FIXED_RATIO, "updateRedeemSettings: wrong ratio values");

    minRedeemRatio = minRedeemRatio_;
    maxRedeemRatio = maxRedeemRatio_;
    minRedeemDuration = minRedeemDuration_;
    maxRedeemDuration = maxRedeemDuration_;

    emit UpdateRedeemSettings(minRedeemRatio_, maxRedeemRatio_, minRedeemDuration_, maxRedeemDuration_);
  }

  /**
   * @dev Adds or removes addresses from the transferWhitelist
   */
  function updateTransferWhitelist(address account, bool add) external onlyOwner {
    require(account != address(this), "updateTransferWhitelist: Cannot remove esProtocol from whitelist");

    if(add) _transferWhitelist.add(account);
    else _transferWhitelist.remove(account);

    emit SetTransferWhitelist(account, add);
  }

  /**
   * @dev Updates the burn rate calculator
   */
  function updateBurnRateCalculator(IRedeemBurnRateCalculator calculator) external onlyOwner {
    calculator.shouldSkipBurnRate(msg.sender, 0); // sanity check
    emit RedeemBurnRateCalculatorChanged(address(burnRateCalculator), address(calculator));
    burnRateCalculator = calculator;
  }

  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Convert caller's "amount" of Protocol to esProtocol
   */
  function convert(uint256 amount) external nonReentrant {
    _convert(amount, msg.sender);
    // self delegate
    address currentDelegate = delegates(msg.sender);
    
    if(currentDelegate == address(0)){
      _delegate(msg.sender, msg.sender);
    }
  }

  /**
   * @dev Convert caller's "amount" of Protocol to esProtocol to "to" address
   */
  function convertTo(uint256 amount, address to) external nonReentrant {
    require(address(msg.sender).isContract(), "convertTo: not allowed");
    _convert(amount, to);
  }

  /**
   * @dev Initiates redeem process (esProtocol to Protocol)
   *   
   */
  function redeem(uint256 esProtocolAmount, uint256 duration) external nonReentrant {
    require(esProtocolAmount > 0, "redeem: esProtocolAmount cannot be null");
    require(duration == minRedeemDuration || duration == maxRedeemDuration, "redeem: invalid duration");

    // get corresponding Protocol amount
    // _getProtocolByVestingDuration is based on the user's balance before the redeem amount is deducted, and not after
    uint256 protocolAmount = _getProtocolByVestingDuration(esProtocolAmount, duration);
    emit Redeem(msg.sender, esProtocolAmount, protocolAmount, duration);

    _transfer(msg.sender, address(this), esProtocolAmount);
    uint256 balance = esProtocolBalances[msg.sender];

    // add to SBT total
    balance = balance + esProtocolAmount;
    esProtocolBalances[msg.sender] = balance;
    
    // add redeeming entry
    userRedeems[msg.sender].push(RedeemInfo(protocolAmount, esProtocolAmount, _currentBlockTimestamp() + duration));
  }

  /**
   * @dev Finalizes redeem process when vesting duration has been reached
   *
   * Can only be called by the redeem entry owner
   */
  function finalizeRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
    uint256 redeemingAmount = esProtocolBalances[msg.sender];
    RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];
    require(_currentBlockTimestamp() >= _redeem.endTime, "finalizeRedeem: vesting duration has not ended yet");

    // remove from SBT total
    redeemingAmount = redeemingAmount - _redeem.esProtocolAmount;
    esProtocolBalances[msg.sender] = redeemingAmount;
    _finalizeRedeem(msg.sender, _redeem.esProtocolAmount, _redeem.protocolAmount);

    // remove redeem entry
    _deleteRedeemEntry(redeemIndex);
  }

  /**
   * @dev Cancels an ongoing redeem entry
   *
   * Can only be called by its owner
   */
  function cancelRedeem(uint256 redeemIndex, uint256 redeemsLength) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
    require(userRedeems[msg.sender].length == redeemsLength, "cancelRedeem: stale data");
    
    uint256 balance = esProtocolBalances[msg.sender];
    RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

    // make redeeming esProtocol available again
    balance = balance - _redeem.esProtocolAmount;
    esProtocolBalances[msg.sender] = balance;
    _transfer(address(this), msg.sender, _redeem.esProtocolAmount);

    emit CancelRedeem(msg.sender, _redeem.esProtocolAmount);

    // remove redeem entry
    _deleteRedeemEntry(redeemIndex);
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev returns redeemable Protocol for "amount" of esProtocol vested for "duration" seconds
   */
  function _getProtocolByVestingDuration(uint256 amount, uint256 duration) internal returns (uint256) {
    require(address(burnRateCalculator) != address(0), "getProtocolByVestingDuration: invalid burnRateCalculator");
   
   // burnRateCalculator is based on the user's balance before the redeem amount is deducted, and not after
    uint256 ratio = duration == maxRedeemDuration ? maxRedeemRatio 
      : (burnRateCalculator.shouldSkipBurnRate(msg.sender, amount) ? maxRedeemRatio : minRedeemRatio);
    
    return amount * ratio / 100;
  }

  /**
   * @dev Convert caller's "amount" of PROTOCOL into esPROTOCOL to "to"
   */
  function _convert(uint256 amount, address to) internal {
    require(amount != 0, "convert: amount cannot be null");

    // mint new esPROTOCOL
    _mint(to, amount);

    emit Convert(msg.sender, to, amount);
    protocolToken.safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @dev Finalizes the redeeming process for "userAddress" by transferring him "protocolAmount" and removing "esProtocolAmount" from supply
   *
   * Any vesting check should be ran before calling this
   * PROTOCOL excess is automatically burnt
   */
  function _finalizeRedeem(address userAddress, uint256 esProtocolAmount, uint256 protocolAmount) internal {
    uint256 protocolExcess = esProtocolAmount - protocolAmount;

    // sends due PROTOCOL tokens
    protocolToken.safeTransfer(userAddress, protocolAmount);

    // burns PROTOCOL excess if any    
    if (protocolExcess > 0) {
      protocolToken.safeTransfer(address(0x000000000000000000000000000000000000dEaD), protocolExcess);
    }
    
    _burn(address(this), esProtocolAmount);

    emit FinalizeRedeem(userAddress, esProtocolAmount, protocolAmount);
  }

  function _deleteRedeemEntry(uint256 index) internal {
    userRedeems[msg.sender][index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
    userRedeems[msg.sender].pop();
  }

  /**
   * @dev Hook override to forbid transfers except from whitelisted addresses and minting
   */
  function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal view override {
    require(from == address(0) || _transferWhitelist.contains(from) || _transferWhitelist.contains(to), "transfer: not allowed");
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }
}

contract esProtocolV2 is esProtocol{
    function initializeV2(string memory name_, string memory symbol_) reinitializer(2) public {
       __ERC20_init(name_, symbol_);
    }
}
