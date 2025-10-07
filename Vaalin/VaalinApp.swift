// ABOUTME: Main entry point for Vaalin native macOS SwiftUI MUD client

import SwiftUI
import VaalinUI

/// Vaalin - Native macOS client for GemStone IV via Lich 5 detachable mode
///
/// This is a complete SwiftUI rewrite of the Illthorn client, targeting macOS 26+
/// with Liquid Glass design language and Swift concurrency (async/await, actors).
///
/// ## Architecture (Phase 1 Integration)
///
/// ```
/// VaalinApp
///    └─ WindowGroup
///        └─ MainView
///            ├─ @State appState: AppState (coordinator)
///            ├─ ConnectionControlsView (top bar)
///            └─ GameLogView (main content)
/// ```
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}

/// Main view that integrates connection controls and game log.
///
/// `MainView` creates the root AppState and passes it to child views for coordination.
/// The connection controls sit at the top, with the game log filling the remaining space.
///
/// ## Layout
///
/// ```
/// VStack {
///   ConnectionControlsView [fixed height]
///   GameLogView [fills remaining space]
/// }
/// ```
struct MainView: View {
    /// App coordinator managing connection lifecycle and polling
    @State private var appState = AppState()

    var body: some View {
        VStack(spacing: 0) {
            // Connection controls at top
            ConnectionControlsView(appState: appState)

            // Game log fills remaining space
            GameLogView(
                viewModel: appState.gameLogViewModel,
                isConnected: appState.isConnected
            )
        }
    }
}

// MARK: - Previews

#Preview("Main View") {
    MainView()
        .frame(width: 1200, height: 800)
}
