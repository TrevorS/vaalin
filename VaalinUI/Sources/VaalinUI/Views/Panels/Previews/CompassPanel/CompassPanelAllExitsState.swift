// ABOUTME: Preview file for CompassPanel showing all available exits including special directions

import SwiftUI
import VaalinCore

/// Preview provider for CompassPanel with all exits available.
///
/// Shows comprehensive navigation state with all possible exits:
/// - Room name: "[Adventurer's Guild, Main Hall]"
/// - Room ID: 456
/// - Exits: All 8 cardinal/diagonal + up, down, out
struct CompassPanelAllExitsStatePreview: PreviewProvider {
    static var previews: some View {
        CompassPanel(viewModel: createAllExitsViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("All Exits State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with all exits available.
    private static func createAllExitsViewModel() -> CompassPanelViewModel {
        let eventBus = EventBus()
        let viewModel = CompassPanelViewModel(eventBus: eventBus)
        // Manually set state for preview (bypassing EventBus)
        viewModel.roomName = "[Adventurer's Guild, Main Hall]"
        viewModel.roomId = 456
        viewModel.exits = ["n", "ne", "e", "se", "s", "sw", "w", "nw", "up", "down", "out"]
        return viewModel
    }
}
