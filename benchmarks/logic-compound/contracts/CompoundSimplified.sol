// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Compound - Reward Distribution Bug
 * @notice Simplified version of the $80M+ exploit
 * 
 * ROOT CAUSE: Governance proposal updated reward distribution logic
 * but didn't properly handle existing accrued rewards. Users who
 * had rewards from old system could claim MORE than intended under
 * new system due to state inconsistency.
 * 
 * LESSON: State migration in upgrades is extremely dangerous.
 * All state relationships must remain consistent.
 */

contract VulnerableCompoundRewards {
    // User reward accounting
    mapping(address => uint256) public compAccrued;
    mapping(address => uint256) public lastRewardBlock;
    mapping(address => uint256) public suppliedAmount;
    
    // Global reward parameters
    uint256 public rewardPerBlock;
    uint256 public totalSupplied;
    
    // COMP token
    address public compToken;
    
    constructor(address _comp) {
        compToken = _comp;
        rewardPerBlock = 1e18; // Initial rate
    }
    
    /**
     * @notice Supply assets to earn COMP
     */
    function supply(uint256 amount) external {
        _accrueRewards(msg.sender);
        suppliedAmount[msg.sender] += amount;
        totalSupplied += amount;
    }
    
    /**
     * @notice Accrue pending rewards
     */
    function _accrueRewards(address user) internal {
        if (lastRewardBlock[user] == 0) {
            lastRewardBlock[user] = block.number;
            return;
        }
        
        uint256 blocks = block.number - lastRewardBlock[user];
        uint256 userShare = suppliedAmount[user] * 1e18 / totalSupplied;
        uint256 newRewards = blocks * rewardPerBlock * userShare / 1e18;
        
        compAccrued[user] += newRewards;
        lastRewardBlock[user] = block.number;
    }
    
    /**
     * @notice VULNERABLE: Upgrade that changes reward rate
     * @dev This doesn't handle existing accrued amounts properly
     */
    function upgradeRewardRate(uint256 newRate) external {
        // BUG: Doesn't settle existing rewards before changing rate
        // Users with old compAccrued values now calculated against new rate
        rewardPerBlock = newRate;
        
        // MISSING: Should force-settle all users or use a snapshot
    }
    
    /**
     * @notice Claim rewards - BUG after upgrade
     */
    function claimRewards() external {
        _accrueRewards(msg.sender);
        
        uint256 amount = compAccrued[msg.sender];
        require(amount > 0, "No rewards");
        
        // BUG: compAccrued may include incorrectly calculated values
        // from the rate transition
        compAccrued[msg.sender] = 0;
        
        // Transfer COMP (simplified)
        // IERC20(compToken).transfer(msg.sender, amount);
    }
    
    /**
     * @notice FIXED: Proper upgrade with state migration
     */
    function upgradeRewardRateFixed(uint256 newRate) external {
        // Option 1: Snapshot and reset
        // Store all current accruals at a snapshot
        // Apply new rate only to future blocks
        
        // Option 2: Batch settle
        // Force-accrue rewards for all users before rate change
        
        // The key: No user should gain/lose from the rate transition
        // State before = State after (for same action)
    }
}
