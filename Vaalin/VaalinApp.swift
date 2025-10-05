// ABOUTME: Main entry point for Vaalin native macOS SwiftUI MUD client

import SwiftUI

/// Vaalin - Native macOS client for GemStone IV via Lich 5 detachable mode
///
/// This is a complete SwiftUI rewrite of the Illthorn client, targeting macOS 26+
/// with Liquid Glass design language and Swift concurrency (async/await, actors).
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}

/// Temporary placeholder view - will be replaced in Phase 1 with proper game UI
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Vaalin")
                .font(.system(size: 48, weight: .bold))
            Text("Native macOS Client for GemStone IV")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Project structure initialized - ready for Phase 1 implementation")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

#Preview {
    ContentView()
}
