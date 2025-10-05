// ABOUTME: XMLStreamParser provides stateful SAX-based XML parsing for GemStone IV game output chunks

import Foundation
import os
import VaalinCore
import libxml2

// MARK: - C Callbacks

/// User data structure for libxml2 SAX callbacks.
private struct ParserUserData {
    weak var parser: XMLStreamParser?
    var currentStream: String?
    var inStream: Bool = false
    var tagStack: [GameTag] = []
    var characterBuffer: String = ""
    var completedTags: [GameTag] = []
}

/// SAX callback for element start events.
private func startElementNsCallback(
    ctx: UnsafeMutableRawPointer?,
    localname: UnsafePointer<UInt8>?,
    prefix: UnsafePointer<UInt8>?,
    URI: UnsafePointer<UInt8>?,
    nb_namespaces: CInt,
    namespaces: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
    nb_attributes: CInt,
    nb_defaulted: CInt,
    attributes: UnsafeMutablePointer<UnsafePointer<UInt8>?>?
) {
    guard let ctx = ctx,
          let localname = localname else { return }

    let elementName = String(cString: localname)

    // Parse attributes
    var attributeDict: [String: String] = [:]
    if nb_attributes > 0, let attributes = attributes {
        for i in 0..<Int(nb_attributes) {
            let attrIndex = i * 5

            guard let attrName = attributes[attrIndex] else { continue }
            let name = String(cString: attrName)

            guard let valueStart = attributes[attrIndex + 3],
                  let valueEnd = attributes[attrIndex + 4] else {
                continue
            }

            let valueLength = valueEnd - valueStart
            let valueBytes = UnsafeBufferPointer(start: valueStart, count: Int(valueLength))
            let value = String(decoding: valueBytes, as: UTF8.self)

            attributeDict[name] = value
        }
    }

    let userDataPtr = ctx.assumingMemoryBound(to: ParserUserData.self)

    // Ignore synthetic root tag
    if elementName == "__synthetic_root__" {
        return
    }

    // Stream control tags
    if elementName == "pushStream" {
        userDataPtr.pointee.currentStream = attributeDict["id"]
        userDataPtr.pointee.inStream = true
        return
    }

    if elementName == "popStream" || elementName == "clearStream" {
        userDataPtr.pointee.currentStream = nil
        userDataPtr.pointee.inStream = false
        return
    }

    // Handle accumulated character data
    if !userDataPtr.pointee.characterBuffer.isEmpty {
        let textNode = GameTag(
            name: ":text",
            text: userDataPtr.pointee.characterBuffer,
            attrs: [:],
            children: [],
            state: .closed,
            streamId: userDataPtr.pointee.inStream ? userDataPtr.pointee.currentStream : nil
        )

        if userDataPtr.pointee.tagStack.isEmpty {
            userDataPtr.pointee.completedTags.append(textNode)
        } else {
            var parent = userDataPtr.pointee.tagStack.removeLast()
            parent.children.append(textNode)
            userDataPtr.pointee.tagStack.append(parent)
        }

        userDataPtr.pointee.characterBuffer = ""
    }

    // Create new tag
    let tag = GameTag(
        name: elementName,
        text: nil,
        attrs: attributeDict,
        children: [],
        state: .open,
        streamId: userDataPtr.pointee.inStream ? userDataPtr.pointee.currentStream : nil
    )

    userDataPtr.pointee.tagStack.append(tag)
}

/// SAX callback for element end events.
private func endElementNsCallback(
    ctx: UnsafeMutableRawPointer?,
    localname: UnsafePointer<UInt8>?,
    prefix: UnsafePointer<UInt8>?,
    URI: UnsafePointer<UInt8>?
) {
    guard let ctx = ctx,
          let localname = localname else { return }

    let elementName = String(cString: localname)
    let userDataPtr = ctx.assumingMemoryBound(to: ParserUserData.self)

    // Ignore synthetic root tag
    if elementName == "__synthetic_root__" {
        return
    }

    // Stream control tags
    if elementName == "popStream" {
        userDataPtr.pointee.currentStream = nil
        userDataPtr.pointee.inStream = false
        return
    }

    if elementName == "pushStream" || elementName == "clearStream" {
        return
    }

    // Pop tag from stack
    guard var tag = userDataPtr.pointee.tagStack.popLast() else { return }
    guard tag.name == elementName else { return }

    // Handle character data
    if tag.children.isEmpty && !userDataPtr.pointee.characterBuffer.isEmpty {
        tag.text = userDataPtr.pointee.characterBuffer
    } else if !tag.children.isEmpty && !userDataPtr.pointee.characterBuffer.isEmpty {
        let textNode = GameTag(
            name: ":text",
            text: userDataPtr.pointee.characterBuffer,
            attrs: [:],
            children: [],
            state: .closed,
            streamId: userDataPtr.pointee.inStream ? userDataPtr.pointee.currentStream : nil
        )
        tag.children.append(textNode)
    }
    tag.state = .closed

    userDataPtr.pointee.characterBuffer = ""

    // Add to completed tags or parent
    if userDataPtr.pointee.tagStack.isEmpty {
        userDataPtr.pointee.completedTags.append(tag)
    } else {
        var parent = userDataPtr.pointee.tagStack.removeLast()
        parent.children.append(tag)
        userDataPtr.pointee.tagStack.append(parent)
    }
}

/// SAX callback for character data events.
private func charactersCallback_C(
    ctx: UnsafeMutableRawPointer?,
    ch: UnsafePointer<UInt8>?,
    len: CInt
) {
    guard let ctx = ctx,
          let ch = ch else { return }

    let charBuffer = UnsafeBufferPointer(start: ch, count: Int(len))
    let characters = String(decoding: charBuffer, as: UTF8.self)

    let userDataPtr = ctx.assumingMemoryBound(to: ParserUserData.self)
    userDataPtr.pointee.characterBuffer += characters
}

// MARK: - XMLStreamParser Actor

/// Thread-safe actor that parses XML chunks from the GemStone IV game server.
///
/// This parser handles incomplete XML fragments received over TCP connections,
/// maintaining state across multiple `parse()` calls. It uses libxml2's push
/// parser API for native streaming XML support.
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
public actor XMLStreamParser { // swiftlint:disable:this actor_naming
    // MARK: - Constants

    /// Maximum error recovery buffer size (10MB).
    ///
    /// If error buffer exceeds this size during recovery, we force a parser reset
    /// to prevent memory exhaustion. 10MB should handle even massive malformed streams.
    private let maxErrorBufferSize = 10_000_000

    /// Logger for error recovery and diagnostics.
    private let logger = Logger(subsystem: "com.vaalin.parser", category: "XMLStreamParser")

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
    /// SAX parsers can split character data into multiple calls.
    /// This buffer accumulates all text for the current tag until the end element callback.
    private var characterBuffer: String = ""

    /// Completed tags from current parse operation.
    private var completedTags: [GameTag] = []

    // MARK: - Error Recovery State

    /// Whether the parser is currently in error recovery mode.
    ///
    /// When true, the parser buffers incoming chunks in `errorBuffer` and searches
    /// for a `<prompt>` tag to resync. Once resynced, exits recovery mode and resumes
    /// normal parsing from the prompt onward.
    private var inErrorRecovery: Bool = false

    /// Buffer for accumulating chunks during error recovery.
    ///
    /// Chunks are buffered here until we find a `<prompt>` tag to resync.
    /// Limited to `maxErrorBufferSize` (10MB) to prevent memory exhaustion.
    private var errorBuffer: String = ""

    /// The most recent parsing error encountered.
    ///
    /// Stores the error for test verification and debugging. Cleared when
    /// parsing succeeds or parser resyncs successfully.
    private var lastError: Error?

    // MARK: - libxml2 State

    /// The libxml2 push parser context.
    ///
    /// Created once during initialization and reused across parse() calls.
    /// This enables true streaming parsing - libxml2 handles incomplete XML natively.
    ///
    /// SAFETY: Marked nonisolated(unsafe) because it's accessed during init/deinit.
    /// Actual parsing calls are actor-isolated, ensuring thread safety.
    nonisolated(unsafe) private var parserContext: xmlParserCtxtPtr?

    /// SAX handler structure with callback pointers.
    ///
    /// SAFETY: Marked nonisolated(unsafe) because it's accessed during init() before actor isolation.
    /// The handler is only modified during initialization and then used immutably.
    nonisolated(unsafe) private var saxHandler: xmlSAXHandler

    /// User data passed to SAX callbacks.
    ///
    /// This structure is stored as UnsafeMutableRawPointer in libxml2 context
    /// and accessed in callbacks. It maintains a weak reference to this actor
    /// to prevent retain cycles.
    ///
    /// SAFETY: Marked nonisolated(unsafe) because it's accessed during init() before actor isolation.
    /// The pointer is only modified during initialization and deinitialization.
    nonisolated(unsafe) private var userData: UnsafeMutablePointer<ParserUserData>?

    // MARK: - Initialization

    /// Creates a new XML stream parser with libxml2 push parser.
    public init() {
        // Initialize SAX handler with XML_SAX2_MAGIC
        var handler = xmlSAXHandler()
        handler.initialized = UInt32(XML_SAX2_MAGIC)

        // Set callback pointers to free functions
        handler.startElementNs = startElementNsCallback
        handler.endElementNs = endElementNsCallback
        handler.characters = charactersCallback_C

        self.saxHandler = handler

        // Initialize user data
        self.userData = UnsafeMutablePointer<ParserUserData>.allocate(capacity: 1)
        self.userData?.initialize(to: ParserUserData(parser: self))

        // Create push parser context with empty initial chunk
        let emptyChunk = ""
        self.parserContext = emptyChunk.withCString { bytes in
            return xmlCreatePushParserCtxt(
                &self.saxHandler,
                self.userData,
                bytes,
                0,
                nil
            )
        }

        // Configure parser options
        if let context = parserContext {
            xmlCtxtUseOptions(context, Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOENT.rawValue))
        }
    }

    deinit {
        // Clean up libxml2 context
        if let context = parserContext {
            xmlFreeParserCtxt(context)
        }

        // Clean up user data
        userData?.deinitialize(count: 1)
        userData?.deallocate()

        // Clean up libxml2 global state (if last parser)
        xmlCleanupParser()
    }

    // MARK: - Public API

    /// Parses an XML chunk and returns the extracted game tags.
    ///
    /// This method is designed to handle incomplete XML fragments from a TCP stream.
    /// State (stream context, nesting) persists across calls, allowing tags that
    /// span multiple chunks to be parsed correctly.
    ///
    /// ## Error Recovery
    ///
    /// When malformed XML is encountered:
    /// 1. Parser enters error recovery mode (`inErrorRecovery = true`)
    /// 2. Returns any successfully parsed tags up to the error point
    /// 3. Buffers subsequent chunks in `errorBuffer` until resync
    /// 4. Searches for `<prompt>` tag to resync parser state
    /// 5. Resumes normal parsing from prompt onward
    ///
    /// - Parameter chunk: A string containing XML data (may be incomplete)
    /// - Returns: An array of parsed `GameTag` elements from this chunk
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
        // ERROR RECOVERY: If in recovery mode, buffer chunk and attempt resync
        if inErrorRecovery {
            // Append chunk to error buffer
            errorBuffer += chunk

            // Protect against unbounded error buffer growth
            if errorBuffer.count > maxErrorBufferSize {
                logger.fault("Error buffer exceeded 10MB limit - forcing parser reset")
                resetParserState()
                // Return empty tags - data is lost but we've recovered
                return []
            }

            // Try to resync on <prompt> tag
            if let recoveredChunk = attemptResync() {
                // Successfully resynced - parse the recovered chunk
                logger.info("Successfully resynced on <prompt> tag after error")
                return await parseChunk(recoveredChunk)
            } else {
                // No prompt found yet - stay in recovery mode
                return []
            }
        }

        // Normal parsing path
        return await parseChunk(chunk)
    }

    // MARK: - Internal Parsing

    /// Internal parsing logic using libxml2 push parser.
    ///
    /// This method feeds the chunk to libxml2's push parser in streaming mode.
    /// The parser context persists across chunks, allowing incomplete tags to
    /// buffer naturally within libxml2.
    ///
    /// - Parameter chunk: The XML chunk to parse
    /// - Returns: Array of successfully parsed tags
    private func parseChunk(_ chunk: String) async -> [GameTag] {
        guard let context = parserContext else {
            logger.error("Parser context is nil - cannot parse")
            return []
        }

        // Handle empty/whitespace input
        if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        // Reset completed tags for this parse operation
        completedTags = []

        // Update user data with current actor state
        userData?.pointee.currentStream = currentStream
        userData?.pointee.inStream = inStream
        userData?.pointee.tagStack = tagStack  // Persist tag stack
        userData?.pointee.characterBuffer = characterBuffer
        userData?.pointee.completedTags = []

        // Wrap in synthetic root to force completion of text nodes
        // This ensures character data is flushed even without a closing tag
        let wrappedXML = "<__synthetic_root__>\(chunk)</__synthetic_root__>"

        // Feed chunk to libxml2 push parser
        // terminate: 0 means more chunks may follow (true streaming mode)
        let result = wrappedXML.withCString { bytes in
            return xmlParseChunk(context, bytes, CInt(wrappedXML.utf8.count), 0)
        }

        // Check for parse errors
        if result != 0 {
            // Parse error occurred
            let error = NSError(
                domain: "XMLStreamParser",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "libxml2 parse error: code \(result)"]
            )

            logger.error("XML parse error in chunk: \(error.localizedDescription)")

            // Enter error recovery mode
            lastError = error
            inErrorRecovery = true

            // Return completed tags before error
            let partialResults = userData?.pointee.completedTags ?? []
            return partialResults
        }

        // Success - sync state back from user data
        currentStream = userData?.pointee.currentStream
        inStream = userData?.pointee.inStream ?? false
        tagStack = userData?.pointee.tagStack ?? []
        characterBuffer = userData?.pointee.characterBuffer ?? ""
        completedTags = userData?.pointee.completedTags ?? []

        // Clear error on successful parse
        lastError = nil

        return completedTags
    }

    // MARK: - Error Recovery

    /// Attempts to resynchronize the parser by finding a `<prompt>` tag.
    ///
    /// Searches the error buffer for a `<prompt>` tag. If found:
    /// 1. Exits error recovery mode
    /// 2. Resets parser state (stream context, tag stack, buffers)
    /// 3. Returns XML from prompt onward for parsing
    ///
    /// If no prompt found, stays in recovery mode and returns nil.
    ///
    /// - Returns: The XML chunk from `<prompt>` onward, or nil if no prompt found
    private func attemptResync() -> String? {
        // Search for <prompt> tag in error buffer
        guard let promptRange = findPromptResyncPoint(in: errorBuffer) else {
            // No prompt found yet - stay in recovery mode
            return nil
        }

        // Extract chunk from prompt onward
        let recoveredChunk = String(errorBuffer[promptRange.lowerBound...])

        // Exit recovery mode
        inErrorRecovery = false
        errorBuffer = ""
        lastError = nil

        // Reset parser state for clean slate
        // NOTE: We preserve stream state with libxml2 - the parser context maintains consistency
        tagStack = []
        characterBuffer = ""

        return recoveredChunk
    }

    /// Finds the resync point (start of `<prompt>` tag) in the given string.
    ///
    /// Uses simple string search to locate `<prompt>`. This is intentionally
    /// simple - we don't try to parse the malformed XML, just find a known-good
    /// sync point.
    ///
    /// - Parameter string: The string to search
    /// - Returns: Range of `<prompt>` tag if found, nil otherwise
    private func findPromptResyncPoint(in string: String) -> Range<String.Index>? {
        // Simple string search for <prompt> tag
        guard let range = string.range(of: "<prompt>") else {
            return nil
        }

        // Return range starting from <prompt> to end of string
        return range.lowerBound..<string.endIndex
    }

    /// Performs a nuclear reset of the parser state.
    ///
    /// Called when error buffer exceeds 10MB limit. Clears all state to prevent
    /// memory exhaustion. This is a last resort - it loses all buffered data.
    ///
    /// Reset actions:
    /// - Reset libxml2 parser context
    /// - Clear all buffers (error, character)
    /// - Reset stream state (currentStream, inStream)
    /// - Clear tag stack
    /// - Exit error recovery mode
    /// - Clear last error
    private func resetParserState() {
        // Clean up old parser context
        if let context = parserContext {
            xmlFreeParserCtxt(context)
        }

        // Create fresh parser context
        let emptyChunk = ""
        parserContext = emptyChunk.withCString { bytes in
            return xmlCreatePushParserCtxt(
                &saxHandler,
                userData,
                bytes,
                0,
                nil
            )
        }

        // Configure parser options
        if let context = parserContext {
            xmlCtxtUseOptions(context, Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOENT.rawValue))
        }

        // Clear all buffers
        errorBuffer = ""
        characterBuffer = ""

        // Reset stream state
        currentStream = nil
        inStream = false

        // Clear tag stack
        tagStack = []

        // Exit recovery mode
        inErrorRecovery = false
        lastError = nil

        logger.warning("Parser state forcibly reset due to buffer overflow")
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

    /// Exposes whether the parser is in error recovery mode (Issue #12).
    ///
    /// When the parser encounters malformed XML, it enters error recovery mode
    /// and buffers incoming chunks until a `<prompt>` tag resyncs the parser.
    ///
    /// - Returns: True if parser is in error recovery mode
    public func isInErrorRecovery() async -> Bool {
        return inErrorRecovery
    }

    /// Exposes the size of the error recovery buffer (Issue #12).
    ///
    /// Returns the number of characters currently buffered during error recovery.
    /// Used to verify the 10MB buffer limit is enforced.
    ///
    /// - Returns: Number of characters in error recovery buffer
    public func getErrorBufferSize() async -> Int {
        return errorBuffer.count
    }

    /// Exposes the last error encountered during parsing (Issue #12).
    ///
    /// Returns the most recent parsing error for test verification and debugging.
    /// Error is cleared when parsing succeeds or parser resyncs.
    ///
    /// - Returns: The last error, or nil if no error occurred
    public func getLastError() async -> Error? {
        return lastError
    }
}
