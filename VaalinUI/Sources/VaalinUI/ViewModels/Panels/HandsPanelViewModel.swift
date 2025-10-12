// ABOUTME: HandsPanelViewModel manages hands panel state with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the hands panel with real-time updates from EventBus.
///
/// `HandsPanelViewModel` subscribes to `metadata/left`, `metadata/right`, and `metadata/spell`
/// events from the EventBus and updates the hand/spell state when the game server sends updates.
/// The hands panel displays what items the player is holding and what spell they have prepared.
///
/// ## EventBus Integration
///
/// Subscribes to three events on initialization:
/// - `"metadata/left"` - Left hand item updates
/// - `"metadata/right"` - Right hand item updates
/// - `"metadata/spell"` - Prepared spell updates
///
/// When the parser emits these events (Issue #31), this view model receives them and updates
/// the corresponding properties, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with child tags containing the item/spell text:
/// ```swift
/// // Left hand example
/// GameTag(
///     name: "left",
///     text: nil,
///     children: [
///         GameTag(name: "item", text: "steel broadsword", ...)
///     ],
///     state: .closed
/// )
///
/// // Empty hand example
/// GameTag(
///     name: "left",
///     text: nil,
///     children: [],  // No children = empty hand
///     state: .closed
/// )
/// ```
///
/// The view model extracts `tag.children[0].text` to get the item/spell name,
/// or falls back to default values ("Empty" for hands, "None" for spell) if
/// there are no children or the text is nil/empty.
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
/// let viewModel = HandsPanelViewModel(eventBus: eventBus)
/// await viewModel.setup()  // Required!
///
/// // Display in SwiftUI view
/// HandsPanel(viewModel: viewModel)
///
/// // The parser will publish hands events:
/// let itemTag = GameTag(name: "item", text: "sword", state: .closed)
/// let leftTag = GameTag(name: "left", children: [itemTag], state: .closed)
/// await eventBus.publish("metadata/left", data: leftTag)
///
/// // SwiftUI view automatically updates with new left hand item
/// print(viewModel.leftHand)  // "sword"
/// ```
@Observable
@MainActor
public final class HandsPanelViewModel {
    // MARK: - Properties

    /// Current left hand item (default: "Empty")
    ///
    /// Updated automatically when `metadata/left` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var leftHand: String = "Empty"

    /// Current right hand item (default: "Empty")
    ///
    /// Updated automatically when `metadata/right` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var rightHand: String = "Empty"

    /// Current prepared spell (default: "None")
    ///
    /// Updated automatically when `metadata/spell` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var preparedSpell: String = "None"

    /// EventBus reference for subscribing to hands/spell events
    private let eventBus: EventBus

    /// Subscription IDs for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var leftSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var rightSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var spellSubscriptionID: EventBus.SubscriptionID?

    /// Logger for HandsPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "HandsPanelViewModel")

    // MARK: - Initialization

    /// Creates a new HandsPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to hands/spell events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to hands/spell events.
    ///
    /// **Must be called immediately after init** to enable hands/spell updates.
    /// In production code, this is typically called in the view's `.task` modifier.
    ///
    /// **Idempotency**: This method can be called multiple times safely - it will only
    /// subscribe once. Subsequent calls are ignored with a debug log.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = HandsPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Idempotency check - prevent duplicate subscriptions
        guard leftSubscriptionID == nil else {
            logger.debug("Already subscribed to EventBus, skipping setup")
            return
        }

        // Subscribe to left hand events
        leftSubscriptionID = await eventBus.subscribe("metadata/left") { [weak self] (tag: GameTag) in
            await self?.handleLeftHandEvent(tag)
        }
        logger.debug("Subscribed to metadata/left events with ID: \(self.leftSubscriptionID!)")

        // Subscribe to right hand events
        rightSubscriptionID = await eventBus.subscribe("metadata/right") { [weak self] (tag: GameTag) in
            await self?.handleRightHandEvent(tag)
        }
        logger.debug("Subscribed to metadata/right events with ID: \(self.rightSubscriptionID!)")

        // Subscribe to spell events
        spellSubscriptionID = await eventBus.subscribe("metadata/spell") { [weak self] (tag: GameTag) in
            await self?.handleSpellEvent(tag)
        }
        logger.debug("Subscribed to metadata/spell events with ID: \(self.spellSubscriptionID!)")
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

        if let id = leftSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = rightSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = spellSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming left hand events from EventBus
    ///
    /// - Parameter tag: GameTag containing left hand item data
    ///
    /// Extracts item name from `tag.text` or `tag.children[0].text`.
    /// Falls back to "Empty" if no text content found.
    @MainActor
    private func handleLeftHandEvent(_ tag: GameTag) {
        // Only process tags named "left"
        guard tag.name == "left" else {
            logger.debug("Ignoring non-left tag: \(tag.name)")
            return
        }

        // DEBUG: Log full tag structure
        logger.debug(
            """
            Processing left hand - Tag: \(tag.name), text: \(tag.text ?? "nil"), \
            children count: \(tag.children.count)
            """
        )

        // Extract item name from tag (check direct text first, then children)
        // Vaalin parser stores simple text in tag.text, complex nested text in children
        let itemText = tag.text ?? tag.children.first?.text

        if let itemText = itemText, !itemText.isEmpty {
            leftHand = itemText
            logger.debug("✓ Updated left hand: \(itemText)")
        } else {
            // No text content -> empty hand
            leftHand = "Empty"
            logger.debug("⚠️ Left hand is now empty")
        }
    }

    /// Handles incoming right hand events from EventBus
    ///
    /// - Parameter tag: GameTag containing right hand item data
    ///
    /// Extracts item name from `tag.text` or `tag.children[0].text`.
    /// Falls back to "Empty" if no text content found.
    @MainActor
    private func handleRightHandEvent(_ tag: GameTag) {
        // Only process tags named "right"
        guard tag.name == "right" else {
            logger.debug("Ignoring non-right tag: \(tag.name)")
            return
        }

        // DEBUG: Log full tag structure
        logger.debug(
            """
            Processing right hand - Tag: \(tag.name), text: \(tag.text ?? "nil"), \
            children count: \(tag.children.count)
            """
        )

        // Extract item name from tag (check direct text first, then children)
        // Vaalin parser stores simple text in tag.text, complex nested text in children
        let itemText = tag.text ?? tag.children.first?.text

        if let itemText = itemText, !itemText.isEmpty {
            rightHand = itemText
            logger.debug("✓ Updated right hand: \(itemText)")
        } else {
            // No text content -> empty hand
            rightHand = "Empty"
            logger.debug("⚠️ Right hand is now empty")
        }
    }

    /// Handles incoming spell events from EventBus
    ///
    /// - Parameter tag: GameTag containing prepared spell data
    ///
    /// Extracts spell name from `tag.text` or `tag.children[0].text`.
    /// Falls back to "None" if no text content found.
    @MainActor
    private func handleSpellEvent(_ tag: GameTag) {
        // Only process tags named "spell"
        guard tag.name == "spell" else {
            logger.debug("Ignoring non-spell tag: \(tag.name)")
            return
        }

        // DEBUG: Log full tag structure
        logger.debug(
            """
            Processing prepared spell - Tag: \(tag.name), text: \(tag.text ?? "nil"), \
            children count: \(tag.children.count)
            """
        )

        // Extract spell name from tag (check direct text first, then children)
        // Vaalin parser stores simple text in tag.text, complex nested text in children
        let spellText = tag.text ?? tag.children.first?.text

        if let spellText = spellText, !spellText.isEmpty {
            preparedSpell = spellText
            logger.debug("✓ Updated prepared spell: \(spellText)")
        } else {
            // No text content -> no spell
            preparedSpell = "None"
            logger.debug("⚠️ No spell prepared")
        }
    }
}
