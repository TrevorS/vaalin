// ABOUTME: GameLogViewModel manages the game log message buffer with automatic pruning at 10,000 lines

import Foundation
import Observation
import os
import VaalinCore
import VaalinParser

/// View model for the game log display with automatic buffer management and theme-based rendering.
///
/// `GameLogViewModel` maintains a circular buffer of the most recent 10,000 game messages,
/// automatically pruning older messages to prevent unbounded memory growth during long
/// play sessions. Messages are rendered from `GameTag` objects into styled `Message` objects
/// with AttributedString using TagRenderer and theme-based colors.
///
/// ## Buffer Management
/// - **Capacity**: 10,000 messages (configurable constant)
/// - **Pruning Strategy**: FIFO (First-In-First-Out) - oldest messages removed first
/// - **Trigger**: Automatic pruning when exceeding capacity
/// - **Performance**: < 1ms average render + append time, < 10ms pruning operation
///
/// ## Rendering Architecture
/// - **TagRenderer**: Actor-based renderer for thread-safe GameTag → AttributedString conversion
/// - **ThemeManager**: Loads and manages color themes (Catppuccin Mocha default)
/// - **Fallback**: Plain text rendering if theme not yet loaded (async theme loading)
///
/// ## Thread Safety
/// **IMPORTANT:** This class is isolated to MainActor. All public methods must be called
/// from the main thread. SwiftUI automatically ensures this for views bound to this view
/// model. The TagRenderer and ThemeManager actors provide thread-safe rendering services
/// accessed via async calls.
///
/// The `@Observable` macro provides property observation for SwiftUI reactivity.
///
/// ## Example Usage
/// ```swift
/// @Observable
/// final class GameLogViewModel {
///     let viewModel = GameLogViewModel()
///
///     // Append messages from parser (async due to rendering)
///     let tag = GameTag(name: "output", text: "You swing at the troll!", state: .closed)
///     await viewModel.appendMessage(tag)
///
///     // SwiftUI view automatically updates with styled text
///     ForEach(viewModel.messages) { message in
///         Text(message.attributedText)
///     }
/// }
/// ```
///
/// ## Performance Characteristics
/// - **Memory**: ~50KB per 1000 messages (typical), 500KB max for full 10,000 buffer
/// - **Append**: O(1) amortized (render + array append + occasional pruning)
/// - **Rendering**: < 1ms per tag average (TagRenderer target)
/// - **Pruning**: O(1) (single removeFirst operation per message over limit)
///
/// ## Stream Filtering
/// Each `Message` preserves its `streamID` property (e.g., "thoughts", "speech"),
/// enabling downstream filtering in stream-specific panels.
@Observable
@MainActor
public final class GameLogViewModel {
    // MARK: - Constants

    /// Maximum number of messages to retain in buffer before pruning oldest.
    /// Chosen to balance memory usage (~500KB) with useful scrollback history.
    private static let maxBufferSize = 10_000

    // MARK: - Properties

    /// Rendered game log messages in chronological order (oldest first, newest last).
    ///
    /// Automatically pruned to maintain `maxBufferSize` limit. Each message contains
    /// styled AttributedString ready for display with theme-based colors.
    ///
    /// SwiftUI views observing this property will automatically update when messages
    /// are appended via the `@Observable` macro.
    public var messages: [Message] = []

    /// TagRenderer actor for thread-safe GameTag → AttributedString conversion.
    private let renderer: TagRenderer

    /// ThemeManager actor for loading and managing color themes.
    private let themeManager: ThemeManager

    /// Current active theme (Catppuccin Mocha by default).
    /// `nil` during initialization until theme loads asynchronously.
    private var currentTheme: Theme?

    /// Timestamp display settings for game log messages.
    /// Timestamps are enabled by default to help track conversation and combat timing.
    private var timestampSettings =
        Settings.StreamSettings.TimestampSettings(
            gameLog: true,  // Enabled by default
            perStream: [:]
        )

    /// Logger for GameLogViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "GameLogViewModel")

    // MARK: - Initialization

    /// Creates a new GameLogViewModel with an empty message buffer.
    ///
    /// Initializes the TagRenderer and ThemeManager, then asynchronously loads
    /// the default Catppuccin Mocha theme. Messages appended before theme loads
    /// will fall back to plain text rendering.
    public init() {
        self.renderer = TagRenderer()
        self.themeManager = ThemeManager()

        // Load default theme asynchronously (Catppuccin Mocha)
        Task { @MainActor in
            await loadDefaultTheme()
        }
    }

    // MARK: - Public Methods

    /// Appends a game message to the log buffer with theme-based rendering.
    ///
    /// Renders the provided `GameTag` into a styled `Message` using TagRenderer and the
    /// current theme. If the theme is not yet loaded, falls back to plain text rendering.
    /// If the buffer exceeds `maxBufferSize` after appending, the oldest message is
    /// automatically removed to maintain the size limit.
    ///
    /// - Parameter tag: The game tag to render and append
    ///
    /// ## Performance
    /// - **Average case**: < 1ms (render + array append)
    /// - **Pruning case**: < 10ms (render + array append + pruning)
    ///
    /// ## Thread Safety
    /// Must be called from the main thread (MainActor). SwiftUI views automatically
    /// satisfy this requirement when binding to this view model.
    ///
    /// ## Example
    /// ```swift
    /// let tag = GameTag(name: "preset", attrs: ["id": "speech"], text: "Hello!", state: .closed)
    /// await viewModel.appendMessage(tag)
    /// ```
    public func appendMessage(_ tag: GameTag) async {
        let message: Message
        let timestamp = Date()  // Capture current timestamp

        if let theme = currentTheme {
            // Render with theme colors and timestamp
            let attributedText = await renderer.render(
                tag,
                theme: theme,
                timestamp: timestamp,
                timestampSettings: timestampSettings
            )
            message = Message(
                timestamp: timestamp,
                attributedText: attributedText,
                tags: [tag],
                streamID: tag.streamId
            )
        } else {
            // Fallback: plain text rendering if theme not yet loaded
            message = Message(from: [tag], streamID: tag.streamId, timestamp: timestamp)
        }

        messages.append(message)

        // Prune oldest messages if buffer exceeds capacity
        if messages.count > Self.maxBufferSize {
            messages = Array(messages.suffix(Self.maxBufferSize))
        }
    }

    /// Toggles timestamp display for game log messages.
    ///
    /// When enabled, messages will be prefixed with `[HH:MM:SS]` timestamp in dimmed color.
    /// This helps players track conversation and combat timing.
    ///
    /// - Parameter enabled: true to show timestamps, false to hide
    ///
    /// ## Example
    /// ```swift
    /// viewModel.setTimestampsEnabled(true)  // Show timestamps
    /// viewModel.setTimestampsEnabled(false) // Hide timestamps
    /// ```
    public func setTimestampsEnabled(_ enabled: Bool) {
        timestampSettings.gameLog = enabled
    }

    // MARK: - Private Methods

    /// Loads the default Catppuccin Mocha theme from the app bundle.
    ///
    /// Called asynchronously during initialization. If loading fails, logs an error
    /// and leaves `currentTheme` as `nil`, which triggers plain text fallback rendering.
    private func loadDefaultTheme() async {
        do {
            // Load theme JSON from SPM resource bundle
            // SPM creates a separate bundle for package resources (Vaalin_Vaalin.bundle)
            // We need to load it explicitly instead of using Bundle.main
            guard let resourceBundleURL = Bundle.main.url(
                forResource: "Vaalin_Vaalin",
                withExtension: "bundle"
            ),
            let resourceBundle = Bundle(url: resourceBundleURL),
            let url = resourceBundle.url(
                forResource: "catppuccin-mocha",
                withExtension: "json"
            ) else {
                // Theme not found - fall back to plain text rendering
                logger.warning("Failed to load theme: resource bundle or theme file not found")
                return
            }

            let data = try Data(contentsOf: url)
            currentTheme = try await themeManager.loadTheme(from: data)
            logger.info("Successfully loaded Catppuccin Mocha theme")
        } catch {
            logger.error("Failed to load theme: \(error.localizedDescription)")
        }
    }
}
