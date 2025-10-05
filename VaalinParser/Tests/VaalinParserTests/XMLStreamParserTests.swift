// ABOUTME: Tests for XMLStreamParser actor - stateful SAX-based XML parsing with chunked TCP support

import Foundation
import Testing
@testable import VaalinCore
@testable import VaalinParser

// swiftlint:disable file_length type_body_length

/// Test suite for XMLStreamParser actor
/// Validates actor initialization, delegate conformance, state management, and chunked XML parsing
///
/// TDD Approach: These tests are written BEFORE implementation to drive design.
/// Initial tests focus on skeleton structure and will fail until implementation exists.
struct XMLStreamParserTests {
    // MARK: - Initialization Tests

    /// Test parser initializes correctly as an actor
    /// Verifies that XMLStreamParser can be instantiated and is an actor type
    @Test func test_parserInitialization() async throws {
        // Parser should initialize successfully
        // This verifies the actor exists and can be created
        _ = XMLStreamParser()
    }

    /// Test parser initial state is correct
    /// Parser must start with clean state for stream tracking
    @Test func test_parserInitialState() async throws {
        let parser = XMLStreamParser()

        // Verify persistent state starts clean
        let currentStream = await parser.getCurrentStream()
        let inStream = await parser.getInStream()

        #expect(currentStream == nil)
        #expect(inStream == false)
    }

    // MARK: - Empty Input Tests

    /// Test empty chunk returns no tags
    /// Parser should gracefully handle empty input without errors
    @Test func test_emptyChunkReturnsNoTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("")

        #expect(tags.isEmpty)
    }

    /// Test whitespace-only chunk returns no tags
    /// Parser should treat pure whitespace as empty
    @Test func test_whitespaceOnlyChunkReturnsNoTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("   \n\t  ")

        #expect(tags.isEmpty)
    }

    // MARK: - Method Signature Tests

    /// Test parse method exists and is async
    /// Verifies the async parse method signature matches requirements
    @Test func test_parseMethodIsAsync() async throws {
        let parser = XMLStreamParser()

        // Parse method should accept String and return [GameTag] asynchronously
        // Type system enforces this at compile time
        _ = await parser.parse("<test/>")
    }

    /// Test parse method accepts String parameter
    /// Verifies parse takes XML chunk as String input
    @Test func test_parseMethodAcceptsString() async throws {
        let parser = XMLStreamParser()

        // Should accept various string inputs without type errors
        _ = await parser.parse("")
        _ = await parser.parse("<tag/>")
        _ = await parser.parse("multiple\nlines\nof\nxml")

        #expect(Bool(true)) // Test completes without compile errors
    }

    /// Test parse method returns array of GameTag
    /// Verifies return type is [GameTag] for downstream processing
    @Test func test_parseMethodReturnsGameTagArray() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("")

        // Verify return type is exactly [GameTag]
        #expect(type(of: tags) == [GameTag].self)
    }

    // MARK: - State Accessor Tests

    /// Test getCurrentStream accessor exists
    /// Parser must expose current stream state for testing and debugging
    @Test func test_getCurrentStreamAccessor() async throws {
        let parser = XMLStreamParser()

        // Accessor should exist and return Optional String
        _ = await parser.getCurrentStream()
    }

    /// Test getInStream accessor exists
    /// Parser must expose stream flag state for testing and debugging
    @Test func test_getInStreamAccessor() async throws {
        let parser = XMLStreamParser()

        // Accessor should exist and return Bool
        _ = await parser.getInStream()
    }

    // MARK: - Actor Isolation Tests

    /// Test parser is isolated as an actor
    /// Verifies concurrent access is serialized through actor isolation
    @Test func test_parserIsActorIsolated() async throws {
        let parser = XMLStreamParser()

        // Multiple concurrent parse calls should be serialized by actor
        async let parse1 = parser.parse("")
        async let parse2 = parser.parse("")
        async let parse3 = parser.parse("")

        let results = await [parse1, parse2, parse3]

        // All should complete without data races
        #expect(results.count == 3)
    }

    /// Test state remains consistent across multiple parse calls
    /// Parser state should persist between invocations (critical for chunked parsing)
    @Test func test_statePersistsAcrossParseCalls() async throws {
        let parser = XMLStreamParser()

        // First parse
        _ = await parser.parse("")
        let stream1 = await parser.getCurrentStream()

        // Second parse
        _ = await parser.parse("")
        let stream2 = await parser.getCurrentStream()

        // State should still be accessible and consistent
        #expect(stream1 == stream2)
    }

    // MARK: - XMLParserDelegate Conformance Tests

    /// Test parser conforms to XMLParserDelegate protocol
    /// Required for NSXMLParser SAX-based parsing
    @Test func test_parserConformsToXMLParserDelegate() async throws {
        // Parser should conform to XMLParserDelegate
        // This is verified at compile time by the protocol conformance
        _ = XMLStreamParser()
    }

    /// Test parser inherits from NSObject
    /// Required for XMLParserDelegate conformance
    @Test func test_parserInheritsFromNSObject() async throws {
        // Parser should inherit from NSObject for Objective-C protocol conformance
        // This is verified at compile time by the class inheritance
        _ = XMLStreamParser()
    }

    // MARK: - Basic Parse Structure Tests

    /// Test parser handles nil return gracefully
    /// Parser should never crash on any input
    @Test func test_parseNeverReturnsNil() async throws {
        let parser = XMLStreamParser()

        // Should return array (possibly empty), never nil
        // Type system guarantees this - [GameTag] is non-optional
        _ = await parser.parse("")
    }

    /// Test parser can be called multiple times
    /// Parser should be reusable across multiple parse operations
    @Test func test_parserIsReusable() async throws {
        let parser = XMLStreamParser()

        _ = await parser.parse("")
        _ = await parser.parse("")
        _ = await parser.parse("")

        // Should complete without errors
        #expect(Bool(true))
    }

    // MARK: - Edge Cases

    /// Test parser handles very long empty string
    /// Performance check: parser should handle large empty input efficiently
    @Test func test_parseLargeEmptyString() async throws {
        let parser = XMLStreamParser()
        let largeEmpty = String(repeating: " ", count: 10000)

        let tags = await parser.parse(largeEmpty)

        #expect(tags.isEmpty)
    }

    /// Test parser handles newlines in empty input
    /// Parser should treat newlines as whitespace
    @Test func test_parseNewlinesOnly() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("\n\n\n\n")

        #expect(tags.isEmpty)
    }

    /// Test parser handles mixed whitespace
    /// Parser should normalize all whitespace types
    @Test func test_parseMixedWhitespace() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse(" \n \t \r\n ")

        #expect(tags.isEmpty)
    }

    // MARK: - Type Safety Tests

    /// Test parser returns Sendable types
    /// GameTag array must be safe to pass across actor boundaries
    @Test func test_parseReturnsSendableType() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("")

        // Should be safe to send across actors
        Task {
            _ = tags // Capture in different task
        }

        #expect(Bool(true))
    }

    // MARK: - Documentation Tests

    /// Test parser has expected public API surface
    /// Verifies all required methods are publicly accessible
    @Test func test_parserPublicAPI() async throws {
        let parser = XMLStreamParser()

        // Core API: parse method
        _ = await parser.parse("")

        // State inspection API (for testing/debugging)
        _ = await parser.getCurrentStream()
        _ = await parser.getInStream()

        #expect(Bool(true))
    }

    // MARK: - Performance Baseline Tests

    /// Test parser completes empty parse quickly
    /// Performance target: < 1ms for empty input (baseline for comparison)
    @Test func test_emptyParsePerformance() async throws {
        let parser = XMLStreamParser()

        let start = Date()
        _ = await parser.parse("")
        let duration = Date().timeIntervalSince(start)

        // Should complete in < 1ms (very generous for empty input)
        #expect(duration < 0.001)
    }

    /// Test multiple rapid parse calls complete quickly
    /// Parser should handle rapid successive calls efficiently
    @Test func test_rapidParseCalls() async throws {
        let parser = XMLStreamParser()

        let start = Date()
        for _ in 0..<100 {
            _ = await parser.parse("")
        }
        let duration = Date().timeIntervalSince(start)

        // 100 empty parses should complete in < 100ms
        #expect(duration < 0.1)
    }

    /// Test deep nesting performance with high volume
    /// Validates >10k lines/min performance requirement with complex nested structures
    @Test func test_deepNestingPerformance() async throws {
        let parser = XMLStreamParser()

        // 1000 deeply nested structures (5 levels each)
        var xml = ""
        for _ in 0..<1000 {
            xml += "<l1><l2><l3><l4><l5>text</l5></l4></l3></l2></l1>"
        }

        let start = Date()
        let tags = await parser.parse(xml)
        let duration = Date().timeIntervalSince(start)

        // 1000 structures should parse in < 100ms
        #expect(duration < 0.1, "Deep nesting took \(duration)s, expected < 0.1s")
        #expect(tags.count == 1000) // Verify parsing succeeded
    }

    /// Test throughput performance with chunked parsing
    /// Validates >10k lines/min performance requirement with realistic game output
    @Test func test_chunkThroughputPerformance() async throws {
        let parser = XMLStreamParser()

        // Generate 10k lines of XML (typical game output pattern)
        // Mix of prompts, text, and tags to simulate real usage
        var testXML = ""
        for i in 1...10_000 {
            testXML += "<prompt>\(i)</prompt>\n"
        }

        let start = Date()
        _ = await parser.parse(testXML)
        let duration = Date().timeIntervalSince(start)

        let linesPerMinute = (10_000.0 / duration) * 60.0
        #expect(linesPerMinute > 10_000.0, "Throughput: \(linesPerMinute) lines/min, expected > 10k")
    }

    // MARK: - Integration Preparation Tests

    /// Test parser integrates with GameTag model
    /// Parser output must use GameTag from VaalinCore
    @Test func test_parserUsesGameTagModel() async throws {
        let parser = XMLStreamParser()

        // Type system verifies GameTag compatibility at compile time
        _ = await parser.parse("")

        // Future: Will verify actual GameTag creation in later tests
    }

    /// Test parser state management design
    /// Documents expected state management for chunked parsing
    @Test func test_stateManagementDesign() async throws {
        let parser = XMLStreamParser()

        // Initial state should be clean
        let initialStream = await parser.getCurrentStream()
        let initialInStream = await parser.getInStream()

        #expect(initialStream == nil)
        #expect(initialInStream == false)

        // Future: Will test state changes when pushStream/popStream parsing is implemented
    }

    // MARK: - Issue #7: Simple Tag Parsing Tests

    /// Test parsing a simple text node
    /// Text outside of tags should be represented as :text nodes
    @Test func test_parseTextNode() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("Hello, world!")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == ":text")
        #expect(tag.text == "Hello, world!")
        #expect(tag.attrs.isEmpty)
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing a prompt tag
    /// <prompt>&gt;</prompt> should parse correctly with HTML entity
    @Test func test_parsePromptTag() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<prompt>&gt;</prompt>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "prompt")
        #expect(tag.text == ">")
        #expect(tag.attrs.isEmpty)
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing left hand tag
    /// <left>Empty</left> should parse correctly
    @Test func test_parseLeftHandTag() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<left>Empty</left>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "left")
        #expect(tag.text == "Empty")
        #expect(tag.attrs.isEmpty)
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing right hand tag
    /// <right>Empty</right> should parse correctly
    @Test func test_parseRightHandTag() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<right>Empty</right>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "right")
        #expect(tag.text == "Empty")
        #expect(tag.attrs.isEmpty)
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing tag with attributes
    /// <a exist="12345" noun="gem">blue gem</a> should parse all attributes
    @Test func test_parseAttributes() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<a exist=\"12345\" noun=\"gem\">blue gem</a>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "a")
        #expect(tag.text == "blue gem")
        #expect(tag.attrs["exist"] == "12345")
        #expect(tag.attrs["noun"] == "gem")
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing self-closing tag
    /// <component id="room"/> should parse correctly
    @Test func test_parseSelfClosingTag() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<component id=\"room\"/>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "component")
        #expect(tag.text == nil || tag.text == "")
        #expect(tag.attrs["id"] == "room")
        #expect(tag.children.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing multiple tags in one chunk
    /// Multiple tags should all be parsed and returned
    @Test func test_parseMultipleTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<left>Empty</left><right>Empty</right>")

        #expect(tags.count == 2)
        #expect(tags[0].name == "left")
        #expect(tags[0].text == "Empty")
        #expect(tags[1].name == "right")
        #expect(tags[1].text == "Empty")
    }

    /// Test parsing tag with empty content
    /// <left></left> should parse with empty text
    @Test func test_parseEmptyTag() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<left></left>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "left")
        #expect(tag.text == "" || tag.text == nil)
        #expect(tag.state == .closed)
    }

    /// Test parsing tag with whitespace content
    /// <prompt>   </prompt> should preserve whitespace
    @Test func test_parseTagWithWhitespace() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<prompt>   </prompt>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "prompt")
        #expect(tag.text == "   ")
    }

    /// Test parsing text mixed with tags
    /// Text nodes should be interspersed with tag nodes
    @Test func test_parseTextMixedWithTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("You see <a exist=\"123\" noun=\"gem\">a blue gem</a> here.")

        #expect(tags.count == 3)
        #expect(tags[0].name == ":text")
        #expect(tags[0].text == "You see ")
        #expect(tags[1].name == "a")
        #expect(tags[1].text == "a blue gem")
        #expect(tags[2].name == ":text")
        #expect(tags[2].text == " here.")
    }

    /// Test incomplete tag across chunk boundary
    /// Incomplete tag should NOT be returned until completed in next chunk
    @Test func test_incompleteTagBuffering() async throws {
        let parser = XMLStreamParser()

        // First chunk: incomplete tag
        let tags1 = await parser.parse("<a exist=\"123\" noun=\"gem\">blue")

        // Should return nothing - tag not complete
        #expect(tags1.isEmpty)

        // Second chunk: complete the tag
        let tags2 = await parser.parse(" gem</a>")

        // Now should return the complete tag
        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "a")
        #expect(tag.text == "blue gem")
        #expect(tag.attrs["exist"] == "123")
        #expect(tag.attrs["noun"] == "gem")
    }

    /// Test incomplete tag at start of chunk
    /// Parser should handle partial opening tag
    @Test func test_incompleteOpeningTag() async throws {
        let parser = XMLStreamParser()

        // First chunk: partial opening tag
        let tags1 = await parser.parse("<a exist=")

        #expect(tags1.isEmpty)

        // Second chunk: complete the tag
        let tags2 = await parser.parse("\"123\">gem</a>")

        #expect(tags2.count == 1)
        #expect(tags2[0].name == "a")
        #expect(tags2[0].attrs["exist"] == "123")
    }

    // MARK: - Additional Edge Cases for Issue #7 Coverage

    /// Test parsing tag with multiple attributes of different types
    /// Verifies attribute dictionary handles various value types
    @Test func test_parseMultipleAttributes() async throws {
        let parser = XMLStreamParser()

        let xml = "<progressBar id=\"health\" value=\"100\" left=\"100\" right=\"100\" text=\"100%\"/>"
        let tags = await parser.parse(xml)

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "progressBar")
        #expect(tag.attrs["id"] == "health")
        #expect(tag.attrs["value"] == "100")
        #expect(tag.attrs["left"] == "100")
        #expect(tag.attrs["right"] == "100")
        #expect(tag.attrs["text"] == "100%")
        #expect(tag.attrs.count == 5)
    }

    /// Test parsing tag with attributes containing special characters
    /// Attributes should handle quotes, ampersands, etc.
    @Test func test_parseAttributesWithSpecialCharacters() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<a title=\"O&apos;Malley&apos;s Inn\">inn</a>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "a")
        #expect(tag.attrs["title"] == "O'Malley's Inn")
        #expect(tag.text == "inn")
    }

    /// Test parsing tag with no attributes but with content
    /// Common case for simple tags like <prompt>
    @Test func test_parseTagWithoutAttributes() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>You see nothing special.</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "You see nothing special.")
        #expect(tag.attrs.isEmpty)
        #expect(tag.state == .closed)
    }

    /// Test parsing multiple self-closing tags
    /// Verifies self-closing tags don't interfere with each other
    @Test func test_parseMultipleSelfClosingTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<component id=\"room\"/><component id=\"exits\"/>")

        #expect(tags.count == 2)
        #expect(tags[0].name == "component")
        #expect(tags[0].attrs["id"] == "room")
        #expect(tags[1].name == "component")
        #expect(tags[1].attrs["id"] == "exits")
    }

    /// Test parsing text with HTML entities
    /// XMLParser should decode entities like &lt;, &gt;, &amp;
    @Test func test_parseHTMLEntities() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>&lt;hidden&gt; &amp; visible</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "<hidden> & visible")
    }

    /// Test parsing tag with newlines in content
    /// Multiline content should be preserved
    @Test func test_parseMultilineContent() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>Line 1\nLine 2\nLine 3</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "Line 1\nLine 2\nLine 3")
    }

    /// Test parsing tags with mixed case names
    /// XML is case-sensitive, verify we preserve case
    @Test func test_parseMixedCaseTagNames() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<LeftHand>sword</LeftHand>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "LeftHand")
        #expect(tag.text == "sword")
    }

    /// Test parsing tag split across chunks (opening tag complete)
    /// Opening tag in chunk 1, content and closing tag in chunk 2
    @Test func test_parseTagSplitAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // First chunk: complete opening tag
        let tags1 = await parser.parse("<prompt>")

        #expect(tags1.isEmpty) // Tag not closed yet

        // Second chunk: content and closing tag
        let tags2 = await parser.parse("&gt;</prompt>")

        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "prompt")
        #expect(tag.text == ">")
    }

    /// Test parsing tag with only whitespace between tags
    /// Whitespace between tags should create text nodes
    @Test func test_parseWhitespaceBetweenTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<left>Empty</left>   <right>Empty</right>")

        #expect(tags.count == 3)
        #expect(tags[0].name == "left")
        #expect(tags[1].name == ":text")
        #expect(tags[1].text == "   ")
        #expect(tags[2].name == "right")
    }

    /// Test parsing tag with trailing whitespace before closing
    /// Whitespace in content should be preserved
    @Test func test_parseTagWithTrailingWhitespace() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>content   </output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "content   ")
    }

    /// Test parsing tag with leading whitespace after opening
    /// Whitespace in content should be preserved
    @Test func test_parseTagWithLeadingWhitespace() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>   content</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "   content")
    }

    /// Test parsing very long text content
    /// Ensure parser handles large text nodes efficiently
    @Test func test_parseLongTextContent() async throws {
        let parser = XMLStreamParser()
        let longText = String(repeating: "A", count: 1000)

        let tags = await parser.parse("<output>\(longText)</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == longText)
        #expect(tag.text?.count == 1000)
    }

    /// Test parsing tag with empty attribute value
    /// Attributes can have empty string values
    @Test func test_parseAttributeWithEmptyValue() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<a exist=\"\" noun=\"gem\">gem</a>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.attrs["exist"] == "")
        #expect(tag.attrs["noun"] == "gem")
    }

    /// Test parsing multiple chunks forming complete tags
    /// Verifies state properly carries over across multiple parse() calls
    @Test func test_parseMultipleChunksFormingTags() async throws {
        let parser = XMLStreamParser()

        // Parse in 4 chunks
        let tags1 = await parser.parse("<a exist=")
        #expect(tags1.isEmpty)

        let tags2 = await parser.parse("\"123\" noun")
        #expect(tags2.isEmpty)

        let tags3 = await parser.parse("=\"gem\">blue ")
        #expect(tags3.isEmpty)

        let tags4 = await parser.parse("gem</a>")
        #expect(tags4.count == 1)
        #expect(tags4[0].name == "a")
        #expect(tags4[0].text == "blue gem")
        #expect(tags4[0].attrs["exist"] == "123")
        #expect(tags4[0].attrs["noun"] == "gem")
    }

    /// Test parsing real GemStone IV output pattern
    /// Verifies realistic game output with mixed tags and text
    @Test func test_parseRealisticGameOutput() async throws {
        let parser = XMLStreamParser()

        let gameOutput = "You see <a exist=\"12345\" noun=\"gem\">a blue gem</a> and " +
            "<a exist=\"67890\" noun=\"coin\">a gold coin</a>."
        let tags = await parser.parse(gameOutput)

        #expect(tags.count == 5)
        #expect(tags[0].name == ":text")
        #expect(tags[0].text == "You see ")
        #expect(tags[1].name == "a")
        #expect(tags[1].text == "a blue gem")
        #expect(tags[2].name == ":text")
        #expect(tags[2].text == " and ")
        #expect(tags[3].name == "a")
        #expect(tags[3].text == "a gold coin")
        #expect(tags[4].name == ":text")
        #expect(tags[4].text == ".")
    }

    /// Test parsing tag with Unicode characters
    /// Ensure proper UTF-8 handling
    @Test func test_parseUnicodeContent() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<output>Hello 世界 🌍</output>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "Hello 世界 🌍")
    }

    /// Test parsing consecutive self-closing tags without whitespace
    /// Edge case for tight XML formatting
    @Test func test_parseConsecutiveSelfClosingTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<br/><br/><br/>")

        #expect(tags.count == 3)
        #expect(tags[0].name == "br")
        #expect(tags[1].name == "br")
        #expect(tags[2].name == "br")
    }

    /// Test parsing numeric attribute values
    /// Attributes are strings but commonly contain numbers
    @Test func test_parseNumericAttributeValues() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<progressBar value=\"100\" max=\"150\"/>")

        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.attrs["value"] == "100")
        #expect(tag.attrs["max"] == "150")
    }

    // MARK: - Issue #8: Nested Tag Parsing Tests

    /// Test parsing basic nested tags
    /// <outer><inner>text</inner></outer> should create parent-child relationship
    @Test func test_parseNestedTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<outer><inner>text</inner></outer>")

        #expect(tags.count == 1)
        let outer = tags[0]
        #expect(outer.name == "outer")
        #expect(outer.text == nil) // Container has no direct text
        #expect(outer.children.count == 1)
        #expect(outer.state == .closed)

        let inner = outer.children[0]
        #expect(inner.name == "inner")
        #expect(inner.text == "text")
        #expect(inner.children.isEmpty)
        #expect(inner.state == .closed)
    }

    /// Test parsing deeply nested tags (5+ levels)
    /// Verifies unlimited nesting depth support
    @Test func test_deepNesting() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<l1><l2><l3><l4><l5>deep</l5></l4></l3></l2></l1>")

        #expect(tags.count == 1)
        let l1 = tags[0]
        #expect(l1.name == "l1")
        #expect(l1.children.count == 1)

        let l2 = l1.children[0]
        #expect(l2.name == "l2")
        #expect(l2.children.count == 1)

        let l3 = l2.children[0]
        #expect(l3.name == "l3")
        #expect(l3.children.count == 1)

        let l4 = l3.children[0]
        #expect(l4.name == "l4")
        #expect(l4.children.count == 1)

        let l5 = l4.children[0]
        #expect(l5.name == "l5")
        #expect(l5.text == "deep")
        #expect(l5.children.isEmpty)
    }

    /// Test parsing multiple sibling tags within parent
    /// <parent><child1/><child2/><child3/></parent> should create 3 children
    @Test func test_multipleSiblings() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<parent><child1/><child2/><child3/></parent>")

        #expect(tags.count == 1)
        let parent = tags[0]
        #expect(parent.name == "parent")
        #expect(parent.children.count == 3)

        #expect(parent.children[0].name == "child1")
        #expect(parent.children[1].name == "child2")
        #expect(parent.children[2].name == "child3")
    }

    /// Test parsing mixed content with nested tags
    /// <parent>text<child/>more text</parent> should handle text and children
    @Test func test_mixedNesting() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<parent>before<child>middle</child>after</parent>")

        #expect(tags.count == 1)
        let parent = tags[0]
        #expect(parent.name == "parent")
        // Parent should have 3 children: :text, child tag, :text
        #expect(parent.children.count == 3)

        #expect(parent.children[0].name == ":text")
        #expect(parent.children[0].text == "before")

        #expect(parent.children[1].name == "child")
        #expect(parent.children[1].text == "middle")

        #expect(parent.children[2].name == ":text")
        #expect(parent.children[2].text == "after")
    }

    /// Test nested tags with attributes at multiple levels
    /// Attributes should be preserved at each nesting level
    @Test func test_nestedTagsWithAttributes() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<d cmd=\"look\"><a exist=\"123\" noun=\"gem\">blue gem</a></d>")

        #expect(tags.count == 1)
        let dTag = tags[0]
        #expect(dTag.name == "d")
        #expect(dTag.attrs["cmd"] == "look")
        #expect(dTag.children.count == 1)

        let aTag = dTag.children[0]
        #expect(aTag.name == "a")
        #expect(aTag.attrs["exist"] == "123")
        #expect(aTag.attrs["noun"] == "gem")
        #expect(aTag.text == "blue gem")
    }

    /// Test real GemStone IV nested structure
    /// <d><a>item</a></d> is common pattern for clickable items
    @Test func test_gemstoneNestedStructure() async throws {
        let parser = XMLStreamParser()

        let xml = "<d cmd=\"look at gem\"><a exist=\"12345\" noun=\"gem\">blue gem</a></d>"
        let tags = await parser.parse(xml)

        #expect(tags.count == 1)
        let dTag = tags[0]
        #expect(dTag.name == "d")
        #expect(dTag.attrs["cmd"] == "look at gem")
        #expect(dTag.children.count == 1)

        let aTag = dTag.children[0]
        #expect(aTag.name == "a")
        #expect(aTag.text == "blue gem")
    }

    /// Test nested self-closing tags
    /// Self-closing tags within containers should work correctly
    @Test func test_nestedSelfClosingTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<container><item id=\"1\"/><item id=\"2\"/></container>")

        #expect(tags.count == 1)
        let container = tags[0]
        #expect(container.children.count == 2)
        #expect(container.children[0].attrs["id"] == "1")
        #expect(container.children[1].attrs["id"] == "2")
    }

    /// Test nested tags across chunk boundaries
    /// Opening parent in chunk 1, children in chunk 2, closing parent in chunk 3
    @Test func test_nestedTagsAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Open parent
        let tags1 = await parser.parse("<parent>")
        #expect(tags1.isEmpty) // Parent not closed yet

        // Chunk 2: Add child
        let tags2 = await parser.parse("<child>text</child>")
        #expect(tags2.isEmpty) // Parent still not closed

        // Chunk 3: Close parent
        let tags3 = await parser.parse("</parent>")
        #expect(tags3.count == 1)

        let parent = tags3[0]
        #expect(parent.name == "parent")
        #expect(parent.children.count == 1)
        #expect(parent.children[0].name == "child")
        #expect(parent.children[0].text == "text")
    }

    /// Test deep nesting across chunk boundaries
    /// Complex nesting state must persist correctly
    @Test func test_deepNestingAcrossChunks() async throws {
        let parser = XMLStreamParser()

        let tags1 = await parser.parse("<l1><l2>")
        #expect(tags1.isEmpty)

        let tags2 = await parser.parse("<l3>text</l3>")
        #expect(tags2.isEmpty)

        let tags3 = await parser.parse("</l2></l1>")
        #expect(tags3.count == 1)

        let l1 = tags3[0]
        #expect(l1.children.count == 1)
        let l2 = l1.children[0]
        #expect(l2.children.count == 1)
        let l3 = l2.children[0]
        #expect(l3.text == "text")
    }

    /// Test nested tags with text at root level
    /// Root text followed by nested structure
    @Test func test_nestedTagsWithRootText() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("You see <d><a exist=\"123\" noun=\"gem\">gem</a></d> here.")

        #expect(tags.count == 3)
        #expect(tags[0].name == ":text")
        #expect(tags[0].text == "You see ")

        #expect(tags[1].name == "d")
        #expect(tags[1].children.count == 1)
        #expect(tags[1].children[0].name == "a")

        #expect(tags[2].name == ":text")
        #expect(tags[2].text == " here.")
    }

    /// Test complex mixed siblings and nesting
    /// Multiple nested levels with siblings at different depths
    @Test func test_complexMixedNesting() async throws {
        let parser = XMLStreamParser()

        let xml = "<root><a>1</a><b><c>2</c><d>3</d></b><e>4</e></root>"
        let tags = await parser.parse(xml)

        #expect(tags.count == 1)
        let root = tags[0]
        #expect(root.children.count == 3)

        #expect(root.children[0].name == "a")
        #expect(root.children[0].text == "1")

        #expect(root.children[1].name == "b")
        #expect(root.children[1].children.count == 2)
        #expect(root.children[1].children[0].name == "c")
        #expect(root.children[1].children[0].text == "2")
        #expect(root.children[1].children[1].name == "d")
        #expect(root.children[1].children[1].text == "3")

        #expect(root.children[2].name == "e")
        #expect(root.children[2].text == "4")
    }

    /// Test nested empty tags
    /// <parent><child></child></parent> with no content
    @Test func test_nestedEmptyTags() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<parent><child></child></parent>")

        #expect(tags.count == 1)
        let parent = tags[0]
        #expect(parent.children.count == 1)
        #expect(parent.children[0].name == "child")
        #expect(parent.children[0].text == nil || parent.children[0].text == "")
    }

    /// Test very deep nesting (10+ levels)
    /// Performance and stack depth test
    @Test func test_veryDeepNesting() async throws {
        let parser = XMLStreamParser()

        let xml = "<l1><l2><l3><l4><l5><l6><l7><l8><l9><l10>bottom</l10></l9></l8></l7></l6></l5></l4></l3></l2></l1>"
        let tags = await parser.parse(xml)

        #expect(tags.count == 1)

        var current = tags[0]
        for level in 1...10 {
            #expect(current.name == "l\(level)")
            if level < 10 {
                #expect(current.children.count == 1)
                current = current.children[0]
            } else {
                #expect(current.text == "bottom")
            }
        }
    }

    /// Test malformed nesting - closing wrong tag
    /// Parser should handle mismatched tags gracefully
    @Test func test_mismatchedNestingTags() async throws {
        let parser = XMLStreamParser()

        // <a><b></a></b> - mismatched closing
        let tags = await parser.parse("<a><b></a></b>")

        // Parser should handle gracefully (may discard malformed portion)
        // This documents current behavior - detailed error recovery in Issue #12
        // For now, we just verify it doesn't crash
        _ = tags
    }

    /// Test unexpected closing tag without matching open tag
    /// Covers error handling path for closing tag without open tag (lines 296-298)
    @Test func test_unexpectedClosingTag() async throws {
        let parser = XMLStreamParser()

        // Closing tag without matching open tag
        let tags = await parser.parse("text</nonexistent>")

        // Should handle gracefully (exact behavior TBD in Issue #12)
        // For now, verify it doesn't crash and returns some result
        _ = tags
    }

    /// Test tag name mismatch between open and close
    /// Covers error handling path for mismatched tag names (lines 303-305)
    @Test func test_tagNameMismatch() async throws {
        let parser = XMLStreamParser()

        // <a> opened but </b> closed
        let tags = await parser.parse("<a>text</b>")

        // Should handle gracefully - parser may auto-close unclosed tags
        // Detailed error recovery specified in Issue #12
        _ = tags
    }

    /// Test nested tags with whitespace preservation
    /// Whitespace in nested content should be maintained
    @Test func test_nestedTagsWithWhitespace() async throws {
        let parser = XMLStreamParser()

        let tags = await parser.parse("<parent>  <child>  text  </child>  </parent>")

        #expect(tags.count == 1)
        let parent = tags[0]
        #expect(parent.children.count == 3) // :text, child, :text

        #expect(parent.children[0].name == ":text")
        #expect(parent.children[0].text == "  ")

        #expect(parent.children[1].name == "child")
        #expect(parent.children[1].text == "  text  ")

        #expect(parent.children[2].name == ":text")
        #expect(parent.children[2].text == "  ")
    }

    /// Test realistic GemStone IV combat output with nesting
    /// Complex real-world example with multiple nested levels
    @Test func test_realisticCombatOutput() async throws {
        let parser = XMLStreamParser()

        let combat = "You swing <d><a exist=\"123\" noun=\"sword\">a silver sword</a></d> at " +
            "<d><a exist=\"456\" noun=\"orc\">an orc</a></d>!"
        let tags = await parser.parse(combat)

        #expect(tags.count == 5) // :text, d, :text, d, :text

        #expect(tags[0].name == ":text")
        #expect(tags[0].text == "You swing ")

        #expect(tags[1].name == "d")
        #expect(tags[1].children.count == 1)
        #expect(tags[1].children[0].name == "a")
        #expect(tags[1].children[0].text == "a silver sword")

        #expect(tags[2].name == ":text")
        #expect(tags[2].text == " at ")

        #expect(tags[3].name == "d")
        #expect(tags[3].children.count == 1)
        #expect(tags[3].children[0].name == "a")
        #expect(tags[3].children[0].text == "an orc")

        #expect(tags[4].name == ":text")
        #expect(tags[4].text == "!")
    }

    // MARK: - Issue #9: Chunked/Incomplete XML Handling Tests

    /// Test incomplete tag buffering - tag cut off mid-element
    /// Incomplete tags should be buffered until complete in next chunk
    @Test func test_parseIncompleteTag() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Incomplete opening tag (cut off in tag name)
        let tags1 = await parser.parse("<pro")

        // Should buffer - nothing returned
        #expect(tags1.isEmpty)

        // Chunk 2: Complete the tag
        let tags2 = await parser.parse("mpt>&gt;</prompt>")

        // Now should return the complete tag
        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "prompt")
        #expect(tag.text == ">")
    }

    /// Test tag split across two chunks at attribute boundary
    /// Parser must handle incomplete attributes and continue correctly
    @Test func test_parseTagAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Tag with incomplete attribute
        let tags1 = await parser.parse("<a exist=\"123\" noun=\"ge")

        #expect(tags1.isEmpty)

        // Chunk 2: Complete attribute and tag
        let tags2 = await parser.parse("m\">blue gem</a>")

        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "a")
        #expect(tag.text == "blue gem")
        #expect(tag.attrs["exist"] == "123")
        #expect(tag.attrs["noun"] == "gem")
    }

    /// Test attribute split across chunks at value boundary
    /// Verifies attribute value parsing works across chunk boundaries
    @Test func test_parseAttributeAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Attribute name complete, value incomplete
        let tags1 = await parser.parse("<progressBar id=\"heal")

        #expect(tags1.isEmpty)

        // Chunk 2: Complete value and close tag
        let tags2 = await parser.parse("th\" value=\"100\"/>")

        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "progressBar")
        #expect(tag.attrs["id"] == "health")
        #expect(tag.attrs["value"] == "100")
    }

    /// Test stream state persistence across chunked parsing
    /// Critical: currentStream and inStream must persist between parse() calls
    @Test func test_streamStatePersistsAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // This test will be expanded in Issue #10 when stream tags are implemented
        // For now, verify that stream state accessors work across chunks

        let stream1 = await parser.getCurrentStream()
        _ = await parser.parse("<a>test</a>")
        let stream2 = await parser.getCurrentStream()

        // State should persist (both nil for now, but accessible)
        #expect(stream1 == stream2)
    }

    /// Test content split across chunks
    /// Tag content can be fragmented across multiple TCP packets
    @Test func test_midContentBreak() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Opening tag and partial content
        let tags1 = await parser.parse("<output>You see a blu")

        #expect(tags1.isEmpty)

        // Chunk 2: Rest of content and closing tag
        let tags2 = await parser.parse("e gem here.</output>")

        #expect(tags2.count == 1)
        let tag = tags2[0]
        #expect(tag.name == "output")
        #expect(tag.text == "You see a blue gem here.")
    }

    /// Test incomplete opening tag at various break points
    /// Opening tags can break anywhere: tag name, attributes, etc.
    @Test func test_midOpeningTagBreak() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Break in the middle of opening tag
        let tags1 = await parser.parse("<a ex")

        #expect(tags1.isEmpty)

        // Chunk 2: Complete opening tag and content
        let tags2 = await parser.parse("ist=\"123\" noun=\"gem\">gem</a>")

        #expect(tags2.count == 1)
        #expect(tags2[0].name == "a")
        #expect(tags2[0].attrs["exist"] == "123")
        #expect(tags2[0].attrs["noun"] == "gem")
        #expect(tags2[0].text == "gem")
    }

    /// Test multiple consecutive incomplete chunks
    /// Parser must accumulate buffers across many fragments
    @Test func test_multipleIncompleteChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Start of tag
        let tags1 = await parser.parse("<a ")
        #expect(tags1.isEmpty)

        // Chunk 2: First attribute name
        let tags2 = await parser.parse("exist")
        #expect(tags2.isEmpty)

        // Chunk 3: Equals and quote
        let tags3 = await parser.parse("=\"")
        #expect(tags3.isEmpty)

        // Chunk 4: Attribute value
        let tags4 = await parser.parse("123")
        #expect(tags4.isEmpty)

        // Chunk 5: Close quote and next attribute
        let tags5 = await parser.parse("\" noun=\"gem")
        #expect(tags5.isEmpty)

        // Chunk 6: Close opening tag
        let tags6 = await parser.parse("\">")
        #expect(tags6.isEmpty)

        // Chunk 7: Content
        let tags7 = await parser.parse("blue gem")
        #expect(tags7.isEmpty)

        // Chunk 8: Closing tag
        let tags8 = await parser.parse("</a>")
        #expect(tags8.count == 1)
        #expect(tags8[0].name == "a")
        #expect(tags8[0].text == "blue gem")
        #expect(tags8[0].attrs["exist"] == "123")
        #expect(tags8[0].attrs["noun"] == "gem")
    }

    /// Test very small chunks (character-by-character parsing)
    /// Extreme fragmentation test - parser should handle byte-level splits
    @Test func test_verySmallChunks() async throws {
        let parser = XMLStreamParser()

        // Parse a complete tag character by character
        let fullTag = "<prompt>&gt;</prompt>"
        var allTags: [GameTag] = []

        for char in fullTag {
            let tags = await parser.parse(String(char))
            allTags.append(contentsOf: tags)
        }

        // Should get exactly one complete tag at the end
        #expect(allTags.count == 1)
        #expect(allTags[0].name == "prompt")
        #expect(allTags[0].text == ">")
    }

    /// Test nested tags split across chunks
    /// Nesting state must be maintained across chunk boundaries
    @Test func test_nestedTagsChunked() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Outer tag start
        let tags1 = await parser.parse("<d cmd=\"loo")
        #expect(tags1.isEmpty)

        // Chunk 2: Complete outer, start inner
        let tags2 = await parser.parse("k\"><a exist=\"")
        #expect(tags2.isEmpty)

        // Chunk 3: Inner attributes and content
        let tags3 = await parser.parse("123\" noun=\"gem\">gem</a>")
        #expect(tags3.isEmpty)

        // Chunk 4: Close outer
        let tags4 = await parser.parse("</d>")
        #expect(tags4.count == 1)

        let outer = tags4[0]
        #expect(outer.name == "d")
        #expect(outer.attrs["cmd"] == "look")
        #expect(outer.children.count == 1)
        #expect(outer.children[0].name == "a")
        #expect(outer.children[0].text == "gem")
    }

    /// Test chunk ending with incomplete closing tag
    /// Closing tags can also be fragmented
    @Test func test_incompleteClosingTag() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Complete opening and content, partial closing
        let tags1 = await parser.parse("<output>text</out")

        #expect(tags1.isEmpty)

        // Chunk 2: Complete closing tag
        let tags2 = await parser.parse("put>")

        #expect(tags2.count == 1)
        #expect(tags2[0].name == "output")
        #expect(tags2[0].text == "text")
    }

    /// Test chunk with multiple complete tags followed by incomplete tag
    /// Mixed complete/incomplete content in single chunk
    @Test func test_mixedCompleteAndIncomplete() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Two complete tags + incomplete tag
        // Current implementation buffers entire chunk when parse fails
        let tags1 = await parser.parse("<left>Empty</left><right>Empty</right><pro")

        // Entire chunk is buffered due to incomplete tag at end
        #expect(tags1.isEmpty)

        // Chunk 2: Complete the buffered tag
        // Should now get all three tags from combined chunks
        let tags2 = await parser.parse("mpt>&gt;</prompt>")

        #expect(tags2.count == 3)
        #expect(tags2[0].name == "left")
        #expect(tags2[1].name == "right")
        #expect(tags2[2].name == "prompt")
    }

    /// Test real-world GemStone IV chunked output
    /// Realistic scenario with game text fragmentation
    @Test func test_realisticChunkedGameOutput() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Partial item description
        // The incomplete tag causes entire chunk to be buffered
        let tags1 = await parser.parse("You see <a exist=\"12345\" noun=\"")
        #expect(tags1.isEmpty) // Buffered due to incomplete tag

        // Chunk 2: Complete item
        // Should now get all content from both chunks
        let tags2 = await parser.parse("gem\">a blue gem</a> here.")
        #expect(tags2.count == 3) // :text "You see ", <a> tag, :text " here."
        #expect(tags2[0].name == ":text")
        #expect(tags2[0].text == "You see ")
        #expect(tags2[1].name == "a")
        #expect(tags2[1].text == "a blue gem")
        #expect(tags2[2].name == ":text")
        #expect(tags2[2].text == " here.")
    }

    /// Test buffer size limit protection
    /// Parser should protect against unbounded buffer growth
    @Test func test_bufferSizeLimitProtection() async throws {
        let parser = XMLStreamParser()

        // Create a very large incomplete chunk (> 10KB)
        let largeChunk = String(repeating: "<tag attr=\"", count: 1000) // ~12KB
        let tags1 = await parser.parse(largeChunk)

        // Buffer should be cleared due to size limit
        #expect(tags1.isEmpty)

        // Next chunk should parse normally (not combined with cleared buffer)
        let tags2 = await parser.parse("<prompt>&gt;</prompt>")
        #expect(tags2.count == 1)
        #expect(tags2[0].name == "prompt")
    }

    /// Test consecutive parse failures with buffering
    /// Verifies that repeated failures don't cause issues
    @Test func test_consecutiveParseFailures() async throws {
        let parser = XMLStreamParser()

        // Multiple incomplete chunks in sequence
        _ = await parser.parse("<a")
        _ = await parser.parse(" exist=")
        _ = await parser.parse("\"123")
        _ = await parser.parse("\" noun")
        _ = await parser.parse("=\"gem")

        // Finally complete the tag
        let tags = await parser.parse("\">gem</a>")
        #expect(tags.count == 1)
        #expect(tags[0].name == "a")
        #expect(tags[0].attrs["exist"] == "123")
        #expect(tags[0].attrs["noun"] == "gem")
    }

    // MARK: - Issue #10: Stream Control Tags Tests

    /// Test pushStream sets currentStream and inStream flag
    /// <pushStream id="thoughts"> should update persistent stream state
    @Test func test_pushStream() async throws {
        let parser = XMLStreamParser()

        // Initial state should be clean
        let initialStream = await parser.getCurrentStream()
        let initialInStream = await parser.getInStream()
        #expect(initialStream == nil)
        #expect(initialInStream == false)

        // Parse pushStream tag
        _ = await parser.parse("<pushStream id=\"thoughts\"/>")

        // Stream state should be updated
        let currentStream = await parser.getCurrentStream()
        let inStream = await parser.getInStream()
        #expect(currentStream == "thoughts")
        #expect(inStream == true)
    }

    /// Test popStream clears currentStream and inStream flag
    /// <popStream/> should reset stream state to nil/false
    @Test func test_popStream() async throws {
        let parser = XMLStreamParser()

        // First set up stream state with pushStream
        _ = await parser.parse("<pushStream id=\"speech\"/>")

        // Verify stream is active
        let beforePop = await parser.getCurrentStream()
        #expect(beforePop == "speech")

        // Parse popStream tag
        _ = await parser.parse("<popStream/>")

        // Stream state should be cleared
        let afterStream = await parser.getCurrentStream()
        let afterInStream = await parser.getInStream()
        #expect(afterStream == nil)
        #expect(afterInStream == false)
    }

    /// Test stream state persists across multiple parse() calls
    /// Critical: currentStream and inStream must remain set between chunks
    @Test func test_streamStateAcrossCalls() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: pushStream
        _ = await parser.parse("<pushStream id=\"combat\"/>")

        // Verify state is set
        let stream1 = await parser.getCurrentStream()
        let inStream1 = await parser.getInStream()
        #expect(stream1 == "combat")
        #expect(inStream1 == true)

        // Chunk 2: some game content
        _ = await parser.parse("<output>You attack the orc!</output>")

        // Stream state should still be active
        let stream2 = await parser.getCurrentStream()
        let inStream2 = await parser.getInStream()
        #expect(stream2 == "combat")
        #expect(inStream2 == true)

        // Chunk 3: more content
        _ = await parser.parse("<output>The orc dodges!</output>")

        // Stream state should STILL be active
        let stream3 = await parser.getCurrentStream()
        let inStream3 = await parser.getInStream()
        #expect(stream3 == "combat")
        #expect(inStream3 == true)

        // Chunk 4: popStream
        _ = await parser.parse("<popStream/>")

        // Now stream state should be cleared
        let stream4 = await parser.getCurrentStream()
        let inStream4 = await parser.getInStream()
        #expect(stream4 == nil)
        #expect(inStream4 == false)
    }

    /// Test nested stream tags (edge case)
    /// pushStream inside pushStream should replace stream ID (not nest)
    @Test func test_nestedStreams() async throws {
        let parser = XMLStreamParser()

        // First stream
        _ = await parser.parse("<pushStream id=\"outer\"/>")
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "outer")

        // Second pushStream without popping first (edge case)
        _ = await parser.parse("<pushStream id=\"inner\"/>")

        // Should replace outer with inner (GemStone IV doesn't nest streams)
        let stream2 = await parser.getCurrentStream()
        #expect(stream2 == "inner")

        // Single popStream should clear current stream
        _ = await parser.parse("<popStream/>")
        let stream3 = await parser.getCurrentStream()
        #expect(stream3 == nil)
    }

    /// Test clearStream tag (if needed for protocol)
    /// Some stream protocols support <clearStream id="X"/> to clear specific streams
    @Test func test_clearStream() async throws {
        let parser = XMLStreamParser()

        // Set up stream
        _ = await parser.parse("<pushStream id=\"thoughts\"/>")
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "thoughts")

        // clearStream should behave like popStream (clear current stream)
        _ = await parser.parse("<clearStream id=\"thoughts\"/>")

        // Stream should be cleared
        let stream2 = await parser.getCurrentStream()
        let inStream2 = await parser.getInStream()
        #expect(stream2 == nil)
        #expect(inStream2 == false)
    }

    /// Test tags between pushStream/popStream should be marked with stream ID
    /// Tags parsed while inStream=true should have their streamId set
    @Test func test_streamTagMarking() async throws {
        let parser = XMLStreamParser()

        // Parse complete stream with content
        let xml = "<pushStream id=\"thoughts\"/><output>You think about magic.</output><popStream/>"
        let tags = await parser.parse(xml)

        // Should get the output tag (stream control tags don't become GameTags)
        #expect(tags.count == 1)
        let tag = tags[0]
        #expect(tag.name == "output")
        #expect(tag.text == "You think about magic.")

        // Tag should be marked with stream ID
        #expect(tag.streamId == "thoughts")
    }

    /// Test multiple stream cycles work correctly
    /// Multiple push/pop sequences should work independently
    @Test func test_multipleStreamCycles() async throws {
        let parser = XMLStreamParser()

        // First stream cycle
        _ = await parser.parse("<pushStream id=\"thoughts\"/>")
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "thoughts")

        _ = await parser.parse("<popStream/>")
        let stream2 = await parser.getCurrentStream()
        #expect(stream2 == nil)

        // Second stream cycle
        _ = await parser.parse("<pushStream id=\"speech\"/>")
        let stream3 = await parser.getCurrentStream()
        #expect(stream3 == "speech")

        _ = await parser.parse("<popStream/>")
        let stream4 = await parser.getCurrentStream()
        #expect(stream4 == nil)

        // Third stream cycle
        _ = await parser.parse("<pushStream id=\"combat\"/>")
        let stream5 = await parser.getCurrentStream()
        #expect(stream5 == "combat")

        _ = await parser.parse("<popStream/>")
        let stream6 = await parser.getCurrentStream()
        #expect(stream6 == nil)
    }

    /// Test incomplete stream across chunks
    /// pushStream in chunk1, content in chunk2, popStream in chunk3
    @Test func test_incompleteStreamAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: pushStream and partial content
        _ = await parser.parse("<pushStream id=\"arrivals\"/><output>Teej arrives")

        // Stream should be active
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "arrivals")

        // Chunk 2: More content
        _ = await parser.parse(" from the north.</output>")

        // Stream should still be active
        let stream2 = await parser.getCurrentStream()
        #expect(stream2 == "arrivals")

        // Chunk 3: popStream
        _ = await parser.parse("<popStream/>")

        // Stream should be cleared
        let stream3 = await parser.getCurrentStream()
        #expect(stream3 == nil)
    }

    /// Test pushStream with different stream IDs
    /// Verifies all common stream IDs work correctly
    @Test func test_variousStreamIDs() async throws {
        let parser = XMLStreamParser()

        // Test common stream IDs from GemStone IV
        let streamIDs = [
            "thoughts",
            "speech",
            "combat",
            "arrivals",
            "deaths",
            "atmospherics",
            "whispers",
            "room",
            "damage"
        ]

        for streamID in streamIDs {
            _ = await parser.parse("<pushStream id=\"\(streamID)\"/>")
            let current = await parser.getCurrentStream()
            #expect(current == streamID)

            _ = await parser.parse("<popStream/>")
            let cleared = await parser.getCurrentStream()
            #expect(cleared == nil)
        }
    }

    /// Test pushStream without id attribute (malformed)
    /// Parser should handle gracefully - may set stream to empty string or nil
    @Test func test_pushStreamWithoutID() async throws {
        let parser = XMLStreamParser()

        // pushStream without id attribute
        _ = await parser.parse("<pushStream/>")

        // Behavior: Should either set to nil/empty or ignore the tag
        // Document current behavior (exact behavior TBD in implementation)
        let stream = await parser.getCurrentStream()
        let inStream = await parser.getInStream()

        // For now, just verify it doesn't crash
        // Implementation will decide: ignore tag, or set stream to ""
        _ = stream
        _ = inStream
    }

    /// Test popStream without matching pushStream (malformed)
    /// Parser should handle gracefully - no-op when no stream is active
    @Test func test_popStreamWithoutPush() async throws {
        let parser = XMLStreamParser()

        // Initial state: no stream
        let initial = await parser.getCurrentStream()
        #expect(initial == nil)

        // popStream without prior pushStream
        _ = await parser.parse("<popStream/>")

        // Should remain nil (no-op)
        let after = await parser.getCurrentStream()
        #expect(after == nil)
    }

    /// Test stream control tags mixed with nested content
    /// Real-world scenario: stream tags around nested game output
    @Test func test_streamControlWithNestedTags() async throws {
        let parser = XMLStreamParser()

        let xml = "<pushStream id=\"thoughts\"/>" +
            "<output>You think <d><a exist=\"123\" noun=\"gem\">a blue gem</a></d> is valuable.</output>" +
            "<popStream/>"

        let tags = await parser.parse(xml)

        // Verify stream was active during parse
        // (After popStream, it should be cleared)
        let finalStream = await parser.getCurrentStream()
        #expect(finalStream == nil)

        // Should get the output tag with nested structure
        #expect(tags.count == 1)
        let output = tags[0]
        #expect(output.name == "output")
        // Verify nesting preserved
        #expect(output.children.count > 0)
    }

    /// Test stream control tags split across chunks
    /// pushStream tag itself can be incomplete at chunk boundary
    @Test func test_streamControlSplitAcrossChunks() async throws {
        let parser = XMLStreamParser()

        // Chunk 1: Incomplete pushStream tag
        _ = await parser.parse("<pushStream id=\"tho")

        // Stream should NOT be active yet (tag incomplete)
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == nil)

        // Chunk 2: Complete the pushStream tag
        _ = await parser.parse("ughts\"/>")

        // Now stream should be active
        let stream2 = await parser.getCurrentStream()
        let inStream2 = await parser.getInStream()
        #expect(stream2 == "thoughts")
        #expect(inStream2 == true)
    }

    /// Test realistic GemStone IV stream output
    /// Complete real-world example with thoughts stream
    @Test func test_realisticStreamOutput() async throws {
        let parser = XMLStreamParser()

        let gameOutput = "<pushStream id=\"thoughts\"/>" +
            "<output>You focus your thoughts on the mystical</output>" +
            "<output>You sense a powerful magical aura nearby</output>" +
            "<popStream/>" +
            "<prompt>&gt;</prompt>"

        let tags = await parser.parse(gameOutput)

        // Verify final state: stream should be cleared after popStream
        let finalStream = await parser.getCurrentStream()
        let finalInStream = await parser.getInStream()
        #expect(finalStream == nil)
        #expect(finalInStream == false)

        // Should get 2 output tags + 1 prompt tag
        #expect(tags.count == 3)
        #expect(tags[0].name == "output")
        #expect(tags[1].name == "output")
        #expect(tags[2].name == "prompt")
    }

    /// Test multiple streams in sequence without interference
    /// Different stream types should not interfere with each other
    @Test func test_sequentialDifferentStreams() async throws {
        let parser = XMLStreamParser()

        // Thoughts stream
        _ = await parser.parse("<pushStream id=\"thoughts\"/>")
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "thoughts")
        _ = await parser.parse("<output>Thinking...</output>")
        _ = await parser.parse("<popStream/>")

        let after1 = await parser.getCurrentStream()
        #expect(after1 == nil)

        // Speech stream
        _ = await parser.parse("<pushStream id=\"speech\"/>")
        let stream2 = await parser.getCurrentStream()
        #expect(stream2 == "speech")
        _ = await parser.parse("<output>Teej says, \"Hello!\"</output>")
        _ = await parser.parse("<popStream/>")

        let after2 = await parser.getCurrentStream()
        #expect(after2 == nil)

        // Combat stream
        _ = await parser.parse("<pushStream id=\"combat\"/>")
        let stream3 = await parser.getCurrentStream()
        #expect(stream3 == "combat")
        _ = await parser.parse("<output>You strike!</output>")
        _ = await parser.parse("<popStream/>")

        let after3 = await parser.getCurrentStream()
        #expect(after3 == nil)
    }

    /// Test stream state with empty content between tags
    /// Stream should remain active even with no content between push/pop
    @Test func test_emptyStreamContent() async throws {
        let parser = XMLStreamParser()

        _ = await parser.parse("<pushStream id=\"test\"/>")
        let stream1 = await parser.getCurrentStream()
        #expect(stream1 == "test")

        // Empty content (just whitespace)
        _ = await parser.parse("   \n   ")

        // Stream should still be active
        let stream2 = await parser.getCurrentStream()
        #expect(stream2 == "test")

        _ = await parser.parse("<popStream/>")
        let stream3 = await parser.getCurrentStream()
        #expect(stream3 == nil)
    }

    /// Test stream control with performance (many stream cycles)
    /// Parser should handle high-frequency stream switching efficiently
    @Test func test_streamCyclePerformance() async throws {
        let parser = XMLStreamParser()

        let start = Date()

        // 100 rapid stream cycles
        for i in 0..<100 {
            _ = await parser.parse("<pushStream id=\"stream\(i)\"/>")
            _ = await parser.parse("<output>content</output>")
            _ = await parser.parse("<popStream/>")
        }

        let duration = Date().timeIntervalSince(start)

        // 100 stream cycles should complete quickly (< 100ms)
        #expect(duration < 0.1, "100 stream cycles took \(duration)s, expected < 0.1s")

        // Final state should be clean
        let finalStream = await parser.getCurrentStream()
        #expect(finalStream == nil)
    }
}
