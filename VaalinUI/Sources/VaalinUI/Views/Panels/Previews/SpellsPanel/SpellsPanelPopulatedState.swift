// ABOUTME: Preview file for SpellsPanel showing populated state with multiple spells at different durations

import SwiftUI
import VaalinCore

/// Preview provider for SpellsPanel in populated state.
///
/// Shows multiple active spells with varying durations and percentages:
/// - High duration (> 66%): Green color
/// - Medium duration (33-66%): Orange color
/// - Low duration (< 33%): Red color
/// - No percentage: Default primary color
struct SpellsPanelPopulatedStatePreview: PreviewProvider {
    static var previews: some View {
        SpellsPanel(viewModel: createPopulatedViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Populated State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with multiple active spells at different durations.
    private static func createPopulatedViewModel() -> SpellsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)

        // Manually set state for preview (bypassing EventBus)
        viewModel.activeSpells = [
            ActiveSpell(
                id: "spell1",
                name: "Spirit Shield",
                timeRemaining: "14:32",
                percentRemaining: 85
            ),
            ActiveSpell(
                id: "spell2",
                name: "Haste",
                timeRemaining: "3:45",
                percentRemaining: 55
            ),
            ActiveSpell(
                id: "spell3",
                name: "Elemental Defense",
                timeRemaining: "45:12",
                percentRemaining: 92
            ),
            ActiveSpell(
                id: "spell4",
                name: "Permanence",
                timeRemaining: nil,
                percentRemaining: nil
            )
        ]

        return viewModel
    }
}
