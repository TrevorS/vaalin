// ABOUTME: Settings data model for app configuration persistence via JSON
// ABOUTME: Codable structures for layout, streams, input, theme, and network settings

import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Application settings with nested configuration structures
///
/// Settings are persisted to `~/Library/Application Support/Vaalin/settings.json`
/// using JSON encoding. All nested structures are Codable for automatic serialization.
///
/// ## Default Values
/// Use `Settings.makeDefault()` to create a new instance with sensible defaults.
///
/// ## Partial Decoding
/// When decoding from JSON, missing fields will use their Codable defaults.
/// This ensures forward/backward compatibility when adding new settings.
public struct Settings: Codable, Sendable {
    public var layout: Layout
    public var streams: StreamSettings
    public var input: InputSettings
    public var theme: ThemeSettings
    public var network: NetworkSettings

    public init(
        layout: Layout,
        streams: StreamSettings,
        input: InputSettings,
        theme: ThemeSettings,
        network: NetworkSettings
    ) {
        self.layout = layout
        self.streams = streams
        self.input = input
        self.theme = theme
        self.network = network
    }

    /// Creates Settings with default values for initial app setup
    public static func makeDefault() -> Settings {
        Settings(
            layout: .makeDefault(),
            streams: .makeDefault(),
            input: .makeDefault(),
            theme: .makeDefault(),
            network: .makeDefault()
        )
    }

    // MARK: - Layout Settings

    /// Panel layout configuration
    ///
    /// Defines which panels appear in left/right columns, column widths,
    /// stream filtering bar height, and collapsed panel state.
    public struct Layout: Codable, Sendable {
        /// Panel IDs displayed in left column (e.g., ["hands", "vitals"])
        public var left: [String]

        /// Panel IDs displayed in right column (e.g., ["compass", "spells"])
        public var right: [String]

        /// Column width overrides per panel ID
        /// Key: panel ID, Value: width in points
        public var colWidth: [String: CGFloat]

        /// Height of stream filtering bar in points
        public var streamsHeight: CGFloat

        /// Collapsed state per panel ID
        /// Key: panel ID, Value: true if collapsed
        public var collapsed: [String: Bool]

        public init(
            left: [String],
            right: [String],
            colWidth: [String: CGFloat],
            streamsHeight: CGFloat,
            collapsed: [String: Bool]
        ) {
            self.left = left
            self.right = right
            self.colWidth = colWidth
            self.streamsHeight = streamsHeight
            self.collapsed = collapsed
        }

        /// Default layout: hands/vitals on left, compass/spells on right
        public static func makeDefault() -> Layout {
            Layout(
                left: ["hands", "vitals"],
                right: ["compass", "spells"],
                colWidth: [:],
                streamsHeight: 200.0,
                collapsed: [:]
            )
        }
    }

    // MARK: - Stream Settings

    /// Stream filtering and display configuration
    public struct StreamSettings: Codable, Sendable {
        /// If true, filtered stream content also appears in main game log
        public var mirrorFilteredToMain: Bool

        /// Timestamp display settings
        public var timestamps: TimestampSettings

        public init(
            mirrorFilteredToMain: Bool,
            timestamps: TimestampSettings
        ) {
            self.mirrorFilteredToMain = mirrorFilteredToMain
            self.timestamps = timestamps
        }

        /// Default: mirror to main, timestamps off
        public static func makeDefault() -> StreamSettings {
            StreamSettings(
                mirrorFilteredToMain: true,
                timestamps: .makeDefault()
            )
        }

        // MARK: - Timestamp Settings

        /// Timestamp display configuration per stream
        public struct TimestampSettings: Codable, Sendable {
            /// Show timestamps in main game log
            public var gameLog: Bool

            /// Per-stream timestamp overrides
            /// Key: stream ID, Value: true if timestamps enabled
            public var perStream: [String: Bool]

            public init(
                gameLog: Bool,
                perStream: [String: Bool]
            ) {
                self.gameLog = gameLog
                self.perStream = perStream
            }

            /// Default: timestamps off globally
            public static func makeDefault() -> TimestampSettings {
                TimestampSettings(
                    gameLog: false,
                    perStream: [:]
                )
            }
        }
    }

    // MARK: - Input Settings

    /// Command input configuration
    public struct InputSettings: Codable, Sendable {
        /// If true, Enter key sends command (false = Cmd+Enter required)
        public var sendOnEnter: Bool

        /// Prefix displayed before echoed commands (e.g., "›")
        public var echoPrefix: String

        /// If true, echo sent commands to game log (can be disabled)
        public var commandEcho: Bool

        public init(
            sendOnEnter: Bool,
            echoPrefix: String,
            commandEcho: Bool
        ) {
            self.sendOnEnter = sendOnEnter
            self.echoPrefix = echoPrefix
            self.commandEcho = commandEcho
        }

        /// Default: send on Enter, "›" prefix, echo enabled
        public static func makeDefault() -> InputSettings {
            InputSettings(
                sendOnEnter: true,
                echoPrefix: "›",
                commandEcho: true
            )
        }
    }

    // MARK: - Theme Settings

    /// Color theme configuration
    public struct ThemeSettings: Codable, Sendable {
        /// Theme name (e.g., "catppuccin-mocha")
        /// Maps to JSON file in Vaalin/Resources/themes/
        public var name: String

        /// ANSI color mapping scheme (e.g., "gemstone")
        /// Defines how ANSI codes map to theme colors
        public var ansiMap: String

        public init(
            name: String,
            ansiMap: String
        ) {
            self.name = name
            self.ansiMap = ansiMap
        }

        /// Default: Catppuccin Mocha theme with GemStone IV ANSI mapping
        public static func makeDefault() -> ThemeSettings {
            ThemeSettings(
                name: "catppuccin-mocha",
                ansiMap: "gemstone"
            )
        }
    }

    // MARK: - Network Settings

    /// Lich connection configuration
    public struct NetworkSettings: Codable, Sendable {
        /// Lich server hostname or IP
        public var host: String

        /// Lich detachable client port (default: 8000)
        public var port: UInt16

        public init(
            host: String,
            port: UInt16
        ) {
            self.host = host
            self.port = port
        }

        /// Default: localhost:8000 (Lich detachable client mode)
        public static func makeDefault() -> NetworkSettings {
            NetworkSettings(
                host: "localhost",
                port: 8000
            )
        }
    }
}
