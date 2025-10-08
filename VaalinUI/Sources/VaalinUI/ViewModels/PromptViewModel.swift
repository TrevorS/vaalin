// ABOUTME: PromptViewModel manages prompt display with EventBus subscription for real-time updates

import Foundation
import Observation
import os
import VaalinCore

/// View model for the prompt display with real-time updates from EventBus.
///
/// `PromptViewModel` subscribes to `metadata/prompt` events from the EventBus and
/// updates the prompt text when the game server sends prompt changes. The prompt
/// is displayed above the command input field to show the current game state.
///
/// ## EventBus Integration
///
/// Subscribes to the `"metadata/prompt"` event on initialization. When the parser
/// emits prompt events (Issue #31), this view model receives them and updates the
/// `promptText` property, which SwiftUI views automatically observe.
///
/// ## Event Structure
///
/// The parser publishes `GameTag` events with the following structure:
/// ```swift
/// GameTag(
///     name: "prompt",
///     text: ">",  // The actual prompt text
///     attrs: [:],
///     children: [],
///     state: .closed
/// )
/// ```
///
/// ## Thread Safety
///
/// **IMPORTANT:** This class is isolated to MainActor. All public properties and methods
/// must be accessed from the main thread. The EventBus subscription handler runs on the
/// main thread via `@MainActor` isolation.
///
/// The `@Observable` macro provides property observation for SwiftUI reactivity.
///
/// ## Lifecycle Management
///
/// The view model unsubscribes from the EventBus on deinitialization to prevent
/// memory leaks and ensure proper cleanup when the view is dismissed.
///
/// ## Example Usage
///
/// ```swift
/// let eventBus = EventBus()
/// let viewModel = PromptViewModel(eventBus: eventBus)
///
/// // Display in SwiftUI view
/// PromptView(viewModel: viewModel)
///
/// // The parser will publish prompt events:
/// let promptTag = GameTag(name: "prompt", text: "You may now edit your spell.>", state: .closed)
/// await eventBus.publish("metadata/prompt", data: promptTag)
///
/// // SwiftUI view automatically updates with new prompt text
/// ```
@Observable
@MainActor
public final class PromptViewModel {
    // MARK: - Properties

    /// Current prompt text to display (default: ">")
    ///
    /// Updated automatically when `metadata/prompt` events are published to EventBus.
    /// SwiftUI views observing this property will automatically update when it changes.
    public var promptText: String = ">"

    /// EventBus reference for subscribing to prompt events
    private let eventBus: EventBus

    /// Subscription ID for cleanup on deinit
    /// Excluded from observation (not part of UI state) and marked nonisolated(unsafe)
    /// for access in deinit. Safe because handler uses weak self.
    @ObservationIgnored
    nonisolated(unsafe) private var subscriptionID: EventBus.SubscriptionID?

    /// Logger for PromptViewModel events and errors
    private let logger = Logger(subsystem: "org.trevorstrieber.vaalin", category: "PromptViewModel")

    // MARK: - Initialization

    /// Creates a new PromptViewModel with EventBus reference.
    ///
    /// - Parameter eventBus: EventBus actor for subscribing to `metadata/prompt` events
    ///
    /// **Important:** Call `setup()` immediately after initialization to subscribe to events.
    /// This two-step init pattern is necessary because Swift doesn't support async initialization
    /// for @MainActor classes with @Observable macro.
    public init(eventBus: EventBus) {
        self.eventBus = eventBus

        // Subscription happens in setup() method
    }

    /// Sets up EventBus subscription to prompt events.
    ///
    /// **Must be called immediately after init** to enable prompt updates.
    /// In production code, this is typically called in the view's `onAppear` or
    /// similar lifecycle method.
    ///
    /// ## Example Usage
    /// ```swift
    /// let viewModel = PromptViewModel(eventBus: eventBus)
    /// await viewModel.setup()  // Required!
    /// ```
    public func setup() async {
        subscriptionID = await eventBus.subscribe("metadata/prompt") { [weak self] (tag: GameTag) in
            await self?.handlePromptEvent(tag)
        }
        logger.debug("Subscribed to metadata/prompt events with ID: \(self.subscriptionID!)")
    }

    // MARK: - Deinitialization

    /// Unsubscribes from EventBus on deallocation
    ///
    /// **Note:** Cleanup happens asynchronously in a detached task. The subscription
    /// will be removed from EventBus after deinit completes. This is safe because
    /// the handler uses `weak self` and won't be called after deallocation.
    deinit {
        // Capture values for async cleanup
        if let id = subscriptionID {
            let bus = eventBus
            // Detached task to avoid actor isolation issues
            Task.detached {
                await bus.unsubscribe(id)
            }
        }
    }

    // MARK: - Private Methods

    /// Handles incoming prompt events from EventBus
    ///
    /// - Parameter tag: GameTag containing prompt text
    ///
    /// Updates `promptText` if the tag has the correct name and non-nil text.
    /// Ignores tags with wrong name or nil text to maintain previous prompt.
    @MainActor
    private func handlePromptEvent(_ tag: GameTag) {
        // Only process tags named "prompt"
        guard tag.name == "prompt" else {
            logger.debug("Ignoring non-prompt tag: \(tag.name)")
            return
        }

        // Only update if text is non-nil
        guard let newPrompt = tag.text else {
            logger.debug("Ignoring prompt event with nil text")
            return
        }

        // Update prompt text (SwiftUI will automatically observe this change)
        promptText = newPrompt
        logger.debug("Updated prompt text: \(newPrompt)")
    }
}
