// ABOUTME: Preview file for GameLogView showing connected state with few messages

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with connection messages.
///
/// Shows normal gameplay state with 6 messages:
/// - Connection sequence
/// - Look command
/// - Room description
/// - Exits
struct GameLogViewConnectedFewMessagesPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())

        // Add sample messages (synchronous for preview)
        Task { @MainActor in
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Connecting to GemStone IV...", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Connected successfully!", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "> look", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "[Abandoned Tower, Ruins]", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(
                    name: ":text",
                    text: """
                    Crumbling stone walls surround you. The ceiling has long since collapsed, \
                    leaving only jagged remnants reaching toward the sky. Rubble covers most of the floor, \
                    making passage difficult.
                    """,
                    state: .closed
                )
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Obvious exits: north, south, east", state: .closed)
            )
        }

        return GameLogView(viewModel: viewModel)
            .frame(width: 800, height: 600)
            .previewDisplayName("Connected - Few Messages")
            .preferredColorScheme(.dark)
    }
}
