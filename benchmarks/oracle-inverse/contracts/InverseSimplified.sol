// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Inverse Finance - Short TWAP Attack
 * @notice Simplified version of the $15.6M exploit
 * 
 * ROOT CAUSE: TWAP window was only 25 minutes on a low-liquidity pair.
 * Attacker could:
 * 1. Make series of large swaps over 25+ minutes
 * 2. TWAP gradually rises to reflect manipulated prices
 * 3. Once TWAP high enough, borrow DOLA against INV
 * 4. Let position liquidate - borrowed more than INV worth
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableTWAPOracle {
    // Price observations
    struct Observation {
        uint256 timestamp;
        uint256 price;
    }
    
    Observation[] public observations;
    
    // BUG: Only 25 minute window - too short!
    uint256 public constant TWAP_WINDOW = 25 minutes;
    
    constructor() {
        // Initialize with some observations
        observations.push(Observation(block.timestamp - 30 minutes, 100e18));
        observations.push(Observation(block.timestamp - 20 minutes, 100e18));
        observations.push(Observation(block.timestamp - 10 minutes, 100e18));
        observations.push(Observation(block.timestamp, 100e18));
    }
    
    /**
     * @notice Update price observation (called on each swap)
     */
    function updatePrice(uint256 newPrice) external {
        observations.push(Observation(block.timestamp, newPrice));
    }
    
    /**
     * @notice Get TWAP - VULNERABLE: short window
     */
    function getTWAP() public view returns (uint256) {
        uint256 targetTime = block.timestamp - TWAP_WINDOW;
        uint256 cumulativePrice;
        uint256 count;
        
        for (uint256 i = observations.length; i > 0; i--) {
            if (observations[i-1].timestamp < targetTime) break;
            cumulativePrice += observations[i-1].price;
            count++;
        }
        
        if (count == 0) return 100e18; // Default
        return cumulativePrice / count;
    }
    
    /**
     * @notice FIXED: Use longer window (4-24 hours)
     */
    function getTWAPFixed() public view returns (uint256) {
        uint256 targetTime = block.timestamp - 4 hours; // Much safer
        // ... same calculation with longer window
        return 100e18;
    }
}

contract VulnerableInverseLending {
    IERC20 public invToken;
    IERC20 public dolaToken;
    VulnerableTWAPOracle public oracle;
    
    mapping(address => uint256) public collateral; // INV
    mapping(address => uint256) public debt; // DOLA
    
    uint256 public constant COLLATERAL_FACTOR = 75; // 75% LTV
    
    constructor(address _inv, address _dola, address _oracle) {
        invToken = IERC20(_inv);
        dolaToken = IERC20(_dola);
        oracle = VulnerableTWAPOracle(_oracle);
    }
    
    function depositCollateral(uint256 amount) external {
        invToken.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }
    
    /**
     * @notice VULNERABLE: Uses short-window TWAP
     */
    function borrow(uint256 amount) external {
        // BUG: TWAP can be manipulated over 25 minutes
        uint256 invPrice = oracle.getTWAP();
        uint256 collateralValue = collateral[msg.sender] * invPrice / 1e18;
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR / 100;
        
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds limit");
        
        debt[msg.sender] += amount;
        dolaToken.transfer(msg.sender, amount);
    }
    
    /**
     * @notice Should add circuit breaker for large price movements
     */
    function borrowWithCircuitBreaker(uint256 amount) external {
        uint256 currentPrice = oracle.getTWAP();
        // uint256 lastKnownPrice = ...; // From Chainlink or longer TWAP
        // require(priceDeviation < 10%, "Price circuit breaker");
    }
}
