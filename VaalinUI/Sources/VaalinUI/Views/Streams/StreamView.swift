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
/// - **Inline Display**: Embedded directly in main layout below stream chips
/// - **Unread Tracking**: Clears unread counts on view appear
///
/// Uses `StreamViewModel` for message rendering and stream buffer access.
public struct StreamView: View {
    /// View model providing stream messages and buffer management
    @Bindable public var viewModel: StreamViewModel

    /// Stream IDs being displayed
    public let activeStreamIDs: Set<String>

    // MARK: - Initialization

    /// Creates a new StreamView for displaying filtered stream content.
    ///
    /// - Parameters:
    ///   - viewModel: View model managing stream content
    ///   - activeStreamIDs: Set of stream IDs being displayed
    public init(
        viewModel: StreamViewModel,
        activeStreamIDs: Set<String>
    ) {
        self.viewModel = viewModel
        self.activeStreamIDs = activeStreamIDs
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        // Stream content (NSTextView-based) - no header, sits directly under chips
        StreamContentView(viewModel: viewModel)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .task {
                // Load stream content when view appears
                await viewModel.loadStreamContent()
                await viewModel.clearUnreadCounts()
            }
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

// MARK: - Previews

#Preview("Empty State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts"]
    
    let viewModel = StreamViewModel(
        streamBufferManager: streamBufferManager,
        activeStreamIDs: activeStreamIDs,
        theme: Theme.catppuccinMocha()
    )
    
    return StreamView(
        viewModel: viewModel,
        activeStreamIDs: activeStreamIDs
    )
    .frame(width: 800, height: 600)
}

#Preview("Populated State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech"]
    
    let viewModel = StreamViewModel(
        streamBufferManager: streamBufferManager,
        activeStreamIDs: activeStreamIDs,
        theme: Theme.catppuccinMocha()
    )
    
    Task {
        // Create sample messages with different presets
        let thoughtTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "thought"],
                children: [
                    GameTag(
                        name: ":text",
                        text: """
                        You carefully consider your tactical options, weighing the risks \
                        of a direct assault against the potential for a more subtle approach.
                        """,
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]
        
        let speechTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "speech"],
                children: [
                    GameTag(
                        name: ":text",
                        text: "You say, \"The path ahead looks dangerous. We should proceed with caution.\"",
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]
        
        let damageTags = [
            GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": "damage"],
                children: [
                    GameTag(
                        name: ":text",
                        text: """
                        You swing a vultite longsword at a hill troll!
                          AS: +246 vs DS: +84 with AvD: +42 + d100 roll: +91 = +295
                           ... and hit for 128 points of damage!
                           Massive blow punches a hole through the hill troll's chest!
                        """,
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )
        ]
        
        // Add messages to streams
        await streamBufferManager.append(
            Message(from: thoughtTags, streamID: "thoughts"),
            toStream: "thoughts"
        )
        
        await streamBufferManager.append(
            Message(from: speechTags, streamID: "speech"),
            toStream: "speech"
        )
        
        await streamBufferManager.append(
            Message(from: thoughtTags, streamID: "thoughts"),
            toStream: "thoughts"
        )
        
        await streamBufferManager.append(
            Message(from: damageTags, streamID: "speech"),
            toStream: "speech"
        )
        
        // Reload view model after populating data
        await viewModel.loadStreamContent()
    }
    
    return StreamView(
        viewModel: viewModel,
        activeStreamIDs: activeStreamIDs
    )
    .frame(width: 800, height: 600)
}

#Preview("Multi-Stream State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts", "speech", "whispers"]
    
    let viewModel = StreamViewModel(
        streamBufferManager: streamBufferManager,
        activeStreamIDs: activeStreamIDs,
        theme: Theme.catppuccinMocha()
    )
    
    Task {
        // Create sample messages across multiple streams
        let thoughtTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "thought"],
            children: [
                GameTag(
                    name: ":text",
                    text: "You think you need only open yourself, when you are ready.",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )
        
        let speechTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "speech"],
            children: [
                GameTag(
                    name: ":text",
                    text: "Elaejia says, \"He swore that he hadn't arrested anyone in some time...\"",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )
        
        let whisperTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "whisper"],
            children: [
                GameTag(
                    name: ":text",
                    text: """
                    Elaejia leans over and whispers, "I think you need only open yourself, \
                    when you are ready."
                    """,
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )
        
        // Add messages with different timestamps to demonstrate chronological merging
        await streamBufferManager.append(
            Message(from: [thoughtTag], streamID: "thoughts"),
            toStream: "thoughts"
        )
        
        try? await Task.sleep(for: .milliseconds(10))
        
        await streamBufferManager.append(
            Message(from: [speechTag], streamID: "speech"),
            toStream: "speech"
        )
        
        try? await Task.sleep(for: .milliseconds(10))
        
        await streamBufferManager.append(
            Message(from: [whisperTag], streamID: "whispers"),
            toStream: "whispers"
        )
        
        try? await Task.sleep(for: .milliseconds(10))
        
        await streamBufferManager.append(
            Message(from: [thoughtTag], streamID: "thoughts"),
            toStream: "thoughts"
        )
        
        // Reload view model after populating data
        await viewModel.loadStreamContent()
    }
    
    return StreamView(
        viewModel: viewModel,
        activeStreamIDs: activeStreamIDs
    )
    .frame(width: 800, height: 600)
}
