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

    // Constants

    function getMarketsCount() external view returns (uint256);
}
