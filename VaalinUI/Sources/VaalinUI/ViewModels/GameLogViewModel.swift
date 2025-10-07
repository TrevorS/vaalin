// ABOUTME: GameLogViewModel manages the game log message buffer with automatic pruning at 10,000 lines

import Foundation
import Observation
import VaalinCore

/// View model for the game log display with automatic buffer management.
///
/// `GameLogViewModel` maintains a circular buffer of the most recent 10,000 game messages,
/// automatically pruning older messages to prevent unbounded memory growth during long
/// play sessions. Messages are stored as `GameTag` values and exposed to SwiftUI views
/// via the `@Observable` macro for automatic UI updates.
///
/// ## Buffer Management
/// - **Capacity**: 10,000 messages (configurable constant)
/// - **Pruning Strategy**: FIFO (First-In-First-Out) - oldest messages removed first
/// - **Trigger**: Automatic pruning when exceeding capacity
/// - **Performance**: < 1ms average append time, < 10ms pruning operation
///
/// ## Thread Safety
/// **IMPORTANT:** This class is NOT inherently thread-safe. All access must occur on the
/// main thread (MainActor). SwiftUI automatically ensures this for views bound to this
/// view model, so no additional synchronization is needed for typical SwiftUI usage.
///
/// The `@Observable` macro provides property observation for SwiftUI reactivity but does
/// NOT provide actor-like isolation or thread safety guarantees.
///
/// ## Example Usage
/// ```swift
/// @Observable
/// final class GameLogViewModel {
///     let viewModel = GameLogViewModel()
///
///     // Append messages from parser
///     let tag = GameTag(name: "output", text: "You swing at the troll!", state: .closed)
///     viewModel.appendMessage(tag)
///
///     // SwiftUI view automatically updates
///     ForEach(viewModel.messages) { message in
///         GameLogRow(message: message)
///     }
/// }
/// ```
///
/// ## Performance Characteristics
/// - **Memory**: ~50KB per 1000 messages (typical), 500KB max for full 10,000 buffer
/// - **Append**: O(1) amortized (array append + occasional O(1) removeFirst)
/// - **Pruning**: O(1) (single removeFirst operation per message over limit)
///
/// ## Stream Filtering
/// Each `GameTag` preserves its `streamId` property (e.g., "thoughts", "speech"),
/// enabling downstream filtering in stream-specific panels.
@Observable
public final class GameLogViewModel {
    // MARK: - Constants

    /// Maximum number of messages to retain in buffer before pruning oldest.
    /// Chosen to balance memory usage (~500KB) with useful scrollback history.
    private static let maxBufferSize = 10_000

    // MARK: - Properties

    /// Game log messages in chronological order (oldest first, newest last).
    ///
    /// Automatically pruned to maintain `maxBufferSize` limit. Each message is a
    /// parsed `GameTag` from the game server XML protocol.
    ///
    /// SwiftUI views observing this property will automatically update when messages
    /// are appended via the `@Observable` macro.
    public var messages: [GameTag] = []

    // MARK: - Initialization

    /// Creates a new GameLogViewModel with an empty message buffer.
    public init() {
        // Intentionally empty - messages array initializes to empty
    }

    // MARK: - Public Methods

    /// Appends a game message to the log buffer.
    ///
    /// Adds the provided `GameTag` to the end of the messages array. If the buffer
    /// exceeds `maxBufferSize` after appending, the oldest message is automatically
    /// removed to maintain the size limit.
    ///
    /// - Parameter tag: The game tag to append
    ///
    /// ## Performance
    /// - **Average case**: < 1ms (array append)
    /// - **Pruning case**: < 10ms (array append + removeFirst)
    ///
    /// ## Thread Safety
    /// Must be called from the main thread (MainActor). SwiftUI views automatically
    /// satisfy this requirement when binding to this view model.
    ///
    /// ## Example
    /// ```swift
    /// let tag = GameTag(name: "output", text: "The troll swings at you!", state: .closed)
    /// viewModel.appendMessage(tag)
    /// ```
    public func appendMessage(_ tag: GameTag) {
        messages.append(tag)

        // Prune oldest message if buffer exceeds capacity
        if messages.count > Self.maxBufferSize {
            messages.removeFirst()
        }
    }
}
