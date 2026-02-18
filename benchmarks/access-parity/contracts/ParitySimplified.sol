// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Parity Multisig - Unprotected Library Initialize
 * @notice $150M frozen due to library destruction
 * 
 * ROOT CAUSE: The WalletLibrary contract had initWallet() without
 * access control. Someone called it on the deployed library contract,
 * became owner, and called kill() which self-destructed the library.
 * All wallets using delegatecall to the library became non-functional.
 */

/**
 * @notice The VULNERABLE wallet library
 */
contract VulnerableWalletLibrary {
    address[] public owners;
    uint256 public required;
    bool public initialized;
    
    /**
     * @notice VULNERABLE: No access control!
     * Anyone can call this on the library contract itself
     */
    function initWallet(address[] calldata _owners, uint256 _required) external {
        // BUG: No check if already initialized when called on library
        // BUG: No check that caller is authorized
        
        // This check was present but not enough:
        // It only works when called via delegatecall from a wallet
        // When called directly on library, initialized is false
        require(!initialized, "Already initialized");
        
        owners = _owners;
        required = _required;
        initialized = true;
    }
    
    /**
     * @notice Owner-only function - but attacker became owner!
     */
    function kill(address payable beneficiary) external {
        require(isOwner(msg.sender), "Not owner");
        // BUG: selfdestruct destroys the LIBRARY, not just one wallet
        selfdestruct(beneficiary);
    }
    
    function isOwner(address addr) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == addr) return true;
        }
        return false;
    }
    
    // Other wallet functions...
    function execute(address target, uint256 value, bytes calldata data) external {
        require(isOwner(msg.sender), "Not owner");
        (bool success,) = target.call{value: value}(data);
        require(success, "Execution failed");
    }
}

/**
 * @notice Wallet that delegates to the library
 */
contract ParityWallet {
    address public library;
    
    constructor(address _library) {
        library = _library;
    }
    
    // All calls delegated to library
    fallback() external payable {
        address lib = library;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), lib, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    receive() external payable {}
}

/**
 * @notice FIXED library with proper initialization
 */
contract FixedWalletLibrary {
    address[] public owners;
    uint256 public required;
    bool public initialized;
    
    /**
     * @notice FIXED: Disable initialization on implementation
     */
    constructor() {
        // Initialize implementation so it can't be initialized later
        initialized = true;
    }
    
    /**
     * @notice FIXED: Can only be called via delegatecall
     */
    function initWallet(address[] calldata _owners, uint256 _required) external {
        // This check ensures we're in delegatecall context
        // (library's initialized is true, but proxy's is false)
        require(!initialized, "Already initialized");
        require(_owners.length > 0, "No owners");
        require(_required <= _owners.length, "Invalid required");
        
        owners = _owners;
        required = _required;
        initialized = true;
    }
    
    // Remove selfdestruct entirely - too dangerous
}
