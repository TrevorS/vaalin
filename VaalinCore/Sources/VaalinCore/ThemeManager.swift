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

    /// Creates the default Catppuccin Mocha theme.
    ///
    /// Attempts to load from bundled JSON resource first, falls back to embedded JSON string
    /// if bundle loading fails (common in previews and tests).
    ///
    /// - Returns: Catppuccin Mocha theme with full color palette
    public static func catppuccinMocha() -> Theme {
        // Try to load from SPM resource bundle first
        if let resourceBundleURL = Bundle.main.url(forResource: "Vaalin_Vaalin", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let url = resourceBundle.url(forResource: "catppuccin-mocha", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let theme = try? JSONDecoder().decode(Theme.self, from: data) {
            return theme
        }

        // Fallback: embedded JSON for previews and tests where bundle loading fails
        let embeddedJSON = """
        {
          "name": "Catppuccin Mocha",
          "palette": {
            "rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink": "#f5c2e7", "mauve": "#cba6f7",
            "red": "#f38ba8", "maroon": "#eba0ac", "peach": "#fab387", "yellow": "#f9e2af",
            "green": "#a6e3a1", "teal": "#94e2d5", "sky": "#89dceb", "sapphire": "#74c7ec",
            "blue": "#89b4fa", "lavender": "#b4befe", "text": "#cdd6f4", "subtext1": "#bac2de",
            "subtext0": "#a6adc8", "overlay2": "#9399b2", "overlay1": "#7f849c", "overlay0": "#6c7086",
            "surface2": "#585b70", "surface1": "#45475a", "surface0": "#313244",
            "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b"
          },
          "presets": {
            "speech": "green", "whisper": "teal", "thought": "subtext1", "damage": "red",
            "heal": "sky", "monster": "peach", "roomName": "lavender", "roomDesc": "subtext0",
            "bold": "text", "watching": "yellow", "link": "blue", "prompt": "text",
            "command": "subtext1", "macro": "mauve", "channel": "sapphire"
          },
          "categories": {
            "weapon": "red", "armor": "sapphire", "clothing": "flamingo", "gem": "yellow",
            "jewelry": "pink", "reagent": "mauve", "food": "peach", "valuable": "rosewater",
            "box": "overlay1", "junk": "overlay0"
          },
          "semantic": {
            "text": "text", "link": "blue", "command": "subtext1", "success": "green",
            "warning": "yellow", "danger": "red", "info": "blue", "timestamp": "overlay0"
          }
        }
        """

        guard let data = embeddedJSON.data(using: .utf8),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            fatalError("Failed to decode embedded Catppuccin Mocha theme - this should never happen")
        }

        return theme
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
