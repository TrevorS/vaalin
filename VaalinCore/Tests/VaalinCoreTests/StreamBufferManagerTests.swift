// ABOUTME: Tests for StreamBufferManager actor - thread-safe stream buffer management with circular buffers

import Foundation
import Testing
@testable import VaalinCore

/// Comprehensive test suite for StreamBufferManager actor.
///
/// Tests verify:
/// - Message appending to stream-specific buffers
/// - Automatic pruning when exceeding 10,000 line capacity
/// - Unread count tracking and clearing
/// - Multiple independent stream buffers
/// - Thread safety with concurrent access
/// - Graceful handling of non-existent streams
@Suite("StreamBufferManager Tests")
struct StreamBufferManagerTests {
    // MARK: - Basic Functionality

    /// Test appending messages to a specific stream buffer.
    ///
    /// Verifies that messages are correctly added to the specified stream's buffer
    /// and can be retrieved in the order they were added.
    @Test func test_addToStreamBuffer() async throws {
        let manager = StreamBufferManager()

        // Create test messages
        let message1 = Message(
            timestamp: Date(),
            attributedText: AttributedString("First message"),
            tags: [],
            streamID: "thoughts"
        )
        let message2 = Message(
            timestamp: Date(),
            attributedText: AttributedString("Second message"),
            tags: [],
            streamID: "thoughts"
        )

        // Append messages
        await manager.append(message1, toStream: "thoughts")
        await manager.append(message2, toStream: "thoughts")

        // Verify messages in buffer
        let messages = await manager.messages(forStream: "thoughts")
        #expect(messages.count == 2)
        #expect(messages[0].attributedText == AttributedString("First message"))
        #expect(messages[1].attributedText == AttributedString("Second message"))
    }

    // MARK: - Buffer Pruning

    /// Test automatic buffer pruning when exceeding 10,000 line capacity.
    ///
    /// Verifies FIFO (First-In-First-Out) behavior: oldest messages are removed
    /// when buffer exceeds maximum size.
    @Test func test_bufferPruning() async throws {
        let manager = StreamBufferManager()

        // Add 10,001 messages to trigger pruning
        for i in 0..<10_001 {
            let message = Message(
                timestamp: Date(),
                attributedText: AttributedString("Message \(i)"),
                tags: [],
                streamID: "thoughts"
            )
            await manager.append(message, toStream: "thoughts")
        }

        // Verify buffer size is capped at 10,000
        let messages = await manager.messages(forStream: "thoughts")
        #expect(messages.count == 10_000)

        // Verify oldest message was removed (FIFO)
        // First message should be "Message 1", not "Message 0"
        #expect(messages.first?.attributedText == AttributedString("Message 1"))

        // Verify newest message is preserved
        #expect(messages.last?.attributedText == AttributedString("Message 10000"))
    }

    // MARK: - Unread Count Tracking

    /// Test unread count tracking for stream buffers.
    ///
    /// Verifies that unread count increments when messages are added
    /// and starts at 0 for new streams.
    @Test func test_unreadCount() async throws {
        let manager = StreamBufferManager()

        // Initial unread count should be 0
        let initialCount = await manager.unreadCount(forStream: "thoughts")
        #expect(initialCount == 0)

        // Add messages
        for i in 0..<5 {
            let message = Message(
                timestamp: Date(),
                attributedText: AttributedString("Message \(i)"),
                tags: [],
                streamID: "thoughts"
            )
            await manager.append(message, toStream: "thoughts")
        }

        // Verify unread count incremented
        let unreadCount = await manager.unreadCount(forStream: "thoughts")
        #expect(unreadCount == 5)
    }

    /// Test clearing unread count when stream is viewed.
    ///
    /// Verifies that clearing unread count resets to 0 and doesn't affect
    /// other streams or the buffer contents.
    @Test func test_clearUnread() async throws {
        let manager = StreamBufferManager()

        // Add messages to thoughts stream
        for i in 0..<3 {
            let message = Message(
                timestamp: Date(),
                attributedText: AttributedString("Thought \(i)"),
                tags: [],
                streamID: "thoughts"
            )
            await manager.append(message, toStream: "thoughts")
        }

        // Add messages to speech stream
        for i in 0..<2 {
            let message = Message(
                timestamp: Date(),
                attributedText: AttributedString("Speech \(i)"),
                tags: [],
                streamID: "speech"
            )
            await manager.append(message, toStream: "speech")
        }

        // Verify initial unread counts
        let thoughtsUnread = await manager.unreadCount(forStream: "thoughts")
        let speechUnread = await manager.unreadCount(forStream: "speech")
        #expect(thoughtsUnread == 3)
        #expect(speechUnread == 2)

        // Clear thoughts unread count
        await manager.clearUnreadCount(forStream: "thoughts")

        // Verify thoughts unread is 0
        let thoughtsAfterClear = await manager.unreadCount(forStream: "thoughts")
        #expect(thoughtsAfterClear == 0)

        // Verify speech unread unchanged
        let speechAfterClear = await manager.unreadCount(forStream: "speech")
        #expect(speechAfterClear == 2)

        // Verify messages still in buffer
        let thoughtsMessages = await manager.messages(forStream: "thoughts")
        #expect(thoughtsMessages.count == 3)
    }

    // MARK: - Multiple Streams

    /// Test independent buffers for multiple streams.
    ///
    /// Verifies that each stream has its own independent buffer and
    /// messages don't leak between streams.
    @Test func test_multipleStreams() async throws {
        let manager = StreamBufferManager()

        // Add messages to different streams
        let thoughtMessage = Message(
            timestamp: Date(),
            attributedText: AttributedString("A thought"),
            tags: [],
            streamID: "thoughts"
        )
        let speechMessage = Message(
            timestamp: Date(),
            attributedText: AttributedString("A speech"),
            tags: [],
            streamID: "speech"
        )
        let combatMessage = Message(
            timestamp: Date(),
            attributedText: AttributedString("A combat"),
            tags: [],
            streamID: "combat"
        )

        await manager.append(thoughtMessage, toStream: "thoughts")
        await manager.append(speechMessage, toStream: "speech")
        await manager.append(combatMessage, toStream: "combat")

        // Verify each stream has only its own message
        let thoughtsMessages = await manager.messages(forStream: "thoughts")
        let speechMessages = await manager.messages(forStream: "speech")
        let combatMessages = await manager.messages(forStream: "combat")

        #expect(thoughtsMessages.count == 1)
        #expect(speechMessages.count == 1)
        #expect(combatMessages.count == 1)

        #expect(thoughtsMessages[0].attributedText == AttributedString("A thought"))
        #expect(speechMessages[0].attributedText == AttributedString("A speech"))
        #expect(combatMessages[0].attributedText == AttributedString("A combat"))

        // Verify unread counts are independent
        let thoughtsUnread = await manager.unreadCount(forStream: "thoughts")
        let speechUnread = await manager.unreadCount(forStream: "speech")
        let combatUnread = await manager.unreadCount(forStream: "combat")

        #expect(thoughtsUnread == 1)
        #expect(speechUnread == 1)
        #expect(combatUnread == 1)
    }

    /// Test retrieving messages from a specific stream buffer.
    ///
    /// Verifies that getting messages for a stream returns correct messages
    /// in chronological order.
    @Test func test_getMessages() async throws {
        let manager = StreamBufferManager()

        // Create messages with specific timestamps for ordering
        let timestamp1 = Date()
        let timestamp2 = timestamp1.addingTimeInterval(1)
        let timestamp3 = timestamp1.addingTimeInterval(2)

        let message1 = Message(
            timestamp: timestamp1,
            attributedText: AttributedString("First"),
            tags: [],
            streamID: "thoughts"
        )
        let message2 = Message(
            timestamp: timestamp2,
            attributedText: AttributedString("Second"),
            tags: [],
            streamID: "thoughts"
        )
        let message3 = Message(
            timestamp: timestamp3,
            attributedText: AttributedString("Third"),
            tags: [],
            streamID: "thoughts"
        )

        // Append in order
        await manager.append(message1, toStream: "thoughts")
        await manager.append(message2, toStream: "thoughts")
        await manager.append(message3, toStream: "thoughts")

        // Verify messages returned in correct order
        let messages = await manager.messages(forStream: "thoughts")
        #expect(messages.count == 3)
        #expect(messages[0].timestamp == timestamp1)
        #expect(messages[1].timestamp == timestamp2)
        #expect(messages[2].timestamp == timestamp3)
    }

    // MARK: - Edge Cases

    /// Test graceful handling of non-existent streams.
    ///
    /// Verifies that querying a stream that doesn't exist returns empty results
    /// without crashing or errors.
    @Test func test_emptyBuffer() async throws {
        let manager = StreamBufferManager()

        // Query non-existent stream
        let messages = await manager.messages(forStream: "nonexistent")
        let unreadCount = await manager.unreadCount(forStream: "nonexistent")

        // Verify empty results
        #expect(messages.isEmpty)
        #expect(unreadCount == 0)

        // Clearing unread for non-existent stream should not crash
        await manager.clearUnreadCount(forStream: "nonexistent")

        // Verify still empty after clear
        let unreadAfterClear = await manager.unreadCount(forStream: "nonexistent")
        #expect(unreadAfterClear == 0)
    }

    // MARK: - Thread Safety

    /// Test concurrent access to stream buffers from multiple tasks.
    ///
    /// Verifies that the actor provides thread-safe access when multiple
    /// tasks append messages and query buffers concurrently.
    @Test func test_concurrentAccess() async throws {
        let manager = StreamBufferManager()

        // Concurrently append 100 messages from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let message = Message(
                        timestamp: Date(),
                        attributedText: AttributedString("Message \(i)"),
                        tags: [],
                        streamID: "thoughts"
                    )
                    await manager.append(message, toStream: "thoughts")
                }
            }
        }

        // Verify all messages were added
        let messages = await manager.messages(forStream: "thoughts")
        #expect(messages.count == 100)

        // Verify unread count matches
        let unreadCount = await manager.unreadCount(forStream: "thoughts")
        #expect(unreadCount == 100)
    }
}
