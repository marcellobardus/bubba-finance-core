pragma solidity ^0.6.2;

interface IBubbaFinanceGovernance {
    event NewProposal(uint256 proposalId);
    event ProposalExecution(uint256 proposalId);
    event ProposalExecutionFailed(uint256 proposalId);

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    struct Proposal {
        uint256 votingExpires;
        address proposedBy;
        uint256 votes;
        Transaction txn;
        mapping(address => uint256) lockedVoters;
    }
}
