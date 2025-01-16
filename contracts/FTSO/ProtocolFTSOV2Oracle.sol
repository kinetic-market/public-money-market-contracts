// SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "../OverridablePriceOracle.sol";
import "../CErc20.sol";
import "../EIP20Interface.sol";
import "../SafeMath.sol";
import "./IFTSOV2.sol";
import "./IExchangeableAsset.sol";

contract ProtocolFTSOV2Oracle is OverridablePriceOracle {
    using SafeMath for uint;
    
    struct TokenConfig {        
        address asset;
        bytes21 ftsoV2FeedId;        
        uint64 maxStalePeriod;
        address exchangeAsset;
    }

    /// @notice Flare Time Series Oracle V2
    IFTSOV2 public ftsoV2;    

    /// @notice Underlying token configs by token symbol
    mapping(string => TokenConfig) public tokenConfigs;

    /// @notice Emit when setting a new FTSO V2 address
    event FTSOV2OracleSet(address indexed oldFTSOV2, address indexed newFTSOV2);

    /// @notice Emit when a token config is added
    event TokenConfigAdded(
        address indexed asset,
        bytes21 indexed ftsoV2FeedId,
        uint64 indexed maxStalePeriod,
        address exchangeAsset
    );

    constructor(string memory cNativeSymbol_) OverridablePriceOracle(cNativeSymbol_) public { }
    
    function _getPrice(address tokenAddress) internal view returns (uint) {
        EIP20Interface token = EIP20Interface(tokenAddress);
        TokenConfig memory tokenConfig = getFeed(token.symbol());
        uint _price = getFTSOPrice(getFeed(token.symbol()));

        if(tokenConfig.exchangeAsset != address(0)){
            uint decimals = IExchangeableAsset(tokenConfig.exchangeAsset).decimals();
            uint exchangeRate = IExchangeableAsset(tokenConfig.exchangeAsset).getExchangeRate();
           
            _price = _price.mul(exchangeRate).div(10**decimals);
        }
        
        return _price;
    }

    function _getEtherPrice() internal view returns (uint) {
        return getFTSOPrice(tokenConfigs[cNativeSymbol]);
    }

    /**
     * @notice Set single token config. `maxStalePeriod` cannot be 0 and `cToken` can't be a null address
     */
    function setTokenConfig(TokenConfig memory config) public onlyOwner {
        if (config.asset == address(0))
            revert("can't be zero address");

        if (config.maxStalePeriod == 0)
            revert("max stale period cannot be 0");

        EIP20Interface token = EIP20Interface(config.asset);

        if (token.decimals() > 18)
            revert("invalid token");
        
        if(config.exchangeAsset != address(0)){
            // sanity check
            IExchangeableAsset(config.exchangeAsset).getExchangeRate();
            
            require(IExchangeableAsset(config.exchangeAsset).decimals() == 18, "invalid exchangeable token");
        }
    
        tokenConfigs[token.symbol()] = config;     

        emit TokenConfigAdded(            
            config.asset,
            config.ftsoV2FeedId,
            config.maxStalePeriod,
            config.exchangeAsset
        );
    }

    /**
     * @notice Set single token config. `maxStalePeriod` cannot be 0
     */
    function setNativeTokenConfig(TokenConfig memory config) public onlyOwner {
        if (config.maxStalePeriod == 0)
            revert("max stale period cannot be 0");

        require(config.exchangeAsset == address(0), "invalid exchangeAsset for Native token");

        tokenConfigs[cNativeSymbol] = config;        

        emit TokenConfigAdded(            
            config.asset,
            config.ftsoV2FeedId,
            config.maxStalePeriod,
            config.exchangeAsset
        );
    }

    /**
     * @notice Set the FTSO registry contract address     
     */
    function setFTSOV2(IFTSOV2 ftsoV2_) external onlyOwner {
        address ftsoV2Address = address(ftsoV2_);
        require(ftsoV2Address != address(0) && ftsoV2Address != address(this), "invalid FTSO V2 address");

        // sanity check
        ftsoV2_.FTSO_PROTOCOL_ID();
        
        emit FTSOV2OracleSet(address(ftsoV2), ftsoV2Address);
        ftsoV2 = ftsoV2_;
    }

    function getFeed(string memory tokenSymbol) internal view returns (TokenConfig memory config){         
        TokenConfig memory tokenConfig = tokenConfigs[tokenSymbol];
        
        require(tokenConfig.maxStalePeriod > 0, "asset config doesn't exist");

        return tokenConfig;
    }

    function getFTSOPrice(TokenConfig memory tokenConfig) internal view returns (uint) {
        (uint256 _price, int8 _assetPriceUsdDecimals, uint256 _timestamp) = 
            ftsoV2.getFeedById(tokenConfig.ftsoV2FeedId);

        require(_price > 0, "invalid price");
        require(_assetPriceUsdDecimals > 0, 'invalid exponential');
        require(block.timestamp.sub(_timestamp) <= tokenConfig.maxStalePeriod, "stale price");
        
        uint decimalDelta = uint(18).sub(uint(_assetPriceUsdDecimals));
                
        if (decimalDelta > 0) {
            return _price.mul(10**decimalDelta);            
        } else {
            return _price;
        }
    }
}
