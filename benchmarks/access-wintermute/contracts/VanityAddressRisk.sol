// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Wintermute - Vanity Address Vulnerability
 * @notice $160M lost due to weak vanity address generation
 * 
 * ROOT CAUSE: The Profanity vanity address tool had a vulnerability
 * in its random number generation. The secp256k1 private key space
 * was reduced to ~2^32 possibilities, making brute force feasible.
 * 
 * LESSON: This is NOT a smart contract vulnerability - it's key management.
 * However, auditors should flag reliance on vanity addresses as a risk.
 * 
 * DETECTION: Look for addresses with unusual patterns (many leading zeros)
 * that suggest vanity generation. Flag as key management risk.
 */

/**
 * @notice Contract that might be deployed at a vanity address
 */
contract VulnerableVanityWallet {
    address public owner;
    
    // If this contract is at 0x0000000fee...
    // That's a vanity address - potential key compromise risk!
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        // Owner address might be vanity-generated
        // If attacker recovers owner's private key, game over
    }
    
    function withdraw(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }
    
    function execute(address target, bytes calldata data) external onlyOwner {
        (bool success,) = target.call(data);
        require(success, "Execution failed");
    }
    
    receive() external payable {}
}

/**
 * @notice Audit checklist for vanity address risks
 * 
 * RED FLAGS:
 * 1. Owner/admin address has leading zeros (0x000000...)
 * 2. Owner/admin address has recognizable pattern
 * 3. Deployment address looks "vanity" generated
 * 4. No multi-sig for high-value operations
 * 
 * RECOMMENDATIONS:
 * 1. Use multi-sig (Safe, etc.) for all high-value wallets
 * 2. Don't use vanity addresses for anything critical
 * 3. If vanity is needed, use Create2 (deterministic, safe)
 * 4. Hardware wallet for owner keys
 */

/**
 * @notice Safe alternative: Create2 for deterministic addresses
 */
contract Create2Factory {
    function deploy(bytes32 salt, bytes memory bytecode) external returns (address) {
        address deployed;
        assembly {
            deployed := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(deployed != address(0), "Deployment failed");
        return deployed;
    }
    
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }
}
