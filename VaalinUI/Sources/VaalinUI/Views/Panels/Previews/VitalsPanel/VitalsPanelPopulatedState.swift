// ABOUTME: Preview file for VitalsPanel showing populated state with realistic combat values

import SwiftUI
import VaalinCore

/// Preview provider for VitalsPanel in populated state.
///
/// Shows realistic combat values:
/// - Health: 68/100 (medium/yellow)
/// - Mana: 45/85 (medium)
/// - Stamina: 72/95 (high)
/// - Spirit: 54/100 (medium)
/// - Mind: "clear" (100%)
/// - Stance: "offensive"
/// - Encumbrance: "light"
struct VitalsPanelPopulatedStatePreview: PreviewProvider {
    static var previews: some View {
        VitalsPanel(viewModel: createPopulatedViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Populated State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with populated vitals (normal gameplay).
    private static func createPopulatedViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Manually set state for preview (bypassing EventBus) - realistic combat values
        viewModel.health = 68  // Medium (yellow)
        viewModel.healthText = "68/100"
        viewModel.mana = 53  // Medium
        viewModel.manaText = "45/85"
        viewModel.stamina = 76  // High
        viewModel.staminaText = "72/95"
        viewModel.spirit = 54  // Medium
        viewModel.spiritText = "54/100"
        viewModel.mind = 0  // Clear mind
        viewModel.mindText = "clear"
        viewModel.stance = "offensive"
        viewModel.encumbrance = "light"
        return viewModel
    }
}
