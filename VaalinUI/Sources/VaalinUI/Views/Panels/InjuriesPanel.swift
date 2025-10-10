// ABOUTME: SwiftUI view for injuries panel displaying body part injuries and scars with fixed grid layout

import SwiftUI

/// Displays the injuries panel showing body part injury and scar status.
///
/// `InjuriesPanel` presents a fixed 3-column grid showing injury status for 11 body parts:
/// - Head, Neck
/// - Arms (left/right), Hands (left/right)
/// - Chest, Abdomen, Back
/// - Legs (left/right)
///
/// ## Visual Design
///
/// Layout follows a fixed grid structure with 80pt column width:
/// ```
/// ┌────────────────────────────────┐
/// │ Injuries                        │
/// ├────────────────────────────────┤
/// │                                 │
/// │    HEAD         NECK     CHEST │
/// │    ●●●          ○        ●●    │
/// │                                 │
/// │    L.ARM      ABDOMEN   R.ARM  │
/// │    ○            ●        ○     │
/// │                                 │
/// │    L.HAND       BACK   R.HAND  │
/// │    ○            ◉        ●     │
/// │                                 │
/// │    L.LEG                R.LEG  │
/// │    ●                     ○     │
/// │                                 │
/// └────────────────────────────────┘
/// ```
///
/// **Cell Structure:**
/// - Label: 9pt SF Mono, uppercase, secondary color
/// - Indicator: 24×24 frame with severity dots or hollow circle
///
/// **Grid Layout:**
/// - Row 1: head, neck, chest
/// - Row 2: leftArm, abdomen, rightArm
/// - Row 3: leftHand, back, rightHand
/// - Row 4: leftLeg, (empty), rightLeg
///
/// ## Indicator States
///
/// **Healthy (no injury):**
/// - Hollow circle ○ - 16×16, gray 30% opacity stroke
///
/// **Injured/Scarred:**
/// - Stacked dots (6×6 each, 2pt spacing)
/// - Count = severity (1-3 dots)
/// - Injury: Full color (yellow/orange/red)
/// - Scar: 50% opacity of injury colors
///
/// ## Color Scheme (Catppuccin Mocha)
///
/// Severity colors:
/// - Severity 1: Yellow (#f9e2af)
/// - Severity 2: Orange (#fab387)
/// - Severity 3: Red (#f38ba8)
/// - Scar: Same colors at 50% opacity
///
/// ## PanelContainer Integration
///
/// Wraps content in `PanelContainer` with:
/// - Title: "Injuries"
/// - Fixed height: 180pt (per FR-3.6 requirements)
/// - Collapsible header with Liquid Glass material
/// - Persistent collapsed state via Settings binding
///
/// ## EventBus Updates
///
/// Updates automatically via `InjuriesPanelViewModel` which subscribes to:
/// - `metadata/dialogData` - Injuries dialog updates with `<image>` tags
///
/// The view model calls `setup()` in the `.task` modifier to initialize EventBus subscriptions.
///
/// ## Accessibility
///
/// - Each location: Combined accessibility element
/// - Label format: "Head: injured severity 3" / "Neck: healthy"
/// - Scar distinction: "Chest: scarred severity 1"
/// - VoiceOver reads injury status for all body parts
///
/// ## Performance
///
/// Lightweight view with minimal re-renders:
/// - @Observable ensures only changed properties trigger updates
/// - Fixed height prevents layout thrashing
/// - Fixed grid prevents layout shifts
/// - Custom shape rendering is efficient
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
///
/// InjuriesPanel(viewModel: viewModel)
///     .frame(width: 300)
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `injuries-container.lit.ts` and `injury-ui.lit.ts` components,
/// reinterpreted for SwiftUI with native macOS Liquid Glass design.
public struct InjuriesPanel: View {
    // MARK: - Properties

    /// View model managing injuries state via EventBus subscriptions.
    @Bindable public var viewModel: InjuriesPanelViewModel

    /// Collapsed state for PanelContainer (persisted via Settings).
    @State private var isCollapsed: Bool = false

    // MARK: - Grid Data Structure

    /// Grid location definition for fixed 3-column layout.
    ///
    /// Each cell contains optional BodyPart and display label.
    /// nil BodyPart creates empty cell (maintains grid structure).
    private struct GridLocation {
        let bodyPart: BodyPart?
        let label: String
    }

    /// Fixed grid layout data (12 cells: 11 body parts + 1 empty).
    ///
    /// **CRITICAL:** Grid order must never change - ensures stable layout.
    /// Empty cells maintain 3-column alignment regardless of injuries.
    private let gridLocations: [GridLocation] = [
        // Row 1
        GridLocation(bodyPart: .head, label: "HEAD"),
        GridLocation(bodyPart: .neck, label: "NECK"),
        GridLocation(bodyPart: .chest, label: "CHEST"),

        // Row 2
        GridLocation(bodyPart: .leftArm, label: "L.ARM"),
        GridLocation(bodyPart: .abdomen, label: "ABDOMEN"),
        GridLocation(bodyPart: .rightArm, label: "R.ARM"),

        // Row 3
        GridLocation(bodyPart: .leftHand, label: "L.HAND"),
        GridLocation(bodyPart: .back, label: "BACK"),
        GridLocation(bodyPart: .rightHand, label: "R.HAND"),

        // Row 4
        GridLocation(bodyPart: .leftLeg, label: "L.LEG"),
        GridLocation(bodyPart: nil, label: ""),
        GridLocation(bodyPart: .rightLeg, label: "R.LEG")
    ]

    // MARK: - Initializer

    /// Creates an injuries panel with the specified view model.
    ///
    /// - Parameter viewModel: View model managing injuries state
    ///
    /// **Important:** The view model's `setup()` method is called automatically
    /// in the view's `.task` modifier to initialize EventBus subscriptions.
    public init(viewModel: InjuriesPanelViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        PanelContainer(
            title: "Injuries",
            isCollapsed: $isCollapsed,
            height: 180
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(80), alignment: .leading),
                    GridItem(.fixed(80), alignment: .leading),
                    GridItem(.fixed(80), alignment: .leading)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(Array(gridLocations.enumerated()), id: \.offset) { _, location in
                    if let bodyPart = location.bodyPart {
                        // Body part cell with indicator
                        LocationCell(
                            label: location.label,
                            status: viewModel.injuries[bodyPart] ?? InjuryStatus()
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityLabel(for: bodyPart))
                    } else {
                        // Empty cell (maintains grid structure)
                        Color.clear
                            .frame(width: 80, height: 36)
                            .accessibilityHidden(true)
                    }
                }
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

    /// Generates accessibility label for body part.
    ///
    /// - Parameter bodyPart: Body part to describe
    /// - Returns: Accessibility label string
    ///
    /// Format:
    /// - Injured: "Head: injured severity 3"
    /// - Scarred: "Chest: scarred severity 1"
    /// - Healthy: "Neck: healthy"
    private func accessibilityLabel(for bodyPart: BodyPart) -> String {
        let status = viewModel.injuries[bodyPart] ?? InjuryStatus()
        let partName = bodyPart.rawValue.capitalized

        if !status.isInjured {
            return "\(partName): healthy"
        }

        let typeText = status.injuryType == .injury ? "injured" : "scarred"
        return "\(partName): \(typeText) severity \(status.severity)"
    }
}

// MARK: - Subviews

/// Location cell displaying label and injury indicator.
///
/// Shows uppercase label above indicator in 24×24 frame.
/// Left-aligned content with consistent spacing.
private struct LocationCell: View {
    /// Display label (e.g., "HEAD", "L.ARM")
    let label: String

    /// Injury status for indicator rendering
    let status: InjuryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Indicator
            LocationIndicator(status: status)
                .frame(width: 24, height: 24)
        }
    }
}

/// Location indicator showing injury severity and type.
///
/// Renders in 24×24 frame with three states:
/// - Healthy: Hollow circle (16×16, gray 30% opacity)
/// - Injured: Stacked dots (severity count, full color)
/// - Scarred: Stacked dots (severity count, 50% opacity)
///
/// ## Dot Layout
/// - Size: 6×6 each
/// - Spacing: 2pt between dots
/// - Centered in 24×24 frame
/// - Vertical stack alignment
///
/// ## Color Mapping
/// - Severity 1: Yellow (#f9e2af)
/// - Severity 2: Orange (#fab387)
/// - Severity 3: Red (#f38ba8)
/// - Scar: Same colors at 50% opacity
private struct LocationIndicator: View {
    /// Injury status to render
    let status: InjuryStatus

    /// Catppuccin Mocha severity colors
    private enum SeverityColor {
        static let severity1 = Color(red: 0.976, green: 0.886, blue: 0.686)  // Yellow #f9e2af
        static let severity2 = Color(red: 0.980, green: 0.702, blue: 0.529)  // Orange #fab387
        static let severity3 = Color(red: 0.953, green: 0.545, blue: 0.659)  // Red #f38ba8
        static let healthy = Color.gray  // Hollow circle
    }

    var body: some View {
        ZStack {
            if status.isInjured {
                // Injured/scarred: stacked dots
                VStack(spacing: 2) {
                    ForEach(0..<status.severity, id: \.self) { _ in
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 6, height: 6)
                    }
                }
            } else {
                // Healthy: hollow circle
                Circle()
                    .strokeBorder(SeverityColor.healthy.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }
        }
        .frame(width: 24, height: 24)
    }

    /// Calculates indicator color based on severity and injury type.
    ///
    /// - Returns: Color with appropriate severity tint and opacity
    ///
    /// Logic:
    /// 1. Select base color from severity
    /// 2. Apply 50% opacity if scar type
    /// 3. Return full opacity if injury type
    private var indicatorColor: Color {
        let baseColor: Color = switch status.severity {
        case 1: SeverityColor.severity1
        case 2: SeverityColor.severity2
        case 3: SeverityColor.severity3
        default: SeverityColor.healthy
        }

        return status.injuryType == .scar ? baseColor.opacity(0.5) : baseColor
    }
}
