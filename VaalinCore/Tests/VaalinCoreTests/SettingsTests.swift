// ABOUTME: Tests for Settings Codable data model - encoding, decoding, and default values

import Testing
import Foundation
@testable import VaalinCore

/// Test suite for Settings data model
/// Validates JSON encoding/decoding and default value initialization
struct SettingsTests {

    // MARK: - Test Data

    /// Sample JSON representing complete settings
    private let completeSettingsJSON = """
    {
        "layout": {
            "left": ["hands", "vitals"],
            "right": ["compass", "spells"],
            "colWidth": {
                "hands": 200.0,
                "vitals": 220.0
            },
            "streamsHeight": 150.0,
            "collapsed": {
                "hands": false,
                "vitals": false
            }
        },
        "streams": {
            "mirrorFilteredToMain": true,
            "timestamps": {
                "gameLog": false,
                "perStream": {
                    "thoughts": true,
                    "speech": false
                }
            }
        },
        "input": {
            "sendOnEnter": true,
            "echoPrefix": ">"
        },
        "theme": {
            "name": "catppuccin-mocha",
            "ansiMap": "gemstone"
        },
        "network": {
            "host": "localhost",
            "port": 8000
        }
    }
    """

    /// Minimal JSON with only required fields
    private let minimalSettingsJSON = """
    {
        "layout": {
            "left": [],
            "right": [],
            "colWidth": {},
            "streamsHeight": 100.0,
            "collapsed": {}
        },
        "streams": {
            "mirrorFilteredToMain": false,
            "timestamps": {
                "gameLog": false,
                "perStream": {}
            }
        },
        "input": {
            "sendOnEnter": false,
            "echoPrefix": ""
        },
        "theme": {
            "name": "",
            "ansiMap": ""
        },
        "network": {
            "host": "",
            "port": 0
        }
    }
    """

    // MARK: - Encoding Tests

    /// Test that Settings can be encoded to JSON
    @Test func test_settingsEncoding() throws {
        // Create settings with known values
        let settings = Settings(
            layout: Settings.Layout(
                left: ["hands", "vitals"],
                right: ["compass"],
                colWidth: ["hands": 200.0],
                streamsHeight: 150.0,
                collapsed: ["hands": false]
            ),
            streams: Settings.StreamSettings(
                mirrorFilteredToMain: true,
                timestamps: Settings.StreamSettings.TimestampSettings(
                    gameLog: false,
                    perStream: ["thoughts": true]
                )
            ),
            input: Settings.InputSettings(
                sendOnEnter: true,
                echoPrefix: ">"
            ),
            theme: Settings.ThemeSettings(
                name: "catppuccin-mocha",
                ansiMap: "gemstone"
            ),
            network: Settings.NetworkSettings(
                host: "localhost",
                port: 8000
            )
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(settings)
        let jsonString = String(data: data, encoding: .utf8)

        // Verify JSON was created
        #expect(jsonString != nil)
        #expect(jsonString!.contains("\"host\" : \"localhost\""))
        #expect(jsonString!.contains("\"port\" : 8000"))
        #expect(jsonString!.contains("\"mirrorFilteredToMain\" : true"))
    }

    // MARK: - Decoding Tests

    /// Test that Settings can be decoded from complete JSON
    @Test func test_settingsDecoding() throws {
        let data = completeSettingsJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let settings = try decoder.decode(Settings.self, from: data)

        // Verify layout
        #expect(settings.layout.left == ["hands", "vitals"])
        #expect(settings.layout.right == ["compass", "spells"])
        #expect(settings.layout.colWidth["hands"] == 200.0)
        #expect(settings.layout.streamsHeight == 150.0)
        #expect(settings.layout.collapsed["hands"] == false)

        // Verify streams
        #expect(settings.streams.mirrorFilteredToMain == true)
        #expect(settings.streams.timestamps.gameLog == false)
        #expect(settings.streams.timestamps.perStream["thoughts"] == true)
        #expect(settings.streams.timestamps.perStream["speech"] == false)

        // Verify input
        #expect(settings.input.sendOnEnter == true)
        #expect(settings.input.echoPrefix == ">")

        // Verify theme
        #expect(settings.theme.name == "catppuccin-mocha")
        #expect(settings.theme.ansiMap == "gemstone")

        // Verify network
        #expect(settings.network.host == "localhost")
        #expect(settings.network.port == 8000)
    }

    // MARK: - Default Values Tests

    /// Test that Settings provides sensible default values
    @Test func test_defaultValues() {
        let settings = Settings.makeDefault()

        // Layout defaults
        #expect(settings.layout.left == ["hands", "vitals"])
        #expect(settings.layout.right == ["compass", "spells"])
        #expect(settings.layout.streamsHeight == 200.0)
        #expect(settings.layout.colWidth.isEmpty)
        #expect(settings.layout.collapsed.isEmpty)

        // Streams defaults
        #expect(settings.streams.mirrorFilteredToMain == true)
        #expect(settings.streams.timestamps.gameLog == false)
        #expect(settings.streams.timestamps.perStream.isEmpty)

        // Input defaults
        #expect(settings.input.sendOnEnter == true)
        #expect(settings.input.echoPrefix == ">")

        // Theme defaults
        #expect(settings.theme.name == "catppuccin-mocha")
        #expect(settings.theme.ansiMap == "gemstone")

        // Network defaults
        #expect(settings.network.host == "localhost")
        #expect(settings.network.port == 8000)
    }

    /// Test that each nested struct has its own defaults
    @Test func test_nestedStructureDefaults() {
        let layout = Settings.Layout.makeDefault()
        #expect(layout.left == ["hands", "vitals"])
        #expect(layout.right == ["compass", "spells"])

        let streams = Settings.StreamSettings.makeDefault()
        #expect(streams.mirrorFilteredToMain == true)

        let timestamps = Settings.StreamSettings.TimestampSettings.makeDefault()
        #expect(timestamps.gameLog == false)

        let input = Settings.InputSettings.makeDefault()
        #expect(input.sendOnEnter == true)
        #expect(input.echoPrefix == ">")

        let theme = Settings.ThemeSettings.makeDefault()
        #expect(theme.name == "catppuccin-mocha")

        let network = Settings.NetworkSettings.makeDefault()
        #expect(network.host == "localhost")
        #expect(network.port == 8000)
    }

    // MARK: - Partial Decoding Tests

    /// Test that partial JSON falls back to defaults for missing fields
    /// This is critical for migration when new settings are added
    @Test func test_partialDecoding() throws {
        // JSON missing some optional nested fields
        let partialJSON = """
        {
            "layout": {
                "left": ["hands"],
                "right": [],
                "colWidth": {},
                "streamsHeight": 100.0,
                "collapsed": {}
            },
            "streams": {
                "mirrorFilteredToMain": false,
                "timestamps": {
                    "gameLog": true,
                    "perStream": {}
                }
            },
            "input": {
                "sendOnEnter": false,
                "echoPrefix": "$"
            },
            "theme": {
                "name": "custom-theme",
                "ansiMap": "custom"
            },
            "network": {
                "host": "127.0.0.1",
                "port": 9000
            }
        }
        """

        let data = partialJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let settings = try decoder.decode(Settings.self, from: data)

        // Verify explicitly set values
        #expect(settings.layout.left == ["hands"])
        #expect(settings.layout.right.isEmpty)
        #expect(settings.streams.mirrorFilteredToMain == false)
        #expect(settings.input.echoPrefix == "$")
        #expect(settings.network.host == "127.0.0.1")
        #expect(settings.network.port == 9000)
    }

    // MARK: - Round-Trip Tests

    /// Test that encoding then decoding produces equivalent Settings
    @Test func test_roundTripEncoding() throws {
        let original = Settings.makeDefault()

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Settings.self, from: data)

        // Verify equivalence
        #expect(decoded.layout.left == original.layout.left)
        #expect(decoded.layout.right == original.layout.right)
        #expect(decoded.streams.mirrorFilteredToMain == original.streams.mirrorFilteredToMain)
        #expect(decoded.input.sendOnEnter == original.input.sendOnEnter)
        #expect(decoded.theme.name == original.theme.name)
        #expect(decoded.network.host == original.network.host)
        #expect(decoded.network.port == original.network.port)
    }

    /// Test encoding with minimal/edge case values
    @Test func test_minimialSettingsEncoding() throws {
        let data = minimalSettingsJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let settings = try decoder.decode(Settings.self, from: data)

        // Verify minimal values decode correctly
        #expect(settings.layout.left.isEmpty)
        #expect(settings.layout.right.isEmpty)
        #expect(settings.layout.colWidth.isEmpty)
        #expect(settings.streams.timestamps.perStream.isEmpty)
        #expect(settings.input.echoPrefix.isEmpty)
        #expect(settings.network.host.isEmpty)
        #expect(settings.network.port == 0)
    }

    // MARK: - Nested Structure Tests

    /// Test that nested structures encode/decode independently
    @Test func test_nestedStructureEncoding() throws {
        let layout = Settings.Layout(
            left: ["test"],
            right: [],
            colWidth: ["test": 100.0],
            streamsHeight: 50.0,
            collapsed: ["test": true]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(layout)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Settings.Layout.self, from: data)

        #expect(decoded.left == ["test"])
        #expect(decoded.colWidth["test"] == 100.0)
        #expect(decoded.collapsed["test"] == true)
    }

    /// Test TimestampSettings nested structure
    @Test func test_timestampSettingsStructure() throws {
        let timestamps = Settings.StreamSettings.TimestampSettings(
            gameLog: true,
            perStream: ["thoughts": false, "speech": true]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(timestamps)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Settings.StreamSettings.TimestampSettings.self, from: data)

        #expect(decoded.gameLog == true)
        #expect(decoded.perStream["thoughts"] == false)
        #expect(decoded.perStream["speech"] == true)
    }
}
