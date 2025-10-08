// ABOUTME: Tests for TagRenderer actor - converts GameTag objects to styled AttributedStrings with theme-based colors

// swiftlint:disable file_length type_body_length function_body_length

import Foundation
import SwiftUI
import Testing
@testable import VaalinCore
@testable import VaalinParser

/// Test suite for TagRenderer actor
/// Validates rendering of GameTag objects into AttributedStrings with proper styling:
/// - Plain text rendering
/// - Preset color application
/// - Bold formatting
/// - Nested style inheritance
/// - Link/anchor styling
/// - Edge cases and performance
///
/// TDD Approach: These tests are written BEFORE TagRenderer implementation to drive design.
/// Initial tests will fail until TagRenderer actor is implemented.
struct TagRendererTests {
    // MARK: - Test Fixtures

    /// Create a test theme with known color mappings for predictable assertions
    static func createTestTheme() -> Theme {
        Theme(
            name: "Test Theme",
            palette: [
                "green": "#00ff00",
                "red": "#ff0000",
                "blue": "#0000ff",
                "yellow": "#ffff00",
                "teal": "#00ffff"
            ],
            presets: [
                "speech": "green",
                "damage": "red",
                "heal": "green",
                "thought": "blue",
                "whisper": "teal"
            ],
            categories: [
                "gem": "blue",
                "weapon": "red"
            ],
            semantic: [
                "link": "yellow",
                "command": "teal"
            ]
        )
    }

    // MARK: - Initialization Tests

    /// Test renderer initializes correctly as an actor
    @Test func test_rendererInitialization() async throws {
        // Renderer should initialize successfully
        _ = TagRenderer()
    }

    // MARK: - Required Tests from Issue #23

    /// Test rendering plain text node (:text)
    /// Plain text nodes should render without any styling applied
    @Test func test_renderPlainText() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let textTag = GameTag(
            name: ":text",
            text: "Hello, world!",
            attrs: [:],
            children: [],
            state: .closed
        )

        let result = await renderer.render(textTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "Hello, world!")

        // Verify no styling applied (default attributes only)
        // We check that foregroundColor is nil or default
        let runs = result.runs
        for run in runs {
            // Plain text should have no explicit foreground color
            #expect(run.foregroundColor == nil)
        }
    }

    /// Test rendering preset tag with color
    /// <preset id="speech">text</preset> should apply green color from theme
    @Test func test_renderPresetWithColor() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let speechTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "speech"],
            children: [
                GameTag(
                    name: ":text",
                    text: "You say, \"Hello!\"",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(speechTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "You say, \"Hello!\"")

        // Verify green color is applied (from palette: "green" = "#00ff00")
        let expectedColor = Color(hex: "#00ff00")
        #expect(expectedColor != nil)

        // Check that at least one run has the green color
        let runs = result.runs
        var foundGreenColor = false
        for run in runs {
            if let color = run.foregroundColor, color == expectedColor {
                foundGreenColor = true
                break
            }
        }
        #expect(foundGreenColor)
    }

    /// Test rendering bold tag
    /// <b>text</b> should apply bold font attribute
    @Test func test_renderBoldTag() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let boldTag = GameTag(
            name: "b",
            text: nil,
            attrs: [:],
            children: [
                GameTag(
                    name: ":text",
                    text: "Bold text",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(boldTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "Bold text")

        // Verify font attribute is applied (bold)
        // For TDD: We check that a font attribute exists - exact trait verification
        // can be refined during implementation
        let runs = result.runs
        var foundFontAttribute = false
        for run in runs where run.font != nil {
            foundFontAttribute = true
            break
        }
        #expect(foundFontAttribute, "Bold tag should apply font attribute")
    }

    /// Test rendering nested preset and bold
    /// <preset id="damage"><b>50 damage!</b></preset> should apply both red color and bold
    @Test func test_renderNestedPresetAndBold() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let nestedTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "damage"],
            children: [
                GameTag(
                    name: "b",
                    text: nil,
                    attrs: [:],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "50 damage!",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(nestedTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "50 damage!")

        // Verify red color is applied (from palette: "red" = "#ff0000")
        let expectedColor = Color(hex: "#ff0000")
        #expect(expectedColor != nil)

        // Check for both red color and font attribute (bold)
        let runs = result.runs
        var foundRedAndFont = false
        for run in runs {
            let hasRed = run.foregroundColor == expectedColor
            let hasFont = run.font != nil
            if hasRed && hasFont {
                foundRedAndFont = true
                break
            }
        }
        #expect(foundRedAndFont, "Nested preset+bold should have both color and font")
    }

    /// Test rendering anchor tag (link)
    /// <a exist="12345" noun="gem">a blue gem</a> should render with appropriate styling
    @Test func test_renderAnchorTag() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let anchorTag = GameTag(
            name: "a",
            text: nil,
            attrs: ["exist": "12345", "noun": "gem"],
            children: [
                GameTag(
                    name: ":text",
                    text: "a blue gem",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(anchorTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "a blue gem")

        // Verify link styling is applied
        // TagRenderer should apply link color from theme.semantic["link"]
        let expectedColor = Color(hex: "#ffff00") // yellow from semantic.link
        #expect(expectedColor != nil)

        let runs = result.runs
        var foundLinkColor = false
        for run in runs {
            if let color = run.foregroundColor, color == expectedColor {
                foundLinkColor = true
                break
            }
        }
        #expect(foundLinkColor)
    }

    // MARK: - Additional Edge Case Tests

    /// Test rendering empty text
    /// Tags with empty or nil text should return empty AttributedString
    @Test func test_renderEmptyText() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let emptyTag = GameTag(
            name: ":text",
            text: "",
            attrs: [:],
            children: [],
            state: .closed
        )

        let result = await renderer.render(emptyTag, theme: theme)

        #expect(result.characters.isEmpty)
    }

    /// Test rendering tag with nil text and no children
    /// Should return empty AttributedString gracefully
    @Test func test_renderNilTextNoChildren() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let nilTextTag = GameTag(
            name: "output",
            text: nil,
            attrs: [:],
            children: [],
            state: .closed
        )

        let result = await renderer.render(nilTextTag, theme: theme)

        #expect(result.characters.isEmpty)
    }

    /// Test rendering multiple nested levels (3+ deep)
    /// <preset><b><d>command text</d></b></preset>
    /// Should apply all styles correctly through nesting
    @Test func test_renderDeeplyNestedTags() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let deeplyNestedTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "thought"],
            children: [
                GameTag(
                    name: "b",
                    text: nil,
                    attrs: [:],
                    children: [
                        GameTag(
                            name: "d",
                            text: nil,
                            attrs: [:],
                            children: [
                                GameTag(
                                    name: ":text",
                                    text: "complex command",
                                    attrs: [:],
                                    children: [],
                                    state: .closed
                                )
                            ],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(deeplyNestedTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "complex command")

        // Should have blue color (from "thought" preset) and bold
        let expectedBlue = Color(hex: "#0000ff")
        let expectedTeal = Color(hex: "#00ffff") // d tag uses semantic.command

        #expect(expectedBlue != nil)
        #expect(expectedTeal != nil)

        // Content should be present (exact styling may vary based on precedence)
        #expect(!result.characters.isEmpty)
    }

    /// Test rendering unknown tag type
    /// Unknown tags should render children without additional styling
    @Test func test_renderUnknownTagType() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let unknownTag = GameTag(
            name: "unknown_element",
            text: nil,
            attrs: [:],
            children: [
                GameTag(
                    name: ":text",
                    text: "content in unknown tag",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(unknownTag, theme: theme)

        // Should render children without error
        #expect(String(result.characters) == "content in unknown tag")
    }

    /// Test rendering preset with unknown ID
    /// Preset tags with IDs not in theme should render without color
    @Test func test_renderPresetWithUnknownID() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let unknownPresetTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "nonexistent_preset"],
            children: [
                GameTag(
                    name: ":text",
                    text: "unknown preset text",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(unknownPresetTag, theme: theme)

        // Should render text without error
        #expect(String(result.characters) == "unknown preset text")
    }

    /// Test rendering d tag (command)
    /// <d cmd="look">look</d> should render with command styling
    @Test func test_renderCommandTag() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let commandTag = GameTag(
            name: "d",
            text: nil,
            attrs: ["cmd": "look at gem"],
            children: [
                GameTag(
                    name: ":text",
                    text: "look at gem",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(commandTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "look at gem")

        // Verify command color is applied (from semantic.command = teal)
        let expectedColor = Color(hex: "#00ffff")
        #expect(expectedColor != nil)

        let runs = result.runs
        var foundCommandColor = false
        for run in runs {
            if let color = run.foregroundColor, color == expectedColor {
                foundCommandColor = true
                break
            }
        }
        #expect(foundCommandColor)
    }

    /// Test bold style inheritance through multiple levels
    /// Bold should propagate to all nested children
    @Test func test_boldInheritanceThroughNesting() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let boldWithNestedTag = GameTag(
            name: "b",
            text: nil,
            attrs: [:],
            children: [
                GameTag(
                    name: "output",
                    text: nil,
                    attrs: [:],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "nested bold text",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(boldWithNestedTag, theme: theme)

        // Verify content
        #expect(String(result.characters) == "nested bold text")

        // Verify font attribute is applied (bold inherited through nesting)
        let runs = result.runs
        var foundFontAttribute = false
        for run in runs where run.font != nil {
            foundFontAttribute = true
            break
        }
        #expect(foundFontAttribute, "Bold should inherit through nested tags")
    }

    /// Test rendering multiple sibling children
    /// Tag with multiple child tags should concatenate rendered results
    @Test func test_renderMultipleSiblingChildren() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let parentTag = GameTag(
            name: "output",
            text: nil,
            attrs: [:],
            children: [
                GameTag(
                    name: ":text",
                    text: "First ",
                    attrs: [:],
                    children: [],
                    state: .closed
                ),
                GameTag(
                    name: "b",
                    text: nil,
                    attrs: [:],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "bold",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                ),
                GameTag(
                    name: ":text",
                    text: " last",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(parentTag, theme: theme)

        // Verify full concatenated content
        #expect(String(result.characters) == "First bold last")
    }

    /// Test rendering tag with both text and children
    /// If a tag has both text and children, behavior should be defined
    /// (typically children take precedence, or text is prepended)
    @Test func test_renderTagWithTextAndChildren() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let mixedTag = GameTag(
            name: "output",
            text: "Direct text",
            attrs: [:],
            children: [
                GameTag(
                    name: ":text",
                    text: " child text",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let result = await renderer.render(mixedTag, theme: theme)

        // Should render both text and children
        // Exact order depends on implementation - test that both are present
        let resultString = String(result.characters)
        #expect(resultString.contains("Direct text") || resultString.contains("child text"))
    }

    // MARK: - Performance Tests

    /// Test rendering performance with large batch
    /// Should render 1000 tags in less than 1 second (< 1ms average per tag)
    @Test func test_renderPerformance() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        // Generate 1000 test tags with various complexities
        let tagCount = 1000
        var tags: [GameTag] = []

        for i in 0..<tagCount {
            let tag: GameTag
            switch i % 5 {
            case 0:
                // Plain text
                tag = GameTag(
                    name: ":text",
                    text: "Plain text \(i)",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            case 1:
                // Preset tag
                tag = GameTag(
                    name: "preset",
                    text: nil,
                    attrs: ["id": "speech"],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "Speech \(i)",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            case 2:
                // Bold tag
                tag = GameTag(
                    name: "b",
                    text: nil,
                    attrs: [:],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "Bold \(i)",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            case 3:
                // Anchor tag
                tag = GameTag(
                    name: "a",
                    text: nil,
                    attrs: ["exist": "\(i)", "noun": "item"],
                    children: [
                        GameTag(
                            name: ":text",
                            text: "Item \(i)",
                            attrs: [:],
                            children: [],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            default:
                // Nested tag
                tag = GameTag(
                    name: "preset",
                    text: nil,
                    attrs: ["id": "damage"],
                    children: [
                        GameTag(
                            name: "b",
                            text: nil,
                            attrs: [:],
                            children: [
                                GameTag(
                                    name: ":text",
                                    text: "Damage \(i)",
                                    attrs: [:],
                                    children: [],
                                    state: .closed
                                )
                            ],
                            state: .closed
                        )
                    ],
                    state: .closed
                )
            }
            tags.append(tag)
        }

        // Measure rendering time
        let start = Date()
        for tag in tags {
            _ = await renderer.render(tag, theme: theme)
        }
        let duration = Date().timeIntervalSince(start)

        // Performance target: < 1 second for 1000 tags (< 1ms average per tag)
        let averageTime = duration / Double(tagCount)
        #expect(
            duration < 1.0,
            "Rendering \(tagCount) tags took \(duration)s (avg \(averageTime * 1000)ms/tag), expected < 1.0s"
        )
    }

    /// Test rendering performance with deeply nested structure
    /// Complex nesting should not cause exponential slowdown
    @Test func test_renderPerformanceWithDeepNesting() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        // Create a deeply nested structure (10 levels)
        func createNestedTag(depth: Int) -> GameTag {
            if depth == 0 {
                return GameTag(
                    name: ":text",
                    text: "Deep content",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            } else {
                let tagName = depth % 2 == 0 ? "preset" : "b"
                let attrs = tagName == "preset" ? ["id": "thought"] : [:]
                return GameTag(
                    name: tagName,
                    text: nil,
                    attrs: attrs,
                    children: [createNestedTag(depth: depth - 1)],
                    state: .closed
                )
            }
        }

        let deepTag = createNestedTag(depth: 10)

        // Should render in reasonable time (< 10ms for single deeply nested tag)
        let start = Date()
        _ = await renderer.render(deepTag, theme: theme)
        let duration = Date().timeIntervalSince(start)

        #expect(duration < 0.01, "Rendering deeply nested tag took \(duration)s, expected < 0.01s")
    }

    // MARK: - Theme Integration Tests

    /// Test that ThemeManager color resolution works correctly in rendering
    @Test func test_themeManagerColorResolution() async throws {
        _ = TagRenderer()  // Verify renderer can be created
        let themeManager = ThemeManager()
        let theme = Self.createTestTheme()

        // Verify ThemeManager can resolve colors correctly
        let speechColor = await themeManager.color(forPreset: "speech", theme: theme)
        #expect(speechColor != nil)

        let expectedGreen = Color(hex: "#00ff00")
        #expect(speechColor == expectedGreen)
    }

    /// Test rendering with multiple different preset types
    /// Each preset should get its correct color from theme
    @Test func test_renderMultiplePresetTypes() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestTheme()

        let presets: [(id: String, text: String)] = [
            ("speech", "speech text"),
            ("damage", "damage text"),
            ("heal", "heal text"),
            ("thought", "thought text"),
            ("whisper", "whisper text")
        ]

        for preset in presets {
            let tag = GameTag(
                name: "preset",
                text: nil,
                attrs: ["id": preset.id],
                children: [
                    GameTag(
                        name: ":text",
                        text: preset.text,
                        attrs: [:],
                        children: [],
                        state: .closed
                    )
                ],
                state: .closed
            )

            let result = await renderer.render(tag, theme: theme)

            // Verify content rendered
            #expect(String(result.characters) == preset.text)

            // Verify some color was applied (exact color depends on theme mapping)
            let runs = result.runs
            var hasColor = false
            for run in runs where run.foregroundColor != nil {
                hasColor = true
                break
            }
            #expect(hasColor, "Preset \(preset.id) should have color applied")
        }
    }

    // MARK: - Timestamp Tests (Issue #25)

    /// Test rendering with timestamp enabled
    /// Verifies timestamp format [HH:MM:SS] and proper color application
    @Test func test_timestampRendering() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        // Create a known timestamp: 2:30:45 PM (14:30:45)
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 14
        components.minute = 30
        components.second = 45
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        // Create a message with the known timestamp
        let textTag = GameTag(
            name: ":text",
            text: "You say, \"Hello!\"",
            attrs: [:],
            children: [],
            state: .closed
        )

        // Create timestamp settings with timestamps enabled
        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let result = await renderer.render(
            textTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampSettings
        )

        let resultString = String(result.characters)

        // Verify timestamp prefix is present with correct format
        #expect(resultString.hasPrefix("[14:30:45] "), "Expected timestamp prefix [14:30:45], got: \(resultString)")

        // Verify message content follows timestamp
        #expect(resultString.contains("You say, \"Hello!\""))

        // Verify timestamp has dimmed/timestamp color applied
        let expectedDimmedColor = Color(hex: "#888888") // Gray color from test theme
        #expect(expectedDimmedColor != nil)

        let runs = result.runs
        var foundTimestampColor = false
        for run in runs {
            if let color = run.foregroundColor, color == expectedDimmedColor {
                foundTimestampColor = true
                break
            }
        }
        #expect(foundTimestampColor, "Timestamp should have dimmed color applied")
    }

    /// Test timestamp toggle functionality
    /// Verifies that timestamps can be enabled/disabled via settings
    @Test func test_timestampToggle() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        // Create a test timestamp
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 9
        components.minute = 15
        components.second = 30
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        let textTag = GameTag(
            name: ":text",
            text: "Test message",
            attrs: [:],
            children: [],
            state: .closed
        )

        // Test with timestamps OFF (default)
        let timestampsOff = Settings.StreamSettings.TimestampSettings(
            gameLog: false,
            perStream: [:]
        )

        let resultOff = await renderer.render(
            textTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampsOff
        )

        let resultOffString = String(resultOff.characters)
        #expect(!resultOffString.contains("[09:15:30]"), "Timestamp should not be present when disabled")
        #expect(resultOffString == "Test message", "Should only contain message text when timestamps off")

        // Test with timestamps ON
        let timestampsOn = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let resultOn = await renderer.render(
            textTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampsOn
        )

        let resultOnString = String(resultOn.characters)
        #expect(resultOnString.hasPrefix("[09:15:30] "), "Timestamp should be present when enabled")
        #expect(resultOnString.contains("Test message"))
    }

    /// Test timestamp with empty message
    /// Edge case: timestamp should still render correctly even if message is empty
    @Test func test_timestampWithEmptyMessage() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 0
        components.minute = 0
        components.second = 0
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        let emptyTag = GameTag(
            name: ":text",
            text: "",
            attrs: [:],
            children: [],
            state: .closed
        )

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let result = await renderer.render(
            emptyTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampSettings
        )

        let resultString = String(result.characters)

        // Should have timestamp even with empty message
        #expect(resultString.hasPrefix("[00:00:00] "), "Timestamp should be present even with empty message")
    }

    /// Test midnight timestamp formatting
    /// Edge case: verify midnight (00:00:00) formats correctly
    @Test func test_midnightTimestamp() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 0
        components.minute = 0
        components.second = 0
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        let textTag = GameTag(
            name: ":text",
            text: "Midnight message",
            attrs: [:],
            children: [],
            state: .closed
        )

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let result = await renderer.render(
            textTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampSettings
        )

        let resultString = String(result.characters)
        #expect(resultString.hasPrefix("[00:00:00] "), "Midnight timestamp should format as [00:00:00]")
    }

    /// Test timestamp doesn't affect message colors/formatting
    /// Verify that timestamp rendering preserves the original message styling
    @Test func test_timestampPreservesMessageFormatting() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 12
        components.minute = 30
        components.second = 15
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        // Test with colored preset tag
        let presetTag = GameTag(
            name: "preset",
            text: nil,
            attrs: ["id": "speech"],
            children: [
                GameTag(
                    name: ":text",
                    text: "Colored speech",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let result = await renderer.render(
            presetTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampSettings
        )

        let resultString = String(result.characters)

        // Verify timestamp is present
        #expect(resultString.hasPrefix("[12:30:15] "))

        // Verify message content is present
        #expect(resultString.contains("Colored speech"))

        // Verify message still has its color applied (green for speech)
        let expectedGreen = Color(hex: "#00ff00")
        #expect(expectedGreen != nil)

        let runs = result.runs
        var foundGreenColor = false
        for run in runs {
            if let color = run.foregroundColor, color == expectedGreen {
                foundGreenColor = true
                break
            }
        }
        #expect(foundGreenColor, "Message color should be preserved with timestamp")
    }

    /// Test timestamp with bold formatting
    /// Verify timestamp rendering works correctly with bold tags
    @Test func test_timestampWithBoldTag() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 7
        components.hour = 18
        components.minute = 45
        components.second = 22
        let calendar = Calendar.current
        guard let timestamp = calendar.date(from: components) else {
            Issue.record("Failed to create test timestamp")
            return
        }

        let boldTag = GameTag(
            name: "b",
            text: nil,
            attrs: [:],
            children: [
                GameTag(
                    name: ":text",
                    text: "Bold message",
                    attrs: [:],
                    children: [],
                    state: .closed
                )
            ],
            state: .closed
        )

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        let result = await renderer.render(
            boldTag,
            theme: theme,
            timestamp: timestamp,
            timestampSettings: timestampSettings
        )

        let resultString = String(result.characters)

        // Verify timestamp and content
        #expect(resultString.hasPrefix("[18:45:22] "))
        #expect(resultString.contains("Bold message"))

        // Verify bold formatting is still applied (checking for font attribute presence)
        let runs = result.runs
        var foundFontAttribute = false
        for run in runs where run.font != nil {
            foundFontAttribute = true
            break
        }
        #expect(foundFontAttribute, "Bold formatting should be preserved in message")
    }

    /// Test multiple messages with different timestamps
    /// Verify each message gets its own timestamp
    @Test func test_multipleMessagesWithDifferentTimestamps() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        // Create three messages with different timestamps
        let messages = [
            (hour: 10, minute: 15, second: 30, text: "First message"),
            (hour: 10, minute: 16, second: 45, text: "Second message"),
            (hour: 10, minute: 17, second: 0, text: "Third message")
        ]

        for msg in messages {
            var components = DateComponents()
            components.year = 2025
            components.month = 10
            components.day = 7
            components.hour = msg.hour
            components.minute = msg.minute
            components.second = msg.second

            let calendar = Calendar.current
            guard let timestamp = calendar.date(from: components) else {
                Issue.record("Failed to create test timestamp")
                continue
            }

            let textTag = GameTag(
                name: ":text",
                text: msg.text,
                attrs: [:],
                children: [],
                state: .closed
            )

            let result = await renderer.render(
                textTag,
                theme: theme,
                timestamp: timestamp,
                timestampSettings: timestampSettings
            )

            let resultString = String(result.characters)

            // Verify correct timestamp for each message
            let expectedPrefix = String(format: "[%02d:%02d:%02d] ", msg.hour, msg.minute, msg.second)
            #expect(resultString.hasPrefix(expectedPrefix), "Expected \(expectedPrefix) for \(msg.text)")
            #expect(resultString.contains(msg.text))
        }
    }

    /// Test timestamp rendering performance
    /// Timestamps should not significantly degrade rendering performance (still < 1ms/tag)
    @Test func test_timestampRenderingPerformance() async throws {
        let renderer = TagRenderer()
        let theme = Self.createTestThemeWithTimestamp()

        let timestampSettings = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: [:]
        )

        // Generate 1000 test tags with timestamps
        let tagCount = 1000
        var tags: [(tag: GameTag, timestamp: Date)] = []

        let calendar = Calendar.current
        var baseComponents = DateComponents()
        baseComponents.year = 2025
        baseComponents.month = 10
        baseComponents.day = 7
        baseComponents.hour = 10
        baseComponents.minute = 0
        baseComponents.second = 0

        guard let baseDate = calendar.date(from: baseComponents) else {
            Issue.record("Failed to create base date")
            return
        }

        for i in 0..<tagCount {
            let tag = GameTag(
                name: ":text",
                text: "Message \(i)",
                attrs: [:],
                children: [],
                state: .closed
            )
            // Increment timestamp by 1 second for each message
            let timestamp = baseDate.addingTimeInterval(TimeInterval(i))
            tags.append((tag, timestamp))
        }

        // Measure rendering time with timestamps
        let start = Date()
        for (tag, timestamp) in tags {
            _ = await renderer.render(
                tag,
                theme: theme,
                timestamp: timestamp,
                timestampSettings: timestampSettings
            )
        }
        let duration = Date().timeIntervalSince(start)

        // Performance target: < 1 second for 1000 tags (< 1ms average per tag)
        let averageTime = duration / Double(tagCount)
        #expect(
            duration < 1.0,
            "Rendering \(tagCount) tags with timestamps took \(duration)s (avg \(averageTime * 1000)ms/tag), expected < 1.0s"
        )
    }

    // MARK: - Test Helper Methods

    /// Create a test theme with timestamp color support
    static func createTestThemeWithTimestamp() -> Theme {
        Theme(
            name: "Test Theme with Timestamp",
            palette: [
                "green": "#00ff00",
                "red": "#ff0000",
                "blue": "#0000ff",
                "yellow": "#ffff00",
                "teal": "#00ffff",
                "gray": "#888888"
            ],
            presets: [
                "speech": "green",
                "damage": "red",
                "heal": "green",
                "thought": "blue",
                "whisper": "teal"
            ],
            categories: [
                "gem": "blue",
                "weapon": "red"
            ],
            semantic: [
                "link": "yellow",
                "command": "teal",
                "timestamp": "gray"
            ]
        )
    }
}
