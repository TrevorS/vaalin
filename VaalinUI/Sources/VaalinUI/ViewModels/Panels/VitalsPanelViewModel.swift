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
public final class VitalsPanelViewModel: PanelViewModelBase {
    // MARK: - Pattern Constants

    /// Regex patterns for parsing vital text data
    private enum VitalPattern {
        /// Extracts numeric fraction (e.g., "74/74") from potentially contaminated text
        ///
        /// Matches patterns like:
        /// - "74/74" → "74/74"
        /// - "Health 74/74" → "74/74"
        /// - "50 / 100" → "50 / 100" (with spaces)
        ///
        /// Used in `extractVitalData(from:)` to clean server-provided text.
        static let fraction = #"\d+\s*/\s*\d+"#
    }

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

    // MARK: - PanelViewModelBase Requirements

    /// EventBus reference for subscribing to vitals events
    public let eventBus: EventBus

    /// Subscription IDs for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) public var subscriptionIDs: [EventBus.SubscriptionID] = []

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
    /// In production code, this is typically called in the view's `.task` modifier.
    ///
    /// **Idempotency**: This method can be called multiple times safely - it will only
    /// subscribe once. Subsequent calls are ignored with a debug log.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = VitalsPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Idempotency check - prevent duplicate subscriptions
        guard subscriptionIDs.isEmpty else {
            logger.debug("Already subscribed to EventBus, skipping setup")
            return
        }

        // Subscribe to health events
        let healthID = await eventBus.subscribe("metadata/progressBar/health") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "health")
        }
        subscriptionIDs.append(healthID)
        logger.debug("Subscribed to metadata/progressBar/health events with ID: \(healthID)")

        // Subscribe to mana events
        let manaID = await eventBus.subscribe("metadata/progressBar/mana") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "mana")
        }
        subscriptionIDs.append(manaID)
        logger.debug("Subscribed to metadata/progressBar/mana events with ID: \(manaID)")

        // Subscribe to stamina events
        let staminaID = await eventBus.subscribe("metadata/progressBar/stamina") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "stamina")
        }
        subscriptionIDs.append(staminaID)
        logger.debug("Subscribed to metadata/progressBar/stamina events with ID: \(staminaID)")

        // Subscribe to spirit events
        let spiritID = await eventBus.subscribe("metadata/progressBar/spirit") { [weak self] (tag: GameTag) in
            await self?.handleProgressBarEvent(tag, expectedID: "spirit")
        }
        subscriptionIDs.append(spiritID)
        logger.debug("Subscribed to metadata/progressBar/spirit events with ID: \(spiritID)")

        // Subscribe to mind events
        let mindID = await eventBus.subscribe("metadata/progressBar/mindState") { [weak self] tag in
            await self?.handleMindEvent(tag)
        }
        subscriptionIDs.append(mindID)
        logger.debug("Subscribed to metadata/progressBar/mindState events with ID: \(mindID)")

        // Subscribe to stance events
        let stanceID = await eventBus.subscribe("metadata/progressBar/pbarStance") { [weak self] tag in
            await self?.handleStanceEvent(tag)
        }
        subscriptionIDs.append(stanceID)
        logger.debug("Subscribed to metadata/progressBar/pbarStance events with ID: \(stanceID)")

        // Subscribe to encumbrance events
        let encumID = await eventBus.subscribe("metadata/progressBar/encumlevel") { [weak self] tag in
            await self?.handleEncumbranceEvent(tag)
        }
        subscriptionIDs.append(encumID)
        logger.debug("Subscribed to metadata/progressBar/encumlevel events with ID: \(encumID)")
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
            logger.debug("Ignoring progressBar with wrong ID for \(expectedID), got: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // DEBUG: Log raw tag data
        logger.debug("Processing \(expectedID) - Raw attrs: \(tag.attrs)")

        // Extract both percentage and text
        let data = extractVitalData(from: tag)

        // Update appropriate properties
        switch expectedID {
        case "health":
            health = data.percentage
            healthText = data.text
            logger.debug("✓ Updated health: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "mana":
            mana = data.percentage
            manaText = data.text
            logger.debug("✓ Updated mana: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "stamina":
            stamina = data.percentage
            staminaText = data.text
            logger.debug("✓ Updated stamina: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "spirit":
            spirit = data.percentage
            spiritText = data.text
            logger.debug("✓ Updated spirit: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
        case "mindState":
            mind = data.percentage
            mindText = data.text
            logger.debug("✓ Updated mind: \(data.percentage?.description ?? "nil"), text: \(data.text ?? "nil")")
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
        var text = tag.attrs["text"]

        // Clean text: extract ONLY the numeric fraction (e.g., "74/74"), strip any label prefix
        // Server might send contaminated text like "Health 74/74" but we only want "74/74"
        if let rawText = text, rawText.contains("/") {
            if let range = rawText.range(of: VitalPattern.fraction, options: .regularExpression) {
                text = String(rawText[range])  // Extract just "74/74" part
                logger.debug("Cleaned text from '\(rawText)' to '\(text!)'")
            }
        }

        // Try getting value attribute for percentage
        if let valueString = tag.attrs["value"],
           let value = Int(valueString),
           value > 1 {
            // Valid percentage provided by server
            logger.debug("Using server-provided percentage: \(value)")
            return (percentage: value, text: text)
        }

        // Server bug workaround: value is 0 or 1, try calculating from fraction
        if let text = text, text.contains("/") {
            // Parse the cleaned fraction to calculate percentage
            if let match = text.firstMatch(of: /(\d+)\s*\/\s*(\d+)/) {
                let current = Int(match.1) ?? 0
                let max = Int(match.2) ?? 1

                guard max > 0 else {
                    logger.warning("Zero denominator in fraction: \(text)")
                    return (percentage: nil, text: text)
                }

                // Calculate percentage from fraction
                let percentage = Int(round(Double(current) / Double(max) * 100.0))
                logger.debug("Calculated percentage from fraction \(current)/\(max): \(percentage)%")
                return (percentage: percentage, text: text)
            }
        }

        // No valid percentage data available - indeterminate state
        logger.debug("No valid percentage data, returning indeterminate state")
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
            logger.debug("Ignoring progressBar with wrong ID for stance, got: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // DEBUG: Log raw tag data
        logger.debug("Processing stance - Raw attrs: \(tag.attrs)")

        // Extract text and take first word
        if let text = tag.attrs["text"] {
            let firstWord = text.split(separator: " ").first.map(String.init) ?? text
            stance = firstWord
            logger.debug("✓ Updated stance: \(firstWord)")
        } else {
            // No text - use empty string
            stance = ""
            logger.debug("⚠️ Stance text missing, using empty string")
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
            logger.debug("Ignoring progressBar with wrong ID for encumbrance, got: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // DEBUG: Log raw tag data
        logger.debug("Processing encumbrance - Raw attrs: \(tag.attrs)")

        // Extract text and convert to lowercase
        if let text = tag.attrs["text"] {
            encumbrance = text.lowercased()
            logger.debug("✓ Updated encumbrance: \(text.lowercased())")
        } else {
            // No text - use empty string
            encumbrance = ""
            logger.debug("⚠️ Encumbrance text missing, using empty string")
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
            logger.debug("Ignoring progressBar with wrong ID for mind, got: \(tag.attrs["id"] ?? "nil")")
            return
        }

        // DEBUG: Log raw tag data
        logger.debug("Processing mind - Raw attrs: \(tag.attrs)")

        // Extract percentage from value attribute
        if let valueString = tag.attrs["value"],
           let value = Int(valueString) {
            mind = value
        } else {
            mind = nil
        }

        // Extract text directly (no parsing, no splitting)
        mindText = tag.attrs["text"]

        logger.debug("✓ Updated mind: \(self.mind?.description ?? "nil"), text: \(self.mindText ?? "nil")")
    }
}
