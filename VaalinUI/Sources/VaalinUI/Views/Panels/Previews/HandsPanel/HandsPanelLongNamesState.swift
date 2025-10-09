// ABOUTME: Preview file for HandsPanel showing long item names to test truncation

import SwiftUI
import VaalinCore

/// Preview provider for HandsPanel with long item names.
///
/// Shows very long item/spell names to test text truncation:
/// - Left hand: "an enruned vultite greatsword with intricate silver filigree"
/// - Right hand: "a steel-reinforced tower shield with gold embossing"
/// - Prepared spell: "Mass Elemental Wave (410)"
struct HandsPanelLongNamesStatePreview: PreviewProvider {
    static var previews: some View {
        HandsPanel(viewModel: createLongNamesViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Long Names (Truncation)")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with long item names to test truncation.
    private static func createLongNamesViewModel() -> HandsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = HandsPanelViewModel(eventBus: eventBus)
        // Long names to test text truncation
        viewModel.leftHand = "an enruned vultite greatsword with intricate silver filigree"
        viewModel.rightHand = "a steel-reinforced tower shield with gold embossing"
        viewModel.preparedSpell = "Mass Elemental Wave (410)"
        return viewModel
    }
}
