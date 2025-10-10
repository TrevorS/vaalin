// ABOUTME: GameLogView displays the game log with virtualized scrolling and auto-scroll behavior

import SwiftUI
import VaalinCore

/// Displays the game log with auto-scrolling and connection status indicator.
///
/// `GameLogView` renders game messages from the parser as plain text (no ANSI styling yet - Issue #26).
/// It provides smooth auto-scrolling to new messages while preserving scroll position when the user
/// manually scrolls up to review history.
///
/// ## Performance Characteristics
/// - **Target**: 60fps scrolling with 10,000 message buffer
/// - **Optimization**: Uses `LazyVStack` for virtualized rendering (only visible rows loaded)
/// - **Auto-scroll**: Disabled when user manually scrolls up (100px threshold from bottom)
/// - **Memory**: Delegates buffer management to `GameLogViewModel` (auto-prunes at 10k messages)
///
/// ## Layout Structure
/// ```
/// VStack {
///   Connection Status (top)
///   ScrollView {
///     LazyVStack {
///       ForEach(messages) { message in
///         Text(extractedText)  // Plain text only (no ANSI colors yet)
///       }
///       Spacer(height: 0).id("bottom")  // Scroll anchor
///     }
///   }
/// }
/// ```
///
/// ## Auto-Scroll Behavior
/// - **Enabled**: When user is near bottom (within 100px) and new messages arrive
/// - **Disabled**: When user manually scrolls up to review history
/// - **Re-enabled**: Automatically when user scrolls back to bottom
///
/// ## Example Usage
/// ```swift
/// let viewModel = GameLogViewModel()
/// GameLogView(viewModel: viewModel, isConnected: true)
/// ```
public struct GameLogView: View {
    // MARK: - Properties

    /// View model providing game messages and buffer management.
    @Bindable public var viewModel: GameLogViewModel

    /// Connection status indicator (true = connected, false = disconnected).
    public var isConnected: Bool

    /// Tracks whether auto-scrolling is enabled (disabled when user scrolls up).
    @State private var shouldAutoScroll: Bool = true

    /// Current scroll content height (total height of all messages).
    /// Updated via GeometryReader on LazyVStack content.
    @State private var contentHeight: CGFloat = 0

    /// Current viewport height (visible ScrollView area).
    /// Updated via GeometryReader on ScrollView frame.
    @State private var viewportHeight: CGFloat = 0

    /// Current scroll offset (how far user has scrolled from top).
    /// Updated via preference key on scroll position changes.
    @State private var scrollOffset: CGFloat = 0

    // MARK: - Constants

    /// Distance from bottom (in points) to consider user "at bottom" for auto-scroll.
    /// Matches Illthorn's MIN_SCROLL_BUFFER constant for consistent UX.
    private static let autoScrollThreshold: CGFloat = 100

    // MARK: - Initializer

    public init(viewModel: GameLogViewModel, isConnected: Bool) {
        self.viewModel = viewModel
        self.isConnected = isConnected
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Connection status indicator
            connectionStatusBar

            // Main scrollable game log
            ScrollViewReader { scrollProxy in
                GeometryReader { viewportGeometry in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            // Performance: LazyVStack only renders visible rows
                            // Critical for 10,000 message buffer @ 60fps target
                            ForEach(viewModel.messages) { message in
                                messageRow(for: message)
                            }

                            // Scroll anchor - zero-height spacer at bottom
                            // Used by ScrollViewReader.scrollTo() for auto-scroll
                            Spacer(minLength: 0)
                                .frame(height: 0)
                                .id("bottom")
                        }
                        .padding(8)
                        .background(GeometryReader { contentGeometry in
                            // Capture content height (total height of all messages)
                            // Positioned inside LazyVStack to measure actual rendered content
                            Color.clear.preference(
                                key: ContentHeightPreferenceKey.self,
                                value: contentGeometry.size.height
                            )
                        })
                        .background(GeometryReader { scrollGeometry in
                            // Capture scroll offset (current scroll position)
                            // frame(in: .named("scrollView")) returns coordinates relative to ScrollView
                            // origin.y is negative when scrolled down (content moves up)
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: -scrollGeometry.frame(in: .named("scrollView")).minY
                            )
                        })
                    }
                    .coordinateSpace(name: "scrollView")
                    .onAppear {
                        // Capture viewport height when view appears
                        viewportHeight = viewportGeometry.size.height
                    }
                    .onChange(of: viewportGeometry.size.height) { _, newHeight in
                        // Update viewport height when window resizes
                        viewportHeight = newHeight
                    }
                    .onPreferenceChange(ContentHeightPreferenceKey.self) { newContentHeight in
                        // Update content height when messages are added/removed
                        contentHeight = newContentHeight
                        updateAutoScrollState()
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { newScrollOffset in
                        // Update scroll offset when user scrolls
                        scrollOffset = newScrollOffset
                        updateAutoScrollState()
                    }
                    .onChange(of: viewModel.messages.count) { _, newCount in
                        // New messages arrived - auto-scroll if enabled
                        if shouldAutoScroll && newCount > 0 {
                            // Performance: withAnimation(nil) = instant scroll (no 60fps animation overhead)
                            // Critical for rapid message arrival (combat spam, etc.)
                            withAnimation(nil) {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Auto-Scroll Logic

    /// Updates auto-scroll state based on current scroll position.
    ///
    /// Determines if user is "at bottom" by comparing scroll position to content height.
    /// Matches Illthorn's auto-scroll logic:
    /// ```
    /// isAtBottom = scrollOffset + viewportHeight >= contentHeight - threshold
    /// ```
    ///
    /// **Behavior:**
    /// - **At bottom** (within 100px threshold): `shouldAutoScroll = true`
    /// - **Scrolled up** (beyond threshold): `shouldAutoScroll = false`
    ///
    /// **Edge cases:**
    /// - Content shorter than viewport: Always at bottom (auto-scroll enabled)
    /// - Zero dimensions during initial layout: No-op (preserves initial state)
    private func updateAutoScrollState() {
        // Guard against invalid dimensions during initial layout
        guard contentHeight > 0, viewportHeight > 0 else { return }

        // Calculate distance from bottom
        // scrollOffset = how far scrolled from top (0 = top, max = bottom)
        // viewportHeight = visible area height
        // contentHeight = total content height
        // distanceFromBottom = how many points below current viewport bottom to actual content bottom
        let distanceFromBottom = contentHeight - (scrollOffset + viewportHeight)

        // User is "at bottom" if within threshold (100px)
        // Threshold accounts for rounding errors and provides smooth UX (no flickering on/off)
        let isAtBottom = distanceFromBottom <= Self.autoScrollThreshold

        // Update auto-scroll state
        // Only modify if state actually changed (avoids unnecessary view updates)
        if shouldAutoScroll != isAtBottom {
            shouldAutoScroll = isAtBottom
        }
    }

    // MARK: - Subviews

    /// Connection status bar at top of view.
    private var connectionStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .accessibilityLabel(isConnected ? "Connected to server" : "Disconnected from server")
                .accessibilityAddTraits(.isStaticText)

            Text(isConnected ? "Connected" : "Disconnected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    /// Renders a single message row from a Message.
    ///
    /// Displays the pre-rendered AttributedString with theme-based colors and formatting.
    /// Uses monospaced font for proper MUD text alignment.
    ///
    /// - Parameter message: Message to render
    /// - Returns: Text view with styled content
    private func messageRow(for message: Message) -> some View {
        Text(message.attributedText)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled) // Allow text selection for copy/paste
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preference Keys

/// Preference key for tracking scroll view offset.
///
/// Used to detect when user manually scrolls up (disables auto-scroll)
/// versus programmatic scroll to bottom (maintains auto-scroll).
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Preference key for tracking total content height.
///
/// Used to determine if user is at bottom of scroll view for auto-scroll logic.
/// Measures the height of LazyVStack content (all rendered messages).
private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
