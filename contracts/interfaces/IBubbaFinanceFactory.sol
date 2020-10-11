pragma solidity ^0.6.2;

interface IBubbaFinanceFactory {
    event MarketCreation(
        address indexed token0,
        address indexed token1,
        address market
    );

    struct Market {
        address market;
        uint256 expirationTimestamp;
    }

    function getMarketsCount() external view returns (uint256);

    // Constants getters

    function getFeesCommunityAllocation() public view returns (uint8);

    function getFeesDevfundAllocation() public view returns (uint8);

    function getFeesLiquidityProvidersAllocation() public view returns (uint8);
}
