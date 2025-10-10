// ABOUTME: Preview file for InjuriesPanel showing healthy state with no injuries

import SwiftUI
import VaalinCore

/// Preview provider for InjuriesPanel in healthy state.
///
/// Shows all body parts in healthy condition:
/// - All locations: healthy (hollow circles)
/// - No injuries or scars
/// - Default/rested state
struct InjuriesPanelHealthyStatePreview: PreviewProvider {
    static var previews: some View {
        InjuriesPanel(viewModel: createHealthyViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Healthy State (No Injuries)")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with all body parts healthy.
    private static func createHealthyViewModel() -> InjuriesPanelViewModel {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        // All body parts are healthy (default state - empty dictionary)
        // viewModel.injuries remains empty, rendering hollow circles
        return viewModel
    }
}
