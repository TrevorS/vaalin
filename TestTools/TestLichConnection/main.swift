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
        header("Lich Connection Test")

        // Create connection and parser
        let connection = LichConnection()
        let parser = XMLStreamParser()

        // Configuration
        let host = "127.0.0.1"
        let port: UInt16 = 8000

        status("Connecting to Lich at \(host):\(port)...")

        do {
            // Connect to Lich
            try await connection.connect(host: host, port: port, autoReconnect: false)
            success("Connected!")

            // Start streaming task
            let stream = await connection.dataStream
            let streamTask = Task {
                await streamData(from: stream, to: parser)
            }

            // Wait a moment for initial data
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Send test commands
            header("Sending Test Commands")

            let commands = ["look", "time", "info"]

            for command in commands {
                status("Sending: \(Color.yellow.text(command))")
                try await connection.send(command: command)

                // Wait for response
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            }

            // Keep streaming for a bit longer
            status("Streaming for 10 more seconds...")
            try await Task.sleep(nanoseconds: 10_000_000_000)

            // Disconnect
            header("Shutting Down")
            streamTask.cancel()
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

    /// Stream data from connection and parse it
    static func streamData(from stream: AsyncStream<Data>, to parser: XMLStreamParser) async {
        var chunkCount = 0
        var tagCount = 0

        header("XML Stream (Ctrl+C to stop)")

        for await data in stream {
            chunkCount += 1

            guard let xmlChunk = String(data: data, encoding: .utf8) else {
                error("Failed to decode chunk as UTF-8")
                continue
            }

            // Parse the XML chunk
            let tags = await parser.parse(xmlChunk)
            tagCount += tags.count

            // Print raw XML (truncated if too long)
            let displayXML = xmlChunk.count > 200
                ? String(xmlChunk.prefix(200)) + "..."
                : xmlChunk

            print(Color.gray.text("───────────────────────────────────────"))
            print(Color.cyan.text("Chunk #\(chunkCount)") + Color.gray.text(" (\(xmlChunk.count) bytes, \(tags.count) tags)"))
            print(Color.yellow.text(displayXML))

            // Print parsed tags
            if !tags.isEmpty {
                print(Color.green.text("Parsed Tags:"))
                for tag in tags {
                    printTag(tag, indent: 0)
                }
            }
        }

        print("")
        success("Stream ended (\(chunkCount) chunks, \(tagCount) total tags)")
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
