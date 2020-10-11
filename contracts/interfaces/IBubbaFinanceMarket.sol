pragma solidity ^0.6.2;

interface IBubbaFinanceMarket {
    event LiquidityAdded(address indexed provider, uint256 amount);
    event LiquidityWithdrawn(
        address indexed remover,
        uint256 amount,
        uint256 penalty
    );
    event OptionPurchase(address indexed purchaser, uint256 size, uint256 fee);

    event OptionExecuted(address indexed executor, uint256 value);

    struct Option {
        uint256 size;
        uint256 fee;
    }
}
