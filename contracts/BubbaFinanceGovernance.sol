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

    uint256 _activeVotedProposal;

    Counters.Counter private _proposalsCounter;
    mapping(uint256 => Proposal) _proposals;

    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {}

    function propose(
        address txDestination,
        uint256 txValue,
        bytes calldata txData
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
        proposal.txn = Transaction(txDestination, txValue, txData, false);

        _proposals[_proposalsCounter.current()] = proposal;

        emit NewProposal(_proposalsCounter.current());
        _proposalsCounter.increment();
    }

    function vote(uint256 votes) external {
        (bool votingSuccess, bool execution) = _vote(_msgSender(), votes);
        require(votingSuccess, "BubbaFinanceGovernance: voting failed");
    }

    // Internals

    function _vote(address voter, uint256 votes) internal returns (bool, bool) {
        if (
            balanceOf(voter).sub(
                _proposals[_activeVotedProposal].lockedVoters[voter]
            ) < votes
        ) return (false, false);

        _proposals[_activeVotedProposal].lockedVoters[voter].add(votes);

        _proposals[_activeVotedProposal].votes.add(votes);

        emit Vote(_activeVotedProposal, voter, votes);

        if (
            _proposals[_activeVotedProposal].votes >=
            totalSupply().div(100).mul(REQUIRED_MAJORITY)
        ) {
            bool executionResult = executeProposal(_activeVotedProposal);
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
            amount > _proposals[_activeVotedProposal].lockedVoters[from] &&
                block.timestamp <
                _proposals[_activeVotedProposal].votingExpires,
            "BubbaFinanceGovernance: Unable to transfer used votes"
        );
    }

    function executeProposal(uint256 proposalId) internal returns (bool) {
        Transaction storage txn = _proposals[proposalId].txn;
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
