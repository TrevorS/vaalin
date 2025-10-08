// ABOUTME: Tests for HandsPanelViewModel EventBus subscription and hands state updates

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for HandsPanelViewModel hands panel state functionality
/// Validates EventBus subscription and hands/spell state updates per Issue #35 acceptance criteria
@MainActor
struct HandsPanelViewModelTests {

    // MARK: - Initialization Tests

    /// Test that HandsPanelViewModel initializes with default values
    ///
    /// Acceptance Criteria:
    /// - leftHand defaults to "Empty"
    /// - rightHand defaults to "Empty"
    /// - preparedSpell defaults to "None"
    @Test func test_defaults() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults
        #expect(viewModel.leftHand == "Empty")
        #expect(viewModel.rightHand == "Empty")
        #expect(viewModel.preparedSpell == "None")
    }

    /// Test that HandsPanelViewModel initializes correctly
    ///
    /// Acceptance Criteria:
    /// - Initializes with EventBus reference
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults match acceptance criteria
        #expect(viewModel.leftHand == "Empty")
        #expect(viewModel.rightHand == "Empty")
        #expect(viewModel.preparedSpell == "None")
    }

    // MARK: - EventBus Subscription Tests

    /// Test that HandsPanelViewModel subscribes to all hands events
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/left" event on initialization
    /// - Subscribes to "metadata/right" event on initialization
    /// - Subscribes to "metadata/spell" event on initialization
    @Test func test_subscribesToHandsEvents() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify all subscriptions exist
        let leftHandlerCount = await eventBus.handlerCount(for: "metadata/left")
        let rightHandlerCount = await eventBus.handlerCount(for: "metadata/right")
        let spellHandlerCount = await eventBus.handlerCount(for: "metadata/spell")

        #expect(leftHandlerCount == 1)
        #expect(rightHandlerCount == 1)
        #expect(spellHandlerCount == 1)
    }

    // MARK: - Left Hand Update Tests

    /// Test that HandsPanelViewModel updates leftHand when receiving metadata/left events
    ///
    /// Acceptance Criteria:
    /// - Updates leftHand when "metadata/left" event is published
    /// - Extracts text from tag.children[0].text (per Illthorn reference)
    @Test func test_leftHandUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.leftHand == "Empty")

        // Publish a left hand event with child tag containing item name
        let itemTag = GameTag(
            name: "item",
            text: "steel broadsword",
            attrs: [:],
            children: [],
            state: .closed
        )
        let leftTag = GameTag(
            name: "left",
            text: nil,
            attrs: [:],
            children: [itemTag],
            state: .closed
        )

        await eventBus.publish("metadata/left", data: leftTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify left hand updated
        #expect(viewModel.leftHand == "steel broadsword")
    }

    /// Test that leftHand handles empty hand (no children)
    ///
    /// Acceptance Criteria:
    /// - Falls back to "Empty" when tag has no children
    @Test func test_leftHandEmpty() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let itemTag = GameTag(
            name: "item",
            text: "steel broadsword",
            attrs: [:],
            children: [],
            state: .closed
        )
        let leftTag = GameTag(
            name: "left",
            text: nil,
            attrs: [:],
            children: [itemTag],
            state: .closed
        )
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish empty hand event (no children)
        let emptyTag = GameTag(
            name: "left",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/left", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify falls back to "Empty"
        #expect(viewModel.leftHand == "Empty")
    }

    // MARK: - Right Hand Update Tests

    /// Test that HandsPanelViewModel updates rightHand when receiving metadata/right events
    ///
    /// Acceptance Criteria:
    /// - Updates rightHand when "metadata/right" event is published
    /// - Extracts text from tag.children[0].text (per Illthorn reference)
    @Test func test_rightHandUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.rightHand == "Empty")

        // Publish a right hand event with child tag containing item name
        let itemTag = GameTag(
            name: "item",
            text: "wooden shield",
            attrs: [:],
            children: [],
            state: .closed
        )
        let rightTag = GameTag(
            name: "right",
            text: nil,
            attrs: [:],
            children: [itemTag],
            state: .closed
        )

        await eventBus.publish("metadata/right", data: rightTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify right hand updated
        #expect(viewModel.rightHand == "wooden shield")
    }

    /// Test that rightHand handles empty hand (no children)
    ///
    /// Acceptance Criteria:
    /// - Falls back to "Empty" when tag has no children
    @Test func test_rightHandEmpty() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let itemTag = GameTag(
            name: "item",
            text: "wooden shield",
            attrs: [:],
            children: [],
            state: .closed
        )
        let rightTag = GameTag(
            name: "right",
            text: nil,
            attrs: [:],
            children: [itemTag],
            state: .closed
        )
        await eventBus.publish("metadata/right", data: rightTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish empty hand event (no children)
        let emptyTag = GameTag(
            name: "right",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/right", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify falls back to "Empty"
        #expect(viewModel.rightHand == "Empty")
    }

    // MARK: - Spell Update Tests

    /// Test that HandsPanelViewModel updates preparedSpell when receiving metadata/spell events
    ///
    /// Acceptance Criteria:
    /// - Updates preparedSpell when "metadata/spell" event is published
    /// - Extracts text from tag.children[0].text (per Illthorn reference)
    @Test func test_spellUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value
        #expect(viewModel.preparedSpell == "None")

        // Publish a spell event with child tag containing spell name
        let spellTag = GameTag(
            name: "spell",
            text: "Fire Spirit",
            attrs: [:],
            children: [],
            state: .closed
        )
        let preparedTag = GameTag(
            name: "spell",
            text: nil,
            attrs: [:],
            children: [spellTag],
            state: .closed
        )

        await eventBus.publish("metadata/spell", data: preparedTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify prepared spell updated
        #expect(viewModel.preparedSpell == "Fire Spirit")
    }

    /// Test that preparedSpell handles no spell (no children)
    ///
    /// Acceptance Criteria:
    /// - Falls back to "None" when tag has no children
    @Test func test_spellEmpty() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Set a known value first
        let spellTag = GameTag(
            name: "spell",
            text: "Fire Spirit",
            attrs: [:],
            children: [],
            state: .closed
        )
        let preparedTag = GameTag(
            name: "spell",
            text: nil,
            attrs: [:],
            children: [spellTag],
            state: .closed
        )
        await eventBus.publish("metadata/spell", data: preparedTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Now publish empty spell event (no children)
        let emptyTag = GameTag(
            name: "spell",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/spell", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify falls back to "None"
        #expect(viewModel.preparedSpell == "None")
    }

    // MARK: - Multiple Updates Tests

    /// Test that HandsPanelViewModel handles multiple rapid updates
    ///
    /// Acceptance Criteria:
    /// - Handles rapid successive hand changes
    @Test func test_handlesMultipleUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple left hand events rapidly
        let items = ["sword", "axe", "dagger", "mace"]

        for item in items {
            let itemTag = GameTag(
                name: "item",
                text: item,
                attrs: [:],
                children: [],
                state: .closed
            )
            let leftTag = GameTag(
                name: "left",
                text: nil,
                attrs: [:],
                children: [itemTag],
                state: .closed
            )
            await eventBus.publish("metadata/left", data: leftTag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final value is set
        #expect(viewModel.leftHand == "mace")
    }

    /// Test that all three hands can be updated independently
    ///
    /// Acceptance Criteria:
    /// - Each hand field updates independently
    @Test func test_independentHandUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Update left hand
        let leftItem = GameTag(name: "item", text: "sword", attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [leftItem], state: .closed)
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update right hand
        let rightItem = GameTag(name: "item", text: "shield", attrs: [:], children: [], state: .closed)
        let rightTag = GameTag(name: "right", text: nil, attrs: [:], children: [rightItem], state: .closed)
        await eventBus.publish("metadata/right", data: rightTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update spell
        let spell = GameTag(name: "spell", text: "Fire Spirit", attrs: [:], children: [], state: .closed)
        let spellTag = GameTag(name: "spell", text: nil, attrs: [:], children: [spell], state: .closed)
        await eventBus.publish("metadata/spell", data: spellTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all three updated independently
        #expect(viewModel.leftHand == "sword")
        #expect(viewModel.rightHand == "shield")
        #expect(viewModel.preparedSpell == "Fire Spirit")
    }

    // MARK: - Nil/Empty Text Handling Tests

    /// Test that HandsPanelViewModel handles nil text in child tags
    ///
    /// Acceptance Criteria:
    /// - Falls back to default when child has nil text
    @Test func test_handlesNilText() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with child that has nil text
        let nilChild = GameTag(
            name: "item",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )
        let leftTag = GameTag(
            name: "left",
            text: nil,
            attrs: [:],
            children: [nilChild],
            state: .closed
        )
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify falls back to "Empty"
        #expect(viewModel.leftHand == "Empty")
    }

    /// Test that HandsPanelViewModel handles empty text in child tags
    ///
    /// Acceptance Criteria:
    /// - Falls back to default when child has empty text
    @Test func test_handlesEmptyText() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with child that has empty text
        let emptyChild = GameTag(
            name: "item",
            text: "",
            attrs: [:],
            children: [],
            state: .closed
        )
        let leftTag = GameTag(
            name: "left",
            text: nil,
            attrs: [:],
            children: [emptyChild],
            state: .closed
        )
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify falls back to "Empty"
        #expect(viewModel.leftHand == "Empty")
    }

    // MARK: - Lifecycle Tests

    /// Test that HandsPanelViewModel cleans up subscriptions on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from all events when deallocated
    @Test func test_unsubscribesOnDeinit() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = HandsPanelViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscriptions exist
            let leftCount = await eventBus.handlerCount(for: "metadata/left")
            let rightCount = await eventBus.handlerCount(for: "metadata/right")
            let spellCount = await eventBus.handlerCount(for: "metadata/spell")

            #expect(leftCount == 1)
            #expect(rightCount == 1)
            #expect(spellCount == 1)
        }

        // HandsPanelViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify all subscriptions were removed
        let leftCountAfter = await eventBus.handlerCount(for: "metadata/left")
        let rightCountAfter = await eventBus.handlerCount(for: "metadata/right")
        let spellCountAfter = await eventBus.handlerCount(for: "metadata/spell")

        #expect(leftCountAfter == 0)
        #expect(rightCountAfter == 0)
        #expect(spellCountAfter == 0)
    }

    /// Test that multiple HandsPanelViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = HandsPanelViewModel(eventBus: eventBus)
        let viewModel2 = HandsPanelViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let leftHandlerCount = await eventBus.handlerCount(for: "metadata/left")
        #expect(leftHandlerCount == 2)

        // Publish event
        let itemTag = GameTag(name: "item", text: "sword", attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.leftHand == "sword")
        #expect(viewModel2.leftHand == "sword")
    }

    // MARK: - Edge Cases

    /// Test that HandsPanelViewModel handles special characters in item names
    ///
    /// Acceptance Criteria:
    /// - Displays items with special characters correctly
    @Test func test_handlesSpecialCharacters() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let specialItem = "silver-edged longsword (enchanted)"
        let itemTag = GameTag(name: "item", text: specialItem, attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)

        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.leftHand == specialItem)
    }

    /// Test that HandsPanelViewModel handles Unicode in item names
    ///
    /// Acceptance Criteria:
    /// - Displays items with Unicode characters correctly
    @Test func test_handlesUnicode() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let unicodeItem = "龙剑 (Dragon Sword)"
        let itemTag = GameTag(name: "item", text: unicodeItem, attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)

        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.leftHand == unicodeItem)
    }

    /// Test that HandsPanelViewModel ignores tags with wrong name
    ///
    /// Acceptance Criteria:
    /// - Only responds to tags named "left", "right", or "spell"
    @Test func test_ignoresWrongTagName() async throws {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with wrong tag name to metadata/left
        let wrongTag = GameTag(
            name: "item",  // Wrong name - should be "left"
            text: "This should not update",
            attrs: [:],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/left", data: wrongTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify left hand unchanged (still default)
        #expect(viewModel.leftHand == "Empty")
    }
}
