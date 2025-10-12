// ABOUTME: Centralized Catppuccin Mocha color palette for consistent theming across Vaalin

import SwiftUI

/// Catppuccin Mocha color palette for Vaalin UI theming.
///
/// This enum provides a centralized, single source of truth for all Catppuccin Mocha colors
/// used throughout the application. By consolidating color definitions here, we ensure:
///
/// - **Consistency**: All panels use the exact same color values
/// - **Maintainability**: Theme changes only need to be made in one place
/// - **Type safety**: Compile-time checking for color usage
/// - **Documentation**: Clear mapping of semantic names to hex values
///
/// ## Color Categories
///
/// **Base Colors:**
/// - `text`: Primary text color (#cdd6f4) - Used for readable content
///
/// **Severity Colors:**
/// Used by VitalsPanel, InjuriesPanel, and SpellsPanel to indicate health/status levels:
/// - `healthCritical`: Red (#f38ba8) - Critical health or severe injuries
/// - `healthMedium`: Yellow (#f9e2af) - Medium health or moderate injuries
/// - `healthHigh`: Green (#a6e3a1) - High health or minor injuries
///
/// **Vital-Specific Colors:**
/// Used by VitalsPanel for different vital types:
/// - `mana`: Blue (#89b4fa) - Mana/magic power
/// - `stamina`: Yellow (#f9e2af) - Physical endurance (reuses healthMedium)
/// - `spirit`: Purple (#cba6f7) - Spiritual energy
/// - `mind`: Teal (#94e2d5) - Mental focus
///
/// ## Severity Thresholds
///
/// The `Severity` nested struct defines percentage thresholds for color selection:
/// - Below 33%: Critical (use `healthCritical`)
/// - 33-67%: Medium (use `healthMedium`)
/// - Above 67%: High (use `healthHigh`)
///
/// ## Example Usage
///
/// ```swift
/// // In a panel view
/// Text("Health: 25%")
///     .foregroundStyle(CatppuccinMocha.healthCritical)
///
/// // With severity logic
/// let healthPercent = 45
/// let color = healthPercent < CatppuccinMocha.Severity.critical
///     ? CatppuccinMocha.healthCritical
///     : healthPercent < CatppuccinMocha.Severity.medium
///     ? CatppuccinMocha.healthMedium
///     : CatppuccinMocha.healthHigh
/// ```
///
/// ## Reference
///
/// Based on the Catppuccin Mocha palette: https://github.com/catppuccin/catppuccin
/// Hex values match the official Catppuccin specification for consistency with other tooling.
public enum CatppuccinMocha {
    // MARK: - Base Colors

    /// Primary text color - #cdd6f4
    ///
    /// Used for readable content throughout the application.
    public static let text = Color(red: 0.803, green: 0.843, blue: 0.957)

    // MARK: - Severity Colors

    /// Critical severity color - Red #f38ba8
    ///
    /// Used for:
    /// - Health below 33%
    /// - Severe injuries (rank 3)
    /// - Spell timers below 33%
    public static let healthCritical = Color(red: 0.953, green: 0.545, blue: 0.659)

    /// Medium severity color - Yellow #f9e2af
    ///
    /// Used for:
    /// - Health 33-67%
    /// - Moderate injuries (rank 2)
    /// - Spell timers 33-67%
    /// - Stamina vital
    public static let healthMedium = Color(red: 0.976, green: 0.886, blue: 0.686)

    /// High severity color - Green #a6e3a1
    ///
    /// Used for:
    /// - Health above 67%
    /// - Minor injuries (rank 1)
    /// - Spell timers above 67%
    public static let healthHigh = Color(red: 0.651, green: 0.890, blue: 0.631)

    // MARK: - Vital-Specific Colors

    /// Mana vital color - Blue #89b4fa
    public static let mana = Color(red: 0.537, green: 0.706, blue: 0.980)

    /// Stamina vital color - Yellow #f9e2af
    ///
    /// Reuses `healthMedium` for consistency.
    public static let stamina = healthMedium

    /// Spirit vital color - Purple #cba6f7
    public static let spirit = Color(red: 0.796, green: 0.651, blue: 0.969)

    /// Mind vital color - Teal #94e2d5
    public static let mind = Color(red: 0.580, green: 0.886, blue: 0.835)

    // MARK: - Severity Thresholds

    /// Severity threshold constants for percentage-based color selection.
    ///
    /// These thresholds determine which severity color to use based on a percentage value:
    /// - `< critical` (< 33%): Use `healthCritical` (red)
    /// - `< medium` (33-67%): Use `healthMedium` (yellow)
    /// - `>= medium` (> 67%): Use `healthHigh` (green)
    public struct Severity {
        /// Critical threshold - Below this percentage is critical (red)
        public static let critical = 33

        /// Medium threshold - Below this percentage is medium (yellow)
        public static let medium = 67

        // Note: Above medium threshold (>= 67) is considered high (green)
    }
}
