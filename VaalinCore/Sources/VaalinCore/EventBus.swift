// ABOUTME: EventBus actor provides thread-safe event subscription/publishing for cross-component communication

import Foundation

/// Thread-safe event bus for cross-component communication using Swift actors.
///
/// EventBus implements a type-safe publish/subscribe pattern that allows components
/// to communicate without tight coupling. Events are identified by string names,
/// and handlers are type-safe closures that receive strongly-typed event data.
///
/// ## Usage
///
/// ```swift
/// struct PlayerEvent {
///     let name: String
///     let health: Int
/// }
///
/// let bus = EventBus()
///
/// // Subscribe to events
/// let subscriptionId = await bus.subscribe("player.updated") { (event: PlayerEvent) in
///     print("Player \(event.name) has \(event.health) health")
/// }
///
/// // Publish events
/// await bus.publish("player.updated", data: PlayerEvent(name: "Hero", health: 95))
///
/// // Unsubscribe when done
/// await bus.unsubscribe(subscriptionId)
/// ```
///
/// ## Thread Safety
///
/// EventBus is implemented as an actor, ensuring all operations are thread-safe.
/// Multiple components can safely subscribe, publish, and unsubscribe concurrently.
///
/// ## Performance
///
/// - Handlers execute sequentially in subscription order
/// - Async handlers are awaited before proceeding to next handler
/// - High-volume publishing is supported (tested with 1000+ events)
/// - Handler errors are isolated and don't affect other handlers
///
/// ## Common Event Patterns
///
/// - Game metadata: `metadata/left`, `metadata/right`, `metadata/spell`
/// - Progress bars: `metadata/progressBar/health`, `metadata/progressBar/mana`
/// - Streams: `stream/thoughts`, `stream/speech`, `stream/main`
///
public actor EventBus {
    // MARK: - Types

    /// Unique identifier for event subscriptions
    /// Returned when subscribing, used to unsubscribe
    public typealias SubscriptionID = UUID

    /// Type-erased wrapper for event handlers
    /// Stores handler closure with its expected event type
    private struct Handler: Sendable {
        let id: SubscriptionID
        let eventType: Any.Type
        let handler: @Sendable (Any) async throws -> Void

        /// Execute handler with type-safe event data
        /// - Parameter data: Event data to pass to handler
        /// - Throws: Rethrows any error from handler
        func execute(with data: Any) async throws {
            try await handler(data)
        }
    }

    // MARK: - State

    /// Handlers organized by event name
    /// Each event name can have multiple handlers
    private var handlers: [String: [Handler]] = [:]

    // MARK: - Initialization

    /// Create a new event bus
    public init() {}

    // MARK: - Subscription

    /// Subscribe to an event with a type-safe handler
    ///
    /// - Parameters:
    ///   - event: Event name to subscribe to (e.g., "metadata/left", "stream/thoughts")
    ///   - handler: Async closure to call when event is published (can throw)
    /// - Returns: Subscription ID for later unsubscription
    ///
    /// The handler closure receives strongly-typed event data. Only events published
    /// with matching event name and compatible data type will trigger this handler.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct HandsEvent {
    ///     let item: String?
    /// }
    ///
    /// let subId = await bus.subscribe("metadata/left") { (event: HandsEvent) in
    ///     print("Left hand: \(event.item ?? "empty")")
    /// }
    /// ```
    @discardableResult
    public func subscribe<T: Sendable>(
        _ event: String,
        handler: @escaping @Sendable (T) async throws -> Void
    ) -> SubscriptionID {
        let id = UUID()

        // Wrap handler with type checking
        let wrappedHandler = Handler(
            id: id,
            eventType: T.self,
            handler: { data in
                // Type-safe cast - only execute if data matches expected type
                if let typedData = data as? T {
                    try await handler(typedData)
                }
            }
        )

        // Add to handlers for this event
        handlers[event, default: []].append(wrappedHandler)

        return id
    }

    // MARK: - Publishing

    /// Publish an event to all subscribers
    ///
    /// - Parameters:
    ///   - event: Event name to publish (e.g., "metadata/left", "stream/thoughts")
    ///   - data: Event data to send to handlers
    ///
    /// All handlers subscribed to this event name will be called sequentially
    /// in subscription order. Async handlers are awaited before proceeding.
    ///
    /// Handler errors are caught and isolated - one handler throwing does not
    /// prevent other handlers from executing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct HandsEvent {
    ///     let item: String?
    /// }
    ///
    /// await bus.publish("metadata/left", data: HandsEvent(item: "sword"))
    /// ```
    public func publish<T: Sendable>(_ event: String, data: T) async {
        guard let eventHandlers = handlers[event] else {
            // No handlers for this event - this is normal
            return
        }

        // Execute all handlers sequentially
        for handler in eventHandlers {
            do {
                try await handler.execute(with: data)
            } catch {
                // Isolate handler errors - don't let one handler break others
                // In production, could log error here
                continue
            }
        }
    }

    // MARK: - Unsubscription

    /// Unsubscribe from an event using subscription ID
    ///
    /// - Parameter subscriptionId: ID returned from `subscribe()`
    ///
    /// After unsubscribing, the handler will no longer be called when
    /// the event is published. Unsubscribing with an invalid ID is safe
    /// and does nothing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let subId = await bus.subscribe("test.event") { (event: TestEvent) in
    ///     // Handle event
    /// }
    ///
    /// // Later...
    /// await bus.unsubscribe(subId)
    /// ```
    public func unsubscribe(_ subscriptionId: SubscriptionID) {
        // Remove handler with matching ID from all events
        for (event, eventHandlers) in handlers {
            let filtered = eventHandlers.filter { $0.id != subscriptionId }

            if filtered.isEmpty {
                // No more handlers for this event
                handlers.removeValue(forKey: event)
            } else if filtered.count != eventHandlers.count {
                // Found and removed the handler
                handlers[event] = filtered
            }
        }
    }

    // MARK: - Introspection (for testing/debugging)

    /// Get count of handlers for a specific event
    /// - Parameter event: Event name to check
    /// - Returns: Number of handlers subscribed to this event
    internal func handlerCount(for event: String) -> Int {
        return handlers[event]?.count ?? 0
    }

    /// Get total number of active subscriptions across all events
    /// - Returns: Total handler count
    internal func totalHandlerCount() -> Int {
        return handlers.values.reduce(0) { $0 + $1.count }
    }
}
