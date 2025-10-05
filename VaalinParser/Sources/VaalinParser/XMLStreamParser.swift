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

    /// Stack of tags being constructed across parse operations.
    ///
    /// CRITICAL: This must persist across `parse()` calls because tags can
    /// span multiple TCP chunks. For example:
    /// - Chunk 1: `<a exist="123" noun="gem">blue`
    /// - Chunk 2: ` gem</a>`
    ///
    /// The incomplete `<a>` tag from chunk 1 must remain on the stack
    /// until chunk 2 provides the closing tag. Tags are pushed when opened
    /// and popped when closed. Incomplete tags remain on stack until
    /// subsequent chunks complete them.
    private var tagStack: [GameTag] = []

    /// Buffer for accumulating character data across multiple foundCharacters() callbacks.
    ///
    /// Foundation's XMLParser can split character data into multiple calls.
    /// This buffer accumulates all text for the current tag until didEndElement() is called.
    /// - `didStartElement()` → reset `characterBuffer = ""`
    /// - `foundCharacters()` → append to `characterBuffer`
    /// - `didEndElement()` → assign `characterBuffer` to tag's text, then clear
    private var characterBuffer: String = ""

    /// Buffer for incomplete XML from previous chunk.
    ///
    /// When a chunk ends mid-tag (e.g., `<a exist="123" no`), we cannot
    /// parse it until the next chunk arrives. This buffer stores the incomplete
    /// XML and prepends it to the next chunk.
    ///
    /// Example:
    /// - Chunk 1: `text<a exist=` (incomplete, buffered)
    /// - Chunk 2: `"123">gem</a>` (prepend buffer, parse full tag)
    private var xmlBuffer: String = ""

    // MARK: - Per-Parse State

    /// Completed tags from the current parse operation.
    ///
    /// This is reset at the start of each `parse()` call and returned
    /// as the result. Only fully closed tags are added here.
    private var parsedTags: [GameTag] = []

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
    /// ## Buffering Strategy
    ///
    /// The parser maintains multiple buffers to handle TCP fragmentation:
    /// - `xmlBuffer`: Stores incomplete XML from previous chunk
    /// - `tagStack`: Maintains open tags across chunks
    /// - `characterBuffer`: Accumulates character data split across callbacks
    ///
    /// Incomplete tags at chunk boundaries remain on the stack until
    /// subsequent chunks complete them. Only fully closed tags are returned.
    ///
    /// - Parameter chunk: A string containing XML data (may be incomplete)
    /// - Returns: An array of parsed `GameTag` elements from this chunk
    ///
    /// - Note: Returns empty array in skeleton implementation.
    ///         Actual parsing logic will be added in issues #7-#12.
    ///         Implementation will prepend `xmlBuffer` to chunk and wrap
    ///         in `<root>` tag to satisfy XMLParser requirements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // First chunk: incomplete tag
    /// let tags1 = await parser.parse("<a exist=\"123\" noun=\"gem\">blue")
    /// // Returns [] - tag not complete yet
    ///
    /// // Second chunk: completes the tag
    /// let tags2 = await parser.parse(" gem</a>")
    /// // Returns [GameTag(name: "a", text: "blue gem", ...)]
    /// ```
    public func parse(_ chunk: String) async -> [GameTag] {
        // TODO: Implement parsing logic in issues #7-#12
        // Implementation will:
        // 1. Reset parsedTags = []
        // 2. Prepend xmlBuffer to chunk
        // 3. Wrap in <root> tag for XMLParser
        // 4. Create XMLParser instance and parse
        // 5. Return parsedTags
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
