// ABOUTME: SwiftUI view for compass panel displaying room navigation with compass rose and clickable exits

import SwiftUI
import VaalinCore
import VaalinNetwork

/// Displays the compass panel showing room name and navigation directions.
///
/// `CompassPanel` presents room navigation information with:
/// - Room name at top (from EventBus `metadata/streamWindow/room` updates)
/// - Room ID display
/// - 8-direction compass rose with special exits (up/out/down)
/// - Clickable exits for movement commands (requires CommandSending injection)
///
/// ## Visual Design
///
/// Layout follows Illthorn's compass structure with room info and compass rose:
/// ```
/// ┌────────────────────────────────┐
/// │  [Town Square, Market]         │  ← Room name (truncated)
/// │  Room: 228                      │  ← Room ID
/// ├────────────────────────────────┤
/// │    ↑                            │
/// │    ○         N                  │  ← Compass rose
/// │    ↓      NW   NE               │
/// │          W     E                │
/// │           SW   SE               │
/// │              S                  │
/// └────────────────────────────────┘
/// ```
///
/// **Room Display**:
/// - Room name: Primary text, truncated with ellipsis if too long
/// - Room ID: Secondary text, smaller font
/// - Empty state: Shows "Unknown Room" and "Room: 0"
///
/// **Compass Rose**:
/// - 8 cardinal/diagonal directions + 3 special exits
/// - Active exits highlighted in green
/// - Inactive exits dimmed (30% opacity)
///
/// ## PanelContainer Integration
///
/// Wraps content in `PanelContainer` with:
/// - Title: "Compass"
/// - Fixed height: 160pt (per FR-3.4 requirements)
/// - Collapsible header with Liquid Glass material
/// - Persistent collapsed state via Settings binding
///
/// ## EventBus Updates
///
/// Updates automatically via `CompassPanelViewModel` which subscribes to:
/// - `metadata/nav` - Room ID updates
/// - `metadata/compass` - Exit list updates
/// - `metadata/streamWindow/room` - Room title updates
///
/// The view model calls `setup()` in the `.task` modifier to initialize EventBus subscriptions.
///
/// ## CommandSending Integration
///
/// Optional `CommandSending` actor enables clickable exits:
/// - When provided, exits become tappable buttons
/// - Tapping an exit sends movement command to game server
/// - Example: Tapping north exit → `connection.send(command: "north")`
/// - Commands use full direction names (north, northeast, etc.)
///
/// **Direction name mapping**:
/// - n → north, ne → northeast, e → east, se → southeast
/// - s → south, sw → southwest, w → west, nw → northwest
/// - up → up, down → down, out → out
///
/// ## Accessibility
///
/// - Room info: `.accessibilityElement(children: .combine)`
/// - Compass: Individual exit labels via `CompassRose` component
/// - VoiceOver reads available exits and navigation state
///
/// ## Performance
///
/// Lightweight view with minimal re-renders:
/// - @Observable ensures only changed properties trigger updates
/// - Fixed height prevents layout thrashing
/// - Efficient Set lookups for exit highlighting
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let connection = LichConnection()
/// let viewModel = CompassPanelViewModel(eventBus: eventBus)
///
/// // With CommandSending (clickable exits)
/// CompassPanel(viewModel: viewModel, connection: connection)
///
/// // Display-only (no clicks)
/// CompassPanel(viewModel: viewModel)
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `compass-rose-container.lit.ts` and `compass-rose-ui.lit.ts`,
/// reinterpreted for SwiftUI with native macOS Liquid Glass design.
public struct CompassPanel: View {
    // MARK: - Properties

    /// View model managing compass/room state via EventBus subscriptions.
    @Bindable public var viewModel: CompassPanelViewModel

    /// Optional connection for sending movement commands (enables clickable exits).
    private let connection: (any CommandSending)?

    /// Collapsed state for PanelContainer (persisted via Settings).
    @State private var isCollapsed: Bool = false

    // MARK: - Constants

    /// Direction abbreviation to full name mapping for commands
    private let directionNames: [String: String] = [
        "n": "north",
        "ne": "northeast",
        "e": "east",
        "se": "southeast",
        "s": "south",
        "sw": "southwest",
        "w": "west",
        "nw": "northwest",
        "up": "up",
        "down": "down",
        "out": "out"
    ]

    // MARK: - Initializer

    /// Creates a compass panel with the specified view model.
    ///
    /// - Parameters:
    ///   - viewModel: View model managing compass/room state
    ///   - connection: Optional CommandSending actor for clickable exits
    ///
    /// **Important:** The view model's `setup()` method is called automatically
    /// in the view's `.task` modifier to initialize EventBus subscriptions.
    public init(
        viewModel: CompassPanelViewModel,
        connection: (any CommandSending)? = nil
    ) {
        self.viewModel = viewModel
        self.connection = connection
    }

    // MARK: - Body

    public var body: some View {
        PanelContainer(
            title: "Compass",
            isCollapsed: $isCollapsed,
            height: 160
        ) {
            VStack(alignment: .center, spacing: 16) {
                // Room information
                roomInfo
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(roomAccessibilityLabel)

                // Compass rose with exits
                CompassRose(
                    exits: viewModel.exits,
                    onDirectionTap: directionTapHandler
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            // Initialize EventBus subscriptions on appear
            await viewModel.setup()
        }
    }

    // MARK: - Subviews

    /// Room information display (name and ID).
    ///
    /// Shows room title and room ID with appropriate styling.
    /// Empty state displays "Unknown Room" and "Room: 0".
    private var roomInfo: some View {
        VStack(alignment: .center, spacing: 4) {
            // Room name
            Text(roomName)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(viewModel.roomName.isEmpty ? .secondary : .primary)
                .italic(viewModel.roomName.isEmpty)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Room ID
            HStack(spacing: 4) {
                Text("Room")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(viewModel.roomId)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helper Methods

    /// Handles compass direction tap by sending movement command.
    ///
    /// - Parameter direction: Direction abbreviation (e.g., "n", "ne", "up")
    ///
    /// Converts abbreviation to full direction name and sends command to server.
    /// Errors are silently ignored (logged by connection actor).
    private func handleDirectionTap(_ direction: String) {
        guard let connection = connection else { return }

        // Convert abbreviation to full direction name
        let fullDirection = directionNames[direction] ?? direction

        // Send command asynchronously
        Task {
            do {
                try await connection.send(command: fullDirection)
            } catch {
                // Connection will log errors - no UI feedback needed
            }
        }
    }

    // MARK: - Computed Properties

    /// Display text for room name (with fallback for empty state).
    private var roomName: String {
        viewModel.roomName.isEmpty ? "Unknown Room" : viewModel.roomName
    }

    /// Accessibility label for room information.
    private var roomAccessibilityLabel: String {
        "Room: \(roomName), ID: \(viewModel.roomId)"
    }

    /// Optional closure for handling direction taps (nil if no connection).
    private var directionTapHandler: ((String) -> Void)? {
        guard connection != nil else { return nil }
        return handleDirectionTap
    }
}
