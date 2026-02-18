// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Harvest Finance - Flash Loan Oracle Manipulation
 * @notice Simplified version of the $34M exploit
 * 
 * ROOT CAUSE: Harvest valued deposits using Curve pool spot price.
 * Attacker could manipulate price via flash loan, deposit at inflated
 * value, restore price, and withdraw at profit.
 * 
 * Attack flow:
 * 1. Flash loan USDC
 * 2. Swap USDC→USDT on Curve (moves price)
 * 3. Deposit USDT to Harvest at manipulated (favorable) price
 * 4. Swap USDT→USDC on Curve (restores price)
 * 5. Withdraw from Harvest at normal price
 * 6. Repay flash loan with profit
 */

interface ICurvePool {
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableHarvestVault {
    IERC20 public usdt;
    ICurvePool public curvePool;
    
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalDeposits;
    
    constructor(address _usdt, address _curvePool) {
        usdt = IERC20(_usdt);
        curvePool = ICurvePool(_curvePool);
    }
    
    /**
     * @notice Get price from Curve - VULNERABLE to manipulation
     */
    function getPriceFromCurve() public view returns (uint256) {
        // BUG: Spot price - manipulatable in single transaction!
        // Returns how much USDC you get for 1 USDT
        return curvePool.get_dy(1, 0, 1e6); // USDT→USDC
    }
    
    /**
     * @notice VULNERABLE: Uses spot price for share calculation
     */
    function deposit(uint256 amount) external returns (uint256 sharesToMint) {
        usdt.transferFrom(msg.sender, address(this), amount);
        
        // BUG: Price can be manipulated before this call
        uint256 price = getPriceFromCurve();
        uint256 valueInUSDC = amount * price / 1e6;
        
        if (totalShares == 0) {
            sharesToMint = valueInUSDC;
        } else {
            sharesToMint = valueInUSDC * totalShares / totalDeposits;
        }
        
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalDeposits += valueInUSDC;
    }
    
    /**
     * @notice Withdraw - uses current price which may differ from deposit price
     */
    function withdraw(uint256 shareAmount) external returns (uint256 amountOut) {
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");
        
        uint256 price = getPriceFromCurve();
        
        // Calculate USDT amount for shares
        uint256 valueInUSDC = shareAmount * totalDeposits / totalShares;
        amountOut = valueInUSDC * 1e6 / price;
        
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalDeposits -= valueInUSDC;
        
        usdt.transfer(msg.sender, amountOut);
    }
    
    /**
     * @notice FIXED: Use TWAP oracle instead of spot price
     */
    function getPriceTWAP() public view returns (uint256) {
        // Would use Chainlink or Uniswap TWAP instead of spot
        // return chainlinkOracle.getPrice();
        return 1e6; // Placeholder
    }
}

/**
 * @notice Simplified Curve pool for demonstration
 */
contract SimpleCurvePool {
    uint256 public reserveUSDC = 100_000_000e6;
    uint256 public reserveUSDT = 100_000_000e6;
    
    // Returns output amount for swap
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256) {
        if (i == 0) { // USDC → USDT
            return dx * reserveUSDT / reserveUSDC;
        } else { // USDT → USDC  
            return dx * reserveUSDC / reserveUSDT;
        }
    }
    
    // Execute swap - changes reserves
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256 dy) {
        dy = this.get_dy(i, j, dx);
        require(dy >= min_dy, "Slippage");
        
        if (i == 0) {
            reserveUSDC += dx;
            reserveUSDT -= dy;
        } else {
            reserveUSDT += dx;
            reserveUSDC -= dy;
        }
    }
}
