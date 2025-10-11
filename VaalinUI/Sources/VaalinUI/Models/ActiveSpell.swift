// ABOUTME: ActiveSpell represents an active spell or effect with optional duration and percentage tracking

import Foundation

/// Represents an active spell or effect with optional duration and percentage tracking.
///
/// Active spells are displayed in the spells panel and can have:
/// - A unique identifier (required)
/// - A display name (required)
/// - Optional time remaining (e.g., "14:32")
/// - Optional percentage remaining (0-100)
///
/// ## Example Server Data
///
/// ```xml
/// <progressBar id="spell123" text="Spirit Shield" time="14:32" value="85" />
/// ```
///
/// This creates:
/// ```swift
/// ActiveSpell(
///     id: "spell123",
///     name: "Spirit Shield",
///     timeRemaining: "14:32",
///     percentRemaining: 85
/// )
/// ```
///
/// ## Permanent Effects
///
/// Some effects are permanent or indefinite and lack time/percentage:
/// ```swift
/// ActiveSpell(
///     id: "spell456",
///     name: "Permanence",
///     timeRemaining: nil,
///     percentRemaining: nil
/// )
/// ```
public struct ActiveSpell: Identifiable, Equatable, Sendable {
    /// Unique identifier for the spell (from server's progressBar id attribute)
    public let id: String

    /// Display name of the spell or effect
    public let name: String

    /// Optional time remaining (e.g., "14:32", "0:45")
    ///
    /// Stored as-is from server without parsing. Format can vary.
    /// `nil` indicates a permanent or indefinite effect.
    public let timeRemaining: String?

    /// Optional percentage remaining (0-100)
    ///
    /// Used to display progress bar for spell duration.
    /// `nil` indicates no percentage tracking available.
    public let percentRemaining: Int?

    /// Creates a new ActiveSpell instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the spell
    ///   - name: Display name of the spell
    ///   - timeRemaining: Optional time remaining string (e.g., "14:32")
    ///   - percentRemaining: Optional percentage remaining (0-100)
    public init(id: String, name: String, timeRemaining: String? = nil, percentRemaining: Int? = nil) {
        self.id = id
        self.name = name
        self.timeRemaining = timeRemaining
        self.percentRemaining = percentRemaining
    }
}
