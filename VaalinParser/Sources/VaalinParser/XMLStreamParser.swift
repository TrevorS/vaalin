// ABOUTME: XMLStreamParser provides stateful SAX-based XML parsing for GemStone IV game output chunks

import Foundation
import os
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
    ///
    /// SAFETY: Although marked nonisolated(unsafe), this is accessed from XMLParserDelegate
    /// callbacks which are called synchronously during parse(). Since parse() is actor-isolated
    /// and executes serially, only one parse() can run at a time, making this safe.
    nonisolated(unsafe) private var currentStream: String?

    /// Whether the parser is currently inside a stream context.
    ///
    /// This flag persists across `parse()` calls and is updated by:
    /// - `<pushStream>` sets to `true`
    /// - `<popStream>` sets to `false`
    ///
    /// SAFETY: Although marked nonisolated(unsafe), this is accessed from XMLParserDelegate
    /// callbacks which are called synchronously during parse(). Since parse() is actor-isolated
    /// and executes serially, only one parse() can run at a time, making this safe.
    nonisolated(unsafe) private var inStream: Bool = false

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

    /// Line number where the last error occurred.
    ///
    /// Used for diagnostic logging to help identify problematic game output.
    /// XMLParser provides this via `parser.lineNumber` in error callbacks.
    nonisolated(unsafe) private var errorLineNumber: Int = 0

    /// The most recent parsing error encountered.
    ///
    /// Stores the error for test verification and debugging. Cleared when
    /// parsing succeeds or parser resyncs successfully.
    private var lastError: Error?

    /// Count of consecutive parse failures.
    ///
    /// Used to distinguish incomplete XML (which may fail once or twice while
    /// buffering) from truly malformed XML (which keeps failing).
    /// Reset to 0 on successful parse.
    private var consecutiveFailures: Int = 0

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
    /// ## Error Recovery
    ///
    /// When malformed XML is encountered:
    /// 1. Parser enters error recovery mode (`inErrorRecovery = true`)
    /// 2. Returns any successfully parsed tags up to the error point
    /// 3. Buffers subsequent chunks in `errorBuffer` until resync
    /// 4. Searches for `<prompt>` tag to resync parser state
    /// 5. Resumes normal parsing from prompt onward
    ///
    /// ## Buffering Strategy
    ///
    /// The parser maintains multiple buffers to handle TCP fragmentation:
    /// - `xmlBuffer`: Stores incomplete XML from previous chunk
    /// - `tagStack`: Maintains open tags across chunks
    /// - `characterBuffer`: Accumulates character data split across callbacks
    /// - `errorBuffer`: Accumulates chunks during error recovery
    ///
    /// Incomplete tags at chunk boundaries remain on the stack until
    /// subsequent chunks complete them. Only fully closed tags are returned.
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

    /// Internal parsing logic extracted from `parse()` to separate error recovery concerns.
    ///
    /// This method performs the actual XML parsing with XMLParser. If parsing fails,
    /// it enters error recovery mode and returns any tags parsed up to the error point.
    ///
    /// - Parameter chunk: The XML chunk to parse
    /// - Returns: Array of successfully parsed tags
    private func parseChunk(_ chunk: String) async -> [GameTag] {
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
            logger.warning("XML buffer exceeded \(self.maxBufferSize) chars, clearing buffer")
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

        // If parsing failed, decide whether to buffer or enter error recovery
        if !success {
            // Strategy for distinguishing incomplete vs truly malformed XML:
            //
            // MALFORMED XML (enter error recovery immediately):
            //   - Same chunk fails 2+ consecutive times → definitely malformed
            //     (first failure buffers, second confirms it's not just incomplete)
            //   - Syntax error patterns detected (missing quotes, invalid attributes)
            //   - Buffer has grown too large (> maxBufferSize)
            //
            // INCOMPLETE XML (buffer and wait for more data):
            //   - Unbalanced tags (more opening than closing)
            //   - First failure (may just need more data)
            //   - No obvious syntax errors
            //   - Examples: "<a exist=", "<parent><child>text</child>", "<prompt>te"
            //
            // Priority: consecutiveFailures >= 2 > syntax errors > buffer size > tag balance

            // Check 1: Detect obvious syntax errors (missing quotes, malformed attributes)
            // Pattern: attribute name followed by => or =< (invalid syntax)
            // Examples: noun=>, attr=<, id=>
            // BUT: Don't match incomplete closing tags like "</out" (that's just incomplete, not malformed)
            // Strategy: Look for = followed by > or < that's NOT part of a closing tag pattern "</"
            let syntaxErrorPattern = #"=\s*[><]"#
            let hasSyntaxError: Bool
            if let range = combinedXML.range(of: syntaxErrorPattern, options: .regularExpression) {
                // Found potential syntax error - verify it's not an incomplete closing tag
                // Incomplete closing tag pattern: ends with "</[a-z]+" without the closing >
                let incompleteClosingTagPattern = #"</[a-zA-Z_][a-zA-Z0-9_]*$"#
                let isIncompleteClosingTag = combinedXML.range(
                    of: incompleteClosingTagPattern,
                    options: .regularExpression
                ) != nil
                hasSyntaxError = !isIncompleteClosingTag
            } else {
                hasSyntaxError = false
            }

            if hasSyntaxError {
                // Definite syntax error - enter recovery immediately
                let partialTags = currentParsedTags
                // Don't buffer (single chunk failure, prompt in chunk is suspect)
                enterErrorRecovery(error: xmlParser.parserError, lineNumber: xmlParser.lineNumber, failedChunk: combinedXML, shouldBufferChunk: false)
                // Don't resync in the same parseChunk() call - wait for next parse() call
                // The top-level parse() method will handle resync on subsequent chunks
                return partialTags
            }

            // Check 2: Buffer too large
            let bufferTooLarge = combinedXML.count > maxBufferSize
            if bufferTooLarge {
                // Buffer exceeded limit - enter recovery to prevent unbounded growth
                let partialTags = currentParsedTags
                // Don't buffer (discard oversized chunk)
                enterErrorRecovery(error: xmlParser.parserError, lineNumber: xmlParser.lineNumber, failedChunk: combinedXML, shouldBufferChunk: false)
                // Don't resync in the same parseChunk() call - wait for next parse() call
                // The top-level parse() method will handle resync on subsequent chunks
                return partialTags
            }

            // Check 3: Tag balance heuristic
            let openingTagCount = combinedXML.components(separatedBy: "<").count - 1
            let closingTagCount = combinedXML.components(separatedBy: "</").count - 1
            let selfClosingCount = combinedXML.components(separatedBy: "/>").count - 1

            // Rough balance check: if we have as many (or more) closing tags as
            // opening tags (accounting for self-closing), the chunk looks "complete"
            // Subtract self-closing from opening count since they don't need closing tags
            let netOpeningTags = openingTagCount - selfClosingCount
            let requiredClosingTags = Int(Double(netOpeningTags) * 0.8) // 80% of opening tags should be closed
            // Chunk looks complete if: has closing tags AND they roughly match opening tags
            let looksComplete = closingTagCount > 0 && closingTagCount >= requiredClosingTags

            if looksComplete {
                // Chunk appears complete but failed to parse (malformed syntax)
                // Enter error recovery mode and return any partial results
                let partialTags = currentParsedTags
                // Increment failure counter (this is a real failure, not buffering)
                consecutiveFailures += 1
                // Buffer if we had a prior failure (multi-chunk), otherwise discard
                let shouldBuffer = consecutiveFailures >= 2
                enterErrorRecovery(error: xmlParser.parserError, lineNumber: xmlParser.lineNumber, failedChunk: combinedXML, shouldBufferChunk: shouldBuffer)
                // Don't resync in the same parseChunk() call - wait for next parse() call
                // The top-level parse() method will handle resync on subsequent chunks
                return partialTags
            }

            // Check 4: Multiple buffering failures
            // If we've buffered before (consecutiveFailures >= 1) and adding new data still fails,
            // check if this is the second consecutive buffering failure
            if consecutiveFailures >= 1 && !xmlBuffer.isEmpty {
                // This is at least the second buffering failure
                consecutiveFailures += 1

                // Decide whether to enter recovery:
                // - If combined chunk contains <prompt> tag AND we've failed 2+ times: enter recovery
                //   (Prompt is a sync point, suggests buffered data + prompt = malformed + resync opportunity)
                // - If no prompt but 5+ failures: enter recovery
                //   (Valid incomplete XML shouldn't take more than 5 chunks; if it does, likely stuck)
                let containsPrompt = combinedXML.contains("<prompt>")
                let shouldEnterRecovery = (consecutiveFailures >= 2 && containsPrompt) || consecutiveFailures >= 5

                if shouldEnterRecovery {
                    let partialTags = currentParsedTags
                    // Buffer the chunk (may contain prompt for resync)
                    enterErrorRecovery(error: xmlParser.parserError, lineNumber: xmlParser.lineNumber, failedChunk: combinedXML, shouldBufferChunk: true)

                    // Try immediate resync
                    if let recoveredChunk = attemptResync() {
                        logger.info("Successfully resynced after multiple buffering failures")
                        return await parseChunk(recoveredChunk)
                    }

                    return partialTags
                }

                // First consecutive failure - keep buffering
                xmlBuffer = combinedXML
                return []
            }

            // First buffering failure - buffer and wait for more data
            consecutiveFailures += 1
            xmlBuffer = combinedXML
            return []
        }

        // Clear buffer on successful parse
        xmlBuffer = ""

        // Clear error state on successful parse
        lastError = nil
        consecutiveFailures = 0

        // If there's remaining character data at the end and we're at root level,
        // create a final :text node
        if !currentCharacterBuffer.isEmpty && currentTagStack.isEmpty {
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed,
                streamId: inStream ? currentStream : nil
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

    // MARK: - Error Recovery

    /// Enters error recovery mode and handles the failed chunk.
    ///
    /// Called when XML parsing fails. Sets recovery flag, stores error details,
    /// and decides whether to buffer the failed chunk for resync attempts.
    ///
    /// Strategy for buffering vs discarding:
    /// - If `consecutiveFailures >= 2`: Multiple chunks combined, buffer the failed chunk
    ///   (it contains new data that arrived after initial error, may have valid prompt)
    /// - If `consecutiveFailures == 1`: Single chunk failed, discard it
    ///   (prompt in this chunk is suspect, part of malformed data)
    ///
    /// - Parameters:
    ///   - error: The parsing error that triggered recovery (may be nil)
    ///   - lineNumber: The line number where error occurred
    ///   - failedChunk: The full XML chunk that failed
    ///   - shouldBufferChunk: Whether to buffer the chunk (true if new data arrived)
    private func enterErrorRecovery(error: Error?, lineNumber: Int, failedChunk: String, shouldBufferChunk: Bool) {
        inErrorRecovery = true
        lastError = error
        errorLineNumber = lineNumber

        // Buffer strategy: only trust prompts from multi-chunk failures
        if shouldBufferChunk {
            // Multiple chunks combined - buffer for potential resync
            errorBuffer = failedChunk
            logger.info("Buffering \(failedChunk.count) characters for resync (multi-chunk failure)")
        } else {
            // Single chunk failed - discard it (prompt is suspect)
            errorBuffer = ""
            logger.warning("Discarding \(failedChunk.count) characters of malformed XML (single-chunk failure)")
        }

        xmlBuffer = ""

        // Reset consecutive failures counter since we're entering recovery mode
        consecutiveFailures = 0

        logger.error("Entering error recovery mode at line \(lineNumber): \(String(describing: error))")
    }

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
        // CRITICAL: Reset stream state too - after an error we can't trust the stream context
        currentStream = nil
        inStream = false
        tagStack = []
        characterBuffer = ""
        xmlBuffer = ""

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
    /// - Clear all buffers (xml, error, character)
    /// - Reset stream state (currentStream, inStream)
    /// - Clear tag stack
    /// - Exit error recovery mode
    /// - Clear last error
    /// - Reset consecutive failures counter
    private func resetParserState() {
        // Clear all buffers
        xmlBuffer = ""
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
        consecutiveFailures = 0

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

        // STREAM CONTROL: Handle pushStream tag
        // <pushStream id="X"/> sets the current stream context
        // This is a control directive, not a game tag, so return early
        if elementName == "pushStream" {
            // Extract stream ID from id attribute
            // If no id attribute, set currentStream to nil (graceful handling)
            currentStream = attributeDict["id"]
            inStream = true

            // Don't create a GameTag - this is a stream control directive
            return
        }

        // STREAM CONTROL: Handle popStream opening tag (for self-closing tags)
        // <popStream/> clears the current stream context
        // For self-closing tags, XMLParser calls didStartElement first
        // This is a control directive, not a game tag, so return early
        if elementName == "popStream" {
            currentStream = nil
            inStream = false

            // Don't create a GameTag - this is a stream control directive
            return
        }

        // STREAM CONTROL: Handle clearStream tag
        // <clearStream id="X"/> clears the current stream (like popStream)
        // This is a control directive, not a game tag, so return early
        if elementName == "clearStream" {
            currentStream = nil
            inStream = false

            // Don't create a GameTag - this is a stream control directive
            return
        }

        // Handle accumulated character data before starting new tag
        if !currentCharacterBuffer.isEmpty {
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed,
                streamId: inStream ? currentStream : nil
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
            state: .open,
            streamId: inStream ? currentStream : nil
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

        // STREAM CONTROL: Handle popStream tag
        // <popStream/> clears the current stream context
        // This is a control directive, not a game tag, so return early
        if elementName == "popStream" {
            currentStream = nil
            inStream = false

            // Don't process as a normal tag - this is a stream control directive
            return
        }

        // STREAM CONTROL: Handle pushStream closing tag (for self-closing tags)
        // When <pushStream id="X"/> is self-closing, XMLParser calls didEndElement too
        // We need to ignore it since we already handled it in didStartElement
        if elementName == "pushStream" {
            // Don't process as a normal tag - already handled in didStartElement
            return
        }

        // STREAM CONTROL: Handle clearStream closing tag (for self-closing tags)
        // When <clearStream id="X"/> is self-closing, XMLParser calls didEndElement too
        // We need to ignore it since we already handled it in didStartElement
        if elementName == "clearStream" {
            // Don't process as a normal tag - already handled in didStartElement
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
                state: .closed,
                streamId: inStream ? currentStream : nil
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

    /// Called when parser encounters a parsing error.
    ///
    /// This delegate callback is invoked synchronously during the `parse()` call
    /// when XMLParser encounters malformed XML. We store the error details for
    /// error recovery logic in the main `parseChunk()` method.
    ///
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    /// - Parameters:
    ///   - parser: The XMLParser instance
    ///   - parseError: The error that occurred
    nonisolated public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Store line number for error recovery logging
        // The main parseChunk() method will call enterErrorRecovery() after parse() returns
        errorLineNumber = parser.lineNumber

        // Log detailed error information for debugging
        // Note: Logger is safe to use from nonisolated context (thread-safe by design)
        let logger = Logger(subsystem: "com.vaalin.parser", category: "XMLStreamParser")
        logger.error("XML parse error at line \(parser.lineNumber), column \(parser.columnNumber): \(parseError.localizedDescription)")
    }

    /// Called when parser encounters a validation error.
    ///
    /// This is called for DTD/schema validation errors. We treat these the same
    /// as parse errors - the main `parseChunk()` method will handle recovery.
    ///
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    /// - Parameters:
    ///   - parser: The XMLParser instance
    ///   - validationError: The validation error that occurred
    nonisolated public func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        // Store line number for error recovery logging
        errorLineNumber = parser.lineNumber

        // Log validation error
        let logger = Logger(subsystem: "com.vaalin.parser", category: "XMLStreamParser")
        logger.error("XML validation error at line \(parser.lineNumber), column \(parser.columnNumber): \(validationError.localizedDescription)")
    }
}
