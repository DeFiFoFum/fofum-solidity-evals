// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title BonqDAO - Cheap Oracle Update Attack
 * @notice Simplified version of the $120M exploit
 * 
 * ROOT CAUSE: TellorFlex allowed anyone to submit price updates
 * by staking TRB (only ~$175 worth). BonqDAO used these prices
 * without adequate sanity checks.
 * 
 * Attack:
 * 1. Stake minimal TRB to become Tellor reporter
 * 2. Submit manipulated WALBT price (100x real price)
 * 3. BonqDAO accepts inflated price
 * 4. Borrow against inflated WALBT collateral
 * 5. Profit >> staking cost
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @notice Simplified TellorFlex oracle - VULNERABLE to cheap manipulation
 */
contract VulnerableTellorFlex {
    IERC20 public trbToken;
    
    // Minimum stake to become reporter - BUG: too low!
    uint256 public constant MIN_STAKE = 10e18; // Only 10 TRB (~$175)
    
    mapping(address => uint256) public stakedBalance;
    mapping(bytes32 => uint256) public prices;
    mapping(bytes32 => uint256) public lastUpdateTime;
    
    constructor(address _trb) {
        trbToken = IERC20(_trb);
    }
    
    /**
     * @notice Stake TRB to become reporter
     */
    function stake(uint256 amount) external {
        trbToken.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
    }
    
    /**
     * @notice Submit price - VULNERABLE: no sanity checks
     */
    function submitValue(bytes32 queryId, uint256 value) external {
        require(stakedBalance[msg.sender] >= MIN_STAKE, "Insufficient stake");
        
        // BUG: No check if price is reasonable
        // BUG: No comparison to previous price
        // BUG: No dispute period before use
        prices[queryId] = value;
        lastUpdateTime[queryId] = block.timestamp;
    }
    
    function getPrice(bytes32 queryId) external view returns (uint256) {
        return prices[queryId];
    }
}

contract VulnerableBonqLending {
    VulnerableTellorFlex public oracle;
    IERC20 public walbtToken;
    IERC20 public stablecoin;
    
    bytes32 public constant WALBT_QUERY_ID = keccak256("WALBT/USD");
    
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    
    uint256 public constant COLLATERAL_FACTOR = 80;
    
    constructor(address _oracle, address _walbt, address _stable) {
        oracle = VulnerableTellorFlex(_oracle);
        walbtToken = IERC20(_walbt);
        stablecoin = IERC20(_stable);
    }
    
    function deposit(uint256 amount) external {
        walbtToken.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }
    
    /**
     * @notice VULNERABLE: Uses oracle price without sanity checks
     */
    function borrow(uint256 amount) external {
        // BUG: No check if price is stale
        // BUG: No check if price deviates significantly from TWAP
        // BUG: No check against secondary oracle
        uint256 price = oracle.getPrice(WALBT_QUERY_ID);
        
        uint256 collateralValue = collateral[msg.sender] * price / 1e18;
        uint256 maxBorrow = collateralValue * COLLATERAL_FACTOR / 100;
        
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds limit");
        
        debt[msg.sender] += amount;
        stablecoin.transfer(msg.sender, amount);
    }
    
    /**
     * @notice FIXED: Add sanity checks
     */
    function borrowFixed(uint256 amount) external {
        uint256 price = oracle.getPrice(WALBT_QUERY_ID);
        uint256 lastUpdate = oracle.lastUpdateTime(WALBT_QUERY_ID);
        
        // Check staleness
        require(block.timestamp - lastUpdate < 1 hours, "Stale price");
        
        // Check against secondary oracle / TWAP
        // uint256 chainlinkPrice = chainlinkOracle.getPrice();
        // require(priceDeviation(price, chainlinkPrice) < 5%, "Price deviation");
        
        // Check absolute bounds
        require(price > 0.001e18 && price < 1000e18, "Price out of bounds");
        
        // ... rest of borrow logic
    }
}
