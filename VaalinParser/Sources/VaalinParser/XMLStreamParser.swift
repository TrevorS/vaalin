// ABOUTME: XMLStreamParser provides stateful SAX-based XML parsing for GemStone IV game output chunks
// swiftlint:disable type_body_length

import Foundation
import OSLog
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
public actor XMLStreamParser: NSObject, XMLParserDelegate {
    // MARK: - Constants

    /// Maximum buffer size in characters to prevent unbounded memory growth.
    ///
    /// If buffer exceeds this size, it will be cleared and parsing will fail gracefully.
    /// 10KB should handle even extremely fragmented chunks (typical game output is < 1KB).
    private let maxBufferSize = 10_000

    /// Optional EventBus for publishing tag events to subscribers.
    ///
    /// When provided, the parser publishes events for metadata tags (left, right, spell, progressBar, prompt)
    /// and stream control tags (pushStream). This enables reactive UI updates without polling.
    ///
    /// Event naming conventions:
    /// - Hands: `metadata/left`, `metadata/right`
    /// - Spells: `metadata/spell`
    /// - Progress bars: `metadata/progressBar/{id}` (e.g., `metadata/progressBar/health`)
    /// - Prompt: `metadata/prompt`
    /// - Streams: `stream/{id}` (e.g., `stream/thoughts`)
    private let eventBus: EventBus?

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

    /// Active stream tag for wrapping stream content (like Illthorn's collectStreamContent).
    ///
    /// When `<pushStream id="X">` is encountered, we create a synthetic `stream` tag
    /// with `attrs.id = "X"` and `state = .open`. All subsequent content becomes children
    /// of this stream tag until `<popStream>` is encountered.
    ///
    /// This matches Illthorn's architecture:
    /// - Stream content is WRAPPED in a parent stream tag
    /// - Filtering removes the ENTIRE stream tag (and all children)
    /// - Prevents individual tags from "leaking" into main log
    ///
    /// SAFETY: Although marked nonisolated(unsafe), this is accessed from XMLParserDelegate
    /// callbacks which are called synchronously during parse(). Since parse() is actor-isolated
    /// and executes serially, only one parse() can run at a time, making this safe.
    nonisolated(unsafe) private var activeStreamTag: GameTag?

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

    /// Structured logging for error diagnostics.
    private let logger = Logger(subsystem: "com.vaalin.parser", category: "XMLStreamParser")

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

    /// Tags that need EventBus publishing after parsing completes.
    /// Accumulated during nonisolated delegate callbacks, published after parse() returns.
    nonisolated(unsafe) private var tagsNeedingEventPublish: [GameTag] = []

    // MARK: - Initialization

    /// Creates a new XML stream parser with empty state.
    ///
    /// - Parameter eventBus: Optional EventBus for publishing tag events to subscribers.
    ///                       If provided, metadata tags and stream control tags will publish events.
    ///                       Defaults to `nil` for backward compatibility.
    public init(eventBus: EventBus? = nil) {
        self.eventBus = eventBus
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
        tagsNeedingEventPublish = []  // Clear event publish queue

        // Handle empty/whitespace input
        if chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        // Prepend any buffered XML from previous chunk
        var combinedXML = xmlBuffer + chunk

        // Protect against unbounded buffer growth
        if combinedXML.count > maxBufferSize {
            // Buffer too large - likely malformed XML or attack
            // Clear buffer and try parsing just the new chunk
            logger.warning("XML buffer exceeded max size (\(self.maxBufferSize)), clearing buffer")
            xmlBuffer = ""
            combinedXML = chunk
        }

        // Wrap in synthetic root tag for XMLParser (requires single root element)
        let wrappedXML = "<__synthetic_root__>\(combinedXML)</__synthetic_root__>"

        // Create XMLParser instance
        guard let data = wrappedXML.data(using: .utf8) else {
            return []
        }

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        // Parse synchronously (delegate callbacks happen during this call)
        let success = xmlParser.parse()

        // If parsing failed, buffer for next chunk
        if !success {
            xmlBuffer = combinedXML
            // Don't return partial results for incomplete XML - it's still being built up
            return []
        }

        // Parse succeeded - clear buffer
        xmlBuffer = ""

        // Flush any remaining character data at the end
        flushRemainingCharacterData()

        // Transfer any incomplete tags to persistent stack for next parse
        #if DEBUG
        assert(currentTagStack.isEmpty, "Bug: Successful parse left tags open on stack")
        #endif
        tagStack = currentTagStack

        // Publish events for metadata tags (now that we're back in actor context with await support)
        for tag in tagsNeedingEventPublish {
            await publishEventIfNeeded(for: tag)
        }

        // Return completed tags
        return currentParsedTags
    }

    // MARK: - Event Publishing

    /// Publishes stream event for pushStream control directive.
    ///
    /// This method is called when a `<pushStream id="X"/>` tag is encountered.
    /// Unlike regular tags, pushStream doesn't create a GameTag during normal parsing,
    /// so we create a synthetic GameTag just for the event publishing.
    ///
    /// - Parameters:
    ///   - streamId: The stream ID from the pushStream tag
    ///   - attributes: The full attribute dictionary from the tag
    private func publishStreamEvent(streamId: String, attributes: [String: String]) async {
        guard let eventBus = eventBus else { return }

        let streamTag = GameTag(
            name: "pushStream",
            text: nil,
            attrs: attributes,
            children: [],
            state: .closed,
            streamId: streamId
        )
        await eventBus.publish("stream/\(streamId)", data: streamTag)
        logger.debug("Published stream event: stream/\(streamId)")
    }

    /// Publishes EventBus event for metadata tags.
    ///
    /// This method is called after a tag is fully constructed and closed.
    /// Only metadata tags (left, right, spell, progressBar, prompt, nav, compass,
    /// streamWindow, dialogData) and stream control tags (pushStream) trigger events.
    /// Regular game output tags do not publish events.
    ///
    /// Event publishing is synchronous within the actor context to ensure reliable delivery.
    ///
    /// - Parameter tag: The completed GameTag to potentially publish
    private func publishEventIfNeeded(for tag: GameTag) async {
        guard let eventBus = eventBus else { return }

        // Determine event name based on tag type
        let eventName: String? = switch tag.name {
        // Hands metadata
        case "left": "metadata/left"
        case "right": "metadata/right"
        case "spell": "metadata/spell"

        // Progress bars - dynamic event name with id
        case "progressBar":
            if let id = tag.attrs["id"] {
                "metadata/progressBar/\(id)"
            } else {
                nil // No id - don't publish
            }

        // Prompt
        case "prompt": "metadata/prompt"

        // Navigation (compass panel)
        case "nav": "metadata/nav"

        // Compass (compass panel)
        case "compass": "metadata/compass"

        // Stream window (compass panel - room title)
        case "streamWindow":
            // Only publish for main window with subtitle (room title)
            if let id = tag.attrs["id"], id == "main", tag.attrs["subtitle"] != nil {
                "metadata/streamWindow/room"
            } else {
                nil
            }

        // Dialog data (spells panel, injuries panel)
        case "dialogData":
            // Publish with dynamic event name based on id
            if let id = tag.attrs["id"] {
                "metadata/dialogData/\(id)"
            } else {
                nil
            }

        // Stream control - handled separately in didStartElement
        case "pushStream":
            if let id = tag.attrs["id"] {
                "stream/\(id)"
            } else {
                nil
            }

        // Default: no event for regular tags
        default: nil
        }

        guard let eventName = eventName else { return }

        // Publish directly - we're in actor context
        await eventBus.publish(eventName, data: tag)
        logger.debug("Published event: \(eventName) for tag: \(tag.name)")
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

        // STREAM CONTROL: Handle pushStream tag
        // <pushStream id="X"/> creates a synthetic stream wrapper tag and sets stream context
        if elementName == "pushStream" {
            handlePushStream(attributeDict["id"], attributes: attributeDict)
            return
        }

        // STREAM CONTROL: Handle popStream opening tag (for self-closing tags)
        // <popStream/> clears the current stream context
        // For self-closing tags, XMLParser calls didStartElement first
        // This is a control directive, not a game tag, so return early
        if elementName == "popStream" {
            // DEBUG: Log stream state change (before clearing)
            if let streamId = currentStream {
                logger.debug("🌊 popStream: leaving stream '\(streamId, privacy: .public)'")
            }

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

        // STREAM CONTROL: Handle component tag
        // <component id="X"> creates a synthetic stream wrapper tag (like pushStream)
        if elementName == "component" {
            handleComponent(attributeDict["id"], attributes: attributeDict)
            return
        }

        // Handle accumulated character data before starting new tag
        flushCharacterDataBeforeNewTag()

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
        // <popStream/> closes the active stream wrapper and clears stream context
        if elementName == "popStream" {
            closeStreamWrapper()
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

        // STREAM CONTROL: Handle component closing tag
        // </component> closes the active stream wrapper (like popStream)
        // EXCEPTION: Self-closing <component id="X"/> should pass through as regular tags
        if elementName == "component" {
            if handleComponentClosing() {
                return  // Handled as self-closing component
            }
            // Regular closing component tag with content
            closeStreamWrapper()
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
            // Log warning and discard to prevent crashes
            logger.warning("Tag mismatch: expected \(tag.name), got \(elementName)")
            return
        }

        // Handle accumulated character data and finalize tag
        finalizeTag(&tag)

        // Route closed tag to appropriate destination
        routeClosedTag(tag)

        // Queue tag for event publishing (will be published after parse() completes)
        // We can't use await here because didEndElement is nonisolated
        tagsNeedingEventPublish.append(tag)
    }

    /// Called when parser encounters an error
    /// Logs diagnostic information for debugging
    /// - Note: Marked nonisolated because XMLParser calls this synchronously during parse()
    nonisolated public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Log error with line number for diagnostics
        logger.error("XML parse error at line \(parser.lineNumber): \(parseError.localizedDescription)")

        // The parse() method handles error recovery by buffering incomplete XML
        // Any successfully parsed tags before the error are already in currentParsedTags
    }

    // MARK: - Private Helpers

    /// Flushes remaining character data at the end of parse.
    ///
    /// Creates a final :text node from any accumulated character buffer after parsing completes.
    /// Routes to activeStreamTag children or root-level parsed tags.
    nonisolated private func flushRemainingCharacterData() {
        guard !currentCharacterBuffer.isEmpty && currentTagStack.isEmpty else { return }

        let textNode = GameTag(
            name: ":text",
            text: currentCharacterBuffer,
            attrs: [:],
            children: [],
            state: .closed,
            streamId: inStream ? currentStream : nil
        )

        if let activeStream = activeStreamTag {
            // Inside a stream - add to stream wrapper's children
            var streamTag = activeStream
            streamTag.children.append(textNode)
            activeStreamTag = streamTag
        } else {
            // At root level - add to parsed tags
            currentParsedTags.append(textNode)
        }

        currentCharacterBuffer = ""
    }

    /// Handles pushStream control directive.
    ///
    /// Creates synthetic stream wrapper and sets stream context.
    /// Publishes stream event to EventBus if available.
    ///
    /// - Parameters:
    ///   - streamId: Stream ID from id attribute
    ///   - attributes: Full attribute dictionary
    nonisolated private func handlePushStream(_ streamId: String?, attributes: [String: String]) {
        currentStream = streamId
        inStream = true

        // DEBUG: Log stream state change
        if let streamId = streamId {
            logger.debug("🌊 pushStream: entering stream '\(streamId, privacy: .public)'")
        }

        // Create synthetic stream wrapper tag
        let streamTag = GameTag(
            name: "stream",
            text: nil,
            attrs: ["id": streamId ?? "unknown"],
            children: [],
            state: .open,
            streamId: streamId
        )
        activeStreamTag = streamTag

        // Publish stream event
        if let streamId = streamId {
            Task {
                await publishStreamEvent(streamId: streamId, attributes: attributes)
            }
        }
    }

    /// Handles component control directive.
    ///
    /// Creates synthetic stream wrapper (like pushStream) and sets stream context.
    /// Publishes stream event to EventBus if available.
    ///
    /// - Parameters:
    ///   - streamId: Stream ID from id attribute
    ///   - attributes: Full attribute dictionary
    nonisolated private func handleComponent(_ streamId: String?, attributes: [String: String]) {
        currentStream = streamId
        inStream = true

        // DEBUG: Log stream state change
        if let streamId = streamId {
            logger.debug("🌊 component: entering stream '\(streamId, privacy: .public)'")
        }

        // Create synthetic stream wrapper tag
        let streamTag = GameTag(
            name: "stream",
            text: nil,
            attrs: ["id": streamId ?? "unknown"],
            children: [],
            state: .open,
            streamId: streamId
        )
        activeStreamTag = streamTag

        // Publish stream event
        if let streamId = streamId {
            Task {
                await publishStreamEvent(streamId: streamId, attributes: attributes)
            }
        }
    }

    /// Flushes accumulated character data before starting a new tag.
    ///
    /// Creates a :text node from the character buffer and routes it appropriately:
    /// 1. If inside stream, adds to activeStreamTag children
    /// 2. If inside parent tag, adds to parent's children
    /// 3. Otherwise, adds to root-level parsed tags
    nonisolated private func flushCharacterDataBeforeNewTag() {
        guard !currentCharacterBuffer.isEmpty else { return }

        let textNode = GameTag(
            name: ":text",
            text: currentCharacterBuffer,
            attrs: [:],
            children: [],
            state: .closed,
            streamId: inStream ? currentStream : nil
        )

        // Priority routing
        if let activeStream = activeStreamTag {
            // Inside a stream - add to stream wrapper's children
            var streamTag = activeStream
            streamTag.children.append(textNode)
            activeStreamTag = streamTag
        } else if currentTagStack.isEmpty {
            // At root level - add text node to parsed tags
            currentParsedTags.append(textNode)
        } else {
            // Inside a parent tag - add text node as child of parent
            var parent = currentTagStack.removeLast()
            parent.children.append(textNode)
            currentTagStack.append(parent)
        }

        currentCharacterBuffer = ""
    }

    /// Handles component closing tag logic.
    ///
    /// Checks if component is self-closing (empty stream wrapper) and handles
    /// it as metadata tag instead of stream control.
    ///
    /// - Returns: True if handled as self-closing component, false if regular closing
    nonisolated private func handleComponentClosing() -> Bool {
        // Check if this is a self-closing tag (empty stream wrapper with no children)
        guard let streamTag = activeStreamTag, streamTag.children.isEmpty else {
            return false
        }

        // Self-closing component tag - create regular tag instead of stream wrapper
        let componentTag = GameTag(
            name: "component",
            text: nil,
            attrs: streamTag.attrs,
            children: [],
            state: .closed,
            streamId: nil
        )

        // Clear stream context (was temporary for self-closing tag)
        currentStream = nil
        inStream = false
        activeStreamTag = nil

        // Add as regular tag (not stream control)
        currentParsedTags.append(componentTag)

        return true
    }

    /// Finalizes a closing tag by assigning text and children.
    ///
    /// Handles two cases:
    /// 1. Tag has no children - character buffer becomes tag's text
    /// 2. Tag has children and trailing text - adds text as final :text child
    ///
    /// - Parameter tag: Tag to finalize (mutated in place)
    nonisolated private func finalizeTag(_ tag: inout GameTag) {
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
        currentCharacterBuffer = ""
    }

    /// Routes a closed tag to the appropriate destination.
    ///
    /// Priority order:
    /// 1. If inside stream, adds to activeStreamTag children
    /// 2. If inside parent tag, adds to parent's children
    /// 3. Otherwise, adds to root-level parsed tags
    ///
    /// - Parameter tag: Closed tag to route
    nonisolated private func routeClosedTag(_ tag: GameTag) {
        if let activeStream = activeStreamTag {
            // Inside a stream - add to stream wrapper's children
            var streamTag = activeStream
            streamTag.children.append(tag)
            activeStreamTag = streamTag
        } else if currentTagStack.isEmpty {
            // No parent - this is a root-level tag
            currentParsedTags.append(tag)
        } else {
            // Has parent - add as child to the parent tag
            var parent = currentTagStack.removeLast()
            parent.children.append(tag)
            currentTagStack.append(parent)
        }
    }

    /// Closes the active stream wrapper and clears stream context.
    ///
    /// This helper consolidates the common logic for closing stream wrappers
    /// (used by both popStream and component closing tags). It:
    /// 1. Flushes any trailing character data into the stream wrapper
    /// 2. Finalizes the stream wrapper tag
    /// 3. Clears stream context state
    ///
    /// - Note: Marked nonisolated because called from XMLParserDelegate callbacks
    nonisolated private func closeStreamWrapper() {
        // DEBUG: Log stream state change (before clearing)
        if let streamId = currentStream {
            logger.debug("🌊 closeStreamWrapper: leaving stream '\(streamId, privacy: .public)'")
        }

        // CRITICAL: Flush any trailing character data into stream wrapper before closing
        // This prevents text fragments from leaking out as root-level text nodes
        if !currentCharacterBuffer.isEmpty, var streamTag = activeStreamTag {
            let textNode = GameTag(
                name: ":text",
                text: currentCharacterBuffer,
                attrs: [:],
                children: [],
                state: .closed,
                streamId: currentStream
            )
            streamTag.children.append(textNode)
            activeStreamTag = streamTag
            currentCharacterBuffer = ""
        }

        // Close and finalize the active stream wrapper tag
        if var streamTag = activeStreamTag {
            streamTag.state = .closed

            // Add completed stream tag to parsed tags
            currentParsedTags.append(streamTag)

            // Queue for event publishing
            tagsNeedingEventPublish.append(streamTag)
        }

        // Clear stream context
        currentStream = nil
        inStream = false
        activeStreamTag = nil
    }
}
// swiftlint:enable type_body_length
