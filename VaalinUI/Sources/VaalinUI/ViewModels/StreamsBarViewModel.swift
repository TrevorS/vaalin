// ABOUTME: StreamsBarViewModel manages state for the streams filtering bar

import Foundation
import SwiftUI
import VaalinCore

/// View model for the streams filtering bar.
///
/// Manages stream filtering state including:
/// - Loading stream metadata from StreamRegistry
/// - Tracking active/inactive streams
/// - Fetching unread counts from StreamBufferManager
/// - Resolving theme colors for stream chips
/// - Toggling stream filter state
///
/// ## Usage
///
/// ```swift
/// @Bindable var viewModel: StreamsBarViewModel
///
/// StreamsBarView(viewModel: viewModel)
/// ```
///
/// ## Thread Safety
///
/// Marked with `@MainActor` to ensure all UI updates happen on the main thread.
@MainActor
@Observable
public class StreamsBarViewModel {
    // MARK: - Dependencies

    /// Stream registry for loading stream metadata
    private let streamRegistry: StreamRegistry

    /// Stream buffer manager for unread counts
    private let streamBufferManager: StreamBufferManager

    /// Theme for resolving chip colors
    private let theme: Theme

    // MARK: - State

    /// Currently active stream IDs (user has enabled filtering)
    /// Keys are stream IDs, values are always true (Set semantics)
    public var activeStreams: Set<String> = []

    /// Cached stream info for display
    /// Loaded once from registry and cached for performance
    private var cachedStreams: [StreamInfo] = []

    // MARK: - Initialization

    /// Creates a new streams bar view model.
    ///
    /// - Parameters:
    ///   - streamRegistry: Stream registry for metadata
    ///   - streamBufferManager: Buffer manager for unread counts
    ///   - theme: Theme for chip colors
    ///   - initialActiveStreams: Initial set of active stream IDs (defaults to all defaultOn streams)
    public init(
        streamRegistry: StreamRegistry = .shared,
        streamBufferManager: StreamBufferManager,
        theme: Theme,
        initialActiveStreams: Set<String>? = nil
    ) {
        self.streamRegistry = streamRegistry
        self.streamBufferManager = streamBufferManager
        self.theme = theme

        // Initialize active streams
        if let initial = initialActiveStreams {
            self.activeStreams = initial
        }
        // If nil, will be populated by loadStreams()
    }

    // MARK: - Public API

    /// Loads stream metadata from registry.
    ///
    /// Fetches all streams and caches them for display. If initialActiveStreams
    /// was not provided in init, populates activeStreams with all defaultOn streams.
    ///
    /// Call this once during view initialization:
    /// ```swift
    /// .task {
    ///     await viewModel.loadStreams()
    /// }
    /// ```
    public func loadStreams() async {
        let allStreams = await streamRegistry.allStreams()

        // Sort by id for consistent ordering
        cachedStreams = allStreams.sorted { $0.id < $1.id }

        // If active streams not initialized, use default-on streams
        if activeStreams.isEmpty {
            activeStreams = Set(
                cachedStreams
                    .filter { $0.defaultOn }
                    .map { $0.id }
            )
        }
    }

    /// Returns streams that should be displayed as chips.
    ///
    /// Filters for default-on streams (always visible in the bar) and returns
    /// them sorted for consistent display order.
    ///
    /// - Returns: Array of StreamInfo for chip rendering
    public func displayedStreams() -> [StreamInfo] {
        return cachedStreams.filter { $0.defaultOn }
    }

    /// Gets the unread count for a specific stream.
    ///
    /// Queries StreamBufferManager for the current unread message count.
    ///
    /// - Parameter streamId: Stream ID to query
    /// - Returns: Unread message count (0 if stream doesn't exist)
    public func unreadCount(for streamId: String) async -> Int {
        return await streamBufferManager.unreadCount(forStream: streamId)
    }

    /// Checks if a stream is currently active/enabled.
    ///
    /// - Parameter streamId: Stream ID to check
    /// - Returns: True if stream is active, false otherwise
    public func isActive(_ streamId: String) -> Bool {
        return activeStreams.contains(streamId)
    }

    /// Toggles a stream's active state.
    ///
    /// Adds or removes the stream from activeStreams set. This controls
    /// whether the stream's content is filtered in/out of the main log.
    ///
    /// - Parameter streamId: Stream ID to toggle
    public func toggleStream(_ streamId: String) {
        if activeStreams.contains(streamId) {
            activeStreams.remove(streamId)
        } else {
            activeStreams.insert(streamId)
        }
    }

    /// Resolves the chip color for a stream from the theme.
    ///
    /// Looks up the stream's color key in the theme palette and converts
    /// to SwiftUI Color. Falls back to default color if lookup fails.
    ///
    /// - Parameter streamInfo: Stream metadata with color key
    /// - Returns: SwiftUI Color for chip background
    public func chipColor(for streamInfo: StreamInfo) -> Color {
        // Look up palette color from stream's color key
        guard let hexString = theme.palette[streamInfo.color] else {
            // Fallback to default if color key not found
            return Color.secondary
        }

        // Convert hex to Color
        return Color(hex: hexString) ?? Color.secondary
    }

    // MARK: - Testing Support

    /// Exposes cached streams for testing
    internal func getCachedStreams() -> [StreamInfo] {
        return cachedStreams
    }
}
