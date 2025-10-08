// ABOUTME: Tests for PromptViewModel EventBus subscription and prompt text updates

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for PromptViewModel prompt display functionality
/// Validates EventBus subscription and prompt text updates per Issue #30 acceptance criteria
@MainActor
struct PromptViewModelTests {

    // MARK: - Initialization Tests

    /// Test that PromptViewModel initializes with default prompt
    ///
    /// Acceptance Criteria:
    /// - Default prompt is ">"
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify default prompt
        #expect(viewModel.promptText == ">")
    }

    // MARK: - EventBus Subscription Tests

    /// Test that PromptViewModel subscribes to metadata/prompt events
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/prompt" event on initialization
    @Test func test_subscribesToPromptEvents() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify subscription exists
        let handlerCount = await eventBus.handlerCount(for: "metadata/prompt")
        #expect(handlerCount == 1)
    }

    /// Test that PromptViewModel updates promptText when receiving events
    ///
    /// Acceptance Criteria:
    /// - Updates promptText when "metadata/prompt" event is published
    @Test func test_updatesPromptTextOnEvent() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default prompt
        #expect(viewModel.promptText == ">")

        // Publish a prompt event
        let promptTag = GameTag(
            name: "prompt",
            text: "You may now edit your spell.>",
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/prompt", data: promptTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify prompt text updated
        #expect(viewModel.promptText == "You may now edit your spell.>")
    }

    /// Test that PromptViewModel handles multiple prompt updates
    ///
    /// Acceptance Criteria:
    /// - Handles rapid successive prompt changes
    @Test func test_handlesMultiplePromptUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple prompt events
        let prompts = [
            "You may now edit your spell.>",
            "* >",
            "[Press ENTER to continue]",
            ">"
        ]

        for prompt in prompts {
            let tag = GameTag(
                name: "prompt",
                text: prompt,
                attrs: [:],
                children: [],
                state: .closed
            )
            await eventBus.publish("metadata/prompt", data: tag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final prompt is set
        #expect(viewModel.promptText == ">")
    }

    /// Test that PromptViewModel handles empty prompt text
    ///
    /// Acceptance Criteria:
    /// - Handles empty prompt gracefully (uses empty string)
    @Test func test_handlesEmptyPrompt() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with empty text
        let emptyTag = GameTag(
            name: "prompt",
            text: "",
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/prompt", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify empty prompt is set
        #expect(viewModel.promptText == "")
    }

    /// Test that PromptViewModel handles nil prompt text
    ///
    /// Acceptance Criteria:
    /// - Handles nil prompt text gracefully (keeps previous value)
    @Test func test_handlesNilPrompt() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known prompt first
        let validTag = GameTag(
            name: "prompt",
            text: "You may now edit your spell.>",
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/prompt", data: validTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Publish event with nil text
        let nilTag = GameTag(
            name: "prompt",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/prompt", data: nilTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify prompt remains unchanged (keeps previous value)
        #expect(viewModel.promptText == "You may now edit your spell.>")
    }

    // MARK: - Lifecycle Tests

    /// Test that PromptViewModel cleans up subscription on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from EventBus when deallocated
    @Test func test_unsubscribesOnDeinit() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = PromptViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscription exists
            let countBefore = await eventBus.handlerCount(for: "metadata/prompt")
            #expect(countBefore == 1)
        }

        // PromptViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify subscription was removed
        let countAfter = await eventBus.handlerCount(for: "metadata/prompt")
        #expect(countAfter == 0)
    }

    /// Test that multiple PromptViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = PromptViewModel(eventBus: eventBus)
        let viewModel2 = PromptViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let handlerCount = await eventBus.handlerCount(for: "metadata/prompt")
        #expect(handlerCount == 2)

        // Publish event
        let promptTag = GameTag(
            name: "prompt",
            text: "Custom prompt>",
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/prompt", data: promptTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.promptText == "Custom prompt>")
        #expect(viewModel2.promptText == "Custom prompt>")
    }

    // MARK: - Edge Cases

    /// Test that PromptViewModel handles special characters in prompt
    ///
    /// Acceptance Criteria:
    /// - Displays prompts with special characters correctly
    @Test func test_handlesSpecialCharacters() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        let specialPrompt = "[You may now edit your spell.] >> "
        let tag = GameTag(
            name: "prompt",
            text: specialPrompt,
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/prompt", data: tag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.promptText == specialPrompt)
    }

    /// Test that PromptViewModel handles Unicode in prompt
    ///
    /// Acceptance Criteria:
    /// - Displays prompts with Unicode characters correctly
    @Test func test_handlesUnicode() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        let unicodePrompt = "→ 你好 >"
        let tag = GameTag(
            name: "prompt",
            text: unicodePrompt,
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/prompt", data: tag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.promptText == unicodePrompt)
    }

    /// Test that PromptViewModel ignores prompts with wrong tag name
    ///
    /// Acceptance Criteria:
    /// - Only responds to tags named "prompt"
    @Test func test_ignoresWrongTagName() async throws {
        let eventBus = EventBus()
        let viewModel = PromptViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with wrong tag name
        let wrongTag = GameTag(
            name: "output",
            text: "This should not update the prompt",
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/prompt", data: wrongTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify prompt unchanged (still default)
        #expect(viewModel.promptText == ">")
    }
}
