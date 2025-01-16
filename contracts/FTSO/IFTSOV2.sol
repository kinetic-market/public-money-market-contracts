// SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
interface IFTSOV2 {
    /**
     * @dev Get the current value of the FTSO V2 feed
     */
    function getFeedById(bytes21 _feedId) external view returns (uint256 value, int8 decimals, uint64 timestamp);

    /**
     * @dev for sanity check
     */
    function FTSO_PROTOCOL_ID() external view returns (uint256);
}
