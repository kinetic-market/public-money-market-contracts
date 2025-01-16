# Kinetic Smart Contracts

## Overview

Kinetic is an ecosystem-tailored money market enhanced with an optional work-to-earn element.

### Project Details
- **Project Name**: Kinetic
- **Codebase**: [GitHub Repository](https://github.com/kinetic-market/public-money-market-contracts)
- **Language**: Solidity
- **Last audit report**: https://kinetic.market/assets/Kinetic-audit-reports.pdf
- **Audit Date**: April 11, 2024

## Known Issues

### Price Oracle Does Not Support Tokens with `Decimals > 18`
- **Smart Contract**: `contracts/OverridablePriceOracle.sol`
- **Description**: Tokens with decimals greater than 18 cause underflow errors.

### Lack of Expiration for `OverridablePriceOracle` in `prices`
- **Smart Contract/File**: `contracts/OverridablePriceOracle.sol`
- **Description**: The override price lacks expiration, which could lead to unnoticed mispricing.

### Using a Symbol as the Key in `tokenConfigs`
- **Smart Contract**: `contracts/FTSO/ProtocolFTSOV2Oracle.sol`
- **Description**: Using `token.symbol()` as a key can lead to unexpected behavior as symbols can change.

### `ProtocolFTSOV2Oracle.getFTSOPrice()` Decimal Limitation
- **Smart Contract**: `contracts/FTSO/ProtocolFTSOV2Oracle.sol`
- **Description**: Tokens with `_assetPriceUsdDecimals > 18` may encounter underflow.

### Loss of precision, rounding down instead of up on `CToken` using `divScalarByExpTruncate`
- **Smart Contract**: `contracts/CToken.sol`
- **Description**: Precision loss.
