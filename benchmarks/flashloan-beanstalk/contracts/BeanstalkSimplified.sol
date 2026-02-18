// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Beanstalk Governance - Flash Loan Attack
 * @notice Simplified version of the $182M exploit
 * 
 * ROOT CAUSE: Governance allowed immediate execution if quorum met (emergencyCommit).
 * No timelock, no snapshot-based voting. Attacker could:
 * 1. Flash loan BEAN + LP tokens
 * 2. Deposit to get voting power
 * 3. Create malicious proposal
 * 4. Vote with flash loaned power
 * 5. Execute immediately (emergency threshold)
 * 6. Drain funds
 * 7. Repay flash loan
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableBeanstalkGovernance {
    IERC20 public stalk; // Governance token
    
    struct Proposal {
        address proposer;
        address[] targets;
        bytes[] calldatas;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startBlock;
        bool executed;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    
    uint256 public constant QUORUM = 50e18; // 50% of votes needed
    uint256 public constant EMERGENCY_THRESHOLD = 67e18; // 67% for instant execution
    
    address public treasury;
    
    constructor(address _stalk, address _treasury) {
        stalk = IERC20(_stalk);
        treasury = _treasury;
    }
    
    /**
     * @notice Get voting power - VULNERABLE: uses current balance
     * @dev Should use snapshot-based voting (getPastVotes)
     */
    function getVotingPower(address account) public view returns (uint256) {
        // BUG: Current balance, not historical - flashloanable!
        return stalk.balanceOf(account);
    }
    
    function propose(
        address[] calldata targets,
        bytes[] calldata calldatas
    ) external returns (uint256) {
        require(getVotingPower(msg.sender) > 0, "No voting power");
        
        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            targets: targets,
            calldatas: calldatas,
            forVotes: 0,
            againstVotes: 0,
            startBlock: block.number,
            executed: false
        });
        
        return proposalCount;
    }
    
    /**
     * @notice VULNERABLE: No delay between voting and execution
     */
    function vote(uint256 proposalId, bool support) external {
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        // BUG: Uses current balance (flashloanable)
        uint256 votes = getVotingPower(msg.sender);
        require(votes > 0, "No voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].forVotes += votes;
        } else {
            proposals[proposalId].againstVotes += votes;
        }
    }
    
    /**
     * @notice VULNERABLE: Emergency execution with no timelock
     */
    function emergencyCommit(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        
        uint256 totalVotes = p.forVotes + p.againstVotes;
        uint256 forPercentage = p.forVotes * 100 / totalVotes;
        
        // BUG: If threshold met, execute IMMEDIATELY - no timelock!
        require(forPercentage >= EMERGENCY_THRESHOLD, "Threshold not met");
        
        p.executed = true;
        
        // Execute all proposal actions
        for (uint256 i = 0; i < p.targets.length; i++) {
            (bool success,) = p.targets[i].call(p.calldatas[i]);
            require(success, "Execution failed");
        }
    }
    
    /**
     * @notice FIXED: Require timelock and snapshot-based voting
     */
    function commitWithTimelock(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(block.number >= p.startBlock + 17280, "Timelock not passed"); // ~3 days
        
        uint256 totalVotes = p.forVotes + p.againstVotes;
        require(p.forVotes * 100 / totalVotes >= QUORUM, "Quorum not met");
        
        p.executed = true;
        
        for (uint256 i = 0; i < p.targets.length; i++) {
            (bool success,) = p.targets[i].call(p.calldatas[i]);
            require(success, "Execution failed");
        }
    }
}
