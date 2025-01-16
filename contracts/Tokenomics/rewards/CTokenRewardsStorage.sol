// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/** 
 * First storage model of the CTokenRewards.
 * @dev For future storage changes, new versions should be created and inherit from the previous one
 */
contract CTokenRewardsStorageV1 {
  /// User's pending rewards by reward token address
  mapping(IERC20 => mapping(address => uint256)) public userPendingRewards;
  /// User's claimed rewards by reward token address
  mapping(IERC20 => mapping(address => uint256)) public userClaimedRewards;
  /// User's pending ether rewards
  mapping(address => uint256) public userPendingEther;
  /// User's claimed ether rewards
  mapping(address => uint256) public userClaimedEther;
 
  /// @dev All tokens ever distributed will be present even though no pending rewards are available
  EnumerableSet.AddressSet internal rewardTokens;
  
  /**
   * @notice Event for every new reward allocation
   * @param token the reward token address
   * @param user the user that have been allocated rewards to
   * @param amount the amount of rewards that have been allocated to the user
   */
  event TokensDeposited(address indexed token, address indexed user, uint256 amount);
  /**
   * @notice Event for every an user claims allocated rewards
   * @param user the user that claimed the rewards
   * @param token the reward token address
   * @param amount the amount of reward tokens that have been claimed
   */
  event TokensClaimed(address indexed user, address indexed token, uint256 amount);
  /**
   * @notice Event for every new ether reward allocation   
   * @param user the user that have been allocated rewards to
   * @param amount the amount of rewards that have been allocated to the user
   */
  event EtherDeposited(address indexed user, uint256 amount);
  /**
   * @notice Event for every an user claims allocated ether rewards
   * @param user the user that claimed the rewards   
   * @param amount the amount of ether that have been claimed
   */
  event EtherClaimed(address indexed user, uint256 amount);
}
