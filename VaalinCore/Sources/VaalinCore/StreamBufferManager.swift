// ABOUTME: StreamBufferManager actor provides thread-safe stream buffer management with circular buffers

import Foundation
import OSLog

/// Thread-safe stream buffer manager for content organization.
///
/// StreamBufferManager maintains independent 10,000-line circular buffers for each stream
/// (e.g., "thoughts", "speech", "combat") with automatic pruning and unread count tracking.
/// This enables stream filtering UI where users can view specific content types separately
/// from the main game log.
///
/// ## Architecture
///
/// Each stream has two components:
/// - **Message buffer**: Circular buffer of Message objects (max 10,000)
/// - **Unread count**: Tracks messages added since last view
///
/// ## Buffer Management
///
/// - **Capacity**: 10,000 messages per stream (configurable constant)
/// - **Pruning**: FIFO (First-In-First-Out) when exceeding capacity
/// - **Independence**: Each stream has its own isolated buffer
///
/// ## Usage
///
/// ```swift
/// let manager = StreamBufferManager()
///
/// // Append message to stream
/// await manager.append(message, toStream: "thoughts")
///
/// // Get messages for display
/// let messages = await manager.messages(forStream: "thoughts")
///
/// // Check unread count
/// let unread = await manager.unreadCount(forStream: "thoughts")
///
/// // Clear unread when stream viewed
/// await manager.clearUnreadCount(forStream: "thoughts")
/// ```
///
/// ## Thread Safety
///
/// StreamBufferManager is implemented as an actor, ensuring all operations are thread-safe.
/// Multiple components can safely append messages and query buffers concurrently.
///
/// ## Performance
///
/// - **Append**: O(1) amortized (array append + occasional pruning)
/// - **Query**: O(1) for unread count, O(n) for messages (returns copy)
/// - **Memory**: ~50KB per 1000 messages per stream (typical)
///
/// ## Future Architecture
///
/// This buffer logic mirrors `GameLogViewModel` and will be extracted into a reusable
/// `MessageBuffer<T>` component in a future refactoring. For now, we keep the logic
/// here to maintain progress while keeping the extraction option open.
public actor StreamBufferManager {
    // MARK: - Constants

    /// Maximum number of messages to retain per stream before pruning oldest.
    /// Matches GameLogViewModel buffer size for consistency.
    private static let maxBufferSize = 10_000

    // MARK: - State

    /// Message buffers indexed by stream ID.
    ///
    /// Each stream maintains an independent buffer of Message objects.
    /// Buffers are automatically pruned when exceeding maxBufferSize.
    private var buffers: [String: [Message]] = [:]

    /// Unread counts indexed by stream ID.
    ///
    /// Tracks number of messages added since last `clearUnreadCount()` call.
    /// Increments on each `append()`, resets to 0 on `clearUnreadCount()`.
    private var unreadCounts: [String: Int] = [:]

    /// Logger for StreamBufferManager events
    private let logger = Logger(subsystem: "com.vaalin.core", category: "StreamBufferManager")

    // MARK: - Initialization

    /// Creates a new stream buffer manager with empty buffers.
    ///
    /// Use this initializer for production code. All buffers are created lazily
    /// when first message is appended to a stream.
    public init() {}

    // MARK: - Public API

    /// Appends a message to the specified stream's buffer.
    ///
    /// This method adds the message to the stream's circular buffer and increments
    /// the unread count. If the buffer exceeds `maxBufferSize` after appending,
    /// the oldest message is automatically removed (FIFO pruning).
    ///
    /// - Parameters:
    ///   - message: The message to append
    ///   - streamId: The stream identifier (e.g., "thoughts", "speech", "combat")
    ///
    /// ## Performance
    ///
    /// - **Average case**: O(1) (array append)
    /// - **Pruning case**: O(n) where n = messages over limit (typically 1)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = Message(
    ///     timestamp: Date(),
    ///     attributedText: AttributedString("You think about magic."),
    ///     tags: [],
    ///     streamID: "thoughts"
    /// )
    /// await manager.append(message, toStream: "thoughts")
    /// ```
    public func append(_ message: Message, toStream streamId: String) {
        // Append to buffer (create if doesn't exist)
        buffers[streamId, default: []].append(message)

        // Increment unread count
        unreadCounts[streamId, default: 0] += 1

        // Prune if exceeds capacity
        if buffers[streamId]!.count > Self.maxBufferSize {
            let excess = buffers[streamId]!.count - Self.maxBufferSize
            buffers[streamId]!.removeFirst(excess)
            logger.debug("Pruned \(excess) oldest messages from stream '\(streamId, privacy: .public)'")
        }
    }

    /// Retrieves all messages for the specified stream.
    ///
    /// Returns a copy of the stream's message buffer in chronological order
    /// (oldest first, newest last). Returns empty array if stream doesn't exist.
    ///
    /// - Parameter streamId: The stream identifier to query
    /// - Returns: Array of messages in chronological order
    ///
    /// ## Performance
    ///
    /// O(n) where n = number of messages in buffer (returns copy for safety)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let messages = await manager.messages(forStream: "thoughts")
    /// for message in messages {
    ///     print(message.attributedText)
    /// }
    /// ```
    public func messages(forStream streamId: String) -> [Message] {
        return buffers[streamId] ?? []
    }

    /// Gets the unread message count for the specified stream.
    ///
    /// Returns the number of messages added since last `clearUnreadCount()` call,
    /// or 0 if the stream doesn't exist or has no unread messages.
    ///
    /// - Parameter streamId: The stream identifier to query
    /// - Returns: Number of unread messages (0 if stream doesn't exist)
    ///
    /// ## Performance
    ///
    /// O(1) dictionary lookup
    ///
    /// ## Example
    ///
    /// ```swift
    /// let unread = await manager.unreadCount(forStream: "thoughts")
    /// if unread > 0 {
    ///     print("You have \(unread) unread thoughts")
    /// }
    /// ```
    public func unreadCount(forStream streamId: String) -> Int {
        return unreadCounts[streamId] ?? 0
    }

    /// Clears the unread count for the specified stream.
    ///
    /// Resets the unread counter to 0, typically called when the user views
    /// the stream's content. This does not affect the message buffer itself.
    ///
    /// Safe to call on non-existent streams (no-op).
    ///
    /// - Parameter streamId: The stream identifier to clear
    ///
    /// ## Example
    ///
    /// ```swift
    /// // User viewed thoughts stream
    /// await manager.clearUnreadCount(forStream: "thoughts")
    /// ```
    public func clearUnreadCount(forStream streamId: String) {
        unreadCounts[streamId] = 0
    }

    // MARK: - Testing Support

    /// Gets all active stream IDs with non-empty buffers.
    ///
    /// Useful for debugging and testing to see which streams have content.
    ///
    /// - Returns: Array of stream IDs that have messages
    ///
    /// **Note**: This is exposed for testing purposes and should not be used
    /// in production code outside of debugging scenarios.
    internal func activeStreams() -> [String] {
        return Array(buffers.keys.filter { !(buffers[$0]?.isEmpty ?? true) })
    }

    /// Gets the current buffer size for a specific stream.
    ///
    /// Useful for testing buffer pruning behavior.
    ///
    /// - Parameter streamId: The stream identifier to query
    /// - Returns: Number of messages currently in buffer
    ///
    /// **Note**: This is exposed for testing purposes and should not be used
    /// in production code (use `messages(forStream:).count` instead).
    internal func bufferSize(forStream streamId: String) -> Int {
        return buffers[streamId]?.count ?? 0
    }
}
