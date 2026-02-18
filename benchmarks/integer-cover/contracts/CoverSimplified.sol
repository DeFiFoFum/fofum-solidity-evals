// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Cover Protocol - Infinite Mint Bug
 * @notice Simplified version of the $4M exploit
 * 
 * ROOT CAUSE: The Blacksmith (farming) contract had a reward
 * calculation that could be exploited. Attacker could claim
 * rewards without the claimed amount being properly deducted
 * from future calculations.
 */

interface ICoverToken {
    function mint(address to, uint256 amount) external;
}

contract VulnerableBlacksmith {
    ICoverToken public coverToken;
    
    mapping(address => uint256) public deposited;
    mapping(address => uint256) public rewardDebt;
    
    uint256 public totalDeposited;
    uint256 public accRewardPerShare;
    uint256 public constant PRECISION = 1e18;
    
    constructor(address _cover) {
        coverToken = ICoverToken(_cover);
    }
    
    function deposit(uint256 amount) external {
        _updatePool();
        
        if (deposited[msg.sender] > 0) {
            uint256 pending = deposited[msg.sender] * accRewardPerShare / PRECISION - rewardDebt[msg.sender];
            if (pending > 0) {
                coverToken.mint(msg.sender, pending);
            }
        }
        
        deposited[msg.sender] += amount;
        totalDeposited += amount;
        rewardDebt[msg.sender] = deposited[msg.sender] * accRewardPerShare / PRECISION;
    }
    
    /**
     * @notice VULNERABLE: Claim that doesn't update rewardDebt properly
     */
    function claimVulnerable() external {
        _updatePool();
        
        uint256 pending = deposited[msg.sender] * accRewardPerShare / PRECISION - rewardDebt[msg.sender];
        
        if (pending > 0) {
            coverToken.mint(msg.sender, pending);
            // BUG: rewardDebt not updated!
            // Attacker can call again and get same rewards
        }
    }
    
    /**
     * @notice FIXED: Update reward debt after claim
     */
    function claimFixed() external {
        _updatePool();
        
        uint256 pending = deposited[msg.sender] * accRewardPerShare / PRECISION - rewardDebt[msg.sender];
        
        if (pending > 0) {
            // FIXED: Update debt BEFORE minting
            rewardDebt[msg.sender] = deposited[msg.sender] * accRewardPerShare / PRECISION;
            coverToken.mint(msg.sender, pending);
        }
    }
    
    function _updatePool() internal {
        if (totalDeposited == 0) return;
        
        // Add rewards (simplified - would come from protocol revenue)
        uint256 newRewards = 100e18;
        accRewardPerShare += newRewards * PRECISION / totalDeposited;
    }
}

/**
 * @notice Attack flow:
 * 1. Deposit some tokens
 * 2. Call claimVulnerable() - get rewards
 * 3. Call claimVulnerable() again - get SAME rewards again
 * 4. Repeat until all COVER minted
 */
