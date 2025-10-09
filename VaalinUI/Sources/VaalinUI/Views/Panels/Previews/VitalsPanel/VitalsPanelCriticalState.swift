// ABOUTME: Preview file for VitalsPanel showing critical state with heavily damaged character

import SwiftUI
import VaalinCore

/// Preview provider for VitalsPanel in critical state.
///
/// Shows heavily damaged character values:
/// - Health: 18/100 (critical/red)
/// - Mana: 12/85 (low)
/// - Stamina: 25/95 (low)
/// - Spirit: 38/100 (medium)
/// - Mind: "muddled" (60%)
/// - Stance: "defensive"
/// - Encumbrance: "heavy"
struct VitalsPanelCriticalStatePreview: PreviewProvider {
    static var previews: some View {
        VitalsPanel(viewModel: createCriticalViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Critical State (Low Health)")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with critical health (< 33%).
    private static func createCriticalViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Critical combat state - heavily damaged
        viewModel.health = 18  // Critical (red)
        viewModel.healthText = "18/100"
        viewModel.mana = 14  // Low
        viewModel.manaText = "12/85"
        viewModel.stamina = 26  // Low
        viewModel.staminaText = "25/95"
        viewModel.spirit = 38  // Medium
        viewModel.spiritText = "38/100"
        viewModel.mind = 60  // Muddled
        viewModel.mindText = "muddled"
        viewModel.stance = "defensive"
        viewModel.encumbrance = "heavy"
        return viewModel
    }
}
