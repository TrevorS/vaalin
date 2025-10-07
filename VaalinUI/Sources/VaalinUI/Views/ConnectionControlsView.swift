// ABOUTME: ConnectionControlsView provides host/port input and connect/disconnect controls

import SwiftUI

/// Simple connection UI for configuring and controlling Lich connection.
///
/// `ConnectionControlsView` provides text fields for host/port configuration and a button
/// to connect/disconnect from the Lich detachable client. It handles connection errors
/// gracefully and provides visual feedback during connection attempts.
///
/// ## Layout
///
/// ```
/// HStack {
///   TextField("Host", text: $host) [disabled when connected]
///   TextField("Port", text: $port) [disabled when connected]
///   Button("Connect" | "Disconnect") [async action]
///   Text(errorMessage) [if error]
/// }
/// ```
///
/// ## State Management
///
/// - Uses @Bindable for two-way binding to AppState properties
/// - Local @State for connection progress and error handling
/// - Disables inputs while connected or connecting
///
/// ## Error Handling
///
/// Connection errors are displayed inline and automatically cleared when:
/// - User initiates a new connection attempt
/// - User successfully connects
/// - User disconnects
///
/// ## Example Usage
///
/// ```swift
/// @State private var appState = AppState()
///
/// ConnectionControlsView(appState: appState)
/// ```
public struct ConnectionControlsView: View {
    // MARK: - Properties

    /// App state for connection management (two-way binding)
    @Bindable public var appState: AppState

    /// Whether a connection attempt is in progress
    @State private var isConnecting: Bool = false

    /// Error message to display (nil when no error)
    @State private var errorMessage: String?

    // MARK: - Initializer

    public init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Host input
            TextField("Host", text: $appState.host)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .disabled(appState.isConnected || isConnecting)
                .accessibilityLabel("Lich host address")
                .accessibilityHint("Enter the hostname or IP address of the Lich server")

            // Port input
            TextField("Port", text: Binding(
                get: { String(appState.port) },
                set: { newValue in
                    // Parse port number, default to 8000 if invalid
                    if let port = UInt16(newValue) {
                        appState.port = port
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 70)
            .disabled(appState.isConnected || isConnecting)
            .accessibilityLabel("Lich port number")
            .accessibilityHint("Enter the port number of the Lich detachable client")

            // Connect/Disconnect button
            if appState.isConnected {
                Button("Disconnect") {
                    Task {
                        await disconnect()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("Disconnect from Lich")
            } else {
                Button(isConnecting ? "Connecting..." : "Connect") {
                    Task {
                        await connect()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
                .accessibilityLabel(isConnecting ? "Connection in progress" : "Connect to Lich")
            }

            // Error message display
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel("Connection error: \(errorMessage)")
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    /// Handle connection attempt with error handling.
    ///
    /// Sets connecting state, clears previous errors, attempts connection,
    /// and displays error message if connection fails.
    private func connect() async {
        isConnecting = true
        errorMessage = nil

        do {
            try await appState.connect()
            // Success - error message remains nil
        } catch {
            // Connection failed - display error to user
            errorMessage = error.localizedDescription
        }

        isConnecting = false
    }

    /// Handle disconnection.
    ///
    /// Clears error message and disconnects from Lich.
    private func disconnect() async {
        errorMessage = nil
        await appState.disconnect()
    }
}

// MARK: - Previews

struct ConnectionControlsView_Previews: PreviewProvider {
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

            // Preview 3: Error state
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
