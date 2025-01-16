pragma solidity 0.5.17;

import "./PriceOracle.sol";
import "./CErc20.sol";

contract SimplePriceOracle is PriceOracle {
    mapping(address => uint) prices;
    uint etherPrice;
    address public admin;

    constructor() public {
        admin = msg.sender;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        return prices[address(cToken)];
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public {
        require(msg.sender == admin, "Only admin can set the price");

        prices[address(cToken)] = underlyingPriceMantissa;
    }

    function getPrice(address token) public view returns (uint) {
        return prices[token];
    }

    function setPrice(address token, uint priceMantissa) public {
        require(msg.sender == admin, "Only admin can set the price");

        prices[token] = priceMantissa;
    }

    function getEtherPrice() public view returns (uint) {
        return etherPrice;
    }

    function setEtherPrice(uint priceMantissa) public {
        require(msg.sender == admin, "Only admin can set the price");

        etherPrice = priceMantissa;
    }
}
