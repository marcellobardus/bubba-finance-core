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

    function addLiquidity(uint256 amount) external;

    function withdrawLiquidity(uint256 amount) external;

    function claimInterests(uint256 value) external;

    function purchaseOption(uint256 value) external;

    function realizeOption(uint256 value) external;

    function closeMarket()
        external
        returns (
            bool,
            uint256,
            uint256
        );

    // Getters

    function getToken0Address() external view returns (address);

    function getToken1Address() external view returns (address);

    function getLiquidityToken() external view returns (address);

    function getOptionToken() external view returns (address);

    function getLiquidityPoolSize() external view returns (uint256);

    function getPurchasedOptionsValue() external view returns (uint256);

    function getRealizedOptionsValue() external view returns (uint256);

    function getFeesPoolSize() external view returns (uint256);
}
