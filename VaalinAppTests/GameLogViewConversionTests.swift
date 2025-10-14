// ABOUTME: Tests for GameLogView AttributedString → NSAttributedString conversion with color preservation

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Vaalin
@testable import VaalinCore
@testable import VaalinUI

/// Tests for GameLogView AttributedString → NSAttributedString conversion.
///
/// Critical bug fix validation: Conversion must preserve SwiftUI Colors
/// by iterating through AttributedString runs, not stripping via String(characters).
@Suite("GameLogView Color Conversion Tests")
@MainActor
struct GameLogViewConversionTests {
    // MARK: - Test Helpers

    /// Create a GameTag with preset coloring for testing
    private func makePresetTag(presetID: String, text: String) -> GameTag {
        let textChild = GameTag(
            name: ":text",
            text: text,
            attrs: [:],
            children: [],
            state: .closed
        )
        return GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": presetID],
            children: [textChild],
            state: .closed
        )
    }

    // MARK: - Tests

    /// Test AttributedString → NSAttributedString preserves colors.
    @Test("Preserves preset colors (speech = green)")
    func test_preservesSpeechColor() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add message with speech preset (green)
        let textChild = GameTag(
            name: ":text",
            text: "You say, \"Hello!\"",
            attrs: [:],
            children: [],
            state: .closed
        )
        let speechTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "speech"],
            children: [textChild],
            state: .closed
        )
        await viewModel.appendMessage([speechTag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        #expect(nsAttrString.length > 0, "Should have content")

        // Extract color at first character
        var range = NSRange(location: 0, length: 0)
        let attributes = nsAttrString.attributes(at: 0, effectiveRange: &range)
        guard let foregroundColor = attributes[NSAttributedString.Key.foregroundColor] as? NSColor else {
            Issue.record("No foreground color attribute")
            return
        }

        // Catppuccin Mocha green (speech preset) is #a6e3a1
        // RGB: (166, 227, 161) = (0.6510, 0.8902, 0.6314)
        let expectedGreen = NSColor(
            red: 166 / 255.0,
            green: 227 / 255.0,
            blue: 161 / 255.0,
            alpha: 1.0
        )

        // Compare with small tolerance for floating point
        let redMatch = abs(foregroundColor.redComponent - expectedGreen.redComponent) < 0.01
        let greenMatch = abs(foregroundColor.greenComponent - expectedGreen.greenComponent) < 0.01
        let blueMatch = abs(foregroundColor.blueComponent - expectedGreen.blueComponent) < 0.01

        #expect(redMatch, "Red component should match green")
        #expect(greenMatch, "Green component should match green")
        #expect(blueMatch, "Blue component should match green")
    }

    /// Test damage preset color (red) is preserved.
    @Test("Preserves damage color (red)")
    func test_preservesDamageColor() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add message with damage preset (red)
        let textChild = GameTag(
            name: ":text",
            text: "You take 50 damage!",
            attrs: [:],
            children: [],
            state: .closed
        )
        let damageTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "damage"],
            children: [textChild],
            state: .closed
        )
        await viewModel.appendMessage([damageTag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        #expect(nsAttrString.length > 0, "Should have content")

        // Extract color
        var range = NSRange(location: 0, length: 0)
        let attributes = nsAttrString.attributes(at: 0, effectiveRange: &range)
        guard let foregroundColor = attributes[NSAttributedString.Key.foregroundColor] as? NSColor else {
            Issue.record("No foreground color attribute")
            return
        }

        // Catppuccin Mocha red (damage preset) is #f38ba8
        // RGB: (243, 139, 168) = (0.9529, 0.5451, 0.6588)
        let expectedRed = NSColor(
            red: 243 / 255.0,
            green: 139 / 255.0,
            blue: 168 / 255.0,
            alpha: 1.0
        )

        // Red component should be high (> 0.9)
        #expect(foregroundColor.redComponent > 0.9, "Should be red (high red component)")

        // Not green (low green component < 0.6)
        #expect(foregroundColor.greenComponent < 0.6, "Should not be green (low green component)")
    }

    /// Test multiple colors in same message buffer preserved.
    @Test("Preserves multiple different colors")
    func test_preservesMultipleColors() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add two messages with different colors
        let speechTag = makePresetTag(presetID: "speech", text: "Speech")
        let damageTag = makePresetTag(presetID: "damage", text: "Damage")

        await viewModel.appendMessage([speechTag])
        await viewModel.appendMessage([damageTag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        #expect(nsAttrString.length > 0, "Should have content")

        // First line: green (speech)
        var firstRange = NSRange(location: 0, length: 0)
        let firstAttrs = nsAttrString.attributes(at: 0, effectiveRange: &firstRange)
        guard let firstColor = firstAttrs[NSAttributedString.Key.foregroundColor] as? NSColor else {
            Issue.record("No color on first line")
            return
        }

        // Find second line (after newline)
        let fullString = nsAttrString.string
        guard let newlineIndex = fullString.firstIndex(of: "\n") else {
            Issue.record("No newline found")
            return
        }
        let secondLineStart = fullString.distance(from: fullString.startIndex, to: newlineIndex) + 1

        if secondLineStart < nsAttrString.length {
            var secondRange = NSRange(location: 0, length: 0)
            let secondAttrs = nsAttrString.attributes(at: secondLineStart, effectiveRange: &secondRange)
            guard let secondColor = secondAttrs[NSAttributedString.Key.foregroundColor] as? NSColor else {
                Issue.record("No color on second line")
                return
            }

            // Colors should be different (green vs red)
            let redDiff = abs(firstColor.redComponent - secondColor.redComponent)
            let greenDiff = abs(firstColor.greenComponent - secondColor.greenComponent)

            let colorsAreDifferent = redDiff > 0.2 || greenDiff > 0.2
            #expect(colorsAreDifferent, "Different presets should have different colors")
        }
    }

    /// Test default text color applied when no preset.
    @Test("Applies default text color for plain text")
    func test_appliesDefaultTextColor() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add plain text (no preset)
        let plainTag = GameTag(
            name: "output",
            text: "Plain text",
            attrs: [:],
            children: [],
            state: .closed
        )
        await viewModel.appendMessage([plainTag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        #expect(nsAttrString.length > 0, "Should have content")

        // Extract color
        var range = NSRange(location: 0, length: 0)
        let attributes = nsAttrString.attributes(at: 0, effectiveRange: &range)
        guard let foregroundColor = attributes[NSAttributedString.Key.foregroundColor] as? NSColor else {
            Issue.record("No foreground color attribute")
            return
        }

        // Catppuccin Mocha text color is #cdd6f4
        // RGB: (205, 214, 244) = (0.8039, 0.8392, 0.9569)
        let expectedText = NSColor(
            red: 205 / 255.0,
            green: 214 / 255.0,
            blue: 244 / 255.0,
            alpha: 1.0
        )

        // Should match default text color
        let redMatch = abs(foregroundColor.redComponent - expectedText.redComponent) < 0.01
        let greenMatch = abs(foregroundColor.greenComponent - expectedText.greenComponent) < 0.01
        let blueMatch = abs(foregroundColor.blueComponent - expectedText.blueComponent) < 0.01

        #expect(redMatch, "Should use default text red component")
        #expect(greenMatch, "Should use default text green component")
        #expect(blueMatch, "Should use default text blue component")
    }

    /// Test font attributes preserved.
    @Test("Preserves font attributes")
    func test_preservesFontAttributes() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add message
        let tag = GameTag(
            name: "preset",
            text: "Test text",
            attrs: ["id": "speech"],
            children: [],
            state: .closed
        )
        await viewModel.appendMessage([tag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        #expect(nsAttrString.length > 0, "Should have content")

        // Extract font
        var range = NSRange(location: 0, length: 0)
        let attributes = nsAttrString.attributes(at: 0, effectiveRange: &range)
        guard let font = attributes[NSAttributedString.Key.font] as? NSFont else {
            Issue.record("No font attribute")
            return
        }

        // Verify monospaced font
        let isMonospaced = font.fontDescriptor.symbolicTraits.contains(NSFontDescriptor.SymbolicTraits.monoSpace)
        #expect(isMonospaced, "Should use monospaced font")

        // Verify 13pt size
        #expect(font.pointSize == 13.0, "Should be 13pt font")
    }

    /// Test cache is used for repeated conversions.
    @Test("Cache provides speedup for repeated conversions")
    func test_cacheProvidesSpeedup() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Add message
        let tag = GameTag(
            name: "preset",
            text: "Test message",
            attrs: ["id": "speech"],
            children: [],
            state: .closed
        )
        await viewModel.appendMessage([tag])

        // First conversion (cache cold)
        var cache1: [UUID: NSAttributedString] = [:]
        let start1 = CFAbsoluteTimeGetCurrent()
        let result1 = viewModel.messages.toNSAttributedString(cache: &cache1)
        let duration1 = (CFAbsoluteTimeGetCurrent() - start1) * 1000

        // Second conversion with pre-populated cache
        var cache2 = cache1 // Copy populated cache
        let start2 = CFAbsoluteTimeGetCurrent()
        let result2 = viewModel.messages.toNSAttributedString(cache: &cache2)
        let duration2 = (CFAbsoluteTimeGetCurrent() - start2) * 1000

        // Both should produce same output
        #expect(result1.string == result2.string, "Should produce identical output")

        // Cached version should be faster (usually < 0.1ms vs ~1ms)
        #expect(duration2 < duration1, "Cached conversion should be faster")

        // Both should complete quickly (< 10ms)
        #expect(duration1 < 10.0, "First conversion should complete in < 10ms")
        #expect(duration2 < 10.0, "Cached conversion should complete in < 10ms")
    }

    /// Test empty message handling.
    @Test("Handles empty messages gracefully")
    func test_handlesEmptyMessages() async {
        let theme = Theme.catppuccinMocha()
        let viewModel = GameLogViewModel(theme: theme)

        // Attempt to add empty message (filtered by hasContentRecursive)
        let emptyTag = GameTag(
            name: "output",
            text: "",
            attrs: [:],
            children: [],
            state: .closed
        )
        await viewModel.appendMessage([emptyTag])

        // Convert to NSAttributedString
        var cache: [UUID: NSAttributedString] = [:]
        let nsAttrString = viewModel.messages.toNSAttributedString(cache: &cache)

        // Empty messages filtered out, so result should be empty
        #expect(nsAttrString.length == 0, "Empty messages should be filtered")
    }
}
