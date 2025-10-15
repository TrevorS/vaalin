// ABOUTME: Preview state for StreamView with populated stream content

import SwiftUI
import VaalinCore
import VaalinParser

#Preview("Populated State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech"]

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
        // Create sample messages with different presets
        let thoughtTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "thought"],
                children: [
                    GameTag(
                        name: ":text",
                        text: "You ponder the ancient runes carved into the stone wall.",
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]

        let speechTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "speech"],
                children: [
                    GameTag(
                        name: ":text",
                        text: "You say, \"Hello, fellow adventurer!\"",
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]

        let damageTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "damage"],
                children: [
                    GameTag(
                        name: ":text",
                        text: "You take 50 points of damage from the troll's club!",
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]

        // Add messages to streams
        await streamBufferManager.append(
            Message(from: thoughtTags, streamID: "thoughts"),
            toStream: "thoughts"
        )

        await streamBufferManager.append(
            Message(from: speechTags, streamID: "speech"),
            toStream: "speech"
        )

        await streamBufferManager.append(
            Message(from: thoughtTags, streamID: "thoughts"),
            toStream: "thoughts"
        )

        await streamBufferManager.append(
            Message(from: damageTags, streamID: "speech"),
            toStream: "speech"
        )

        // Reload view model after populating data
        await viewModel.loadStreamContent()
    }
}
