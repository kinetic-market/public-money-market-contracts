pragma solidity 0.5.17;

import "./ComptrollerV2.sol";
import "./Tokenomics/IAllowlist.sol";

library ComptrollerLib {
  /// @notice The initial rewards index for a market
  uint224 private constant initialIndexConstant = 1e36;
  /// @notice Money market Unitroller (proxy)
  ComptrollerV2 private constant unitroller = ComptrollerV2(0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8);
  /// @notice Allowlist permission contract
  IAllowList private constant allowList = IAllowList(0x629BA82e92088c03A0998Ff8bFfd95d3f9444208);
  
  /**
  * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
  * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
  **/
  event Failure(uint error, uint info, uint detail);

  /**
  * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
  **/
  function fail(ComptrollerErrorReporter.Error err, ComptrollerErrorReporter.FailureInfo info) private returns (ComptrollerErrorReporter.Error) {
    emit Failure(uint(err), uint(info), 0);

    return err;
  }

  /**
  * @dev extracted from ExponentialNoError.sol
  **/
  function safe32(uint n, string memory errorMessage) pure private returns (uint32) {
    require(n < 2**32, errorMessage);
    return uint32(n);
  }

  /**
  * @dev extracted from Comptroller.sol
  **/
  function getBlockTimestamp() private view returns (uint) {
    return block.timestamp;
  }

  /**
  * @notice Valide execute permission
  **/
  function allowed(address sender) public {
    require(sender == unitroller.admin() || allowList.allowed(sender) , 'NA');
  }

  /**
  * @notice Update rFLR supply/borrow reward state to market state for users
  * @param markets All markets
  * @param users The users to update state
  * @param rewardSupplyState Unitroller rewardSupplyState storage
  * @param rewardSupplierIndex Unitroller rewardSupplierIndex storage
  * @param rewardBorrowState Unitroller rewardBorrowState storage
  * @param rewardBorrowerIndex Unitroller rewardBorrowerIndex storage
  * @param rewardAccrued Unitroller rewardAccrued storage
  **/
  function updateRFLRRewardState(CToken[] calldata markets, address[] calldata users,
      mapping(uint8 => mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardSupplyState,
      mapping(uint8 => mapping(address => mapping(address => uint))) storage rewardSupplierIndex,
      mapping(uint8 => mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardBorrowState,
      mapping(uint8 => mapping(address => mapping(address => uint))) storage rewardBorrowerIndex,
      mapping(uint8 => mapping(address => uint)) storage rewardAccrued)
    external {
      uint marketsLength = markets.length;
      uint usersLength = users.length;

      uint marketIndex;
      uint userIndex;
      address market;

      for(; marketIndex < marketsLength; marketIndex++){
        market = address(markets[marketIndex]);
        unitroller._updateRewardSupplyIndex(3, market);
        unitroller._updateRewardBorrowIndex(3, market);
      }

      for ( ; userIndex < usersLength;  userIndex++) {      
        address user = users[userIndex];

        if(rewardAccrued[3][user] != 0)
          rewardAccrued[3][user] = 0;

        for(marketIndex = 0; marketIndex < marketsLength; marketIndex++){
          market = address(markets[marketIndex]);

          if(rewardSupplierIndex[3][market][user] != 0){
            rewardSupplierIndex[3][market][user] = rewardSupplyState[3][market].index;
          }

          if(rewardBorrowerIndex[3][market][user] != 0){
            rewardBorrowerIndex[3][market][user] = rewardBorrowState[3][market].index;
          }
        }
      }
  }


  /**
  * @notice Configure new reward type to the protocol
  * @param rewardAddress Address of the new reward token
  * @param rewardTokens Unitroller rewardTokens storage
  * @param protocolTokenAddress Protocol Token address
  * @param allMarkets All cToken markets listed on Unitroller
  * @param rewardSupplyState Unitroller rewardSupplyState storage
  * @param rewardBorrowState Unitroller rewardBorrowState storage
  **/
  function setRewardType(address rewardAddress,
      address[] storage rewardTokens,
      address protocolTokenAddress,
      CToken[] calldata allMarkets,
      mapping(uint8 => mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardSupplyState,
      mapping(uint8 =>mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardBorrowState)
    external {
      
      if(rewardTokens.length == 0){
        require(protocolTokenAddress != address(0) && rewardAddress == protocolTokenAddress, "PT");
      }else if(rewardTokens.length == 1){
        require(rewardAddress == address(0), "NO");
      }

      bool alreadySet = false;
      for(uint i = 0; i < rewardTokens.length; i++){
        if(rewardTokens[i] == rewardAddress) {
          alreadySet = true;
          break;
        }
      }
      require(!alreadySet, "AS");

      rewardTokens.push(rewardAddress);
      
      uint marketsLength = allMarkets.length;
      
      for(uint i = 0; i < marketsLength; i++) {
        _initializeMarket(uint8(rewardTokens.length), address(allMarkets[i]), rewardSupplyState, rewardBorrowState);
      }
  }

  /**
    * @notice Add the market to the markets mapping and set it as listed
    * @dev Admin function to set isListed and add support for the market
    * @param cToken The address of the market (token) to list
    * @param markets Unitroller markets storage
    * @param rewardTokens All Reward Tokens
    * @param allMarkets Unitroller allMarkets storage
    * @param rewardSupplyState Unitroller rewardSupplyState storage
    * @param rewardBorrowState Unitroller rewardBorrowState storage
    * @return uint 0=success, otherwise a failure. (See enum Error for details)
    */
  function _supportMarket(CToken cToken, 
      mapping(address => Comptroller.Market) storage markets,
      address[] calldata rewardTokens,
      CToken[] storage allMarkets,
      mapping(uint8 => mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardSupplyState,
      mapping(uint8 =>mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardBorrowState)
    external returns (ComptrollerErrorReporter.Error) {
     
      if (markets[address(cToken)].isListed) {
        return fail(ComptrollerErrorReporter.Error.MARKET_ALREADY_LISTED, ComptrollerErrorReporter.FailureInfo.SUPPORT_MARKET_EXISTS);
      }

      cToken.isCToken(); // Sanity check to make sure its really a CToken

      markets[address(cToken)] = ComptrollerVXStorage.Market({isListed: true, collateralFactorMantissa: 0});

      _addMarketInternal(address(cToken), allMarkets);

      for(uint8 i = 0; i < rewardTokens.length; i++) {
        _initializeMarket(i ,address(cToken), rewardSupplyState, rewardBorrowState);
      }

      return ComptrollerErrorReporter.Error.NO_ERROR;
  }

  function _addMarketInternal(address cToken, CToken[] storage allMarkets) private {
    for (uint i = 0; i < allMarkets.length; i ++) {
        require(allMarkets[i] != CToken(cToken), "MAA");
    }
    allMarkets.push(CToken(cToken));
  }

  function _initializeMarket(uint8 rewardType,
      address cToken,
      mapping(uint8 => mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardSupplyState,
      mapping(uint8 =>mapping(address => ComptrollerVXStorage.RewardMarketState)) storage rewardBorrowState) 
    private {

      uint32 blockTimestamp = safe32(getBlockTimestamp(),"32");

      ComptrollerVXStorage.RewardMarketState storage supplyState = rewardSupplyState[rewardType][cToken];
      ComptrollerVXStorage.RewardMarketState storage borrowState = rewardBorrowState[rewardType][cToken];

      if (supplyState.index == 0) {
          supplyState.index = initialIndexConstant;
      }

      if (borrowState.index == 0) {            
          borrowState.index = initialIndexConstant;
      }
      
      supplyState.timestamp = borrowState.timestamp = blockTimestamp;
    }
}