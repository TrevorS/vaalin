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
                        text: """
                        You carefully consider your tactical options, weighing the risks \
                        of a direct assault against the potential for a more subtle approach.
                        """,
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
                        text: "You say, \"The path ahead looks dangerous. We should proceed with caution.\"",
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
                        text: """
                        You swing a vultite longsword at a hill troll!
                          AS: +246 vs DS: +84 with AvD: +42 + d100 roll: +91 = +295
                           ... and hit for 128 points of damage!
                           Massive blow punches a hole through the hill troll's chest!
                        """,
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
