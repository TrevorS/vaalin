// ABOUTME: Preview file for GameLogView showing many messages for scrolling performance test

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with many messages.
///
/// Shows scrolling performance with 100 messages:
/// - Tests virtualization
/// - Validates auto-scroll behavior
/// - Performance target: 60fps scrolling
struct GameLogViewManyMessagesPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())

        // Add many messages to test scrolling
        Task { @MainActor in
            for i in 1...100 {
                await viewModel.appendMessage(
                    GameTag(
                        name: ":text",
                        text: """
                        Message \(i): This is a test message to demonstrate scrolling behavior \
                        with many lines of text in the game log.
                        """,
                        state: .closed
                    )
                )
            }
        }

        return GameLogView(viewModel: viewModel)
            .frame(width: 800, height: 600)
            .previewDisplayName("Many Messages - Scrolling")
            .preferredColorScheme(.dark)
    }
}
