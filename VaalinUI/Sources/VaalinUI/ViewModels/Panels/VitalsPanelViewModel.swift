// ABOUTME: VitalsPanelViewModel manages vitals panel state with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the vitals panel with real-time updates from EventBus.
///
/// `VitalsPanelViewModel` subscribes to `metadata/progressBar/*` events from the EventBus
/// and updates vitals state when the game server sends progress bar updates. The vitals panel
/// displays health, mana, stamina, spirit, mind, stance, and encumbrance.
///
/// ## EventBus Integration
///
/// Subscribes to seven events on initialization:
/// - `"metadata/progressBar/health"` - Health percentage updates
/// - `"metadata/progressBar/mana"` - Mana percentage updates
/// - `"metadata/progressBar/stamina"` - Stamina percentage updates
/// - `"metadata/progressBar/spirit"` - Spirit percentage updates
/// - `"metadata/progressBar/mindState"` - Mind percentage updates
/// - `"metadata/progressBar/pbarStance"` - Stance text updates
/// - `"metadata/progressBar/encumlevel"` - Encumbrance text updates
///
/// When the parser emits these events (Issue #31), this view model receives them and updates
/// the corresponding properties, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with attributes containing vital data:
/// ```swift
/// // Progress bar example (health, mana, stamina, spirit)
/// GameTag(
///     name: "progressBar",
///     text: nil,
///     attrs: [
///         "id": "health",
///         "value": "75",        // Percentage (0-100)
///         "text": "75/100"      // Fraction display
///     ],
///     state: .closed
/// )
///
/// // Mind example (special - text instead of fractions)
/// GameTag(
///     name: "progressBar",
///     text: nil,
///     attrs: [
///         "id": "mindState",
///         "value": "100",       // Percentage for bar
///         "text": "clear"       // Descriptive text (not a fraction)
///     ],
///     state: .closed
/// )
///
/// // Text field example (stance)
/// GameTag(
///     name: "progressBar",
///     text: nil,
///     attrs: [
///         "id": "pbarStance",
///         "text": "defensive guarded"  // Extract first word
///     ],
///     state: .closed
/// )
/// ```
///
/// ## Percentage Calculation (Server Bug Workaround)
///
/// **Important:** The game server has a bug where vital progress bars send `value="0"`
/// despite showing full/partial health (e.g., `text="74/74"` or `text="50/100"`).
/// Other progress bars (stance, encumbrance) send correct percentages.
///
/// This view model works around the bug by:
/// 1. Using `attrs["value"]` if it's a valid percentage (> 1)
/// 2. Calculating percentage from `attrs["text"]` fraction if value is 0 or 1
/// 3. Returning `nil` (indeterminate state) if neither is available
///
/// Reference: Illthorn implementation at `vitals-container.lit.ts:137-158`
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
/// let viewModel = VitalsPanelViewModel(eventBus: eventBus)
/// await viewModel.setup()  // Required!
///
/// // Display in SwiftUI view
/// VitalsPanel(viewModel: viewModel)
///
/// // The parser will publish vitals events:
/// let healthTag = GameTag(
///     name: "progressBar",
///     attrs: ["id": "health", "value": "75", "text": "75/100"],
///     state: .closed
/// )
/// await eventBus.publish("metadata/progressBar/health", data: healthTag)
///
/// // SwiftUI view automatically updates with new health percentage
/// print(viewModel.health)  // Optional(75)
/// ```
@Observable
@MainActor
public final class VitalsPanelViewModel {
    // MARK: - Properties

    /// Current health percentage (0-100), nil for indeterminate state
    ///
    /// Updated automatically when `metadata/progressBar/health` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// `nil` indicates no data has been received yet (indeterminate state for progress bar).
    public var health: Int?

    /// Current mana percentage (0-100), nil for indeterminate state
    ///
    /// Updated automatically when `metadata/progressBar/mana` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// `nil` indicates no data has been received yet (indeterminate state for progress bar).
    public var mana: Int?

    /// Current stamina percentage (0-100), nil for indeterminate state
    ///
    /// Updated automatically when `metadata/progressBar/stamina` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// `nil` indicates no data has been received yet (indeterminate state for progress bar).
    public var stamina: Int?

    /// Current spirit percentage (0-100), nil for indeterminate state
    ///
    /// Updated automatically when `metadata/progressBar/spirit` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// `nil` indicates no data has been received yet (indeterminate state for progress bar).
    public var spirit: Int?

    /// Current mind percentage (0-100), nil for indeterminate state
    ///
    /// Updated automatically when `metadata/progressBar/mindState` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// `nil` indicates no data has been received yet (indeterminate state for progress bar).
    public var mind: Int?

    /// Current health text showing actual amounts (e.g., "74/74", "50/100")
    ///
    /// Extracted from `attrs["text"]` in progress bar events.
    /// Displayed next to health label in UI instead of percentage.
    public var healthText: String?

    /// Current mana text showing actual amounts (e.g., "85/85", "60/100")
    public var manaText: String?

    /// Current stamina text showing actual amounts (e.g., "90/90", "70/100")
    public var staminaText: String?

    /// Current spirit text showing actual amounts (e.g., "65/100", "80/80")
    public var spiritText: String?

    /// Current mind text showing mental state (e.g., "clear", "muddled", "numbed")
    ///
    /// **Important:** Unlike other vitals, mind displays descriptive text instead of fractions.
    /// The server sends text like "clear as a bell" or "muddled" which is displayed directly
    /// without any parsing or modification.
    public var mindText: String?

    /// Current stance text (e.g., "offensive", "defensive")
    ///
    /// Updated automatically when `metadata/progressBar/pbarStance` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// Default value is "offensive" (most common starting stance).
    /// Extracts first word from multi-word stance text (e.g., "defensive guarded" → "defensive").
    public var stance: String = "offensive"

    /// Current encumbrance text (e.g., "none", "light", "heavy")
    ///
    /// Updated automatically when `metadata/progressBar/encumlevel` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// Default value is "none" (no encumbrance).
    /// Text is converted to lowercase for consistent display.
    public var encumbrance: String = "none"

    /// EventBus reference for subscribing to vitals events
    private let eventBus: EventBus

    /// Subscription IDs for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var healthSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var manaSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var staminaSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var spiritSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var mindSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var stanceSubscriptionID: EventBus.SubscriptionID?

    @ObservationIgnored
    nonisolated(unsafe) private var encumbranceSubscriptionID: EventBus.SubscriptionID?

    /// Logger for VitalsPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "VitalsPanelViewModel")

    // MARK: - Initialization

    /// Creates a new VitalsPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to vitals events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to vitals events.
    ///
    /// **Must be called immediately after init** to enable vitals updates.
    /// In production code, this is typically called in the view's `onAppear` or
    /// similar lifecycle method.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = VitalsPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Subscribe to health events
        healthSubscriptionID = await eventBus.subscribe("metadata/progressBar/health") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "health")
        }
        logger.debug("Subscribed to metadata/progressBar/health events with ID: \(self.healthSubscriptionID!)")

        // Subscribe to mana events
        manaSubscriptionID = await eventBus.subscribe("metadata/progressBar/mana") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "mana")
        }
        logger.debug("Subscribed to metadata/progressBar/mana events with ID: \(self.manaSubscriptionID!)")

        // Subscribe to stamina events
        staminaSubscriptionID = await eventBus.subscribe("metadata/progressBar/stamina") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "stamina")
        }
        logger.debug("Subscribed to metadata/progressBar/stamina events with ID: \(self.staminaSubscriptionID!)")

        // Subscribe to spirit events
        spiritSubscriptionID = await eventBus.subscribe("metadata/progressBar/spirit") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "spirit")
        }
        logger.debug("Subscribed to metadata/progressBar/spirit events with ID: \(self.spiritSubscriptionID!)")

        // Subscribe to mind events
        mindSubscriptionID = await eventBus.subscribe("metadata/progressBar/mindState") { [weak self] tag in
            await self?.handleMindEvent(tag)
        }
        logger.debug("Subscribed to metadata/progressBar/mindState events with ID: \(self.mindSubscriptionID!)")

        // Subscribe to stance events
        stanceSubscriptionID = await eventBus.subscribe("metadata/progressBar/pbarStance") { [weak self] tag in
            await self?.handleStanceEvent(tag)
        }
        let stanceID = self.stanceSubscriptionID!
        logger.debug("Subscribed to metadata/progressBar/pbarStance events with ID: \(stanceID)")

        // Subscribe to encumbrance events
        encumbranceSubscriptionID = await eventBus.subscribe("metadata/progressBar/encumlevel") { [weak self] tag in
            await self?.handleEncumbranceEvent(tag)
        }
        let encumID = self.encumbranceSubscriptionID!
        logger.debug("Subscribed to metadata/progressBar/encumlevel events with ID: \(encumID)")
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

        if let id = healthSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = manaSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = staminaSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = spiritSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = mindSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = stanceSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }

        if let id = encumbranceSubscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming progress bar events for standard vitals (health, mana, stamina, spirit, mind)
    ///
    /// - Parameters:
    ///   - tag: GameTag containing progress bar data
    ///   - expectedID: Expected value of `attrs["id"]` (e.g., "health", "mana")
    ///
    /// Extracts both percentage and text from tag attributes.
    /// Implements workaround for server bug where vitals send `value="0"` with valid fractions.
    ///
    /// ## Data Extraction Logic:
    /// 1. Extract text from `attrs["text"]` (e.g., "74/74", "50/100")
    /// 2. Get `value` attribute - if > 1, use it for percentage
    /// 3. If value ≤ 1, calculate percentage from text fraction (e.g., "74/74" → 100%)
    /// 4. Store both percentage (for progress bar) and text (for display)
    ///
    /// Reference: Illthorn implementation at `vitals-container.lit.ts:137-158`
    @MainActor
    private func handleProgressBarEvent(_ tag: GameTag, expectedID: String) {
        // Verify tag is progressBar type
        guard tag.name == "progressBar" else {
            logger.debug("Ignoring non-progressBar tag: \(tag.name)")
            return
        }

        // Verify ID matches expected vital
        guard let tagID = tag.attrs["id"], tagID == expectedID else {
            logger.debug("Ignoring progressBar with wrong ID for \(expectedID)")
            return
        }

        // Extract both percentage and text
        let data = extractVitalData(from: tag)

        // Update appropriate properties
        switch expectedID {
        case "health":
            health = data.percentage
            healthText = data.text
            logger.debug("Updated health: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "mana":
            mana = data.percentage
            manaText = data.text
            logger.debug("Updated mana: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "stamina":
            stamina = data.percentage
            staminaText = data.text
            logger.debug("Updated stamina: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "spirit":
            spirit = data.percentage
            spiritText = data.text
            logger.debug("Updated spirit: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "mindState":
            mind = data.percentage
            mindText = data.text
            logger.debug("Updated mind: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        default:
            logger.warning("Unexpected vital ID: \(expectedID)")
        }
    }

    /// Extracts both percentage and text from GameTag attributes
    ///
    /// - Parameter tag: GameTag containing progressBar data
    /// - Returns: Tuple with percentage (0-100) or nil, and text string or nil
    ///
    /// ## Logic:
    /// 1. Extract raw text from `attrs["text"]` (e.g., "74/74", "50/100")
    /// 2. Try `attrs["value"]` as Int - if > 1, use it for percentage
    /// 3. If value ≤ 1 or missing, calculate percentage from text fraction
    /// 4. Return nil percentage if both methods fail (indeterminate state)
    ///
    /// This implements the workaround for the GemStone IV server bug where vitals
    /// send `value="0"` despite having valid fraction text.
    private func extractVitalData(from tag: GameTag) -> (percentage: Int?, text: String?) {
        // Extract text first (this is what we display)
        let text = tag.attrs["text"]

        // Try getting value attribute for percentage
        if let valueString = tag.attrs["value"],
           let value = Int(valueString),
           value > 1 {
            // Valid percentage provided by server
            return (percentage: value, text: text)
        }

        // Server bug: value is 0 or 1, try calculating from fraction
        if let text = text, text.contains("/") {
            let parts = text.split(separator: "/").map(String.init)
            guard parts.count == 2,
                  let current = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  let max = Int(parts[1].trimmingCharacters(in: .whitespaces)),
                  max > 0 else {
                // Invalid fraction format or zero denominator
                return (percentage: nil, text: text)
            }

            // Calculate percentage from fraction
            let percentage = Int(round(Double(current) / Double(max) * 100.0))
            logger.debug("Calculated percentage from fraction \(text): \(percentage)%")
            return (percentage: percentage, text: text)
        }

        // No valid percentage data available - indeterminate state
        return (percentage: nil, text: text)
    }

    /// Handles incoming stance events from EventBus
    ///
    /// - Parameter tag: GameTag containing stance data
    ///
    /// Extracts stance text from `tag.attrs["text"]` and takes first word.
    /// Example: "defensive guarded" → "defensive"
    ///
    /// Per Illthorn reference: `vitals-container.lit.ts:110-120`
    @MainActor
    private func handleStanceEvent(_ tag: GameTag) {
        // Verify tag is progressBar type
        guard tag.name == "progressBar" else {
            logger.debug("Ignoring non-progressBar tag: \(tag.name)")
            return
        }

        // Verify ID matches stance
        guard let tagID = tag.attrs["id"], tagID == "pbarStance" else {
            logger.debug("Ignoring progressBar with wrong ID for stance")
            return
        }

        // Extract text and take first word
        if let text = tag.attrs["text"] {
            let firstWord = text.split(separator: " ").first.map(String.init) ?? text
            stance = firstWord
            logger.debug("Updated stance: \(firstWord)")
        } else {
            // No text - use empty string
            stance = ""
            logger.debug("Stance text missing, using empty string")
        }
    }

    /// Handles incoming encumbrance events from EventBus
    ///
    /// - Parameter tag: GameTag containing encumbrance data
    ///
    /// Extracts encumbrance text from `tag.attrs["text"]` and converts to lowercase.
    /// Example: "Light" → "light"
    ///
    /// Per Illthorn reference: `vitals-container.lit.ts:122-133`
    @MainActor
    private func handleEncumbranceEvent(_ tag: GameTag) {
        // Verify tag is progressBar type
        guard tag.name == "progressBar" else {
            logger.debug("Ignoring non-progressBar tag: \(tag.name)")
            return
        }

        // Verify ID matches encumbrance
        guard let tagID = tag.attrs["id"], tagID == "encumlevel" else {
            logger.debug("Ignoring progressBar with wrong ID for encumbrance")
            return
        }

        // Extract text and convert to lowercase
        if let text = tag.attrs["text"] {
            encumbrance = text.lowercased()
            logger.debug("Updated encumbrance: \(text.lowercased())")
        } else {
            // No text - use empty string
            encumbrance = ""
            logger.debug("Encumbrance text missing, using empty string")
        }
    }

    /// Handles incoming mind events from EventBus
    ///
    /// - Parameter tag: GameTag containing mind data
    ///
    /// **Important:** Mind is special - it displays descriptive text like "clear" or "muddled"
    /// instead of fractions like other vitals. The text is used directly from `attrs["text"]`
    /// without any parsing or splitting.
    ///
    /// Example server data:
    /// - `<progressBar id="mindState" text="clear" value="100" />`
    /// - `<progressBar id="mindState" text="muddled" value="60" />`
    ///
    /// Per Illthorn reference: `vitals-container.lit.ts:99-107`
    @MainActor
    private func handleMindEvent(_ tag: GameTag) {
        // Verify tag is progressBar type
        guard tag.name == "progressBar" else {
            logger.debug("Ignoring non-progressBar tag: \(tag.name)")
            return
        }

        // Verify ID matches mind
        guard let tagID = tag.attrs["id"], tagID == "mindState" else {
            logger.debug("Ignoring progressBar with wrong ID for mind")
            return
        }

        // Extract percentage from value attribute
        if let valueString = tag.attrs["value"],
           let value = Int(valueString) {
            mind = value
        } else {
            mind = nil
        }

        // Extract text directly (no parsing, no splitting)
        mindText = tag.attrs["text"]

        logger.debug("Updated mind: \(self.mind?.description ?? "nil"), text: \(self.mindText ?? "nil")")
    }
}
