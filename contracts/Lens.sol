// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./Exponential-0.8.sol";
import "./Tokenomics/rewards/CTokenRewards.sol";

interface Comptroller {
    function isComptroller() external view returns (bool);
    function getAllMarkets() external view returns (address[] memory);
    function oracle() external view returns (PriceOracle);
    function markets(address) external view returns (bool, uint);
    function supplyRewardSpeeds(uint8, address) external view returns (uint);
    function borrowRewardSpeeds(uint8, address) external view returns (uint);
    function borrowCaps(address) external view returns (uint);
    function checkMembership(address account, CToken cToken) external view returns (bool);
    function rewardAccrued(uint8, address) external view returns (uint);
    function rewardBorrowState(uint8, address) external view returns (uint224, uint32);
    function rewardSupplyState(uint8, address) external view returns (uint224, uint32);
    function rewardBorrowerIndex(uint8, address, address) external view returns (uint);
    function rewardSupplierIndex(uint8, address, address) external view returns (uint);
    function initialIndexConstant() external view returns (uint224);
    function mintGuardianPaused(address market) external view returns (bool);
    function borrowGuardianPaused(address market) external view returns (bool);
    function getAllRewardTokens() external view returns (address[] memory rewardTokens);
}

interface CToken {
    function borrowRatePerTimestamp() external view returns (uint);
    function supplyRatePerTimestamp() external view returns (uint);
    function exchangeRateStored() external view returns (uint);
    function reserveFactorMantissa() external view returns (uint);
    function totalSupply() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function underlying() external view returns (address);
    function balanceOf(address) external view returns (uint);
    function allowance(address, address) external view returns (uint);
    function borrowBalanceStored(address) external view returns (uint);
    function decimals() external view returns (uint);
    function totalReserves() external view returns (uint);
    function getCash() external view returns (uint);
    function borrowIndex() external view returns (uint);
}

interface PriceOracle {
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
}

interface PriceOracleV2 {
    function isPriceOracle() external pure returns (bool);
    function getUnderlyingPrice(CToken cToken) external view returns (uint);
    function getPrice(address token) external view returns (uint);
    function getEtherPrice() external view returns (uint);
}

interface UnderlyingToken {
    function decimals() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function allowance(address, address) external view returns (uint);
}

interface PangolinLPToken {
    function balanceOf(address) external view returns (uint);
    function allowance(address, address) external view returns (uint);
    function totalSupply() external view returns (uint);
    function getReserves() external view returns (uint112, uint112, uint32);
    function kLast() external view returns (uint);
}

interface PglStakingContract {
    function pglTokenAddress() external view returns (address);
    function totalSupplies() external view returns (uint);
    function rewardSpeeds(uint) external view returns (uint);
    function supplyAmount(address) external view returns (uint);

    function rewardIndex(uint) external view returns (uint);
    function supplierRewardIndex(address, uint) external view returns (uint);
    function accruedReward(address, uint) external view returns (uint);
}

interface GenesisPoolStakingContract {
    function genesisPoolCTokenAddress() external view returns (address);
    function totalSupplies() external view returns (uint);
    function rewardSpeed() external view returns (uint);
    function supplyAmount(address) external view returns (uint);

    function accrualBlockTimestamp() external view returns (uint);
    function rewardIndex() external view returns (uint);
    function supplierRewardIndex(address) external view returns (uint);
    function accruedReward(address) external view returns (uint);
}

struct ProtocolTokens {
    address esProtocolAddress;
    address protocolAddress;
}

contract Lens is ExponentialNoError {
    Comptroller immutable public comptroller;
    PglStakingContract immutable public pglStakingContract;
    GenesisPoolStakingContract[] public genesisPoolStakingContracts;
    CTokenRewards[] public cTokenRewardsContracts;
    address immutable public esProtocolAddress;
    address immutable public protocolAddress;
    address immutable public pangolinRouter;
    PriceOracleV2 immutable public priceOracleV2;

    constructor(address comptrollerAddress,
                address pglStakingContractAddress,
                address pangolinRouterAddress,
                GenesisPoolStakingContract[] memory genesisPoolStakingContracts_,
                CTokenRewards[] memory cTokenRewardsContracts_,
                ProtocolTokens memory protocolTokens,
                PriceOracleV2 priceOracleV2_) {
        comptroller = Comptroller(comptrollerAddress);
        pglStakingContract = PglStakingContract(pglStakingContractAddress);
        genesisPoolStakingContracts = genesisPoolStakingContracts_;
        cTokenRewardsContracts = cTokenRewardsContracts_;
        esProtocolAddress = protocolTokens.esProtocolAddress;
        protocolAddress = protocolTokens.protocolAddress;
        
        require(priceOracleV2_.isPriceOracle(), 'Invalid priceOracle');
        priceOracleV2 = priceOracleV2_;

        require(comptroller.isComptroller(), 'Invalid comptroller address');
        require((pglStakingContractAddress == address(0) && pangolinRouterAddress == address(0)) 
            || pglStakingContract.pglTokenAddress() != address(0), 'Invalid pglStakingContract');

        pangolinRouter = pangolinRouterAddress;
    }

    struct MarketMetadata {
        /// @dev Market (CToken) address
        address market;

        /// @dev Interest rate model's supply rate
        uint supplyRate;

        /// @dev Interest rate model's borrow rate
        uint borrowRate;

        /// @dev Token price (decimal count 36 - underlying decimals)
        uint price;

        /// @dev CToken to underlying token exchange rate (18 - CToken decimals + underlying decimals)
        uint exchangeRate;

        /// @dev Reserve factor percentage (18 decimals)
        uint reserveFactor;

        /// @dev Maximum total borrowable amount for the market, denominated in the underlying asset
        uint borrowCap;

        /// @dev Total supply, denominated in CTokens
        uint totalSupply;

        /// @dev Total supply, denominated in the underlying token
        uint totalUnderlyingSupply;

        /// @dev Total borrows, denominated in the underlying token
        uint totalBorrows;

        /// @dev Collateral factor (18 decimals)
        uint collateralFactor;

        /// @dev Underlying token address
        address underlyingToken;

        /// @dev Underlying token decimal count
        uint underlyingTokenDecimals;

        /// @dev Market CToken decimal count
        uint cTokenDecimals;

        /// @dev Amount of rewards rewarded to suppliers every second
        uint[] supplyRewardSpeeds;
        
        /// @dev Amount of rewards rewarded to borrowers every second
        uint[] borrowRewardSpeeds;

        /// @dev Total amount of reserves of the underlying held in this market
        uint totalReserves;

        /// @dev Cash balance of this cToken in the underlying token (underlying token's decimals)
        uint cash;

        /// @dev Indicates if adding supply is paused
        bool mintPaused;

        /// @dev Indicates if borrowing is paused
        bool borrowPaused;
    }

    struct AccountSnapshot {
        AccountMarketSnapshot[] accountMarketSnapshots;
        AccountRewards rewards;
    }

    struct AccountRewards {
        /// @dev Rewards that can be claimed through the comptroller contract
        AccountComptrollerRewards comptroller;

        /// @dev Rewards that can be claimed through the contract for CTokenRewards
        AccountCTokenRewards[] cTokenRewards;

        /// @dev Rewards that can be claimed through the genesis pools contracts
        AccountGenesisPoolRewards[] genesisPools;
    }

    struct AccountMarketSnapshot {
        /// @dev Market address
        address market;

        /// @dev Account's wallet balance for the underlying token
        uint balance;

        /// @dev The allowed maximum expenditure of the underlying token by the market contract
        uint allowance;

        /// @dev Account's supply balance, denominated in the underlying token
        uint supplyBalance;

        /// @dev Account's borrow balance, denominated in the underlying token
        uint borrowBalance;

        /// @dev Indicates if a market is avaiable as collateral on the account
        bool collateralEnabled;
    }

    struct ComptrollerReward{        
        uint8 rewardType;
        uint unclaimedAmount;
    }

    struct AccountComptrollerRewards {
        ComptrollerReward[] unclaimedRewards;

        /// @dev List of all markets in which the user has unclaimed rewards
        address[] markets;
    }

    struct AccountRewardErc20Info {
        /// @dev Amount of unclaimed token rewards (18 decimals)
        uint amount;

        /// @dev Address of the associated reward token
        address rewardTokenAddress;
    }

    struct AccountCTokenRewards {
        /// @dev The contract where the rewards can be claimed
        CTokenRewards rewardContract;

        /// @dev Amount of unclaimed native token rewards (18 decimals)
        uint unclaimedNativeToken;

        /// @dev Info about unclaimed ERC20 token rewards
        AccountRewardErc20Info[] unclaimedErc20;
    }

    struct AccountGenesisPoolRewards {
        /// @dev Address of the genesis pool where the rewards can be claimed
        GenesisPoolStakingContract poolAddress;

        /// @dev The address of the cToken deposited to the genesis pool
        address cTokenAddress;

        /// @dev Amount of unclaimed esProtocol token rewards (18 decimals)
        uint unclaimedEsProtocolToken;
    }

    struct AccountPglSnapshot {
        /// @dev The PGL balance of the user's wallet (PGL token`s decimals)
        uint balance;

        /// @dev The amount of PGL tokens the user has deposited (PGL token`s decimals)
        uint deposited;

        /// @dev Unclaimed protocol token rewards (18 decimals)
        uint unclaimedProtocolToken;

        /// @dev The allowed maximum expenditure of the user's PGL tokens by the staking contract (PGL token`s decimals)
        uint pglStakingContractAllowance;

        /// @dev The allowed maximum expenditure of the user's protocol tokens (actual protocol tokens, not cTokens) by the pangolin router (18 decimals)
        uint pangolinRouterProtocolTokenAllowance;
    }

    struct AccountGenesisPoolSnapshot {
        /// @dev Address of the genesis pool
        GenesisPoolStakingContract poolAddress;

        /// @dev The address of the cToken deposited to the genesis pool
        address cTokenAddress;

        /// @dev Amount of unclaimed esProtocol token rewards (18 decimals)
        uint unclaimedEsProtocolToken;

        /// @dev The cToken balance of the user's wallet (CToken`s decimals)
        uint balance;

        /// @dev The amount of GenesisPool tokens the user has deposited (GenesisPool token`s decimals)
        uint deposited;

        /// @dev The allowed maximum expenditure of the user's GenesisPool tokens by the staking contract (GenesisPool token`s decimals)
        uint stakingContractAllowance;
    }

    struct MarketPglSnapshot {
        /// @dev Total PGL token amount deposited into the staking contract (PGL token's decimals)
        uint totalDepositedPglTokenAmount;

        /// @dev total supply of PGL tokens (18 decimals)
        uint pglTokenTotalSupply;

        /// @dev amount of protocol tokens in the pool (18 decimals)
        uint pglProtocolTokenReserves;

        /// @dev amount of native tokens in the pool (18 decimals)
        uint pglNativeTokenReserves;

        /// @dev reserve0 * reserve1
        uint kLast;

        /// @dev APR (18 decimals, 1e18 means 100%)
        uint apr;
    }

    struct MarketGenesisPoolSnapshot {
        /// @dev Address of the genesis pool
        GenesisPoolStakingContract poolAddress;

        /// @dev The address of the cToken deposited to the genesis pool
        address cTokenAddress;

        /// @dev Total cToken amount deposited into the staking contract (CToken's decimals)
        uint totalDepositedCTokenAmount;

        /// @dev Total supply of cToken (CToken's decimals)
        uint cTokenTotalSupply;

        /// @dev Exchange rate from the cToken to the underlying token (18 decimals)
        uint cTokenExchangeRate;

        /// @dev price of underlying token of the deposited cToken (18 decimals)
        uint underlyingTokenPrice;

        /// @dev Reward accrual speeds as tokens per second (ESProtocol's decimals)
        uint esProtocolRewardSpeed;

        /// @dev APR (18 decimals, 1e18 means 100%)
        uint apr;
    }

    /**
     * @notice Get prices for the base tokens used by the protocol (the ProtocolToken and the network native token)
     * @return protocolTokenPrice Price of the protocolToken (18 decimals)
     * @return nativeTokenPrice Price of the native token (18 decimals)
     */
    function getPrices() external view returns (uint protocolTokenPrice, uint nativeTokenPrice) {
        nativeTokenPrice = priceOracleV2.getEtherPrice();
        protocolTokenPrice = priceOracleV2.getPrice(protocolAddress);
    }

    /**
     * @notice Get metadata for a specific market
     * @param  market The ctoken address which metadata will be fetched for
     * @return Market metadata
     */
    function getMarketMetadata(CToken market) external view returns (MarketMetadata memory) {
        return _getMarketMetadata(market);
    }

    /**
     * @notice Get metadata for all markets
     * @return Market metadata for all markets
     */
    function getMarketMetadataForAllMarkets() external view returns (MarketMetadata[] memory) {
        address[] memory allMarkets = comptroller.getAllMarkets();
        uint marketCount = allMarkets.length;

        MarketMetadata[] memory metadata = new MarketMetadata[](marketCount);

        for (uint i; i < marketCount;) {
            metadata[i] = _getMarketMetadata(CToken(allMarkets[i]));
            unchecked { ++i; }
        }

        return metadata;
    }

    /**
     * @notice Get account-specific data for supply and borrow positions
     * @param  account Account for the snapshot
     * @return Account snapshot array
     */
    function getAccountSnapshot(address account) external view returns (AccountSnapshot memory) {
        return _getAccountSnapshot(account);
    }

    /**
     * @notice Calculate an account snapshot for a specific market
     * @param  account The account which the snapshot will belong to
     * @param  market The specific market which a snapshot will be calculated for the given account
     * @return Account snapshot
     */
    function getAccountMarketSnapshot(address account, CToken market) external view returns (AccountMarketSnapshot memory) {
        return _getAccountMarketSnapshot(account, market);
    }

    /**
     * @notice Calculate account-specific GenesisPool staking snapshots for each GenesisPool
     * @param  account The account which the snapshot will belong to
     * @return snapshots Account snapshot array for GenesisPool data
     */
    function getAccountGenesisPoolSnapshot(address account) external view returns (AccountGenesisPoolSnapshot[] memory snapshots) {
        uint genesisPoolCount = genesisPoolStakingContracts.length;
        snapshots = new AccountGenesisPoolSnapshot[](genesisPoolCount);

        for (uint i; i < genesisPoolCount;) {
            snapshots[i] = _getAccountGenesisPoolSnapshot(account, genesisPoolStakingContracts[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculate the GenesisPool market snapshots
     * @return Market snapshot for GenesisPool data
     */
    function getMarketGenesisPoolSnapshots() external view returns (MarketGenesisPoolSnapshot[] memory) {
        uint genesisPoolCount = genesisPoolStakingContracts.length;
        MarketGenesisPoolSnapshot[] memory snapshots = new MarketGenesisPoolSnapshot[](genesisPoolCount);

        for (uint i; i < genesisPoolCount;) {
            snapshots[i] = _getMarketGenesisPoolSnapshot(genesisPoolStakingContracts[i]);

            unchecked {
                ++i;
            }
        }

        return snapshots;
    }

    function _getMarketMetadata(CToken market) internal view returns (MarketMetadata memory) {
        address marketAddress = address(market);
        (, uint collateralFactor) = comptroller.markets(marketAddress);

        address underlyingToken;
        uint underlyingTokenDecimals;
       
        underlyingToken = market.underlying();
        underlyingTokenDecimals = UnderlyingToken(underlyingToken).decimals();

        uint totalSupply = market.totalSupply();
        uint totalUnderlyingTokenSupply = _cTokenBalanceToUnderlying(totalSupply, market);
        
        uint rewards = comptroller.getAllRewardTokens().length;
        
        uint[] memory supplyRewardSpeeds = new uint[](rewards);
        uint[] memory borrowRewardSpeeds = new uint[](rewards);
        
        for(uint8 r; r < rewards; r++){        
            supplyRewardSpeeds[r] = comptroller.supplyRewardSpeeds(r, marketAddress);
            borrowRewardSpeeds[r] = comptroller.borrowRewardSpeeds(r, marketAddress);
        }
        

        MarketMetadata memory metadata = MarketMetadata(
            marketAddress,
            market.supplyRatePerTimestamp(),
            market.borrowRatePerTimestamp(),
            comptroller.oracle().getUnderlyingPrice(market),
            market.exchangeRateStored(),
            market.reserveFactorMantissa(),
            comptroller.borrowCaps(marketAddress),
            totalSupply,
            totalUnderlyingTokenSupply,
            market.totalBorrows(),
            collateralFactor,
            underlyingToken,
            underlyingTokenDecimals,
            market.decimals(),
            supplyRewardSpeeds,
            borrowRewardSpeeds,            
            market.totalReserves(),
            market.getCash(),
            comptroller.mintGuardianPaused(marketAddress),
            comptroller.borrowGuardianPaused(marketAddress)
        );

        return metadata;
    }

    function _getAccountSnapshot(address account) internal view returns (AccountSnapshot memory) {
        address[] memory allMarkets = comptroller.getAllMarkets();
        uint marketCount = allMarkets.length;

        AccountMarketSnapshot[] memory snapshots = new AccountMarketSnapshot[](marketCount);

        for (uint i; i < marketCount;) {
            snapshots[i] = _getAccountMarketSnapshot(account, CToken(allMarkets[i]));
            unchecked { ++i; }
        }

        AccountComptrollerRewards memory comprollerRewards = _getAccountComptrollerRewards(account);
        AccountCTokenRewards[] memory cTokenRewards = _getAccountCTokenRewards(account);
        AccountGenesisPoolRewards[] memory genesisPoolRewards = _getAccountGenesisPoolsRewards(account);

        return AccountSnapshot(
            snapshots,
            AccountRewards(
                comprollerRewards,
                cTokenRewards,
                genesisPoolRewards
            )
        );
    }

    function _getAccountComptrollerRewards(address account) internal view returns (AccountComptrollerRewards memory) {
        (
            ComptrollerReward[] memory unclaimedRewards,
            address[] memory marketsWithClaimableRewards
        ) = getComptrollerClaimableRewards(account);

        return AccountComptrollerRewards(unclaimedRewards, marketsWithClaimableRewards);
    }

    function _getAccountCTokenRewards(address account) internal view returns (AccountCTokenRewards[] memory cTokenRewards) {
        unchecked {
            uint numCTokenContracts = cTokenRewardsContracts.length;
            cTokenRewards = new AccountCTokenRewards[](numCTokenContracts);

            for (uint i; i < numCTokenContracts;++i) {
                cTokenRewards[i] = getCTokenClaimableRewards(account, cTokenRewardsContracts[i]);
            }
        }
    }

    function _getAccountGenesisPoolsRewards(address account) internal view returns (AccountGenesisPoolRewards[] memory genesisPoolsRewards) {
        unchecked {
            uint numGenesisPoolsContracts = genesisPoolStakingContracts.length;
            genesisPoolsRewards = new AccountGenesisPoolRewards[](numGenesisPoolsContracts);

            for (uint i; i < numGenesisPoolsContracts;++i) {
                genesisPoolsRewards[i] = getGenesisPoolsClaimableRewards(account, genesisPoolStakingContracts[i]);
            }
        }
    }

    function _getAccountMarketSnapshot(address account, CToken market) internal view returns (AccountMarketSnapshot memory) {
        uint balance;
        uint allowance;

        UnderlyingToken underlyingToken = UnderlyingToken(market.underlying());

        balance = underlyingToken.balanceOf(account);
        allowance = underlyingToken.allowance(account, address(market));
    
        uint cTokenBalance = market.balanceOf(account);
        uint supplyBalance = _cTokenBalanceToUnderlying(cTokenBalance, market);
        bool collateralEnabled = comptroller.checkMembership(account, market);

        return AccountMarketSnapshot(
            address(market),
            balance,
            allowance,
            supplyBalance,
            market.borrowBalanceStored(account),
            collateralEnabled
        );
    }

    function _getAccountGenesisPoolSnapshot(address account, GenesisPoolStakingContract genesisPoolContract) internal view returns (AccountGenesisPoolSnapshot memory) {
        CToken cToken = CToken(genesisPoolContract.genesisPoolCTokenAddress());

        uint balance = cToken.balanceOf(account);
        uint deposited = genesisPoolContract.supplyAmount(account);

        uint unclaimedProtocolToken = updateAndDistributeGenesisPoolRewards(account, genesisPoolContract);

        uint genesisPoolContractAllowance = cToken.allowance(account, address(genesisPoolContract));

        return AccountGenesisPoolSnapshot(
            genesisPoolContract,
            address(cToken),
            unclaimedProtocolToken,
            balance,
            deposited,
            genesisPoolContractAllowance
        );
    }

    function _getMarketGenesisPoolSnapshot(GenesisPoolStakingContract genesisPoolStakingContract) internal view returns (MarketGenesisPoolSnapshot memory) {
        CToken cToken = CToken(genesisPoolStakingContract.genesisPoolCTokenAddress());
        PriceOracle oracle = comptroller.oracle();

        uint totalDepositedCTokenAmount = genesisPoolStakingContract.totalSupplies();
        uint cTokenTotalSupply = cToken.totalSupply();
        uint cTokenExchangeRate = cToken.exchangeRateStored();
        uint underlyingTokenPrice = oracle.getUnderlyingPrice(cToken);

        uint esProtocolRewardSpeed = genesisPoolStakingContract.rewardSpeed();

        uint apr = _calculateAPR(
            esProtocolRewardSpeed,
            priceOracleV2.getPrice(protocolAddress),
            _cTokenBalanceToUnderlying(totalDepositedCTokenAmount, cToken),
            underlyingTokenPrice
        );

        return MarketGenesisPoolSnapshot(
            genesisPoolStakingContract,
            address(cToken),
            totalDepositedCTokenAmount,
            cTokenTotalSupply,
            cTokenExchangeRate,
            underlyingTokenPrice,
            esProtocolRewardSpeed,
            apr
        );
    }

    function _calculatePglAPR(
        uint protocolTokenRewardSpeed,
        uint protocolTokenReserves,
        uint nativeTokenReserves,
        uint protocolTokenPrice,
        uint nativeTokenPrice,
        uint pglTotalSupply,
        uint totalDepositedPGLTokenAmount
    ) internal pure returns (uint usdPerStakedPglValue) {
        uint protocolTokenReservesValue = (protocolTokenReserves * protocolTokenPrice);
        uint nativeTokenReserveValue = (nativeTokenReserves * nativeTokenPrice);

        uint pglPrice = (protocolTokenReservesValue + nativeTokenReserveValue) / pglTotalSupply;

        usdPerStakedPglValue = _calculateAPR(
            protocolTokenRewardSpeed,
            protocolTokenPrice,
            totalDepositedPGLTokenAmount,
            pglPrice
        );
    }

    function _calculateAPR(
        uint protocolTokenRewardSpeed,
        uint protocolTokenPrice,
        uint totalDepositedTokenAmount,
        uint depositedTokenPrice
    ) internal pure returns (uint) {
        uint totalStakedValue = totalDepositedTokenAmount * depositedTokenPrice / 1e18;
        
        if(totalStakedValue == 0){
            return 0;
        }

        uint protocolTokenUsdValuePerYear = protocolTokenRewardSpeed * (60 * 60 * 24 * 365) * protocolTokenPrice;

        return protocolTokenUsdValuePerYear / totalStakedValue;
    }

    function getComptrollerClaimableRewards(address user) internal view returns (ComptrollerReward[] memory, address[] memory) {
        uint8 rewards = uint8(comptroller.getAllRewardTokens().length);        
        uint marketsCount = comptroller.getAllMarkets().length;        
        ComptrollerReward[] memory unclaimedRewards = new ComptrollerReward[](rewards);
        address[] memory rewardMarkets = new address[](marketsCount);
        uint uniqueRewardMarketCount;
        
        for(uint8 r; r < rewards; r++){
            (uint claimableAmount, address[] memory markets) = getComptrollerClaimableReward(user, r);

            unclaimedRewards[r] = ComptrollerReward(r, claimableAmount);

            for (uint i; i < markets.length;++i) {
                bool duplicate = false;

                for (uint j; j < uniqueRewardMarketCount;++j) {
                    if(rewardMarkets[j] == markets[i]) {
                        duplicate = true;
                        break;
                    }
                }

                if (!duplicate) {
                    rewardMarkets[uniqueRewardMarketCount] = markets[i];
                    ++uniqueRewardMarketCount;
                }
            }
        }

        address[] memory marketsWithClaimableRewards = new address[](uniqueRewardMarketCount);

        for (uint i; i < uniqueRewardMarketCount; ++i) {
            marketsWithClaimableRewards[i] = rewardMarkets[i];
        }

        return (unclaimedRewards, marketsWithClaimableRewards);        
    }
    
    function getComptrollerClaimableReward(address user, uint8 rewardType) public view returns (uint, address[] memory) {
        address[] memory markets = comptroller.getAllMarkets();
        uint numMarkets = markets.length;

        uint accrued = comptroller.rewardAccrued(rewardType, user);

        uint totalMarketAccrued;

        address[] memory rawMarketsWithRewards = new address[](numMarkets);
        uint numMarketsWithRewards;

        for (uint i; i < numMarkets;) {
            CToken market = CToken(markets[i]);

            totalMarketAccrued = updateAndDistributeSupplierReward(rewardType, market, user);
            totalMarketAccrued += updateAndDistributeBorrowerReward(rewardType, market, user);

            accrued += totalMarketAccrued;

            if (totalMarketAccrued > 0) {
                rawMarketsWithRewards[numMarketsWithRewards++] = address(market);
            }

            unchecked { ++i; }
        }

        address[] memory marketsWithRewards = new address[](numMarketsWithRewards);

        for (uint i; i < numMarketsWithRewards;) {
            marketsWithRewards[i] = rawMarketsWithRewards[i];
            unchecked { ++i; }
        }

        return (accrued, marketsWithRewards);
    }

    function getCTokenClaimableRewards(address account, CTokenRewards cTokenRewards) internal view returns (AccountCTokenRewards memory) {
        uint rewardTokensLength = cTokenRewards.rewardTokensLength();

        uint unclaimedNative = cTokenRewards.userPendingEther(account);
        AccountRewardErc20Info[] memory unclaimedErc20 = new AccountRewardErc20Info[](rewardTokensLength);

        for (uint i; i < rewardTokensLength;) {
            address rewardTokenAddress = cTokenRewards.rewardTokenAt(i);
            uint unclaimedAmount = cTokenRewards.userPendingRewards(IERC20(rewardTokenAddress), account);
            unclaimedErc20[i] = AccountRewardErc20Info(unclaimedAmount, rewardTokenAddress);

            unchecked {
                ++i;
            }
        }

        return AccountCTokenRewards(cTokenRewards, unclaimedNative, unclaimedErc20);
    }

    function getGenesisPoolsClaimableRewards(address account, GenesisPoolStakingContract genesisPoolContract) internal view returns (AccountGenesisPoolRewards memory) {
        uint unclaimedRewards = updateAndDistributeGenesisPoolRewards(account, genesisPoolContract);
        return AccountGenesisPoolRewards(genesisPoolContract, genesisPoolContract.genesisPoolCTokenAddress(), unclaimedRewards);
    }

    function updateAndDistributeGenesisPoolRewards(address recipient, GenesisPoolStakingContract genesisPool) internal view returns (uint unclaimedRewards) {
        uint rewardIndex = accrueRewardGenesisPool(genesisPool);

        uint rewardIndexDelta = rewardIndex - genesisPool.supplierRewardIndex(recipient);
        uint accruedAmount = rewardIndexDelta * genesisPool.supplyAmount(recipient) / 1e36;
        unclaimedRewards = genesisPool.accruedReward(recipient) + accruedAmount;
    }

    function accrueRewardGenesisPool(GenesisPoolStakingContract genesisPoolContract) internal view returns (uint) {
        uint blockTimestampDelta = block.timestamp - genesisPoolContract.accrualBlockTimestamp();
        uint totalSupplies = genesisPoolContract.totalSupplies();
        uint rewardSpeed = genesisPoolContract.rewardSpeed();
        uint rewardIndex = genesisPoolContract.rewardIndex();

        if (blockTimestampDelta == 0 || totalSupplies == 0 || rewardSpeed == 0) {
            return rewardIndex;
        }

        uint accrued = rewardSpeed * blockTimestampDelta;
        uint accruedPerCToken = (accrued * 1e36) / totalSupplies;

        return rewardIndex + accruedPerCToken;
    }

    function updateRewardBorrowIndex(
        uint8 rewardType,
        CToken cToken,
        Exp memory marketBorrowIndex
    ) internal view returns (uint224) {
        (uint224 borrowStateIndex, uint32 borrowStateTimestamp) = comptroller.rewardBorrowState(rewardType, address(cToken));
        uint borrowSpeed = comptroller.borrowRewardSpeeds(rewardType, address(cToken));
        uint32 blockTimestamp = uint32(block.timestamp);
        uint deltaTimestamps = sub_(blockTimestamp, uint(borrowStateTimestamp));

        if (deltaTimestamps > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(cToken.totalBorrows(), marketBorrowIndex);
            uint rewardAccrued = mul_(deltaTimestamps, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(rewardAccrued, borrowAmount) : Double({ mantissa: 0 });
            Double memory index = add_(Double({ mantissa: borrowStateIndex }), ratio);

            return uint224(index.mantissa);
        }

        return borrowStateIndex;
    }

    function updateRewardSupplyIndex(
        uint8 rewardType,
        CToken cToken
    ) internal view returns (uint) {
        (uint224 supplyStateIndex, uint32 supplyStateTimestamp) = comptroller.rewardSupplyState(rewardType, address(cToken));
        uint supplySpeed = comptroller.supplyRewardSpeeds(rewardType, address(cToken));
        uint32 blockTimestamp = uint32(block.timestamp);
        uint deltaTimestamps = sub_(blockTimestamp, uint(supplyStateTimestamp));

        if (deltaTimestamps > 0 && supplySpeed > 0) {
            uint supplyTokens = cToken.totalSupply();
            uint rewardAccrued = mul_(deltaTimestamps, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(rewardAccrued, supplyTokens) : Double({ mantissa: 0 });
            Double memory index = add_(Double({ mantissa: supplyStateIndex }), ratio);

            return index.mantissa;
        }

        return supplyStateIndex;
    }

    function distributeBorrowerReward(
        uint8 rewardType,
        CToken cToken,
        address borrower,
        uint borrowStateIndex,
        Exp memory marketBorrowIndex
    ) internal view returns (uint) {

        Double memory borrowIndex = Double({ mantissa: borrowStateIndex });
        Double memory borrowerIndex = Double({ mantissa: comptroller.rewardBorrowerIndex(rewardType, address(cToken), borrower) });

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(cToken.borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);

            return borrowerDelta;
        }

        return 0;
    }

    function distributeSupplierReward(
        uint8 rewardType,
        CToken cToken,
        address supplier,
        uint supplyStateIndex
    ) internal view returns (uint) {
        Double memory supplyIndex = Double({ mantissa: supplyStateIndex });
        Double memory supplierIndex = Double({ mantissa: comptroller.rewardSupplierIndex(rewardType, address(cToken), supplier) });

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = comptroller.initialIndexConstant();
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = cToken.balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);

        return supplierDelta;
    }

    function updateAndDistributeBorrowerReward(
        uint8 rewardType,
        CToken cToken,
        address borrower
    ) internal view returns (uint) {
        Exp memory marketBorrowIndex = Exp({ mantissa: cToken.borrowIndex() });
        uint borrowStateIndex = updateRewardBorrowIndex(rewardType, cToken, marketBorrowIndex);

        return distributeBorrowerReward(rewardType, cToken, borrower, borrowStateIndex, marketBorrowIndex);
    }

    function updateAndDistributeSupplierReward(
        uint8 rewardType,
        CToken cToken,
        address supplier
    ) internal view returns (uint) {
        uint supplyStateIndex = updateRewardSupplyIndex(rewardType, cToken);

        return distributeSupplierReward(rewardType, cToken, supplier, supplyStateIndex);
    }

    function _cTokenBalanceToUnderlying(uint cTokenBalance, CToken market) internal view returns (uint) {
        uint exchangeRate = market.exchangeRateStored();

        return cTokenBalance * exchangeRate / 10 ** 18;
    }
}
