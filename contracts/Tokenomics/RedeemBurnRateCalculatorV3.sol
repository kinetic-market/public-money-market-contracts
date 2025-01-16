// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./IRedeemBurnRateCalculator.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface PriceOracleV2{
    /**
      * @notice Get the price of a token asset
      * @param token The token to get the price of
      * @return The asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    function getPrice(address token) external view returns (uint);
}

interface IUniV3Oracle{
    function consult(address token, uint128 amountIn, uint32 age) external view returns (uint amountOut);
}

contract RedeemBurnRateCalculatorV3 is IRedeemBurnRateCalculator, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice TWAP Oracle period
    uint32 private constant PERIOD = 60 minutes; 

    /// @notice UniV3 Oracle
    IUniV3Oracle public uniV3Oracle;

    /// @notice Protocol token
    IERC20Metadata public protocolToken;
    
    /// @notice Protocol token decimals
    uint8 public protocolTokenDecimals;
    
    /// @notice esProtocol token
    IERC20Metadata public esProtocolToken;

    /// @notice esProtocol token decimals
    uint8 public esProtocolTokenDecimals;

    /// @notice staked ETH token
    IERC20Metadata public sETH;

    /// @notice Staked ETH token decimals
    uint8 public sETHDecimals;

    /// @notice Burn rate Threshold in USD
    uint public burnRateThresholdUSD;

    /// @notice Price Oracle
    PriceOracleV2 public priceOracle;

    /// @notice Use the price Oracle price for the Protocol Token
    bool public useOraclePrice;

    /// @notice The addresses that are excluded from USD balance check
    EnumerableSet.AddressSet internal _exclusionListedAddresses; 

    /// @notice Emitted when an address is allowed to check the USD balance
    event AddressAllowed(address address_);

    /// @notice Emitted when an address is disallowed to check the USD balance
    event AddressDisallowed(address address_);

    constructor(IERC20Metadata _protocolToken,
        IERC20Metadata _esProtocolToken,
        IERC20Metadata _sETH,
        uint _burnRateThresholdUSD,
        PriceOracleV2 _priceOracle,
        bool _useOraclePrice,
        IUniV3Oracle _uniV3Oracle) {

        protocolToken = _protocolToken;
        protocolTokenDecimals = protocolToken.decimals();
        require(protocolTokenDecimals == 18, 'invalid protocolToken decimals');

        esProtocolToken = _esProtocolToken;
        esProtocolTokenDecimals = esProtocolToken.decimals();
        require(esProtocolTokenDecimals == 18, 'invalid esProtocolToken decimals');

        sETH = _sETH;
        sETHDecimals = sETH.decimals();
        require(sETHDecimals == 18, 'invalid sETH decimals');
        
        burnRateThresholdUSD = _burnRateThresholdUSD;
        require(burnRateThresholdUSD > 0, 'invalid burn rate threshold');
        useOraclePrice = _useOraclePrice;

        // sanity check
        _priceOracle.getPrice(address(sETH));
        priceOracle = _priceOracle;
        uniV3Oracle = _uniV3Oracle;
    }

     /**
     * @notice Remove address from the exclusion list
     */
    function allow(address address_) external onlyOwner {
        require(_exclusionListedAddresses.contains(address_), 'address already allowed');

        emit AddressAllowed(address_);
        _exclusionListedAddresses.remove(address_);
    }

    /**
     * @notice Add address to the exclusion list
     */
    function disallow(address address_) external onlyOwner {
        require(!_exclusionListedAddresses.contains(address_), 'address already disallowed');

        emit AddressDisallowed(address_);
        _exclusionListedAddresses.add(address_);    
    }

    /**
     * @dev returns length of _exclusionListedAddresses array
     */
    function exclusionListedAddressesLength() external view returns (uint256) {
        return _exclusionListedAddresses.length();
    }

    /**
     * @dev returns _exclusionListedAddresses array item's address for "index"
     */
    function exclusionListedAddressAt(uint256 index) external view returns (address) {
        return _exclusionListedAddresses.at(index);
    }

    /**
     * @dev Check if a address is in the exclusion list
     */
    function exclusionListedAddress(address user) external view returns (bool) {
        return _exclusionListedAddresses.contains(user);
    }

    function shouldSkipBurnRate(
        address user,
        uint256 /*amount*/
    ) external view override returns (bool) {
        if (_exclusionListedAddresses.contains(user))
            return false;

        if (useOraclePrice) {
            uint256 price = priceOracle.getPrice(address(protocolToken));

            return ((price * esProtocolToken.balanceOf(user) / (10**esProtocolTokenDecimals)) > burnRateThresholdUSD);
        }
        uint amountOut = getAmountOut();

        uint esProtocolWNativePrice = amountOut * esProtocolToken.balanceOf(user) / (10**esProtocolTokenDecimals);

        uint sNativePrice =  priceOracle.getPrice(address(sETH));

        esProtocolWNativePrice = esProtocolWNativePrice * sNativePrice / (10**sETHDecimals);

        return esProtocolWNativePrice > burnRateThresholdUSD;
    }

    function getAmountOut() internal view returns (uint amountOut){
        amountOut = uniV3Oracle.consult(address(protocolToken), uint128(10**protocolTokenDecimals), PERIOD);
    }
}