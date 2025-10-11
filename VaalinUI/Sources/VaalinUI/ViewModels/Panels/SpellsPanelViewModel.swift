// ABOUTME: SpellsPanelViewModel manages active spells panel state with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the active spells panel with real-time updates from EventBus.
///
/// `SpellsPanelViewModel` subscribes to `metadata/dialogData/spellfront` events from the EventBus
/// and updates the active spells list when the game server sends spell/effect data.
///
/// ## EventBus Integration
///
/// Subscribes to one event on initialization:
/// - `"metadata/dialogData/spellfront"` - Active spells dialog updates
///
/// When the parser emits these events (Issue #44), this view model receives them and updates
/// the `activeSpells` list, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with progressBar children containing spell data:
/// ```swift
/// // Spellfront dialog example
/// GameTag(
///     name: "dialogData",
///     text: nil,
///     attrs: ["id": "spellfront"],
///     children: [
///         GameTag(
///             name: "progressBar",
///             attrs: [
///                 "id": "spell123",           // Required: unique identifier
///                 "text": "Spirit Shield",    // Required: spell name
///                 "time": "14:32",           // Optional: time remaining
///                 "value": "85"              // Optional: percentage
///             ],
///             state: .closed
///         ),
///         GameTag(
///             name: "progressBar",
///             attrs: [
///                 "id": "spell456",
///                 "text": "Haste",
///                 "time": "3:45",
///                 "value": "25"
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
///     attrs: ["id": "spellfront"],
///     children: [],  // Empty children = clear all spells
///     state: .closed
/// )
/// ```
///
/// ## Data Extraction Logic
///
/// 1. **Tag filtering**: Only processes dialogData tags with `id="spellfront"`
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
/// // The parser will publish spellfront events:
/// let spell = GameTag(
///     name: "progressBar",
///     attrs: ["id": "spell123", "text": "Spirit Shield", "time": "14:32", "value": "85"]
/// )
/// let dialog = GameTag(
///     name: "dialogData",
///     attrs: ["id": "spellfront"],
///     children: [spell]
/// )
/// await eventBus.publish("metadata/dialogData/spellfront", data: dialog)
///
/// // SwiftUI view automatically updates with new spell list
/// print(viewModel.activeSpells.count)  // 1
/// print(viewModel.activeSpells[0].name)  // "Spirit Shield"
/// ```
@Observable
@MainActor
public final class SpellsPanelViewModel {
    // MARK: - Properties

    /// List of currently active spells
    ///
    /// Updated automatically when `metadata/dialogData/spellfront` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// Empty array indicates no spells are currently active.
    public var activeSpells: [ActiveSpell] = []

    /// EventBus reference for subscribing to spellfront events
    private let eventBus: EventBus

    /// Subscription ID for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handler uses weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var spellsSubscriptionID: EventBus.SubscriptionID?

    /// Logger for SpellsPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "SpellsPanelViewModel")

    // MARK: - Initialization

    /// Creates a new SpellsPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to spellfront events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to spellfront events.
    ///
    /// **Must be called immediately after init** to enable spells updates.
    /// In production code, this is typically called in the view's `onAppear` or
    /// similar lifecycle method.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = SpellsPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Subscribe to spellfront events
        let eventName = "metadata/dialogData/spellfront"
        spellsSubscriptionID = await eventBus.subscribe(eventName) { [weak self] (tag: GameTag) in
            await self?.handleSpellfrontEvent(tag)
        }
        let subID = self.spellsSubscriptionID!
        logger.debug("Subscribed to \(eventName) events with ID: \(subID)")
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

        if let id = spellsSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming spellfront events from EventBus
    ///
    /// - Parameter tag: GameTag containing spellfront dialog data
    ///
    /// ## Processing Logic:
    /// 1. Verify tag is dialogData type
    /// 2. Verify ID matches "spellfront"
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
    private func handleSpellfrontEvent(_ tag: GameTag) {
        // Verify tag is dialogData type
        guard tag.name == "dialogData" else {
            logger.debug("Ignoring non-dialogData tag: \(tag.name)")
            return
        }

        // Verify ID matches spellfront
        guard let tagID = tag.attrs["id"], tagID == "spellfront" else {
            logger.debug("Ignoring dialogData with wrong ID: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // Empty children = clear all spells
        if tag.children.isEmpty {
            activeSpells = []
            logger.debug("Cleared all spells (empty children)")
            return
        }

        logger.debug("Processing spellfront event with \(tag.children.count) children")

        // Process progressBar children
        let newSpells = tag.children.compactMap { child -> ActiveSpell? in
            // Only process progressBar tags
            guard child.name == "progressBar" else {
                logger.debug("Skipping non-progressBar child: \(child.name)")
                return nil
            }

            // Extract required id field
            guard let id = child.attrs["id"] else {
                logger.debug("Skipping progressBar without id attribute")
                return nil
            }

            // Extract required text field (spell name)
            guard let name = child.attrs["text"], !name.isEmpty else {
                logger.debug("Skipping progressBar \(id) without text or with empty text")
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
            logger.debug("Extracted spell: id=\(id), name=\(name), time=\(timeStr), percent=\(percentStr)")

            return spell
        }

        // Replace activeSpells with new list (full replacement)
        activeSpells = newSpells
        logger.debug("Updated activeSpells: \(newSpells.count) spells")
    }
}
