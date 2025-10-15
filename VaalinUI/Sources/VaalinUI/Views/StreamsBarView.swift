// ABOUTME: StreamsBarView displays horizontal bar of stream filtering chips with Liquid Glass styling

import SwiftUI
import VaalinCore

/// Horizontal bar of stream filtering chips for Phase 4 stream filtering.
///
/// `StreamsBarView` displays a row of interactive StreamChip components for filtering
/// game output by stream type (thoughts, speech, whispers, etc.). Features include:
/// - Liquid Glass translucent background
/// - Horizontal scrolling for many streams
/// - Real-time unread count badges
/// - Toggle stream filtering on/off via chip taps
/// - Color-coded chips from theme palette
///
/// ## Design Specifications
///
/// - **Material**: `.regularMaterial` for translucent background
/// - **Height**: Configurable via `height` parameter from `Settings.layout.streamsHeight`
/// - **Layout**: HStack with horizontal scrolling if needed
/// - **Spacing**: 12pt between chips
/// - **Padding**: 16pt horizontal, 12pt vertical
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
            HStack(spacing: 12) {
                ForEach(viewModel.displayedStreams()) { streamInfo in
                    StreamChip(
                        streamInfo: streamInfo,
                        unreadCount: unreadCounts[streamInfo.id] ?? 0,
                        isActive: viewModel.isActive(streamInfo.id),
                        chipColor: viewModel.chipColor(for: streamInfo),
                        onToggle: {
                            viewModel.toggleStream(streamInfo.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    /// Translucent background with Liquid Glass styling
    private var streamsBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.regularMaterial)
            .overlay {
                // Subtle glass highlight
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.05),
                                Color.white.opacity(colorScheme == .dark ? 0.01 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                // Subtle border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.15 : 0.1),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 4,
                y: 2
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
