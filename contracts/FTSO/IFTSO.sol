// SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
interface IFTSO {
    /**
     * @notice Public view function to get the price of active FTSO for given asset symbol
     * @param _symbol asset symbol
     * @dev Reverts if unsupported symbol is passed
     * @return _price current price of asset in USD
     * @return _timestamp timestamp for when this price was updated
     * @return _assetPriceUsdDecimals number of decimals used for USD price
     */
    function getCurrentPriceWithDecimals(
    string calldata _symbol
    ) external view returns (
    uint256 _price,
    uint256 _timestamp,
    uint256 _assetPriceUsdDecimals);

    function productionMode() external view returns (bool);
}
