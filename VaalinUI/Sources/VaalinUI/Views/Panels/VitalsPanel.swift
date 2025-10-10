// ABOUTME: SwiftUI view for vitals panel displaying health, mana, stamina, spirit, mind, stance, and encumbrance

import SwiftUI
import VaalinCore

/// Displays the vitals panel showing character vital statistics.
///
/// `VitalsPanel` presents seven rows showing:
/// - Health: Red→Yellow→Green gradient based on percentage (< 33% red, 33-66% yellow, > 66% green)
/// - Mana: Blue progress bar with fraction (e.g., "45/85")
/// - Stamina: Yellow progress bar with fraction (e.g., "72/95")
/// - Spirit: Purple progress bar with fraction (e.g., "54/100")
/// - Mind: Teal progress bar with **descriptive text** (e.g., "clear", "muddled") - not fractions
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
            height: 200
        ) {
            VStack(alignment: .leading, spacing: 5) {
                // Health progress bar (dynamic color based on percentage)
                VitalProgressBar(
                    label: "Health",
                    percentage: viewModel.health,
                    text: viewModel.healthText,
                    color: healthColor(percentage: viewModel.health)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Health: \(viewModel.healthText ?? "unknown")")

                // Mana progress bar (blue)
                VitalProgressBar(
                    label: "Mana",
                    percentage: viewModel.mana,
                    text: viewModel.manaText,
                    color: VitalColor.mana
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mana: \(viewModel.manaText ?? "unknown")")

                // Stamina progress bar (yellow)
                VitalProgressBar(
                    label: "Stamina",
                    percentage: viewModel.stamina,
                    text: viewModel.staminaText,
                    color: VitalColor.stamina
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stamina: \(viewModel.staminaText ?? "unknown")")

                // Spirit progress bar (purple)
                VitalProgressBar(
                    label: "Spirit",
                    percentage: viewModel.spirit,
                    text: viewModel.spiritText,
                    color: VitalColor.spirit
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spirit: \(viewModel.spiritText ?? "unknown")")

                // Mind progress bar (teal)
                VitalProgressBar(
                    label: "Mind",
                    percentage: viewModel.mind,
                    text: viewModel.mindText,
                    color: VitalColor.mind
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mind: \(viewModel.mindText ?? "unknown")")

                // Visual separator between vitals and stance/encumbrance
                Divider()
                    .padding(.vertical, 6)

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
            .padding(.top, 18)
            .padding(.bottom, 16)
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
/// Shows label + fraction text above a custom Capsule-based progress bar.
/// Indeterminate state shows animated shuffle bar sliding back and forth.
private struct VitalProgressBar: View {
    /// Vital label (e.g., "Health", "Mana").
    let label: String

    /// Percentage value (0-100) or nil for indeterminate state.
    let percentage: Int?

    /// Text value showing actual amounts (e.g., "74/74", "50/100").
    let text: String?

    /// Progress bar tint color (vital-specific).
    let color: Color

    /// Animation offset for indeterminate shuffle (0.0 to 1.0)
    @State private var shuffleOffset: CGFloat = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
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

            // Custom Capsule progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track (gray)
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 3)

                    // Foreground bar (colored)
                    if let percentage = percentage {
                        // Determinate state: fixed width based on percentage
                        Capsule()
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(percentage) / 100.0, height: 3)
                    } else {
                        // Indeterminate state: animated shuffle bar
                        let shuffleWidth = geometry.size.width * 0.3  // 30% width shuffle bar
                        let maxOffset = geometry.size.width - shuffleWidth

                        Capsule()
                            .fill(color.opacity(0.6))
                            .frame(width: shuffleWidth, height: 3)
                            .offset(x: maxOffset * shuffleOffset)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                    shuffleOffset = 1.0
                                }
                            }
                    }
                }
            }
            .frame(height: 3)
        }
    }

    /// Formatted value text for display.
    ///
    /// Returns "..." for indeterminate state (nil text).
    private var valueText: String {
        guard let text = text else {
            return "..."
        }
        return text
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
