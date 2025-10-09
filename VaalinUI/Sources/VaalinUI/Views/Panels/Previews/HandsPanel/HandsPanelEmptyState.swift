// ABOUTME: Preview file for HandsPanel showing empty state with no items or spell

import SwiftUI
import VaalinCore

/// Preview provider for HandsPanel in empty state.
///
/// Shows empty hands and no prepared spell:
/// - Left hand: "Empty"
/// - Right hand: "Empty"
/// - Prepared spell: "None"
struct HandsPanelEmptyStatePreview: PreviewProvider {
    static var previews: some View {
        HandsPanel(viewModel: createEmptyViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Empty State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with empty hands and no spell.
    private static func createEmptyViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Default state: leftHand = "Empty", rightHand = "Empty", preparedSpell = "None"
        return viewModel
    }
}
