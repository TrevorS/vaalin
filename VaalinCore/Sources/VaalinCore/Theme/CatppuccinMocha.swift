// ABOUTME: Centralized Catppuccin Mocha color palette for consistent theming across Vaalin

import SwiftUI

/// Catppuccin Mocha color palette for Vaalin UI theming.
///
/// This enum provides a centralized, single source of truth for all 26 Catppuccin Mocha colors
/// used throughout the application. By consolidating color definitions here, we ensure:
///
/// - **Consistency**: All panels use the exact same color values
/// - **Maintainability**: Theme changes only need to be made in one place
/// - **Type safety**: Compile-time checking for color usage
/// - **Documentation**: Clear mapping of semantic names to hex values
///
/// ## Architecture
///
/// **Theme Framework** (Catppuccin Mocha):
/// - 14 Accent Colors: rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green,
///   teal, sky, sapphire, blue, lavender
/// - 12 Neutral Colors: text, subtext1, subtext0, overlay2, overlay1, overlay0, surface2,
///   surface1, surface0, base, mantle, crust
///
/// **Semantic Aliases** (Application Layer):
/// - `healthCritical`, `healthMedium`, `healthHigh` - Severity colors mapped to red/yellow/green
/// - `mana`, `stamina`, `spirit`, `mind` - Vital-specific colors mapped to Catppuccin colors
///
/// ## Severity Thresholds
///
/// The `Severity` nested struct defines percentage thresholds for color selection:
/// - Below 33%: Critical (use `healthCritical` → red)
/// - 33-67%: Medium (use `peach`)
/// - Above 67%: High (use `healthHigh` → green)
///
/// ## Example Usage
///
/// ```swift
/// // Using theme framework colors
/// Text("Custom UI Element")
///     .foregroundStyle(CatppuccinMocha.lavender)
///
/// // Using semantic aliases for vitals
/// Text("Health: 25%")
///     .foregroundStyle(CatppuccinMocha.healthCritical)  // Maps to red
///
/// // Using severity helper
/// let healthPercent = 45
/// let color = CatppuccinMocha.severityColor(for: healthPercent)  // Returns peach
/// ```
///
/// ## Reference
///
/// Based on the Catppuccin Mocha palette: https://github.com/catppuccin/catppuccin
/// Hex values match the official Catppuccin specification for consistency with other tooling.
public enum CatppuccinMocha {
    // MARK: - Catppuccin Mocha Palette (Theme Framework)

    // MARK: Accent Colors

    /// Rosewater - #f5e0dc
    public static let rosewater = Color(red: 0.961, green: 0.878, blue: 0.863)

    /// Flamingo - #f2cdcd
    public static let flamingo = Color(red: 0.949, green: 0.804, blue: 0.804)

    /// Pink - #f5c2e7
    public static let pink = Color(red: 0.961, green: 0.761, blue: 0.906)

    /// Mauve - #cba6f7
    public static let mauve = Color(red: 0.796, green: 0.651, blue: 0.969)

    /// Red - #f38ba8
    public static let red = Color(red: 0.953, green: 0.545, blue: 0.659)

    /// Maroon - #eba0ac
    public static let maroon = Color(red: 0.922, green: 0.627, blue: 0.675)

    /// Peach - #fab387
    public static let peach = Color(red: 0.980, green: 0.702, blue: 0.529)

    /// Yellow - #f9e2af
    public static let yellow = Color(red: 0.976, green: 0.886, blue: 0.686)

    /// Green - #a6e3a1
    public static let green = Color(red: 0.651, green: 0.890, blue: 0.631)

    /// Teal - #94e2d5
    public static let teal = Color(red: 0.580, green: 0.886, blue: 0.835)

    /// Sky - #89dceb
    public static let sky = Color(red: 0.537, green: 0.863, blue: 0.922)

    /// Sapphire - #74c7ec
    public static let sapphire = Color(red: 0.455, green: 0.780, blue: 0.925)

    /// Blue - #89b4fa
    public static let blue = Color(red: 0.537, green: 0.706, blue: 0.980)

    /// Lavender - #b4befe
    public static let lavender = Color(red: 0.706, green: 0.745, blue: 0.996)

    // MARK: Neutral Colors

    /// Text - #cdd6f4 (Primary text color)
    public static let text = Color(red: 0.803, green: 0.843, blue: 0.957)

    /// Subtext1 - #bac2de
    public static let subtext1 = Color(red: 0.729, green: 0.761, blue: 0.871)

    /// Subtext0 - #a6adc8
    public static let subtext0 = Color(red: 0.651, green: 0.678, blue: 0.784)

    /// Overlay2 - #9399b2
    public static let overlay2 = Color(red: 0.576, green: 0.600, blue: 0.698)

    /// Overlay1 - #7f849c
    public static let overlay1 = Color(red: 0.498, green: 0.518, blue: 0.612)

    /// Overlay0 - #6c7086
    public static let overlay0 = Color(red: 0.424, green: 0.439, blue: 0.525)

    /// Surface2 - #585b70
    public static let surface2 = Color(red: 0.345, green: 0.357, blue: 0.439)

    /// Surface1 - #45475a
    public static let surface1 = Color(red: 0.271, green: 0.278, blue: 0.353)

    /// Surface0 - #313244
    public static let surface0 = Color(red: 0.192, green: 0.196, blue: 0.267)

    /// Base - #1e1e2e (Primary background)
    public static let base = Color(red: 0.118, green: 0.118, blue: 0.180)

    /// Mantle - #181825
    public static let mantle = Color(red: 0.094, green: 0.094, blue: 0.145)

    /// Crust - #11111b
    public static let crust = Color(red: 0.067, green: 0.067, blue: 0.106)

    // MARK: - Semantic Aliases (Application Layer)

    /// Critical severity color - Maps to `red`
    ///
    /// Used for:
    /// - Health below 33%
    /// - Severe injuries (rank 3)
    /// - Spell timers below 33%
    public static let healthCritical = red

    /// Medium severity color - Maps to `yellow`
    ///
    /// Used for:
    /// - Health 33-67% (when yellow is appropriate)
    /// - Stamina vital
    /// - Minor injuries (rank 1)
    ///
    /// **Note**: Use `peach` (orange) for moderate injuries (rank 2) and spell timers 33-67%
    public static let healthMedium = yellow

    /// High severity color - Maps to `green`
    ///
    /// Used for:
    /// - Health above 67%
    /// - Spell timers above 67%
    public static let healthHigh = green

    /// Mana vital color - Maps to `blue`
    public static let mana = blue

    /// Stamina vital color - Maps to `yellow`
    ///
    /// Reuses `healthMedium` for consistency.
    public static let stamina = healthMedium

    /// Spirit vital color - Maps to `mauve`
    public static let spirit = mauve

    /// Mind vital color - Maps to `teal`
    public static let mind = teal

    // MARK: - Severity Thresholds

    /// Severity threshold constants for percentage-based color selection.
    ///
    /// These thresholds determine which severity color to use based on a percentage value:
    /// - `< critical` (< 33%): Use `healthCritical` (red)
    /// - `< medium` (33-67%): Use `peach` (orange)
    /// - `>= medium` (> 67%): Use `healthHigh` (green)
    public struct Severity {
        /// Critical threshold - Below this percentage is critical (red)
        public static let critical = 33

        /// Medium threshold - Below this percentage is medium (orange)
        public static let medium = 67

        // Note: Above medium threshold (>= 67) is considered high (green)
    }

    // MARK: - Visual Constants

    /// Visual constants for UI elements.
    ///
    /// This namespace provides centralized constants for visual properties that use
    /// the Catppuccin Mocha color palette. By consolidating these values here, we ensure
    /// consistency across all UI components.
    public struct Visual {
        /// Opacity for scar indicators in InjuriesPanel (50% of injury color)
        ///
        /// Used to differentiate scars from active injuries by reducing color intensity.
        public static let scarOpacity: CGFloat = 0.5
    }

    // MARK: - Helper Methods

    /// Returns the appropriate severity color for a given percentage.
    ///
    /// This helper method encapsulates the severity color selection logic used throughout
    /// the application for vitals, injuries, and spell timers.
    ///
    /// - Parameter percentage: Optional percentage value (0-100), or nil for default
    /// - Returns: Color corresponding to severity level:
    ///   - `< 33%`: Red (`healthCritical`)
    ///   - `33-67%`: Orange (`peach`)
    ///   - `> 67%` or `nil`: Green (`healthHigh`)
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // In VitalsPanel
    /// Text("Health")
    ///     .foregroundStyle(CatppuccinMocha.severityColor(for: healthPercent))
    ///
    /// // In SpellsPanel
    /// Text(spell.timeRemaining)
    ///     .foregroundStyle(CatppuccinMocha.severityColor(for: spell.percentRemaining))
    /// ```
    public static func severityColor(for percentage: Int?) -> Color {
        guard let percentage = percentage else {
            return healthHigh  // Default to green when no percentage provided
        }

        if percentage < Severity.critical {
            return healthCritical  // Red for critical (< 33%)
        } else if percentage < Severity.medium {
            return peach  // Orange for medium (33-67%)
        } else {
            return healthHigh  // Green for high (> 67%)
        }
    }
}
