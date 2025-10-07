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
    func test_appendMessage() {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed
        )

        viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.count == 1, "Should contain exactly one message")
        #expect(messages.first?.name == "prompt", "Message should be the prompt tag")
        #expect(messages.first?.text == ">", "Message text should be preserved")
    }

    /// Verify that multiple messages are appended in order.
    /// Game log must display messages in the exact order they are received.
    @Test("appendMessage maintains message ordering")
    func test_messagesOrdering() {
        let viewModel = GameLogViewModel()

        let tag1 = GameTag(name: "output", text: "First message", attrs: [:], children: [], state: .closed)
        let tag2 = GameTag(name: "output", text: "Second message", attrs: [:], children: [], state: .closed)
        let tag3 = GameTag(name: "output", text: "Third message", attrs: [:], children: [], state: .closed)

        viewModel.appendMessage(tag1)
        viewModel.appendMessage(tag2)
        viewModel.appendMessage(tag3)

        let messages = viewModel.messages
        #expect(messages.count == 3, "Should contain three messages")
        #expect(messages[0].text == "First message", "First message should be at index 0")
        #expect(messages[1].text == "Second message", "Second message should be at index 1")
        #expect(messages[2].text == "Third message", "Third message should be at index 2")
    }

    /// Verify that complex nested GameTags are appended correctly.
    /// Game output often contains nested structures (bold text inside links, etc.).
    @Test("appendMessage handles nested GameTag structures")
    func test_appendNestedMessage() {
        let viewModel = GameLogViewModel()

        let boldTag = GameTag(name: "b", text: "gem", attrs: [:], children: [], state: .closed)
        let linkTag = GameTag(
            name: "a",
            text: nil,
            attrs: ["exist": "12345", "noun": "gem"],
            children: [boldTag],
            state: .closed
        )

        viewModel.appendMessage(linkTag)

        let messages = viewModel.messages
        #expect(messages.count == 1, "Should contain one message")
        #expect(messages.first?.children.count == 1, "Should preserve nested structure")
        #expect(messages.first?.children.first?.name == "b", "Child tag should be preserved")
    }

    // MARK: - Buffer Pruning Tests

    /// Verify that the 10,000 line buffer limit is enforced with automatic pruning.
    /// This is critical for memory management during long play sessions.
    @Test("Buffer pruning removes oldest messages when exceeding 10,000 limit")
    func test_bufferPruning() {
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
            viewModel.appendMessage(tag)
        }

        // Verify at exactly 10,000
        var messages = viewModel.messages
        #expect(messages.count == 10_000, "Should contain exactly 10,000 messages at buffer limit")
        #expect(messages.first?.text == "Message 0", "First message should be 'Message 0'")
        #expect(messages.last?.text == "Message 9999", "Last message should be 'Message 9999'")

        // Add one more message to trigger pruning
        let newTag = GameTag(
            name: "output",
            text: "Message 10000",
            attrs: [:],
            children: [],
            state: .closed
        )
        viewModel.appendMessage(newTag)

        // Verify pruning occurred
        messages = viewModel.messages
        #expect(messages.count == 10_000, "Should maintain 10,000 message limit")
        #expect(messages.first?.text == "Message 1", "Oldest message (Message 0) should be removed")
        #expect(messages.last?.text == "Message 10000", "Newest message should be appended")
    }

    /// Verify that pruning removes the oldest messages first (FIFO).
    /// This ensures users see recent game history, not ancient history.
    @Test("Buffer pruning follows FIFO ordering")
    func test_bufferPruningFIFO() {
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
            viewModel.appendMessage(tag)
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
            viewModel.appendMessage(tag)
        }

        // Verify FIFO behavior
        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should maintain 10,000 message limit")
        #expect(messages.first?.text == "Message 100", "First 100 messages should be removed")
        #expect(messages.last?.text == "Message 10099", "Last message should be most recent")
    }

    // MARK: - Boundary Condition Tests

    /// Verify behavior at exactly 10,000 messages (boundary condition).
    /// No pruning should occur until 10,001st message is added.
    @Test("Buffer does not prune at exactly 10,000 messages")
    func test_boundaryConditionAtLimit() {
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
            viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should contain exactly 10,000 messages")
        #expect(messages.first?.text == "Message 0", "First message should not be pruned at exact limit")
    }

    /// Verify behavior when adding the 10,001st message (boundary condition).
    /// This is the first time pruning should occur.
    @Test("Buffer prunes on 10,001st message")
    func test_boundaryConditionOverLimit() {
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
            viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 10_000, "Should prune to exactly 10,000 messages")
        #expect(messages.first?.text == "Message 1", "First message (Message 0) should be pruned")
        #expect(messages.last?.text == "Message 10000", "Last message should be the 10,001st message")
    }

    /// Verify behavior with very small message counts.
    /// No pruning should occur with fewer than 10,000 messages.
    @Test("No pruning occurs with small message counts")
    func test_noPruningBelowLimit() {
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
            viewModel.appendMessage(tag)
        }

        let messages = viewModel.messages
        #expect(messages.count == 100, "Should contain all 100 messages")
        #expect(messages.first?.text == "Message 0", "No messages should be pruned")
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
                    viewModel.appendMessage(tag)
                }
            }
        }

        let messages = viewModel.messages
        #expect(messages.count == 100, "All concurrent appends should succeed")

        // Verify no duplicate message texts (all unique)
        let uniqueTexts = Set(messages.compactMap { $0.text })
        #expect(uniqueTexts.count == 100, "All messages should have unique text")
    }

    // MARK: - Stream ID Preservation Tests

    /// Verify that streamId is preserved when appending messages.
    /// Stream context is critical for filtering (thoughts panel, speech panel, etc.).
    @Test("appendMessage preserves streamId from GameTag")
    func test_streamIdPreservation() {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "output",
            text: "You think about...",
            attrs: [:],
            children: [],
            state: .closed,
            streamId: "thoughts"
        )

        viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.first?.streamId == "thoughts", "StreamId should be preserved")
    }

    /// Verify that tags without streamId (nil) are handled correctly.
    @Test("appendMessage handles tags with nil streamId")
    func test_nilStreamIdHandling() {
        let viewModel = GameLogViewModel()

        let tag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed,
            streamId: nil
        )

        viewModel.appendMessage(tag)

        let messages = viewModel.messages
        #expect(messages.first?.streamId == nil, "Nil streamId should be preserved")
    }

    // MARK: - Performance Tests

    /// Verify that appending messages is fast enough for real-time game output.
    /// Performance target: < 1ms per append for typical messages.
    @Test("appendMessage performance meets target")
    func test_appendPerformance() {
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
            viewModel.appendMessage(tag)
        }

        let duration = Date().timeIntervalSince(start)
        let averageTime = (duration / Double(iterations)) * 1000 // Convert to milliseconds

        #expect(averageTime < 1.0, "Average append time should be < 1ms (actual: \(averageTime)ms)")
    }

    /// Verify that buffer pruning performance is acceptable.
    /// Performance target: < 10ms for pruning operation.
    @Test("Buffer pruning performance meets target")
    func test_pruningPerformance() {
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
            viewModel.appendMessage(tag)
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
        viewModel.appendMessage(tag)
        let duration = Date().timeIntervalSince(start)

        let durationMs = duration * 1000
        #expect(durationMs < 10.0, "Pruning should complete in < 10ms (actual: \(durationMs)ms)")
    }
}
