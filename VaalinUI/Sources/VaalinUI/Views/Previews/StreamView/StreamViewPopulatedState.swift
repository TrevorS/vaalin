// ABOUTME: Preview state for StreamView with populated stream content

import SwiftUI
import VaalinCore
import VaalinParser

#Preview("Populated State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech"]

    // Create sample messages with different presets
    Task { @MainActor in
        let thoughtTags = [
            GameTag(
                name: "preset",
                text: "You ponder the ancient runes carved into the stone wall.",
                attrs: ["id": "thought"],
                state: .closed
            )
        ]

        let speechTags = [
            GameTag(
                name: "preset",
                text: "You say, \"Hello, fellow adventurer!\"",
                attrs: ["id": "speech"],
                state: .closed
            )
        ]

        let damageTags = [
            GameTag(
                name: "preset",
                text: "You take 50 points of damage from the troll's club!",
                attrs: ["id": "damage"],
                state: .closed
            )
        ]

        // Add messages to streams
        await streamBufferManager.addToStream(
            streamID: "thoughts",
            Message(from: thoughtTags, streamID: "thoughts")
        )

        await streamBufferManager.addToStream(
            streamID: "speech",
            Message(from: speechTags, streamID: "speech")
        )

        await streamBufferManager.addToStream(
            streamID: "thoughts",
            Message(from: thoughtTags, streamID: "thoughts")
        )

        await streamBufferManager.addToStream(
            streamID: "speech",
            Message(from: damageTags, streamID: "speech")
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
