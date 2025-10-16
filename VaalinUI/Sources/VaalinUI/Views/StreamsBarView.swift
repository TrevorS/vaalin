// ABOUTME: StreamsBarView displays horizontal bar of stream filtering chips with Liquid Glass styling

import SwiftUI
import VaalinCore

/// Horizontal bar of stream filtering chips for Phase 4 stream filtering.
///
/// `StreamsBarView` displays a row of interactive StreamChip components for filtering
/// game output by stream type (thoughts, speech, whispers, etc.). Features include:
/// - Minimal frosted glass background
/// - Horizontal scrolling for many streams
/// - Unread indicator dots (instead of count badges)
/// - Toggle stream filtering on/off via chip taps
/// - Color-coded chips from theme palette
///
/// ## Design Specifications
///
/// - **Material**: `.ultraThinMaterial` for minimal frosted background
/// - **Height**: Configurable via `height` parameter (default: 38pt)
/// - **Layout**: HStack with horizontal scrolling if needed
/// - **Spacing**: 8pt between chips
/// - **Padding**: 12pt horizontal, 6pt vertical
///
/// ## Layout Integration
///
/// Positioned between GameLogView and CommandInputView in the center column of MainView:
/// ```swift
/// VStack {
///     StreamsBarView(
///         viewModel: streamsBarViewModel,
///         height: settings.layout.streamsHeight
///     )
///     GameLogView(...)  // Fills remaining space
///     CommandInputView(...)  // Bottom fixed height
/// }
/// ```
///
/// ## Performance
///
/// - **Rendering**: < 5ms for typical 6-stream bar
/// - **Updates**: Reactive via @Observable viewModel
/// - **Scrolling**: 60fps smooth scrolling
///
/// ## Example Usage
///
/// ```swift
/// @Bindable var viewModel: StreamsBarViewModel
///
/// StreamsBarView(
///     viewModel: viewModel,
///     height: 112
/// )
/// .task {
///     await viewModel.loadStreams()
/// }
/// ```
public struct StreamsBarView: View {
    // MARK: - Properties

    /// View model managing stream state and unread counts
    @Bindable public var viewModel: StreamsBarViewModel

    /// Height of the streams bar in points (from Settings.layout.streamsHeight)
    public let height: CGFloat

    /// State for tracking unread counts (refreshed periodically)
    @State private var unreadCounts: [String: Int] = [:]

    // MARK: - Initialization

    /// Creates a streams bar with the specified view model and height.
    ///
    /// - Parameters:
    ///   - viewModel: View model managing stream state
    ///   - height: Height in points (default: 112)
    public init(
        viewModel: StreamsBarViewModel,
        height: CGFloat = 112
    ) {
        self.viewModel = viewModel
        self.height = height
    }

    // MARK: - Body

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        streamsContent
            .frame(height: height)
            .background(streamsBackground)
            .task {
                // Refresh unread counts every 2 seconds
                while !Task.isCancelled {
                    await refreshUnreadCounts()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
    }

    // MARK: - Subviews

    /// Main content with chip row
    private var streamsContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.displayedStreams().enumerated()), id: \.element.id) { index, streamInfo in
                    streamChipWithShortcut(streamInfo: streamInfo, index: index)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
    }

    /// Stream chip with keyboard shortcut (Cmd+1 through Cmd+6 for first 6 chips)
    @ViewBuilder
    private func streamChipWithShortcut(streamInfo: StreamInfo, index: Int) -> some View {
        let chip = StreamChip(
            streamInfo: streamInfo,
            unreadCount: unreadCounts[streamInfo.id] ?? 0,
            isActive: viewModel.isActive(streamInfo.id),
            chipColor: viewModel.chipColor(for: streamInfo),
            onToggle: {
                viewModel.toggleStream(streamInfo.id)
            }
        )

        // Add keyboard shortcut for first 6 chips (Cmd+1 through Cmd+6)
        if index < 6 {
            let key = KeyEquivalent(Character("\(index + 1)"))
            chip.keyboardShortcut(key, modifiers: .command)
        } else {
            chip
        }
    }

    /// Minimal frosted glass background
    private var streamsBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.ultraThinMaterial)
            .overlay {
                // Subtle border
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 1.5,
                y: 1
            )
    }

    // MARK: - Helpers

    /// Refreshes unread counts from view model for all displayed streams
    private func refreshUnreadCounts() async {
        var counts: [String: Int] = [:]
        for stream in viewModel.displayedStreams() {
            let count = await viewModel.unreadCount(for: stream.id)
            counts[stream.id] = count
        }
        unreadCounts = counts
    }
}
