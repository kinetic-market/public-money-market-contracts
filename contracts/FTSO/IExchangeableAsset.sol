// SPDX-License-Identifier: MIT
interface IExchangeableAsset{
    function getExchangeRate() external view returns (uint);
    function decimals() external view returns (uint8);
}
