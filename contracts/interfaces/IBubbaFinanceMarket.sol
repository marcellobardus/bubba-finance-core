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

    // State changers

    function addLiquidity(uint256 _amount) external;

    function claimInterests(uint256 _value) external;

    function purchaseOption(uint256 _value) external;

    function realizeOption(uint256 _value) external;

    function closeMarket()
        external
        returns (
            bool _success,
            uint256 _communityWithdrawal,
            uint256 _devFundWithdrawal
        );

    // Getters

    function getToken0Address() external view returns (address _token0);

    function getToken1Address() external view returns (address _token1);
}
