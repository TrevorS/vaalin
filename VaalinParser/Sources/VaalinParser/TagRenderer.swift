// ABOUTME: TagRenderer converts GameTag objects into styled AttributedStrings with theme-based colors and formatting

import Foundation
import SwiftUI
import VaalinCore

/// Thread-safe actor that renders GameTag objects into styled AttributedStrings.
///
/// TagRenderer applies theme-based colors, bold formatting, and handles nested tag structures
/// with proper style inheritance. It's designed for high-performance rendering of game output
/// with a target of < 1ms per tag average.
///
/// ## Supported Tag Types
/// - `:text` - Plain text nodes (no styling)
/// - `preset` - Themed color presets (speech, damage, heal, etc.)
/// - `b` - Bold formatting
/// - `a` - Links/anchors (with semantic link color)
/// - `d` - Commands (with semantic command color)
/// - Unknown tags - Rendered gracefully by processing children
///
/// ## Style Inheritance
/// - Bold formatting propagates through nested tags
/// - Colors are applied at the tag level and inherited by children
/// - Parent styles combine with child styles (e.g., bold + color)
///
/// ## Performance
/// - Target: < 1ms per tag average
/// - Optimized for high-throughput game output (>10,000 lines/minute)
/// - Actor isolation ensures thread-safe concurrent rendering
///
/// ## Example Usage
/// ```swift
/// let renderer = TagRenderer()
/// let theme = // ... load theme
///
/// // Render a colored speech preset
/// let tag = GameTag(name: "preset", attrs: ["id": "speech"], children: [...])
/// let attributed = await renderer.render(tag, theme: theme)
/// ```
public actor TagRenderer {
    /// ThemeManager for color lookups
    private let themeManager: ThemeManager

    /// Default system font for text rendering
    private let defaultFont: Font = .system(size: 14)

    /// Bold variant of default font
    private let boldFont: Font = .system(size: 14).bold()

    /// Cached DateFormatter for timestamp rendering (performance optimization)
    private let timestampFormatter: DateFormatter

    /// Initializes a new TagRenderer with its own ThemeManager instance
    public init() {
        self.themeManager = ThemeManager()

        // Initialize cached DateFormatter for timestamp rendering
        self.timestampFormatter = DateFormatter()
        self.timestampFormatter.dateFormat = "HH:mm:ss"
    }

    /// Renders a GameTag into a styled AttributedString.
    ///
    /// Recursively processes the tag and its children, applying appropriate styling
    /// based on tag type, attributes, and theme configuration.
    ///
    /// - Parameters:
    ///   - tag: The GameTag to render
    ///   - theme: Theme containing color and preset mappings
    ///   - timestamp: Optional timestamp to prepend as `[HH:MM:SS] ` prefix
    ///   - timestampSettings: Optional settings controlling timestamp display
    /// - Returns: Styled AttributedString with colors, fonts, and formatting applied
    public func render(
        _ tag: GameTag,
        theme: Theme,
        timestamp: Date? = nil,
        timestampSettings: VaalinCore.Settings.StreamSettings.TimestampSettings? = nil
    ) async -> AttributedString {
        // Render the tag content
        var result = await renderTag(tag, theme: theme, inheritedBold: false)

        // Prepend timestamp if enabled and timestamp is provided
        if let timestamp = timestamp,
           let settings = timestampSettings,
           settings.gameLog {
            let timestampPrefix = await renderTimestamp(timestamp, theme: theme)
            result = timestampPrefix + result
        }

        return result
    }

    // MARK: - Private Rendering Methods

    /// Internal recursive rendering method with bold inheritance tracking.
    ///
    /// - Parameters:
    ///   - tag: The GameTag to render
    ///   - theme: Theme for color lookups
    ///   - inheritedBold: Whether bold formatting should be inherited from parent
    /// - Returns: Styled AttributedString
    private func renderTag(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        switch tag.name {
        case ":text":
            return await renderText(tag, theme: theme, inheritedBold: inheritedBold)

        case "preset":
            return await renderPreset(tag, theme: theme, inheritedBold: inheritedBold)

        case "b":
            // Bold tags enable bold for themselves and all children
            return await renderBold(tag, theme: theme, inheritedBold: inheritedBold)

        case "a":
            // Anchor/link tags
            return await renderAnchor(tag, theme: theme, inheritedBold: inheritedBold)

        case "d":
            // Command tags
            return await renderCommand(tag, theme: theme, inheritedBold: inheritedBold)

        default:
            // Unknown tags: render children without additional styling
            return await renderChildren(tag.children, theme: theme, inheritedBold: inheritedBold)
        }
    }

    /// Renders a plain text node.
    ///
    /// - Parameters:
    ///   - tag: Text tag (name: ":text")
    ///   - theme: Theme (unused for plain text)
    ///   - inheritedBold: Whether to apply bold from parent
    /// - Returns: AttributedString with optional bold formatting
    private func renderText(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        let text = tag.text ?? ""
        var attributed = AttributedString(text)

        // Apply bold if inherited from parent tag
        if inheritedBold {
            attributed.font = boldFont
        }

        return attributed
    }

    /// Renders a preset tag with themed color.
    ///
    /// Looks up the preset ID in theme.presets and applies the corresponding color
    /// from theme.palette. Falls back to rendering children without color if preset not found.
    ///
    /// - Parameters:
    ///   - tag: Preset tag with "id" attribute
    ///   - theme: Theme with preset mappings
    ///   - inheritedBold: Whether to apply bold from parent
    /// - Returns: AttributedString with themed color applied
    private func renderPreset(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        // Render children first
        var result = await renderChildren(tag.children, theme: theme, inheritedBold: inheritedBold)

        // Apply preset color if available
        if let presetID = tag.attrs["id"] {
            if let color = await themeManager.color(forPreset: presetID, theme: theme) {
                result.foregroundColor = color
            }
        }

        return result
    }

    /// Renders a bold tag.
    ///
    /// Applies bold formatting to all children by passing inheritedBold: true.
    ///
    /// - Parameters:
    ///   - tag: Bold tag (name: "b")
    ///   - theme: Theme for child rendering
    ///   - inheritedBold: Whether bold is already inherited (redundant but supported)
    /// - Returns: AttributedString with bold formatting
    private func renderBold(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        // Render children with bold enabled
        var result = await renderChildren(tag.children, theme: theme, inheritedBold: true)

        // If this tag has direct text content, apply bold to it as well
        if let text = tag.text, !text.isEmpty {
            var attributed = AttributedString(text)
            attributed.font = boldFont
            result = attributed + result
        }

        return result
    }

    /// Renders an anchor/link tag.
    ///
    /// Applies semantic link color from theme if available.
    ///
    /// - Parameters:
    ///   - tag: Anchor tag (name: "a") with optional exist/noun attributes
    ///   - theme: Theme with semantic color mappings
    ///   - inheritedBold: Whether to apply bold from parent
    /// - Returns: AttributedString with link color
    private func renderAnchor(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        // Render tag text and children
        var result = AttributedString()

        if let text = tag.text {
            var attributed = AttributedString(text)
            if inheritedBold {
                attributed.font = boldFont
            }
            result = attributed
        }

        let childrenResult = await renderChildren(tag.children, theme: theme, inheritedBold: inheritedBold)
        result += childrenResult

        // Apply semantic link color
        if let linkColor = await themeManager.semanticColor(for: "link", theme: theme) {
            result.foregroundColor = linkColor
        }

        return result
    }

    /// Renders a command tag.
    ///
    /// Applies semantic command color from theme if available.
    ///
    /// - Parameters:
    ///   - tag: Command tag (name: "d")
    ///   - theme: Theme with semantic color mappings
    ///   - inheritedBold: Whether to apply bold from parent
    /// - Returns: AttributedString with command color
    private func renderCommand(
        _ tag: GameTag,
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        // Render tag text and children
        var result = AttributedString()

        if let text = tag.text {
            var attributed = AttributedString(text)
            if inheritedBold {
                attributed.font = boldFont
            }
            result = attributed
        }

        let childrenResult = await renderChildren(tag.children, theme: theme, inheritedBold: inheritedBold)
        result += childrenResult

        // Apply semantic command color
        if let commandColor = await themeManager.semanticColor(for: "command", theme: theme) {
            result.foregroundColor = commandColor
        }

        return result
    }

    /// Recursively renders an array of child tags.
    ///
    /// Concatenates rendered children into a single AttributedString.
    ///
    /// - Parameters:
    ///   - children: Array of child GameTags
    ///   - theme: Theme for child rendering
    ///   - inheritedBold: Whether to pass bold formatting to children
    /// - Returns: Concatenated AttributedString of all children
    private func renderChildren(
        _ children: [GameTag],
        theme: Theme,
        inheritedBold: Bool
    ) async -> AttributedString {
        var result = AttributedString()

        for child in children {
            let rendered = await renderTag(child, theme: theme, inheritedBold: inheritedBold)
            result += rendered
        }

        return result
    }

    /// Renders a timestamp as a styled prefix.
    ///
    /// Formats the timestamp as `[HH:MM:SS] ` and applies semantic timestamp color.
    /// Uses cached DateFormatter for performance.
    ///
    /// - Parameters:
    ///   - timestamp: The date to format
    ///   - theme: Theme for semantic color lookup
    /// - Returns: AttributedString with formatted timestamp and dimmed color
    private func renderTimestamp(
        _ timestamp: Date,
        theme: Theme
    ) async -> AttributedString {
        // Format timestamp using cached formatter
        let timeString = timestampFormatter.string(from: timestamp)
        let timestampText = "[\(timeString)] "

        var attributed = AttributedString(timestampText)

        // Apply semantic timestamp color (dimmed/gray)
        if let timestampColor = await themeManager.semanticColor(for: "timestamp", theme: theme) {
            attributed.foregroundColor = timestampColor
        }

        return attributed
    }
}
