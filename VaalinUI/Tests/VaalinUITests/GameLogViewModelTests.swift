// ABOUTME: Tests for GameLogViewModel command echo functionality

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for GameLogViewModel command echo functionality
/// Validates command echoing behavior per Issue #28 acceptance criteria
@MainActor
struct GameLogViewModelTests {

    // MARK: - Command Echo Tests

    /// Test that commands are echoed to game log with prefix
    ///
    /// Acceptance Criteria:
    /// - Commands echoed with `›` prefix
    /// - Echo happens before command sent to server
    @Test func test_commandEcho() async throws {
        let viewModel = GameLogViewModel()

        // Initially empty
        #expect(viewModel.messages.isEmpty)

        // Echo a command
        await viewModel.echoCommand("look", prefix: "›")

        // Verify message was added
        #expect(viewModel.messages.count == 1)

        let message = viewModel.messages[0]
        let text = String(message.attributedText.characters)

        // Verify content includes prefix and command
        #expect(text.contains("›"))
        #expect(text.contains("look"))
    }

    /// Test that echo uses correct prefix
    ///
    /// Acceptance Criteria:
    /// - Commands echoed with `›` prefix (default)
    /// - Prefix is configurable
    @Test func test_echoPrefix() async throws {
        let viewModel = GameLogViewModel()

        // Test default prefix
        await viewModel.echoCommand("north")
        #expect(viewModel.messages.count == 1)
        let defaultText = String(viewModel.messages[0].attributedText.characters)
        #expect(defaultText.contains("›"))
        #expect(defaultText.contains("north"))

        // Test custom prefix
        await viewModel.echoCommand("south", prefix: ">")
        #expect(viewModel.messages.count == 2)
        let customText = String(viewModel.messages[1].attributedText.characters)
        #expect(customText.contains(">"))
        #expect(customText.contains("south"))
    }

    /// Test that echoed commands are dimmed/styled to distinguish from game output
    ///
    /// Acceptance Criteria:
    /// - Dimmed/styled to distinguish from game output
    @Test func test_echoStyling() async throws {
        let viewModel = GameLogViewModel()

        await viewModel.echoCommand("cast 118", prefix: "›")

        #expect(viewModel.messages.count == 1)
        let message = viewModel.messages[0]

        // Verify attributedText has secondary foreground color (dimmed)
        // We check for the presence of foregroundColor attribute
        let attributedText = message.attributedText
        #expect(!attributedText.runs.isEmpty)

        // At least one run should have foregroundColor attribute set
        let hasForegroundColor = attributedText.runs.contains { run in
            run.attributes.foregroundColor != nil
        }
        #expect(hasForegroundColor)
    }

    /// Test that command echoes don't belong to a stream
    ///
    /// Command echoes are user-generated output, not game output,
    /// so they shouldn't be associated with any stream ID
    @Test func test_echoNoStream() async throws {
        let viewModel = GameLogViewModel()

        await viewModel.echoCommand("look", prefix: "›")

        #expect(viewModel.messages.count == 1)
        let message = viewModel.messages[0]

        // Verify no stream ID
        #expect(message.streamID == nil)
    }

    /// Test that command echoes respect buffer size limit
    ///
    /// Ensures echo messages don't break buffer management
    @Test func test_echoBufferLimit() async throws {
        let viewModel = GameLogViewModel()

        // Echo many commands (more than buffer size would be impractical for test,
        // so we just verify the mechanism works)
        for i in 0..<10 {
            await viewModel.echoCommand("look \(i)", prefix: "›")
        }

        // All messages should be present (below buffer limit)
        #expect(viewModel.messages.count == 10)

        // Verify messages are in order
        let lastMessage = String(viewModel.messages[9].attributedText.characters)
        #expect(lastMessage.contains("look 9"))
    }

    /// Test that command echoes include timestamps
    ///
    /// Each echo should have an associated timestamp for display purposes
    @Test func test_echoTimestamp() async throws {
        let viewModel = GameLogViewModel()

        let beforeEcho = Date()
        await viewModel.echoCommand("look", prefix: "›")
        let afterEcho = Date()

        #expect(viewModel.messages.count == 1)
        let message = viewModel.messages[0]

        // Verify timestamp is within expected range
        #expect(message.timestamp >= beforeEcho)
        #expect(message.timestamp <= afterEcho)
    }

    /// Test that empty commands can be echoed
    ///
    /// Edge case: ensure empty string doesn't crash
    @Test func test_echoEmptyCommand() async throws {
        let viewModel = GameLogViewModel()

        await viewModel.echoCommand("", prefix: "›")

        #expect(viewModel.messages.count == 1)
        let text = String(viewModel.messages[0].attributedText.characters)
        #expect(text.contains("›"))
    }

    /// Test that special characters in commands are handled correctly
    ///
    /// Commands may contain quotes, special symbols, etc.
    @Test func test_echoSpecialCharacters() async throws {
        let viewModel = GameLogViewModel()

        let specialCommand = "say \"Hello, world! #test @user\""
        await viewModel.echoCommand(specialCommand, prefix: "›")

        #expect(viewModel.messages.count == 1)
        let text = String(viewModel.messages[0].attributedText.characters)
        #expect(text.contains(specialCommand))
        #expect(text.contains("\""))
        #expect(text.contains("#"))
        #expect(text.contains("@"))
    }
}
