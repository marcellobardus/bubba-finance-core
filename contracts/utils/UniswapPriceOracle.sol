pragma solidity ^0.6.2;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

library UniswapPriceOracle {
    using SafeMath for uint256;

    function getPrice(address pair) public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, uint32 _) = IUniswapV2Pair(pair)
            .getReserves();
        return uint256(reserve0).div(uint256(reserve1));
    }
}
