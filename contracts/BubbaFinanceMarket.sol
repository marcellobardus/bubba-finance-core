pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/GSN/Context.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBubbaFinanceMarket.sol";
import "./interfaces/IBubbaFinanceFactory.sol";

import "./BubbaMarketToken.sol";

contract BubbaFinanceMarket is IBubbaFinanceMarket, Context {
    using SafeMath for uint256;

    IERC20 private _token0;
    IERC20 private _token1;

    BubbaMarketToken private _liquidityToken;
    BubbaMarketToken private _optionToken;

    IBubbaFinanceFactory private _factory;

    uint256 public _marketExpirationTimestamp;
    uint256 public _timeToOptionExectution;

    uint256 public _liquidityPoolSize;

    uint256 public _feesPoolSize;

    uint256 public _purchasedOptionsValue;
    uint256 public _realizedOptionsValue;

    uint256 _openingToken1Price;

    // Defined as promil
    uint8 _optionFee;

    constructor(
        address token0,
        address token1,
        uint256 expirationTimestamp,
        uint256 timeToOptionExecution,
        uint256 openingToken1Price,
        uint8 optionFee,
        string memory marketName,
        string memory marketSymbol
    ) public {
        _token0 = IERC20(token0);
        _token1 = IERC20(token1);
        _marketExpirationTimestamp = expirationTimestamp;
        _timeToOptionExectution = timeToOptionExecution;
        _optionFee = optionFee;
        _openingToken1Price = openingToken1Price;

        _factory = IBubbaFinanceFactory(msg.sender);

        _optionToken = new BubbaMarketToken(
            string(abi.encodePacked("Option ", marketName)),
            string(abi.encodePacked("OPT:", marketSymbol))
        );

        _liquidityToken = new BubbaMarketToken(
            string(abi.encodePacked("Liquidity ", marketName)),
            string(abi.encodePacked("LIQ:", marketSymbol))
        );
    }

    function addLiquidity(uint256 value) external override {
        require(
            block.timestamp <= _marketExpirationTimestamp,
            "BubbaFinanceMarket: Market expired"
        );

        require(
            _token1.transferFrom(_msgSender(), address(this), value),
            "BubbaFinanceMarket: Transfer failed"
        );

        _liquidityToken.mint(_msgSender(), value);

        _liquidityPoolSize.add(value);

        emit LiquidityAdded(_msgSender(), value);
    }

    function withdrawLiquidity(uint256 value) external override {
        require(
            _purchasedOptionsValue == 0,
            "BubbaFinanceMarket: Market already started"
        );

        require(
            _liquidityToken.balanceOf(_msgSender()) >= value,
            "BubbaFinanceMarket: Insufficient balance"
        );

        uint256 duedUnsoldLiquidityAsset = _token1
            .balanceOf(address(this))
            .div(_liquidityToken.totalSupply())
            .mul(value);

        require(
            _token1.transfer(_msgSender(), duedUnsoldLiquidityAsset),
            "BubbaFinanceMarket: Transfer failed"
        );
    }

    function claimInterests(uint256 value) external override {
        require(
            block.timestamp >=
                _marketExpirationTimestamp.add(_timeToOptionExectution),
            "BubbaFinanceMarket: Options can still be realized"
        );

        require(
            _liquidityToken.balanceOf(_msgSender()) >= value,
            "BubbaFinanceMarket: Insufficient balance"
        );

        uint256 duedUnsoldLiquidityAsset = _token1
            .balanceOf(address(this))
            .div(_liquidityToken.totalSupply())
            .mul(value);

        require(
            _token1.transfer(_msgSender(), duedUnsoldLiquidityAsset),
            "BubbaFinanceMarket: Transfer failed"
        );

        uint256 duedOptionBackAsset = _token0
            .balanceOf(address(this))
            .div(_liquidityToken.totalSupply())
            .mul(value);

        uint256 duedInterests = _feesPoolSize
            .div(_liquidityToken.totalSupply())
            .mul(value)
            .div(100)
            .mul(uint256(_factory.getFeesLiquidityProvidersAllocation()));

        require(
            _token0.transfer(
                _msgSender(),
                duedOptionBackAsset.add(duedInterests)
            ),
            "BubbaFinanceMarket: Transfer failed"
        );

        _liquidityToken.burn(_msgSender(), value);

        emit InterestsClaimed(
            _msgSender(),
            duedUnsoldLiquidityAsset,
            duedOptionBackAsset.add(duedInterests)
        );
    }

    function purchaseOption(uint256 value) external override {
        require(
            block.timestamp <= _marketExpirationTimestamp,
            "BubbaFinanceMarket: Option purchase unavailable"
        );

        require(
            _liquidityPoolSize.sub(_purchasedOptionsValue) >= value,
            "BubbaFinanceMarket: Not enought liquidity"
        );

        uint256 fee = value.div(1000).mul(_optionFee).mul(_openingToken1Price);

        require(
            _token0.transferFrom(_msgSender(), address(this), fee),
            "BubbaFinanceMarket: Transfer failed"
        );

        _feesPoolSize.add(fee);

        _optionToken.mint(_msgSender(), value);

        _purchasedOptionsValue.add(value);

        emit OptionPurchase(_msgSender(), value, fee);
    }

    function realizeOption(uint256 value) external override {
        require(
            block.timestamp >= _marketExpirationTimestamp,
            "BubbaFinanceMarket: Market still open"
        );

        require(
            block.timestamp <=
                _marketExpirationTimestamp.add(_timeToOptionExectution),
            "BubbaFinanceMarket: Execution time expired"
        );

        require(
            _optionToken.balanceOf(_msgSender()) >= value,
            "BubbaFinanceMarket: Unsufficient option size"
        );

        uint256 missingLiquidity = (_liquidityPoolSize > value)
            ? 0
            : value.sub(_liquidityPoolSize);

        uint256 optionAssetsValue = (value.sub(missingLiquidity)).mul(
            _openingToken1Price
        );

        require(
            _token0.transferFrom(
                _msgSender(),
                address(this),
                optionAssetsValue
            ),
            "BubbaFinanceMarket: Transfer failed"
        );

        require(
            _token1.transfer(_msgSender(), value.sub(missingLiquidity)),
            "BubbaFinanceMarket: Transfer failed"
        );

        _optionToken.burn(_msgSender(), value.sub(missingLiquidity));

        _realizedOptionsValue.add(value.sub(missingLiquidity));

        emit OptionExecuted(_msgSender(), value.sub(missingLiquidity));
    }

    function closeMarket()
        external
        override
        returns (
            bool,
            uint256,
            uint256
        )
    {
        require(
            block.timestamp >=
                _marketExpirationTimestamp.add(_timeToOptionExectution),
            "BubbaFinanceMarket: Options can still be realized"
        );

        require(
            msg.sender == address(_factory),
            "BubbaFinanceMarket: Unauthorized"
        );

        uint256 communityWithdrawal = _feesPoolSize
            .div(_liquidityToken.totalSupply())
            .mul(_liquidityToken.balanceOf(_msgSender()))
            .div(100)
            .mul(uint256(_factory.getFeesCommunityAllocation()));

        uint256 devFundWithdrawal = _feesPoolSize
            .div(_liquidityToken.totalSupply())
            .mul(_liquidityToken.balanceOf(_msgSender()))
            .div(100)
            .mul(uint256(_factory.getFeesDevfundAllocation()));

        bool success = _token0.transfer(
            msg.sender,
            communityWithdrawal.add(devFundWithdrawal)
        );

        return (success, communityWithdrawal, devFundWithdrawal);

        emit MarketClosed(communityWithdrawal, devFundWithdrawal);
    }

    // Getters

    function getToken0Address() external override view returns (address) {
        return address(_token0);
    }

    function getToken1Address() external override view returns (address) {
        return address(_token1);
    }

    function getOptionToken() external override view returns (address) {
        return address(_optionToken);
    }

    function getLiquidityToken() external override view returns (address) {
        return address(_liquidityToken);
    }

    function getLiquidityPoolSize() external override view returns (uint256) {
        return _liquidityPoolSize;
    }

    function getPurchasedOptionsValue()
        external
        override
        view
        returns (uint256)
    {
        return _purchasedOptionsValue;
    }

    function getRealizedOptionsValue()
        external
        override
        view
        returns (uint256)
    {
        return _realizedOptionsValue;
    }

    function getFeesPoolSize() external override view returns (uint256) {
        return _feesPoolSize;
    }
}
