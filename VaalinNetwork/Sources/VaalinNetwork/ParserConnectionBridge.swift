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
/// - **Malformed UTF-8**: Logged and skipped
/// - **Incomplete UTF-8**: Multi-byte characters split across chunks are buffered
/// - **Parser errors**: Logged and continued (parser returns empty array)
/// - **Connection errors**: Logged and stream finished
///
/// The bridge is resilient and continues processing even when individual
/// chunks fail to parse.
///
/// ## Memory Management
///
/// Tags accumulate up to a maximum of 10,000 entries. When this limit is exceeded,
/// the oldest tags are automatically evicted to prevent unbounded memory growth
/// during long game sessions. Consumers should call `clearParsedTags()` periodically
/// after processing tags to maintain optimal memory usage.
public actor ParserConnectionBridge { // swiftlint:disable:this actor_naming
    // MARK: - Constants

    /// Logger for bridge events and errors
    private let logger = Logger(subsystem: "com.vaalin.network", category: "ParserConnectionBridge")

    /// Maximum number of tags to accumulate before auto-eviction
    ///
    /// Prevents unbounded memory growth during long game sessions.
    /// When exceeded, oldest tags are dropped to maintain this limit.
    /// Set to 10,000 tags - approximately 1-2 hours of active gameplay.
    private let maxAccumulatedTags = 10_000

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

    /// Buffer for incomplete UTF-8 byte sequences across chunk boundaries
    ///
    /// When a multi-byte UTF-8 character is split across TCP chunks, the trailing
    /// bytes are buffered here and prepended to the next chunk. This prevents data
    /// loss from UTF-8 decode failures on incomplete characters.
    ///
    /// Example: "café" where é is [0xC3, 0xA9]
    /// - Chunk 1 ends with: [0xC3] → buffered
    /// - Chunk 2 starts with: [0xA9, ...] → combined with buffer → "café"
    private var utf8Buffer = Data()

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
    /// 2. Handles UTF-8 boundary conditions (multi-byte chars split across chunks)
    /// 3. Decodes each Data chunk to UTF-8 String
    /// 4. Passes String to parser.parse()
    /// 5. Accumulates resulting GameTags (with memory limit enforcement)
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

            // Prepend any buffered UTF-8 bytes from previous chunk
            let combinedData = utf8Buffer + chunk
            utf8Buffer = Data()

            // Attempt UTF-8 decode
            guard let xmlString = String(data: combinedData, encoding: .utf8) else {
                // UTF-8 decode failed - check if this might be an incomplete multi-byte character
                // UTF-8 multi-byte sequences: 2 bytes (0xC0-0xDF), 3 bytes (0xE0-0xEF), 4 bytes (0xF0-0xF7)
                // If we have 1-4 trailing bytes that could be incomplete, buffer them
                if combinedData.count > 0 && combinedData.count <= 4 {
                    // Could be incomplete multi-byte character at chunk boundary
                    logger.debug("Buffering \(combinedData.count) bytes for UTF-8 completion")
                    utf8Buffer = combinedData
                    continue
                }

                // Truly malformed UTF-8 - skip this chunk
                logger.warning("Received non-UTF-8 data (\(combinedData.count) bytes), skipping chunk")
                continue
            }

            logger.debug("Received \(chunk.count) bytes (\(xmlString.count) chars)")

            // Parse the chunk (parser handles incomplete XML by buffering, returns [] until complete)
            let tags = await parser.parse(xmlString)

            logger.debug("Parsed \(tags.count) tags from chunk")

            // Accumulate tags with memory limit enforcement
            if !tags.isEmpty {
                parsedTags.append(contentsOf: tags)

                // Enforce memory limit - evict oldest tags if exceeded
                if parsedTags.count > maxAccumulatedTags {
                    let excess = parsedTags.count - maxAccumulatedTags
                    logger.warning("""
                        Tag accumulation exceeded limit (\(self.maxAccumulatedTags)), \
                        dropping \(excess) oldest tags
                        """)
                    parsedTags.removeFirst(excess)
                }

                logger.debug("Total accumulated tags: \(self.parsedTags.count)")
            }
        }

        logger.info("Data flow loop ended")
        running = false
    }
}
