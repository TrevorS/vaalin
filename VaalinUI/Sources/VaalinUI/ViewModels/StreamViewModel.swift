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
    private let activeStreamIDs: Set<String>

    /// TagRenderer actor for thread-safe GameTag → AttributedString conversion
    private let renderer: TagRenderer

    /// ThemeManager actor for loading and managing color themes
    private let themeManager: ThemeManager

    /// Current active theme (Catppuccin Mocha by default)
    private var currentTheme: Theme?

    /// Whether stream content is currently being loaded
    public var isLoading: Bool = false

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
    /// theme-based preset colors.
    ///
    /// ## Algorithm
    /// 1. Fetch messages from each active stream buffer
    /// 2. Merge all messages into single chronological array
    /// 3. Re-render each message with TagRenderer + theme
    /// 4. Update `messages` property (triggers SwiftUI update)
    ///
    /// ## Performance
    /// - **Single stream**: < 50ms for 10,000 messages
    /// - **Multi-stream**: < 100ms for 10,000 messages across 3 streams
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

        // Re-render messages with TagRenderer for styled AttributedStrings
        // This fixes the plain text issue from Message(from:) convenience initializer
        var styledMessages: [Message] = []

        for message in allMessages {
            if let theme = currentTheme {
                // Re-render with theme colors and timestamp
                let attributedText = await renderer.render(
                    message.tags,
                    theme: theme,
                    timestamp: message.timestamp,
                    timestampSettings: Settings.StreamSettings.TimestampSettings(
                        gameLog: false,  // Timestamps off by default
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
    /// if loading fails (common in previews).
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
                return
            }

            let data = try Data(contentsOf: url)
            currentTheme = try await themeManager.loadTheme(from: data)
            logger.info("Successfully loaded Catppuccin Mocha theme for StreamView")
        } catch {
            // Error loading from bundle - use hardcoded fallback
            logger.error(
                "Failed to load theme from bundle (\(error.localizedDescription)), using fallback"
            )
            currentTheme = Theme.catppuccinMocha()
        }
    }
}
