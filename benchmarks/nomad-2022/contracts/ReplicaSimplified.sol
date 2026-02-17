// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Nomad Bridge Replica - Simplified Vulnerable Code
 * @notice Shows the root cause of the $190M Nomad exploit
 * 
 * ROOT CAUSE: After an upgrade, confirmAt[root] was set to 0 for a trusted root.
 * The acceptableRoot() function checked if confirmAt[root] != 0 to determine validity,
 * but 0 was a valid timestamp! So ALL messages with hash 0x00 were treated as confirmed.
 */

contract NomadReplica {
    // Maps message hash => confirmation timestamp
    // BUG: 0 means both "uninitialized" AND "confirmed at timestamp 0"
    mapping(bytes32 => uint256) public confirmAt;
    
    // Processed messages (replay protection)
    mapping(bytes32 => bool) public processed;
    
    // Trusted root (set during upgrade - THIS WAS SET TO 0x00!)
    bytes32 public committedRoot;
    
    uint256 public constant PROCESS_GAS = 850_000;
    uint256 public optimisticSeconds = 30 minutes;

    event Process(bytes32 indexed messageHash, bool indexed success, bytes returnData);

    // Initialize with a trusted root
    // BUG: In the actual exploit, this was called with 0x00 as _committedRoot
    function initialize(bytes32 _committedRoot) external {
        committedRoot = _committedRoot;
        // This sets confirmAt[0x00] = 1 (block.timestamp was 1 in the context)
        // But the upgrade script had a bug that set it to 0!
        confirmAt[_committedRoot] = 1; 
    }

    /**
     * @notice Process a cross-chain message
     * @dev VULNERABLE: acceptableRoot() returns true for messages[hash] == 0
     */
    function process(bytes memory _message) external returns (bool _success) {
        bytes32 _messageHash = keccak256(_message);
        
        // Check message hasn't been processed
        require(!processed[_messageHash], "already processed");
        
        // VULNERABILITY: This check passes when confirmAt[hash] == 0
        // because 0 is treated as a valid timestamp!
        require(acceptableRoot(confirmAt[_messageHash]), "!confirmAt");
        
        // Mark as processed
        processed[_messageHash] = true;
        
        // Execute message (simplified - actual impl decodes and calls)
        // In real attack, this would unlock tokens
        (_success, ) = address(this).call{gas: PROCESS_GAS}(_message);
        
        emit Process(_messageHash, _success, "");
    }

    /**
     * @notice Check if a root has been confirmed
     * @dev BUG: Returns TRUE when _root == 0 because confirmAt[0] could be 0
     *      which is >= block.timestamp - optimisticSeconds when timestamp is small
     *      
     *      Actually the real bug: confirmAt[_root] == 0 was being treated as valid
     *      because the check was just `confirmAt[_root] != 0` originally,
     *      but after upgrade it became timestamp-based and 0 was valid!
     */
    function acceptableRoot(uint256 _confirmAt) internal view returns (bool) {
        // Original vulnerable check:
        // This returns TRUE when _confirmAt == 0 on chains where 
        // block.timestamp - optimisticSeconds could underflow to 0
        // OR when _confirmAt == 0 was explicitly set as valid
        
        // The ACTUAL bug was simpler: mapping returned 0 for uninitialized keys
        // and 0 was considered a valid "confirmed" state
        
        // Simplified to show the bug:
        if (_confirmAt == 0) {
            // BUG: Should return false (uninitialized)
            // But returned true (treated as "confirmed at time 0")
            return true; // THIS IS THE BUG
        }
        
        return _confirmAt <= block.timestamp - optimisticSeconds;
    }

    /**
     * @notice Proper fix - explicitly check for uninitialized
     */
    function acceptableRootFixed(bytes32 _root) internal view returns (bool) {
        uint256 _confirmAt = confirmAt[_root];
        
        // FIXED: Explicitly check for uninitialized (0 means not confirmed)
        if (_confirmAt == 0) {
            return false;
        }
        
        return _confirmAt <= block.timestamp - optimisticSeconds;
    }
}
