// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Audius - Governance Re-initialization
 * @notice Simplified version of the $6M exploit
 * 
 * ROOT CAUSE: The governance contract used a proxy pattern, but
 * the implementation's initialize() function wasn't properly
 * protected. Attacker could call initialize() on the proxy
 * pointing to a new implementation, taking control.
 */

contract VulnerableAudiusGovernance {
    address public guardian;
    address public voting;
    uint256 public votingQuorumPercent;
    uint256 public votingPeriod;
    
    bool public initialized;
    
    /**
     * @notice VULNERABLE: Can be called multiple times through proxy
     */
    function initialize(
        address _guardian,
        address _voting,
        uint256 _quorum,
        uint256 _period
    ) external {
        // BUG: This check uses proxy's storage slot for `initialized`
        // If implementation wasn't initialized, proxy's `initialized` is false
        require(!initialized, "Already initialized");
        
        guardian = _guardian;
        voting = _voting;
        votingQuorumPercent = _quorum;
        votingPeriod = _period;
        initialized = true;
    }
    
    /**
     * @notice Guardian can execute arbitrary calls
     */
    function guardianExecuteTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        require(msg.sender == guardian, "Not guardian");
        
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "Execution failed");
        
        return returnData;
    }
    
    receive() external payable {}
}

/**
 * @notice The proxy contract
 */
contract AudiusProxy {
    address public implementation;
    
    constructor(address _impl) {
        implementation = _impl;
    }
    
    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    receive() external payable {}
}

/**
 * @notice Attack flow:
 * 1. Proxy points to implementation
 * 2. Implementation was deployed but initialize() never called on it
 * 3. Attacker calls initialize() through proxy
 * 4. Sets themselves as guardian
 * 5. Calls guardianExecuteTransaction to drain funds
 */

/**
 * @notice FIXED: Disable initializers on implementation
 */
contract FixedAudiusGovernance {
    bool public initialized;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable initializers on implementation
        initialized = true;
    }
    
    function initialize(...) external {
        require(!initialized, "Already initialized");
        // ...
    }
}
