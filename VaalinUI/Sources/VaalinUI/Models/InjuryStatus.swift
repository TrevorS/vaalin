// ABOUTME: InjuryStatus represents the injury state of a single body location

import Foundation

/// Contains the injury state for a single body part.
///
/// Populated from `<image>` tags in the injuries dialogData:
/// ```xml
/// <dialogData id="injuries">
///     <image id="head" name="Injury3"/>        <!-- injury severity 3 -->
///     <image id="leftArm" name="Scar1"/>       <!-- scar severity 1 -->
///     <image id="chest" name="chest"/>         <!-- healthy (name==id) -->
/// </dialogData>
/// ```
///
/// ## Severity Levels
///
/// - `0` - No injury (healthy state)
/// - `1` - Rank 1 wound (minor)
/// - `2` - Rank 2 wound (moderate)
/// - `3` - Rank 3 wound (severe)
///
/// ## Injury Types
///
/// - `.none` - No injury or scar (healthy)
/// - `.injury` - Fresh wound (Injury1, Injury2, Injury3)
/// - `.scar` - Healed wound (Scar1, Scar2, Scar3)
///
/// **IMPORTANT:** Injury and scar are mutually exclusive. A body part cannot have
/// both an active injury and a scar simultaneously.
///
/// ## Image Name Patterns
///
/// - `name="Injury1"` → `InjuryStatus(injuryType: .injury, severity: 1)`
/// - `name="Injury2"` → `InjuryStatus(injuryType: .injury, severity: 2)`
/// - `name="Injury3"` → `InjuryStatus(injuryType: .injury, severity: 3)`
/// - `name="Scar1"` → `InjuryStatus(injuryType: .scar, severity: 1)`
/// - `name="Scar2"` → `InjuryStatus(injuryType: .scar, severity: 2)`
/// - `name="Scar3"` → `InjuryStatus(injuryType: .scar, severity: 3)`
/// - `name="head"` (name == id) → `InjuryStatus(injuryType: .none, severity: 0)`
///
/// ## SwiftUI Integration
///
/// ```swift
/// struct BodyPartRow: View {
///     let status: InjuryStatus
///
///     var body: some View {
///         HStack {
///             if status.isInjured {
///                 if status.injuryType == .injury {
///                     InjuryIcon(severity: status.severity)
///                 } else {
///                     ScarIcon(severity: status.severity)
///                 }
///             }
///         }
///     }
/// }
/// ```
public struct InjuryStatus: Equatable, Sendable {
    /// Type of injury (none, injury, or scar)
    public var injuryType: InjuryType

    /// Severity level (0 = none/healthy, 1-3 = severity ranks)
    public var severity: Int

    /// Creates a new injury status with default values.
    ///
    /// - Parameters:
    ///   - injuryType: Type of injury (default: `.none`)
    ///   - severity: Severity level 0-3 (default: `0`)
    ///
    /// Severity values are automatically clamped to 0-3 range.
    public init(injuryType: InjuryType = .none, severity: Int = 0) {
        self.injuryType = injuryType
        self.severity = max(0, min(3, severity))  // Clamp to 0-3
    }

    /// Returns true if this location has an active injury or scar.
    ///
    /// - Returns: `true` if `injuryType != .none` and `severity > 0`
    public var isInjured: Bool {
        injuryType != .none && severity > 0
    }
}

/// Type of injury or wound on a body part.
///
/// Injury and scar are mutually exclusive - a body part can only have one type at a time.
public enum InjuryType: Equatable, Sendable {
    /// No injury (healthy state)
    case none

    /// Fresh wound (Injury1/2/3 image names)
    case injury

    /// Healed wound (Scar1/2/3 image names)
    case scar
}
