pragma solidity 0.5.17;

import "./Comptroller.sol";
import "./ComptrollerLib.sol";

contract ComptrollerV2 is Comptroller{
  /**
  * @notice Update users rFLR supply/borrow reward state to market state
  * @param users The users list to update state
  * @dev msg.sender must be unitroller.admin or ComptrollerLib.allowList.allowed(msg.sender)
  **/
  function _updateRFLRRewardState(address[] calldata users) external {
    ComptrollerLib.allowed(msg.sender);
    ComptrollerLib.updateRFLRRewardState(allMarkets, users, rewardSupplyState, rewardSupplierIndex, rewardBorrowState, rewardBorrowerIndex, rewardAccrued);
  }

  /**
   * @notice Accrue rewards to the market by updating the supply index
   * @param rewardType 1 = Native token, != 1 ERC20 Tokens
   * @param cToken The market whose supply index to update
   * @dev msg.sender must be unitroller
   */
  function _updateRewardSupplyIndex(uint8 rewardType, address cToken) external {
    require(msg.sender == address(this), 'UO');
    require(markets[cToken].isListed, "ML");
    updateRewardSupplyIndex(rewardType, cToken);
  }

  /**
   * @notice Accrue rewards to the market by updating the borrow index
   * @param rewardType 1 = Native token, != 1 ERC20 Tokens
   * @param cToken The market whose borrow index to update
   * @dev msg.sender must be unitroller
   */
  function _updateRewardBorrowIndex(uint8 rewardType, address cToken) external {
    require(msg.sender == address(this), 'UO');
    require(markets[cToken].isListed, "ML");
    updateRewardBorrowIndex(rewardType, cToken,  ExponentialNoError.Exp({mantissa: CToken(cToken).borrowIndex()}));
  }

  /**
  * @notice Configure new reward type to the protocol
  * @param rewardAddress New reward token address
  **/
  function setRewardType(address rewardAddress) external {
    require(msg.sender == admin, 'AO');
    ComptrollerLib.setRewardType(rewardAddress, rewardTokens, protocolTokenAddress, allMarkets, rewardSupplyState, rewardBorrowState);

    uint8 rewardsLength = uint8(rewardTokens.length);

    require(rewardsLength > 0, 'IRT');

    // keep event emission on Comptroller
    emit NewRewardType(rewardAddress, (rewardsLength - 1));
  }

  /**
  * @notice Add the market to the markets mapping and set it as listed
  * @dev Admin function to set isListed and add support for the market
  * @param cToken The address of the market (token) to list
  * @return uint 0=success, otherwise a failure. (See enum Error for details)
  **/
  function _supportMarket(CToken cToken) external returns (uint) {
    if (msg.sender != admin) {
        return uint(fail(ComptrollerErrorReporter.Error.UNAUTHORIZED, ComptrollerErrorReporter.FailureInfo.SUPPORT_MARKET_OWNER_CHECK));
    }
    
    ComptrollerErrorReporter.Error result = ComptrollerLib._supportMarket(cToken, markets, rewardTokens, allMarkets, rewardSupplyState, rewardBorrowState);

    if(result == ComptrollerErrorReporter.Error.NO_ERROR){
      // keep event emission on Comptroller
      emit MarketListed(cToken);
    }
      
    return uint(result);
  }
}