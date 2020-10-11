pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "./interfaces/IBubbaMarketToken.sol";

contract BubbaMarketToken is IBubbaMarketToken, Ownable, ERC20 {
    constructor(string memory _name, string memory _symbol)
        public
        Ownable()
        ERC20(_name, _symbol)
    {}

    function mint(address _beneficiary, uint256 _amount) external onlyOwner {
        _mint(_beneficiary, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyOwner {
        _burn(_account, _amount);
    }
}
