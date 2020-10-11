pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBubbaFinanceMarket.sol";
import "./interfaces/IBubbaFinanceFactory.sol";

import "./BubbaMarketToken.sol";

contract BubbaFinanceMarket is IBubbaFinanceMarket, Context {
    using SafeMath for uint256;

    IERC20 private token0;
    IERC20 private token1;

    BubbaMarketToken private liquidityToken;
    BubbaMarketToken private optionToken;

    IBubbaFinanceFactory private factory;

    uint256 marketExpirationTimestamp;
    uint256 timeToOptionExectution;

    uint256 public liquidityPoolSize;

    uint256 public feesPoolSize;

    uint256 public realizedOptionsValue;

    uint256 openingToken1Price;

    // Defined as promil
    uint8 optionFee;

    constructor(
        address _token0,
        address _token1,
        uint256 _expirationTimestamp,
        uint256 _timeToOptionExecution,
        uint256 _openingToken1Price,
        uint8 _optionFee,
        string memory _marketName,
        string memory _marketSymbol
    ) public {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        marketExpirationTimestamp = _expirationTimestamp;
        timeToOptionExectution = _timeToOptionExecution;
        optionFee = _optionFee;
        openingToken1Price = _openingToken1Price;

        factory = IBubbaFinanceFactory(msg.sender);

        optionToken = new BubbaMarketToken(
            string(abi.encodePacked("Option ", _marketName)),
            string(abi.encodePacked("OPT:", _marketSymbol))
        );

        liquidityToken = new BubbaMarketToken(
            string(abi.encodePacked("Liquidity ", _marketName)),
            string(abi.encodePacked("LIQ:", _marketSymbol))
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

        liquidityToken.mint(_msgSender(), _amount);

        liquidityPoolSize.add(_amount);

        emit LiquidityAdded(_msgSender(), _amount);
    }

    function claimInterests(uint256 _value) external {
        require(
            block.timestamp >=
                marketExpirationTimestamp.add(timeToOptionExectution),
            "BubbaFinanceMarket: Options can still be realized"
        );

        require(
            liquidityToken.balanceOf(_msgSender()) >= _value,
            "BubbaFinanceMarket: Insufficient balance"
        );

        uint256 duedUnsoldLiquidityAsset = token1
            .balanceOf(address(this))
            .div(liquidityToken.totalSupply())
            .mul(liquidityToken.balanceOf(_msgSender()));

        require(
            token1.transfer(_msgSender(), duedUnsoldLiquidityAsset),
            "BubbaFinanceMarket: Transfer failed"
        );

        uint256 duedOptionBackAsset = token0
            .balanceOf(address(this))
            .div(liquidityToken.totalSupply())
            .mul(liquidityToken.balanceOf(_msgSender()));

        uint256 duedInterests = feesPoolSize
            .div(liquidityToken.totalSupply())
            .mul(liquidityToken.balanceOf(_msgSender()))
            .div(100)
            .mul(uint256(factory.getFeesLiquidityProvidersAllocation()));

        require(
            token0.transfer(
                _msgSender(),
                duedOptionBackAsset.add(feesPoolSize)
            ),
            "BubbaFinanceMarket: Transfer failed"
        );

        liquidityToken.burn(_msgSender(), _value);

        emit InterestsClaimed(
            _msgSender(),
            duedUnsoldLiquidityAsset,
            duedOptionBackAsset.add(duedInterests)
        );
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

        optionToken.mint(_msgSender(), _value);

        emit OptionPurchase(_msgSender(), _value, fee);
    }

    function realizeOption(uint256 _value) external {
        require(
            block.timestamp >= marketExpirationTimestamp,
            "BubbaFinanceMarket: Market still open"
        );

        require(
            block.timestamp <=
                marketExpirationTimestamp.add(timeToOptionExectution),
            "BubbaFinanceMarket: Execution time expired"
        );

        require(
            optionToken.balanceOf(_msgSender()) >= _value,
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

        optionToken.burn(_msgSender(), _value.sub(missingLiquidity));

        realizedOptionsValue.add(_value.sub(missingLiquidity));

        emit OptionExecuted(_msgSender(), _value.sub(missingLiquidity));
    }

    function closeMarket()
        external
        returns (
            bool _success,
            uint256 _communityWithdrawal,
            uint256 _devFundWithdrawal
        )
    {
        require(
            block.timestamp >=
                marketExpirationTimestamp.add(timeToOptionExectution),
            "BubbaFinanceMarket: Options can still be realized"
        );

        require(
            msg.sender == address(factory),
            "BubbaFinanceMarket: Unauthorized"
        );

        _communityWithdrawal = feesPoolSize
            .div(liquidityToken.totalSupply())
            .mul(liquidityToken.balanceOf(_msgSender()))
            .div(100)
            .mul(uint256(factory.getFeesCommunityAllocation()));

        _devFundWithdrawal = feesPoolSize
            .div(liquidityToken.totalSupply())
            .mul(liquidityToken.balanceOf(_msgSender()))
            .div(100)
            .mul(uint256(factory.getFeesDevfundAllocation()));

        _success = token0.transfer(
            msg.sender,
            _communityWithdrawal.add(_devFundWithdrawal)
        );

        emit MarketClosed(_communityWithdrawal, _devFundWithdrawal);
    }
}
