// ABOUTME: ActiveSpell represents an active spell or effect with optional duration and percentage tracking

import Foundation

/// Represents an active spell or effect with optional duration and percentage tracking.
///
/// Active spells are displayed in the spells panel and can have:
/// - A unique identifier (GemStone IV spell number, required)
/// - A display name (required)
/// - Optional time remaining (e.g., "14:32")
/// - Optional percentage remaining (0-100)
///
/// ## GemStone IV Spell IDs
///
/// Spell IDs are numeric strings representing the spell's number in GemStone IV:
/// - 100s: Minor Spiritual (e.g., "107" = Spirit Warding I)
/// - 200s: Major Spiritual (e.g., "202" = Spirit Shield)
/// - 300s: Cleric Base (e.g., "303" = Prayer of Protection)
/// - 400s: Minor Elemental (e.g., "401" = Elemental Defense I)
/// - 500s: Major Elemental (e.g., "506" = Haste)
/// - 900s: Wizard Base (e.g., "901" = Minor Shock)
/// - 1700s: Wizard Advanced (e.g., "1720" = Permanence)
///
/// ## Example Server Data
///
/// ```xml
/// <progressBar id="202" text="Spirit Shield" time="14:32" value="85" />
/// ```
///
/// This creates:
/// ```swift
/// ActiveSpell(
///     id: "202",
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
///     id: "1720",
///     name: "Permanence",
///     timeRemaining: nil,
///     percentRemaining: nil
/// )
/// ```
public struct ActiveSpell: Identifiable, Equatable, Sendable {
    /// GemStone IV spell number (e.g., "202", "506", "1720")
    ///
    /// This is the numeric spell ID from GemStone IV, provided by the server
    /// in the progressBar id attribute. Used for sorting and display.
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
