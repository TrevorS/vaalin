// ABOUTME: ThemeManager loads and manages color themes for game text and UI elements

import Foundation
import SwiftUI

/// Represents a complete color theme with palette, preset, category, and semantic color mappings
public struct Theme: Codable, Sendable {
    /// Theme display name
    public let name: String

    /// Base color palette (e.g., Catppuccin Mocha 26-color palette)
    public let palette: [String: String]

    /// Preset ID to palette color mappings (e.g., "speech" → "green")
    public let presets: [String: String]

    /// Item category to palette color mappings (e.g., "weapon" → "red")
    public let categories: [String: String]

    /// UI semantic color mappings (e.g., "success" → "green")
    public let semantic: [String: String]

    public init(
        name: String,
        palette: [String: String],
        presets: [String: String],
        categories: [String: String],
        semantic: [String: String]
    ) {
        self.name = name
        self.palette = palette
        self.presets = presets
        self.categories = categories
        self.semantic = semantic
    }
}

/// Thread-safe theme manager for loading themes and providing color lookups
public actor ThemeManager {
    /// Cached color conversions for performance (hex string → SwiftUI Color)
    private var colorCache: [String: Color] = [:]

    public init() {}

    /// Load theme from JSON data
    /// - Parameter data: JSON data representing a Theme
    /// - Returns: Parsed Theme object
    /// - Throws: DecodingError if JSON is malformed
    public func loadTheme(from data: Data) async throws -> Theme {
        let decoder = JSONDecoder()
        return try decoder.decode(Theme.self, from: data)
    }

    /// Get color for a preset ID (e.g., "speech", "damage")
    /// - Parameters:
    ///   - presetID: Preset identifier from game XML
    ///   - theme: Theme containing preset mappings
    /// - Returns: SwiftUI Color if found, nil otherwise
    public func color(forPreset presetID: String, theme: Theme) async -> Color? {
        guard let paletteKey = theme.presets[presetID] else {
            return nil
        }
        return await resolveColor(paletteKey: paletteKey, palette: theme.palette)
    }

    /// Get color for an item category (e.g., "weapon", "gem")
    /// - Parameters:
    ///   - category: Item category identifier
    ///   - theme: Theme containing category mappings
    /// - Returns: SwiftUI Color if found, nil otherwise
    public func color(forCategory category: String, theme: Theme) async -> Color? {
        guard let paletteKey = theme.categories[category] else {
            return nil
        }
        return await resolveColor(paletteKey: paletteKey, palette: theme.palette)
    }

    /// Get semantic UI color (e.g., "success", "warning", "danger", "info")
    /// - Parameters:
    ///   - semantic: Semantic color identifier
    ///   - theme: Theme containing semantic mappings
    /// - Returns: SwiftUI Color if found, nil otherwise
    public func semanticColor(for semantic: String, theme: Theme) async -> Color? {
        guard let paletteKey = theme.semantic[semantic] else {
            return nil
        }
        return await resolveColor(paletteKey: paletteKey, palette: theme.palette)
    }

    // MARK: - Private Helpers

    /// Resolve a palette key to a SwiftUI Color
    /// - Parameters:
    ///   - paletteKey: Key in theme palette (e.g., "green", "red")
    ///   - palette: Theme palette dictionary
    /// - Returns: SwiftUI Color if hex value found and valid, nil otherwise
    private func resolveColor(paletteKey: String, palette: [String: String]) async -> Color? {
        guard let hexString = palette[paletteKey] else {
            return nil
        }

        // Check cache first
        if let cachedColor = colorCache[hexString] {
            return cachedColor
        }

        // Convert hex to Color
        guard let color = Color(hex: hexString) else {
            return nil
        }

        // Cache for future lookups
        colorCache[hexString] = color
        return color
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    /// Create a SwiftUI Color from a hex string
    /// - Parameter hex: Hex color string (e.g., "#f38ba8", "f38ba8", "#FFF")
    /// - Returns: SwiftUI Color if valid hex, nil otherwise
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        // Handle different hex formats
        let length = hex.count
        guard length == 3 || length == 6 || length == 8 else {
            return nil
        }

        // Expand 3-char hex to 6-char (e.g., "FFF" → "FFFFFF")
        let expandedHex: String
        if length == 3 {
            expandedHex = hex.map { "\($0)\($0)" }.joined()
        } else {
            expandedHex = hex
        }

        // Parse hex components
        guard let rgb = Int(expandedHex.prefix(6), radix: 16) else {
            return nil
        }

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        // Parse alpha if present (8-char hex)
        let alpha: Double
        if expandedHex.count == 8 {
            guard let alphaValue = Int(expandedHex.suffix(2), radix: 16) else {
                return nil
            }
            alpha = Double(alphaValue) / 255.0
        } else {
            alpha = 1.0
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
