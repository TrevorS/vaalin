// ABOUTME: LichConnection actor - TCP connection to Lich detachable client using NWConnection

import Foundation
import Network
import os

/// Thread-safe actor that manages TCP connection to Lich's detachable client port
///
/// This actor uses Network.framework's NWConnection for modern async networking.
/// It handles connection lifecycle, data streaming, and automatic reconnection.
///
/// ## Usage
///
/// ```swift
/// let connection = LichConnection()
///
/// // Connect to Lich
/// try await connection.connect(host: "127.0.0.1", port: 8000)
///
/// // Send commands
/// try await connection.send(command: "look")
///
/// // Stream incoming data
/// for await chunk in connection.dataStream {
///     // Process XML chunk
/// }
///
/// // Disconnect
/// await connection.disconnect()
/// ```
///
/// ## Reconnection
///
/// Implements exponential backoff on connection failures:
/// - 1st retry: 0.5s
/// - 2nd retry: 1s
/// - 3rd retry: 2s
/// - 4th retry: 4s
/// - 5th+ retry: 8s (max)
public actor LichConnection {
    // MARK: - Constants

    /// Maximum reconnection delay (8 seconds)
    private let maxReconnectDelay: TimeInterval = 8.0

    /// Initial reconnection delay (0.5 seconds)
    private let initialReconnectDelay: TimeInterval = 0.5

    /// Logger for connection events and errors
    private let logger = Logger(subsystem: "com.vaalin.network", category: "LichConnection")

    // MARK: - State

    /// Current connection state
    private(set) var state: ConnectionState = .disconnected

    /// The underlying NWConnection
    private var connection: NWConnection?

    /// Current reconnection attempt count
    private var reconnectAttempts: Int = 0

    /// Whether automatic reconnection is enabled
    private var shouldReconnect: Bool = false

    /// Connection parameters (host, port) for reconnection
    private var connectionHost: String?
    private var connectionPort: UInt16?

    /// Continuation for data streaming
    private var dataContinuation: AsyncStream<Data>.Continuation?

    // MARK: - Initialization

    /// Creates a new LichConnection actor
    public init() {
        logger.info("LichConnection initialized")
    }

    // MARK: - Public API

    /// Connect to Lich detachable client
    ///
    /// - Parameters:
    ///   - host: Hostname or IP address (typically "127.0.0.1")
    ///   - port: Port number (typically 8000)
    ///   - autoReconnect: Whether to automatically reconnect on failure (default: false)
    /// - Throws: LichConnectionError if connection fails
    public func connect(host: String, port: UInt16, autoReconnect: Bool = false) async throws {
        logger.info("Attempting connection to \(host):\(port)")

        // Store connection parameters for reconnection
        connectionHost = host
        connectionPort = port
        shouldReconnect = autoReconnect

        // Update state
        state = .connecting

        // Create NWConnection
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )

        let parameters = NWParameters.tcp
        let nwConnection = NWConnection(to: endpoint, using: parameters)

        connection = nwConnection

        // Set up state change handler
        nwConnection.stateUpdateHandler = { [weak self] newState in
            Task {
                await self?.handleStateChange(newState)
            }
        }

        // Start connection
        nwConnection.start(queue: .global())

        // Wait for connection to be ready or fail
        try await waitForConnection()

        logger.info("Connected to \(host):\(port)")
    }

    /// Disconnect from Lich
    ///
    /// Cleanly closes the connection and resets state
    public func disconnect() {
        logger.info("Disconnecting from Lich")

        // Disable auto-reconnect
        shouldReconnect = false

        // Cancel connection
        connection?.cancel()
        connection = nil

        // Update state
        state = .disconnected

        // Complete data stream
        dataContinuation?.finish()
        dataContinuation = nil

        logger.info("Disconnected")
    }

    /// Send a command to Lich
    ///
    /// - Parameter command: Command string to send (e.g., "look")
    /// - Throws: LichConnectionError if not connected or send fails
    public func send(command: String) async throws {
        // Validate command first (input validation before state checks)
        guard !command.isEmpty else {
            throw LichConnectionError.invalidCommand
        }

        guard state == .connected else {
            throw LichConnectionError.notConnected
        }

        guard let connection = connection else {
            throw LichConnectionError.notConnected
        }

        // Append newline to command (Lich protocol expects \n terminated commands)
        let commandData = (command + "\n").data(using: .utf8)!

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: commandData,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: LichConnectionError.sendFailed)
                        self.logger.error("Failed to send command: \(error.localizedDescription)")
                    } else {
                        continuation.resume()
                        self.logger.debug("Sent command: \(command)")
                    }
                }
            )
        }
    }

    /// Stream of incoming data from Lich
    ///
    /// Use this to receive XML chunks from the server
    ///
    /// ## Example
    ///
    /// ```swift
    /// for await data in connection.dataStream {
    ///     let xml = String(data: data, encoding: .utf8) ?? ""
    ///     let tags = await parser.parse(xml)
    ///     // Process tags...
    /// }
    /// ```
    public var dataStream: AsyncStream<Data> {
        AsyncStream { continuation in
            dataContinuation = continuation
            startReceiving()
        }
    }

    // MARK: - Private Implementation

    /// Handle NWConnection state changes
    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            state = .connected
            reconnectAttempts = 0 // Reset on successful connection
            logger.info("Connection ready")

        case .waiting(let error):
            state = .failed(error)
            logger.error("Connection waiting: \(error.localizedDescription)")
            attemptReconnect()

        case .failed(let error):
            state = .failed(error)
            logger.error("Connection failed: \(error.localizedDescription)")
            attemptReconnect()

        case .cancelled:
            state = .disconnected
            logger.info("Connection cancelled")

        case .preparing:
            state = .connecting
            logger.debug("Connection preparing")

        case .setup:
            state = .connecting
            logger.debug("Connection setup")

        @unknown default:
            logger.warning("Unknown connection state")
        }
    }

    /// Wait for connection to reach ready or failed state
    private func waitForConnection() async throws {
        // Poll state until connected or failed
        for _ in 0..<100 { // 10 second timeout (100 * 0.1s)
            switch state {
            case .connected:
                return
            case .failed:
                throw LichConnectionError.connectionFailed
            default:
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        throw LichConnectionError.connectionFailed
    }

    /// Attempt to reconnect with exponential backoff
    private func attemptReconnect() {
        guard shouldReconnect else {
            logger.debug("Auto-reconnect disabled, not reconnecting")
            return
        }

        guard let host = connectionHost, let port = connectionPort else {
            logger.error("Cannot reconnect: missing connection parameters")
            return
        }

        reconnectAttempts += 1

        // Calculate backoff delay
        let delay = min(
            initialReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)),
            maxReconnectDelay
        )

        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts))")

        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await connect(host: host, port: port, autoReconnect: true)
        }
    }

    /// Start receiving data from connection
    private func startReceiving() {
        guard let connection = connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task {
                await self?.handleReceive(data: data, isComplete: isComplete, error: error)
            }
        }
    }

    /// Handle received data
    private func handleReceive(data: Data?, isComplete: Bool, error: NWError?) {
        if let error = error {
            logger.error("Receive error: \(error.localizedDescription)")
            dataContinuation?.finish()
            return
        }

        if let data = data, !data.isEmpty {
            logger.debug("Received \(data.count) bytes")
            dataContinuation?.yield(data)
        }

        if isComplete {
            logger.info("Receive complete")
            dataContinuation?.finish()
        } else {
            // Continue receiving
            startReceiving()
        }
    }
}

/// Errors that can occur during Lich connection operations
public enum LichConnectionError: Error, LocalizedError, Equatable {
    case notConnected
    case connectionFailed
    case invalidCommand
    case sendFailed

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Lich"
        case .connectionFailed:
            return "Failed to connect to Lich"
        case .invalidCommand:
            return "Invalid command (empty or malformed)"
        case .sendFailed:
            return "Failed to send command to Lich"
        }
    }
}
