// ABOUTME: Main entry point for Vaalin native macOS SwiftUI MUD client

import SwiftUI
import VaalinUI

/// Vaalin - Native macOS client for GemStone IV via Lich 5 detachable mode
///
/// This is a complete SwiftUI rewrite of the Illthorn client, targeting macOS 26+
/// with Liquid Glass design language and Swift concurrency (async/await, actors).
///
/// ## Architecture (Phase 2 Integration)
///
/// ```
/// VaalinApp
///    └─ WindowGroup
///        └─ MainView (from VaalinUI)
///            ├─ @State appState: AppState (coordinator)
///            ├─ ConnectionControlsView (top bar)
///            ├─ HStack (three columns)
///            │   ├─ Left: Panels (hands, vitals)
///            │   ├─ Center: Streams + GameLog + Prompt/Input
///            │   └─ Right: Panels (compass, spells)
///            └─ EventBus subscriptions for panels
/// ```
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            DebugWindowCommands()
        }

        Window("Debug Console - Raw XML Stream", id: "vaalin-debug-console") {
            DebugConsoleView()
        }
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.bottomTrailing)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
    }
}

/// Commands for debug window integration
struct DebugWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Divider()

            Button("Show Debug Console") {
                openWindow(id: "vaalin-debug-console")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
