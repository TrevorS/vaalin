// ABOUTME: StreamView displays filtered stream content with styled rendering and virtualized scrolling

import AppKit
import os
import SwiftUI
import VaalinCore

/// NSTextView-based stream content view with styled rendering and multi-stream support.
///
/// Provides high-performance filtered stream display with:
/// - Multi-line selection (via NSTextView)
/// - Auto-scroll to latest content
/// - Cmd+F find panel (built-in to NSTextView)
/// - 60fps scrolling with 10k+ message buffer
/// - Full theme-based styling (green for speech, red for damage, etc.)
///
/// ## Features
/// - **Styled Rendering**: Uses TagRenderer for preset colors (NOT plain text)
/// - **Multi-Stream**: Union of multiple active streams merged chronologically
/// - **Back Button**: Returns to main game log
/// - **Unread Tracking**: Clears unread counts on view appear
///
/// Uses `StreamViewModel` for message rendering and stream buffer access.
public struct StreamView: View {
    /// View model providing stream messages and buffer management
    @Bindable public var viewModel: StreamViewModel

    /// Stream IDs being displayed (for header badge)
    public let activeStreamIDs: Set<String>

    /// Dismiss action to return to main log
    public let onDismiss: () -> Void

    // MARK: - Initialization

    /// Creates a new StreamView for displaying filtered stream content.
    ///
    /// - Parameters:
    ///   - viewModel: View model managing stream content
    ///   - activeStreamIDs: Set of stream IDs being displayed
    ///   - onDismiss: Callback when user dismisses the view
    public init(
        viewModel: StreamViewModel,
        activeStreamIDs: Set<String>,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.activeStreamIDs = activeStreamIDs
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        VStack(spacing: 0) {
            // Header with back button and stream badges
            streamHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)

            // Stream content (NSTextView-based)
            StreamContentView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Load stream content when view appears
            await viewModel.loadStreamContent()
            await viewModel.clearUnreadCounts()
        }
    }

    // MARK: - Subviews

    /// Header with back button and active stream badges
    private var streamHeader: some View {
        HStack {
            // Back button
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back to Log")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help("Return to main game log")

            Spacer()

            // Active stream badges
            HStack(spacing: 8) {
                ForEach(Array(activeStreamIDs).sorted(), id: \.self) { streamID in
                    streamBadge(for: streamID)
                }
            }
        }
    }

    /// Badge for an active stream
    private func streamBadge(for streamID: String) -> some View {
        Text(streamID.capitalized)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
            )
    }
}

// MARK: - StreamContentView

/// NSTextView-based stream content display with virtualized scrolling
private struct StreamContentView: NSViewRepresentable {
    /// View model providing stream messages
    @Bindable var viewModel: StreamViewModel

    /// Logger for StreamContentView events
    private let logger = Logger(
        subsystem: "org.trevorstrieber.vaalin",
        category: "StreamContentView"
    )

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Failed to create NSTextView from scrollableTextView()")
        }

        // Configure NSTextView for read-only, selectable stream content
        configureTextView(textView)

        // Force TextKit 1 for proven stability with large buffers
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            assert(layoutManager.textContainers.contains(textContainer),
                   "TextKit 1 not initialized correctly")
        }

        // Configure scroll view
        configureScrollView(scrollView)

        // Store references in coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Set initial content (only if non-empty)
        if !viewModel.messages.isEmpty {
            context.coordinator.replaceAllText(with: viewModel.messages)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update with current messages
        context.coordinator.updateMessages(
            currentMessages: viewModel.messages,
            textView: textView
        )

        // Auto-scroll to bottom (always show latest content)
        context.coordinator.scrollToBottom()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(logger: logger)
    }

    // MARK: - Configuration

    /// Configures NSTextView for stream content display
    private func configureTextView(_ textView: NSTextView) {
        // Read-only but selectable
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false

        // Typography (accessibility-aware)
        let baseSize: CGFloat = 13
        let systemFontSize = NSFont.systemFontSize
        let scaledSize = systemFontSize * (baseSize / 13)

        textView.font = NSFont.monospacedSystemFont(
            ofSize: scaledSize,
            weight: .regular
        )

        // Opaque background (Catppuccin Mocha Base)
        textView.backgroundColor = NSColor(
            red: 30 / 255,
            green: 30 / 255,
            blue: 46 / 255,
            alpha: 1.0
        )
        textView.drawsBackground = true

        // Text color (accessibility-aware)
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            textView.textColor = .white
        } else {
            textView.textColor = NSColor(
                red: 205 / 255,
                green: 214 / 255,
                blue: 244 / 255,
                alpha: 1.0
            )
        }

        // Layout
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        // Performance optimizations
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Find panel
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isIncrementalSearchingEnabled = true

        // Paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = scaledSize * 0.2
        textView.defaultParagraphStyle = paragraphStyle

        // Dark mode (always)
        textView.appearance = NSAppearance(named: .darkAqua)

        // Accessibility
        textView.setAccessibilityLabel("Stream Content")
        textView.setAccessibilityRole(.textArea)
        textView.setAccessibilityHelp("Displays filtered stream content. Use Cmd+F to find text.")
    }

    /// Configures NSScrollView for optimal performance
    private func configureScrollView(_ scrollView: NSScrollView) {
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true  // Always show for stream view
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
    }

    // MARK: - Coordinator

    /// Coordinator manages NSTextView state and handles updates
    @MainActor
    final class Coordinator: NSObject {
        // MARK: - Properties

        /// Weak reference to NSTextView
        weak var textView: NSTextView?

        /// Weak reference to NSScrollView
        weak var scrollView: NSScrollView?

        /// Number of messages in the last update
        private var lastMessageCount: Int = 0

        /// Cache of converted NSAttributedStrings
        private var nsAttributedCache: [UUID: NSAttributedString] = [:]

        /// Logger for coordinator events
        private let logger: Logger

        // MARK: - Initialization

        init(logger: Logger) {
            self.logger = logger
            super.init()
        }

        // MARK: - Text Updates

        /// Replace all text (used on initial load)
        func replaceAllText(with messages: [Message]) {
            guard let textStorage = textView?.textStorage else { return }

            let attributed = messages.toNSAttributedString(cache: &nsAttributedCache)

            textStorage.beginEditing()
            textStorage.setAttributedString(attributed)
            textStorage.endEditing()

            lastMessageCount = messages.count
        }

        /// Update messages (replace all if count changes)
        func updateMessages(currentMessages: [Message], textView: NSTextView) {
            // For stream view, always replace all content (simpler than delta tracking)
            // Stream views are typically smaller than main log, so full replacement is fast
            if currentMessages.count != lastMessageCount {
                replaceAllText(with: currentMessages)
            }
        }

        // MARK: - Scroll Management

        /// Scroll to bottom
        func scrollToBottom() {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }

            let endRange = NSRange(location: textStorage.length, length: 0)

            // Delay until after layout completes
            DispatchQueue.main.async {
                textView.scrollRangeToVisible(endRange)
            }
        }

        // MARK: - Cleanup

        deinit {
            // Cache and weak refs deallocated automatically
        }
    }
}
