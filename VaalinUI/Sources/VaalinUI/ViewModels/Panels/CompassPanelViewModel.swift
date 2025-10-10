// ABOUTME: CompassPanelViewModel manages compass panel state with EventBus subscription for room and navigation updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the compass panel with real-time updates from EventBus.
///
/// `CompassPanelViewModel` subscribes to `metadata/nav`, `metadata/compass`, and `metadata/streamWindow/room`
/// events from the EventBus and updates the room/navigation state when the game server sends updates.
/// The compass panel displays the current room name, room ID, and available exits on a compass rose.
///
/// ## EventBus Integration
///
/// Subscribes to three events on initialization:
/// - `"metadata/nav"` - Room ID updates from `<nav rm="..."/>` tag
/// - `"metadata/compass"` - Exit list from `<compass><dir value="..."/></compass>` tag
/// - `"metadata/streamWindow/room"` - Room title from `<streamWindow subtitle=" - [Room] - 123"/>` tag
///
/// When the parser emits these events (Issue #39), this view model receives them and updates
/// the corresponding properties, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// ### Navigation Event (metadata/nav)
/// The parser publishes `GameTag` events with room ID attribute:
/// ```swift
/// // Room navigation example
/// GameTag(
///     name: "nav",
///     attrs: ["rm": "228"],
///     state: .closed
/// )
/// ```
///
/// ### Compass Event (metadata/compass)
/// The parser publishes `GameTag` events with exit children:
/// ```swift
/// // Compass with multiple exits
/// GameTag(
///     name: "compass",
///     children: [
///         GameTag(name: "dir", attrs: ["value": "n"], state: .closed),
///         GameTag(name: "dir", attrs: ["value": "s"], state: .closed),
///         GameTag(name: "dir", attrs: ["value": "e"], state: .closed)
///     ],
///     state: .closed
/// )
///
/// // Empty compass (dead end)
/// GameTag(
///     name: "compass",
///     children: [],
///     state: .closed
/// )
/// ```
///
/// ### Room Title Event (metadata/streamWindow/room)
/// The parser publishes `GameTag` events with formatted subtitle:
/// ```swift
/// // GemStone IV format
/// GameTag(
///     name: "streamWindow",
///     attrs: [
///         "id": "main",
///         "subtitle": " - [Town Square, Market] - 228"
///     ],
///     state: .closed
/// )
/// ```
///
/// The view model extracts and parses the subtitle to get clean room name:
/// - Input: `" - [Town Square, Market] - 228"`
/// - Output: `"[Town Square, Market]"`
///
/// ## Room Title Parsing
///
/// Supports multiple formats:
///
/// **GemStone IV format** (standard):
/// - Input: `" - [Room Name] - 123"`
/// - Steps:
///   1. Remove leading " - " → `"[Room Name] - 123"`
///   2. Remove trailing " - \d+" → `"[Room Name]"`
///
/// **DragonRealms format**:
/// - Input: `"[Room Name] (123)"`
/// - Steps:
///   1. Remove trailing " (\d+)" → `"[Room Name]"`
///
/// **Edge cases**:
/// - Empty subtitle → `""`
/// - Missing subtitle attribute → preserve previous value
/// - Malformed formats → best-effort parsing
///
/// ## Exit Directions
///
/// All 11 standard directions supported:
/// - **Cardinal**: n, e, s, w
/// - **Diagonal**: ne, se, sw, nw
/// - **Special**: up, down, out
///
/// Exits stored as `Set<String>` for efficient lookup and automatic deduplication.
///
/// ## Thread Safety
///
/// **IMPORTANT:** This class is isolated to MainActor. All public properties and methods
/// must be accessed from the main thread. The EventBus subscription handlers run on the
/// main thread via `@MainActor` isolation.
///
/// The `@Observable` macro provides property observation for SwiftUI reactivity.
///
/// ## Lifecycle Management
///
/// The view model unsubscribes from all EventBus events on deinitialization to prevent
/// memory leaks and ensure proper cleanup when the view is dismissed.
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = CompassPanelViewModel(eventBus: eventBus)
/// await viewModel.setup()  // Required!
///
/// // Display in SwiftUI view
/// CompassPanel(viewModel: viewModel)
///
/// // The parser will publish navigation events:
/// let navTag = GameTag(name: "nav", attrs: ["rm": "228"], state: .closed)
/// await eventBus.publish("metadata/nav", data: navTag)
///
/// let compassTag = GameTag(
///     name: "compass",
///     children: [
///         GameTag(name: "dir", attrs: ["value": "n"], state: .closed),
///         GameTag(name: "dir", attrs: ["value": "s"], state: .closed)
///     ],
///     state: .closed
/// )
/// await eventBus.publish("metadata/compass", data: compassTag)
///
/// // SwiftUI view automatically updates
/// print(viewModel.roomId)  // 228
/// print(viewModel.exits)   // ["n", "s"]
/// ```
///
/// ## Reference
///
/// Based on Illthorn's `compass-rose-container.lit.ts` and GemStone IV XML protocol
/// documented in `docs/compass-tags.md` (Issue #39).
@Observable
@MainActor
public final class CompassPanelViewModel {
    // MARK: - Properties

    /// Current room name (default: "")
    ///
    /// Updated automatically when `metadata/streamWindow/room` events are published to EventBus.
    /// Parsed from subtitle attribute to extract clean room name.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var roomName: String = ""

    /// Current room ID (default: 0)
    ///
    /// Updated automatically when `metadata/nav` events are published to EventBus.
    /// Extracted from `rm` attribute of `<nav>` tag.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var roomId: Int = 0

    /// Set of available exit directions (default: empty)
    ///
    /// Updated automatically when `metadata/compass` events are published to EventBus.
    /// Extracted from `<dir value="..."/>` children of `<compass>` tag.
    /// Contains direction codes: n, ne, e, se, s, sw, w, nw, up, down, out.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var exits: Set<String> = []

    /// EventBus reference for subscribing to navigation/compass events
    private let eventBus: EventBus

    /// Subscription IDs for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var navSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var compassSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var streamWindowSubscriptionID: EventBus.SubscriptionID?

    /// Logger for CompassPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "CompassPanelViewModel")

    // MARK: - Initialization

    /// Creates a new CompassPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to navigation/compass events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to navigation/compass events.
    ///
    /// **Must be called immediately after init** to enable navigation/compass updates.
    /// In production code, this is typically called in the view's `.task` modifier.
    ///
    /// **Idempotency**: This method can be called multiple times safely - it will only
    /// subscribe once. Subsequent calls are ignored with a debug log.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = CompassPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Idempotency check - prevent duplicate subscriptions
        guard navSubscriptionID == nil else {
            logger.debug("Already subscribed to EventBus, skipping setup")
            return
        }

        // Subscribe to nav events (room ID)
        navSubscriptionID = await eventBus.subscribe("metadata/nav") { [weak self] (tag: GameTag) in
            await self?.handleNavEvent(tag)
        }
        logger.debug("Subscribed to metadata/nav events with ID: \(self.navSubscriptionID!)")

        // Subscribe to compass events (exits)
        compassSubscriptionID = await eventBus.subscribe("metadata/compass") { [weak self] (tag: GameTag) in
            await self?.handleCompassEvent(tag)
        }
        logger.debug("Subscribed to metadata/compass events with ID: \(self.compassSubscriptionID!)")

        // Subscribe to streamWindow events (room title)
        streamWindowSubscriptionID = await eventBus.subscribe(
            "metadata/streamWindow/room"
        ) { [weak self] (tag: GameTag) in
            await self?.handleStreamWindowEvent(tag)
        }
        logger.debug("Subscribed to metadata/streamWindow/room events with ID: \(self.streamWindowSubscriptionID!)")
    }

    // MARK: - Deinitialization

    /// Unsubscribes from EventBus on deallocation
    ///
    /// **Note:** Cleanup happens asynchronously in detached tasks. The subscriptions
    /// will be removed from EventBus after deinit completes. This is safe because
    /// the handlers use `weak self` and won't be called after deallocation.
    deinit {
        // Capture values for async cleanup
        let bus = eventBus

        if let id = navSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = compassSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = streamWindowSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming nav events from EventBus
    ///
    /// - Parameter tag: GameTag containing room ID data
    ///
    /// Extracts room ID from `tag.attrs["rm"]` (per GemStone IV protocol).
    /// Falls back to 0 if attribute missing or non-numeric.
    @MainActor
    private func handleNavEvent(_ tag: GameTag) {
        // Only process tags named "nav"
        guard tag.name == "nav" else {
            logger.debug("Ignoring non-nav tag: \(tag.name)")
            return
        }

        // Extract room ID from rm attribute
        if let rmValue = tag.attrs["rm"] as? String,
           let parsedId = Int(rmValue) {
            roomId = parsedId
            logger.debug("Updated room ID: \(parsedId)")
        } else {
            // Missing or invalid rm attribute
            logger.debug("Nav tag missing or invalid rm attribute, keeping previous value")
        }
    }

    /// Handles incoming compass events from EventBus
    ///
    /// - Parameter tag: GameTag containing exit directions data
    ///
    /// Extracts exit directions from `tag.children` where each child has `attrs["value"]`.
    /// Creates a Set for efficient lookup and automatic deduplication.
    /// Empty children array indicates no available exits (dead end).
    @MainActor
    private func handleCompassEvent(_ tag: GameTag) {
        // Only process tags named "compass"
        guard tag.name == "compass" else {
            logger.debug("Ignoring non-compass tag: \(tag.name)")
            return
        }

        // Extract exit directions from children
        let exitDirections = tag.children
            .compactMap { child -> String? in
                // Each child should be a <dir value="..."/> tag
                guard child.name == "dir",
                      let value = child.attrs["value"] as? String,
                      !value.isEmpty else {
                    return nil
                }
                return value
            }

        exits = Set(exitDirections)

        if exits.isEmpty {
            logger.debug("Compass has no exits (dead end)")
        } else {
            logger.debug("Updated exits: \(self.exits.sorted())")
        }
    }

    /// Handles incoming streamWindow events from EventBus
    ///
    /// - Parameter tag: GameTag containing room title data
    ///
    /// Extracts room title from `tag.attrs["subtitle"]` and parses to get clean room name.
    /// Supports both GemStone IV format (`" - [Room] - 123"`) and DragonRealms format (`"[Room] (123)"`).
    /// Falls back to empty string if attribute missing or malformed.
    @MainActor
    private func handleStreamWindowEvent(_ tag: GameTag) {
        // Only process tags named "streamWindow"
        guard tag.name == "streamWindow" else {
            logger.debug("Ignoring non-streamWindow tag: \(tag.name)")
            return
        }

        // Extract subtitle attribute
        guard let subtitle = tag.attrs["subtitle"] as? String else {
            logger.debug("StreamWindow tag missing subtitle attribute, keeping previous value")
            return
        }

        // Parse subtitle to extract clean room name
        let parsedName = parseRoomTitle(from: subtitle)
        roomName = parsedName

        if parsedName.isEmpty {
            logger.debug("Parsed empty room name from subtitle: \"\(subtitle)\"")
        } else {
            logger.debug("Updated room name: \(parsedName)")
        }
    }

    /// Parses room title from subtitle attribute.
    ///
    /// - Parameter subtitle: Raw subtitle string from `<streamWindow>` tag
    /// - Returns: Cleaned room name with leading prefix and trailing room ID removed
    ///
    /// **Parsing Logic**:
    /// 1. Remove leading " - " prefix
    /// 2. Remove trailing " - {room_id}" (GemStone IV format) if present AFTER a closing bracket
    /// 3. Remove trailing " ({room_id})" (DragonRealms format) if present
    ///
    /// **Examples**:
    /// - Input: `" - [Town Square, Market] - 228"`
    /// - Output: `"[Town Square, Market]"`
    ///
    /// - Input: `"[Bosque Deriel] (230008)"` (DragonRealms)
    /// - Output: `"[Bosque Deriel]"`
    ///
    /// - Input: `" - [Tavern] - 456"` (where ` - 456` is part of the name, no closing bracket)
    /// - Output: `"[Tavern] - 456"` (preserved because ` - 456` is inside the brackets)
    ///
    /// **Rationale**:
    /// The room ID is redundant (already available as separate `roomId` property).
    /// Removing it provides cleaner UI display compared to Illthorn's simpler approach.
    private func parseRoomTitle(from subtitle: String) -> String {
        var title = subtitle

        // Remove leading hyphens and spaces
        while title.hasPrefix("-") || title.hasPrefix(" ") {
            title = String(title.dropFirst(1))
        }

        // Remove trailing " - {room_id}" pattern (GemStone IV format)
        // ONLY if there's a closing bracket BEFORE the ` - {id}` pattern
        // Regex: "\] - \d+$" (closing bracket, space, hyphen, space, digits, end of string)
        if let range = title.range(of: #"\] - \d+$"#, options: .regularExpression) {
            // Remove only the " - {digits}" part, keep the "]"
            let bracketIndex = title.distance(from: title.startIndex, to: range.lowerBound)
            let endIndex = title.index(title.startIndex, offsetBy: bracketIndex + 1) // Keep the "]"
            title = String(title[..<endIndex])
        } else if !title.contains("[") {
            // Fallback: Malformed subtitle without brackets
            // Remove trailing " - {digits}" pattern anyway for robustness
            if let range = title.range(of: #" - \d+$"#, options: .regularExpression) {
                title.removeSubrange(range)
            }
        }

        // Remove trailing " ({room_id})" pattern (DragonRealms format)
        // Regex: " \(\d+\)$" (space, open paren, digits, close paren, end of string)
        if let range = title.range(of: #" \(\d+\)$"#, options: .regularExpression) {
            title.removeSubrange(range)
        }

        return title
    }
}
