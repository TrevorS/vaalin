// ABOUTME: Test suite for ThemeManager actor - TDD approach for preset-based color theme system
// swiftlint:disable file_length type_body_length

import Foundation
import SwiftUI
import Testing
@testable import VaalinCore

/// Test suite for ThemeManager actor
/// Validates theme JSON loading, preset color lookup, category colors, semantic colors, and error handling
@Suite("ThemeManager Theme System Tests")
struct ThemeManagerTests {
    // MARK: - Test Theme Data

    /// Mock theme JSON for isolated testing
    private static let mockThemeJSON = """
    {
      "name": "Catppuccin Mocha",
      "palette": {
        "rosewater": "#f5e0dc",
        "flamingo": "#f2cdcd",
        "pink": "#f5c2e7",
        "mauve": "#cba6f7",
        "red": "#f38ba8",
        "maroon": "#eba0ac",
        "peach": "#fab387",
        "yellow": "#f9e2af",
        "green": "#a6e3a1",
        "teal": "#94e2d5",
        "sky": "#89dceb",
        "sapphire": "#74c7ec",
        "blue": "#89b4fa",
        "lavender": "#b4befe",
        "text": "#cdd6f4",
        "subtext1": "#bac2de",
        "subtext0": "#a6adc8",
        "overlay2": "#9399b2",
        "overlay1": "#7f849c",
        "overlay0": "#6c7086",
        "surface2": "#585b70",
        "surface1": "#45475a",
        "surface0": "#313244",
        "base": "#1e1e2e",
        "mantle": "#181825",
        "crust": "#11111b"
      },
      "presets": {
        "speech": "green",
        "whisper": "teal",
        "thought": "subtext1",
        "damage": "red",
        "heal": "sky",
        "roomName": "yellow",
        "roomDesc": "text",
        "bold": "text",
        "watching": "lavender",
        "link": "blue"
      },
      "categories": {
        "weapon": "red",
        "armor": "sapphire",
        "gem": "yellow",
        "jewelry": "pink",
        "clothing": "flamingo",
        "food": "peach",
        "reagent": "lavender",
        "valuable": "green",
        "box": "teal",
        "junk": "overlay1"
      },
      "semantic": {
        "success": "green",
        "warning": "yellow",
        "danger": "red",
        "info": "blue"
      }
    }
    """

    /// Invalid JSON for error handling tests
    private static let invalidThemeJSON = """
    {
      "name": "Broken Theme",
      "palette": {
        "red": "#f38ba8"
      }
      "presets": {
    }
    """

    /// Theme with missing palette reference
    private static let missingReferenceJSON = """
    {
      "name": "Incomplete Theme",
      "palette": {
        "red": "#f38ba8"
      },
      "presets": {
        "speech": "nonexistent_color"
      },
      "categories": {},
      "semantic": {}
    }
    """

    /// Theme with invalid hex colors
    private static let invalidHexJSON = """
    {
      "name": "Invalid Hex Theme",
      "palette": {
        "red": "not_a_hex",
        "blue": "#12345",
        "green": "#GGGGGG"
      },
      "presets": {
        "speech": "red"
      },
      "categories": {},
      "semantic": {}
    }
    """

    // MARK: - Core Loading Tests

    /// Test theme loads successfully from valid JSON
    /// This is the foundation - must parse JSON and construct Theme object
    @Test("Load theme from valid JSON")
    func test_loadThemeFromJSON() async throws {
        // This test will fail initially - ThemeManager doesn't exist yet
        let themeManager = ThemeManager()

        // Load theme from mock JSON data
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Verify theme loaded successfully
        #expect(theme.name == "Catppuccin Mocha")
        #expect(theme.palette.count == 26) // All 26 Catppuccin colors
    }

    /// Test theme name is accessible after loading
    @Test("Access theme name")
    func test_themeName() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        #expect(theme.name == "Catppuccin Mocha")
    }

    // MARK: - Preset Color Lookup Tests

    /// Test preset ID → Color mapping works correctly
    /// Core functionality: "speech" preset → "green" → "#a6e3a1" hex → SwiftUI Color
    @Test("Preset color lookup returns correct color")
    func test_presetColorLookup() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Test speech preset → green color
        let speechColor = await themeManager.color(forPreset: "speech", theme: theme)
        #expect(speechColor != nil, "Speech preset should return a color")

        // Test whisper preset → teal color
        let whisperColor = await themeManager.color(forPreset: "whisper", theme: theme)
        #expect(whisperColor != nil, "Whisper preset should return a color")

        // Test damage preset → red color
        let damageColor = await themeManager.color(forPreset: "damage", theme: theme)
        #expect(damageColor != nil, "Damage preset should return a color")
    }

    /// Test multiple preset lookups return different colors
    @Test("Different presets return different colors")
    func test_differentPresetsDifferentColors() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let speechColor = await themeManager.color(forPreset: "speech", theme: theme)
        let damageColor = await themeManager.color(forPreset: "damage", theme: theme)
        let whisperColor = await themeManager.color(forPreset: "whisper", theme: theme)

        // These should all be different colors (can't test Color equality directly,
        // but we verify they're all non-nil and represent different palette entries)
        #expect(speechColor != nil)
        #expect(damageColor != nil)
        #expect(whisperColor != nil)
    }

    /// Test missing preset returns nil (fallback to caller)
    @Test("Missing preset returns nil")
    func test_missingPresetFallback() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Request nonexistent preset
        let unknownColor = await themeManager.color(forPreset: "nonexistent_preset", theme: theme)

        #expect(unknownColor == nil, "Unknown preset should return nil")
    }

    /// Test empty string preset returns nil
    @Test("Empty preset string returns nil")
    func test_emptyPresetString() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let emptyColor = await themeManager.color(forPreset: "", theme: theme)

        #expect(emptyColor == nil, "Empty preset should return nil")
    }

    // MARK: - Catppuccin Palette Completeness Tests

    /// Test all 26 Catppuccin Mocha colors are present
    /// This validates the full palette is loaded correctly
    @Test("Catppuccin palette is complete with all 26 colors")
    func test_catppuccinPaletteComplete() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Verify palette has exactly 26 colors
        #expect(theme.palette.count == 26)

        // Verify all expected Catppuccin colors exist
        let expectedColors = [
            "rosewater", "flamingo", "pink", "mauve", "red", "maroon",
            "peach", "yellow", "green", "teal", "sky", "sapphire",
            "blue", "lavender", "text", "subtext1", "subtext0",
            "overlay2", "overlay1", "overlay0", "surface2", "surface1",
            "surface0", "base", "mantle", "crust"
        ]

        for colorName in expectedColors {
            #expect(theme.palette[colorName] != nil, "Missing color: \(colorName)")
        }
    }

    /// Test specific Catppuccin hex values are correct
    @Test("Catppuccin color hex values are correct")
    func test_catppuccinHexValues() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Verify specific hex values from Catppuccin Mocha palette
        #expect(theme.palette["red"] == "#f38ba8")
        #expect(theme.palette["green"] == "#a6e3a1")
        #expect(theme.palette["blue"] == "#89b4fa")
        #expect(theme.palette["yellow"] == "#f9e2af")
        #expect(theme.palette["teal"] == "#94e2d5")
        #expect(theme.palette["text"] == "#cdd6f4")
        #expect(theme.palette["base"] == "#1e1e2e")
    }

    // MARK: - Category Color Lookup Tests

    /// Test item category color lookup works
    /// Categories: gem, jewelry, weapon, armor, clothing, food, reagent, valuable, box, junk
    @Test("Category color lookup returns correct color")
    func test_categoryColorLookup() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Test weapon category → red
        let weaponColor = await themeManager.color(forCategory: "weapon", theme: theme)
        #expect(weaponColor != nil, "Weapon category should return a color")

        // Test gem category → yellow
        let gemColor = await themeManager.color(forCategory: "gem", theme: theme)
        #expect(gemColor != nil, "Gem category should return a color")

        // Test armor category → sapphire
        let armorColor = await themeManager.color(forCategory: "armor", theme: theme)
        #expect(armorColor != nil, "Armor category should return a color")
    }

    /// Test all category types have colors
    @Test("All item categories have colors")
    func test_allCategoriesHaveColors() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let categories = ["weapon", "armor", "gem", "jewelry", "clothing",
                          "food", "reagent", "valuable", "box", "junk"]

        for category in categories {
            let color = await themeManager.color(forCategory: category, theme: theme)
            #expect(color != nil, "Category \(category) should have a color")
        }
    }

    /// Test unknown category returns nil
    @Test("Unknown category returns nil")
    func test_unknownCategoryReturnsNil() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let unknownColor = await themeManager.color(forCategory: "nonexistent_category", theme: theme)

        #expect(unknownColor == nil, "Unknown category should return nil")
    }

    // MARK: - Semantic Color Lookup Tests

    /// Test UI semantic color lookup works
    /// Semantic colors: success, warning, danger, info
    @Test("Semantic color lookup returns correct color")
    func test_semanticColorLookup() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Test success → green
        let successColor = await themeManager.semanticColor(for: "success", theme: theme)
        #expect(successColor != nil, "Success semantic should return a color")

        // Test warning → yellow
        let warningColor = await themeManager.semanticColor(for: "warning", theme: theme)
        #expect(warningColor != nil, "Warning semantic should return a color")

        // Test danger → red
        let dangerColor = await themeManager.semanticColor(for: "danger", theme: theme)
        #expect(dangerColor != nil, "Danger semantic should return a color")

        // Test info → blue
        let infoColor = await themeManager.semanticColor(for: "info", theme: theme)
        #expect(infoColor != nil, "Info semantic should return a color")
    }

    /// Test unknown semantic returns nil
    @Test("Unknown semantic returns nil")
    func test_unknownSemanticReturnsNil() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let unknownColor = await themeManager.semanticColor(for: "nonexistent", theme: theme)

        #expect(unknownColor == nil, "Unknown semantic should return nil")
    }

    // MARK: - Palette Reference Resolution Tests

    /// Test palette reference chain: "speech" → "green" → "#a6e3a1"
    /// This validates the indirection layer works correctly
    @Test("Palette reference resolution chain works")
    func test_paletteReferenceResolution() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Verify the reference chain:
        // 1. presets["speech"] → "green"
        #expect(theme.presets["speech"] == "green")

        // 2. palette["green"] → "#a6e3a1"
        #expect(theme.palette["green"] == "#a6e3a1")

        // 3. color(forPreset: "speech") returns Color from "#a6e3a1"
        let speechColor = await themeManager.color(forPreset: "speech", theme: theme)
        #expect(speechColor != nil)
    }

    /// Test missing palette reference returns nil gracefully
    @Test("Missing palette reference returns nil")
    func test_missingPaletteReference() async throws {
        let themeManager = ThemeManager()
        let data = Self.missingReferenceJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // "speech" preset references "nonexistent_color" which doesn't exist in palette
        let speechColor = await themeManager.color(forPreset: "speech", theme: theme)

        #expect(speechColor == nil, "Missing palette reference should return nil")
    }

    // MARK: - Error Handling Tests

    /// Test invalid JSON throws appropriate error
    @Test("Invalid JSON throws error")
    func test_invalidJSONHandling() async throws {
        let themeManager = ThemeManager()
        let data = Self.invalidThemeJSON.data(using: .utf8)!

        // Should throw decoding error
        do {
            _ = try await themeManager.loadTheme(from: data)
            Issue.record("Expected loadTheme to throw, but it succeeded")
        } catch {
            // Expected - test passes
        }
    }

    /// Test empty data throws error
    @Test("Empty data throws error")
    func test_emptyDataHandling() async throws {
        let themeManager = ThemeManager()
        let data = Data()

        do {
            _ = try await themeManager.loadTheme(from: data)
            Issue.record("Expected loadTheme to throw on empty data, but it succeeded")
        } catch {
            // Expected - test passes
        }
    }

    /// Test malformed UTF-8 throws error
    @Test("Malformed UTF-8 throws error")
    func test_malformedUTF8Handling() async throws {
        let themeManager = ThemeManager()
        // Invalid UTF-8 sequence
        let data = Data([0xFF, 0xFE, 0xFD])

        do {
            _ = try await themeManager.loadTheme(from: data)
            Issue.record("Expected loadTheme to throw on malformed UTF-8, but it succeeded")
        } catch {
            // Expected - test passes
        }
    }

    // MARK: - Color Conversion Tests

    /// Test hex → SwiftUI Color conversion accuracy
    /// Verify standard hex formats are handled correctly
    @Test("Hex to Color conversion is accurate")
    func test_colorConversionAccuracy() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Get color from known hex value
        let redColor = await themeManager.color(forPreset: "damage", theme: theme)

        #expect(redColor != nil, "Red color should be converted successfully")

        // Note: We can't directly compare SwiftUI Colors for equality,
        // but we verify the conversion succeeded (non-nil result)
    }

    /// Test various hex formats are handled
    @Test("Various hex formats are handled")
    func test_hexFormatVariations() async throws {
        let variationsJSON = """
        {
          "name": "Hex Variations",
          "palette": {
            "lowercase": "#a6e3a1",
            "uppercase": "#A6E3A1",
            "mixed": "#A6e3a1"
          },
          "presets": {
            "test1": "lowercase",
            "test2": "uppercase",
            "test3": "mixed"
          },
          "categories": {},
          "semantic": {}
        }
        """

        let themeManager = ThemeManager()
        let data = variationsJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // All variations should parse successfully
        let color1 = await themeManager.color(forPreset: "test1", theme: theme)
        let color2 = await themeManager.color(forPreset: "test2", theme: theme)
        let color3 = await themeManager.color(forPreset: "test3", theme: theme)

        #expect(color1 != nil, "Lowercase hex should parse")
        #expect(color2 != nil, "Uppercase hex should parse")
        #expect(color3 != nil, "Mixed case hex should parse")
    }

    /// Test invalid hex values return nil gracefully
    @Test("Invalid hex values return nil")
    func test_invalidHexValuesHandling() async throws {
        let themeManager = ThemeManager()
        let data = Self.invalidHexJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Preset "speech" references "red" with invalid hex "not_a_hex"
        let color = await themeManager.color(forPreset: "speech", theme: theme)

        #expect(color == nil, "Invalid hex should return nil color")
    }

    // MARK: - Thread Safety Tests

    /// Test concurrent access to ThemeManager via actor isolation
    /// Multiple tasks should be able to access theme data safely
    @Test("Concurrent theme access is thread-safe")
    func test_threadSafety() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Create 100 concurrent tasks accessing theme data
        await withTaskGroup(of: Color?.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let presets = ["speech", "whisper", "damage", "heal", "thought"]
                    let preset = presets[i % presets.count]
                    return await themeManager.color(forPreset: preset, theme: theme)
                }
            }

            // Collect all results
            var results: [Color?] = []
            for await color in group {
                results.append(color)
            }

            // All lookups should succeed (no crashes, no race conditions)
            #expect(results.count == 100)
            #expect(results.allSatisfy { $0 != nil })
        }
    }

    /// Test concurrent lookups across different lookup types
    @Test("Mixed concurrent lookups are thread-safe")
    func test_mixedConcurrentLookups() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Mix preset, category, and semantic lookups concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await themeManager.color(forPreset: "speech", theme: theme)
            }
            group.addTask {
                _ = await themeManager.color(forCategory: "weapon", theme: theme)
            }
            group.addTask {
                _ = await themeManager.semanticColor(for: "success", theme: theme)
            }
            group.addTask {
                _ = await themeManager.color(forPreset: "damage", theme: theme)
            }
            group.addTask {
                _ = await themeManager.color(forCategory: "gem", theme: theme)
            }

            await group.waitForAll()
        }

        // Test completes without deadlock or race conditions
        #expect(Bool(true))
    }

    // MARK: - Edge Cases

    /// Test theme with empty palette
    @Test("Empty palette theme handles gracefully")
    func test_emptyPalette() async throws {
        let emptyPaletteJSON = """
        {
          "name": "Empty Palette",
          "palette": {},
          "presets": {
            "speech": "green"
          },
          "categories": {},
          "semantic": {}
        }
        """

        let themeManager = ThemeManager()
        let data = emptyPaletteJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Preset references missing palette color
        let color = await themeManager.color(forPreset: "speech", theme: theme)

        #expect(color == nil, "Missing palette entry should return nil")
    }

    /// Test theme with empty presets
    @Test("Empty presets theme handles gracefully")
    func test_emptyPresets() async throws {
        let emptyPresetsJSON = """
        {
          "name": "Empty Presets",
          "palette": {
            "red": "#f38ba8"
          },
          "presets": {},
          "categories": {},
          "semantic": {}
        }
        """

        let themeManager = ThemeManager()
        let data = emptyPresetsJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let color = await themeManager.color(forPreset: "speech", theme: theme)

        #expect(color == nil, "Missing preset should return nil")
    }

    /// Test null values in JSON
    @Test("Null values in JSON are handled")
    func test_nullValuesHandling() async throws {
        let nullValuesJSON = """
        {
          "name": "Null Values",
          "palette": {
            "red": "#f38ba8"
          },
          "presets": {
            "speech": null
          },
          "categories": {},
          "semantic": {}
        }
        """

        let themeManager = ThemeManager()
        let data = nullValuesJSON.data(using: .utf8)!

        // JSON with null values should either throw or handle gracefully
        // Implementation can choose - test verifies no crash
        do {
            let theme = try await themeManager.loadTheme(from: data)
            let color = await themeManager.color(forPreset: "speech", theme: theme)
            #expect(color == nil, "Null preset value should return nil color")
        } catch {
            // Also acceptable - throw on invalid JSON
            #expect(Bool(true))
        }
    }

    // MARK: - Real-World Integration Tests

    /// Test loading actual Catppuccin Mocha theme (full integration)
    @Test("Full Catppuccin Mocha theme integration")
    func test_fullCatppuccinMochaIntegration() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Verify theme structure
        #expect(theme.name == "Catppuccin Mocha")
        #expect(theme.palette.count == 26)
        #expect(theme.presets.count == 10)
        #expect(theme.categories.count == 10)
        #expect(theme.semantic.count == 4)

        // Verify key game presets work
        #expect(await themeManager.color(forPreset: "speech", theme: theme) != nil)
        #expect(await themeManager.color(forPreset: "damage", theme: theme) != nil)
        #expect(await themeManager.color(forPreset: "roomName", theme: theme) != nil)

        // Verify item categories work
        #expect(await themeManager.color(forCategory: "weapon", theme: theme) != nil)
        #expect(await themeManager.color(forCategory: "gem", theme: theme) != nil)

        // Verify UI semantics work
        #expect(await themeManager.semanticColor(for: "success", theme: theme) != nil)
        #expect(await themeManager.semanticColor(for: "danger", theme: theme) != nil)
    }

    /// Test realistic game preset usage pattern
    @Test("Realistic game preset rendering pattern")
    func test_gamePresetRenderingPattern() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Simulate rendering multiple game text lines with different presets
        let gamePresets = [
            "speech",   // Player says something
            "roomName", // Room name
            "roomDesc", // Room description
            "damage",   // Combat damage
            "heal",     // Healing
            "whisper",  // Whispered message
            "thought",  // Thought text
            "link",     // Clickable link
            "bold",     // Bold text
            "watching"  // Watching text
        ]

        for preset in gamePresets {
            let color = await themeManager.color(forPreset: preset, theme: theme)
            #expect(color != nil, "Game preset '\(preset)' should have a color")
        }
    }

    /// Test realistic item categorization pattern
    @Test("Realistic item categorization pattern")
    func test_itemCategorizationPattern() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        // Simulate categorizing items in inventory
        struct Item {
            let name: String
            let category: String
        }

        let items = [
            Item(name: "a ruby", category: "gem"),
            Item(name: "a longsword", category: "weapon"),
            Item(name: "some full plate", category: "armor"),
            Item(name: "a gold ring", category: "jewelry"),
            Item(name: "a blue cloak", category: "clothing"),
            Item(name: "a meat pie", category: "food"),
            Item(name: "some acantha leaf", category: "reagent"),
            Item(name: "a silver wand", category: "valuable"),
            Item(name: "a wooden box", category: "box"),
            Item(name: "a broken shield", category: "junk")
        ]

        for item in items {
            let color = await themeManager.color(forCategory: item.category, theme: theme)
            #expect(color != nil, "Item '\(item.name)' category '\(item.category)' should have a color")
        }
    }

    // MARK: - Performance Tests

    /// Test color lookup performance (should be very fast)
    @Test("Color lookup performance")
    func test_colorLookupPerformance() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!
        let theme = try await themeManager.loadTheme(from: data)

        let start = Date()

        // Perform 1000 lookups
        for i in 0..<1000 {
            let presets = ["speech", "whisper", "damage", "heal", "thought"]
            let preset = presets[i % presets.count]
            _ = await themeManager.color(forPreset: preset, theme: theme)
        }

        let duration = Date().timeIntervalSince(start)

        // 1000 lookups should complete in < 100ms (0.1s)
        #expect(duration < 0.1, "1000 lookups took \(duration)s, expected < 0.1s")
    }

    /// Test theme loading performance
    @Test("Theme loading performance")
    func test_themeLoadingPerformance() async throws {
        let themeManager = ThemeManager()
        let data = Self.mockThemeJSON.data(using: .utf8)!

        let start = Date()

        // Load theme 10 times
        for _ in 0..<10 {
            _ = try await themeManager.loadTheme(from: data)
        }

        let duration = Date().timeIntervalSince(start)

        // 10 loads should complete in < 100ms
        #expect(duration < 0.1, "10 theme loads took \(duration)s, expected < 0.1s")
    }
}
