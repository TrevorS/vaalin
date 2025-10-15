// ABOUTME: Preview state for StreamView with multiple active streams (union behavior)

import SwiftUI
import VaalinCore
import VaalinParser
@testable import VaalinUI

#Preview("Multi-Stream State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech", "whispers"]

    // Create sample messages across multiple streams
    Task { @MainActor in
        let thoughtTag = GameTag(
            name: "preset",
            text: "You consider your next move carefully.",
            state: .closed,
            attrs: ["id": "thought"]
        )

        let speechTag = GameTag(
            name: "preset",
            text: "Adventurer says, \"The path ahead looks treacherous!\"",
            state: .closed,
            attrs: ["id": "speech"]
        )

        let whisperTag = GameTag(
            name: "preset",
            text: "Someone whispers, \"Meet me at the tavern after dark.\"",
            state: .closed,
            attrs: ["id": "whisper"]
        )

        // Add messages with different timestamps to demonstrate chronological merging
        await streamBufferManager.addToStream(
            streamID: "thoughts",
            Message(from: [thoughtTag], streamID: "thoughts")
        )

        // Simulate slight delay between messages
        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.addToStream(
            streamID: "speech",
            Message(from: [speechTag], streamID: "speech")
        )

        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.addToStream(
            streamID: "whispers",
            Message(from: [whisperTag], streamID: "whispers")
        )

        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.addToStream(
            streamID: "thoughts",
            Message(from: [thoughtTag], streamID: "thoughts")
        )
    }

    let viewModel = StreamViewModel(
        streamBufferManager: streamBufferManager,
        activeStreamIDs: activeStreamIDs,
        theme: Theme.catppuccinMocha()
    )

    StreamView(
        viewModel: viewModel,
        activeStreamIDs: activeStreamIDs,
        onDismiss: {}
    )
    .frame(width: 800, height: 600)
}
