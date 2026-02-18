// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Poly Network - Cross-Chain Target Validation
 * @notice Simplified version of the $611M exploit
 * 
 * ROOT CAUSE: Cross-chain messages could target ANY contract
 * with ANY calldata. Attacker crafted a message that called
 * the EthCrossChainManager's keeper contract to change the
 * keeper address. With control of keeper, they could sign
 * arbitrary withdrawals.
 */

contract VulnerableEthCrossChainManager {
    address public keeper;
    
    // Bookkeeper that manages the keeper list
    address public bookkeeper;
    
    mapping(bytes32 => bool) public processedTxs;
    
    modifier onlyKeeper() {
        require(msg.sender == keeper, "Not keeper");
        _;
    }
    
    constructor(address _keeper, address _bookkeeper) {
        keeper = _keeper;
        bookkeeper = _bookkeeper;
    }
    
    /**
     * @notice VULNERABLE: Process cross-chain transaction
     * Can target ANY contract with ANY data
     */
    function verifyAndExecuteTx(
        bytes calldata proof,
        bytes calldata header,
        bytes calldata merkleProof,
        address toContract,
        bytes calldata toData
    ) external {
        // Verify proof (simplified)
        bytes32 txHash = keccak256(abi.encodePacked(proof, header));
        require(!processedTxs[txHash], "Already processed");
        processedTxs[txHash] = true;
        
        // BUG: No validation of toContract!
        // Attacker can set toContract = bookkeeper
        // And toData = changeKeeper(attackerAddress)
        
        // Execute cross-chain call
        (bool success,) = toContract.call(toData);
        require(success, "Execution failed");
    }
    
    /**
     * @notice Unlock tokens - requires keeper signature
     */
    function unlock(
        bytes calldata args,
        bytes calldata signature
    ) external {
        // Verify keeper signed this
        bytes32 messageHash = keccak256(args);
        address signer = recoverSigner(messageHash, signature);
        require(signer == keeper, "Invalid signature");
        
        // Process unlock
        // (address token, address to, uint256 amount) = abi.decode(args, ...);
        // IERC20(token).transfer(to, amount);
    }
    
    function recoverSigner(bytes32 hash, bytes memory sig) internal pure returns (address) {
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
}

/**
 * @notice The bookkeeper contract that manages keepers
 */
contract VulnerableBookkeeper {
    address public crossChainManager;
    address public keeper;
    
    constructor(address _ccm) {
        crossChainManager = _ccm;
    }
    
    /**
     * @notice VULNERABLE: Can be called via cross-chain message
     */
    function changeKeeper(address newKeeper) external {
        // BUG: Only checks if caller is crossChainManager
        // But crossChainManager executes arbitrary cross-chain calls!
        require(msg.sender == crossChainManager, "Only CCM");
        keeper = newKeeper;
    }
    
    /**
     * @notice FIXED: Whitelist allowed cross-chain callers
     */
    function changeKeeperFixed(address newKeeper) external {
        // Option 1: Only allow from specific trusted chains/contracts
        // Option 2: Require multi-sig
        // Option 3: Add timelock
        // Option 4: Don't allow keeper changes via cross-chain at all
    }
}

/**
 * @notice Attack flow:
 * 1. Craft cross-chain message with:
 *    - toContract = bookkeeper address
 *    - toData = changeKeeper(attackerAddress)
 * 2. Submit to Poly Network
 * 3. EthCrossChainManager.verifyAndExecuteTx() calls bookkeeper.changeKeeper()
 * 4. Attacker is now the keeper
 * 5. Sign withdrawals for all locked assets
 */
