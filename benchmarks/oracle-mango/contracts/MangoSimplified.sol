// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Mango Markets - Self-Referential Oracle
 * @notice Simplified version of the $116M exploit (originally on Solana)
 * 
 * ROOT CAUSE: Mango used its own perp market price as oracle for
 * collateral valuation. Attacker could:
 * 1. Open large long position on MNGO-PERP
 * 2. Pump MNGO-PERP price on Mango itself (thin liquidity)
 * 3. Collateral value (based on MNGO-PERP price) increases
 * 4. Borrow all available assets against inflated collateral
 * 5. Let position liquidate - borrowed more than collateral worth
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableMangoExchange {
    // Perp positions
    mapping(address => int256) public perpPosition; // positive = long
    mapping(address => uint256) public perpEntryPrice;
    
    // Collateral
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    
    // Oracle price - VULNERABLE: derived from own order book
    uint256 public mngoPrice = 100e18; // $100 initial
    
    IERC20 public usdc;
    
    uint256 public constant COLLATERAL_FACTOR = 80; // 80% LTV
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    /**
     * @notice Get MNGO price - VULNERABLE: uses own market price
     * @dev Should use external oracle (Pyth, Chainlink)
     */
    function getMngoPrice() public view returns (uint256) {
        // BUG: This is manipulated by trading on this very platform!
        return mngoPrice;
    }
    
    /**
     * @notice Trade on perp market - moves price
     */
    function tradePerp(int256 size, bool isLong) external {
        // Simplified: buying moves price up, selling moves price down
        if (isLong && size > 0) {
            // BUG: Large buy moves price with minimal capital
            // Real markets have more liquidity, but Mango had thin books
            mngoPrice = mngoPrice * (100 + uint256(size) / 1000) / 100;
            perpPosition[msg.sender] += size;
        } else if (!isLong && size > 0) {
            mngoPrice = mngoPrice * 100 / (100 + uint256(size) / 1000);
            perpPosition[msg.sender] -= size;
        }
        perpEntryPrice[msg.sender] = mngoPrice;
    }
    
    /**
     * @notice Deposit collateral (in MNGO value)
     */
    function depositCollateral(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }
    
    /**
     * @notice Borrow against collateral - VULNERABLE
     * @dev Uses self-referential price for valuation
     */
    function borrow(uint256 amount) external {
        // BUG: Collateral value uses manipulatable price
        uint256 collateralValue = collateral[msg.sender];
        
        // Also count unrealized PnL from perp position
        // This is where the attack compounds
        int256 pnl = calculatePnL(msg.sender);
        if (pnl > 0) {
            collateralValue += uint256(pnl);
        }
        
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR / 100;
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds limit");
        
        debt[msg.sender] += amount;
        usdc.transfer(msg.sender, amount);
    }
    
    /**
     * @notice Calculate unrealized PnL - uses manipulated price
     */
    function calculatePnL(address user) public view returns (int256) {
        if (perpPosition[user] == 0) return 0;
        
        int256 currentValue = perpPosition[user] * int256(getMngoPrice());
        int256 entryValue = perpPosition[user] * int256(perpEntryPrice[user]);
        
        return (currentValue - entryValue) / 1e18;
    }
    
    /**
     * @notice FIXED: Use external oracle
     */
    function getMngoPriceFixed() public view returns (uint256) {
        // return pythOracle.getPrice("MNGO-USD");
        // return chainlinkFeed.latestAnswer();
        return 100e18; // Placeholder
    }
}
