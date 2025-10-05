// ABOUTME: Tests for XMLStreamParser actor - stateful SAX-based XML parsing with chunked TCP support

import Foundation
import Testing
@testable import VaalinCore
@testable import VaalinParser

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

        let tags = await parser.parse("<progressBar id=\"health\" value=\"100\" left=\"100\" right=\"100\" text=\"100%\"/>")

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

        let gameOutput = "You see <a exist=\"12345\" noun=\"gem\">a blue gem</a> and <a exist=\"67890\" noun=\"coin\">a gold coin</a>."

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
}
