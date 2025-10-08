// ABOUTME: AppState coordinates connection lifecycle, polling bridge, command input, and command history

import Foundation
import Observation
import os
import VaalinCore
import VaalinNetwork

#if canImport(VaalinParser)
import VaalinParser
#endif

/// @Observable @MainActor coordinator that manages connection lifecycle, UI polling, and command input.
///
/// `AppState` acts as the integration layer between actor-based networking components
/// (LichConnection, XMLStreamParser, ParserConnectionBridge) and SwiftUI views. It manages
/// the connection lifecycle, polls the bridge for parsed tags, coordinates command input
/// with command history, and sends commands to the game server.
///
/// ## Architecture
///
/// ```
/// AppState (MainActor)
///    ├─ owns → LichConnection (actor)
///    ├─ owns → XMLStreamParser (actor)
///    ├─ owns → ParserConnectionBridge (actor)
///    ├─ owns → CommandHistory (actor)
///    ├─ owns → GameLogViewModel (@Observable)
///    ├─ owns → CommandInputViewModel (@Observable)
///    ├─ polling → getParsedTags() → appendMessage() [main thread]
///    └─ sendCommand() → connection.send() [game server]
/// ```
///
/// ## Polling Pattern
///
/// The polling loop decouples actor-based components from @Observable view models:
/// - Bridge accumulates GameTags in actor-isolated storage
/// - Polling task fetches tags every 100ms on main thread
/// - Tags are converted to Messages and appended to GameLogViewModel
/// - View automatically updates via @Observable reactivity
///
/// ## Thread Safety
///
/// All access to GameLogViewModel occurs on MainActor, ensuring thread-safe SwiftUI updates.
/// Bridge operations are async calls to actor-isolated methods, maintaining proper isolation.
///
/// ## Performance
///
/// - **Polling interval**: 100ms (10 updates/second)
/// - **Overhead**: < 1ms per poll when no tags (empty array check)
/// - **Tag processing**: < 5ms per 100 tags (typical batch size)
///
/// ## Example Usage
///
/// ```swift
/// @State private var appState = AppState()
///
/// // Connect to Lich
/// try await appState.connect()
///
/// // Bind to GameLogView
/// GameLogView(viewModel: appState.gameLogViewModel, isConnected: appState.isConnected)
///
/// // Bind to CommandInputView
/// CommandInputView(viewModel: appState.commandInputViewModel) { command in
///     await appState.sendCommand(command)
/// }
///
/// // Disconnect when done
/// await appState.disconnect()
/// ```
@Observable
@MainActor
public final class AppState {
    // MARK: - Dependencies

    /// The TCP connection to Lich detachable client
    private let connection: LichConnection

    /// The XML stream parser
    #if canImport(VaalinParser)
    private let parser: XMLStreamParser
    #else
    private let parser: any XMLStreamParsing
    #endif

    /// The bridge that integrates connection and parser
    private let bridge: ParserConnectionBridge

    // MARK: - State

    /// The game log view model (main thread access only)
    public let gameLogViewModel: GameLogViewModel

    /// The command input view model (main thread access only)
    public let commandInputViewModel: CommandInputViewModel

    /// Command history actor for storing and recalling commands
    private let commandHistory: CommandHistory

    /// Whether currently connected to Lich
    public var isConnected: Bool = false

    /// Lich host address (default: localhost for detachable client)
    public var host: String = "127.0.0.1"

    /// Lich port number (default: 8000 for detachable client)
    public var port: UInt16 = 8000

    /// Polling task for fetching parsed tags from bridge
    private var pollingTask: Task<Void, Never>?

    /// Logger for AppState events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "AppState")

    // MARK: - Initialization

    /// Creates a new AppState with all dependencies initialized.
    public init() {
        // Initialize actor-based components
        self.connection = LichConnection()

        #if canImport(VaalinParser)
        self.parser = XMLStreamParser()
        #else
        // For testing without VaalinParser module
        fatalError("VaalinParser module required")
        #endif

        self.bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Initialize command history (500 command buffer)
        self.commandHistory = CommandHistory(maxSize: 500)

        // Initialize view models on main thread
        self.gameLogViewModel = GameLogViewModel()
        self.commandInputViewModel = CommandInputViewModel(commandHistory: commandHistory)
    }

    // MARK: - Connection Lifecycle

    /// Connect to Lich detachable client and start data flow.
    ///
    /// Establishes TCP connection, starts the bridge data flow, and begins polling
    /// for parsed tags. Updates `isConnected` state on success.
    ///
    /// - Throws: LichConnectionError if connection fails
    ///
    /// ## Performance
    /// - **Connection timeout**: 10 seconds
    /// - **First data**: Typically < 100ms after connection
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await appState.connect()
    ///     // Connection successful, UI auto-updates via @Observable
    /// } catch {
    ///     // Show error to user
    ///     print("Connection failed: \(error.localizedDescription)")
    /// }
    /// ```
    public func connect() async throws {
        // Connect to Lich
        try await connection.connect(host: host, port: port, autoReconnect: false)

        // Start bridge data flow
        await bridge.start()

        // Update state
        isConnected = true

        // Start polling for tags
        startPolling()
    }

    /// Disconnect from Lich and stop data flow.
    ///
    /// Stops polling, halts bridge data flow, and closes the TCP connection.
    /// Updates `isConnected` state. This method is safe to call multiple times.
    ///
    /// ## Example
    /// ```swift
    /// await appState.disconnect()
    /// // Connection closed, UI auto-updates via @Observable
    /// ```
    public func disconnect() async {
        // Stop polling first
        stopPolling()

        // Stop bridge data flow
        await bridge.stop()

        // Disconnect from Lich
        await connection.disconnect()

        // Update state
        isConnected = false
    }

    // MARK: - Command Sending

    /// Sends a command to the game server via the Lich connection.
    ///
    /// Commands are sent as UTF-8 encoded strings followed by a newline character.
    /// This method should be called from the command input submit handler.
    ///
    /// - Parameter command: The command string to send (without trailing newline)
    ///
    /// ## Example
    /// ```swift
    /// CommandInputView(viewModel: appState.commandInputViewModel) { command in
    ///     await appState.sendCommand(command)
    /// }
    /// ```
    public func sendCommand(_ command: String) async {
        // Send command via connection (LichConnection handles newline encoding)
        do {
            try await connection.send(command: command)
        } catch {
            logger.error("Failed to send command: \(error.localizedDescription)")
        }
    }

    // MARK: - Polling Implementation

    /// Start polling bridge for parsed tags.
    ///
    /// Creates a task that fetches tags from the bridge every 100ms and appends them
    /// to the game log view model. The task runs until cancelled by `stopPolling()`.
    ///
    /// ## Threading
    /// Polling task runs on MainActor to ensure thread-safe access to GameLogViewModel.
    /// Bridge calls are async actor-isolated methods.
    ///
    /// ## Performance
    /// - **Interval**: 100ms (10 updates/second)
    /// - **Overhead**: < 1ms per empty poll
    /// - **Batch processing**: < 5ms per 100 tags
    private func startPolling() {
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                // Fetch tags from bridge (async actor call)
                let tags = await bridge.getParsedTags()

                // Process tags if any arrived
                if !tags.isEmpty {
                    // Render GameTags to Messages and append to view model
                    for tag in tags {
                        // appendMessage() now renders with TagRenderer + ThemeManager
                        await gameLogViewModel.appendMessage(tag)
                    }

                    // Clear processed tags from bridge
                    await bridge.clearParsedTags()
                }

                // Sleep for 100ms before next poll
                // Using try? to ignore cancellation errors (task cleanup is graceful)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    /// Stop polling for parsed tags.
    ///
    /// Cancels the polling task if running. Safe to call multiple times.
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
