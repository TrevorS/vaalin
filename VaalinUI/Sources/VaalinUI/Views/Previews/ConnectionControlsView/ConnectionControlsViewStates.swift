// ABOUTME: Preview file for ConnectionControlsView showing disconnected, connected, and error states

import SwiftUI

/// Preview provider for ConnectionControlsView in all connection states.
///
/// Shows three states to test connection UI:
/// - **Disconnected**: Default state with host/port inputs enabled and "Connect" button
/// - **Connected**: Active connection with inputs disabled and "Disconnect" button
/// - **Error**: Disconnected state (would show error message after failed connection attempt)
///
/// Note: Error message is internal @State in the view, so we can't directly set it in preview.
/// The error state preview shows the disconnected appearance; actual error would appear after
/// a failed connection attempt.
struct ConnectionControlsViewStatesPreview: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Disconnected state
            ConnectionControlsView(appState: disconnectedState())
                .frame(width: 600, height: 60)
                .previewDisplayName("Disconnected")

            // Preview 2: Connected state
            ConnectionControlsView(appState: connectedState())
                .frame(width: 600, height: 60)
                .previewDisplayName("Connected")

            // Preview 3: Error state (shows disconnected appearance)
            ConnectionControlsView(appState: errorState())
                .frame(width: 600, height: 60)
                .previewDisplayName("Connection Error")
        }
    }

    // MARK: - Sample Data

    /// Creates app state in disconnected state.
    @MainActor
    private static func disconnectedState() -> AppState {
        let state = AppState()
        state.isConnected = false
        return state
    }

    /// Creates app state in connected state.
    @MainActor
    private static func connectedState() -> AppState {
        let state = AppState()
        state.isConnected = true
        return state
    }

    /// Creates app state with error message.
    @MainActor
    private static func errorState() -> AppState {
        let state = AppState()
        state.isConnected = false
        // Note: We can't directly set errorMessage since it's @State in the view
        // This preview shows the disconnected state; error would appear after failed connect
        return state
    }
}
