// ABOUTME: Preview file for GameLogView showing empty state (no messages)

import SwiftUI
import VaalinCore

/// Preview provider for GameLogView in empty state.
///
/// Shows the baseline UI with no content:
/// - Empty text view
/// - Opaque Catppuccin Mocha background
/// - No messages (clean slate)
struct GameLogViewEmptyStatePreview: PreviewProvider {
    static var previews: some View {
        GameLogView(viewModel: GameLogViewModel())
            .frame(width: 800, height: 600)
            .previewDisplayName("Empty State")
            .preferredColorScheme(.dark)
    }
}
