// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Euler Finance - Simplified Vulnerable Code
 * @notice This is a simplified version showing the vulnerable pattern
 * @dev The actual Euler codebase is complex; this isolates the bug
 * 
 * ROOT CAUSE: donateToReserves() allows users to transfer their eTokens
 * to reserves, which increases their debt-to-collateral ratio WITHOUT
 * checking if the account becomes liquidatable. Combined with self-liquidation,
 * this allows extracting more value than deposited.
 */

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract EulerEToken {
    IERC20 public underlying;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public debt;
    uint256 public totalReserves;
    uint256 public totalSupply;
    
    uint256 constant COLLATERAL_FACTOR = 90; // 90%
    
    constructor(address _underlying) {
        underlying = IERC20(_underlying);
    }
    
    // Deposit underlying, receive eTokens
    function deposit(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }
    
    // Mint eTokens (borrow) - creates debt
    function mint(uint256 amount) external {
        // Check: can only mint up to collateral factor * balance
        uint256 maxBorrow = balanceOf[msg.sender] * COLLATERAL_FACTOR / 100;
        require(debt[msg.sender] + amount <= maxBorrow * 10, "Exceeds borrow limit");
        
        balanceOf[msg.sender] += amount;
        debt[msg.sender] += amount;
        totalSupply += amount;
    }
    
    // Repay debt
    function repay(uint256 amount) external {
        underlying.transferFrom(msg.sender, address(this), amount);
        debt[msg.sender] -= amount;
    }
    
    // VULNERABLE FUNCTION
    // Donates eTokens to reserves - reduces collateral WITHOUT health check
    function donateToReserves(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        totalReserves += amount;
        
        // BUG: No health check after donation!
        // User can make themselves liquidatable intentionally
        // _checkHealth(msg.sender); // THIS IS MISSING
    }
    
    // Withdraw underlying
    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        _checkHealth(msg.sender);
        
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        underlying.transfer(msg.sender, amount);
    }
    
    // Liquidate unhealthy position
    // VULNERABILITY: Self-liquidation is allowed
    function liquidate(address violator, uint256 repayAmount) external {
        require(!_isHealthy(violator), "Account is healthy");
        
        // Liquidator repays debt
        underlying.transferFrom(msg.sender, address(this), repayAmount);
        
        // Calculate collateral to seize (with bonus)
        uint256 seizeAmount = repayAmount * 110 / 100; // 10% liquidation bonus
        
        // BUG: No check if msg.sender == violator (self-liquidation)
        // This allows extracting the liquidation bonus from yourself
        
        debt[violator] -= repayAmount;
        balanceOf[violator] -= seizeAmount;
        balanceOf[msg.sender] += seizeAmount;
    }
    
    function _checkHealth(address account) internal view {
        require(_isHealthy(account), "Account unhealthy");
    }
    
    function _isHealthy(address account) internal view returns (bool) {
        if (debt[account] == 0) return true;
        uint256 collateralValue = balanceOf[account] * COLLATERAL_FACTOR / 100;
        return collateralValue >= debt[account];
    }
    
    function getHealthFactor(address account) external view returns (uint256) {
        if (debt[account] == 0) return type(uint256).max;
        return balanceOf[account] * COLLATERAL_FACTOR * 1e18 / (debt[account] * 100);
    }
}
