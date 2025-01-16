// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CTokenRewardsStorage.sol";

/**
 * @title CToken liquidity incentive rewards 
 * @notice First version of the CTokenRewards contract that receives manual reward allocations for specific users.
 * @dev This contract does no proportional allocation or any other logic to distribute the rewards, it's basically a vault so the users can claim rewards
 */
contract CTokenRewards is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, CTokenRewardsStorageV1 {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
      _disableInitializers();
  }

  /**
   * @notice Standard Initializable method
   */
  function initialize() initializer public {
    __Ownable_init();
    __ReentrancyGuard_init();
  }

  /**
   * Deposits reward tokens allocating different shares to different users
   * @notice The total amount of reward tokens allocated will be transfered from the caller to the contract during this call, 
   *         so make sure to have enough allowance on the reward token for this contract and enough balance.
   *         Also, if the number of users is too big, this function should be called in smaller batches so it does not run out of gas
   * @param rewardToken The token being rewarded to users
   * @param users Users that are being allocated rewards
   * @param amounts Amounts of token reward allocated to the user on the same index
   * @dev The arrays of users and amounts should have the same length
   */
  function depositTokens(address rewardToken, address[] calldata users, uint256[] calldata amounts) external onlyOwner {
    require(users.length > 0 && users.length == amounts.length, "Invalid input");    
    require(rewardToken != address(0), "Invalid reward token");

    uint256 totalAmount;
    IERC20 rewardTokenContract = IERC20(rewardToken);

    uint256 i;
    uint256 userCount = users.length;
    for (; i < userCount;) {
      address user = users[i];
      uint256 amount = amounts[i];

      require(amount > 0, "Amount must be greater than zero");

      userPendingRewards[rewardTokenContract][user] = userPendingRewards[rewardTokenContract][user] + amount;
      totalAmount = totalAmount + amount;
    
      emit TokensDeposited(rewardToken, user, amount);
      unchecked { ++i; }
    }

    rewardTokens.add(rewardToken);
    
    uint balanceBefore = rewardTokenContract.balanceOf(address(this));
    // Transfer tokens from caller to contract
    rewardTokenContract.safeTransferFrom(msg.sender, address(this), totalAmount);
    uint actualTransferredAmount = rewardTokenContract.balanceOf(address(this)) - balanceBefore;

    require(actualTransferredAmount >= totalAmount, "Invalid deposit");
  }

  /**
   * Claims the available rewards for the specified reward token
   * @notice All the available rewards for the token will be claimed to the caller of the function. So only end users should call it
   * @param token The token to claim
   */
  function claimTokens(address token) external nonReentrant {
    require(token != address(0), "Invalid token address");
    IERC20 tokenContract = IERC20(token);
    uint256 amount = userPendingRewards[tokenContract][msg.sender];
    require(amount > 0, "No tokens to claim");

    userPendingRewards[tokenContract][msg.sender] = 0;
    userClaimedRewards[tokenContract][msg.sender] = userClaimedRewards[tokenContract][msg.sender] + amount;
    emit TokensClaimed(msg.sender, token, amount);

    // Transfer tokens to user
    tokenContract.safeTransfer(msg.sender, amount);
  }
  

  /**
   * Deposits ether rewards allocating different shares to different users
   * @notice The total amount of ether allocated will be transfered from the caller to the contract during this call, 
   *         so make sure to have enough ether balance.
   *         Also, if the number of users is too big, this function should be called in smaller batches so it does not run out of gas   
   * @param users Users that are being allocated rewards
   * @param amounts Amounts of ether allocated to the user on the same index
   * @dev The arrays of users and amounts should have the same length
   */
  function depositEther(address[] calldata users, uint256[] calldata amounts) external payable onlyOwner  {
    require(users.length > 0 && users.length == amounts.length, "Invalid input");    

    uint256 totalAmount;
    uint256 i;
    uint256 userCount = users.length;
    for ( ; i < userCount; ) {
      address user = users[i];
      uint256 amount = amounts[i];

      require(amount > 0, "Amount must be greater than zero");

      userPendingEther[user] = userPendingEther[user] + amount;
      totalAmount = totalAmount + amount;
    
      emit EtherDeposited(user, amount);
      unchecked { ++i; }
    }
    
    require(totalAmount == msg.value, "insufficient amount");   
  }
  
  /**
   * Claims the available ether rewards
   * @notice All the available ether be claimed to the caller of the function. So only end users should call it   
   */
  function claimEther() external nonReentrant{
    uint256 amount = userPendingEther[msg.sender];
    require(amount > 0, "No ether to claim");
   
    userPendingEther[msg.sender] = 0;    
    userClaimedEther[msg.sender] = userClaimedEther[msg.sender] + amount;
    emit EtherClaimed(msg.sender, amount);

    // Transfer Ether to user
    (bool success, ) = payable(msg.sender).call{value: amount, gas: 4029}("");    
    require(success, "Transfer failed.");
  }

  /**
   * @dev Checks if an index exists
   */
  modifier validateRewardTokensIndex(uint256 index) {
    require(index < rewardTokens.length(), "validateRewardTokensIndex: index exists?");
    _;
  }

  /**
   * @dev Returns the number of rewards tokens
   */
  function rewardTokensLength() external view returns (uint256) {
    return rewardTokens.length();
  }

  /**
   * @dev Returns rewards token address from given index
   */
  function rewardTokenAt(uint256 index) external view validateRewardTokensIndex(index) returns (address) {
    return address(rewardTokens.at(index));
  }
}
