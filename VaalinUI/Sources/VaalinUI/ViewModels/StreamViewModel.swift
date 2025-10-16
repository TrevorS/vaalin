// ABOUTME: StreamViewModel manages filtered stream content display with styled rendering

import Foundation
import Observation
import os
import VaalinCore
import VaalinParser

/// View model for the stream content view with styled rendering and multi-stream merging.
///
/// `StreamViewModel` displays filtered content from one or more active stream buffers
/// (thoughts, speech, whispers, etc.) with full theme-based styling via TagRenderer.
/// Multiple active streams show a union of their content, merged chronologically.
///
/// ## Key Features
/// - **Styled Rendering**: Uses TagRenderer + ThemeManager for preset colors (NOT plain text)
/// - **Multi-Stream Merging**: Union of multiple active streams, sorted chronologically
/// - **Unread Tracking**: Clears unread counts when stream viewed
/// - **Performance**: Virtualized scrolling support for 10,000+ messages per stream
///
/// ## Architecture
///
/// ```
/// StreamViewModel
///    ├─ StreamBufferManager (content source)
///    ├─ TagRenderer (styled rendering)
///    ├─ ThemeManager (color themes)
///    └─ Active stream IDs (from StreamsBarViewModel)
/// ```
///
/// ## Rendering Fix (Issue #56)
///
/// **Problem**: StreamBufferManager stores Messages created with `Message(from:)` convenience
/// initializer which doesn't apply TagRenderer/theme colors.
///
/// **Solution**: StreamViewModel re-renders Messages using TagRenderer to apply styled
/// AttributedStrings with proper preset colors (speech=green, damage=red, etc.).
///
/// ## Usage
///
/// ```swift
/// let viewModel = StreamViewModel(
///     streamBufferManager: bufferManager,
///     activeStreamIDs: ["thoughts", "speech"]
/// )
///
/// // Load and render stream content
/// await viewModel.loadStreamContent()
///
/// // Display in StreamView
/// ForEach(viewModel.messages) { message in
///     Text(message.attributedText)
/// }
///
/// // Clear unread counts when view appears
/// await viewModel.clearUnreadCounts()
/// ```
///
/// ## Performance
/// - **Loading**: < 50ms for 10,000 messages from single stream
/// - **Merging**: < 100ms for 10,000 messages from 3 streams
/// - **Rendering**: < 1ms per message average (TagRenderer target)
/// - **Memory**: ~50KB per 1000 messages (typical)
@Observable
@MainActor
public final class StreamViewModel {
    // MARK: - Properties

    /// Rendered stream messages in chronological order (oldest first, newest last).
    ///
    /// Contains styled AttributedString with theme-based colors, re-rendered from
    /// StreamBufferManager content via TagRenderer.
    public var messages: [Message] = []

    /// Stream buffer manager for accessing stream content
    private let streamBufferManager: StreamBufferManager

    /// Active stream IDs to display (from StreamsBarViewModel)
    ///
    /// Mutable to allow updates via `updateActiveStreams()` which triggers content reload.
    private var activeStreamIDs: Set<String>

    /// TagRenderer actor for thread-safe GameTag → AttributedString conversion
    private let renderer: TagRenderer

    /// ThemeManager actor for loading and managing color themes
    private let themeManager: ThemeManager

    /// Current active theme (Catppuccin Mocha by default)
    private var currentTheme: Theme?

    /// Whether stream content is currently being loaded
    public var isLoading: Bool = false

    /// Whether the theme has finished loading
    ///
    /// Used to detect race conditions where loadStreamContent() is called before
    /// theme loads asynchronously. When theme finishes loading, content is automatically
    /// re-rendered with proper colors if activeStreams is not empty.
    private var isThemeReady: Bool = false

    /// Cache of rendered messages by their UUID ID
    ///
    /// Optimization to avoid re-rendering unchanged messages. Maps message ID to
    /// (AttributedString, theme hash) to detect when re-rendering is needed.
    /// Cleared when theme changes to force re-render with new colors.
    private var renderedMessageCache: [UUID: (attributed: AttributedString, themeHash: Int)] = [:]

    /// Current theme hash for cache invalidation
    ///
    /// When theme changes, we increment this to invalidate all cached renders,
    /// forcing re-rendering with new theme colors.
    private var currentThemeHash: Int = 0

    /// Logger for StreamViewModel events and errors
    private let logger = Logger(
        subsystem: "org.trevorstrieber.vaalin",
        category: "StreamViewModel"
    )

    // MARK: - Initialization

    /// Creates a new StreamViewModel for displaying filtered stream content.
    ///
    /// - Parameters:
    ///   - streamBufferManager: Stream buffer manager for content access
    ///   - activeStreamIDs: Set of stream IDs to display (empty = no streams)
    ///   - theme: Optional theme (defaults to Catppuccin Mocha if nil)
    public init(
        streamBufferManager: StreamBufferManager,
        activeStreamIDs: Set<String>,
        theme: Theme? = nil
    ) {
        self.streamBufferManager = streamBufferManager
        self.activeStreamIDs = activeStreamIDs
        self.renderer = TagRenderer()
        self.themeManager = ThemeManager()
        self.currentTheme = theme

        // Load default theme asynchronously if not provided
        if theme == nil {
            Task { @MainActor in
                await loadDefaultTheme()
            }
        }
    }

    // MARK: - Public Methods

    /// Loads and renders stream content from active stream buffers.
    ///
    /// Fetches messages from all active streams, merges them chronologically,
    /// and re-renders with TagRenderer to apply styled AttributedStrings with
    /// theme-based preset colors. Uses message cache to avoid re-rendering unchanged messages.
    ///
    /// ## Algorithm
    /// 1. Fetch messages from each active stream buffer
    /// 2. Merge all messages into single chronological array
    /// 3. For each message:
    ///    - Check cache for previously rendered version
    ///    - If cached and theme unchanged, use cached AttributedString
    ///    - Otherwise, render with TagRenderer + theme + cache result
    /// 4. Update `messages` property (triggers SwiftUI update)
    ///
    /// ## Performance
    /// - **Single stream**: < 50ms for 10,000 messages (first load)
    /// - **Multi-stream**: < 100ms for 10,000 messages across 3 streams (first load)
    /// - **Incremental updates**: < 5ms for 100 new messages (cached old messages skipped)
    ///
    /// ## Example
    /// ```swift
    /// await viewModel.loadStreamContent()
    /// // messages now contains styled content from active streams
    /// ```
    public func loadStreamContent() async {
        isLoading = true
        defer { isLoading = false }

        logger.debug("Loading content for streams: \(self.activeStreamIDs.joined(separator: ", "))")

        // Fetch messages from all active streams
        var allMessages: [Message] = []
        for streamID in activeStreamIDs {
            let streamMessages = await streamBufferManager.messages(forStream: streamID)
            allMessages.append(contentsOf: streamMessages)
        }

        // Sort merged messages chronologically (oldest first)
        allMessages.sort { $0.timestamp < $1.timestamp }

        // Re-render messages with TagRenderer, using cache to skip unchanged messages
        var styledMessages: [Message] = []

        for message in allMessages {
            if let theme = currentTheme {
                // Check cache for previously rendered version
                if let cached = renderedMessageCache[message.id],
                   cached.themeHash == currentThemeHash {
                    // Cache hit - reuse cached AttributedString
                    let cachedMessage = Message(
                        id: message.id,
                        timestamp: message.timestamp,
                        attributedText: cached.attributed,
                        tags: message.tags,
                        streamID: message.streamID
                    )
                    styledMessages.append(cachedMessage)
                } else {
                    // Cache miss - render with theme and cache result
                    let attributedText = await renderer.render(
                        message.tags,
                        theme: theme,
                        timestamp: message.timestamp,
                        timestampSettings: Settings.StreamSettings.TimestampSettings(
                            gameLog: false,  // Timestamps off by default
                            perStream: [:]
                        )
                    )

                    // Store in cache
                    renderedMessageCache[message.id] = (attributed: attributedText, themeHash: currentThemeHash)

                    let styledMessage = Message(
                        id: message.id,
                        timestamp: message.timestamp,
                        attributedText: attributedText,
                        tags: message.tags,
                        streamID: message.streamID
                    )
                    styledMessages.append(styledMessage)
                }
            } else {
                // Fallback: keep original message if theme not loaded yet
                styledMessages.append(message)
            }
        }

        // Update messages (triggers SwiftUI update)
        messages = styledMessages

        logger.debug(
            "Loaded \(styledMessages.count) messages from \(self.activeStreamIDs.count) stream(s)"
        )
    }

    /// Clears unread counts for all active streams.
    ///
    /// Call this when the StreamView appears to mark all displayed content as read.
    ///
    /// ## Example
    /// ```swift
    /// StreamView()
    ///     .onAppear {
    ///         await viewModel.clearUnreadCounts()
    ///     }
    /// ```
    public func clearUnreadCounts() async {
        for streamID in activeStreamIDs {
            await streamBufferManager.clearUnreadCount(forStream: streamID)
        }
        logger.debug("Cleared unread counts for \(self.activeStreamIDs.count) stream(s)")
    }

    /// Updates the active stream IDs and reloads content.
    ///
    /// Called when the user toggles streams in the filtering UI. Updates `activeStreamIDs` and
    /// automatically triggers content reload via `loadStreamContent()`.
    ///
    /// Safe to call repeatedly - if IDs haven't changed, no reload occurs (optimization).
    ///
    /// ## Example
    /// ```swift
    /// // User clicked "Thoughts" and "Speech" chips
    /// await viewModel.updateActiveStreams(["thoughts", "speech"])
    /// // Content automatically reloaded and messages updated
    /// ```
    ///
    /// - Parameter streamIDs: New set of stream IDs to display (empty = show nothing)
    public func updateActiveStreams(_ streamIDs: Set<String>) async {
        // Only reload if streams actually changed (optimization)
        guard streamIDs != activeStreamIDs else { return }

        activeStreamIDs = streamIDs
        logger.debug("Updated active streams to: \(streamIDs.joined(separator: ", "))")

        // Reload content with new streams
        await loadStreamContent()
    }

    /// Waits for the theme to finish loading.
    ///
    /// Use this method in previews or tests to ensure the theme is loaded before
    /// loading stream content.
    ///
    /// - Returns: When the theme has been loaded (or immediately if already loaded)
    public func waitForTheme() async {
        // Poll every 10ms until theme is loaded (max 1 second timeout)
        for _ in 0..<100 {
            if currentTheme != nil {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        logger.warning("Theme loading timeout after 1 second")
    }

    // MARK: - Private Methods

    /// Loads the default Catppuccin Mocha theme from the app bundle.
    ///
    /// Called asynchronously during initialization. Falls back to hardcoded theme
    /// if loading fails (common in previews). After theme loads successfully,
    /// automatically re-renders content if streams are active (race condition fix).
    private func loadDefaultTheme() async {
        do {
            // Try to load from SPM resource bundle
            guard let resourceBundleURL = Bundle.main.url(
                forResource: "Vaalin_Vaalin",
                withExtension: "bundle"
            ),
            let resourceBundle = Bundle(url: resourceBundleURL),
            let url = resourceBundle.url(
                forResource: "catppuccin-mocha",
                withExtension: "json"
            ) else {
                // Resource bundle not found (common in previews) - use hardcoded fallback
                logger.warning("Failed to load theme from bundle, using hardcoded fallback")
                currentTheme = Theme.catppuccinMocha()

                // Invalidate render cache since theme changed
                currentThemeHash += 1
                renderedMessageCache.removeAll()
                isThemeReady = true

                // If content was loaded before theme, re-render with theme now
                if !activeStreamIDs.isEmpty {
                    await reloadContentWithTheme()
                }
                return
            }

            let data = try Data(contentsOf: url)
            currentTheme = try await themeManager.loadTheme(from: data)
            logger.info("Successfully loaded Catppuccin Mocha theme for StreamView")

            // Invalidate render cache since theme changed
            currentThemeHash += 1
            renderedMessageCache.removeAll()
            isThemeReady = true

            // If content was loaded before theme finished, re-render with proper colors
            if !activeStreamIDs.isEmpty {
                await reloadContentWithTheme()
            }
        } catch {
            // Error loading from bundle - use hardcoded fallback
            logger.error(
                "Failed to load theme from bundle (\(error.localizedDescription)), using fallback"
            )
            currentTheme = Theme.catppuccinMocha()

            // Invalidate render cache since theme changed
            currentThemeHash += 1
            renderedMessageCache.removeAll()
            isThemeReady = true

            // Re-render content if needed
            if !activeStreamIDs.isEmpty {
                await reloadContentWithTheme()
            }
        }
    }

    /// Re-renders current content with theme (called when theme finishes loading).
    ///
    /// Used to fix race condition where content was loaded before theme was ready.
    /// Only re-renders if content exists and theme is now available.
    private func reloadContentWithTheme() async {
        guard !messages.isEmpty && currentTheme != nil else { return }

        logger.debug("🎨 Re-rendering content after theme loaded")

        // Re-render existing messages with theme
        var styledMessages: [Message] = []

        for message in messages {
            if let theme = currentTheme {
                let attributedText = await renderer.render(
                    message.tags,
                    theme: theme,
                    timestamp: message.timestamp,
                    timestampSettings: Settings.StreamSettings.TimestampSettings(
                        gameLog: false,
                        perStream: [:]
                    )
                )

                let styledMessage = Message(
                    timestamp: message.timestamp,
                    attributedText: attributedText,
                    tags: message.tags,
                    streamID: message.streamID
                )
                styledMessages.append(styledMessage)
            }
        }

        // Update messages with newly styled versions
        messages = styledMessages
    }
}
