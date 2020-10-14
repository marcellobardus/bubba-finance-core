pragma solidity ^0.6.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";

import "./interfaces/IBubbaFinanceGovernance.sol";

contract BubbaFinanceGovernance is IBubbaFinanceGovernance, ERC20 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint8 constant REQUIRED_SUPPLY_PERCENTAGE_TO_PROPOSE = 10;
    uint8 constant REQUIRED_MAJORITY = 51;

    uint256 activeVotedProposal;

    Counters.Counter private proposalsCounter;
    mapping(uint256 => Proposal) proposals;

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

        Proposal memory proposal;

        proposal.proposedBy = _msgSender();
        proposal.txn = Transaction(_txDestination, _txValue, _txData, false);

        proposals[proposalsCounter.current()] = proposal;

        emit NewProposal(proposalsCounter.current());
        proposalsCounter.increment();
    }

    function vote(uint256 _votes) external {
        (bool votingSuccess, bool execution) = _vote(_msgSender(), _votes);
        require(votingSuccess, "BubbaFinanceGovernance: voting failed");
    }

    // Internals

    function _vote(address _voter, uint256 _votes)
        internal
        returns (bool, bool)
    {
        if (
            balanceOf(_voter).sub(
                proposals[activeVotedProposal].lockedVoters[_voter]
            ) < _votes
        ) return (false, false);

        proposals[activeVotedProposal].lockedVoters[_voter].add(_votes);

        proposals[activeVotedProposal].votes.add(_votes);

        emit Vote(activeVotedProposal, _voter, _votes);

        if (
            proposals[activeVotedProposal].votes >=
            totalSupply().div(100).mul(REQUIRED_MAJORITY)
        ) {
            bool executionResult = executeProposal(activeVotedProposal);
            return (true, executionResult);
        }

        return (true, false);
    }

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

    function executeProposal(uint256 proposalId) internal returns (bool) {
        Transaction storage txn = proposals[proposalId].txn;
        txn.executed = true;
        if (
            external_call(txn.destination, txn.value, txn.data.length, txn.data)
        ) emit ProposalExecution(proposalId);
        else {
            emit ProposalExecutionFailed(proposalId);
            txn.executed = false;
        }

        return txn.executed;
    }

    function external_call(
        address destination,
        uint256 value,
        uint256 dataLength,
        bytes memory data
    ) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)
            let d := add(data, 32)
            let g := sub(gas(), 34710)
            result := call(g, destination, value, d, dataLength, x, 0)
        }
        return result;
    }
}
