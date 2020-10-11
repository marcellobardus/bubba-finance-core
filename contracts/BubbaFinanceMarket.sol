pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBubbaFinanceMarket.sol";

import "./BubbaMarketToken.sol";

/**
TODO 
1. Disable liquidity withdrawals before market expiration.
2. Instead of saving data regarding liquidity and option size, mint tokens.
 */

contract BubbaFinanceMarket is IBubbaFinanceMarket, Context {
    using SafeMath for uint256;

    IERC20 public token0;
    IERC20 public token1;

    uint256 marketExpirationTimestamp;

    mapping(address => uint256) public providedLiquidity;
    uint256 public liquidityPoolSize;

    uint256 public penaltiesPoolSize;

    uint256 public feesPoolSize;

    uint256 public realizedOptionsValue;

    mapping(address => uint256) purchasedOptionValue;

    uint256 openingToken1Price;

    // Defined as promil
    uint8 optionFee;

    constructor(
        address _token0,
        address _token1,
        uint256 _expirationTimestamp,
        uint256 _openingToken1Price,
        uint8 _optionFee,
        string memory _optionTokenName,
        string memory _optionTokenSymbol,
        string memory _liquidityTokenName,
        string memory _liquidityTokenSymbol
    ) public {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        marketExpirationTimestamp = _expirationTimestamp;
        optionFee = _optionFee;
        openingToken1Price = _openingToken1Price;

        BubbaMarketToken optionToken = new BubbaMarketToken(
            _optionTokenName,
            _optionTokenSymbol
        );
        BubbaMarketToken liquidityToken = new BubbaMarketToken(
            _liquidityTokenName,
            _liquidityTokenSymbol
        );
    }

    function addLiquidity(uint256 _amount) external {
        require(
            block.timestamp <= marketExpirationTimestamp,
            "BubbaFinanceMarket: Market expired"
        );

        require(
            token1.transferFrom(_msgSender(), address(this), _amount),
            "BubbaFinanceMarket: Transfer failed"
        );

        providedLiquidity[_msgSender()].add(_amount);

        liquidityPoolSize.add(_amount);

        emit LiquidityAdded(_msgSender(), _amount);
    }

    function withdrawLiquidity(uint256 _amount) external {
        require(
            providedLiquidity[_msgSender()] >= _amount,
            "BubbaFinanceMarket: Insufficient liquidity provided"
        );

        uint256 penalty;

        if (block.timestamp < marketExpirationTimestamp) {
            penalty.add(_amount.div(1000).mul(optionFee));
        }

        require(
            token1.transfer(_msgSender(), _amount.sub(penalty)),
            "BubbaFinanceMarket: Transfer failed"
        );

        providedLiquidity[_msgSender()].sub(_amount);
        liquidityPoolSize.sub(_amount);
        penaltiesPoolSize.add(penalty);

        emit LiquidityWithdrawn(_msgSender(), _amount, penalty);
    }

    function purchaseOption(uint256 _value) external {
        require(
            block.timestamp <= marketExpirationTimestamp,
            "BubbaFinanceMarket: Option purchase unavailable"
        );

        uint256 fee = _value.div(1000).mul(optionFee).mul(openingToken1Price);

        require(
            token0.transferFrom(_msgSender(), address(this), fee),
            "BubbaFinanceMarket: Transfer failed"
        );

        feesPoolSize.add(fee);
        purchasedOptionValue[_msgSender()].add(_value);

        emit OptionPurchase(_msgSender(), _value, fee);
    }

    function realizeOption(uint256 _value) external {
        require(
            block.timestamp >= marketExpirationTimestamp,
            "BubbaFinanceMarket: Market still open"
        );

        require(
            purchasedOptionValue[_msgSender()] >= _value,
            "BubbaFinanceMarket: Unsufficient option size"
        );

        uint256 missingLiquidity = (liquidityPoolSize > _value)
            ? 0
            : _value.sub(liquidityPoolSize);

        uint256 optionAssetsValue = (_value.sub(missingLiquidity)).mul(
            openingToken1Price
        );

        require(
            token0.transferFrom(_msgSender(), address(this), optionAssetsValue),
            "BubbaFinanceMarket: Transfer failed"
        );

        require(
            token1.transfer(_msgSender(), _value.sub(missingLiquidity)),
            "BubbaFinanceMarket: Transfer failed"
        );

        realizedOptionsValue.add(_value.sub(missingLiquidity));

        emit OptionExecuted(_msgSender(), _value.sub(missingLiquidity));
    }
}
