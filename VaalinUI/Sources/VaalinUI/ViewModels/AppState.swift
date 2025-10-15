// ABOUTME: AppState coordinates connection lifecycle, polling bridge, command input, and command history

import Foundation
import Observation
import os
import VaalinCore
import VaalinNetwork

#if canImport(VaalinParser)
import VaalinParser
#endif

/// @Observable @MainActor coordinator that manages connection lifecycle, UI polling, and command input.
///
/// `AppState` acts as the integration layer between actor-based networking components
/// (LichConnection, XMLStreamParser, ParserConnectionBridge) and SwiftUI views. It manages
/// the connection lifecycle, polls the bridge for parsed tags, coordinates command input
/// with command history, and sends commands to the game server.
///
/// ## Architecture
///
/// ```
/// AppState (MainActor)
///    ├─ owns → LichConnection (actor)
///    ├─ owns → XMLStreamParser (actor)
///    ├─ owns → ParserConnectionBridge (actor)
///    ├─ owns → CommandHistory (actor)
///    ├─ owns → GameLogViewModel (@Observable)
///    ├─ owns → CommandInputViewModel (@Observable)
///    ├─ polling → getParsedTags() → filterContentTags() → appendMessage() [main thread]
///    └─ sendCommand() → connection.send() [game server]
/// ```
///
/// ## Tag Filtering
///
/// AppState implements three-layer filtering to prevent blank lines:
/// 1. **Parser layer**: XMLStreamParser publishes metadata events to EventBus
/// 2. **Session layer**: AppState filters metadata tags from game log (this class)
/// 3. **View layer**: GameLogViewModel.hasContentRecursive() catches remaining empty tags
///
/// Metadata tags (left, right, spell, progressBar, dialogData, etc.) are NOT
/// displayed in the game log because they have no visible text content. Instead,
/// they are consumed by panels via EventBus subscriptions.
///
/// This matches the architecture of illthorn (filters metadata at session layer)
/// and ProfanityFE (returns nil for metadata tags).
///
/// ## Polling Pattern
///
/// The polling loop decouples actor-based components from @Observable view models:
/// - Bridge accumulates GameTags in actor-isolated storage
/// - Polling task fetches tags every 100ms on main thread
/// - Tags are converted to Messages and appended to GameLogViewModel
/// - View automatically updates via @Observable reactivity
///
/// ## Thread Safety
///
/// All access to GameLogViewModel occurs on MainActor, ensuring thread-safe SwiftUI updates.
/// Bridge operations are async calls to actor-isolated methods, maintaining proper isolation.
///
/// ## Performance
///
/// - **Polling interval**: 100ms (10 updates/second)
/// - **Overhead**: < 1ms per poll when no tags (empty array check)
/// - **Tag processing**: < 5ms per 100 tags (typical batch size)
///
/// ## Example Usage
///
/// ```swift
/// @State private var appState = AppState()
///
/// // Connect to Lich
/// try await appState.connect()
///
/// // Bind to GameLogView
/// GameLogView(viewModel: appState.gameLogViewModel, isConnected: appState.isConnected)
///
/// // Bind to CommandInputView
/// CommandInputView(viewModel: appState.commandInputViewModel) { command in
///     await appState.sendCommand(command)
/// }
///
/// // Disconnect when done
/// await appState.disconnect()
/// ```
@Observable
@MainActor
public final class AppState {
    // MARK: - Dependencies

    /// The TCP connection to Lich detachable client
    private let connection: LichConnection

    /// The XML stream parser
    #if canImport(VaalinParser)
    private let parser: XMLStreamParser
    #else
    private let parser: any XMLStreamParsing
    #endif

    /// The bridge that integrates connection and parser
    private let bridge: ParserConnectionBridge

    /// Shared EventBus for cross-component communication
    private let eventBus: EventBus

    /// Stream buffer manager for routing stream content to independent buffers
    private let streamBufferManager: StreamBufferManager

    /// Stream router for routing stream content based on mirror mode
    private let streamRouter: StreamRouter

    // MARK: - State

    /// Application settings for configuration (mirror mode, etc.)
    public var settings: Settings = .makeDefault()

    /// The game log view model (main thread access only)
    public let gameLogViewModel: GameLogViewModel

    /// The command input view model (main thread access only)
    public let commandInputViewModel: CommandInputViewModel

    /// Panel view models for HUD panels (Phase 2 layout)
    public let handsPanelViewModel: HandsPanelViewModel
    public let vitalsPanelViewModel: VitalsPanelViewModel
    public let compassPanelViewModel: CompassPanelViewModel
    public let injuriesPanelViewModel: InjuriesPanelViewModel
    public let spellsPanelViewModel: SpellsPanelViewModel

    /// Prompt view model for prompt display (Phase 2 layout)
    public let promptViewModel: PromptViewModel

    /// Command history actor for storing and recalling commands
    private let commandHistory: CommandHistory

    /// Whether currently connected to Lich
    public var isConnected: Bool = false

    /// Lich host address (default: localhost for detachable client)
    public var host: String = "127.0.0.1"

    /// Lich port number (default: 8000 for detachable client)
    public var port: UInt16 = 8000

    /// Polling task for fetching parsed tags from bridge
    private var pollingTask: Task<Void, Never>?

    /// Logger for AppState events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "AppState")

    /// Deduplication tracking for preventing rapid duplicate messages.
    ///
    /// Maps stream type (or "main" for non-streamed) to recent messages with timestamps.
    /// Matches Illthorn's 200ms deduplication window to catch server-side duplicates.
    ///
    /// ## Example
    /// ```swift
    /// recentMessages["speech"] = [
    ///     (text: "Speaking in Elven, Devo says...", timestamp: Date())
    /// ]
    /// ```
    private var recentMessages: [String: [(text: String, timestamp: Date)]] = [:]

    /// Deduplication time window in seconds (200ms = 0.2 seconds)
    private let deduplicationWindow: TimeInterval = 0.2

    /// Metadata tag names that should NOT appear in game log.
    ///
    /// These tags are dispatched as EventBus events for panels instead of being
    /// displayed in the main game log. The parser publishes these tags to EventBus
    /// (via XMLStreamParser.publishEventIfNeeded), and panels subscribe to the events.
    ///
    /// ## Tag Categories
    /// - **Hands**: left, right, spell
    /// - **Vitals**: progressBar (health, mana, stamina, etc.)
    /// - **Navigation**: nav, compass, streamWindow
    /// - **Dialog Data**: dialogData (spells, injuries from game dialogs)
    /// - **Stream Control**: pushStream, popStream, clearStream (routing directives)
    /// - **Formatting Control**: pushBold, popBold (no visible content)
    /// - **Stream Wrappers**: stream (synthetic wrapper tags created by parser)
    ///
    /// **Note**: `prompt` tags are NOT filtered as metadata - they appear in game log
    /// AND are published to PromptViewModel via EventBus for dedicated prompt display.
    ///
    /// ## Architecture Note
    /// This filtering happens at the session layer (AppState), matching illthorn's
    /// approach of separating metadata from content. ProfanityFE does the same by
    /// returning `nil` for these tags.
    private let metadataTagNames: Set<String> = [
        // Hands panel metadata
        "left",
        "right",
        "spell",

        // Vitals panel metadata
        "progressBar",

        // Navigation panel metadata
        "nav",
        "compass",
        "streamWindow",

        // Dialog data (spells panel, injuries panel)
        "dialogData",

        // Stream control directives (not visible content)
        "pushStream",
        "popStream",
        "clearStream",

        // Formatting control tags (no visible content - control rendering only)
        "pushBold",       // Bold formatting start (no text)
        "popBold"         // Bold formatting end (no text)

        // NOTE: "stream" wrapper tags are NOT filtered as metadata
        // Instead, we filter specific stream types by their "id" attribute
        // This allows us to selectively show/hide streams based on panel availability
        //
        // NOTE: "prompt" tags are NOT filtered as metadata (as of Issue #142)
        // Prompts now appear in game log to provide visual feedback like traditional MUD clients
        // PromptViewModel still receives prompt events via EventBus for dedicated prompt display
    ]

    // MARK: - Initialization

    /// Creates a new AppState with all dependencies initialized.
    public init() {
        // Initialize actor-based components
        self.connection = LichConnection()

        // Initialize shared EventBus FIRST (parser needs it)
        self.eventBus = EventBus()

        // Initialize stream buffer manager for stream content routing
        self.streamBufferManager = StreamBufferManager()

        // Initialize stream router for routing logic
        self.streamRouter = StreamRouter(bufferManager: streamBufferManager)

        #if canImport(VaalinParser)
        // Pass eventBus to parser so it can publish metadata events
        self.parser = XMLStreamParser(eventBus: eventBus)
        #else
        // For testing without VaalinParser module
        fatalError("VaalinParser module required")
        #endif

        self.bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Initialize command history (500 command buffer)
        self.commandHistory = CommandHistory(maxSize: 500)

        // Initialize view models on main thread
        self.gameLogViewModel = GameLogViewModel()
        self.commandInputViewModel = CommandInputViewModel(
            commandHistory: commandHistory,
            gameLogViewModel: gameLogViewModel,
            settings: .makeDefault(),
            connection: connection
        )

        // Initialize panel view models with EventBus subscriptions
        self.handsPanelViewModel = HandsPanelViewModel(eventBus: eventBus)
        self.vitalsPanelViewModel = VitalsPanelViewModel(eventBus: eventBus)
        self.compassPanelViewModel = CompassPanelViewModel(eventBus: eventBus)
        self.injuriesPanelViewModel = InjuriesPanelViewModel(eventBus: eventBus)
        self.spellsPanelViewModel = SpellsPanelViewModel(eventBus: eventBus)

        // Initialize prompt view model with EventBus subscription
        self.promptViewModel = PromptViewModel(eventBus: eventBus)
    }

    // MARK: - Connection Lifecycle

    /// Connect to Lich detachable client and start data flow.
    ///
    /// Establishes TCP connection, starts the bridge data flow, and begins polling
    /// for parsed tags. Updates `isConnected` state on success.
    ///
    /// - Throws: LichConnectionError if connection fails
    ///
    /// ## Performance
    /// - **Connection timeout**: 10 seconds
    /// - **First data**: Typically < 100ms after connection
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await appState.connect()
    ///     // Connection successful, UI auto-updates via @Observable
    /// } catch {
    ///     // Show error to user
    ///     print("Connection failed: \(error.localizedDescription)")
    /// }
    /// ```
    public func connect() async throws {
        // Connect to Lich
        try await connection.connect(host: host, port: port, autoReconnect: false)

        // Set up debug interceptor for debug console window
        await connection.setDebugInterceptor(DebugWindowManager.shared)

        // Start bridge data flow
        await bridge.start()

        // Set up EventBus subscriptions for panels and prompt
        await handsPanelViewModel.setup()
        await vitalsPanelViewModel.setup()
        await compassPanelViewModel.setup()
        await injuriesPanelViewModel.setup()
        await spellsPanelViewModel.setup()
        await promptViewModel.setup()

        // Update state
        isConnected = true

        // Start polling for tags
        startPolling()
    }

    /// Disconnect from Lich and stop data flow.
    ///
    /// Stops polling, halts bridge data flow, and closes the TCP connection.
    /// Updates `isConnected` state. This method is safe to call multiple times.
    ///
    /// ## Example
    /// ```swift
    /// await appState.disconnect()
    /// // Connection closed, UI auto-updates via @Observable
    /// ```
    public func disconnect() async {
        // Stop polling first
        stopPolling()

        // Stop bridge data flow
        await bridge.stop()

        // Disconnect from Lich
        await connection.disconnect()

        // Update state
        isConnected = false
    }

    // MARK: - Command Sending

    /// Sends a command to the game server via the Lich connection.
    ///
    /// Commands are sent as UTF-8 encoded strings followed by a newline character.
    /// This method should be called from the command input submit handler.
    ///
    /// - Parameter command: The command string to send (without trailing newline)
    ///
    /// ## Example
    /// ```swift
    /// CommandInputView(viewModel: appState.commandInputViewModel) { command in
    ///     await appState.sendCommand(command)
    /// }
    /// ```
    public func sendCommand(_ command: String) async {
        // Send command via connection (LichConnection handles newline encoding)
        do {
            try await connection.send(command: command)
        } catch {
            logger.error("Failed to send command: \(error.localizedDescription)")
        }
    }

    // MARK: - Stream Buffer Management

    /// Gets messages for a specific stream buffer.
    ///
    /// Returns messages from the specified stream's circular buffer in chronological order.
    /// Useful for displaying stream-specific content in dedicated panels.
    ///
    /// - Parameter streamId: The stream identifier (e.g., "thoughts", "speech", "combat")
    /// - Returns: Array of messages for the specified stream
    ///
    /// ## Example
    /// ```swift
    /// let thoughtMessages = await appState.streamMessages(forStream: "thoughts")
    /// for message in thoughtMessages {
    ///     print(message.attributedText)
    /// }
    /// ```
    public func streamMessages(forStream streamId: String) async -> [Message] {
        return await streamBufferManager.messages(forStream: streamId)
    }

    /// Gets the unread message count for a specific stream.
    ///
    /// Returns the number of messages added to the stream since it was last viewed.
    ///
    /// - Parameter streamId: The stream identifier
    /// - Returns: Number of unread messages (0 if stream doesn't exist)
    ///
    /// ## Example
    /// ```swift
    /// let unread = await appState.streamUnreadCount(forStream: "thoughts")
    /// if unread > 0 {
    ///     print("You have \(unread) unread thoughts")
    /// }
    /// ```
    public func streamUnreadCount(forStream streamId: String) async -> Int {
        return await streamBufferManager.unreadCount(forStream: streamId)
    }

    /// Clears the unread count for a specific stream.
    ///
    /// Typically called when the user views the stream's content.
    ///
    /// - Parameter streamId: The stream identifier
    ///
    /// ## Example
    /// ```swift
    /// // User viewed thoughts stream
    /// await appState.clearStreamUnreadCount(forStream: "thoughts")
    /// ```
    public func clearStreamUnreadCount(forStream streamId: String) async {
        await streamBufferManager.clearUnreadCount(forStream: streamId)
    }

    /// Toggles mirror mode for stream content.
    ///
    /// When mirror mode is ON (default), stream content appears in both the stream buffer
    /// and the main game log. When OFF, stream content only appears in stream buffers.
    ///
    /// - Parameter enabled: true to enable mirror mode, false to disable
    ///
    /// ## Example
    /// ```swift
    /// // Disable mirror mode - streams only in buffers
    /// appState.setMirrorMode(false)
    ///
    /// // Re-enable mirror mode - streams in both places
    /// appState.setMirrorMode(true)
    /// ```
    public func setMirrorMode(_ enabled: Bool) {
        settings.streams.mirrorFilteredToMain = enabled
        logger.info("Mirror mode \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Polling Implementation

    /// Start polling bridge for parsed tags.
    ///
    /// Creates a task that fetches tags from the bridge every 100ms and appends them
    /// to the game log view model as a single batch. Tags from one polling cycle are
    /// rendered together with one timestamp, matching ProfanityFE and Illthorn behavior.
    /// The task runs until cancelled by `stopPolling()`.
    ///
    /// ## Threading
    /// Polling task runs on MainActor to ensure thread-safe access to GameLogViewModel.
    /// Bridge calls are async actor-isolated methods.
    ///
    /// ## Performance
    /// - **Interval**: 100ms (10 updates/second)
    /// - **Overhead**: < 1ms per empty poll
    /// - **Batch processing**: < 5ms per 100 tags (rendered as one message)
    private func startPolling() {
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                // Fetch tags from bridge (async actor call)
                let tags = await bridge.getParsedTags()

                // DEBUG: Log tag processing (temporary - remove after verification)
                logFetchedTags(tags)

                // STREAM ROUTING: Route stream wrapper tags to StreamBufferManager
                // Returns tags for main log (streams unwrapped if mirror ON, excluded if mirror OFF)
                let routedTags = await routeStreamTags(tags)

                // Filter out metadata tags before sending to game log
                // Metadata tags are already dispatched to panels via EventBus by the parser,
                // so they should NOT appear in the game log (they have no visible content)
                let contentTags = filterContentTags(routedTags)

                // DEBUG: Log filtering results (temporary - remove after verification)
                logFilteringResults(tags: tags, contentTags: contentTags)

                // Filter out whitespace-only tags (prevents blank lines from server newlines)
                // Server sends newlines between tags like: <prompt>s></prompt>\n\n<component>...
                // These become :text nodes with only whitespace, creating unwanted blank lines
                let nonEmptyTags = contentTags.filter { hasContent($0) }

                // Check for duplicates before rendering (200ms deduplication window)
                // This catches server-side duplicates that slip through filtering
                if !nonEmptyTags.isEmpty {
                    if isDuplicate(nonEmptyTags) {
                        logger.debug("🔄 Deduplication: Skipping duplicate content")
                    } else {
                        // Process ONLY content tags - render entire batch as ONE message
                        // This matches illthorn's approach: contentTags = parsed.filter(!metadata)
                        // and ProfanityFE's approach: metadata tags return nil
                        // appendMessage() renders all tags together with one timestamp
                        // This matches ProfanityFE's approach of batching text between XML tags
                        await gameLogViewModel.appendMessage(nonEmptyTags)
                    }
                }

                // Clear ALL tags from bridge (both metadata and content have been processed)
                // Metadata was published to EventBus by parser, content was sent to game log
                if !tags.isEmpty {
                    await bridge.clearParsedTags()
                }

                // Sleep for 100ms before next poll
                // Using try? to ignore cancellation errors (task cleanup is graceful)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    /// Stop polling for parsed tags.
    ///
    /// Cancels the polling task if running. Safe to call multiple times.
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Log fetched tags for debugging (temporary - remove after verification)
    private func logFetchedTags(_ tags: [GameTag]) {
        guard !tags.isEmpty else { return }

        logger.debug("📦 Polling: Fetched \(tags.count) tags from bridge")

        // VERBOSE: Log EVERY tag with streamId to diagnose duplicates
        for tag in tags {
            let preview = tag.text?.prefix(50) ?? "(no text)"
            let stream = tag.streamId ?? "nil"
            logger.debug("""
              📝 Tag: name=\(tag.name, privacy: .public), streamId=\(stream, privacy: .public), \
              text=\(preview, privacy: .public)
              """)
        }
    }

    /// Log filtering results for debugging (temporary - remove after verification)
    private func logFilteringResults(tags: [GameTag], contentTags: [GameTag]) {
        guard !tags.isEmpty else { return }

        let filteredCount = tags.count - contentTags.count
        if filteredCount > 0 {
            let metadataIDs = extractMetadataIDs(tags)
            let excludedStreams: Set<String> = [
                "room", "roomName", "roomDesc", "room objs", "room players", "room exits"
            ]

            // Separate metadata vs stream filtering
            let metadataNames = tags
                .filter { metadataIDs.contains($0.id) }
                .map { $0.name }
            let streamTags = tags
                .filter { tag in
                    tag.streamId != nil &&
                    excludedStreams.contains(tag.streamId!) &&
                    !metadataIDs.contains(tag.id)
                }
                .map { tag in
                    "\(tag.name)[stream:\(tag.streamId ?? "nil")]"
                }

            logger.debug("🔍 Filtering: Removed \(filteredCount) tags")
            if !metadataNames.isEmpty {
                let list = metadataNames.joined(separator: ", ")
                logger.debug("  - Metadata (\(metadataNames.count)): \(list)")
            }
            if !streamTags.isEmpty {
                let list = streamTags.joined(separator: ", ")
                logger.debug("  - Streams (\(streamTags.count)): \(list)")
            }
        }
        logger.debug("✅ Content: Passing \(contentTags.count) tags to game log")
    }

    // MARK: - Deduplication

    /// Extracts text content from tags for deduplication comparison.
    ///
    /// Recursively traverses tag tree to build complete text representation.
    /// This matches Illthorn's approach of comparing full text content.
    ///
    /// - Parameter tags: Tags to extract text from
    /// - Returns: Combined text content (trimmed)
    private func extractTextContent(_ tags: [GameTag]) -> String {
        var text = ""
        for tag in tags {
            if let tagText = tag.text {
                text += tagText
            }
            if !tag.children.isEmpty {
                text += extractTextContent(tag.children)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if tags are duplicate of recent message.
    ///
    /// Implements 200ms deduplication window matching Illthorn's approach.
    /// Checks recent messages for the same stream type (or "main" for non-streamed).
    ///
    /// - Parameter tags: Tags to check for duplicates
    /// - Returns: True if duplicate found within 200ms window
    private func isDuplicate(_ tags: [GameTag]) -> Bool {
        guard !tags.isEmpty else { return false }

        // Extract text content
        let textContent = extractTextContent(tags)
        guard !textContent.isEmpty else { return false }

        // Determine stream type (use first tag's streamId or "main")
        let streamType = tags.first?.streamId ?? "main"

        // Get recent messages for this stream type
        let now = Date()
        var recentForType = recentMessages[streamType] ?? []

        // Clean up old messages outside deduplication window
        recentForType = recentForType.filter { message in
            now.timeIntervalSince(message.timestamp) <= deduplicationWindow
        }

        // Check if this text already exists in recent messages
        let isDuplicate = recentForType.contains { message in
            message.text == textContent
        }

        // If not duplicate, add to recent messages
        if !isDuplicate {
            recentForType.append((text: textContent, timestamp: now))
            recentMessages[streamType] = recentForType
        }

        return isDuplicate
    }

    // MARK: - Tag Filtering

    /// Recursively checks if a tag has any meaningful content.
    ///
    /// This mirrors `GameLogViewModel.hasContentRecursive()` to filter whitespace-only
    /// tags at the session layer (AppState) instead of waiting for the view layer.
    /// Prevents blank lines from server-sent newlines between XML tags.
    ///
    /// ## Whitespace Sources
    ///
    /// Server sends newlines between tags:
    /// ```xml
    /// <prompt>s></prompt>
    /// \n\n
    /// <component id='room objs'>...</component>
    /// ```
    ///
    /// These newlines become `:text` nodes with `text = "\n\n"`. When batched with
    /// content tags, they render as blank lines unless filtered here.
    ///
    /// - Parameter tag: GameTag to check for content
    /// - Returns: True if tag has non-whitespace text content, false otherwise
    ///
    /// ## Example
    /// ```swift
    /// hasContent(GameTag(name: ":text", text: "\n"))       // true (structural newline preserved)
    /// hasContent(GameTag(name: ":text", text: "\n\n"))     // true (multiple newlines kept - trimmed later)
    /// hasContent(GameTag(name: "prompt", text: "s>"))      // true
    /// hasContent(GameTag(name: ":text", text: "   "))      // false (spaces/tabs filtered)
    /// ```
    private func hasContent(_ tag: GameTag) -> Bool {
        // Check direct text content
        if let text = tag.text {
            // Only trim spaces/tabs, NOT newlines
            // Single newlines (\n) between tags provide structural separation
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return true  // Found content (including structural newlines)
            }
        }

        // No direct text - check children recursively
        return tag.children.contains { hasContent($0) }
    }

    /// Recursively extracts metadata tag IDs from tag tree.
    ///
    /// This helper traverses the entire tag tree (including nested children) and
    /// collects IDs of all tags whose names match metadata tag names. This ensures
    /// nested metadata tags (e.g., `<output><prompt/></output>`) are properly identified.
    ///
    /// Matches illthorn's recursive extraction approach:
    /// ```typescript
    /// extractMetadata(tags: Array<GameTag>): Array<GameTag> {
    ///   const metadata: Array<GameTag> = [];
    ///   for (const tag of tags) {
    ///     if (tag.kind === TagKind.METADATA) {
    ///       metadata.push(tag);
    ///     }
    ///     metadata.push(...this.extractMetadata(tag.children));  // ← Recurse
    ///   }
    ///   return metadata;
    /// }
    /// ```
    ///
    /// ## Example
    /// ```swift
    /// let tags = [
    ///     GameTag(name: "output", children: [
    ///         GameTag(name: "progressBar", ...),  // ← Nested metadata
    ///         GameTag(name: ":text", ...)
    ///     ])
    /// ]
    /// let metadataIDs = extractMetadataIDs(tags)
    /// // Result: Set containing progressBar tag's ID (not output or :text)
    /// ```
    ///
    /// - Parameter tags: Tags to extract metadata from
    /// - Returns: Set of UUIDs for all metadata tags (including nested)
    private func extractMetadataIDs(_ tags: [GameTag]) -> Set<UUID> {
        var metadataIDs = Set<UUID>()

        for tag in tags {
            // Check if this tag is metadata
            if metadataTagNames.contains(tag.name) {
                metadataIDs.insert(tag.id)
            }

            // Recursively extract from children
            metadataIDs.formUnion(extractMetadataIDs(tag.children))
        }

        return metadataIDs
    }

    /// Filters out metadata tags and stream content that belong in dedicated panels.
    ///
    /// This implements selective stream filtering to prevent duplicates while showing appropriate content:
    /// 1. **Metadata filtering**: Removes metadata tags (progressBar, left, right, pushBold, etc.)
    /// 2. **Selective stream filtering**: Filters specific stream types by their "id" attribute
    ///
    /// ## Stream Wrapper Architecture (Duplicate Fix)
    ///
    /// The parser wraps stream content in synthetic `stream` tags (like Illthorn):
    /// ```swift
    /// // <pushStream id="speech">Speaking in Elven...<popStream>
    /// // Becomes:
    /// GameTag(name: "stream", attrs: ["id": "speech"], children: [
    ///     GameTag(name: "preset", text: "Speaking in Elven...", ...)
    /// ])
    /// ```
    ///
    /// ## Selective Filtering Strategy
    ///
    /// We filter `stream` wrapper tags by checking their `attrs["id"]`:
    /// - **Filtered streams** (go to dedicated panels when implemented):
    ///   - Communication: `speech`, `thoughts`, `logon`, `logoff`, `death`, `arrivals`
    ///   - Room: `room`, `roomName`, `roomDesc`, `room objs`, `room players`, `room exits`
    /// - **Passed-through streams** (show in main log):
    ///   - Combat, general output, and any other stream types
    ///
    /// This prevents duplicates because:
    /// 1. Content is wrapped ONCE in a parent stream tag
    /// 2. We filter the entire parent tag (removing all children at once)
    /// 3. Server can't send the same content twice in different contexts
    ///
    /// ## Three-Layer Defense
    ///
    /// 1. **Parser layer**: Wraps streams in `stream` tags, publishes metadata events
    /// 2. **Session layer** (THIS METHOD): Filters metadata and excluded streams
    /// 3. **View layer**: GameLogViewModel.hasContentRecursive() catches remaining empty tags
    ///
    /// ## Example
    /// ```swift
    /// let tags = [
    ///     GameTag(name: "stream", attrs: ["id": "speech"], ...),    // ← Filtered OUT (excluded stream)
    ///     GameTag(name: "stream", attrs: ["id": "combat"], ...),    // ← Pass THROUGH (not excluded)
    ///     GameTag(name: "output", streamId: nil, ...),              // ← Pass THROUGH (main content)
    ///     GameTag(name: "progressBar", ...)                         // ← Filtered OUT (metadata)
    /// ]
    /// let contentTags = filterContentTags(tags)
    /// // Result: [stream(combat), output(nil)]
    /// ```
    ///
    /// - Parameter tags: All tags from parser (metadata + content + streams)
    /// - Returns: Only content tags for game log display
    private func filterContentTags(_ tags: [GameTag]) -> [GameTag] {
        // Extract all metadata IDs (including nested)
        let metadataIDs = extractMetadataIDs(tags)

        // Define streams that should be filtered out (go to dedicated panels)
        // These are stream wrapper tags with specific "id" attributes
        let excludedStreamIDs: Set<String> = [
            // Communication streams (for future StreamsPanel)
            "speech",         // Speech content: "Devo says..."
            "thoughts",       // Thought content: "You think..."
            "logon",          // Login messages
            "logoff",         // Logout messages
            "death",          // Death messages
            "arrivals",       // Arrival messages

            // Room streams (for future RoomPanel)
            "room",           // Room wrapper stream
            "roomName",       // Room title: "[Town Square, East - 229]"
            "roomDesc",       // Room description: "Here in the center..."
            "room objs",      // Room objects: "You also see..."
            "room players",   // Room players: "Also here: ..."
            "room exits"      // Room exits: "Obvious paths: ..."
        ]

        return tags.filter { tag in
            // Must NOT be metadata
            guard !metadataIDs.contains(tag.id) else { return false }

            // Special handling for stream wrapper tags
            if tag.name == "stream" {
                // Filter if this stream ID is in excluded list
                if let streamID = tag.attrs["id"] as? String {
                    return !excludedStreamIDs.contains(streamID)
                }
                // If no ID attribute, keep it (shouldn't happen but be safe)
                return true
            }

            // For non-stream tags, also filter by streamId
            if let streamId = tag.streamId {
                return !excludedStreamIDs.contains(streamId)
            }

            // Not metadata, not excluded stream - pass through
            return true
        }
    }

    // MARK: - Stream Routing

    /// Routes stream wrapper tags to StreamBufferManager and returns tags for main game log.
    ///
    /// Uses StreamRouter actor to route stream content to buffers and determine what should
    /// appear in the main game log based on mirror mode setting.
    ///
    /// ## Stream Wrapper Architecture
    ///
    /// Parser wraps stream content in synthetic `stream` tags:
    /// ```swift
    /// // Server: <pushStream id="thoughts">You ponder...<popStream>
    /// // Parser creates:
    /// GameTag(name: "stream", attrs: ["id": "thoughts"], children: [...])
    /// ```
    ///
    /// ## Mirror Mode
    ///
    /// - **ON (default)**: Stream content goes to BOTH stream buffer AND main game log (unwrapped)
    /// - **OFF**: Stream content goes ONLY to stream buffer (filtered from main log)
    ///
    /// ## Performance
    ///
    /// - **Per stream tag**: < 2ms (render + routing operations)
    /// - **Typical case**: 0-2 stream tags per polling cycle
    ///
    /// - Parameter tags: All tags from parser (includes stream wrappers)
    /// - Returns: Tags that should appear in main game log (streams unwrapped if mirror ON)
    private func routeStreamTags(_ tags: [GameTag]) async -> [GameTag] {
        // Use StreamRouter to route tags and get main log tags based on mirror mode
        let mainLogTags = await streamRouter.route(
            tags,
            mirrorMode: settings.streams.mirrorFilteredToMain
        )

        logger.debug("📨 Routed streams (mirror: \(self.settings.streams.mirrorFilteredToMain))")
        return mainLogTags
    }
}
