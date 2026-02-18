// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Build Finance - Hostile Governance Takeover
 * @notice DAO treasury taken over via low quorum
 * 
 * ROOT CAUSE: 
 * 1. Quorum was low (could be met with small % of supply)
 * 2. No minimum voting period enforcement
 * 3. No timelock on execution
 * 4. Single proposal could grant arbitrary permissions
 */

contract VulnerableBuildDAO {
    struct Proposal {
        address proposer;
        address target;
        bytes data;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 endBlock;
        bool executed;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    
    mapping(address => uint256) public votingPower;
    uint256 public totalVotingPower;
    
    // VULNERABLE: Very low quorum (can be achieved by whale)
    uint256 public quorum = 1000e18; // Only 1000 tokens needed
    uint256 public constant VOTING_PERIOD = 100; // blocks
    
    address public treasury;
    
    constructor(address _treasury) {
        treasury = _treasury;
    }
    
    function setVotingPower(address user, uint256 power) external {
        totalVotingPower = totalVotingPower - votingPower[user] + power;
        votingPower[user] = power;
    }
    
    function propose(address target, bytes calldata data) external returns (uint256) {
        // BUG: No minimum voting power to propose
        // BUG: No check if target is safe
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            target: target,
            data: data,
            forVotes: 0,
            againstVotes: 0,
            endBlock: block.number + VOTING_PERIOD,
            executed: false
        });
        
        return proposalCount;
    }
    
    function vote(uint256 proposalId, bool support) external {
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.number <= proposals[proposalId].endBlock, "Voting ended");
        
        uint256 power = votingPower[msg.sender];
        require(power > 0, "No voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].forVotes += power;
        } else {
            proposals[proposalId].againstVotes += power;
        }
    }
    
    /**
     * @notice VULNERABLE: Execute immediately after voting ends
     */
    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        
        require(!p.executed, "Already executed");
        require(block.number > p.endBlock, "Voting not ended");
        require(p.forVotes >= quorum, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Not passed");
        
        // BUG: No timelock for execution
        // BUG: No validation of target/data
        p.executed = true;
        
        (bool success,) = p.target.call(p.data);
        require(success, "Execution failed");
    }
    
    /**
     * @notice Attack scenario:
     * 1. Acquire 1000+ BUILD tokens
     * 2. Create proposal: transfer treasury to attacker
     * 3. Vote for own proposal
     * 4. Wait 100 blocks
     * 5. Execute and drain treasury
     */
}
