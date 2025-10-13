// ABOUTME: Preview file for GameLogView showing text wrapping with long lines

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView with long lines.
///
/// Shows text wrapping behavior:
/// - Very long lines that exceed view width
/// - Mixed with short lines
/// - Tests monospaced font wrapping
struct GameLogViewLongLinesPreview: PreviewProvider {
    static var previews: some View {
        let viewModel = GameLogViewModel(theme: .catppuccinMocha())

        Task { @MainActor in
            await viewModel.appendMessage(
                GameTag(
                    name: ":text",
                    text: """
                    This is a very long line that should wrap around to the next line when \
                    the text exceeds the width of the game log view. This tests the text wrapping \
                    behavior of NSTextView with monospaced fonts.
                    """,
                    state: .closed
                )
            )
            await viewModel.appendMessage(
                GameTag(name: ":text", text: "Short line.", state: .closed)
            )
            await viewModel.appendMessage(
                GameTag(
                    name: ":text",
                    text: """
                    Another extremely long line with lots of text that goes on and on and on \
                    to demonstrate how the game log handles very long lines of text that need to \
                    wrap around multiple times. This simulates game descriptions or verbose output.
                    """,
                    state: .closed
                )
            )
        }

        return GameLogView(viewModel: viewModel)
            .frame(width: 800, height: 600)
            .previewDisplayName("Long Lines - Wrapping")
            .preferredColorScheme(.dark)
    }
}
