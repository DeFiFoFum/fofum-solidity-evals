// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Wormhole - Signature Verification Bug
 * @notice Simplified version of the $326M exploit
 * 
 * ROOT CAUSE: The Solana side had a signature verification bug.
 * The verifySignatures instruction didn't properly validate
 * that the provided SignatureSet was actually created by guardians.
 * 
 * Attacker could create fake SignatureSets that appeared valid,
 * allowing them to forge VAA messages.
 * 
 * NOTE: Actual bug was in Solana program. This Solidity version
 * demonstrates similar patterns that could exist in EVM bridges.
 */

contract VulnerableWormholeBridge {
    // Guardian set
    mapping(address => bool) public guardians;
    address[] public guardianList;
    uint256 public guardianSetIndex;
    uint256 public threshold; // e.g., 13 of 19
    
    // Processed VAAs (replay protection)
    mapping(bytes32 => bool) public processedVAAs;
    
    struct VAA {
        uint32 guardianSetIndex;
        bytes signatures;
        uint32 timestamp;
        uint32 nonce;
        uint16 emitterChainId;
        bytes32 emitterAddress;
        uint64 sequence;
        uint8 consistencyLevel;
        bytes payload;
    }
    
    constructor(address[] memory _guardians, uint256 _threshold) {
        for (uint i = 0; i < _guardians.length; i++) {
            guardians[_guardians[i]] = true;
            guardianList.push(_guardians[i]);
        }
        threshold = _threshold;
    }
    
    /**
     * @notice VULNERABLE: Simplified signature verification
     * Real bug was more subtle (Solana-specific)
     */
    function parseAndVerifyVAA(bytes calldata encodedVAA) external view returns (VAA memory) {
        VAA memory vaa = abi.decode(encodedVAA, (VAA));
        
        // BUG: Signature verification could be bypassed
        // In real exploit, attacker could provide fake signature data
        // that the verification logic accepted
        
        require(verifySignatures(vaa.signatures, vaa), "Invalid signatures");
        
        return vaa;
    }
    
    /**
     * @notice VULNERABLE signature verification
     */
    function verifySignatures(bytes memory signatures, VAA memory vaa) internal view returns (bool) {
        bytes32 messageHash = keccak256(abi.encode(
            vaa.timestamp,
            vaa.nonce,
            vaa.emitterChainId,
            vaa.emitterAddress,
            vaa.sequence,
            vaa.consistencyLevel,
            vaa.payload
        ));
        
        // BUG: Incomplete validation
        // Real exploit involved tricking the verifier about which accounts
        // were actually guardian signatures
        
        uint256 validSigs;
        uint256 offset;
        
        while (offset < signatures.length) {
            // Extract signature (65 bytes: r, s, v)
            bytes32 r;
            bytes32 s;
            uint8 v;
            
            assembly {
                r := mload(add(signatures, add(offset, 32)))
                s := mload(add(signatures, add(offset, 64)))
                v := byte(0, mload(add(signatures, add(offset, 96))))
            }
            
            address signer = ecrecover(messageHash, v, r, s);
            
            // BUG: What if signer is zero? What if signature data is malformed?
            if (guardians[signer]) {
                validSigs++;
            }
            
            offset += 65;
        }
        
        return validSigs >= threshold;
    }
    
    /**
     * @notice Process a VAA to mint tokens
     */
    function processVAA(bytes calldata encodedVAA) external {
        VAA memory vaa = this.parseAndVerifyVAA(encodedVAA);
        
        bytes32 vaaHash = keccak256(encodedVAA);
        require(!processedVAAs[vaaHash], "Already processed");
        processedVAAs[vaaHash] = true;
        
        // Decode payload and mint tokens
        // (simplified)
    }
}
