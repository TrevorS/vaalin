// ABOUTME: Preview file for CompassPanel showing populated state with room and multiple exits

import SwiftUI
import VaalinCore

/// Preview for CompassPanel in populated state.
///
/// Shows populated room information with multiple exits:
/// - Room name: "[Town Square, Market]"
/// - Room ID: 228
/// - Exits: n, e, s, w (cardinal directions)
#Preview("Populated State") {
    CompassPanel(viewModel: createPopulatedViewModel())
        .frame(width: 300)
        .padding()
        .preferredColorScheme(.dark)
}

/// Creates view model with populated room and exits.
@MainActor
private func createPopulatedViewModel() -> CompassPanelViewModel {
    let eventBus = EventBus()
    let viewModel = CompassPanelViewModel(eventBus: eventBus)
    // Manually set state for preview (bypassing EventBus)
    viewModel.roomName = "[Town Square, Market]"
    viewModel.roomId = 228
    viewModel.exits = ["n", "e", "s", "w"]
    return viewModel
}
