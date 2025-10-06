// ABOUTME: Interactive test program for LichConnection - connects to Lich and streams XML

import Foundation
import VaalinCore
import VaalinNetwork
import VaalinParser

/// ANSI color codes for pretty terminal output
enum Color: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case gray = "\u{001B}[90m"

    func text(_ string: String) -> String {
        return "\(rawValue)\(string)\(Color.reset.rawValue)"
    }
}

/// Print colored status message
func status(_ message: String, color: Color = .cyan) {
    print(color.text("▸ \(message)"))
}

/// Print colored error message
func error(_ message: String) {
    print(Color.red.text("✗ ERROR: \(message)"))
}

/// Print colored success message
func success(_ message: String) {
    print(Color.green.text("✓ \(message)"))
}

/// Print section header
func header(_ message: String) {
    print("\n" + Color.magenta.text("═══ \(message) ═══"))
}

@main
struct TestLichConnection {
    static func main() async {
        header("Lich Connection Test with Parser Integration")

        // Create connection, parser, and bridge
        let connection = LichConnection()
        let parser = XMLStreamParser()
        let bridge = ParserConnectionBridge(connection: connection, parser: parser)

        // Configuration
        let host = "127.0.0.1"
        let port: UInt16 = 8000

        status("Connecting to Lich at \(host):\(port)...")

        do {
            // Connect to Lich
            try await connection.connect(host: host, port: port, autoReconnect: false)
            success("Connected!")

            // Start the bridge (handles data flow automatically)
            status("Starting parser integration bridge...")
            await bridge.start()
            success("Bridge started - XML parsing active")

            // Wait a moment for initial data
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Show initial parsed tags (don't clear - let them accumulate)
            await showParsedTags(from: bridge, label: "Initial Connection", clearAfter: false)

            // Send test commands
            header("Sending Test Commands")

            let commands = ["look", "time", "info"]

            for command in commands {
                status("Sending: \(Color.yellow.text(command))")
                try await connection.send(command: command)

                // Wait for response
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

                // Show parsed tags after command
                // Clear after first two commands to demonstrate memory management
                let shouldClear = command != "info"
                await showParsedTags(
                    from: bridge,
                    label: "After '\(command)'",
                    clearAfter: shouldClear
                )
            }

            // Keep streaming for a bit longer
            status("Streaming for 5 more seconds...")
            try await Task.sleep(nanoseconds: 5_000_000_000)

            // Show final parsed tags (don't clear - show final state)
            await showParsedTags(from: bridge, label: "Final State", clearAfter: false)

            // Disconnect
            header("Shutting Down")
            await bridge.stop()
            await connection.disconnect()
            success("Disconnected cleanly")
        } catch let connectionError {
            error("Connection failed: \(connectionError.localizedDescription)")
            print("")
            print(Color.yellow.text("Make sure Lich is running with:"))
            print(Color.gray.text("  lich --without-frontend --detachable-client=8000"))
        }

        header("Test Complete")
    }

    /// Show parsed tags from the bridge
    ///
    /// - Parameters:
    ///   - bridge: The bridge to read tags from
    ///   - label: Section label to display
    ///   - clearAfter: Whether to clear tags after displaying (demonstrates memory management)
    static func showParsedTags(from bridge: ParserConnectionBridge, label: String, clearAfter: Bool = false) async {
        let tags = await bridge.getParsedTags()

        header(label)

        // Show count with memory limit context (10,000 tag limit)
        let limitPercent = (Double(tags.count) / 10_000.0) * 100.0
        let percentText = String(format: "%.1f", limitPercent)
        status("Total parsed tags: \(Color.yellow.text(String(tags.count))) (\(percentText)% of memory limit)")

        // Warn if approaching limit (> 50% = 5,000 tags)
        if tags.count > 5_000 {
            print(Color.yellow.text("⚠️  Tag accumulation > 50% of limit - consider clearing"))
        }

        if !tags.isEmpty {
            // Show last 10 tags
            let recentTags = Array(tags.suffix(10))
            print(Color.green.text("Most Recent Tags (\(recentTags.count)):"))

            for tag in recentTags {
                printTag(tag, indent: 0)
            }
        } else {
            print(Color.gray.text("  (no tags parsed yet)"))
        }

        // Clear tags if requested (demonstrates memory management best practice)
        if clearAfter && !tags.isEmpty {
            await bridge.clearParsedTags()
            success("Tags cleared - memory freed")
        }

        print("")
    }

    /// Pretty-print a GameTag with indentation
    static func printTag(_ tag: GameTag, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        let nameColor: Color = tag.name == ":text" ? .gray : .blue

        var line = "\(indentStr)• \(nameColor.text(tag.name))"

        // Add attributes
        if !tag.attrs.isEmpty {
            let attrs = tag.attrs.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
            line += Color.magenta.text(" [\(attrs)]")
        }

        // Add text
        if let text = tag.text, !text.isEmpty {
            let truncated = text.count > 50 ? String(text.prefix(50)) + "..." : text
            line += Color.yellow.text(": \"\(truncated)\"")
        }

        // Add stream ID
        if let streamId = tag.streamId {
            line += Color.cyan.text(" (stream: \(streamId))")
        }

        print(line)

        // Print children
        for child in tag.children {
            printTag(child, indent: indent + 1)
        }
    }
}
