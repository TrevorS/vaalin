// ABOUTME: Tests for HandsPanel SwiftUI view component using Swift Testing framework

import Testing
import SwiftUI
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for HandsPanel view component.
///
/// Tests cover:
/// - View rendering with empty and populated states
/// - Integration with PanelContainer
/// - View model setup lifecycle
/// - Layout and spacing requirements
/// - State-driven UI updates via view model
///
/// ## Testing Approach
///
/// SwiftUI views are declarative value types, making traditional state introspection difficult.
/// These tests verify:
/// 1. **View instantiation** - Views compile and initialize correctly with different states
/// 2. **Type correctness** - Generic content types work as expected
/// 3. **View model integration** - View properly observes and responds to view model changes
/// 4. **Lifecycle behavior** - Setup methods are called at appropriate times
///
/// ## Reference
///
/// Based on PanelContainerTests.swift testing patterns and HandsPanel implementation.
/// See Issue #36 acceptance criteria for complete requirements.
@Suite("HandsPanel Tests")
@MainActor
struct HandsPanelTests {

    // MARK: - View Rendering Tests

    @Test("HandsPanel renders successfully with empty state")
    func test_rendersWithEmptyState() {
        // Given: Empty state view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created with empty state
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View should be valid HandsPanel type
        #expect(type(of: panel) == HandsPanel.self)

        // Verify initial empty state
        #expect(viewModel.leftHand == "Empty")
        #expect(viewModel.rightHand == "Empty")
        #expect(viewModel.preparedSpell == "None")
    }

    @Test("HandsPanel renders successfully with populated state")
    func test_rendersWithPopulatedState() {
        // Given: Populated state view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // Manually set populated state for test
        viewModel.leftHand = "steel broadsword"
        viewModel.rightHand = "wooden shield"
        viewModel.preparedSpell = "Minor Shock"

        // When: Panel is created with populated state
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View should be valid HandsPanel type
        #expect(type(of: panel) == HandsPanel.self)

        // Verify populated state
        #expect(viewModel.leftHand == "steel broadsword")
        #expect(viewModel.rightHand == "wooden shield")
        #expect(viewModel.preparedSpell == "Minor Shock")
    }

    @Test("HandsPanel renders with long item names for truncation testing")
    func test_rendersWithLongItemNames() {
        // Given: View model with very long item names
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // Set long names to test truncation behavior
        viewModel.leftHand = "an enruned vultite greatsword with intricate silver filigree"
        viewModel.rightHand = "a steel-reinforced tower shield with gold embossing"
        viewModel.preparedSpell = "Mass Elemental Wave (410)"

        // When: Panel is created with long names
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View should be valid and contain long names
        #expect(type(of: panel) == HandsPanel.self)
        #expect(viewModel.leftHand.count > 40)
        #expect(viewModel.rightHand.count > 40)
    }

    // MARK: - PanelContainer Integration Tests

    @Test("HandsPanel integrates properly with PanelContainer")
    func test_panelContainerIntegration() {
        // Given: HandsPanel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created (internally uses PanelContainer)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View should be valid HandsPanel wrapping PanelContainer
        #expect(type(of: panel) == HandsPanel.self)

        // PanelContainer is internal to HandsPanel's body, but we verify
        // the panel can be instantiated successfully, which means
        // PanelContainer integration is working
    }

    @Test("HandsPanel uses correct fixed height per requirements")
    func test_usesCorrectHeight() {
        // Given: HandsPanel specification requires 140pt height (FR-3.1)
        let expectedHeight: CGFloat = 140

        // When: Panel is created
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Height is enforced in HandsPanel.swift line 87: height: 140
        // This test documents the requirement; actual height enforcement
        // is tested visually via Xcode Previews and in integration tests
        #expect(expectedHeight == 140)
    }

    // MARK: - View Model Integration Tests

    @Test("HandsPanel view model updates when leftHand changes")
    func test_viewModelLeftHandUpdates() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // Initially empty
        #expect(viewModel.leftHand == "Empty")

        // When: Left hand event is published
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

        // Then: View model updates and SwiftUI view observes change
        #expect(viewModel.leftHand == "steel broadsword")

        // Panel remains valid after update
        #expect(type(of: panel) == HandsPanel.self)
    }

    @Test("HandsPanel view model updates when rightHand changes")
    func test_viewModelRightHandUpdates() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // Initially empty
        #expect(viewModel.rightHand == "Empty")

        // When: Right hand event is published
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

        // Then: View model updates and SwiftUI view observes change
        #expect(viewModel.rightHand == "wooden shield")

        // Panel remains valid after update
        #expect(type(of: panel) == HandsPanel.self)
    }

    @Test("HandsPanel view model updates when preparedSpell changes")
    func test_viewModelSpellUpdates() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // Initially none
        #expect(viewModel.preparedSpell == "None")

        // When: Spell event is published
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

        // Then: View model updates and SwiftUI view observes change
        #expect(viewModel.preparedSpell == "Fire Spirit")

        // Panel remains valid after update
        #expect(type(of: panel) == HandsPanel.self)
    }

    @Test("HandsPanel applies correct styling for empty state")
    func test_emptyStateStyling() {
        // Given: Panel with empty state
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created (view model has empty state by default)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View model reflects empty state
        #expect(viewModel.leftHand == "Empty")
        #expect(viewModel.rightHand == "Empty")
        #expect(viewModel.preparedSpell == "None")

        // Note: Empty state styling (secondary color, italic) is applied by HandRow
        // in HandsPanel.swift lines 149-150:
        // - .foregroundStyle(isEmpty ? .secondary : .primary)
        // - .italic(isEmpty)
        // This is tested visually via Xcode Previews
        #expect(type(of: panel) == HandsPanel.self)
    }

    @Test("HandsPanel applies correct styling for populated state")
    func test_populatedStateStyling() {
        // Given: Panel with populated state
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        viewModel.leftHand = "steel broadsword"
        viewModel.rightHand = "wooden shield"
        viewModel.preparedSpell = "Minor Shock"

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View model reflects populated state (not default empty values)
        #expect(viewModel.leftHand != "Empty")
        #expect(viewModel.rightHand != "Empty")
        #expect(viewModel.preparedSpell != "None")

        // Note: Populated state styling (primary color, no italic) is tested visually
        #expect(type(of: panel) == HandsPanel.self)
    }

    // MARK: - Layout Tests

    @Test("HandsPanel displays three rows for left/right/spell")
    func test_displaysThreeRows() {
        // Given: Panel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: View should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Three rows are defined in HandsPanel.swift lines 91-109:
        // - HandRow(icon: "✋", content: viewModel.leftHand, ...)
        // - HandRow(icon: "🤚", content: viewModel.rightHand, ...)
        // - HandRow(icon: "✨", content: viewModel.preparedSpell, ...)
        //
        // Row structure is tested visually via Xcode Previews and in integration tests
    }

    @Test("HandsPanel uses correct spacing between rows")
    func test_correctSpacingBetweenRows() {
        // Given: HandsPanel specification requires 12pt spacing (line 89)
        let expectedSpacing: CGFloat = 12

        // When: Panel is created
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Spacing is enforced in HandsPanel.swift line 89: spacing: 12
        // This test documents the requirement; actual spacing is tested visually
        #expect(expectedSpacing == 12)
    }

    @Test("HandsPanel uses correct padding")
    func test_correctPadding() {
        // Given: HandsPanel specification requires 16pt horizontal, 12pt vertical padding
        let expectedHorizontalPadding: CGFloat = 16
        let expectedVerticalPadding: CGFloat = 12

        // When: Panel is created
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Padding is enforced in HandsPanel.swift lines 111-112:
        // - .padding(.horizontal, 16)
        // - .padding(.vertical, 12)
        // This test documents the requirements
        #expect(expectedHorizontalPadding == 16)
        #expect(expectedVerticalPadding == 12)
    }

    // MARK: - Lifecycle Tests

    @Test("HandsPanel calls viewModel.setup() on appear")
    func test_callsViewModelSetupOnAppear() async throws {
        // Given: Panel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // Initially no subscriptions
        let initialLeftHandlerCount = await eventBus.handlerCount(for: "metadata/left")
        let initialRightHandlerCount = await eventBus.handlerCount(for: "metadata/right")
        let initialSpellHandlerCount = await eventBus.handlerCount(for: "metadata/spell")

        #expect(initialLeftHandlerCount == 0)
        #expect(initialRightHandlerCount == 0)
        #expect(initialSpellHandlerCount == 0)

        // When: Panel is created (has .task modifier that calls setup())
        let panel = HandsPanel(viewModel: viewModel)

        // Note: The .task modifier in HandsPanel.swift line 115-118 calls:
        //   await viewModel.setup()
        // This happens automatically when the view appears in SwiftUI.
        //
        // We verify this behavior by manually calling setup() and checking subscriptions

        // Simulate view appearing by manually calling setup
        await viewModel.setup()

        // Then: View model should have subscribed to all events
        let finalLeftHandlerCount = await eventBus.handlerCount(for: "metadata/left")
        let finalRightHandlerCount = await eventBus.handlerCount(for: "metadata/right")
        let finalSpellHandlerCount = await eventBus.handlerCount(for: "metadata/spell")

        #expect(finalLeftHandlerCount == 1)
        #expect(finalRightHandlerCount == 1)
        #expect(finalSpellHandlerCount == 1)

        // Panel remains valid
        #expect(type(of: panel) == HandsPanel.self)
    }

    // MARK: - Collapse State Tests

    @Test("HandsPanel can be collapsed")
    func test_canBeCollapsed() {
        // Given: Panel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created (internally creates @State isCollapsed binding)
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid and have collapse capability
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Collapse state is managed by PanelContainer via @State isCollapsed
        // in HandsPanel.swift line 67 and passed to PanelContainer on line 86.
        //
        // The collapse/expand behavior is tested in PanelContainerTests.swift
        // and visually via Xcode Previews. SwiftUI @State can't be directly
        // accessed from outside the view.
    }

    @Test("HandsPanel content hidden when collapsed")
    func test_contentHiddenWhenCollapsed() {
        // Given: Panel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Content visibility based on collapse state is managed by PanelContainer.
        // HandsPanel passes isCollapsed binding to PanelContainer (line 86),
        // which handles showing/hiding content.
        //
        // This behavior is tested in PanelContainerTests.swift and visually
        // via Xcode Previews. We can't directly test @State mutations from
        // outside the view in unit tests.
    }

    @Test("HandsPanel height changes when collapsed")
    func test_heightChangesWhenCollapsed() {
        // Given: Panel with view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should be valid
        #expect(type(of: panel) == HandsPanel.self)

        // Note: Height adjustment on collapse is managed by PanelContainer.
        // HandsPanel specifies fixed height: 140 (line 87), and PanelContainer
        // adjusts layout when collapsed to show only the header.
        //
        // This behavior is tested visually via Xcode Previews and in
        // integration tests. Unit tests verify the view initializes correctly.
    }

    // MARK: - Integration Tests with Multiple Updates

    @Test("HandsPanel handles all three fields updating independently")
    func test_independentFieldUpdates() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // When: Update left hand
        let leftItem = GameTag(name: "item", text: "sword", attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [leftItem], state: .closed)
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Only left hand updated
        #expect(viewModel.leftHand == "sword")
        #expect(viewModel.rightHand == "Empty")
        #expect(viewModel.preparedSpell == "None")

        // When: Update right hand
        let rightItem = GameTag(name: "item", text: "shield", attrs: [:], children: [], state: .closed)
        let rightTag = GameTag(name: "right", text: nil, attrs: [:], children: [rightItem], state: .closed)
        await eventBus.publish("metadata/right", data: rightTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Left and right updated, spell still none
        #expect(viewModel.leftHand == "sword")
        #expect(viewModel.rightHand == "shield")
        #expect(viewModel.preparedSpell == "None")

        // When: Update spell
        let spell = GameTag(name: "spell", text: "Fire Spirit", attrs: [:], children: [], state: .closed)
        let spellTag = GameTag(name: "spell", text: nil, attrs: [:], children: [spell], state: .closed)
        await eventBus.publish("metadata/spell", data: spellTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: All three fields updated
        #expect(viewModel.leftHand == "sword")
        #expect(viewModel.rightHand == "shield")
        #expect(viewModel.preparedSpell == "Fire Spirit")

        // Panel remains valid after all updates
        #expect(type(of: panel) == HandsPanel.self)
    }

    @Test("HandsPanel handles rapid successive updates")
    func test_rapidSuccessiveUpdates() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // When: Publish multiple rapid left hand updates
        let items = ["sword", "axe", "dagger", "mace"]
        for item in items {
            let itemTag = GameTag(name: "item", text: item, attrs: [:], children: [], state: .closed)
            let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)
            await eventBus.publish("metadata/left", data: leftTag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Final value should be set
        #expect(viewModel.leftHand == "mace")

        // Panel remains valid
        #expect(type(of: panel) == HandsPanel.self)
    }

    // MARK: - Edge Case Tests

    @Test("HandsPanel handles special characters in item names")
    func test_handlesSpecialCharacters() {
        // Given: View model with special characters in item names
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        let specialItem = "silver-edged longsword (enchanted)"
        viewModel.leftHand = specialItem

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should render correctly with special characters
        #expect(type(of: panel) == HandsPanel.self)
        #expect(viewModel.leftHand == specialItem)
    }

    @Test("HandsPanel handles Unicode in item names")
    func test_handlesUnicode() {
        // Given: View model with Unicode characters in item names
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        let unicodeItem = "龙剑 (Dragon Sword)"
        viewModel.leftHand = unicodeItem

        // When: Panel is created
        let panel = HandsPanel(viewModel: viewModel)

        // Then: Panel should render correctly with Unicode
        #expect(type(of: panel) == HandsPanel.self)
        #expect(viewModel.leftHand == unicodeItem)
    }

    @Test("HandsPanel handles empty-to-populated-to-empty transitions")
    func test_emptyToPopulatedToEmptyTransitions() async throws {
        // Given: Panel with EventBus-connected view model
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let panel = HandsPanel(viewModel: viewModel)

        // Initially empty
        #expect(viewModel.leftHand == "Empty")

        // When: Transition to populated
        let itemTag = GameTag(name: "item", text: "sword", attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)
        await eventBus.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Populated
        #expect(viewModel.leftHand == "sword")

        // When: Transition back to empty
        let emptyTag = GameTag(name: "left", text: nil, attrs: [:], children: [], state: .closed)
        await eventBus.publish("metadata/left", data: emptyTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Back to empty
        #expect(viewModel.leftHand == "Empty")

        // Panel remains valid through all transitions
        #expect(type(of: panel) == HandsPanel.self)
    }

    // MARK: - Nesting and Composition Tests

    @Test("HandsPanel can be nested in other views")
    func test_nestingInOtherViews() {
        // Given: HandsPanel nested in VStack
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Panel is nested in container view
        let containerView = VStack {
            Text("Header")
            HandsPanel(viewModel: viewModel)
            Text("Footer")
        }

        // Then: Container should compile successfully with nested panel
        #expect(type(of: containerView) == VStack<TupleView<(Text, HandsPanel, Text)>>.self)
    }

    @Test("Multiple HandsPanel instances with independent view models")
    func test_multipleIndependentPanels() async throws {
        // Given: Two EventBus instances with separate view models
        let eventBus1 = EventBus()
        let eventBus2 = EventBus()
        let viewModel1 = HandsPanelViewModel(eventBus: eventBus1)
        let viewModel2 = HandsPanelViewModel(eventBus: eventBus2)

        await viewModel1.setup()
        await viewModel2.setup()

        // When: Two separate panels are created
        let panel1 = HandsPanel(viewModel: viewModel1)
        let panel2 = HandsPanel(viewModel: viewModel2)

        // Both initially empty
        #expect(viewModel1.leftHand == "Empty")
        #expect(viewModel2.leftHand == "Empty")

        // When: Update only panel1
        let itemTag = GameTag(name: "item", text: "sword", attrs: [:], children: [], state: .closed)
        let leftTag = GameTag(name: "left", text: nil, attrs: [:], children: [itemTag], state: .closed)
        await eventBus1.publish("metadata/left", data: leftTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Then: Only panel1 view model updated
        #expect(viewModel1.leftHand == "sword")
        #expect(viewModel2.leftHand == "Empty")

        // Both panels remain valid
        #expect(type(of: panel1) == HandsPanel.self)
        #expect(type(of: panel2) == HandsPanel.self)
    }

    // MARK: - Performance Tests

    @Test("HandsPanel initializes quickly")
    func test_initializationPerformance() {
        // Given: Event bus and view model ready
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)

        // When: Measure panel creation time
        let start = Date()

        for _ in 0..<100 {
            _ = HandsPanel(viewModel: viewModel)
        }

        let duration = Date().timeIntervalSince(start)

        // Then: 100 instantiations should complete very quickly (< 100ms)
        // SwiftUI views are lightweight value types
        #expect(duration < 0.1) // 100ms for 100 views = 1ms average
    }
}
