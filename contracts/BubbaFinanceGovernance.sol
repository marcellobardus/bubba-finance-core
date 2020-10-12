pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BubbaFinanceGovernance is ERC20 {
    using SafeMath for uint256;

    constructor(string memory _name, string memory _symbol)
        public
        ERC20(_name, _symbol)
    {}
}
