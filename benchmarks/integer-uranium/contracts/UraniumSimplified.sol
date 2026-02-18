// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Uranium Finance - Fee Calculation Mismatch
 * @notice Simplified version of the $50M exploit
 * 
 * ROOT CAUSE: During upgrade, fee basis changed from 1000 to 10000
 * but not all calculations were updated consistently.
 * 
 * Before: fee = amount * 3 / 1000 (0.3%)
 * After (buggy): amount calculation used 10000, fee used 1000
 * Result: Users could extract more than they should
 */

contract VulnerableUraniumPair {
    uint256 public reserve0;
    uint256 public reserve1;
    
    // Fee parameters - INCONSISTENT!
    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR_SWAP = 10000;  // Updated
    uint256 public constant FEE_DENOMINATOR_CALC = 1000;   // Not updated!
    
    constructor() {
        reserve0 = 1000000e18;
        reserve1 = 1000000e18;
    }
    
    /**
     * @notice VULNERABLE swap function with inconsistent fee basis
     */
    function swap(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out) external {
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output");
        
        // Calculate new reserves
        uint256 balance0 = reserve0 + amount0In - amount0Out;
        uint256 balance1 = reserve1 + amount1In - amount1Out;
        
        // BUG: Inconsistent fee calculation
        // Uses 10000 basis for one part, 1000 for another
        uint256 balance0Adjusted = balance0 * FEE_DENOMINATOR_SWAP - amount0In * FEE_NUMERATOR;
        uint256 balance1Adjusted = balance1 * FEE_DENOMINATOR_SWAP - amount1In * FEE_NUMERATOR;
        
        // This check passes when it shouldn't due to basis mismatch
        // Attacker can extract more value than they put in
        require(
            balance0Adjusted * balance1Adjusted >= 
            reserve0 * reserve1 * (FEE_DENOMINATOR_CALC ** 2),  // BUG: Uses wrong basis!
            "K invariant failed"
        );
        
        reserve0 = balance0;
        reserve1 = balance1;
    }
    
    /**
     * @notice FIXED: Consistent fee basis
     */
    function swapFixed(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out) external {
        uint256 balance0 = reserve0 + amount0In - amount0Out;
        uint256 balance1 = reserve1 + amount1In - amount1Out;
        
        // FIXED: Use same basis (10000) everywhere
        uint256 balance0Adjusted = balance0 * 10000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 10000 - amount1In * 3;
        
        require(
            balance0Adjusted * balance1Adjusted >= 
            reserve0 * reserve1 * (10000 ** 2),  // Same basis
            "K invariant failed"
        );
        
        reserve0 = balance0;
        reserve1 = balance1;
    }
}
