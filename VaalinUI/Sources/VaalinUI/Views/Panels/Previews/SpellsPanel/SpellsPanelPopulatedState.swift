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
        // Realistic Wizard buff spells (sorted by spell ID)
        viewModel.activeSpells = [
            ActiveSpell(
                id: "401",  // Elemental Defense I (Minor Elemental)
                name: "Elemental Defense I",
                timeRemaining: "48:15",
                percentRemaining: 92
            ),
            ActiveSpell(
                id: "506",  // Celerity (Major Elemental)
                name: "Celerity",
                timeRemaining: "0:58",
                percentRemaining: 30
            ),
            ActiveSpell(
                id: "509",  // Strength (Major Elemental)
                name: "Strength",
                timeRemaining: "28:44",
                percentRemaining: 68
            ),
            ActiveSpell(
                id: "535",  // Haste (Major Elemental)
                name: "Haste",
                timeRemaining: "11:22",
                percentRemaining: 55
            ),
            ActiveSpell(
                id: "913",  // Melgorehn's Aura (Wizard Base)
                name: "Melgorehn's Aura",
                timeRemaining: "22:05",
                percentRemaining: 75
            )
        ]

        return viewModel
    }
}
