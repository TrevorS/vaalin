// ABOUTME: Test suite for Message data model - TDD approach for game log rendering

import Foundation
import Testing
@testable import VaalinCore

// swiftlint:disable type_body_length
@Suite("Message Data Model Tests")
struct MessageTests {
    // MARK: - Identifiable Tests

    @Test("Message has unique ID for each instance")
    func test_messageIdentifiability() {
        let tags = [
            GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
        ]
        let message1 = Message(from: tags, streamID: "main")
        let message2 = Message(from: tags, streamID: "main")

        #expect(message1.id != message2.id, "Different instances should have different IDs")
    }

    @Test("Message ID can be explicitly set")
    func test_messageExplicitID() {
        let customID = UUID()
        let attributedText = AttributedString("test")
        let tags: [GameTag] = []

        let message = Message(
            id: customID,
            attributedText: attributedText,
            tags: tags
        )

        #expect(message.id == customID, "Should use provided ID")
    }

    // MARK: - Full Initialization Tests

    @Test("Message initialization with all parameters")
    func test_messageFullInitialization() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000)
        let attributedText = AttributedString("You see a blue gem.")
        let tag = GameTag(
            name: "a",
            text: "a blue gem",
            attrs: ["exist": "12345", "noun": "gem"],
            children: [],
            state: .closed
        )
        let tags = [tag]
        let streamID = "main"

        let message = Message(
            id: id,
            timestamp: timestamp,
            attributedText: attributedText,
            tags: tags,
            streamID: streamID
        )

        #expect(message.id == id)
        #expect(message.timestamp == timestamp)
        #expect(message.attributedText == attributedText)
        #expect(message.tags.count == 1)
        #expect(message.tags.first?.name == "a")
        #expect(message.streamID == streamID)
    }

    @Test("Message initialization with default timestamp")
    func test_messageDefaultTimestamp() {
        let before = Date()
        let message = Message(
            attributedText: AttributedString("test"),
            tags: []
        )
        let after = Date()

        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }

    @Test("Message initialization with default ID")
    func test_messageDefaultID() {
        let message = Message(
            attributedText: AttributedString("test"),
            tags: []
        )

        #expect(message.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
    }

    // MARK: - Convenience Initializer Tests (from GameTag array)

    @Test("Message from single GameTag with simple text")
    func test_messageFromSingleTag() {
        let tag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed
        )
        let message = Message(from: [tag], streamID: "main")

        #expect(String(message.attributedText.characters) == ">")
        #expect(message.tags.count == 1)
        #expect(message.tags.first?.name == "prompt")
        #expect(message.streamID == "main")
    }

    @Test("Message from multiple GameTags concatenates text")
    func test_messageFromMultipleTags() {
        let tag1 = GameTag(name: ":text", text: "You see ", attrs: [:], children: [], state: .closed)
        let tag2 = GameTag(name: "a", text: "a gem", attrs: ["noun": "gem"], children: [], state: .closed)
        let tag3 = GameTag(name: ":text", text: ".", attrs: [:], children: [], state: .closed)

        let message = Message(from: [tag1, tag2, tag3])

        #expect(String(message.attributedText.characters) == "You see a gem.")
        #expect(message.tags.count == 3)
    }

    @Test("Message from GameTag with nested children extracts all text")
    func test_messageFromNestedTags() {
        let innerTag = GameTag(
            name: "b",
            text: "bold",
            attrs: [:],
            children: [],
            state: .closed
        )
        let middleTag = GameTag(
            name: "a",
            text: " link ",
            attrs: ["noun": "item"],
            children: [innerTag],
            state: .closed
        )
        let outerTag = GameTag(
            name: "d",
            text: "prefix ",
            attrs: [:],
            children: [middleTag],
            state: .closed
        )

        let message = Message(from: [outerTag])

        // Expected: "prefix " + " link " + "bold" = "prefix  link bold"
        #expect(String(message.attributedText.characters) == "prefix  link bold")
    }

    @Test("Message from deeply nested structure extracts all text")
    func test_messageFromDeeplyNestedStructure() {
        let level3 = GameTag(name: ":text", text: "level3", attrs: [:], children: [], state: .closed)
        let level2 = GameTag(name: "b", text: "level2 ", attrs: [:], children: [level3], state: .closed)
        let level1 = GameTag(name: "d", text: "level1 ", attrs: [:], children: [level2], state: .closed)

        let message = Message(from: [level1])

        #expect(String(message.attributedText.characters) == "level1 level2 level3")
    }

    @Test("Message from GameTag with nil text")
    func test_messageFromTagWithNilText() {
        let tag = GameTag(
            name: "stream",
            text: nil,
            attrs: ["id": "thoughts"],
            children: [],
            state: .open
        )

        let message = Message(from: [tag])

        #expect(String(message.attributedText.characters) == "")
        #expect(message.tags.count == 1)
    }

    @Test("Message from empty tags array")
    func test_messageFromEmptyTagsArray() {
        let message = Message(from: [], streamID: nil)

        #expect(String(message.attributedText.characters) == "")
        #expect(message.tags.isEmpty)
        #expect(message.streamID == nil)
    }

    @Test("Message from tags with mixed nil and non-nil text")
    func test_messageFromMixedNilText() {
        let tag1 = GameTag(name: "stream", text: nil, attrs: [:], children: [], state: .open)
        let tag2 = GameTag(name: ":text", text: "actual text", attrs: [:], children: [], state: .closed)
        let tag3 = GameTag(name: "d", text: nil, attrs: [:], children: [], state: .closed)

        let message = Message(from: [tag1, tag2, tag3])

        #expect(String(message.attributedText.characters) == "actual text")
    }

    // MARK: - Stream ID Tests

    @Test("Message with stream ID")
    func test_messageWithStreamID() {
        let tags = [
            GameTag(name: ":text", text: "thought", attrs: [:], children: [], state: .closed)
        ]
        let message = Message(from: tags, streamID: "thoughts")

        #expect(message.streamID == "thoughts")
    }

    @Test("Message with nil stream ID")
    func test_messageWithNilStreamID() {
        let tags = [
            GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
        ]
        let message = Message(from: tags, streamID: nil)

        #expect(message.streamID == nil)
    }

    @Test("Message with default nil stream ID")
    func test_messageWithDefaultNilStreamID() {
        let tags = [
            GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
        ]
        let message = Message(from: tags)

        #expect(message.streamID == nil)
    }

    // MARK: - Timestamp Tests

    @Test("Message preserves provided timestamp")
    func test_messagePreservesTimestamp() {
        let customTimestamp = Date(timeIntervalSince1970: 500)
        let tags = [
            GameTag(name: ":text", text: "test", attrs: [:], children: [], state: .closed)
        ]

        let message = Message(from: tags, timestamp: customTimestamp)

        #expect(message.timestamp == customTimestamp)
    }

    @Test("Message uses current time as default timestamp")
    func test_messageDefaultTimestampFromTags() {
        let before = Date()
        let tags = [
            GameTag(name: ":text", text: "test", attrs: [:], children: [], state: .closed)
        ]
        let message = Message(from: tags)
        let after = Date()

        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }

    // MARK: - Tags Preservation Tests

    @Test("Message preserves original tags array")
    func test_messagePreservesOriginalTags() {
        let tag1 = GameTag(
            name: "a",
            text: "gem",
            attrs: ["exist": "12345"],
            children: [],
            state: .closed
        )
        let tag2 = GameTag(
            name: "b",
            text: "bold",
            attrs: [:],
            children: [],
            state: .closed
        )
        let tags = [tag1, tag2]

        let message = Message(from: tags)

        #expect(message.tags.count == 2)
        #expect(message.tags[0].name == "a")
        #expect(message.tags[0].attrs["exist"] == "12345")
        #expect(message.tags[1].name == "b")
        #expect(message.tags[1].text == "bold")
    }

    @Test("Message preserves nested tag structure in tags array")
    func test_messagePreservesNestedStructure() {
        let innerTag = GameTag(name: "b", text: "inner", attrs: [:], children: [], state: .closed)
        let outerTag = GameTag(
            name: "a",
            text: "outer",
            attrs: [:],
            children: [innerTag],
            state: .closed
        )

        let message = Message(from: [outerTag])

        #expect(message.tags.count == 1)
        #expect(message.tags[0].children.count == 1)
        #expect(message.tags[0].children[0].name == "b")
        #expect(message.tags[0].children[0].text == "inner")
    }

    // MARK: - Edge Cases

    @Test("Message from tag with empty string text")
    func test_messageFromTagWithEmptyText() {
        let tag = GameTag(name: ":text", text: "", attrs: [:], children: [], state: .closed)
        let message = Message(from: [tag])

        #expect(String(message.attributedText.characters) == "")
        #expect(message.tags.count == 1)
    }

    @Test("Message from tag with whitespace-only text")
    func test_messageFromTagWithWhitespaceText() {
        let tag = GameTag(name: ":text", text: "   ", attrs: [:], children: [], state: .closed)
        let message = Message(from: [tag])

        #expect(String(message.attributedText.characters) == "   ")
    }

    @Test("Message from tag with special characters")
    func test_messageFromTagWithSpecialCharacters() {
        let tag = GameTag(
            name: ":text",
            text: "Hello\nWorld\t!",
            attrs: [:],
            children: [],
            state: .closed
        )
        let message = Message(from: [tag])

        #expect(String(message.attributedText.characters) == "Hello\nWorld\t!")
    }

    @Test("Message from tag with Unicode characters")
    func test_messageFromTagWithUnicodeCharacters() {
        let tag = GameTag(
            name: ":text",
            text: "✨🎮 GemStone IV 🎮✨",
            attrs: [:],
            children: [],
            state: .closed
        )
        let message = Message(from: [tag])

        #expect(String(message.attributedText.characters) == "✨🎮 GemStone IV 🎮✨")
    }

    @Test("Message from complex nested structure with multiple children")
    func test_messageFromComplexNestedStructure() {
        let child1 = GameTag(name: ":text", text: "A", attrs: [:], children: [], state: .closed)
        let child2 = GameTag(name: ":text", text: "B", attrs: [:], children: [], state: .closed)
        let child3 = GameTag(name: ":text", text: "C", attrs: [:], children: [], state: .closed)

        let parent = GameTag(
            name: "d",
            text: "Parent ",
            attrs: [:],
            children: [child1, child2, child3],
            state: .closed
        )

        let message = Message(from: [parent])

        #expect(String(message.attributedText.characters) == "Parent ABC")
    }

    // MARK: - AttributedString Tests

    @Test("Message attributedText is AttributedString type")
    func test_messageAttributedTextType() {
        let tags = [
            GameTag(name: ":text", text: "test", attrs: [:], children: [], state: .closed)
        ]
        let message = Message(from: tags)

        // Verify AttributedString type by checking it can be used as AttributedString
        let _: AttributedString = message.attributedText
        #expect(String(message.attributedText.characters) == "test")
    }

    @Test("Message with custom AttributedString preserves styling")
    func test_messageWithCustomAttributedString() {
        let attributedText = AttributedString("Styled text")
        // Note: In real usage, this would have actual attributes like colors, fonts, etc.
        // For this test, we just verify the attributed string is preserved

        let tags: [GameTag] = []
        let message = Message(
            attributedText: attributedText,
            tags: tags
        )

        #expect(String(message.attributedText.characters) == "Styled text")
    }

    // MARK: - Real-World Scenario Tests

    @Test("Message from game prompt scenario")
    func test_gamePromptScenario() {
        let promptTag = GameTag(
            name: "prompt",
            text: ">",
            attrs: [:],
            children: [],
            state: .closed
        )

        let message = Message(from: [promptTag], streamID: "main")

        #expect(String(message.attributedText.characters) == ">")
        #expect(message.streamID == "main")
        #expect(message.tags.count == 1)
    }

    @Test("Message from item with link scenario")
    func test_itemWithLinkScenario() {
        let linkTag = GameTag(
            name: "a",
            text: "a blue gem",
            attrs: [
                "exist": "12345",
                "noun": "gem",
                "cmd": "look at gem"
            ],
            children: [],
            state: .closed
        )

        let message = Message(from: [linkTag], streamID: "main")

        #expect(String(message.attributedText.characters) == "a blue gem")
        #expect(message.tags[0].attrs["exist"] == "12345")
        #expect(message.tags[0].attrs["noun"] == "gem")
        #expect(message.tags[0].attrs["cmd"] == "look at gem")
    }

    @Test("Message from thought stream scenario")
    func test_thoughtStreamScenario() {
        let thoughtTag = GameTag(
            name: ":text",
            text: "You think to yourself, \"What a day!\"",
            attrs: [:],
            children: [],
            state: .closed
        )

        let message = Message(from: [thoughtTag], streamID: "thoughts")

        #expect(String(message.attributedText.characters) == "You think to yourself, \"What a day!\"")
        #expect(message.streamID == "thoughts")
    }

    @Test("Message from complex game output scenario")
    func test_complexGameOutputScenario() {
        let textTag1 = GameTag(name: ":text", text: "You see ", attrs: [:], children: [], state: .closed)
        let boldTag = GameTag(name: "b", text: "a blue gem", attrs: [:], children: [], state: .closed)
        let linkTag = GameTag(
            name: "a",
            text: nil,
            attrs: ["exist": "12345", "noun": "gem"],
            children: [boldTag],
            state: .closed
        )
        let textTag2 = GameTag(name: ":text", text: " on the ground.", attrs: [:], children: [], state: .closed)

        let message = Message(from: [textTag1, linkTag, textTag2], streamID: "main")

        #expect(String(message.attributedText.characters) == "You see a blue gem on the ground.")
        #expect(message.tags.count == 3)
    }
}
