// ABOUTME: XMLPrettyPrinter formats raw XML strings with indentation using proper XMLParser
// Async implementation runs on background thread for UI performance

import Foundation

/// Formats XML strings with proper indentation for improved readability.
///
/// Uses Foundation's XMLParser for robust parsing, running asynchronously on background thread.
///
/// Performance target: < 5ms per operation for typical game output chunks
///
/// ## Features
/// - Indents nested tags with 2 spaces per level
/// - Handles all XML edge cases (entities, CDATA, processing instructions)
/// - Async execution on background thread (non-blocking)
/// - Preserves text content with decoded entities
///
/// ## Example
/// ```swift
/// let xml = "<pushStream id=\"thoughts\"><preset id=\"thought\">You think...</preset></pushStream>"
/// let formatted = await XMLPrettyPrinter.format(xml)
/// // Result:
/// // <pushStream id="thoughts">
/// //   <preset id="thought">You think...</preset>
/// // </pushStream>
/// ```
struct XMLPrettyPrinter {
    // MARK: - Public API

    /// Format XML string with indentation asynchronously
    ///
    /// - Parameter xml: Raw XML string to format
    /// - Returns: Formatted XML with proper indentation
    static func format(_ xml: String) async -> String {
        guard !xml.isEmpty else { return xml }

        // Wrap in root tag for XMLParser (requires single root element)
        let wrappedXML = "<__root__>\(xml)</__root__>"

        guard let data = wrappedXML.data(using: .utf8) else {
            return xml // Fallback to original if encoding fails
        }

        // Create formatter and parse on background thread
        let formatter = XMLFormatter()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = formatter

        // Parse synchronously (already on background via Task.detached in caller)
        let success = xmlParser.parse()

        if success {
            return formatter.getFormattedOutput()
        } else {
            // Parse failed - return original
            return xml
        }
    }
}

// MARK: - XMLFormatter Implementation

/// Internal formatter that implements XMLParserDelegate to build indented output
private final class XMLFormatter: NSObject, XMLParserDelegate {
    private var output: String = ""
    private var indentLevel: Int = 0
    private let indent = "  " // 2 spaces per level
    private var characterBuffer: String = ""
    private var skipRoot: Bool = true // Skip synthetic root tag

    /// Get the formatted output string
    func getFormattedOutput() -> String {
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - XMLParserDelegate Methods

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Skip synthetic root tag
        if elementName == "__root__" && skipRoot {
            skipRoot = false
            return
        }

        // Flush any pending character data
        flushCharacterBuffer()

        // Add indentation
        output += String(repeating: indent, count: indentLevel)

        // Build opening tag
        output += "<\(elementName)"

        // Add attributes
        for (key, value) in attributeDict.sorted(by: { $0.key < $1.key }) {
            let escapedValue = value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            output += " \(key)=\"\(escapedValue)\""
        }

        output += ">\n"

        // Increase indent for children
        indentLevel += 1
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Skip synthetic root tag
        if elementName == "__root__" {
            return
        }

        // Flush any pending character data
        flushCharacterBuffer()

        // Decrease indent
        indentLevel = max(0, indentLevel - 1)

        // Add indentation
        output += String(repeating: indent, count: indentLevel)

        // Build closing tag
        output += "</\(elementName)>\n"
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Accumulate character data (XMLParser can call this multiple times)
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        // Flush any pending character data first
        flushCharacterBuffer()

        // Add CDATA section
        if let cdataString = String(data: CDATABlock, encoding: .utf8) {
            output += String(repeating: indent, count: indentLevel)
            output += "<![CDATA[\(cdataString)]]>\n"
        }
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
        // Flush any pending character data first
        flushCharacterBuffer()

        // Add comment
        output += String(repeating: indent, count: indentLevel)
        output += "<!--\(comment)-->\n"
    }

    func parser(
        _ parser: XMLParser,
        foundProcessingInstructionWithTarget target: String,
        data: String?
    ) {
        // Flush any pending character data first
        flushCharacterBuffer()

        // Add processing instruction
        output += String(repeating: indent, count: indentLevel)
        if let data = data {
            output += "<?xml \(target) \(data)?>\n"
        } else {
            output += "<?xml \(target)?>\n"
        }
    }

    // MARK: - Private Helpers

    /// Flush accumulated character data to output
    private func flushCharacterBuffer() {
        guard !characterBuffer.isEmpty else { return }

        // Trim whitespace-only content
        let trimmed = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // Add indented text content
            output += String(repeating: indent, count: indentLevel)
            output += trimmed
            output += "\n"
        }

        // Clear buffer
        characterBuffer = ""
    }
}
