// ABOUTME: SwiftUI view for hands panel displaying left hand, right hand, and prepared spell with emoji icons

import SwiftUI
import VaalinCore

/// Displays the hands panel showing held items and prepared spell.
///
/// `HandsPanel` presents three rows showing:
/// - Left hand: Items held in left hand (e.g., weapons, shields)
/// - Right hand: Items held in right hand
/// - Prepared spell: Currently prepared spell ready to cast
///
/// ## Visual Design
///
/// Layout follows Illthorn's three-row structure with emoji icons:
/// - ✋ Left hand item name
/// - 🤚 Right hand item name
/// - ✨ Prepared spell name
///
/// Empty states display "Empty" for hands and "None" for spell with secondary text color and italic style.
///
/// ## PanelContainer Integration
///
/// Wraps content in `PanelContainer` with:
/// - Title: "Hands"
/// - Fixed height: 140pt (per FR-3.1 requirements)
/// - Collapsible header with Liquid Glass material
/// - Persistent collapsed state via Settings binding
///
/// ## EventBus Updates
///
/// Updates automatically via `HandsPanelViewModel` which subscribes to:
/// - `metadata/left` - Left hand item updates
/// - `metadata/right` - Right hand item updates
/// - `metadata/spell` - Prepared spell updates
///
/// The view model calls `setup()` in the `.task` modifier to initialize EventBus subscriptions.
///
/// ## Performance
///
/// Lightweight view with minimal re-renders:
/// - @Observable ensures only changed properties trigger updates
/// - Fixed height prevents layout thrashing
/// - Emoji SF Symbols-compatible rendering
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = HandsPanelViewModel(eventBus: eventBus)
///
/// HandsPanel(viewModel: viewModel)
///     .frame(width: 300)
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `hands-container.lit.ts` and `hand-row.lit.ts` components,
/// reinterpreted for SwiftUI with native macOS Liquid Glass design.
public struct HandsPanel: View {
    // MARK: - Properties

    /// View model managing hands/spell state via EventBus subscriptions.
    @Bindable public var viewModel: HandsPanelViewModel

    /// Collapsed state for PanelContainer (persisted via Settings).
    @State private var isCollapsed: Bool = false

    // MARK: - Constants

    /// Emoji icons for hand and spell rows
    private enum HandEmoji {
        static let leftHand = "✋"
        static let rightHand = "🤚"
        static let spell = "✨"
    }

    // MARK: - Initializer

    /// Creates a hands panel with the specified view model.
    ///
    /// - Parameter viewModel: View model managing hands/spell state
    ///
    /// **Important:** The view model's `setup()` method is called automatically
    /// in the view's `.task` modifier to initialize EventBus subscriptions.
    public init(viewModel: HandsPanelViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        PanelContainer(
            title: "Hands",
            isCollapsed: $isCollapsed,
            height: 140
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // Left hand row
                HandRow(
                    icon: HandEmoji.leftHand,
                    content: viewModel.leftHand,
                    isEmpty: viewModel.leftHand == "Empty"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Left hand: \(viewModel.leftHand)")

                // Right hand row
                HandRow(
                    icon: HandEmoji.rightHand,
                    content: viewModel.rightHand,
                    isEmpty: viewModel.rightHand == "Empty"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Right hand: \(viewModel.rightHand)")

                // Prepared spell row
                HandRow(
                    icon: HandEmoji.spell,
                    content: viewModel.preparedSpell,
                    isEmpty: viewModel.preparedSpell == "None"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Prepared spell: \(viewModel.preparedSpell)")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial)
        }
        .task {
            // Initialize EventBus subscriptions on appear
            await viewModel.setup()
        }
    }
}

// MARK: - Subviews

/// Individual row displaying an icon and content with appropriate styling.
///
/// Displays emoji icon next to item/spell name with proper spacing and truncation.
/// Empty states show secondary color and italic style per Illthorn reference.
/// Includes hover feedback and Liquid Glass icon treatments.
private struct HandRow: View {
    /// Emoji icon (✋, 🤚, or ✨).
    let icon: String

    /// Content text (item name, spell name, "Empty", or "None").
    let content: String

    /// Whether this row represents an empty state.
    let isEmpty: Bool

    /// Tracks hover state for visual feedback.
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Emoji icon with floating badge effect
            Text(icon)
                .font(.system(size: 16))
                .opacity(isEmpty ? 0.5 : 0.95)
                .frame(width: 20, alignment: .center)
                .padding(6)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(isEmpty ? 0.3 : 0.6)
                )

            // Content text with typography enhancements
            Text(content)
                .font(.system(size: 13, weight: isEmpty ? .regular : .medium, design: .monospaced))
                .foregroundStyle(isEmpty ? .secondary : Color(nsColor: .labelColor))
                .italic(isEmpty)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .visualEffect { content, _ in
                    content
                        .saturation(isEmpty ? 0.8 : 1.1)
                        .brightness(isEmpty ? 0.0 : 0.02)
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
                .opacity(isHovering ? 0.5 : 0.0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Previews

struct HandsPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Empty state
            HandsPanel(viewModel: createEmptyViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Empty State")
                .preferredColorScheme(.dark)

            // Preview 2: Populated state
            HandsPanel(viewModel: createPopulatedViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Populated State")
                .preferredColorScheme(.dark)

            // Preview 3: Long item names (truncation test)
            HandsPanel(viewModel: createLongNamesViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Long Names (Truncation)")
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Preview Helpers

    /// Creates view model with empty hands and no spell.
    private static func createEmptyViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Default state: leftHand = "Empty", rightHand = "Empty", preparedSpell = "None"
        return viewModel
    }

    /// Creates view model with populated hands and spell.
    private static func createPopulatedViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Manually set state for preview (bypassing EventBus)
        viewModel.leftHand = "steel broadsword"
        viewModel.rightHand = "wooden shield"
        viewModel.preparedSpell = "Minor Shock"
        return viewModel
    }

    /// Creates view model with long item names to test truncation.
    private static func createLongNamesViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Long names to test text truncation
        viewModel.leftHand = "an enruned vultite greatsword with intricate silver filigree"
        viewModel.rightHand = "a steel-reinforced tower shield with gold embossing"
        viewModel.preparedSpell = "Mass Elemental Wave (410)"
        return viewModel
    }
}
