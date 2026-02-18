// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ronin Bridge - Validator Concentration Attack
 * @notice Simplified version of the $625M exploit
 * 
 * ROOT CAUSE: 5/9 threshold, but Sky Mavis controlled 5 keys:
 * - 4 Sky Mavis validator keys
 * - 1 Axie DAO key (delegated to Sky Mavis)
 * 
 * Attackers compromised these keys through social engineering
 * and signed fraudulent withdrawal requests.
 * 
 * LESSON: Validator distribution matters as much as threshold
 */

contract VulnerableRoninBridge {
    // Validator set
    mapping(address => bool) public validators;
    address[] public validatorList;
    uint256 public threshold;
    
    // Withdrawal tracking
    mapping(bytes32 => bool) public processedWithdrawals;
    
    // Assets
    mapping(address => uint256) public lockedTokens;
    
    event Withdrawal(bytes32 indexed withdrawalId, address indexed to, uint256 amount);
    
    constructor(address[] memory _validators, uint256 _threshold) {
        // BUG: No check that validators are from different organizations
        // BUG: Threshold could be met by single entity controlling multiple keys
        for (uint256 i = 0; i < _validators.length; i++) {
            validators[_validators[i]] = true;
            validatorList.push(_validators[i]);
        }
        threshold = _threshold;
    }
    
    /**
     * @notice Process withdrawal with validator signatures
     * @dev VULNERABLE: Only checks signature count, not key distribution
     */
    function withdraw(
        bytes32 withdrawalId,
        address to,
        uint256 amount,
        bytes[] calldata signatures
    ) external {
        require(!processedWithdrawals[withdrawalId], "Already processed");
        require(signatures.length >= threshold, "Not enough signatures");
        
        bytes32 messageHash = keccak256(abi.encodePacked(withdrawalId, to, amount));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // BUG: Just counts valid signatures, doesn't ensure key diversity
        uint256 validSigs = 0;
        address lastSigner = address(0);
        
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = recoverSigner(ethSignedHash, signatures[i]);
            require(signer > lastSigner, "Signatures not ordered"); // Prevents duplicates
            
            if (validators[signer]) {
                validSigs++;
            }
            lastSigner = signer;
        }
        
        require(validSigs >= threshold, "Invalid signatures");
        
        processedWithdrawals[withdrawalId] = true;
        
        // Transfer (simplified)
        payable(to).transfer(amount);
        
        emit Withdrawal(withdrawalId, to, amount);
    }
    
    function recoverSigner(bytes32 hash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        
        return ecrecover(hash, v, r, s);
    }
    
    receive() external payable {
        lockedTokens[address(0)] += msg.value;
    }
}

/**
 * @notice FIXED: Track validator organizations
 */
contract FixedRoninBridge {
    struct Validator {
        address addr;
        bytes32 organizationId; // Different orgs required
        bool active;
    }
    
    mapping(address => Validator) public validators;
    uint256 public threshold;
    uint256 public minOrganizations; // e.g., require 5 different orgs
    
    // Require signatures from at least N different organizations
    // This prevents single-entity control even with multiple keys
}
