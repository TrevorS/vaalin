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
        viewModel.activeSpells = [
            ActiveSpell(
                id: "spell1",
                name: "Spirit Shield",
                timeRemaining: "0:45",
                percentRemaining: 12
            ),
            ActiveSpell(
                id: "spell2",
                name: "Haste",
                timeRemaining: "1:23",
                percentRemaining: 28
            ),
            ActiveSpell(
                id: "spell3",
                name: "Minor Sanctuary",
                timeRemaining: "0:18",
                percentRemaining: 5
            ),
            ActiveSpell(
                id: "spell4",
                name: "Elemental Defense",
                timeRemaining: "2:04",
                percentRemaining: 32
            )
        ]

        return viewModel
    }
}
