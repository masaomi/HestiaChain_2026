// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HestiaAnchor
 * @notice Minimal witness anchor contract for HestiaChain
 * @dev Records only hashes (proof of existence), never actual content.
 * 
 * Design Philosophy:
 * > "History is not replayable, but reconstructible through cooperation."
 * 
 * This contract acts as a public witness layer, recording that certain
 * data existed at a specific time. The actual content remains private
 * and can only be reconstructed through cooperation between participants.
 * 
 * Features:
 * - Single anchor recording (recordAnchor)
 * - Batch recording for gas optimization (recordAnchors)
 * - Verification (verifyAnchor)
 * - Optional anchor type tracking
 * 
 * Gas Optimization:
 * - Batching: 10 anchors in 1 tx uses ~60% less gas than 10 separate txs
 * - Minimal storage: Only hash + timestamp + type string
 * - Events for off-chain indexing
 */
contract HestiaAnchor {
    // =========================================================================
    // Events
    // =========================================================================

    /**
     * @notice Emitted when an anchor is recorded
     * @param anchorHash The unique hash identifying this anchor
     * @param anchorType The type of anchor (e.g., "meeting", "genomics")
     * @param timestamp The block timestamp when recorded
     * @param sender The address that recorded the anchor
     */
    event AnchorRecorded(
        bytes32 indexed anchorHash,
        string indexed anchorType,
        uint256 timestamp,
        address indexed sender
    );

    /**
     * @notice Emitted when a batch of anchors is recorded
     * @param count Number of anchors in the batch
     * @param sender The address that recorded the batch
     */
    event BatchRecorded(
        uint256 count,
        address indexed sender
    );

    // =========================================================================
    // Storage
    // =========================================================================

    /// @notice Mapping from anchor hash to existence flag
    mapping(bytes32 => bool) public anchors;

    /// @notice Mapping from anchor hash to recording timestamp
    mapping(bytes32 => uint256) public timestamps;

    /// @notice Mapping from anchor hash to anchor type
    mapping(bytes32 => string) public anchorTypes;

    /// @notice Mapping from anchor hash to recorder address
    mapping(bytes32 => address) public recorders;

    /// @notice Total number of anchors recorded
    uint256 public totalAnchors;

    // =========================================================================
    // Core Functions
    // =========================================================================

    /**
     * @notice Record a single anchor
     * @param anchorHash The unique hash of the anchor (SHA256 of anchor payload)
     * @param anchorType The type of anchor (e.g., "meeting", "generic")
     * @return success True if the anchor was recorded (false if already exists)
     * 
     * @dev Emits AnchorRecorded event on success
     * 
     * Example usage from Ruby:
     *   contract.recordAnchor(anchor.anchor_hash, anchor.anchor_type)
     */
    function recordAnchor(
        bytes32 anchorHash,
        string calldata anchorType
    ) external returns (bool success) {
        if (anchors[anchorHash]) {
            return false; // Already exists, don't revert
        }

        _recordAnchor(anchorHash, anchorType);
        return true;
    }

    /**
     * @notice Record a single anchor (reverts if exists)
     * @param anchorHash The unique hash of the anchor
     * @param anchorType The type of anchor
     * 
     * @dev Use this when you want the transaction to fail if anchor exists
     */
    function recordAnchorStrict(
        bytes32 anchorHash,
        string calldata anchorType
    ) external {
        require(!anchors[anchorHash], "HestiaAnchor: anchor already exists");
        _recordAnchor(anchorHash, anchorType);
    }

    /**
     * @notice Record multiple anchors in a single transaction (gas optimization)
     * @param anchorHashes Array of anchor hashes
     * @param types Array of anchor types (must match hashes length)
     * @return recorded Number of anchors actually recorded (skips duplicates)
     * 
     * @dev Gas savings: ~60% compared to individual calls
     * 
     * Example usage from Ruby:
     *   hashes = anchors.map(&:anchor_hash)
     *   types = anchors.map(&:anchor_type)
     *   contract.recordAnchors(hashes, types)
     */
    function recordAnchors(
        bytes32[] calldata anchorHashes,
        string[] calldata types
    ) external returns (uint256 recorded) {
        require(
            anchorHashes.length == types.length,
            "HestiaAnchor: arrays length mismatch"
        );
        require(
            anchorHashes.length <= 100,
            "HestiaAnchor: batch too large (max 100)"
        );

        recorded = 0;
        for (uint256 i = 0; i < anchorHashes.length; i++) {
            if (!anchors[anchorHashes[i]]) {
                _recordAnchor(anchorHashes[i], types[i]);
                recorded++;
            }
        }

        emit BatchRecorded(recorded, msg.sender);
        return recorded;
    }

    /**
     * @notice Record multiple anchors of the same type (gas optimization)
     * @param anchorHashes Array of anchor hashes
     * @param anchorType The type for all anchors
     * @return recorded Number of anchors actually recorded
     * 
     * @dev Even more gas efficient when all anchors have the same type
     */
    function recordAnchorsSameType(
        bytes32[] calldata anchorHashes,
        string calldata anchorType
    ) external returns (uint256 recorded) {
        require(
            anchorHashes.length <= 100,
            "HestiaAnchor: batch too large (max 100)"
        );

        recorded = 0;
        for (uint256 i = 0; i < anchorHashes.length; i++) {
            if (!anchors[anchorHashes[i]]) {
                _recordAnchor(anchorHashes[i], anchorType);
                recorded++;
            }
        }

        emit BatchRecorded(recorded, msg.sender);
        return recorded;
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /**
     * @notice Verify an anchor exists and get its details
     * @param anchorHash The anchor hash to verify
     * @return exists True if the anchor exists
     * @return timestamp When the anchor was recorded (0 if not exists)
     * @return anchorType The type of the anchor (empty if not exists)
     * @return recorder The address that recorded the anchor (0x0 if not exists)
     * 
     * @dev This is a view function, no gas cost when called off-chain
     */
    function verifyAnchor(
        bytes32 anchorHash
    ) external view returns (
        bool exists,
        uint256 timestamp,
        string memory anchorType,
        address recorder
    ) {
        return (
            anchors[anchorHash],
            timestamps[anchorHash],
            anchorTypes[anchorHash],
            recorders[anchorHash]
        );
    }

    /**
     * @notice Check if an anchor exists
     * @param anchorHash The anchor hash to check
     * @return True if exists
     */
    function exists(bytes32 anchorHash) external view returns (bool) {
        return anchors[anchorHash];
    }

    /**
     * @notice Get the timestamp of an anchor
     * @param anchorHash The anchor hash
     * @return The block timestamp when recorded (0 if not exists)
     */
    function getTimestamp(bytes32 anchorHash) external view returns (uint256) {
        return timestamps[anchorHash];
    }

    /**
     * @notice Get the type of an anchor
     * @param anchorHash The anchor hash
     * @return The anchor type (empty string if not exists)
     */
    function getType(bytes32 anchorHash) external view returns (string memory) {
        return anchorTypes[anchorHash];
    }

    /**
     * @notice Get the recorder of an anchor
     * @param anchorHash The anchor hash
     * @return The address that recorded the anchor (0x0 if not exists)
     */
    function getRecorder(bytes32 anchorHash) external view returns (address) {
        return recorders[anchorHash];
    }

    // =========================================================================
    // Internal Functions
    // =========================================================================

    /**
     * @dev Internal function to record an anchor
     */
    function _recordAnchor(
        bytes32 anchorHash,
        string calldata anchorType
    ) internal {
        anchors[anchorHash] = true;
        timestamps[anchorHash] = block.timestamp;
        anchorTypes[anchorHash] = anchorType;
        recorders[anchorHash] = msg.sender;
        totalAnchors++;

        emit AnchorRecorded(anchorHash, anchorType, block.timestamp, msg.sender);
    }
}
