// ABOUTME: XMLSyntaxHighlighter provides regex-based syntax highlighting for XML strings
// using Catppuccin Mocha color scheme

import Foundation
import SwiftUI

/// Syntax highlighter for XML using Catppuccin Mocha colors.
///
/// Performance target: < 5ms per row
///
/// ## Color Scheme (Catppuccin Mocha)
/// - **Tags:** Blue (#89b4fa) - `<tag>`, `</tag>`, `<tag/>`
/// - **Attributes:** Mauve (#cba6f7) - attribute names
/// - **Strings:** Green (#a6e3a1) - attribute values in quotes
/// - **Text:** Text (#cdd6f4) - content between tags
/// - **Comments:** Overlay0 (#6c7086) - `<!-- comment -->`
@MainActor
struct XMLSyntaxHighlighter {
    // MARK: - Catppuccin Mocha Colors

    private static let tagColor = Color(red: 0x89 / 255.0, green: 0xb4 / 255.0, blue: 0xfa / 255.0)       // Blue
    private static let attributeColor = Color(red: 0xcb / 255.0, green: 0xa6 / 255.0, blue: 0xf7 / 255.0) // Mauve
    private static let stringColor = Color(red: 0xa6 / 255.0, green: 0xe3 / 255.0, blue: 0xa1 / 255.0)    // Green
    private static let textColor = Color(red: 0xcd / 255.0, green: 0xd6 / 255.0, blue: 0xf4 / 255.0)      // Text
    private static let commentColor = Color(red: 0x6c / 255.0, green: 0x70 / 255.0, blue: 0x86 / 255.0)   // Overlay0

    // MARK: - Regex Patterns

    /// Regex for XML tags (opening, closing, self-closing)
    private static let tagPattern = #"</?[a-zA-Z][a-zA-Z0-9_\-:]*(?:\s[^>]*)?>|<\?[^?]+\?>"#

    /// Regex for attributes within tags
    private static let attributePattern = #"\b([a-zA-Z][a-zA-Z0-9_\-:]*)\s*="#

    /// Regex for quoted strings (attribute values)
    private static let stringPattern = #""[^"]*""#

    /// Regex for XML comments
    private static let commentPattern = #"<!--[\s\S]*?-->"#

    // MARK: - Public API

    /// Highlight XML syntax in the given text
    ///
    /// - Parameter xml: XML string to highlight
    /// - Returns: AttributedString with syntax colors applied
    static func highlight(_ xml: String) -> AttributedString {
        var attributedString = AttributedString(xml)

        // Apply base text color
        attributedString.foregroundColor = textColor

        // Apply highlighting in order (comments first to avoid conflicts)
        highlightComments(in: &attributedString, xml: xml)
        highlightTags(in: &attributedString, xml: xml)
        highlightAttributes(in: &attributedString, xml: xml)
        highlightStrings(in: &attributedString, xml: xml)

        return attributedString
    }

    // MARK: - Private Helpers

    /// Highlight XML comments
    private static func highlightComments(in attributedString: inout AttributedString, xml: String) {
        guard let regex = try? NSRegularExpression(pattern: commentPattern, options: []) else { return }

        let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
        for match in matches {
            if let range = Range(match.range, in: xml) {
                let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!
                    ..< AttributedString.Index(range.upperBound, within: attributedString)!
                attributedString[attributedRange].foregroundColor = commentColor
            }
        }
    }

    /// Highlight XML tags (opening, closing, self-closing)
    private static func highlightTags(in attributedString: inout AttributedString, xml: String) {
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: []) else { return }

        let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
        for match in matches {
            if let range = Range(match.range, in: xml) {
                let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!
                    ..< AttributedString.Index(range.upperBound, within: attributedString)!
                attributedString[attributedRange].foregroundColor = tagColor
            }
        }
    }

    /// Highlight attribute names within tags
    private static func highlightAttributes(in attributedString: inout AttributedString, xml: String) {
        guard let regex = try? NSRegularExpression(pattern: attributePattern, options: []) else { return }

        let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
        for match in matches where match.numberOfRanges > 1 {
            // Capture group 1 is the attribute name
            if let range = Range(match.range(at: 1), in: xml) {
                let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!
                    ..< AttributedString.Index(range.upperBound, within: attributedString)!
                attributedString[attributedRange].foregroundColor = attributeColor
            }
        }
    }

    /// Highlight quoted strings (attribute values)
    private static func highlightStrings(in attributedString: inout AttributedString, xml: String) {
        guard let regex = try? NSRegularExpression(pattern: stringPattern, options: []) else { return }

        let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
        for match in matches {
            if let range = Range(match.range, in: xml) {
                let attributedRange = AttributedString.Index(range.lowerBound, within: attributedString)!
                    ..< AttributedString.Index(range.upperBound, within: attributedString)!
                attributedString[attributedRange].foregroundColor = stringColor
            }
        }
    }
}
