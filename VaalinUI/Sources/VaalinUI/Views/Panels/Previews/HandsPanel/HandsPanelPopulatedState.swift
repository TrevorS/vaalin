// ABOUTME: Preview file for HandsPanel showing populated state with weapons and spell

import SwiftUI
import VaalinCore

/// Preview provider for HandsPanel in populated state.
///
/// Shows populated hands and prepared spell:
/// - Left hand: "steel broadsword"
/// - Right hand: "wooden shield"
/// - Prepared spell: "Minor Shock"
struct HandsPanelPopulatedStatePreview: PreviewProvider {
    static var previews: some View {
        HandsPanel(viewModel: createPopulatedViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Populated State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with populated hands and spell.
    private static func createPopulatedViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Manually set state for preview (bypassing EventBus)
        viewModel.leftHand = "steel broadsword"
        viewModel.rightHand = "wooden shield"
        viewModel.preparedSpell = "Minor Shock"
        return viewModel
    }
}
