pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";

import "./interfaces/IBubbaFinanceGovernance.sol";

contract BubbaFinanceGovernance is IBubbaFinanceGovernance, ERC20 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint8 constant REQUIRED_SUPPLY_PERCENTAGE_TO_PROPOSE = 10;

    uint256 activeVotedProposal;

    Counters.Counter private proposalsCounter;
    mapping(uint256 => Proposal) public proposals;

    constructor(string memory _name, string memory _symbol)
        public
        ERC20(_name, _symbol)
    {}

    function propose(
        address _txDestination,
        uint256 _txValue,
        bytes calldata _txData
    ) external {
        require(
            balanceOf(_msgSender()) >=
                totalSupply().div(100).mul(
                    REQUIRED_SUPPLY_PERCENTAGE_TO_PROPOSE
                ),
            "BubbaFinanceGovernance: Insufficient governance tokens in order to create proposals"
        );

        proposals[proposalsCounter.current()] = Proposal({
            proposedBy: _msgSender(),
            votes: 0,
            txn: Transaction(_txDestination, _txValue, _txData, false)
        });

        emit NewProposal(proposalsCounter.current());
        proposalsCounter.increment();
    }

    // Internals

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(
            amount > proposals[activeVotedProposal].lockedVoters[from] &&
                block.timestamp < proposals[activeVotedProposal].votingExpires,
            "BubbaFinanceGovernance: Unable to transfer used votes"
        );
    }

    function executeProposal(uint256 proposalId) internal {
        Transaction storage txn = proposals[proposalId].txn;
        txn.executed = true;
        if (
            external_call(txn.destination, txn.value, txn.data.length, txn.data)
        ) emit ProposalExecution(proposalId);
        else {
            emit ProposalExecutionFailed(transactionId);
            txn.executed = false;
        }
    }

    function external_call(
        address destination,
        uint256 value,
        uint256 dataLength,
        bytes memory data
    ) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40) // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas, 34710), // 34710 is the value that solidity is currently emitting
                // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                d,
                dataLength, // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0 // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }
}
