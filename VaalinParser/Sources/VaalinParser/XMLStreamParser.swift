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
    // MARK: - Constants

    /// Maximum buffer size in characters to prevent unbounded memory growth.
    ///
    /// If buffer exceeds this size, it will be cleared and parsing will fail gracefully.
    /// 10KB should handle even extremely fragmented chunks (typical game output is < 1KB).
    private let maxBufferSize = 10_000

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

    // MARK: - Per-Parse State (Thread-Local)

    /// Temporary storage for current parse operation
    /// These are accessed by XMLParserDelegate callbacks during synchronous parse()
    /// and must be thread-local (not actor-isolated) since XMLParser is synchronous.
    ///
    /// SAFETY: These are only accessed during parse() which is serialized by actor,
    /// so even though they're nonisolated, only one parse() runs at a time.
    nonisolated(unsafe) private var currentTagStack: [GameTag] = []
    nonisolated(unsafe) private var currentCharacterBuffer: String = ""
    nonisolated(unsafe) private var currentParsedTags: [GameTag] = []

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
        // Reset per-parse state (thread-local, safe because actor serializes calls)
        currentTagStack = []
        currentCharacterBuffer = ""
        currentParsedTags = []

        // Handle empty/whitespace input
        if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        // Prepend any buffered XML from previous chunk
        var combinedXML = xmlBuffer + chunk

        // Protect against unbounded buffer growth
        if combinedXML.count > maxBufferSize {
            // Buffer too large - likely malformed XML or attack
            // Clear buffer and process only current chunk
            xmlBuffer = ""
            combinedXML = chunk // Reset to just current chunk
            // Log warning in production: "XML buffer exceeded max size, clearing"
        }

        // Wrap in synthetic root tag for XMLParser (requires single root element)
        // Using unique tag name to avoid conflicts with game XML
        let wrappedXML = "<__synthetic_root__>\(combinedXML)</__synthetic_root__>"

        // Create XMLParser instance
        guard let data = wrappedXML.data(using: .utf8) else {
            return []
        }

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        // Parse synchronously (delegate callbacks happen during this call)
        let success = xmlParser.parse()

        // If parsing failed, buffer the entire chunk for next parse
        if !success {
            xmlBuffer = combinedXML
            return []
        }

        // Clear buffer on successful parse
        xmlBuffer = ""

        // If there's remaining character data at the end and we're at root level,
        // create a final :text node
        if !currentCharacterBuffer.isEmpty && currentTagStack.isEmpty {
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed
            )
            currentParsedTags.append(textNode)
            currentCharacterBuffer = ""
        }

        // Transfer any incomplete tags to persistent stack for next parse
        // NOTE: currentTagStack should always be empty here (successful parse = all tags closed)
        // The synthetic root wrapper ensures XMLParser only succeeds when all tags are properly closed
        #if DEBUG
        assert(currentTagStack.isEmpty, "Bug: Successful parse left tags open on stack")
        #endif
        tagStack = currentTagStack

        // Return completed tags
        return currentParsedTags
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

    /// Called when parser encounters an opening tag
    /// Creates a new GameTag and pushes it onto the stack
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    nonisolated public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Ignore the synthetic root tag
        if elementName == "__synthetic_root__" {
            return
        }

        // Handle accumulated character data before starting new tag
        if !currentCharacterBuffer.isEmpty {
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed
            )

            if currentTagStack.isEmpty {
                // At root level - add text node to parsed tags
                currentParsedTags.append(textNode)
            } else {
                // Inside a parent tag - add text node as child of parent
                var parent = currentTagStack.removeLast()
                parent.children.append(textNode)
                currentTagStack.append(parent)
            }
        }

        // Create new GameTag with .open state
        let tag = GameTag(
            name: elementName,
            text: nil,
            attrs: attributeDict,
            children: [],
            state: .open
        )

        // Push to tag stack (thread-local state)
        currentTagStack.append(tag)

        // Clear character buffer for new tag content
        currentCharacterBuffer = ""
    }

    /// Called when parser encounters character data
    /// Accumulates text for the current tag or creates a text node if no tag is active
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    nonisolated public func parser(_ parser: XMLParser, foundCharacters string: String) {
        // XMLParser can call this multiple times for a single text node
        // Accumulate into buffer (thread-local state)
        currentCharacterBuffer += string
    }

    /// Called when parser encounters a closing tag
    /// Pops tag from stack, assigns text/children, and adds to parsedTags or parent's children
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    nonisolated public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Ignore the synthetic root tag
        if elementName == "__synthetic_root__" {
            return
        }

        // Pop the most recent tag from stack (thread-local state)
        guard var tag = currentTagStack.popLast() else {
            // Unexpected closing tag with no matching open tag
            // This shouldn't happen with well-formed XML, but handle gracefully
            return
        }

        // Verify tag names match (defensive check)
        guard tag.name == elementName else {
            // Tag mismatch - this indicates malformed XML
            // For now, just discard. Issue #12 will handle error recovery.
            return
        }

        // Handle accumulated character data:
        // - If tag has no children, character data becomes the tag's text
        // - If tag has children, character data was already added as :text child nodes
        if tag.children.isEmpty && !currentCharacterBuffer.isEmpty {
            tag.text = currentCharacterBuffer
        } else if !tag.children.isEmpty && !currentCharacterBuffer.isEmpty {
            // Tag has children AND trailing text - add text as final child
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed
            )
            tag.children.append(textNode)
        }
        tag.state = .closed

        // Clear character buffer for next tag
        currentCharacterBuffer = ""

        // CRITICAL NESTING LOGIC:
        // If there's a parent tag on the stack, add this tag as a child of the parent
        // Otherwise, add to the root-level parsed tags
        if currentTagStack.isEmpty {
            // No parent - this is a root-level tag
            currentParsedTags.append(tag)
        } else {
            // Has parent - add as child to the parent tag
            // Parent is at the top of the stack (last element)
            var parent = currentTagStack.removeLast()
            parent.children.append(tag)
            currentTagStack.append(parent) // Put parent back on stack
        }
    }

    /// Called when parser encounters an error
    /// For issue #7, we handle gracefully (detailed recovery in issue #12)
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    nonisolated public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // For now, just let parsing fail
        // Issue #12 will implement proper error recovery
        // The parse() method will buffer the chunk for retry
    }
}
