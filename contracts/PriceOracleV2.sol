pragma solidity 0.5.17;

import "./CToken.sol";
import "./PriceOracle.sol";

contract PriceOracleV2 is PriceOracle {
    /**
      * @notice Get the price of a token asset
      * @param token The token to get the price of
      * @return The asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getPrice(address token) external view returns (uint);

    /**
      * @notice Get the price of the native network token
      * @return The price mantissa of the Ether token (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getEtherPrice() external view returns (uint);
}
