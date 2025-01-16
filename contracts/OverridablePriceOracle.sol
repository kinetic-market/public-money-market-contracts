pragma solidity 0.5.17;

import "./OpenZeppelin/Ownable.sol";
import "./PriceOracleV2.sol";
import "./CErc20.sol";
import "./EIP20Interface.sol";
import "./SafeMath.sol";

contract OverridablePriceOracle is PriceOracleV2, Ownable2Step {
    using SafeMath for uint;

    string internal cNativeSymbol;
    mapping(address => uint) internal prices;
    uint etherPrice;
    
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event FeedSet(address feed, string symbol);

    constructor(string memory cNativeSymbol_) public {
        cNativeSymbol = cNativeSymbol_;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        string memory symbol = cToken.symbol();
        if (compareStrings(symbol, cNativeSymbol)) {
            return getEtherPrice();
        } else {
            address underlyingAddress = CErc20(address(cToken)).underlying();
            return getPrice(underlyingAddress);
        }
    }

    function getPrice(address tokenAddress) public view returns (uint price) {
        EIP20Interface token = EIP20Interface(tokenAddress);

        if (prices[address(token)] != 0) {
            price = prices[address(token)];
        } else {
            price = _getPrice(tokenAddress);
        }

        uint decimalDelta = uint(18).sub(uint(token.decimals()));
        // Ensure that we don't multiply the result by 0
        if (decimalDelta > 0) {
            return price.mul(10**decimalDelta);
        } else {
            return price;
        }
    }

    function getEtherPrice() public view returns (uint price) {
        if (etherPrice != 0) {
            price = etherPrice;
        } else {
            price = _getEtherPrice();
        }
    }

    function setEtherPrice(uint price) public onlyOwner(){
        etherPrice = price;
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) external onlyOwner() {
        string memory symbol = cToken.symbol();
        if (compareStrings(symbol, cNativeSymbol)) {
            setEtherPrice(underlyingPriceMantissa);
        }
        else {
            address asset = address(CErc20(address(cToken)).underlying());
            setPrice(asset, underlyingPriceMantissa);        
        }        
    }

    function setPrice(address asset, uint price) public onlyOwner() {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _getPrice(address token) internal view returns (uint) {
        token;
        this;
        return 0;
    }

    function _getEtherPrice() internal view returns (uint) {
        this;
        return 0;
    }
}
