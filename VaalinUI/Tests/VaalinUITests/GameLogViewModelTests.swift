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

    // MARK: - Consecutive Prompt Deduplication Tests

    /// Test that consecutive identical prompts are deduplicated
    ///
    /// When the server sends the same prompt multiple times in a row,
    /// only the first one should appear in the game log to reduce visual clutter.
    @Test func test_consecutiveIdenticalPromptsDeduped() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let prompt1 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let prompt3 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)

        // Append first prompt - should be added
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)
        let text1 = String(viewModel.messages[0].attributedText.characters)
        #expect(text1.contains("s>"))

        // Append duplicate prompt - should be skipped
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 1) // Still only 1 message

        // Append another duplicate - should be skipped
        await viewModel.appendMessage([prompt3])
        #expect(viewModel.messages.count == 1) // Still only 1 message
    }

    /// Test that prompt deduplication resets after non-prompt content
    ///
    /// When content appears between prompts, the same prompt can appear again
    /// because it's contextually different (e.g., after a command response).
    @Test func test_promptDeduplicationResetsAfterContent() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let prompt1 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let content = GameTag(name: ":text", text: "You swing at the troll!", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)

        // Append first prompt
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)

        // Append content - resets prompt tracking
        await viewModel.appendMessage([content])
        #expect(viewModel.messages.count == 2)

        // Append same prompt again - should be added (not deduped)
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 3)

        // Verify both prompts are present
        let text1 = String(viewModel.messages[0].attributedText.characters)
        let text2 = String(viewModel.messages[1].attributedText.characters)
        let text3 = String(viewModel.messages[2].attributedText.characters)
        #expect(text1.contains("s>"))
        #expect(text2.contains("You swing"))
        #expect(text3.contains("s>"))
    }

    /// Test that different prompts are not deduplicated
    ///
    /// Only consecutive identical prompts should be deduped.
    /// Different prompt texts should always be displayed.
    @Test func test_differentPromptsNotDeduped() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let prompt1 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
        let prompt3 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)

        // Append first prompt
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)

        // Append different prompt - should be added
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 2)

        // Append first prompt again - should be added (different from previous)
        await viewModel.appendMessage([prompt3])
        #expect(viewModel.messages.count == 3)

        // Verify all prompts are present
        let text1 = String(viewModel.messages[0].attributedText.characters)
        let text2 = String(viewModel.messages[1].attributedText.characters)
        let text3 = String(viewModel.messages[2].attributedText.characters)
        #expect(text1.contains("s>"))
        #expect(text2.contains(">"))
        #expect(text3.contains("s>"))
    }

    /// Test that mixed tags (prompt + content) reset deduplication
    ///
    /// If tags array contains both prompt and non-prompt tags,
    /// it should be treated as content and reset prompt tracking.
    @Test func test_mixedTagsResetDeduplication() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let prompt1 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let mixedPrompt = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)
        let mixedContent = GameTag(name: ":text", text: "You are ready.", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)

        // Append first prompt
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)

        // Append mixed batch (prompt + content) - should reset tracking
        await viewModel.appendMessage([mixedPrompt, mixedContent])
        #expect(viewModel.messages.count == 2)

        // Append same prompt again - should be added (tracking was reset)
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 3)

        // Verify prompts are present
        let text1 = String(viewModel.messages[0].attributedText.characters)
        let text3 = String(viewModel.messages[2].attributedText.characters)
        #expect(text1.contains("s>"))
        #expect(text3.contains("s>"))
    }

    /// Test that only prompt-only tags are deduplicated
    ///
    /// Non-prompt tags should never be deduplicated, even if they appear consecutively.
    @Test func test_onlyPromptTagsDeduped() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let content1 = GameTag(name: ":text", text: "The troll roars!", attrs: [:], children: [], state: .closed)
        let content2 = GameTag(name: ":text", text: "The troll roars!", attrs: [:], children: [], state: .closed)
        let content3 = GameTag(name: ":text", text: "The troll roars!", attrs: [:], children: [], state: .closed)

        // Append same content three times - should all be added
        await viewModel.appendMessage([content1])
        await viewModel.appendMessage([content2])
        await viewModel.appendMessage([content3])

        #expect(viewModel.messages.count == 3)

        // Verify all three are present
        for message in viewModel.messages {
            let text = String(message.attributedText.characters)
            #expect(text.contains("The troll roars!"))
        }
    }

    /// Test that prompt deduplication works with complex text content
    ///
    /// Prompts may contain HTML entities, whitespace, special characters, etc.
    /// Deduplication should handle these correctly.
    @Test func test_promptDeduplicationComplexText() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let prompt1 = GameTag(name: "prompt", text: "s&gt;", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: "s&gt;", attrs: [:], children: [], state: .closed)
        let prompt3 = GameTag(name: "prompt", text: "s>", attrs: [:], children: [], state: .closed)

        // Append first prompt with HTML entity
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)

        // Append duplicate with same HTML entity - should be deduped
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 1)

        // Append prompt with different text - should be added
        await viewModel.appendMessage([prompt3])
        #expect(viewModel.messages.count == 2)
    }

    /// Test that prompt deduplication handles nested tag structures
    ///
    /// Prompts with children should have text extracted recursively for comparison.
    @Test func test_promptDeduplicationWithChildren() async throws {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())
        await viewModel.waitForTheme()

        let child1 = GameTag(name: ":text", text: ">", attrs: [:], children: [], state: .closed)
        let prompt1 = GameTag(name: "prompt", text: "s", attrs: [:], children: [child1], state: .closed)

        let child2 = GameTag(name: ":text", text: ">", attrs: [:], children: [], state: .closed)
        let prompt2 = GameTag(name: "prompt", text: "s", attrs: [:], children: [child2], state: .closed)

        // Append first prompt with nested structure
        await viewModel.appendMessage([prompt1])
        #expect(viewModel.messages.count == 1)

        // Append duplicate with same nested structure - should be deduped
        await viewModel.appendMessage([prompt2])
        #expect(viewModel.messages.count == 1)
    }
}
