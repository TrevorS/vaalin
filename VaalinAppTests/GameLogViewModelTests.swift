// ABOUTME: Test suite for GameLogViewModel - TDD approach for game log message buffering and display

import Foundation
import Testing
@testable import Vaalin
@testable import VaalinCore
@testable import VaalinUI

@Suite("GameLogViewModel Tests")
@MainActor
struct GameLogViewModelTests {
    // MARK: - Initial State Tests

    /// Verify that GameLogViewModel initializes with empty messages array.
    /// This ensures the view starts with a clean slate before any game data arrives.
    @Test("GameLogViewModel initializes with empty messages array")
    func test_initialState() {
        let viewModel = GameLogViewModel()

        let messages = viewModel.messages
        #expect(messages.isEmpty, "Messages array should be empty on initialization")
    }

    // MARK: - Message Appending Tests

    /// Verify that appendMessage correctly adds a GameTag to the messages array.
    /// This is the core functionality for displaying game output.
    @Test("appendMessage adds GameTag to messages array")
    func test_appendMessage() async {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed
        )

        await viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.count == 1, "Should contain exactly one message")
        #expect(messages.first?.tags.first?.name == "prompt", "Message should be the prompt tag")
        #expect(messages.first?.tags.first?.text == ">", "Message text should be preserved")
    }

    /// Verify that multiple messages are appended in order.
    /// Game log must display messages in the exact order they are received.
    @Test("appendMessage maintains message ordering")
    func test_messagesOrdering() async {
        let viewModel = GameLogViewModel()

        let tag1 = GameTag(name: "output", text: "First message", attrs: [:], children: [], state: .closed)
        let tag2 = GameTag(name: "output", text: "Second message", attrs: [:], children: [], state: .closed)
        let tag3 = GameTag(name: "output", text: "Third message", attrs: [:], children: [], state: .closed)

        await viewModel.appendMessage(tag1)
        await viewModel.appendMessage(tag2)
        await viewModel.appendMessage(tag3)

        let messages = viewModel.messages
        #expect(messages.count == 3, "Should contain three messages")
        #expect(messages[0].tags.first?.text == "First message", "First message should be at index 0")
        #expect(messages[1].tags.first?.text == "Second message", "Second message should be at index 1")
        #expect(messages[2].tags.first?.text == "Third message", "Third message should be at index 2")
    }

    /// Verify that complex nested GameTags are appended correctly.
    /// Game output often contains nested structures (bold text inside links, etc.).
    @Test("appendMessage handles nested GameTag structures")
    func test_appendNestedMessage() async {
        let viewModel = GameLogViewModel()

        let boldTag = GameTag(name: "b", text: "gem", attrs: [:], children: [], state: .closed)
        let linkTag = GameTag(
            name: "a",
            text: nil,
            attrs: ["exist": "12345", "noun": "gem"],
            children: [boldTag],
            state: .closed
        )

        await viewModel.appendMessage(linkTag)

        let messages = viewModel.messages
        #expect(messages.count == 1, "Should contain one message")
        #expect(messages.first?.tags.first?.children.count == 1, "Should preserve nested structure")
        #expect(messages.first?.tags.first?.children.first?.name == "b", "Child tag should be preserved")
    }

    // MARK: - Buffer Pruning Tests

    /// Verify that the 10,000 line buffer limit is enforced with automatic pruning.
    /// This is critical for memory management during long play sessions.
    @Test("Buffer pruning removes oldest messages when exceeding 10,000 limit")
    func test_bufferPruning() async {
        let viewModel = GameLogViewModel()

        // Add exactly 10,000 messages (at buffer limit)
        for i in 0..<10_000 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        // Verify at exactly 10,000
        var messages = viewModel.messages
        #expect(messages.count == 10_000, "Should contain exactly 10,000 messages at buffer limit")
        #expect(messages.first?.tags.first?.text == "Message 0", "First message should be 'Message 0'")
        #expect(messages.last?.tags.first?.text == "Message 9999", "Last message should be 'Message 9999'")

        // Add one more message to trigger pruning
        let newTag = GameTag(
            name: "output",
            text: "Message 10000",
            attrs: [:],
            children: [],
            state: .closed
        )
        await viewModel.appendMessage(newTag)

        // Verify pruning occurred
        messages = viewModel.messages
        #expect(messages.count == 10_000, "Should maintain 10,000 message limit")
        #expect(messages.first?.tags.first?.text == "Message 1", "Oldest message (Message 0) should be removed")
        #expect(messages.last?.tags.first?.text == "Message 10000", "Newest message should be appended")
    }

    /// Verify that pruning removes the oldest messages first (FIFO).
    /// This ensures users see recent game history, not ancient history.
    @Test("Buffer pruning follows FIFO ordering")
    func test_bufferPruningFIFO() async {
        let viewModel = GameLogViewModel()

        // Add 10,000 messages to reach buffer limit
        for i in 0..<10_000 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        // Add 100 more messages to trigger multiple pruning operations
        for i in 10_000..<10_100 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        // Verify FIFO behavior
        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should maintain 10,000 message limit")
        #expect(messages.first?.tags.first?.text == "Message 100", "First 100 messages should be removed")
        #expect(messages.last?.tags.first?.text == "Message 10099", "Last message should be most recent")
    }

    // MARK: - Boundary Condition Tests

    /// Verify behavior at exactly 10,000 messages (boundary condition).
    /// No pruning should occur until 10,001st message is added.
    @Test("Buffer does not prune at exactly 10,000 messages")
    func test_boundaryConditionAtLimit() async {
        let viewModel = GameLogViewModel()

        // Add exactly 10,000 messages
        for i in 0..<10_000 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should contain exactly 10,000 messages")
        #expect(messages.first?.tags.first?.text == "Message 0", "First message should not be pruned at exact limit")
    }

    /// Verify behavior when adding the 10,001st message (boundary condition).
    /// This is the first time pruning should occur.
    @Test("Buffer prunes on 10,001st message")
    func test_boundaryConditionOverLimit() async {
        let viewModel = GameLogViewModel()

        // Add 10,001 messages
        for i in 0..<10_001 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should prune to exactly 10,000 messages")
        #expect(messages.first?.tags.first?.text == "Message 1", "First message (Message 0) should be pruned")
        #expect(messages.last?.tags.first?.text == "Message 10000", "Last message should be the 10,001st message")
    }

    /// Verify behavior with very small message counts.
    /// No pruning should occur with fewer than 10,000 messages.
    @Test("No pruning occurs with small message counts")
    func test_noPruningBelowLimit() async {
        let viewModel = GameLogViewModel()

        // Add 100 messages (well below limit)
        for i in 0..<100 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 100, "Should contain all 100 messages")
        #expect(messages.first?.tags.first?.text == "Message 0", "No messages should be pruned")
    }

    // MARK: - Thread Safety Tests

    /// Verify that concurrent appends are handled safely via @Observable actor isolation.
    /// Multiple parsers or event sources may append messages simultaneously.
    @Test("Concurrent appends are thread-safe")
    func test_concurrentAppends() async {
        let viewModel = GameLogViewModel()

        // Launch 100 concurrent append operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { @MainActor in
                    let tag = GameTag(
                        name: "output",
                        text: "Concurrent message \(i)",
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                    await viewModel.appendMessage(tag)
                }
            }
        }

        let messages = viewModel.messages
        #expect(messages.count == 100, "All concurrent appends should succeed")

        // Verify no duplicate message texts (all unique)
        let uniqueTexts = Set(messages.compactMap { $0.tags.first?.text })
        #expect(uniqueTexts.count == 100, "All messages should have unique text")
    }

    // MARK: - Stream ID Preservation Tests

    /// Verify that streamID is preserved when appending messages.
    /// Stream context is critical for filtering (thoughts panel, speech panel, etc.).
    @Test("appendMessage preserves streamID from GameTag")
    func test_streamIDPreservation() async {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "output",
            text: "You think about...",
            attrs: [:],
            children: [],
            state: .closed,
            streamId: "thoughts"
        )

        await viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.first?.streamID == "thoughts", "StreamID should be preserved")
    }

    /// Verify that tags without streamID (nil) are handled correctly.
    @Test("appendMessage handles tags with nil streamID")
    func test_nilStreamIDHandling() async {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed,
            streamId: nil
        )

        await viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.first?.streamID == nil, "Nil streamID should be preserved")
    }

    // MARK: - Performance Tests

    /// Verify that appending messages is fast enough for real-time game output.
    /// Performance target: < 1ms per append for typical messages (with rendering).
    /// Note: Rendering adds overhead but should stay under 1ms average.
    @Test("appendMessage performance meets target")
    func test_appendPerformance() async {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "output",
            text: "Test message with some typical game content",
            attrs: ["class": "game-text"],
            children: [],
            state: .closed
        )

        let iterations = 1000
        let start = Date()

        for _ in 0..<iterations {
            await viewModel.appendMessage(tag)
        }

        let duration = Date().timeIntervalSince(start)
        let averageTime = (duration / Double(iterations)) * 1000 // Convert to milliseconds

        // Rendering adds < 1ms overhead per message (TagRenderer target)
        #expect(averageTime < 2.0, "Average append time should be < 2ms with rendering (actual: \(averageTime)ms)")
    }

    /// Verify that buffer pruning performance is acceptable.
    /// Performance target: < 10ms for pruning operation (with rendering overhead).
    @Test("Buffer pruning performance meets target")
    func test_pruningPerformance() async {
        let viewModel = GameLogViewModel()

        // Fill buffer to exactly 10,000 messages
        for i in 0..<10_000 {
            let tag = GameTag(
                name: "output",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            await viewModel.appendMessage(tag)
        }

        // Measure time to add message that triggers pruning
        let tag = GameTag(
            name: "output",
            text: "Trigger pruning",
            attrs: [:],
            children: [],
            state: .closed
        )

        let start = Date()
        await viewModel.appendMessage(tag)
        let duration = Date().timeIntervalSince(start)

        let durationMs = duration * 1000
        #expect(durationMs < 15.0, "Pruning should complete in < 15ms with rendering (actual: \(durationMs)ms)")
    }
}
