// ABOUTME: Tests for VitalsPanelViewModel EventBus subscription and vitals state updates

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for VitalsPanelViewModel vitals panel state functionality
/// Validates EventBus subscription and vitals state updates per Issue #37 acceptance criteria
@MainActor
struct VitalsPanelViewModelTests {

    // MARK: - Initialization Tests

    /// Test that VitalsPanelViewModel initializes with default values
    ///
    /// Acceptance Criteria:
    /// - All progress bars default to nil (indeterminate state)
    /// - Stance defaults to "offensive"
    /// - Encumbrance defaults to "none"
    @Test func test_defaults() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults - progress bars start as nil (indeterminate)
        #expect(viewModel.health == nil)
        #expect(viewModel.mana == nil)
        #expect(viewModel.stamina == nil)
        #expect(viewModel.spirit == nil)
        #expect(viewModel.mind == nil)

        // Text fields have defaults
        #expect(viewModel.stance == "offensive")
        #expect(viewModel.encumbrance == "none")
    }

    /// Test that VitalsPanelViewModel initializes correctly
    ///
    /// Acceptance Criteria:
    /// - Initializes with EventBus reference
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults match acceptance criteria
        #expect(viewModel.health == nil)
        #expect(viewModel.mana == nil)
        #expect(viewModel.stamina == nil)
        #expect(viewModel.spirit == nil)
        #expect(viewModel.mind == nil)
        #expect(viewModel.stance == "offensive")
        #expect(viewModel.encumbrance == "none")
    }

    // MARK: - EventBus Subscription Tests

    /// Test that VitalsPanelViewModel subscribes to all vitals events
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/progressBar/health" event on initialization
    /// - Subscribes to "metadata/progressBar/mana" event on initialization
    /// - Subscribes to "metadata/progressBar/stamina" event on initialization
    /// - Subscribes to "metadata/progressBar/spirit" event on initialization
    /// - Subscribes to "metadata/progressBar/mindState" event on initialization
    /// - Subscribes to "metadata/progressBar/pbarStance" event on initialization
    /// - Subscribes to "metadata/progressBar/encumlevel" event on initialization
    @Test func test_subscribesToVitalsEvents() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify all subscriptions exist
        let healthCount = await eventBus.handlerCount(for: "metadata/progressBar/health")
        let manaCount = await eventBus.handlerCount(for: "metadata/progressBar/mana")
        let staminaCount = await eventBus.handlerCount(for: "metadata/progressBar/stamina")
        let spiritCount = await eventBus.handlerCount(for: "metadata/progressBar/spirit")
        let mindCount = await eventBus.handlerCount(for: "metadata/progressBar/mindState")
        let stanceCount = await eventBus.handlerCount(for: "metadata/progressBar/pbarStance")
        let encumbranceCount = await eventBus.handlerCount(for: "metadata/progressBar/encumlevel")

        #expect(healthCount == 1)
        #expect(manaCount == 1)
        #expect(staminaCount == 1)
        #expect(spiritCount == 1)
        #expect(mindCount == 1)
        #expect(stanceCount == 1)
        #expect(encumbranceCount == 1)
    }

    // MARK: - Health Update Tests

    /// Test that VitalsPanelViewModel updates health when receiving metadata/progressBar/health events
    ///
    /// Acceptance Criteria:
    /// - Updates health when "metadata/progressBar/health" event is published
    /// - Extracts percentage from tag.attrs["value"]
    @Test func test_healthBarUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default value (nil)
        #expect(viewModel.health == nil)

        // Publish a health event with percentage
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "75", "text": "75/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)

        // Give the event bus a moment to process (actor isolation)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify health updated
        #expect(viewModel.health == 75)
    }

    /// Test that mana bar updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates mana percentage from progressBar event
    @Test func test_manaBarUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let manaTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "mana", "value": "50", "text": "50/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/mana", data: manaTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.mana == 50)
    }

    /// Test that stamina bar updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates stamina percentage from progressBar event
    @Test func test_staminaBarUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let staminaTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "stamina", "value": "90", "text": "90/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/stamina", data: staminaTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.stamina == 90)
    }

    /// Test that spirit bar updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates spirit percentage from progressBar event
    @Test func test_spiritBarUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let spiritTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spirit", "value": "100", "text": "100/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/spirit", data: spiritTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.spirit == 100)
    }

    /// Test that mind bar updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates mind percentage from progressBar event
    @Test func test_mindBarUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let mindTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "mindState", "value": "80", "text": "clear"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/mindState", data: mindTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.mind == 80)
    }

    // MARK: - Text Field Update Tests

    /// Test that stance updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates stance text from progressBar event
    /// - Extracts first word from text attribute
    @Test func test_stanceUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default
        #expect(viewModel.stance == "offensive")

        // Publish stance event
        let stanceTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "pbarStance", "text": "defensive guarded"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/pbarStance", data: stanceTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify stance updated (extracts first word)
        #expect(viewModel.stance == "defensive")
    }

    /// Test that encumbrance updates correctly
    ///
    /// Acceptance Criteria:
    /// - Updates encumbrance text from progressBar event
    /// - Converts to lowercase
    @Test func test_encumbranceUpdate() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially has default
        #expect(viewModel.encumbrance == "none")

        // Publish encumbrance event
        let encumTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "encumlevel", "text": "Light"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/encumlevel", data: encumTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify encumbrance updated (lowercase)
        #expect(viewModel.encumbrance == "light")
    }

    // MARK: - Percentage Calculation Tests

    /// Test that VitalsPanelViewModel calculates percentage from fractions
    ///
    /// Acceptance Criteria:
    /// - Calculates percentage from fraction if server sends incorrect value
    /// - Handles game server bug where value="0" despite showing full fractions
    @Test func test_percentageCalculation() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Server bug: sends value="0" with fraction "74/74"
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "0", "text": "74/74"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should calculate 100% from fraction (74/74)
        #expect(viewModel.health == 100)
    }

    /// Test percentage calculation with partial health
    ///
    /// Acceptance Criteria:
    /// - Correctly calculates percentage from partial fractions
    @Test func test_percentageCalculationPartial() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Server bug: value="0" with partial fraction "50/100"
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "0", "text": "50/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should calculate 50% from fraction
        #expect(viewModel.health == 50)
    }

    /// Test that correct percentages are used when provided
    ///
    /// Acceptance Criteria:
    /// - Uses server-provided percentage when it's correct
    @Test func test_usesCorrectPercentage() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Server sends correct percentage
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "85", "text": "85/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should use provided percentage
        #expect(viewModel.health == 85)
    }

    // MARK: - Indeterminate State Tests

    /// Test that VitalsPanelViewModel handles indeterminate state
    ///
    /// Acceptance Criteria:
    /// - Returns nil for percentage when no data available
    /// - Handles missing attributes gracefully
    @Test func test_indeterminateState() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with no value or text (indeterminate)
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should remain nil (indeterminate)
        #expect(viewModel.health == nil)
    }

    /// Test indeterminate state with invalid fraction
    ///
    /// Acceptance Criteria:
    /// - Handles malformed fractions gracefully
    @Test func test_indeterminateStateInvalidFraction() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with invalid fraction
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "0", "text": "invalid"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should remain nil (can't parse)
        #expect(viewModel.health == nil)
    }

    // MARK: - Multiple Updates Tests

    /// Test that VitalsPanelViewModel handles multiple rapid updates
    ///
    /// Acceptance Criteria:
    /// - Handles rapid successive vitals changes
    @Test func test_multipleUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple health events rapidly
        let percentages = [100, 90, 80, 70]

        for percent in percentages {
            let healthTag = GameTag(
                name: "progressBar",
                text: nil,
                attrs: ["id": "health", "value": "\(percent)", "text": "\(percent)/100"],
                children: [],
                state: .closed
            )
            await eventBus.publish("metadata/progressBar/health", data: healthTag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final value is set
        #expect(viewModel.health == 70)
    }

    /// Test that all vitals can be updated independently
    ///
    /// Acceptance Criteria:
    /// - Each vital field updates independently
    @Test func test_independentVitalUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Update health
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "75", "text": "75/100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update mana
        let manaTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "mana", "value": "50", "text": "50/100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/progressBar/mana", data: manaTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update stamina
        let staminaTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "stamina", "value": "90", "text": "90/100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/progressBar/stamina", data: staminaTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Update stance
        let stanceTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "pbarStance", "text": "defensive"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/progressBar/pbarStance", data: stanceTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all updated independently
        #expect(viewModel.health == 75)
        #expect(viewModel.mana == 50)
        #expect(viewModel.stamina == 90)
        #expect(viewModel.stance == "defensive")
    }

    // MARK: - Lifecycle Tests

    /// Test that VitalsPanelViewModel cleans up subscriptions on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from all events when deallocated
    @Test func test_unsubscribesOnDeinit() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = VitalsPanelViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscriptions exist
            let healthCount = await eventBus.handlerCount(for: "metadata/progressBar/health")
            let manaCount = await eventBus.handlerCount(for: "metadata/progressBar/mana")
            let stanceCount = await eventBus.handlerCount(for: "metadata/progressBar/pbarStance")

            #expect(healthCount == 1)
            #expect(manaCount == 1)
            #expect(stanceCount == 1)
        }

        // VitalsPanelViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify all subscriptions were removed
        let healthCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/health")
        let manaCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/mana")
        let staminaCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/stamina")
        let spiritCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/spirit")
        let mindCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/mindState")
        let stanceCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/pbarStance")
        let encumbranceCountAfter = await eventBus.handlerCount(for: "metadata/progressBar/encumlevel")

        #expect(healthCountAfter == 0)
        #expect(manaCountAfter == 0)
        #expect(staminaCountAfter == 0)
        #expect(spiritCountAfter == 0)
        #expect(mindCountAfter == 0)
        #expect(stanceCountAfter == 0)
        #expect(encumbranceCountAfter == 0)
    }

    /// Test that multiple VitalsPanelViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = VitalsPanelViewModel(eventBus: eventBus)
        let viewModel2 = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let healthHandlerCount = await eventBus.handlerCount(for: "metadata/progressBar/health")
        #expect(healthHandlerCount == 2)

        // Publish event
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "75", "text": "75/100"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.health == 75)
        #expect(viewModel2.health == 75)
    }

    // MARK: - Edge Cases

    /// Test that VitalsPanelViewModel handles zero division safely
    ///
    /// Acceptance Criteria:
    /// - Handles fraction with 0 denominator gracefully
    @Test func test_handlesZeroDivision() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with 0 denominator
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "0", "text": "50/0"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should remain nil (can't divide by 0)
        #expect(viewModel.health == nil)
    }

    /// Test stance extraction with single word
    ///
    /// Acceptance Criteria:
    /// - Handles single-word stance correctly
    @Test func test_stanceSingleWord() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let stanceTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "pbarStance", "text": "offensive"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/pbarStance", data: stanceTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.stance == "offensive")
    }

    /// Test encumbrance with empty text
    ///
    /// Acceptance Criteria:
    /// - Handles missing text gracefully
    @Test func test_encumbranceEmpty() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let encumTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "encumlevel"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/encumlevel", data: encumTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should default to empty string, lowercased
        #expect(viewModel.encumbrance == "")
    }

    /// Test that VitalsPanelViewModel ignores tags with wrong ID
    ///
    /// Acceptance Criteria:
    /// - Only responds to progressBar tags with matching IDs
    @Test func test_ignoresWrongTagID() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish event with wrong ID to health event
        let wrongTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "invalid", "value": "999"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: wrongTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify health unchanged (still nil)
        #expect(viewModel.health == nil)
    }

    /// Test percentage rounding
    ///
    /// Acceptance Criteria:
    /// - Rounds calculated percentages to nearest integer
    @Test func test_percentageRounding() async throws {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Fraction that rounds to 67% (67.333...)
        let healthTag = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "health", "value": "0", "text": "67/100"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/progressBar/health", data: healthTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.health == 67)
    }
}
