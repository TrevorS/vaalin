// ABOUTME: Preview state for StreamView with multiple active streams (union behavior)

import SwiftUI
import VaalinCore
import VaalinParser

#Preview("Multi-Stream State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech", "whispers"]

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
    .task {
        // Create sample messages across multiple streams
        let thoughtTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "thought"],
            children: [
                GameTag(
                    name: ":text",
                    text: "You consider your next move carefully.",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let speechTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "speech"],
            children: [
                GameTag(
                    name: ":text",
                    text: "Adventurer says, \"The path ahead looks treacherous!\"",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let whisperTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "whisper"],
            children: [
                GameTag(
                    name: ":text",
                    text: "Someone whispers, \"Meet me at the tavern after dark.\"",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        // Add messages with different timestamps to demonstrate chronological merging
        await streamBufferManager.append(
            Message(from: [thoughtTag], streamID: "thoughts"),
            toStream: "thoughts"
        )

        // Simulate slight delay between messages
        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.append(
            Message(from: [speechTag], streamID: "speech"),
            toStream: "speech"
        )

        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.append(
            Message(from: [whisperTag], streamID: "whispers"),
            toStream: "whispers"
        )

        try? await Task.sleep(for: .milliseconds(10))

        await streamBufferManager.append(
            Message(from: [thoughtTag], streamID: "thoughts"),
            toStream: "thoughts"
        )

        // Reload view model after populating data
        await viewModel.loadStreamContent()
    }
}
