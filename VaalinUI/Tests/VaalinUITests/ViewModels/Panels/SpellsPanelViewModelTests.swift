// ABOUTME: Tests for SpellsPanelViewModel EventBus subscription and active spells state management

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for SpellsPanelViewModel spells panel state functionality
/// Validates EventBus subscription and active spells tracking per Issue #44 acceptance criteria
@MainActor
struct SpellsPanelViewModelTests {

    // MARK: - Initialization Tests

    /// Test that SpellsPanelViewModel initializes with no active spells
    ///
    /// Acceptance Criteria:
    /// - activeSpells defaults to empty array
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)

        // Verify initialization with no spells
        #expect(viewModel.activeSpells.isEmpty)
    }

    // MARK: - EventBus Subscription Tests

    /// Test that SpellsPanelViewModel subscribes to Active Spells events on setup
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/dialogData/Active Spells" event on setup
    @Test func test_setup() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)

        await viewModel.setup()

        // Verify subscription exists
        let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/Active Spells")
        #expect(handlerCount == 1)
    }

    /// Test that SpellsPanelViewModel processes valid Active Spells events after setup
    ///
    /// Acceptance Criteria:
    /// - Processes events published to "metadata/dialogData/Active Spells"
    /// - Updates activeSpells when event contains spell data
    @Test func test_subscribesToSpellfrontEvents() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify initially empty
        #expect(viewModel.activeSpells.isEmpty)

        // Publish a Active Spells event with empty children (no spells)
        let emptyTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: emptyTag)

        // Give async operation time to complete
        try? await Task.sleep(for: .milliseconds(10))

        // Verify still empty (empty children = no spells)
        #expect(viewModel.activeSpells.isEmpty)
    }

    // MARK: - Add Spell Tests

    /// Test that SpellsPanelViewModel adds a single spell
    ///
    /// Acceptance Criteria (Issue #44):
    /// - Stores spell with name and optional duration
    /// - Extracts spell data from progressBar children
    @Test func test_addSpell() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish Active Spells event with one spell
        let spellBar = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Spirit Shield",
                "time": "14:32",
                "value": "85"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spellBar],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].id == "spell123")
        #expect(viewModel.activeSpells[0].name == "Spirit Shield")
        #expect(viewModel.activeSpells[0].timeRemaining == "14:32")
        #expect(viewModel.activeSpells[0].percentRemaining == 85)
    }

    /// Test that SpellsPanelViewModel adds spell with minimal data
    ///
    /// Acceptance Criteria:
    /// - Handles spell with only id and name
    /// - Optional time and percentage fields can be nil
    @Test func test_addSpellMinimalData() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell with only required fields (id and text)
        let spellBar = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell456",
                "text": "Permanence"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spellBar],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added with nil optional fields
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].id == "spell456")
        #expect(viewModel.activeSpells[0].name == "Permanence")
        #expect(viewModel.activeSpells[0].timeRemaining == nil)
        #expect(viewModel.activeSpells[0].percentRemaining == nil)
    }

    // MARK: - Multiple Spells Tests

    /// Test that SpellsPanelViewModel handles multiple simultaneous spells
    ///
    /// Acceptance Criteria (Issue #44):
    /// - Stores multiple active spells
    /// - Maintains spell order from server
    @Test func test_multipleSpells() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish Active Spells event with multiple spells
        let spell1 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Spirit Shield",
                "time": "14:32",
                "value": "85"
            ],
            children: [],
            state: .closed
        )
        let spell2 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell456",
                "text": "Haste",
                "time": "3:45",
                "value": "25"
            ],
            children: [],
            state: .closed
        )
        let spell3 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell789",
                "text": "Bravery",
                "time": "20:00",
                "value": "100"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spell1, spell2, spell3],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all three spells added
        #expect(viewModel.activeSpells.count == 3)

        // Verify first spell
        #expect(viewModel.activeSpells[0].id == "spell123")
        #expect(viewModel.activeSpells[0].name == "Spirit Shield")

        // Verify second spell
        #expect(viewModel.activeSpells[1].id == "spell456")
        #expect(viewModel.activeSpells[1].name == "Haste")

        // Verify third spell
        #expect(viewModel.activeSpells[2].id == "spell789")
        #expect(viewModel.activeSpells[2].name == "Bravery")
    }

    /// Test that SpellsPanelViewModel maintains spell order from server
    ///
    /// Acceptance Criteria:
    /// - Preserves order of spells as sent by server
    @Test func test_spellOrdering() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Create spells in specific order
        let spellA = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spellA", "text": "Armor"],
            children: [],
            state: .closed
        )
        let spellB = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spellB", "text": "Barrier"],
            children: [],
            state: .closed
        )
        let spellC = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spellC", "text": "Courage"],
            children: [],
            state: .closed
        )

        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spellA, spellB, spellC],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify exact order maintained
        #expect(viewModel.activeSpells[0].name == "Armor")
        #expect(viewModel.activeSpells[1].name == "Barrier")
        #expect(viewModel.activeSpells[2].name == "Courage")
    }

    // MARK: - Remove Expired Spell Tests

    /// Test that SpellsPanelViewModel removes expired spells
    ///
    /// Acceptance Criteria (Issue #44):
    /// - Clears all spells when dialog has no children
    @Test func test_removeExpiredSpell() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // First, add a spell
        let spellBar = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Spirit Shield",
                "time": "14:32",
                "value": "85"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spellBar],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell exists
        #expect(viewModel.activeSpells.count == 1)

        // Now publish empty dialog (spell expired)
        let emptyTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all spells cleared
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel clears all spells when receiving empty dialog
    ///
    /// Acceptance Criteria:
    /// - Empty children array = no active spells
    @Test func test_clearAllSpells() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Add multiple spells
        let spell1 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell1", "text": "Armor"],
            children: [],
            state: .closed
        )
        let spell2 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell2", "text": "Shield"],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spell1, spell2],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both spells exist
        #expect(viewModel.activeSpells.count == 2)

        // Clear all spells with empty dialog
        let emptyTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all spells cleared
        #expect(viewModel.activeSpells.isEmpty)
    }

    // MARK: - Update Existing Spell Tests

    /// Test that SpellsPanelViewModel updates existing spell when same ID appears
    ///
    /// Acceptance Criteria:
    /// - Updates spell time/percentage when same spell ID is sent
    /// - Does not duplicate spells with same ID
    @Test func test_updateExistingSpell() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Add initial spell
        let initialSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Spirit Shield",
                "time": "14:32",
                "value": "85"
            ],
            children: [],
            state: .closed
        )
        let initialTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [initialSpell],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: initialTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify initial state
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].timeRemaining == "14:32")
        #expect(viewModel.activeSpells[0].percentRemaining == 85)

        // Update with new time/percentage (same ID)
        let updatedSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Spirit Shield",
                "time": "14:00",
                "value": "82"
            ],
            children: [],
            state: .closed
        )
        let updatedTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [updatedSpell],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: updatedTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify updated (not duplicated)
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].id == "spell123")
        #expect(viewModel.activeSpells[0].timeRemaining == "14:00")
        #expect(viewModel.activeSpells[0].percentRemaining == 82)
    }

    /// Test that multiple spell updates work correctly
    ///
    /// Acceptance Criteria:
    /// - Full replacement of spell list with each update
    /// - Handles addition and removal in same update
    @Test func test_multipleSpellUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // First update: 2 spells
        let spell1 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell1", "text": "Armor", "time": "10:00"],
            children: [],
            state: .closed
        )
        let spell2 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell2", "text": "Shield", "time": "5:00"],
            children: [],
            state: .closed
        )
        let tag1 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spell1, spell2],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: tag1)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.activeSpells.count == 2)

        // Second update: remove spell2, add spell3
        let spell3 = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell3", "text": "Haste", "time": "8:00"],
            children: [],
            state: .closed
        )
        let tag2 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spell1, spell3],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: tag2)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify correct spells present
        #expect(viewModel.activeSpells.count == 2)
        #expect(viewModel.activeSpells[0].id == "spell1")
        #expect(viewModel.activeSpells[1].id == "spell3")
    }

    // MARK: - Spell Without Time Tests

    /// Test that SpellsPanelViewModel handles spell without time attribute
    ///
    /// Acceptance Criteria:
    /// - Passive effects may not have duration
    /// - timeRemaining should be nil for permanent effects
    @Test func test_spellWithoutTime() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell without time attribute (permanent effect)
        let permanentSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell999",
                "text": "Permanence",
                "value": "100"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [permanentSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added with nil time
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Permanence")
        #expect(viewModel.activeSpells[0].timeRemaining == nil)
        #expect(viewModel.activeSpells[0].percentRemaining == 100)
    }

    // MARK: - Spell Without Percentage Tests

    /// Test that SpellsPanelViewModel handles spell without value attribute
    ///
    /// Acceptance Criteria:
    /// - Some effects may not have percentage indicator
    /// - percentRemaining should be nil when not provided
    @Test func test_spellWithoutPercentage() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell without value attribute
        let noPercentSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell777",
                "text": "Blurred Image",
                "time": "5:30"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [noPercentSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added with nil percentage
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Blurred Image")
        #expect(viewModel.activeSpells[0].timeRemaining == "5:30")
        #expect(viewModel.activeSpells[0].percentRemaining == nil)
    }

    /// Test that SpellsPanelViewModel handles spell without time or percentage
    ///
    /// Acceptance Criteria:
    /// - Both optional fields can be nil simultaneously
    @Test func test_spellWithNoOptionalFields() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell with only required fields
        let minimalSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell555",
                "text": "Unknown Effect"
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [minimalSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added with both optional fields nil
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Unknown Effect")
        #expect(viewModel.activeSpells[0].timeRemaining == nil)
        #expect(viewModel.activeSpells[0].percentRemaining == nil)
    }

    // MARK: - Tag Filtering Tests

    /// Test that SpellsPanelViewModel handles non-dialogData tags
    ///
    /// Acceptance Criteria:
    /// - Only processes dialogData tags
    /// - Ignores tags with wrong name
    @Test func test_handleNonDialogDataTag() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish tag with wrong name
        let wrongTag = GameTag(
            name: "progressBar",  // Wrong - should be "dialogData"
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: wrongTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify no spells added (wrong tag name ignored)
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel handles dialogData tags with wrong ID
    ///
    /// Acceptance Criteria:
    /// - Only processes dialogData tags with id="Active Spells"
    /// - Ignores other dialog types
    @Test func test_handleWrongDialogID() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish dialogData with wrong ID
        let wrongIdTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "inventory"],  // Wrong ID
            children: [
                GameTag(
                    name: "progressBar",
                    text: nil,
                    attrs: ["id": "spell123", "text": "Should not add"],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: wrongIdTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify no spells added (wrong dialog ID ignored)
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel only processes progressBar children
    ///
    /// Acceptance Criteria:
    /// - Filters children to only include progressBar tags
    /// - Ignores other child tag types
    @Test func test_filtersNonProgressBarChildren() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Mix of progressBar and non-progressBar children
        let validSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123", "text": "Valid Spell"],
            children: [],
            state: .closed
        )
        let invalidChild = GameTag(
            name: "output",  // Wrong type
            text: "Not a spell",
            attrs: ["id": "invalid"],
            children: [],
            state: .closed
        )

        let mixedTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [invalidChild, validSpell, invalidChild],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: mixedTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify only progressBar child processed
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Valid Spell")
    }

    // MARK: - Lifecycle Tests

    /// Test that SpellsPanelViewModel cleans up subscriptions on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from events when deallocated
    @Test func test_deinit() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = SpellsPanelViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscription exists
            let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/Active Spells")
            #expect(handlerCount == 1)
        }

        // SpellsPanelViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify subscription was removed
        let handlerCountAfter = await eventBus.handlerCount(for: "metadata/dialogData/Active Spells")
        #expect(handlerCountAfter == 0)
    }

    /// Test that multiple SpellsPanelViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = SpellsPanelViewModel(eventBus: eventBus)
        let viewModel2 = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/Active Spells")
        #expect(handlerCount == 2)

        // Publish event
        let spellBar = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123", "text": "Armor"],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [spellBar],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.activeSpells.count == 1)
        #expect(viewModel1.activeSpells[0].name == "Armor")
        #expect(viewModel2.activeSpells.count == 1)
        #expect(viewModel2.activeSpells[0].name == "Armor")
    }

    // MARK: - Edge Cases

    /// Test that SpellsPanelViewModel handles missing spell ID gracefully
    ///
    /// Acceptance Criteria:
    /// - Skips progressBar children without id attribute
    @Test func test_handlesMissingSpellID() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell without ID attribute
        let noIdSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["text": "No ID Spell"],  // Missing "id" key
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [noIdSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell skipped (no id = invalid)
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel handles missing spell name gracefully
    ///
    /// Acceptance Criteria:
    /// - Skips progressBar children without text attribute
    @Test func test_handlesMissingSpellName() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell without text attribute
        let noNameSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123"],  // Missing "text" key
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [noNameSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell skipped (no text = invalid)
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel handles empty string spell name
    ///
    /// Acceptance Criteria:
    /// - Skips spells with empty name
    @Test func test_handlesEmptySpellName() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell with empty text
        let emptyNameSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123", "text": ""],  // Empty string
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [emptyNameSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell skipped (empty name = invalid)
        #expect(viewModel.activeSpells.isEmpty)
    }

    /// Test that SpellsPanelViewModel handles invalid percentage value
    ///
    /// Acceptance Criteria:
    /// - Converts value attribute to Int
    /// - Handles non-numeric values gracefully
    @Test func test_handlesInvalidPercentage() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Spell with non-numeric value
        let invalidPercentSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: [
                "id": "spell123",
                "text": "Armor",
                "value": "invalid"  // Non-numeric
            ],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [invalidPercentSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify spell added with nil percentage
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Armor")
        #expect(viewModel.activeSpells[0].percentRemaining == nil)
    }

    /// Test that SpellsPanelViewModel handles special characters in spell names
    ///
    /// Acceptance Criteria:
    /// - Displays spell names with special characters correctly
    @Test func test_handlesSpecialCharactersInName() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let specialName = "Spirit Shield (1215)"
        let specialSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123", "text": specialName],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [specialSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.activeSpells[0].name == specialName)
    }

    /// Test that SpellsPanelViewModel handles Unicode in spell names
    ///
    /// Acceptance Criteria:
    /// - Displays spell names with Unicode characters correctly
    @Test func test_handlesUnicodeInName() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let unicodeName = "龙之力 (Dragon's Strength)"
        let unicodeSpell = GameTag(
            name: "progressBar",
            text: nil,
            attrs: ["id": "spell123", "text": unicodeName],
            children: [],
            state: .closed
        )
        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: [unicodeSpell],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.activeSpells[0].name == unicodeName)
    }

    /// Test that SpellsPanelViewModel handles long spell lists
    ///
    /// Acceptance Criteria:
    /// - Handles many simultaneous spells efficiently
    @Test func test_handlesLargeSpellList() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Create 20 spells
        var spells: [GameTag] = []
        for i in 1...20 {
            let spell = GameTag(
                name: "progressBar",
                text: nil,
                attrs: [
                    "id": "spell\(i)",
                    "text": "Spell \(i)",
                    "time": "\(i):00",
                    "value": "\(i * 5)"
                ],
                children: [],
                state: .closed
            )
            spells.append(spell)
        }

        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: spells,
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all 20 spells added
        #expect(viewModel.activeSpells.count == 20)
        #expect(viewModel.activeSpells[0].name == "Spell 1")
        #expect(viewModel.activeSpells[19].name == "Spell 20")
    }

    /// Test that SpellsPanelViewModel handles rapid updates correctly
    ///
    /// Acceptance Criteria:
    /// - Handles rapid successive spell list changes
    /// - Always reflects most recent state
    @Test func test_handlesRapidUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple rapid updates
        for i in 1...5 {
            let spell = GameTag(
                name: "progressBar",
                text: nil,
                attrs: ["id": "spell\(i)", "text": "Spell \(i)"],
                children: [],
                state: .closed
            )
            let tag = GameTag(
                name: "dialogData",
                text: nil,
                attrs: ["id": "Active Spells"],
                children: [spell],
                state: .closed
            )
            await eventBus.publish("metadata/dialogData/Active Spells", data: tag)
            try? await Task.sleep(for: .milliseconds(2))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final state (only last spell)
        #expect(viewModel.activeSpells.count == 1)
        #expect(viewModel.activeSpells[0].name == "Spell 5")
    }

    /// Test that SpellsPanelViewModel handles time format variations
    ///
    /// Acceptance Criteria:
    /// - Stores time string as-is without parsing
    /// - Handles various time formats
    @Test func test_handlesTimeFormatVariations() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Various time formats
        let timeFormats = ["14:32", "0:45", "120:00", "1:05"]
        var spells: [GameTag] = []

        for (index, time) in timeFormats.enumerated() {
            let spell = GameTag(
                name: "progressBar",
                text: nil,
                attrs: [
                    "id": "spell\(index)",
                    "text": "Spell \(index)",
                    "time": time
                ],
                children: [],
                state: .closed
            )
            spells.append(spell)
        }

        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: spells,
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all time formats preserved as-is
        #expect(viewModel.activeSpells[0].timeRemaining == "14:32")
        #expect(viewModel.activeSpells[1].timeRemaining == "0:45")
        #expect(viewModel.activeSpells[2].timeRemaining == "120:00")
        #expect(viewModel.activeSpells[3].timeRemaining == "1:05")
    }

    /// Test that SpellsPanelViewModel handles boundary percentage values
    ///
    /// Acceptance Criteria:
    /// - Handles 0%, 100%, and intermediate values
    @Test func test_handlesBoundaryPercentages() async throws {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Boundary percentages
        let percentages = [0, 1, 50, 99, 100]
        var spells: [GameTag] = []

        for (index, percent) in percentages.enumerated() {
            let spell = GameTag(
                name: "progressBar",
                text: nil,
                attrs: [
                    "id": "spell\(index)",
                    "text": "Spell \(index)",
                    "value": "\(percent)"
                ],
                children: [],
                state: .closed
            )
            spells.append(spell)
        }

        let activeSpellsTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "Active Spells"],
            children: spells,
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/Active Spells", data: activeSpellsTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all percentages handled correctly
        #expect(viewModel.activeSpells[0].percentRemaining == 0)
        #expect(viewModel.activeSpells[1].percentRemaining == 1)
        #expect(viewModel.activeSpells[2].percentRemaining == 50)
        #expect(viewModel.activeSpells[3].percentRemaining == 99)
        #expect(viewModel.activeSpells[4].percentRemaining == 100)
    }
}
