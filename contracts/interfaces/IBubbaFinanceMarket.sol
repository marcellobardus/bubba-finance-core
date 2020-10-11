pragma solidity ^0.6.2;

interface IBubbaFinanceMarket {
    event LiquidityAdded(address indexed provider, uint256 amount);
    event OptionPurchase(address indexed purchaser, uint256 size, uint256 fee);
    event OptionExecuted(address indexed executor, uint256 value);
    event InterestsClaimed(
        address indexed claimer,
        uint256 claimedLiquidityAsset,
        uint256 claimedBackAsset
    );
    event MarketClosed(
        uint256 communityFundWithdrawal,
        uint256 devFundWithdrawal
    );

    struct Option {
        uint256 size;
        uint256 fee;
    }
}
