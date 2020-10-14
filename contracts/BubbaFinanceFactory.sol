pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "./BubbaFinanceMarket.sol";

import "./interfaces/IBubbaFinanceMarket.sol";
import "./interfaces/IBubbaFinanceFactory.sol";

import "./utils/UniswapPriceOracle.sol";

contract BubbaFinanceFactory is IBubbaFinanceFactory, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Constants

    uint8 public constant ALLOCATED_COMMUNITY_FEE_PERCENTAGE = 5;
    uint8 public constant ALLOCATED_DEVFUND_FEE_PERCENTAGE = 15;
    uint8 public constant ALLOCATED_LIQUIDITY_PROVIDERS_FEE_PERCENTAGE = 80;

    Counters.Counter private _marketsCounter;

    mapping(uint256 => Market) public _markets;

    mapping(address => uint256) _devFunds;
    mapping(address => uint256) _communityFunds;

    constructor() public Ownable() {}

    function openMarket(
        address token0,
        address token1,
        uint256 expirationTimestamp,
        uint256 timeToOptionExecution,
        uint8 optionFee,
        address uniswapMarket,
        string calldata marketName,
        string calldata marketSymbol
    ) external onlyOwner returns (uint256 marketId) {
        uint256 token1Price = UniswapPriceOracle.getPrice(uniswapMarket);
        BubbaFinanceMarket market = new BubbaFinanceMarket(
            token0,
            token1,
            expirationTimestamp,
            timeToOptionExecution,
            token1Price,
            optionFee,
            marketName,
            marketSymbol
        );

        marketId = _marketsCounter.current();

        _markets[marketId] = Market(address(market), expirationTimestamp);

        emit MarketCreation(token0, token1, address(market), marketId);
        _marketsCounter.increment();
    }

    function closeMarket(uint256 marketId)
        external
        onlyOwner
        returns (
            bool success,
            uint256 communityWithdrawal,
            uint256 devFundWithdrawal
        )
    {
        require(
            _markets[marketId].market != address(0),
            "BubbaFinanceFactory: Non existing market"
        );

        (success, communityWithdrawal, devFundWithdrawal) = IBubbaFinanceMarket(
            _markets[marketId]
                .market
        )
            .closeMarket();

        address marketToken0 = IBubbaFinanceMarket(_markets[marketId].market)
            .getToken0Address();

        _devFunds[marketToken0].add(devFundWithdrawal);
        _communityFunds[marketToken0].add(communityWithdrawal);

        emit MarketClosed(marketId);
    }

    // Getters

    function getMarketsCount() external override view returns (uint256) {
        return _marketsCounter.current();
    }

    function getMarket(uint256 id)
        external
        override
        view
        returns (uint256, address)
    {
        return (_markets[id].expirationTimestamp, _markets[id].market);
    }

    function getFeesCommunityAllocation()
        external
        override
        view
        returns (uint8)
    {
        return ALLOCATED_COMMUNITY_FEE_PERCENTAGE;
    }

    function getFeesDevfundAllocation() external override view returns (uint8) {
        return ALLOCATED_DEVFUND_FEE_PERCENTAGE;
    }

    function getFeesLiquidityProvidersAllocation()
        external
        override
        view
        returns (uint8)
    {
        return ALLOCATED_LIQUIDITY_PROVIDERS_FEE_PERCENTAGE;
    }
}
