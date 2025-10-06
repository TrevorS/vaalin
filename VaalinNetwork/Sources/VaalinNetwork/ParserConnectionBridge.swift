// ABOUTME: ParserConnectionBridge integrates LichConnection with XMLStreamParser for end-to-end data flow

import Foundation
import OSLog
import VaalinCore
import VaalinParser

/// Thread-safe actor that bridges LichConnection and XMLStreamParser.
///
/// This actor manages the data flow from TCP connection through XML parsing,
/// providing a clean integration point between network and parsing layers.
///
/// ## Architecture
///
/// ```
/// LichConnection (AsyncStream<Data>)
///        ↓
/// ParserConnectionBridge (decode UTF-8, coordinate)
///        ↓
/// XMLStreamParser (parse XML chunks)
///        ↓
/// [GameTag] (accumulated results)
/// ```
///
/// ## Usage
///
/// ```swift
/// let connection = LichConnection()
/// let parser = XMLStreamParser()
/// let bridge = ParserConnectionBridge(connection: connection, parser: parser)
///
/// // Connect to Lich
/// try await connection.connect(host: "127.0.0.1", port: 8000)
///
/// // Start data flow
/// await bridge.start()
///
/// // Access parsed tags periodically
/// let tags = await bridge.getParsedTags()
/// // Process tags in UI...
///
/// // Clear processed tags
/// await bridge.clearParsedTags()
///
/// // Stop when done
/// await bridge.stop()
/// ```
///
/// ## Thread Safety
///
/// All operations are actor-isolated and thread-safe. Multiple components
/// can safely access parsed tags concurrently.
///
/// ## Error Handling
///
/// - Malformed UTF-8: Logged and skipped
/// - Parser errors: Logged and continued
/// - Connection errors: Logged and stream finished
///
/// The bridge is resilient and continues processing even when individual
/// chunks fail to parse.
public actor ParserConnectionBridge { // swiftlint:disable:this actor_naming
    // MARK: - Constants

    /// Logger for bridge events and errors
    private let logger = Logger(subsystem: "com.vaalin.network", category: "ParserConnectionBridge")

    // MARK: - Dependencies

    /// The TCP connection to Lich
    private let connection: LichConnection

    /// The XML stream parser
    private let parser: XMLStreamParser

    // MARK: - State

    /// Whether the bridge is currently running
    private(set) var running: Bool = false

    /// Accumulated parsed tags from all processed chunks
    private var parsedTags: [GameTag] = []

    /// Task for running the data flow loop
    private var dataFlowTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new bridge between connection and parser
    ///
    /// - Parameters:
    ///   - connection: The LichConnection to read data from
    ///   - parser: The XMLStreamParser to parse chunks with
    public init(connection: LichConnection, parser: XMLStreamParser) {
        self.connection = connection
        self.parser = parser
        logger.info("ParserConnectionBridge initialized")
    }

    // MARK: - Public API

    /// Start the data flow from connection through parser
    ///
    /// Begins iterating the connection's data stream, parsing each chunk,
    /// and accumulating the resulting GameTags. This method is idempotent -
    /// calling it multiple times while already running has no effect.
    ///
    /// The bridge runs until `stop()` is called or the connection stream ends.
    public func start() {
        // Idempotent - don't start multiple tasks
        guard !running else {
            logger.debug("Bridge already running, ignoring start()")
            return
        }

        running = true
        logger.info("Starting bridge data flow")

        // Create task to process data stream
        dataFlowTask = Task { [weak self] in
            await self?.processDataStream()
        }
    }

    /// Stop the data flow and clean up resources
    ///
    /// Cancels the data flow task and sets state to stopped. This method is
    /// idempotent - calling it multiple times has no effect.
    ///
    /// Parsed tags are preserved after stopping and remain accessible via
    /// `getParsedTags()` until `clearParsedTags()` is called.
    public func stop() {
        guard running else {
            logger.debug("Bridge already stopped, ignoring stop()")
            return
        }

        logger.info("Stopping bridge data flow")

        // Cancel data flow task
        dataFlowTask?.cancel()
        dataFlowTask = nil

        running = false
    }

    /// Get all parsed tags accumulated since start or last clear
    ///
    /// Returns a copy of the accumulated tags. The internal buffer is not
    /// modified - call `clearParsedTags()` to clear it.
    ///
    /// - Returns: Array of all GameTags parsed from connection data
    public func getParsedTags() -> [GameTag] {
        return parsedTags
    }

    /// Clear all accumulated parsed tags
    ///
    /// Resets the internal tag buffer to empty. The bridge continues running
    /// and accumulating new tags if it's currently started.
    public func clearParsedTags() {
        logger.debug("Clearing \(self.parsedTags.count) parsed tags")
        parsedTags.removeAll()
    }

    /// Check if the bridge is currently running
    ///
    /// - Returns: True if data flow is active, false otherwise
    public func isRunning() -> Bool {
        return running
    }

    // MARK: - Private Implementation

    /// Process the connection's data stream
    ///
    /// This is the main data flow loop that:
    /// 1. Iterates connection.dataStream
    /// 2. Decodes each Data chunk to UTF-8 String
    /// 3. Passes String to parser.parse()
    /// 4. Accumulates resulting GameTags
    ///
    /// Runs until the stream ends or the task is cancelled.
    private func processDataStream() async {
        logger.info("Data flow loop started")

        // Iterate connection's data stream
        for await chunk in await connection.dataStream {
            // Check for cancellation
            if Task.isCancelled {
                logger.info("Data flow task cancelled")
                break
            }

            // Decode Data to String
            guard let xmlString = String(data: chunk, encoding: .utf8) else {
                logger.warning("Received non-UTF-8 data (\(chunk.count) bytes), skipping chunk")
                continue
            }

            logger.debug("Received \(chunk.count) bytes (\(xmlString.count) chars)")

            // Parse the chunk (parser.parse() doesn't throw, returns empty array on error)
            let tags = await parser.parse(xmlString)

            logger.debug("Parsed \(tags.count) tags from chunk")

            // Accumulate tags
            if !tags.isEmpty {
                parsedTags.append(contentsOf: tags)
                logger.debug("Total accumulated tags: \(self.parsedTags.count)")
            }
        }

        logger.info("Data flow loop ended")
        running = false
    }
}
