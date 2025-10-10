// ABOUTME: Preview file for CompassPanel showing empty state with no room or exits

import SwiftUI
import VaalinCore

/// Preview for CompassPanel in empty state.
///
/// Shows initial state with no room information or exits:
/// - Room name: "Unknown Room"
/// - Room ID: 0
/// - Exits: Empty set
#Preview("Empty State") {
    CompassPanel(viewModel: createEmptyViewModel())
        .frame(width: 300)
        .padding()
        .preferredColorScheme(.dark)
}

/// Creates view model with no room or exits.
@MainActor
private func createEmptyViewModel() -> CompassPanelViewModel {
    let eventBus = EventBus()
    let viewModel = CompassPanelViewModel(eventBus: eventBus)
    // Default state: roomName = "", roomId = 0, exits = []
    return viewModel
}
