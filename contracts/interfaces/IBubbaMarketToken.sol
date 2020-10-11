pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface IBubbaMarketToken is IERC20 {
    function mint(address _beneficiary, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;
}
