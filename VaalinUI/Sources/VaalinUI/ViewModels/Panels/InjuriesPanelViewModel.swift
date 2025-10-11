// ABOUTME: InjuriesPanelViewModel manages injuries panel state with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the injuries panel with real-time updates from EventBus.
///
/// `InjuriesPanelViewModel` subscribes to `metadata/dialogData` events from the EventBus
/// and updates injuries state when the game server sends injuries dialog updates. The injuries panel
/// displays body part injuries and scars with severity levels 1-3.
///
/// ## Protocol Discovery
///
/// Based on expert analysis of Illthorn reference implementation and GemStone IV protocol,
/// the injuries window uses **ONLY `<image>` tags**, not progressBar/radio/label widgets.
///
/// ## Actual Server XML
///
/// ```xml
/// <dialogData id="injuries">
///     <image id="head" name="Injury3"/>        <!-- injury severity 3 -->
///     <image id="leftArm" name="Scar1"/>       <!-- scar severity 1 -->
///     <image id="chest" name="chest"/>         <!-- healthy (name==id) -->
///     <image id="healthSkin" name="healthBar2"/> <!-- ignore this -->
/// </dialogData>
/// ```
///
/// ## Image Tag Patterns
///
/// - **Injury**: `name="Injury1"`, `name="Injury2"`, `name="Injury3"`
/// - **Scar**: `name="Scar1"`, `name="Scar2"`, `name="Scar3"`
/// - **Healthy**: `name == id` (e.g., `<image id="head" name="head"/>`)
/// - **Filter**: Ignore `<image id="healthSkin" .../>`  (mannequin sprite, not body part)
///
/// ## Key Rules
///
/// 1. **Only `<image>` tags** - No progressBar, no radio, no label
/// 2. **Injury vs Scar are mutually exclusive** - Not separate boolean flags
/// 3. **Severity in name**: Extract number from `"Injury1"` / `"Scar2"` patterns
/// 4. **Healthy state**: `name == id` means no injury (severity 0, type .none)
/// 5. **Filter healthSkin**: Must ignore `<image id="healthSkin" .../>` sprite
/// 6. **Severity range**: 1-3 (not 0-4)
///
/// ## EventBus Integration
///
/// Subscribes to `"metadata/dialogData"` event on initialization.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with child `<image>` tags:
/// ```swift
/// GameTag(
///     name: "dialogData",
///     text: nil,
///     attrs: ["id": "injuries"],
///     children: [
///         GameTag(name: "image", attrs: ["id": "head", "name": "Injury3"], state: .closed),
///         GameTag(name: "image", attrs: ["id": "chest", "name": "chest"], state: .closed),
///     ],
///     state: .closed
/// )
/// ```
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
/// let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
/// await viewModel.setup()  // Required!
///
/// // Display in SwiftUI view
/// InjuriesPanel(viewModel: viewModel)
///
/// // The parser will publish injuries events:
/// let dialogTag = GameTag(
///     name: "dialogData",
///     attrs: ["id": "injuries"],
///     children: [
///         GameTag(name: "image", attrs: ["id": "head", "name": "Injury3"], state: .closed)
///     ],
///     state: .closed
/// )
/// await eventBus.publish("metadata/dialogData", data: dialogTag)
///
/// // SwiftUI view automatically updates with new head injury
/// print(viewModel.injuries[.head]?.severity)  // 3
/// print(viewModel.injuries[.head]?.injuryType)  // .injury
/// ```
@Observable
@MainActor
public final class InjuriesPanelViewModel {
    // MARK: - Properties

    /// Current injuries by body part (all parts default to .none severity)
    ///
    /// Updated automatically when `metadata/dialogData` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    /// All `BodyPart` cases are present in the dictionary at all times.
    public var injuries: [BodyPart: InjuryStatus] = {
        var dict: [BodyPart: InjuryStatus] = [:]
        for bodyPart in BodyPart.allCases {
            dict[bodyPart] = InjuryStatus()
        }
        return dict
    }()

    // MARK: - Computed Status Properties

    /// Total count of injured body parts (excludes healthy parts)
    ///
    /// Returns the number of body parts with active injuries or scars.
    /// Used by status area to display "X wounds" text.
    public var injuryCount: Int {
        injuries.values.filter { $0.isInjured }.count
    }

    /// True if all body parts are healthy (no injuries or scars)
    ///
    /// Returns true when all body parts have severity 0 and type .none.
    /// Used by status area to display "Healthy" text.
    public var isHealthy: Bool {
        injuries.values.allSatisfy { !$0.isInjured }
    }

    /// True if nervous system is damaged
    ///
    /// Returns true when nerves have any injury or scar (severity > 0).
    /// Used by status area to display nervous system warning.
    public var hasNervousDamage: Bool {
        guard let nervesStatus = injuries[.nerves] else { return false }
        return nervesStatus.isInjured
    }

    /// Nervous system injury severity (0 if not injured)
    ///
    /// Returns the severity level (1-3) of nervous system damage, or 0 if healthy.
    /// Used by status area to colorize the nervous system warning.
    public var nervousSeverity: Int {
        guard let nervesStatus = injuries[.nerves] else { return 0 }
        return nervesStatus.severity
    }

    /// EventBus reference for subscribing to injuries events
    private let eventBus: EventBus

    /// Subscription ID for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handlers use weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var subscriptionID: EventBus.SubscriptionID?

    /// Logger for InjuriesPanelViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "InjuriesPanelViewModel")

    // MARK: - Initialization

    /// Creates a new InjuriesPanelViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to injuries events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscriptions happen in setup() method
    }

    /// Sets up EventBus subscriptions to injuries events.
    ///
    /// **Must be called immediately after init** to enable injuries updates.
    /// In production code, this is typically called in the view's `onAppear` or
    /// similar lifecycle method.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        // Subscribe to dialogData events
        subscriptionID = await eventBus.subscribe("metadata/dialogData") { [weak self] (tag: GameTag) in
            await self?.handleDialogDataEvent(tag)
        }
        logger.debug("Subscribed to metadata/dialogData events with ID: \(self.subscriptionID!)")
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

        if let id = subscriptionID {
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming dialogData events from EventBus
    ///
    /// - Parameter tag: GameTag containing injuries dialog image data
    ///
    /// Parses child `<image>` tags to extract injury type and severity.
    /// Resets all injuries to default state before applying updates (handles healing).
    ///
    /// ## Image Tag Parsing:
    /// - `<image id="head" name="Injury3"/>` → Sets head injury severity 3
    /// - `<image id="chest" name="Scar1"/>` → Sets chest scar severity 1
    /// - `<image id="neck" name="neck"/>` → Sets neck to healthy (name == id)
    /// - `<image id="healthSkin" .../>` → Ignored (mannequin sprite)
    @MainActor
    private func handleDialogDataEvent(_ tag: GameTag) {
        // Only process tags named "dialogData"
        guard tag.name == "dialogData" else {
            logger.debug("Ignoring non-dialogData tag: \(tag.name)")
            return
        }

        // Only process injuries dialog (filter other dialogs like spells, familiar, etc.)
        // The injuries dialog has id="injuries" attribute
        guard tag.attrs["id"] == "injuries" else {
            logger.debug("Ignoring non-injuries dialogData (id=\(tag.attrs["id"] ?? "nil"))")
            return
        }

        // Reset all injuries to default state (handles healing)
        resetInjuries()

        // Parse all child image tags
        for child in tag.children where child.name == "image" {
            parseInjuryImage(child)
        }

        logger.debug("Updated injuries state from dialogData")
    }

    /// Resets all injuries to default state
    ///
    /// Called at the start of each dialogData event to ensure clean state.
    /// Handles the case where injuries are healed and no longer present in the dialog.
    @MainActor
    private func resetInjuries() {
        // Reset all body parts to .none severity
        for bodyPart in BodyPart.allCases {
            injuries[bodyPart] = InjuryStatus()
        }
    }

    /// Parses image tag to extract injury type and severity
    ///
    /// - Parameter tag: GameTag containing image data
    ///
    /// Extracts `id` (body part) and `name` (injury pattern).
    ///
    /// ## Parsing Rules:
    /// 1. Filter `healthSkin` sprite: `id == "healthSkin"` → skip
    /// 2. Map `id` to `BodyPart` enum (fail if unknown)
    /// 3. Parse `name` attribute:
    ///    - `name == id` → Healthy state (severity 0, type .none)
    ///    - `name.hasPrefix("Injury")` → Extract severity from "Injury1" / "Injury2" / "Injury3"
    ///    - `name.hasPrefix("Scar")` → Extract severity from "Scar1" / "Scar2" / "Scar3"
    ///
    /// ## Examples:
    /// ```xml
    /// <image id="head" name="Injury3"/>  → injuries[.head] = InjuryStatus(.injury, 3)
    /// <image id="chest" name="Scar1"/>   → injuries[.chest] = InjuryStatus(.scar, 1)
    /// <image id="neck" name="neck"/>     → injuries[.neck] = InjuryStatus(.none, 0)
    /// <image id="healthSkin" name="healthBar2"/>  → ignored
    /// ```
    @MainActor
    private func parseInjuryImage(_ tag: GameTag) {
        guard let imageId = tag.attrs["id"],
              let imageName = tag.attrs["name"] else {
            logger.warning("Image tag missing id or name attribute")
            return
        }

        // Filter healthSkin sprite (mannequin image, not a body part)
        if imageId == "healthSkin" {
            return
        }

        // Map to BodyPart enum
        guard let bodyPart = BodyPart(rawValue: imageId) else {
            logger.debug("Unknown body part ID: \(imageId)")
            return
        }

        // Healthy state: name == id
        if imageName == imageId {
            injuries[bodyPart] = InjuryStatus(injuryType: .none, severity: 0)
            logger.debug("Set \(imageId) to healthy state")
            return
        }

        // Parse Injury pattern (Injury1, Injury2, Injury3)
        if imageName.hasPrefix("Injury") {
            let severityStr = imageName.dropFirst(6)  // Drop "Injury" prefix
            let severity = Int(severityStr) ?? 1
            injuries[bodyPart] = InjuryStatus(injuryType: .injury, severity: severity)
            logger.debug("Set \(imageId) injury severity to \(severity)")
            return
        }

        // Parse Scar pattern (Scar1, Scar2, Scar3)
        if imageName.hasPrefix("Scar") {
            let severityStr = imageName.dropFirst(4)  // Drop "Scar" prefix
            let severity = Int(severityStr) ?? 1
            injuries[bodyPart] = InjuryStatus(injuryType: .scar, severity: severity)
            logger.debug("Set \(imageId) scar severity to \(severity)")
            return
        }

        // Unknown pattern - log and ignore
        logger.warning("Unknown image name pattern for \(imageId): \(imageName)")
    }
}
