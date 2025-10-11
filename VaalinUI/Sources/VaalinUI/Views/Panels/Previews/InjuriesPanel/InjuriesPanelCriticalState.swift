// ABOUTME: Preview file for InjuriesPanel showing critical state with severe injuries

import SwiftUI
import VaalinCore

/// Preview provider for InjuriesPanel in critical state.
///
/// Shows heavily injured character:
/// - Head: Injury severity 3 (red, 3 dots)
/// - Neck: Injury severity 2 (orange, 2 dots)
/// - Chest: Injury severity 3 (red, 3 dots)
/// - Left Arm: Injury severity 3 (red, 3 dots)
/// - Abdomen: Injury severity 3 (red, 3 dots)
/// - Right Arm: Injury severity 2 (orange, 2 dots)
/// - Left Hand: Injury severity 2 (orange, 2 dots)
/// - Back: Injury severity 3 (red, 3 dots)
/// - Right Hand: Injury severity 1 (yellow, 1 dot)
/// - Left Leg: Injury severity 3 (red, 3 dots)
/// - Right Leg: Injury severity 2 (orange, 2 dots)
/// - Nerves: Injury severity 3 (red, 3 dots) - Triggers nervous system warning
///
/// This represents near-death combat state with multiple severe wounds
/// and critical nervous system damage. Status area shows wound count
/// and "Nervous system damaged" warning in red.
struct InjuriesPanelCriticalStatePreview: PreviewProvider {
    static var previews: some View {
        InjuriesPanel(viewModel: createCriticalViewModel())
            .frame(width: 300, height: 300)
            .padding()
            .previewDisplayName("Critical State (Near Death)")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with critical injuries across all body parts.
    private static func createCriticalViewModel() -> InjuriesPanelViewModel {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)

        // Heavily injured character - nearly dead
        viewModel.injuries = [
            .head: InjuryStatus(injuryType: .injury, severity: 3),       // Severe head wound
            .neck: InjuryStatus(injuryType: .injury, severity: 2),       // Moderate neck wound
            .chest: InjuryStatus(injuryType: .injury, severity: 3),      // Severe chest wound
            .leftArm: InjuryStatus(injuryType: .injury, severity: 3),    // Severe left arm wound
            .abdomen: InjuryStatus(injuryType: .injury, severity: 3),    // Severe abdomen wound
            .rightArm: InjuryStatus(injuryType: .injury, severity: 2),   // Moderate right arm wound
            .leftHand: InjuryStatus(injuryType: .injury, severity: 2),   // Moderate left hand wound
            .back: InjuryStatus(injuryType: .injury, severity: 3),       // Severe back wound
            .rightHand: InjuryStatus(injuryType: .injury, severity: 1),  // Minor right hand wound
            .leftLeg: InjuryStatus(injuryType: .injury, severity: 3),    // Severe left leg wound
            .rightLeg: InjuryStatus(injuryType: .injury, severity: 2),   // Moderate right leg wound
            .nerves: InjuryStatus(injuryType: .injury, severity: 3)      // Critical nervous damage
        ]

        return viewModel
    }
}
