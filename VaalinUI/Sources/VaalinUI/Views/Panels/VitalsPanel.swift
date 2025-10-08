// ABOUTME: SwiftUI view for vitals panel displaying health, mana, stamina, spirit, mind, stance, and encumbrance

import SwiftUI
import VaalinCore

/// Displays the vitals panel showing character vital statistics.
///
/// `VitalsPanel` presents seven rows showing:
/// - Health: Red→Yellow→Green gradient based on percentage (< 33% red, 33-66% yellow, > 66% green)
/// - Mana: Blue progress bar
/// - Stamina: Yellow progress bar
/// - Spirit: Purple progress bar
/// - Mind: Teal progress bar
/// - Stance: Text label (e.g., "offensive", "defensive")
/// - Encumbrance: Text label (e.g., "none", "light", "heavy")
///
/// ## Visual Design
///
/// Layout follows Illthorn's vertical stack with labeled progress bars:
/// - 5 progress bars with label + value + colored bar
/// - 2 text fields with label + value (no progress bar)
/// - Indeterminate state: Shows "..." when percentage is nil
/// - Font sizing: 11pt for all labels/values, monospaced for numeric values
///
/// ## Color Scheme (Catppuccin Mocha)
///
/// Vital-specific colors matching FR-3.2 requirements:
/// - Health: Dynamic based on percentage
///   - < 33%: Red (#f38ba8) - critical
///   - 33-66%: Yellow (#f9e2af) - medium
///   - > 66%: Green (#a6e3a1) - high
/// - Mana: Blue (#89b4fa)
/// - Stamina: Yellow (#f9e2af)
/// - Spirit: Purple (#cba6f7)
/// - Mind: Teal (#94e2d5)
///
/// ## PanelContainer Integration
///
/// Wraps content in `PanelContainer` with:
/// - Title: "Vitals"
/// - Fixed height: 160pt (per FR-3.2 requirements)
/// - Collapsible header with Liquid Glass material
/// - Persistent collapsed state via Settings binding
///
/// ## EventBus Updates
///
/// Updates automatically via `VitalsPanelViewModel` which subscribes to:
/// - `metadata/progressBar/health` - Health percentage updates
/// - `metadata/progressBar/mana` - Mana percentage updates
/// - `metadata/progressBar/stamina` - Stamina percentage updates
/// - `metadata/progressBar/spirit` - Spirit percentage updates
/// - `metadata/progressBar/mindState` - Mind percentage updates
/// - `metadata/progressBar/pbarStance` - Stance text updates
/// - `metadata/progressBar/encumlevel` - Encumbrance text updates
///
/// The view model calls `setup()` in the `.task` modifier to initialize EventBus subscriptions.
///
/// ## Performance
///
/// Lightweight view with minimal re-renders:
/// - @Observable ensures only changed properties trigger updates
/// - Fixed height prevents layout thrashing
/// - Native SwiftUI ProgressView for efficient rendering
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = VitalsPanelViewModel(eventBus: eventBus)
///
/// VitalsPanel(viewModel: viewModel)
///     .frame(width: 300)
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `vitals-ui.lit.ts` and `vital-stat.lit.ts` components,
/// reinterpreted for SwiftUI with native macOS Liquid Glass design.
public struct VitalsPanel: View {
    // MARK: - Properties

    /// View model managing vitals state via EventBus subscriptions.
    @Bindable public var viewModel: VitalsPanelViewModel

    /// Collapsed state for PanelContainer (persisted via Settings).
    @State private var isCollapsed: Bool = false

    // MARK: - Constants

    /// Catppuccin Mocha color palette for vitals
    private enum VitalColor {
        static let healthCritical = Color(red: 0.953, green: 0.545, blue: 0.659) // #f38ba8 red
        static let healthMedium = Color(red: 0.976, green: 0.886, blue: 0.686)   // #f9e2af yellow
        static let healthHigh = Color(red: 0.651, green: 0.890, blue: 0.631)     // #a6e3a1 green
        static let mana = Color(red: 0.537, green: 0.706, blue: 0.980)           // #89b4fa blue
        static let stamina = Color(red: 0.976, green: 0.886, blue: 0.686)        // #f9e2af yellow
        static let spirit = Color(red: 0.796, green: 0.651, blue: 0.969)         // #cba6f7 purple
        static let mind = Color(red: 0.580, green: 0.886, blue: 0.835)           // #94e2d5 teal
    }

    // MARK: - Initializer

    /// Creates a vitals panel with the specified view model.
    ///
    /// - Parameter viewModel: View model managing vitals state
    ///
    /// **Important:** The view model's `setup()` method is called automatically
    /// in the view's `.task` modifier to initialize EventBus subscriptions.
    public init(viewModel: VitalsPanelViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        PanelContainer(
            title: "Vitals",
            isCollapsed: $isCollapsed,
            height: 160
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // Health progress bar (dynamic color based on percentage)
                VitalProgressBar(
                    label: "Health",
                    percentage: viewModel.health,
                    color: healthColor(percentage: viewModel.health)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Health: \(viewModel.health.map { "\($0) percent" } ?? "unknown")")

                // Mana progress bar (blue)
                VitalProgressBar(
                    label: "Mana",
                    percentage: viewModel.mana,
                    color: VitalColor.mana
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mana: \(viewModel.mana.map { "\($0) percent" } ?? "unknown")")

                // Stamina progress bar (yellow)
                VitalProgressBar(
                    label: "Stamina",
                    percentage: viewModel.stamina,
                    color: VitalColor.stamina
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stamina: \(viewModel.stamina.map { "\($0) percent" } ?? "unknown")")

                // Spirit progress bar (purple)
                VitalProgressBar(
                    label: "Spirit",
                    percentage: viewModel.spirit,
                    color: VitalColor.spirit
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spirit: \(viewModel.spirit.map { "\($0) percent" } ?? "unknown")")

                // Mind progress bar (teal)
                VitalProgressBar(
                    label: "Mind",
                    percentage: viewModel.mind,
                    color: VitalColor.mind
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mind: \(viewModel.mind.map { "\($0) percent" } ?? "unknown")")

                // Stance text field
                VitalTextField(
                    label: "Stance",
                    value: viewModel.stance
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stance: \(viewModel.stance)")

                // Encumbrance text field
                VitalTextField(
                    label: "Encumbrance",
                    value: viewModel.encumbrance
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Encumbrance: \(viewModel.encumbrance)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            // Initialize EventBus subscriptions on appear
            await viewModel.setup()
        }
    }

    // MARK: - Helper Methods

    /// Determines health bar color based on percentage thresholds.
    ///
    /// - Parameter percentage: Health percentage (0-100) or nil for indeterminate
    /// - Returns: Color matching health level (red/yellow/green)
    ///
    /// Color mapping:
    /// - < 33%: Red (critical)
    /// - 33-66%: Yellow (medium)
    /// - > 66%: Green (high)
    /// - nil: Green (default for indeterminate state)
    private func healthColor(percentage: Int?) -> Color {
        guard let percentage = percentage else {
            // Indeterminate state - use green as default
            return VitalColor.healthHigh
        }

        if percentage < 33 {
            return VitalColor.healthCritical
        } else if percentage < 67 {
            return VitalColor.healthMedium
        } else {
            return VitalColor.healthHigh
        }
    }
}

// MARK: - Subviews

/// Progress bar row displaying label, value, and colored progress indicator.
///
/// Shows label + percentage text above a native SwiftUI ProgressView with custom tint.
/// Indeterminate state shows "..." when percentage is nil.
private struct VitalProgressBar: View {
    /// Vital label (e.g., "Health", "Mana").
    let label: String

    /// Percentage value (0-100) or nil for indeterminate state.
    let percentage: Int?

    /// Progress bar tint color (vital-specific).
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label + value text
            HStack(spacing: 6) {
                Text(label.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Text(valueText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Progress bar
            if let percentage = percentage {
                // Determinate state - show percentage
                ProgressView(value: Double(percentage), total: 100.0)
                    .tint(color)
                    .frame(height: 6)
            } else {
                // Indeterminate state - show indeterminate progress bar
                ProgressView()
                    .tint(color)
                    .frame(height: 6)
            }
        }
    }

    /// Formatted value text for percentage display.
    ///
    /// Returns "..." for indeterminate state (nil percentage).
    private var valueText: String {
        guard let percentage = percentage else {
            return "..."
        }
        return "\(percentage)%"
    }
}

/// Text field row displaying label and value (no progress bar).
///
/// Used for stance and encumbrance which are text-only fields.
private struct VitalTextField: View {
    /// Field label (e.g., "Stance", "Encumbrance").
    let label: String

    /// Field value text.
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Previews

struct VitalsPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Empty state (all vitals nil/indeterminate)
            VitalsPanel(viewModel: createEmptyViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Empty State")
                .preferredColorScheme(.dark)

            // Preview 2: Populated state (normal vitals)
            VitalsPanel(viewModel: createPopulatedViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Populated State")
                .preferredColorScheme(.dark)

            // Preview 3: Critical state (low health)
            VitalsPanel(viewModel: createCriticalViewModel())
                .frame(width: 300)
                .padding()
                .previewDisplayName("Critical State (Low Health)")
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Preview Helpers

    /// Creates view model with empty/indeterminate vitals.
    private static func createEmptyViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Default state: all vitals nil (indeterminate), stance="offensive", encumbrance="none"
        return viewModel
    }

    /// Creates view model with populated vitals (normal gameplay).
    private static func createPopulatedViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Manually set state for preview (bypassing EventBus)
        viewModel.health = 75
        viewModel.mana = 85
        viewModel.stamina = 90
        viewModel.spirit = 65
        viewModel.mind = 80
        viewModel.stance = "offensive"
        viewModel.encumbrance = "light"
        return viewModel
    }

    /// Creates view model with critical health (< 33%).
    private static func createCriticalViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Critical health state (red color)
        viewModel.health = 25
        viewModel.mana = 60
        viewModel.stamina = 50
        viewModel.spirit = 70
        viewModel.mind = 75
        viewModel.stance = "defensive"
        viewModel.encumbrance = "heavy"
        return viewModel
    }
}
