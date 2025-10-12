// ABOUTME: GameLogView displays the game log with virtualized scrolling and auto-scroll behavior

import SwiftUI
import VaalinCore

/// Displays the game log with auto-scrolling and connection status indicator.
///
/// `GameLogView` renders game messages from the parser with theme-based styling.
/// It uses SwiftUI's modern `.defaultScrollAnchor(.bottom)` modifier for automatic
/// scroll-to-bottom behavior that mimics iOS Messages and terminal applications.
///
/// ## Performance Characteristics
/// - **Target**: 60fps scrolling with 10,000 message buffer
/// - **Optimization**: Uses `LazyVStack` for virtualized rendering (only visible rows loaded)
/// - **Auto-scroll**: Native SwiftUI behavior via `.defaultScrollAnchor(.bottom)`
/// - **Memory**: Delegates buffer management to `GameLogViewModel` (auto-prunes at 10k messages)
///
/// ## Layout Structure
/// ```
/// VStack {
///   Connection Status (top)
///   ScrollView {
///     LazyVStack {
///       ForEach(messages) { message in
///         Text(attributedText)
///       }
///     }
///   }
///   .defaultScrollAnchor(.bottom)  // Auto-scroll magic
/// }
/// ```
///
/// ## Auto-Scroll Behavior
/// - **Native iOS 17+ behavior**: Uses `.defaultScrollAnchor(.bottom)` modifier
/// - **Enabled**: Automatically scrolls to bottom when new messages arrive
/// - **Disabled**: When user manually scrolls up to review history
/// - **Re-enabled**: Automatically when user scrolls back to bottom
/// - Mimics iOS Messages app: scroll stays at bottom unless user explicitly scrolls up
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

            // Main scrollable game log with native auto-scroll behavior
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Performance: LazyVStack only renders visible rows
                    // Critical for 10,000 message buffer @ 60fps target
                    ForEach(viewModel.messages) { message in
                        messageRow(for: message)
                    }
                }
                .padding(8)
            }
            .defaultScrollAnchor(.bottom)  // Native iOS 17+ auto-scroll
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
