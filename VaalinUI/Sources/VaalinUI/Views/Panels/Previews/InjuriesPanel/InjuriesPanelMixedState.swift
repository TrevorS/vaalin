// ABOUTME: Preview file for InjuriesPanel showing mixed injuries and scars

import SwiftUI
import VaalinCore

/// Preview provider for InjuriesPanel in mixed state.
///
/// Shows realistic combat aftermath:
/// - Head: Injury severity 3 (red, 3 dots)
/// - Neck: Healthy
/// - Chest: Scar severity 1 (yellow, dimmed)
/// - Left Arm: Injury severity 2 (orange, 2 dots)
/// - Abdomen: Injury severity 1 (yellow, 1 dot)
/// - Right Arm: Healthy
/// - Left Hand: Healthy
/// - Back: Scar severity 2 (orange, dimmed)
/// - Right Hand: Injury severity 1 (yellow, 1 dot)
/// - Left Leg: Injury severity 2 (orange, 2 dots)
/// - Right Leg: Healthy
struct InjuriesPanelMixedStatePreview: PreviewProvider {
    static var previews: some View {
        InjuriesPanel(viewModel: createMixedViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Mixed State (Injuries + Scars)")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with mixed injuries and scars.
    private static func createMixedViewModel() -> InjuriesPanelViewModel {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)

        // Manually set injuries for preview (bypassing EventBus)
        viewModel.injuries = [
            .head: InjuryStatus(injuryType: .injury, severity: 3),       // Critical head wound
            .chest: InjuryStatus(injuryType: .scar, severity: 1),        // Old chest scar
            .leftArm: InjuryStatus(injuryType: .injury, severity: 2),    // Moderate left arm wound
            .abdomen: InjuryStatus(injuryType: .injury, severity: 1),    // Minor abdomen wound
            .back: InjuryStatus(injuryType: .scar, severity: 2),         // Old back scar
            .rightHand: InjuryStatus(injuryType: .injury, severity: 1),  // Minor hand wound
            .leftLeg: InjuryStatus(injuryType: .injury, severity: 2)     // Moderate leg wound
        ]

        return viewModel
    }
}
