// ABOUTME: MainView implements three-column layout with left/right HUD panels and center game content

import SwiftUI
import VaalinCore

/// Root view implementing the three-column Vaalin layout with translucent Liquid Glass panels.
///
/// `MainView` creates the main application layout with:
/// - **Left column**: HUD panels (hands, vitals by default) - 280pt fixed width
/// - **Center column**: Streams bar + game log + prompt/command input (fills remaining space)
/// - **Right column**: HUD panels (compass, spells by default) - 280pt fixed width
///
/// ## Architecture
///
/// ```
/// MainView
///    ├─ @State appState: AppState (coordinator)
///    └─ HStack (three columns)
///        ├─ Left: VStack of panels from settings.layout.left
///        ├─ Center: VStack {
///        │     StreamsBarView (placeholder)
///        │     GameLogView (fills)
///        │     HStack { PromptView + CommandInputView }
///        │   }
///        └─ Right: VStack of panels from settings.layout.right
/// ```
///
/// ## Panel Configuration
///
/// Panels are rendered based on Settings.layout configuration:
/// - `settings.layout.left`: Array of panel IDs for left column (default: ["hands", "vitals"])
/// - `settings.layout.right`: Array of panel IDs for right column (default: ["compass", "spells"])
/// - `settings.layout.colWidth`: Optional width overrides per panel
/// - `settings.layout.streamsHeight`: Height of streams bar in points
///
/// ## Panel Mapping
///
/// Panel IDs map to SwiftUI views:
/// - `"hands"` → HandsPanel
/// - `"vitals"` → VitalsPanel
/// - `"compass"` → CompassPanel
/// - `"spells"` → SpellsPanel
/// - `"injuries"` → InjuriesPanel
///
/// ## Visual Design
///
/// Follows macOS 26 Liquid Glass design language:
/// - Translucent panel backgrounds (`.regularMaterial`)
/// - Fixed column widths (280pt default)
/// - Center column fills remaining space
/// - 12pt spacing between columns
/// - 12pt spacing between panels within columns
///
/// ## Performance
///
/// - **Layout**: < 1ms for layout calculations (fixed widths, single fill)
/// - **Panel updates**: Only changed panels re-render via @Observable
/// - **Game log**: 60fps scrolling maintained (virtualized ScrollView)
///
/// ## Example Usage
///
/// ```swift
/// @main
/// struct VaalinApp: App {
///     var body: some Scene {
///         WindowGroup {
///             MainView()
///         }
///         .windowResizability(.contentSize)
///         .defaultSize(width: 1200, height: 800)
///     }
/// }
/// ```
///
/// ## Phase 2 Integration
///
/// This layout completes Phase 2 (Issue #46) by integrating:
/// - Connection controls (moved to top bar)
/// - Game log with command echo
/// - Command input with history
/// - HUD panels with EventBus subscriptions
/// - Stream filtering placeholder (full implementation in Phase 4)
public struct MainView: View {
    // MARK: - Properties

    /// App coordinator managing connection lifecycle and polling
    @State private var appState = AppState()

    /// Settings for layout configuration (Phase 3: will be loaded from SettingsManager)
    @State private var settings = Settings.makeDefault()

    /// Default column width in points
    private let defaultColumnWidth: CGFloat = 280

    // MARK: - Initialization

    /// Creates a new MainView with default AppState and Settings.
    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Connection controls at top
            ConnectionControlsView(appState: appState)
                .frame(height: 50)
                .padding(.bottom, 8)

            // Three-column layout
            HStack(alignment: .top, spacing: 12) {
                // Left column: Panels from settings.layout.left
                VStack(alignment: .center, spacing: 12) {
                    ForEach(settings.layout.left, id: \.self) { panelID in
                        panelView(for: panelID)
                    }
                }
                .frame(width: columnWidth(for: "left"), alignment: .top)

                // Center column: GameLog + Prompt/Input
                VStack(spacing: 0) {
                    // Game log fills available space
                    GameLogView(
                        viewModel: appState.gameLogViewModel
                    )

                    // Prompt + Command input at bottom
                    HStack(spacing: 8) {
                        PromptView(viewModel: appState.promptViewModel)
                            .frame(width: 44, height: 44)

                        CommandInputView(viewModel: appState.commandInputViewModel) { _ in
                            // No-op handler - CommandInputViewModel already sends via connection
                            // (Issue #29: connection is injected into viewModel at line 158 of AppState.swift)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)

                // Right column: Panels from settings.layout.right
                VStack(alignment: .center, spacing: 12) {
                    ForEach(settings.layout.right, id: \.self) { panelID in
                        panelView(for: panelID)
                    }
                }
                .frame(width: columnWidth(for: "right"), alignment: .top)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helper Methods

    /// Returns the appropriate panel view for a given panel ID.
    ///
    /// - Parameter id: Panel identifier (e.g., "hands", "vitals", "compass")
    /// - Returns: SwiftUI view for the panel, or EmptyView if ID is unknown
    @ViewBuilder
    private func panelView(for id: String) -> some View {
        switch id {
        case "hands":
            HandsPanel(viewModel: appState.handsPanelViewModel)
        case "vitals":
            VitalsPanel(viewModel: appState.vitalsPanelViewModel)
        case "compass":
            CompassPanel(viewModel: appState.compassPanelViewModel)
        case "spells":
            SpellsPanel(viewModel: appState.spellsPanelViewModel)
        case "injuries":
            InjuriesPanel(viewModel: appState.injuriesPanelViewModel)
        default:
            EmptyView()
        }
    }

    /// Returns the width for a panel column.
    ///
    /// Checks `settings.layout.colWidth` for per-panel overrides, otherwise
    /// returns the default column width (280pt).
    ///
    /// - Parameter column: Column identifier ("left" or "right")
    /// - Returns: Width in points
    private func columnWidth(for column: String) -> CGFloat {
        // Check for per-panel width overrides in settings
        if let override = settings.layout.colWidth[column] {
            return override
        }

        // Default column width
        return defaultColumnWidth
    }
}
