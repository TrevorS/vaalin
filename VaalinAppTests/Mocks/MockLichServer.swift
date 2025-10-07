// ABOUTME: MockLichServer - In-process TCP server simulating Lich's XML protocol for integration testing

import Foundation
import Network
import os

/// Actor-based mock server that simulates Lich's detachable client XML protocol.
///
/// Designed for automated integration testing without requiring a real Lich/GemStone IV server.
/// Listens on a random available port to avoid conflicts in parallel test execution.
///
/// ## Usage
///
/// ```swift
/// let server = MockLichServer()
/// try await server.start()
///
/// // Get the assigned port
/// let port = await server.port
///
/// // Connect your client to localhost:port
/// let connection = LichConnection()
/// try await connection.connect(host: "127.0.0.1", port: port)
///
/// // Send test scenarios
/// await server.sendScenario(.initialConnection)
/// await server.sendScenario(.roomDescription)
///
/// // Clean shutdown
/// await server.stop()
/// ```
///
/// ## Thread Safety
/// All operations are actor-isolated for safe concurrent test execution.
///
/// ## Performance
/// Supports multiple concurrent client connections for testing reconnection logic.
public actor MockLichServer { // swiftlint:disable:this actor_naming
    // MARK: - Constants

    /// Logger for server events and debugging
    private let logger = Logger(subsystem: "com.vaalin.test", category: "MockLichServer")

    // MARK: - State

    /// The underlying NWListener for accepting connections
    private var listener: NWListener?

    /// Assigned port number (0 until server starts)
    private(set) var port: UInt16 = 0

    /// Active client connections
    private var connections: [NWConnection] = []

    /// Whether the server is currently running
    private var isRunning = false

    /// DispatchQueue for NWListener callbacks
    private let queue = DispatchQueue(label: "com.vaalin.mocklichserver", qos: .userInitiated)

    // MARK: - Initialization

    /// Creates a new MockLichServer
    public init() {
        logger.info("MockLichServer initialized")
    }

    // MARK: - Server Lifecycle

    /// Start the server on a random available port
    ///
    /// Binds to localhost with a random port assignment. The assigned port is stored
    /// in the `port` property for clients to connect to.
    ///
    /// - Throws: MockLichServerError if server fails to start
    public func start() async throws {
        guard !isRunning else {
            logger.warning("Server already running on port \(self.port)")
            return
        }

        logger.info("Starting MockLichServer...")

        // Create listener with random port (port 0 = auto-assign)
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = true // Security: only accept localhost connections

        // Use port 0 for automatic port assignment
        guard let listener = try? NWListener(using: parameters, on: 0) else {
            throw MockLichServerError.failedToStart
        }

        self.listener = listener

        // Set up new connection handler
        listener.newConnectionHandler = { [weak self] newConnection in
            Task {
                await self?.handleNewConnection(newConnection)
            }
        }

        // Set up state change handler to capture assigned port
        listener.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleListenerStateChange(state)
            }
        }

        // Start listening
        listener.start(queue: queue)

        // Wait for listener to be ready and port to be assigned
        try await waitForReady()

        isRunning = true
        logger.info("MockLichServer started on port \(self.port)")
    }

    /// Stop the server and close all connections
    ///
    /// Performs clean shutdown: closes all client connections, then cancels the listener.
    public func stop() async {
        guard isRunning else {
            logger.debug("Server already stopped")
            return
        }

        logger.info("Stopping MockLichServer...")

        // Close all client connections
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()

        // Cancel listener
        listener?.cancel()
        listener = nil

        isRunning = false
        port = 0

        logger.info("MockLichServer stopped")
    }

    // MARK: - XML Broadcasting

    /// Send raw XML to all connected clients
    ///
    /// Broadcasts the XML string to every active connection. Use this for custom
    /// test scenarios or to send specific XML patterns.
    ///
    /// - Parameter xml: XML string to send (should be valid GemStone IV protocol XML)
    public func sendXML(_ xml: String) async {
        guard isRunning else {
            logger.warning("Cannot send XML: server not running")
            return
        }

        guard let data = xml.data(using: .utf8) else {
            logger.error("Failed to encode XML as UTF-8")
            return
        }

        logger.debug("Broadcasting \(data.count) bytes to \(self.connections.count) clients")

        for connection in connections {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    self.logger.error("Send error: \(error.localizedDescription)")
                }
            })
        }
    }

    /// Send a predefined game scenario to all connected clients
    ///
    /// Convenience method for sending realistic GemStone IV XML sequences.
    ///
    /// - Parameter scenario: The scenario to send
    public func sendScenario(_ scenario: Scenario) async {
        await sendXML(scenario.xml)
    }

    // MARK: - Connection Management

    /// Current number of active connections (for test assertions)
    public var connectionCount: Int {
        connections.count
    }

    // MARK: - Private Implementation

    /// Handle new incoming client connection
    private func handleNewConnection(_ newConnection: NWConnection) {
        logger.info("New client connection from \(String(describing: newConnection.endpoint))")

        // Add to active connections
        connections.append(newConnection)

        // Set up state change handler
        newConnection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionStateChange(newConnection, state: state)
            }
        }

        // Start the connection
        newConnection.start(queue: queue)
    }

    /// Handle connection state changes
    private func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
            logger.debug("Client connection ready")

        case .failed(let error):
            logger.warning("Client connection failed: \(error.localizedDescription)")
            removeConnection(connection)

        case .cancelled:
            logger.debug("Client connection cancelled")
            removeConnection(connection)

        default:
            break
        }
    }

    /// Remove a connection from the active list
    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        logger.debug("\(self.connections.count) connections remaining")
    }

    /// Handle listener state changes
    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            // Capture the assigned port
            if let port = listener?.port {
                self.port = port.rawValue
                logger.info("Listener ready on port \(port.rawValue)")
            }

        case .failed(let error):
            logger.error("Listener failed: \(error.localizedDescription)")

        case .cancelled:
            logger.debug("Listener cancelled")

        default:
            break
        }
    }

    /// Wait for listener to reach ready state
    private func waitForReady() async throws {
        // Poll listener state until ready or failed
        for _ in 0..<50 { // 5 second timeout (50 * 0.1s)
            if port != 0 {
                return // Port assigned, listener is ready
            }

            if let state = listener?.state, case .failed = state {
                throw MockLichServerError.failedToStart
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        throw MockLichServerError.failedToStart
    }
}

// MARK: - Scenarios

/// Predefined GemStone IV XML scenarios for testing
public extension MockLichServer {
    /// Common game scenarios for integration testing
    enum Scenario {
        /// Initial connection handshake with game mode and settings
        case initialConnection

        /// Room description with exits and objects
        case roomDescription

        /// Combat spam with damage and vitals updates
        case combatSequence

        /// Stream changes (thoughts, speech, etc.)
        case streamSequence

        /// Item tags with exist/noun attributes for highlighting
        case itemLoot

        /// Hands update (left/right equipment)
        case handsUpdate

        /// Vitals update (health, mana, stamina, spirit)
        case vitalsUpdate

        /// Prompt sequence (game ready for input)
        case promptSequence

        /// Mixed content with nested tags and attributes
        case complexNested

        /// Returns the XML string for this scenario
        var xml: String {
            switch self {
            case .initialConnection:
                return Self.initialConnectionXML

            case .roomDescription:
                return Self.roomDescriptionXML

            case .combatSequence:
                return Self.combatSequenceXML

            case .streamSequence:
                return Self.streamSequenceXML

            case .itemLoot:
                return Self.itemLootXML

            case .handsUpdate:
                return Self.handsUpdateXML

            case .vitalsUpdate:
                return Self.vitalsUpdateXML

            case .promptSequence:
                return Self.promptSequenceXML

            case .complexNested:
                return Self.complexNestedXML
            }
        }
    }
}

// MARK: - Scenario XML Templates

private extension MockLichServer.Scenario {
    /// Initial connection XML (game mode, settings, stream windows)
    static let initialConnectionXML = """
    <mode id="GAME"/>
    <settingsInfo width="100" height="40" crc="123456789"/>
    <streamWindow id="main" title="Story" subtitle="" location="center" target="drop"/>
    <streamWindow id="room" title="Room" location="center" target="drop"/>
    <streamWindow id="inv" title="Inventory" location="left"/>
    <streamWindow id="logons" title="Logons" location="right"/>
    <streamWindow id="death" title="Death" location="right"/>
    <streamWindow id="thoughts" title="Thoughts" location="right"/>
    <streamWindow id="assess" title="Assess" location="right"/>
    <streamWindow id="speech" title="Speech" location="right"/>
    <component id="room"/>
    <component id="room desc"/>
    <component id="room objs"/>
    <component id="room players"/>
    <component id="room exits"/>
    <clearContainer id="inv"/>
    <clearContainer id="stow"/>
    <clearContainer id="room"/>
    <prompt time="1696550000">&gt;</prompt>
    """

    /// Room description XML with pushStream/popStream
    static let roomDescriptionXML = """
    <pushStream id="room"/>
    [Wehnimer's Landing, Town Square]
    The tree-lined streets of Wehnimer's Landing converge at this central point. \
    Several benches and flower beds border the cobblestone area, providing a pleasant \
    place to rest.  You also see a wooden barrel and a large purple wooden disk.
    Obvious exits: north, east, south, west
    <popStream/>
    <compass><dir value="n"/><dir value="e"/><dir value="s"/><dir value="w"/></compass>
    <nav/>
    <prompt time="1696550001">&gt;</prompt>
    """

    /// Combat sequence with damage and vitals
    static let combatSequenceXML = """
    <pushStream id="combat"/>
    You swing a steel broadsword at a kobold!
      AS: +250 vs DS: +180 with AvD: +32 + d100 roll: +75 = +177
      ... and hit for 45 points of damage!
      Neck broken.
      The kobold crumples to the ground motionless.
    <popStream/>
    <progressBar id="health" value="95" text="health 95" />
    <progressBar id="stamina" value="82" text="stamina 82" />
    <prompt time="1696550002">&gt;</prompt>
    """

    /// Stream sequence (thoughts, speech)
    static let streamSequenceXML = """
    <pushStream id="thoughts"/>
    You think to yourself, "I need healing and rest."
    <popStream/>
    <pushStream id="speech"/>
    Adventurer says, "Anyone need a group?"
    <popStream/>
    <prompt time="1696550003">&gt;</prompt>
    """

    /// Item loot with exist/noun attributes
    static let itemLootXML = """
    <pushStream id="room"/>
    You see <a exist="12345" noun="gem">a blue gem</a>, \
    <a exist="12346" noun="coin">some silver coins</a>, and \
    <a exist="12347" noun="box">a wooden box</a> here.
    <popStream/>
    <prompt time="1696550004">&gt;</prompt>
    """

    /// Hands update (equipment changes)
    static let handsUpdateXML = """
    <left exist="12350" noun="shield">a steel shield</left>
    <right exist="12351" noun="sword">a steel broadsword</right>
    <prompt time="1696550005">&gt;</prompt>
    """

    /// Vitals update (all progress bars)
    static let vitalsUpdateXML = """
    <progressBar id="health" value="100" text="health 100" />
    <progressBar id="mana" value="87" text="mana 87" />
    <progressBar id="stamina" value="95" text="stamina 95" />
    <progressBar id="spirit" value="10" text="spirit 10" />
    <progressBar id="concentration" value="3" text="concentration 3" />
    <progressBar id="encumbrance" value="25" text="encumbrance 25" />
    <prompt time="1696550006">&gt;</prompt>
    """

    /// Prompt sequence (multiple prompts)
    static let promptSequenceXML = """
    <prompt time="1696550007">&gt;</prompt>
    <prompt time="1696550008">&gt;</prompt>
    <prompt time="1696550009">&gt;</prompt>
    """

    /// Complex nested structure (bold, presets, multiple levels)
    static let complexNestedXML = """
    <pushStream id="main"/>
    <output class="mono"/>
    You carefully examine the <pushBold/>gem<popBold/> and determine that \
    <preset id="whisper">the weight is about 1 pound</preset>.
    <d cmd="look at gem">Looking closer, you see <a exist="99999" noun="gem">\
    <pushBold/>a flawless blue gem<popBold/></a>.</d>
    <popStream/>
    <prompt time="1696550010">&gt;</prompt>
    """
}

// MARK: - Errors

/// Errors that can occur during MockLichServer operations
public enum MockLichServerError: Error, LocalizedError {
    case failedToStart
    case notRunning
    case sendFailed

    public var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start mock server"
        case .notRunning:
            return "Server is not running"
        case .sendFailed:
            return "Failed to send data to clients"
        }
    }
}
