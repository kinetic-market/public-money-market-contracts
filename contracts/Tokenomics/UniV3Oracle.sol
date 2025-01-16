// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {Ownable2Step} from "../OpenZeppelin/Ownable2Step.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title PriceOracle
 * @notice This contract allows to retrieve a token's TWAP price in staked ETH from Uniswap V3 pools.
 */
contract UniV3Oracle is Ownable2Step {
    address private immutable sETH;
    IUniswapV3Factory private immutable UNISWAP_V3_FACTORY;

    // Token >> Pool
    mapping(address => address) public oracles;

    event PoolAdded(address token, address pool);
    event PoolRemoved(address token);

    /**
     *
     * @param _sETH Staked Ether address.
     * @param _uniswapV3Factory Uniswap V3 factory address.
     */
    constructor(address _sETH, address _uniswapV3Factory) Ownable2Step() {
        sETH = _sETH;
        UNISWAP_V3_FACTORY = IUniswapV3Factory(_uniswapV3Factory);
    }

    /**
     * @param token The token we want the price in staked ETH for.
     * @param fee Uniswap V3 pool fee.
     */
    function addOracle(address token, uint24 fee) external onlyOwner {
        address pool = UNISWAP_V3_FACTORY.getPool(token, sETH, fee);
        oracles[token] = pool;
        emit PoolAdded(token, pool);
    }

    /**
     * @param token The token we no longer want the price in staked ETH for.
     */
    function removeOracle(address token) external onlyOwner {
        oracles[token] = address(0);
        emit PoolRemoved(token);
    }

    /**
     *
     * @param token The token we want the price in staked ETH for.
     * @param secondsAgo The duration we want to time-weight the average price.
     */
    function consult(address token, uint128 amountIn, uint32 secondsAgo) external view returns (uint256 price) {
        address pool = oracles[token];
        require(pool != address(0), 'Pool not allowed');

        (int24 arithmeticMeanTick, ) = OracleLibrary.consult(pool, secondsAgo);
        price = OracleLibrary.getQuoteAtTick({
            tick: arithmeticMeanTick,
            baseAmount: amountIn,
            baseToken: token,
            quoteToken: sETH
        });
    }
}