// ABOUTME: Preview file for SpellsPanel showing empty state with no active spells

import SwiftUI
import VaalinCore

/// Preview provider for SpellsPanel in empty state.
///
/// Shows empty state message "No active spells" with secondary color and italic styling.
struct SpellsPanelEmptyStatePreview: PreviewProvider {
    static var previews: some View {
        SpellsPanel(viewModel: createEmptyViewModel())
            .frame(width: 300)
            .padding()
            .previewDisplayName("Empty State")
            .preferredColorScheme(.dark)
    }

    /// Creates view model with no active spells.
    private static func createEmptyViewModel() -> SpellsPanelViewModel {
        let eventBus = EventBus()
        let viewModel = SpellsPanelViewModel(eventBus: eventBus)
        // Default state is empty (no spells)
        return viewModel
    }
}
