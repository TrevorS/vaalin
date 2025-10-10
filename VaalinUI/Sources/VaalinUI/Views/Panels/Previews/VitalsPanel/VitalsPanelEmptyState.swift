// ABOUTME: Preview file for VitalsPanel showing empty/indeterminate state with animated shuffle bars

import SwiftUI
import VaalinCore

/// Preview provider for VitalsPanel in empty/indeterminate state.
///
/// Shows all vitals as nil (indeterminate) with animated shuffle bars.
/// Default values: stance="offensive", encumbrance="none"
struct VitalsPanelEmptyStatePreview: PreviewProvider {
    static var previews: some View {
        VitalsPanel(viewModel: createEmptyViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Empty State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with empty/indeterminate vitals.
    private static func createEmptyViewModel() -> VitalsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = VitalsPanelViewModel(eventBus: eventBus)
        // Default state: all vitals nil (indeterminate), stance="offensive", encumbrance="none"
        return viewModel
    }
}
