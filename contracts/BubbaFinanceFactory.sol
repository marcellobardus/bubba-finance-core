pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "./BubbaFinanceMarket.sol";

import "./interfaces/IBubbaFinanceFactory.sol";

import "./utils/UniswapPriceOracle.sol";

contract BubbaFinanceFactory is IBubbaFinanceFactory, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Constants

    uint8 public constant ALLOCATED_COMMUNITY_FEE_PERCENTAGE = 5;
    uint8 public constant ALLOCATED_DEVFUND_FEE_PERCENTAGE = 15;
    uint8 public constant ALLOCATED_LIQUIDITY_PROVIDERS_FEE_PERCENTAGE = 80;

    Counters.Counter private marketsCounter;

    mapping(uint256 => Market) public markets;

    constructor() public Ownable() {}

    function openMarket(
        address _token0,
        address _token1,
        uint256 _expirationTimestamp,
        uint256 _timeToOptionExecution,
        uint8 _optionFee,
        address _uniswapMarket,
        string calldata _marketName,
        string calldata _marketSymbol
    ) external onlyOwner {
        uint256 token1Price = UniswapPriceOracle.getPrice(_uniswapMarket);
        BubbaFinanceMarket _market = new BubbaFinanceMarket(
            _token0,
            _token1,
            _expirationTimestamp,
            _timeToOptionExecution,
            token1Price,
            _optionFee,
            _marketName,
            _marketSymbol
        );
        markets[marketsCounter.current()] = Market(
            address(_market),
            _expirationTimestamp
        );
        emit MarketCreation(_token0, _token1, address(_market));
    }

    // Getters

    function getMarketsCount() public override view returns (uint256) {
        return marketsCounter.current();
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
