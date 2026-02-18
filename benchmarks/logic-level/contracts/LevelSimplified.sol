// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Level Finance - Referral Double Claim
 * @notice Simplified version of the $1.1M exploit
 * 
 * ROOT CAUSE: 
 * 1. Users could self-refer (be their own referrer)
 * 2. Reward claim didn't reset/update state properly
 * 3. Same reward could be claimed multiple times
 */

contract VulnerableLevelReferral {
    mapping(address => address) public referrer;
    mapping(address => uint256) public referralRewards;
    mapping(address => uint256) public tradingVolume;
    
    uint256 public constant REFERRAL_RATE = 10; // 10% of fees
    
    /**
     * @notice Set referrer - VULNERABLE: allows self-referral
     */
    function setReferrer(address _referrer) external {
        // BUG: No check preventing self-referral
        // BUG: No check if referrer already set
        referrer[msg.sender] = _referrer;
    }
    
    /**
     * @notice Record trading activity and accrue referral rewards
     */
    function recordTrade(address trader, uint256 volume, uint256 fee) external {
        tradingVolume[trader] += volume;
        
        address ref = referrer[trader];
        if (ref != address(0)) {
            // Accrue referral reward
            uint256 reward = fee * REFERRAL_RATE / 100;
            referralRewards[ref] += reward;
        }
    }
    
    /**
     * @notice Claim referral rewards - VULNERABLE
     */
    function claimReferralRewards() external {
        uint256 amount = referralRewards[msg.sender];
        require(amount > 0, "No rewards");
        
        // BUG: Transfer before state update
        payable(msg.sender).transfer(amount);
        
        // BUG: This should happen BEFORE transfer
        // AND should use a pattern that prevents double-claim
        referralRewards[msg.sender] = 0;
    }
    
    /**
     * @notice VULNERABLE: Combined self-referral + double claim
     * Attack flow:
     * 1. Call setReferrer(self)
     * 2. Trade (recordTrade gets called)
     * 3. Earn referral rewards from own trading
     * 4. Claim rewards
     * 5. If reentrancy possible, claim again
     */
    
    /**
     * @notice FIXED version
     */
    function setReferrerFixed(address _referrer) external {
        require(_referrer != msg.sender, "Cannot self-refer");
        require(referrer[msg.sender] == address(0), "Referrer already set");
        require(_referrer != address(0), "Invalid referrer");
        referrer[msg.sender] = _referrer;
    }
    
    function claimReferralRewardsFixed() external {
        uint256 amount = referralRewards[msg.sender];
        require(amount > 0, "No rewards");
        
        // FIXED: State update BEFORE transfer (CEI)
        referralRewards[msg.sender] = 0;
        
        payable(msg.sender).transfer(amount);
    }
    
    receive() external payable {}
}
