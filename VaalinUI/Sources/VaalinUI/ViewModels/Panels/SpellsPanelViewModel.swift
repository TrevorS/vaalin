// ABOUTME: SpellsPanelViewModel manages active spells panel state with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the active spells panel with real-time updates from EventBus.
///
/// `SpellsPanelViewModel` subscribes to `metadata/dialogData/Active Spells` events from the EventBus
/// and updates the active spells list when the game server sends spell/effect data.
///
/// ## EventBus Integration
///
/// Subscribes to one event on initialization:
/// - `"metadata/dialogData/Active Spells"` - Active spells dialog updates
///
/// When the parser emits these events (Issue #44), this view model receives them and updates
/// the `activeSpells` list, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with progressBar children containing spell data:
/// ```swift
/// // Active Spells dialog example
/// GameTag(
///     name: "dialogData",
///     text: nil,
///     attrs: ["id": "Active Spells"],
///     children: [
///         GameTag(
///             name: "progressBar",
///             attrs: [
///                 "id": "401",                          // Required: GemStone IV spell number
///                 "text": "Elemental Defense I",      // Required: spell name
///                 "time": "45:20",                     // Optional: time remaining
///                 "value": "88"                        // Optional: percentage
///             ],
///             state: .closed
///         ),
///         GameTag(
///             name: "progressBar",
///             attrs: [
///                 "id": "913",                        // Melgorehn's Aura (Wizard Base)
///                 "text": "Melgorehn's Aura",
///                 "time": "22:15",
///                 "value": "74"
///             ],
///             state: .closed
///         )
///     ],
///     state: .closed
/// )
///
/// // Empty dialog (no spells active)
/// GameTag(
///     name: "dialogData",
///     text: nil,
///     attrs: ["id": "Active Spells"],
///     children: [],  // Empty children = clear all spells
///     state: .closed
/// )
/// ```
///
/// ## Data Extraction Logic
///
/// 1. **Tag filtering**: Only processes dialogData tags with `id="Active Spells"`
/// 2. **Child filtering**: Only processes progressBar children
/// 3. **Required fields**: Spells must have `id` and `text` attributes, text must not be empty
/// 4. **Optional fields**:
///    - `timeRemaining` from `attrs["time"]` (String, can be nil)
///    - `percentRemaining` from `attrs["value"]` converted to Int (nil if missing/invalid)
/// 5. **Empty children**: When `children` is empty, clears all spells
/// 6. **Full replacement**: Each event completely replaces the spell list (no append)
/// 7. **Order preservation**: Maintains order from `tag.children` array
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
/// let viewModel = SpellsPanelViewModel(eventBus: eventBus)
/// await viewModel.setup()  // Required!
///
/// // Display in SwiftUI view
/// SpellsPanel(viewModel: viewModel)
///
/// // The parser will publish Active Spells events:
/// let spell = GameTag(
///     name: "progressBar",
///     attrs: ["id": "913", "text": "Melgorehn's Aura", "time": "14:32", "value": "85"]
/// )
/// let dialog = GameTag(
///     name: "dialogData",
///     attrs: ["id": "Active Spells"],
///     children: [spell]
/// )
/// await eventBus.publish("metadata/dialogData/Active Spells", data: dialog)
///
/// // SwiftUI view automatically updates with new spell list
/// print(viewModel.activeSpells.count)  // 1
/// print(viewModel.activeSpells[0].name)  // "Melgorehn's Aura"
/// ```
@Observable
@MainActor
public final class SpellsPanelViewModel: PanelViewModelBase {
    // MARK: - Properties

    /// List of currently active spells
    ///
    /// Updated automatically when `metadata/dialogData/Active Spells` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// Empty array indicates no spells are currently active.
    public var activeSpells: [ActiveSpell] = []

    // MARK: - PanelViewModelBase Requirements

    /// EventBus reference for subscribing to Active Spells events
    public let eventBus: EventBus

    /// Subscription IDs for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) public var subscriptionIDs: [EventBus.SubscriptionID] = []

    /// Logger for SpellsPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "SpellsPanelViewModel")

    // MARK: - Initialization

    /// Creates a new SpellsPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to Active Spells events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to Active Spells events.
    ///
    /// **Must be called immediately after init** to enable spells updates.
    /// In production code, this is typically called in the view's `.task` modifier.
    ///
    /// **Idempotency**: This method can be called multiple times safely - it will only
    /// subscribe once. Subsequent calls are ignored with a debug log.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = SpellsPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Idempotency check - prevent duplicate subscriptions
        guard subscriptionIDs.isEmpty else {
            logger.debug("Already subscribed to EventBus, skipping setup")
            return
        }

        // Subscribe to Active Spells events
        let eventName = "metadata/dialogData/Active Spells"
        let id = await eventBus.subscribe(eventName) { [weak self] (tag: GameTag) in
            await self?.handleActiveSpellsEvent(tag)
        }
        subscriptionIDs.append(id)
        logger.debug("Subscribed to \(eventName) events with ID: \(id)")
    }

    // MARK: - Deinitialization

    /// Unsubscribes from EventBus on deallocation
    ///
    /// **Note:** Cleanup happens asynchronously via PanelViewModelBase.cleanup().
    /// The subscriptions will be removed from EventBus after deinit completes.
    /// This is safe because the handlers use `weak self` and won't be called after deallocation.
    deinit {
        cleanup()
    }

    // MARK: - Private Methods

    /// Handles incoming Active Spells events from EventBus
    ///
    /// - Parameter tag: GameTag containing Active Spells dialog data
    ///
    /// ## Processing Logic:
    /// 1. Verify tag is dialogData type
    /// 2. Verify ID matches "Active Spells"
    /// 3. If children empty, clear all spells
    /// 4. Filter children for progressBar tags
    /// 5. Extract spell data from each progressBar
    /// 6. Replace activeSpells with new list (full replacement)
    ///
    /// Required spell fields:
    /// - `id`: Unique spell identifier (String)
    /// - `text`: Spell name (String, must not be empty)
    ///
    /// Optional spell fields:
    /// - `time`: Time remaining (String, can be nil)
    /// - `value`: Percentage remaining (Int, can be nil or invalid)
    @MainActor
    private func handleActiveSpellsEvent(_ tag: GameTag) {
        // Verify tag is dialogData type
        guard tag.name == "dialogData" else {
            logger.debug("Ignoring non-dialogData tag: \(tag.name)")
            return
        }

        // Verify ID matches Active Spells
        guard let tagID = tag.attrs["id"], tagID == "Active Spells" else {
            logger.debug("Ignoring dialogData with wrong ID: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // DEBUG: Log full tag structure
        logger.debug("Processing Active Spells - Tag: \(tag.name), ID: \(tagID), children count: \(tag.children.count)")

        // Empty children = clear all spells
        if tag.children.isEmpty {
            activeSpells = []
            logger.debug("✓ Cleared all spells (empty children)")
            return
        }

        logger.debug("Processing Active Spells event with \(tag.children.count) children")

        // Process progressBar children
        let newSpells = tag.children.compactMap(extractSpellFromProgressBar)

        // Sort spells by numeric spell ID
        // Spell IDs are numeric strings (e.g., "202", "901", "1720")
        // Use localizedStandardCompare for proper numeric string sorting
        let sortedSpells = newSpells.sorted { lhs, rhs in
            lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }

        // Replace activeSpells with new sorted list
        activeSpells = sortedSpells
        logger.debug("Updated activeSpells: \(sortedSpells.count) spells, sorted by spell ID")
    }

    /// Extracts an ActiveSpell from a progressBar GameTag.
    ///
    /// - Parameter child: GameTag to process (expected to be progressBar)
    /// - Returns: ActiveSpell if extraction succeeds, nil otherwise
    ///
    /// ## Extraction Logic:
    /// 1. Verify tag is progressBar type
    /// 2. Extract required id field (String)
    /// 3. Extract required text field (String, must not be empty)
    /// 4. Extract optional time field (String)
    /// 5. Extract optional value field (String → Int conversion)
    private func extractSpellFromProgressBar(_ child: GameTag) -> ActiveSpell? {
        // Only process progressBar tags
        guard child.name == "progressBar" else {
            logger.debug("  Skipping non-progressBar child: \(child.name)")
            return nil
        }

        // DEBUG: Log full child structure
        logger.debug("  Processing child progressBar - attrs: \(child.attrs)")

        // Extract required id field
        guard let id = child.attrs["id"] else {
            logger.debug("  ⚠️ Skipping progressBar without id attribute")
            return nil
        }

        // Extract required text field (spell name)
        guard let name = child.attrs["text"], !name.isEmpty else {
            logger.debug("  ⚠️ Skipping progressBar \(id) without text or with empty text")
            return nil
        }

        // Extract optional time field
        let timeRemaining = child.attrs["time"]

        // Extract optional percentage field (convert to Int)
        var percentRemaining: Int?
        if let valueString = child.attrs["value"],
           let value = Int(valueString) {
            percentRemaining = value
        }

        let spell = ActiveSpell(
            id: id,
            name: name,
            timeRemaining: timeRemaining,
            percentRemaining: percentRemaining
        )

        let timeStr = timeRemaining ?? "nil"
        let percentStr = percentRemaining?.description ?? "nil"
        logger.debug("  ✓ Extracted spell: id=\(id), name=\(name), time=\(timeStr), percent=\(percentStr)")

        return spell
    }
}
