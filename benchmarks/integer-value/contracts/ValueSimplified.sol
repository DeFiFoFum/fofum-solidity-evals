// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Value DeFi - Precision Loss
 * @notice Simplified version of the $11M exploit
 * 
 * ROOT CAUSE: Division before multiplication caused precision loss.
 * Small deposits would round down to zero shares, but the assets
 * remained in the vault, inflating price for next depositor.
 */

contract VulnerableValueVault {
    uint256 public totalShares;
    uint256 public totalAssets;
    
    mapping(address => uint256) public shares;
    
    /**
     * @notice VULNERABLE: Division before multiplication
     */
    function deposit(uint256 assets) external returns (uint256 sharesToMint) {
        if (totalShares == 0) {
            sharesToMint = assets;
        } else {
            // BUG: Division before multiplication causes precision loss
            // If assets is small relative to totalAssets, this rounds to 0
            sharesToMint = assets / totalAssets * totalShares;
            // Example: assets=999, totalAssets=1000, totalShares=100
            // 999 / 1000 = 0 (integer division)
            // 0 * 100 = 0 shares
            // But 999 tokens still added to vault!
        }
        
        require(sharesToMint > 0, "Zero shares");  // But what if this check is missing?
        
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssets += assets;
    }
    
    /**
     * @notice VULNERABLE version without zero check
     */
    function depositVulnerable(uint256 assets) external returns (uint256 sharesToMint) {
        if (totalShares == 0) {
            sharesToMint = assets;
        } else {
            // Division first - precision loss!
            sharesToMint = assets / totalAssets * totalShares;
        }
        
        // BUG: No check for zero shares
        // Attacker gets 0 shares but vault gets their assets
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssets += assets;
    }
    
    function withdraw(uint256 shareAmount) external returns (uint256 assets) {
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");
        
        assets = shareAmount * totalAssets / totalShares;
        
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalAssets -= assets;
        
        // Transfer assets...
    }
    
    /**
     * @notice FIXED: Multiplication before division
     */
    function depositFixed(uint256 assets) external returns (uint256 sharesToMint) {
        if (totalShares == 0) {
            sharesToMint = assets;
        } else {
            // FIXED: Multiply first, then divide
            sharesToMint = assets * totalShares / totalAssets;
        }
        
        require(sharesToMint > 0, "Zero shares");
        
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalAssets += assets;
    }
}
