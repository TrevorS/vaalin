// ABOUTME: StreamRegistry actor provides thread-safe stream registration and lookup for stream filtering
// ABOUTME: StreamInfo model contains stream metadata (id, label, defaultOn, color, aliases)
// ABOUTME: StreamConfig is the JSON root structure wrapper for loading stream-config.json

import Foundation
import OSLog

// MARK: - StreamInfo

/// Stream metadata for registration and filtering configuration
///
/// Contains all information needed to display and manage a stream filter:
/// - Unique ID for lookup and settings persistence
/// - Display label for UI
/// - Default enabled/disabled state
/// - Color palette key for themed rendering
/// - Aliases for alternate lookup names
///
/// ## Example
///
/// ```swift
/// let thoughts = StreamInfo(
///     id: "thoughts",
///     label: "Thoughts",
///     defaultOn: true,
///     color: "subtext1",
///     aliases: []
/// )
/// ```
public struct StreamInfo: Codable, Sendable, Equatable {
    /// Unique stream identifier (e.g., "thoughts", "speech", "whispers")
    /// Used for settings persistence and lookup
    public let id: String

    /// Display label shown in stream filter UI
    public let label: String

    /// Default enabled state when user hasn't overridden
    public let defaultOn: Bool

    /// Palette color key for themed rendering (e.g., "green", "teal")
    public let color: String

    /// Alternate names for stream lookup (e.g., ["whisper"] for "whispers")
    public let aliases: [String]

    /// Create a stream info instance
    ///
    /// - Parameters:
    ///   - id: Unique stream identifier
    ///   - label: Display label for UI
    ///   - defaultOn: Default enabled state
    ///   - color: Palette color key
    ///   - aliases: Alternate lookup names
    public init(
        id: String,
        label: String,
        defaultOn: Bool,
        color: String,
        aliases: [String]
    ) {
        self.id = id
        self.label = label
        self.defaultOn = defaultOn
        self.color = color
        self.aliases = aliases
    }
}

// MARK: - StreamConfig

/// Root structure for stream-config.json
///
/// Wraps the array of stream definitions for JSON loading.
///
/// ## JSON Format
///
/// ```json
/// {
///   "streams": [
///     {
///       "id": "thoughts",
///       "label": "Thoughts",
///       "defaultOn": true,
///       "color": "subtext1",
///       "aliases": []
///     }
///   ]
/// }
/// ```
public struct StreamConfig: Codable {
    /// Array of stream definitions
    public let streams: [StreamInfo]

    /// Create a stream configuration
    ///
    /// - Parameter streams: Array of stream definitions
    public init(streams: [StreamInfo]) {
        self.streams = streams
    }
}

// MARK: - StreamRegistry

/// Thread-safe stream registry for stream filtering management
///
/// StreamRegistry provides a central location for streams to be loaded from JSON
/// configuration with metadata (id, label, defaultOn, color, aliases). This enables:
/// - Dynamic stream discovery
/// - Settings-based stream filtering
/// - Alias-based lookup
/// - Default state management
///
/// ## Usage
///
/// ```swift
/// let registry = StreamRegistry.shared
///
/// // Load streams from JSON
/// let data = try Data(contentsOf: streamConfigURL)
/// try await registry.load(from: data)
///
/// // Lookup by ID
/// if let stream = await registry.stream(withID: "thoughts") {
///     print("Stream: \(stream.label)")
/// }
///
/// // Lookup by alias
/// if let stream = await registry.stream(withAlias: "whisper") {
///     print("Found via alias: \(stream.label)")
/// }
///
/// // Get all streams
/// let all = await registry.allStreams()
/// ```
///
/// ## Thread Safety
///
/// StreamRegistry is implemented as an actor, ensuring all operations are thread-safe.
/// Multiple components can safely load, lookup, and query concurrently.
///
/// ## Unknown Streams
///
/// When looking up a stream ID that doesn't exist, the registry logs a warning
/// and returns nil. Unknown streams are **not** created on-the-fly.
public actor StreamRegistry {
    // MARK: - State

    /// Registered streams indexed by ID
    private var streams: [String: StreamInfo] = [:]

    /// Alias to stream ID mapping for O(1) alias lookups
    private var aliasMap: [String: String] = [:]

    /// Logger for debugging unknown stream lookups
    private let logger = Logger(subsystem: "com.vaalin.core", category: "StreamRegistry")

    // MARK: - Shared Instance

    /// Shared singleton instance for app-wide stream registry
    public static let shared = StreamRegistry()

    // MARK: - Initialization

    /// Create a new stream registry
    ///
    /// For most use cases, use the shared singleton instance via `StreamRegistry.shared`.
    /// Creating separate instances is useful for testing.
    public init() {}

    // MARK: - Loading

    /// Load streams from JSON data
    ///
    /// - Parameter data: JSON data in StreamConfig format
    /// - Throws: DecodingError if JSON is malformed or missing required fields
    ///
    /// Replaces all existing streams and aliases with the newly loaded configuration.
    /// This allows for runtime configuration reloading.
    ///
    /// ## Collision Handling
    ///
    /// - **Duplicate IDs**: Last definition wins, previous aliases are removed
    /// - **Duplicate Aliases**: Last definition wins, collision logged as warning
    ///
    /// ## Example
    ///
    /// ```swift
    /// let registry = StreamRegistry.shared
    /// let data = try Data(contentsOf: streamConfigURL)
    /// try await registry.load(from: data)
    /// ```
    public func load(from data: Data) throws {
        let decoder = JSONDecoder()
        let config = try decoder.decode(StreamConfig.self, from: data)

        // Clear existing state (keep capacity for performance on reload)
        streams.removeAll(keepingCapacity: true)
        aliasMap.removeAll(keepingCapacity: true)

        // Register all streams from config
        for stream in config.streams {
            // If this stream ID already exists, remove its old aliases first
            if let existingStream = streams[stream.id] {
                for oldAlias in existingStream.aliases {
                    aliasMap.removeValue(forKey: oldAlias)
                }
            }

            // Register the new stream (overwrites if duplicate ID)
            streams[stream.id] = stream

            // Register all aliases for this stream
            for alias in stream.aliases {
                // Warn if alias already exists (collision)
                if let existingID = aliasMap[alias] {
                    logger.warning(
                        """
                        Alias '\(alias, privacy: .public)' remapped: \
                        '\(existingID, privacy: .public)' -> '\(stream.id, privacy: .public)'
                        """
                    )
                }
                aliasMap[alias] = stream.id
            }
        }
    }

    // MARK: - Lookup

    /// Retrieve a stream by ID
    ///
    /// - Parameter id: Stream ID to look up
    /// - Returns: Stream info if found, nil otherwise
    ///
    /// If the stream ID doesn't exist, logs a warning and returns nil.
    /// Unknown streams are not created on-the-fly.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let stream = await registry.stream(withID: "thoughts") {
    ///     print("Found stream: \(stream.label)")
    /// } else {
    ///     print("Stream not found")
    /// }
    /// ```
    public func stream(withID id: String) -> StreamInfo? {
        let result = streams[id]
        if result == nil {
            logger.warning("Unknown stream ID: \(id, privacy: .public)")
        }
        return result
    }

    /// Retrieve a stream by alias
    ///
    /// - Parameter alias: Stream alias to look up
    /// - Returns: Stream info if alias found, nil otherwise
    ///
    /// Aliases provide alternate lookup names for streams. For example,
    /// "whisper" might be an alias for the "whispers" stream.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let stream = await registry.stream(withAlias: "whisper") {
    ///     print("Found via alias: \(stream.label)")
    /// } else {
    ///     print("Alias not found")
    /// }
    /// ```
    public func stream(withAlias alias: String) -> StreamInfo? {
        guard let id = aliasMap[alias] else {
            return nil
        }
        return streams[id]
    }

    /// Get all registered streams
    ///
    /// - Returns: Array of all stream info instances
    ///
    /// Order is not guaranteed. Sort by ID or other criteria as needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let allStreams = await registry.allStreams()
    /// for stream in allStreams.sorted(by: { $0.id < $1.id }) {
    ///     print("Stream: \(stream.id) - \(stream.label)")
    /// }
    /// ```
    public func allStreams() -> [StreamInfo] {
        return Array(streams.values)
    }
}
