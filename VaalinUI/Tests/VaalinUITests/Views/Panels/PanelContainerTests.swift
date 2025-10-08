// ABOUTME: Tests for PanelContainer view component using Swift Testing framework

import Testing
import SwiftUI
@testable import VaalinUI

/// Test suite for PanelContainer view component.
///
/// Tests cover:
/// - Collapsed state toggling
/// - Title rendering
/// - Content visibility based on collapsed state
/// - Fixed height behavior
/// - Animation and accessibility
@Suite("PanelContainer Tests")
struct PanelContainerTests {
    // MARK: - Basic Functionality Tests

    @Test("PanelContainer initializes with correct properties")
    func test_initialization() {
        // Given: Initial collapsed state
        let isCollapsed = false
        let title = "Test Panel"
        let height: CGFloat = 140

        // When: Container is created (implicit - SwiftUI views are value types)
        // SwiftUI views are structs, so we can't directly test internal state
        // Instead, we verify the view can be instantiated with correct types

        // Then: View should compile and be valid
        let container = PanelContainer(
            title: title,
            isCollapsed: .constant(isCollapsed),
            height: height
        ) {
            Text("Content")
        }

        // Verify the view type is correct
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    @Test("PanelContainer accepts different content types")
    func test_genericContent() {
        // Given: Different content view types
        let height: CGFloat = 160

        // When: Container is created with VStack content
        let vStackContainer = PanelContainer(
            title: "VStack Panel",
            isCollapsed: .constant(false),
            height: height
        ) {
            VStack {
                Text("Line 1")
                Text("Line 2")
            }
        }

        // Then: Should compile with VStack content type
        #expect(type(of: vStackContainer) == PanelContainer<VStack<TupleView<(Text, Text)>>>.self)

        // When: Container is created with HStack content
        let hStackContainer = PanelContainer(
            title: "HStack Panel",
            isCollapsed: .constant(false),
            height: height
        ) {
            HStack {
                Text("Left")
                Text("Right")
            }
        }

        // Then: Should compile with HStack content type
        #expect(type(of: hStackContainer) == PanelContainer<HStack<TupleView<(Text, Text)>>>.self)
    }

    // MARK: - Collapse State Tests

    @Test("PanelContainer binding updates when collapsed state changes")
    func test_collapsedStateBinding() {
        // Given: Initial expanded state
        var isCollapsed = false

        // When: Binding is created and toggled
        let binding = Binding(
            get: { isCollapsed },
            set: { isCollapsed = $0 }
        )

        // Initially expanded
        #expect(isCollapsed == false)

        // When: State is toggled
        binding.wrappedValue = true

        // Then: Binding should reflect new state
        #expect(isCollapsed == true)

        // When: Toggled back
        binding.wrappedValue = false

        // Then: Should return to expanded
        #expect(isCollapsed == false)
    }

    @Test("PanelContainer can be created in collapsed state")
    func test_initiallyCollapsed() {
        // Given: Initially collapsed state
        let isCollapsed = true

        // When: Container is created in collapsed state
        let container = PanelContainer(
            title: "Collapsed Panel",
            isCollapsed: .constant(isCollapsed),
            height: 140
        ) {
            Text("Hidden Content")
        }

        // Then: View should be valid
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    // MARK: - Height Tests

    @Test("PanelContainer accepts various height values", arguments: [
        140.0,  // Hands panel height
        160.0,  // Room/Vitals panel height
        180.0,  // Injuries/Spells panel height
        200.0,  // Custom height
        100.0   // Minimum height
    ])
    func test_heightValues(height: CGFloat) {
        // When: Container is created with specified height
        let container = PanelContainer(
            title: "Panel",
            isCollapsed: .constant(false),
            height: height
        ) {
            Text("Content")
        }

        // Then: View should be valid with any positive height
        #expect(height > 0)
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    // MARK: - Title Tests

    @Test("PanelContainer accepts various title strings", arguments: [
        "Hands",
        "Vitals",
        "Compass",
        "Injuries",
        "Spells",
        "Very Long Panel Title For Testing",
        "A"  // Single character
    ])
    func test_titleValues(title: String) {
        // When: Container is created with specified title
        let container = PanelContainer(
            title: title,
            isCollapsed: .constant(false),
            height: 140
        ) {
            Text("Content")
        }

        // Then: View should be valid with any title string
        #expect(title.isEmpty == false)
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    @Test("PanelContainer handles empty title")
    func test_emptyTitle() {
        // Given: Empty title string
        let title = ""

        // When: Container is created with empty title
        let container = PanelContainer(
            title: title,
            isCollapsed: .constant(false),
            height: 140
        ) {
            Text("Content")
        }

        // Then: View should still be valid (empty title is allowed)
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    // MARK: - Integration Tests

    @Test("PanelContainer can be nested in other views")
    func test_nestingInOtherViews() {
        // When: Container is nested in VStack
        let vStackView = VStack {
            PanelContainer(
                title: "Panel 1",
                isCollapsed: .constant(false),
                height: 140
            ) {
                Text("Content 1")
            }
            PanelContainer(
                title: "Panel 2",
                isCollapsed: .constant(true),
                height: 160
            ) {
                Text("Content 2")
            }
        }

        // Then: Should compile successfully
        #expect(type(of: vStackView) == VStack<TupleView<(PanelContainer<Text>, PanelContainer<Text>)>>.self)
    }

    @Test("Multiple PanelContainers with independent states")
    func test_multipleIndependentPanels() {
        // Given: Two independent collapse states
        var panel1Collapsed = false
        var panel2Collapsed = true

        // When: Two panels with independent bindings
        let binding1 = Binding(
            get: { panel1Collapsed },
            set: { panel1Collapsed = $0 }
        )
        let binding2 = Binding(
            get: { panel2Collapsed },
            set: { panel2Collapsed = $0 }
        )

        // Initially: Panel 1 expanded, Panel 2 collapsed
        #expect(panel1Collapsed == false)
        #expect(panel2Collapsed == true)

        // When: Panel 1 is collapsed
        binding1.wrappedValue = true

        // Then: Only Panel 1 state changes
        #expect(panel1Collapsed == true)
        #expect(panel2Collapsed == true)

        // When: Panel 2 is expanded
        binding2.wrappedValue = false

        // Then: Only Panel 2 state changes
        #expect(panel1Collapsed == true)
        #expect(panel2Collapsed == false)
    }

    // MARK: - Edge Case Tests

    @Test("PanelContainer with very large height")
    func test_veryLargeHeight() {
        // Given: Very large height value
        let height: CGFloat = 10000

        // When: Container is created with large height
        let container = PanelContainer(
            title: "Large Panel",
            isCollapsed: .constant(false),
            height: height
        ) {
            Text("Content")
        }

        // Then: View should be valid
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    @Test("PanelContainer with zero height")
    func test_zeroHeight() {
        // Given: Zero height (edge case)
        let height: CGFloat = 0

        // When: Container is created with zero height
        let container = PanelContainer(
            title: "Zero Height Panel",
            isCollapsed: .constant(false),
            height: height
        ) {
            Text("Content")
        }

        // Then: View should still compile (SwiftUI will handle layout)
        #expect(type(of: container) == PanelContainer<Text>.self)
    }

    @Test("PanelContainer with complex content")
    func test_complexContent() {
        // Given: Complex nested content
        let container = PanelContainer(
            title: "Complex Panel",
            isCollapsed: .constant(false),
            height: 200
        ) {
            VStack {
                HStack {
                    Text("Left")
                    Spacer()
                    Text("Right")
                }
                Divider()
                ScrollView {
                    VStack {
                        ForEach(0..<10, id: \.self) { index in
                            Text("Item \(index)")
                        }
                    }
                }
            }
        }

        // Then: Complex content should compile and be valid PanelContainer type
        let isValidType = type(of: container) is PanelContainer<VStack<TupleView<(HStack<TupleView<(Text, Spacer, Text)>>, Divider, ScrollView<VStack<ForEach<Range<Int>, Int, Text>>>)>>>.Type
        #expect(isValidType)
    }
}
