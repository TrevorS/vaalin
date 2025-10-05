// ABOUTME: XMLStreamParser provides stateful SAX-based XML parsing for GemStone IV game output chunks

import Foundation
import VaalinCore

/// Thread-safe actor that parses XML chunks from the GemStone IV game server.
///
/// This parser handles incomplete XML fragments received over TCP connections,
/// maintaining state across multiple `parse()` calls. It uses Foundation's
/// XMLParser (SAX-based) for memory-efficient streaming parsing.
///
/// ## Critical State Management
///
/// The parser maintains persistent state between chunks because:
/// - XML arrives in incomplete fragments over the network
/// - Stream control tags (`<pushStream>`, `<popStream>`) can span multiple chunks
/// - Tag nesting must be tracked across chunk boundaries
///
/// ## Performance Target
///
/// > 10,000 lines/minute throughput with < 500MB memory usage
///
/// ## Usage
///
/// ```swift
/// let parser = XMLStreamParser()
///
/// // Parse first chunk
/// let tags1 = await parser.parse("<pushStream id=\"thoughts\">You think")
///
/// // Parse second chunk - state persists
/// let tags2 = await parser.parse(" about magic.</popStream>")
/// ```
public actor XMLStreamParser: NSObject, XMLParserDelegate { // swiftlint:disable:this actor_naming
    // MARK: - Persistent State

    /// The currently active stream ID from the most recent `<pushStream>` tag.
    ///
    /// This value persists across `parse()` calls and is updated by:
    /// - `<pushStream id="X">` sets this to "X"
    /// - `<popStream>` clears this to `nil`
    ///
    /// Stream IDs include: thoughts, speech, combat, arrivals, deaths, etc.
    private var currentStream: String?

    /// Whether the parser is currently inside a stream context.
    ///
    /// This flag persists across `parse()` calls and is updated by:
    /// - `<pushStream>` sets to `true`
    /// - `<popStream>` sets to `false`
    private var inStream: Bool = false

    // MARK: - Per-Parse State

    /// Stack of tags being constructed during the current parse operation.
    ///
    /// This is reset at the start of each `parse()` call. It tracks the
    /// nesting hierarchy of tags within a single chunk.
    private var tagStack: [GameTag] = []

    // MARK: - Initialization

    /// Creates a new XML stream parser with empty state.
    public override init() {
        super.init()
    }

    // MARK: - Public API

    /// Parses an XML chunk and returns the extracted game tags.
    ///
    /// This method is designed to handle incomplete XML fragments from a TCP stream.
    /// State (stream context, nesting) persists across calls, allowing tags that
    /// span multiple chunks to be parsed correctly.
    ///
    /// - Parameter chunk: A string containing XML data (may be incomplete)
    /// - Returns: An array of parsed `GameTag` elements from this chunk
    ///
    /// - Note: Returns empty array in skeleton implementation.
    ///         Actual parsing logic will be added in issues #7-#12.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // First chunk: incomplete tag
    /// let tags1 = await parser.parse("<pushStream id=\"thoughts\">You")
    ///
    /// // Second chunk: completes the tag
    /// let tags2 = await parser.parse(" think.</popStream>")
    /// ```
    public func parse(_ chunk: String) async -> [GameTag] {
        // TODO: Implement parsing logic in issues #7-#12
        // For now, return empty array to satisfy type system
        return []
    }

    // MARK: - Testing Support

    /// Exposes the current stream state for testing purposes.
    ///
    /// - Returns: The currently active stream ID, or nil if not in a stream
    public func getCurrentStream() async -> String? {
        return currentStream
    }

    /// Exposes the stream context flag for testing purposes.
    ///
    /// - Returns: True if currently inside a stream context
    public func getInStream() async -> Bool {
        return inStream
    }

    // MARK: - XMLParserDelegate

    // Delegate methods will be implemented in subsequent issues (#7-#12)
    // These will handle:
    // - didStartElement: Create GameTag, push to stack, handle stream tags
    // - didEndElement: Pop from stack, associate with currentStream
    // - foundCharacters: Accumulate character data for current tag
    // - parseErrorOccurred: Error recovery for malformed XML
}
