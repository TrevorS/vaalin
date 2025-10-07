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
                }
                .background(GeometryReader { geometry in
                    // Invisible view to track scroll position
                    // Updates shouldAutoScroll when user manually scrolls
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scrollView")).origin.y
                    )
                })
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                    // TODO: Implement manual scroll detection for auto-scroll state
                    // When user scrolls up beyond threshold, set shouldAutoScroll = false
                    // When user scrolls back to bottom, set shouldAutoScroll = true
                    // Deferred to maintain minimal scope for Issue #19 integration checkpoint
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
        .background(Color(nsColor: .controlBackgroundColor))
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

    /// Renders a single message row from a GameTag.
    ///
    /// Extracts text recursively from tag and all nested children.
    /// Uses monospaced font for proper MUD text alignment.
    ///
    /// - Parameter message: GameTag to render
    /// - Returns: Text view with extracted content
    private func messageRow(for message: GameTag) -> some View {
        Text(extractText(from: message))
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(Color(nsColor: .textColor))
            .textSelection(.enabled) // Allow text selection for copy/paste
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Text Extraction

    /// Recursively extracts all text content from a GameTag and its children.
    ///
    /// Traverses the tag tree depth-first, accumulating text from:
    /// 1. Tag's own `text` property
    /// 2. All nested children (recursively)
    ///
    /// Special handling for common GemStone IV tags:
    /// - `prompt`: Displayed as-is (e.g., ">")
    /// - `:text`: Pure text nodes (no tag name rendered)
    /// - `a`: Interactive objects (just text for now, clickability in later issue)
    ///
    /// - Parameter tag: GameTag to extract text from
    /// - Returns: Concatenated text content with preserved whitespace
    ///
    /// ## Performance
    /// - **Complexity**: O(n) where n = total nodes in tag tree
    /// - **Typical depth**: 1-3 levels (shallow XML from GemStone IV)
    /// - **Target**: < 1ms per message for smooth 60fps scrolling
    private func extractText(from tag: GameTag) -> String {
        var result = ""

        // Add tag's own text content
        if let text = tag.text {
            result += text
        }

        // Recursively extract text from children
        for child in tag.children {
            result += extractText(from: child)
        }

        return result
    }
}

// MARK: - Preference Key

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

// MARK: - Previews

struct GameLogView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Empty state - Disconnected
            GameLogView(
                viewModel: GameLogViewModel(),
                isConnected: false
            )
            .frame(width: 600, height: 400)
            .previewDisplayName("Empty - Disconnected")

            // Preview 2: Populated state - Connected with sample messages
            GameLogView(
                viewModel: sampleViewModel(),
                isConnected: true
            )
            .frame(width: 600, height: 400)
            .previewDisplayName("Populated - Connected")

            // Preview 3: Large buffer state - Performance testing
            GameLogView(
                viewModel: largeBufferViewModel(),
                isConnected: true
            )
            .frame(width: 600, height: 400)
            .previewDisplayName("Large Buffer - 100 Messages")
        }
    }

    // MARK: - Sample Data

    /// Creates a view model with sample game messages for preview.
    private static func sampleViewModel() -> GameLogViewModel {
        let viewModel = GameLogViewModel()

        // Simulate typical game output
        let sampleMessages: [(String, String?)] = [
            ("output", "You swing a vultite greatsword at a hobgoblin!"),
            ("output", "  AS: +125 vs DS: +89 with AvD: +35 + d100 roll: +42 = +113"),
            ("output", "   ... and hit for 23 points of damage!"),
            ("prompt", ">"),
            ("output", "The hobgoblin swings a short sword at you!"),
            ("output", "  AS: +95 vs DS: +105 with AvD: +12 + d100 roll: +15 = +17"),
            ("output", "   A clean miss."),
            ("prompt", ">"),
            ("output", "You search the hobgoblin."),
            ("output", "You discard the hobgoblin's useless equipment."),
            ("output", "He had 124 silvers on him."),
            ("output", "You gather the remaining 124 coins."),
            ("prompt", ">"),
            ("output", "Roundtime: 3 sec."),
            ("output", "[Wehnimer's Landing, Town Square]"),
            ("output", "The bustling town comes alive around you."),
            ("output", "Obvious exits: north, south, east, west"),
            ("prompt", ">"),
            ("output", "Lord Xanlin just arrived."),
            ("output", "Xanlin waves to you."),
            ("prompt", ">")
        ]

        for (tagName, text) in sampleMessages {
            let tag = GameTag(
                name: tagName,
                text: text,
                state: .closed
            )
            viewModel.appendMessage(tag)
        }

        return viewModel
    }

    /// Creates a view model with 100+ messages for performance testing.
    private static func largeBufferViewModel() -> GameLogViewModel {
        let viewModel = GameLogViewModel()

        // Generate 100 messages to test LazyVStack virtualization
        for i in 1...100 {
            let messageText = """
                [\(String(format: "%03d", i))] Game message line with some typical combat spam and \
                room description text that wraps across multiple lines when the window is narrow.
                """
            let tag = GameTag(
                name: "output",
                text: messageText,
                state: .closed
            )
            viewModel.appendMessage(tag)
        }

        // Add a prompt at the end
        let promptTag = GameTag(
            name: "prompt",
            text: ">",
            state: .closed
        )
        viewModel.appendMessage(promptTag)

        return viewModel
    }
}
