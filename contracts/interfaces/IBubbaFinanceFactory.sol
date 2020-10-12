pragma solidity ^0.6.2;

interface IBubbaFinanceFactory {
    event MarketCreation(
        address indexed token0,
        address indexed token1,
        address market,
        uint256 marketId
    );

    event MarketClosed(uint256 marketId);

    struct Market {
        address market;
        uint256 expirationTimestamp;
    }

    function getMarketsCount() external view returns (uint256);

    // Constants getters

    function getFeesCommunityAllocation() external view returns (uint8);

    function getFeesDevfundAllocation() external view returns (uint8);

    function getFeesLiquidityProvidersAllocation()
        external
        view
        returns (uint8);
}
