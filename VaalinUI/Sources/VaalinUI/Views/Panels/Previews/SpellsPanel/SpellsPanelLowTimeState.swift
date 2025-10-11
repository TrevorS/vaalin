// ABOUTME: Preview file for SpellsPanel showing low time state with spells about to expire

import SwiftUI
import VaalinCore

/// Preview provider for SpellsPanel in low time state.
///
/// Shows multiple active spells all with low percentages (< 33%) to demonstrate
/// red warning colors for spells about to expire. This preview is useful for
/// testing the visual warning system when spell durations are critically low.
struct SpellsPanelLowTimeStatePreview: PreviewProvider {
    static var previews: some View {
        SpellsPanel(viewModel: createLowTimeViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Low Time State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with multiple spells at critically low durations.
    private static func createLowTimeViewModel() -> SpellsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)

        // Manually set state for preview (bypassing EventBus)
        // All spells have < 33% remaining to show red warning colors
        // Realistic Wizard buffs about to expire (sorted by spell ID)
        viewModel.activeSpells = [
            ActiveSpell(
                id: "401",  // Elemental Defense I (Minor Elemental)
                name: "Elemental Defense I",
                timeRemaining: "3:12",
                percentRemaining: 15
            ),
            ActiveSpell(
                id: "503",  // Thurfel's Ward (Major Elemental)
                name: "Thurfel's Ward",
                timeRemaining: "1:04",
                percentRemaining: 8
            ),
            ActiveSpell(
                id: "506",  // Celerity (Major Elemental) - short duration spell
                name: "Celerity",
                timeRemaining: "0:18",
                percentRemaining: 5
            ),
            ActiveSpell(
                id: "509",  // Strength (Major Elemental)
                name: "Strength",
                timeRemaining: "4:33",
                percentRemaining: 25
            ),
            ActiveSpell(
                id: "535",  // Haste (Major Elemental)
                name: "Haste",
                timeRemaining: "2:47",
                percentRemaining: 18
            ),
            ActiveSpell(
                id: "911",  // Mass Blur (Wizard Base)
                name: "Mass Blur",
                timeRemaining: "1:55",
                percentRemaining: 12
            )
        ]

        return viewModel
    }
}
