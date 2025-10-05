// ABOUTME: Test suite for GameTag data model - TDD approach for parser foundation

import Testing
import Foundation
@testable import VaalinParser

@Suite("GameTag Data Model Tests")
struct GameTagTests {

    // MARK: - Identifiable Tests

    @Test("GameTag has unique ID for each instance")
    func test_gameTagIdentifiability() {
        let tag1 = GameTag(name: "a", text: "a gem", attrs: [:], children: [], state: .open)
        let tag2 = GameTag(name: "a", text: "a gem", attrs: [:], children: [], state: .open)

        #expect(tag1.id != tag2.id, "Different instances should have different IDs")
    }

    @Test("GameTag ID remains stable across property changes")
    func test_gameTagIDStability() {
        var tag = GameTag(name: "a", text: nil, attrs: [:], children: [], state: .open)
        let originalID = tag.id

        tag.text = "updated text"
        tag.state = .closed

        #expect(tag.id == originalID, "ID should remain stable when mutable properties change")
    }

    // MARK: - Equatable Tests

    @Test("GameTag equality compares all fields")
    func test_gameTagEquality() {
        let tag1 = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
        let tag2 = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)

        #expect(tag1 == tag2, "Tags with identical content should be equal")
    }

    @Test("GameTag inequality when names differ")
    func test_gameTagInequalityName() {
        let tag1 = GameTag(name: "a", text: "gem", attrs: [:], children: [], state: .open)
        let tag2 = GameTag(name: "b", text: "gem", attrs: [:], children: [], state: .open)

        #expect(tag1 != tag2, "Tags with different names should not be equal")
    }

    @Test("GameTag inequality when text differs")
    func test_gameTagInequalityText() {
        let tag1 = GameTag(name: "a", text: "blue gem", attrs: [:], children: [], state: .closed)
        let tag2 = GameTag(name: "a", text: "red gem", attrs: [:], children: [], state: .closed)

        #expect(tag1 != tag2, "Tags with different text should not be equal")
    }

    @Test("GameTag inequality when attributes differ")
    func test_gameTagInequalityAttrs() {
        let tag1 = GameTag(name: "a", text: "gem", attrs: ["exist": "12345"], children: [], state: .closed)
        let tag2 = GameTag(name: "a", text: "gem", attrs: ["exist": "67890"], children: [], state: .closed)

        #expect(tag1 != tag2, "Tags with different attributes should not be equal")
    }

    @Test("GameTag inequality when state differs")
    func test_gameTagInequalityState() {
        let tag1 = GameTag(name: "stream", text: nil, attrs: ["id": "thoughts"], children: [], state: .open)
        let tag2 = GameTag(name: "stream", text: nil, attrs: ["id": "thoughts"], children: [], state: .closed)

        #expect(tag1 != tag2, "Tags with different states should not be equal")
    }

    // MARK: - Nested Tag Structure Tests

    @Test("GameTag supports nested children array")
    func test_nestedTagStructure() {
        let innerTag = GameTag(name: "b", text: "bold text", attrs: [:], children: [], state: .closed)
        let outerTag = GameTag(name: "d", text: nil, attrs: [:], children: [innerTag], state: .closed)

        #expect(outerTag.children.count == 1, "Should contain one child")
        #expect(outerTag.children.first?.name == "b", "Child should be bold tag")
        #expect(outerTag.children.first?.text == "bold text", "Child text should be preserved")
    }

    @Test("GameTag supports deeply nested structures")
    func test_deeplyNestedStructure() {
        let level3 = GameTag(name: "a", text: "gem", attrs: ["noun": "gem"], children: [], state: .closed)
        let level2 = GameTag(name: "b", text: nil, attrs: [:], children: [level3], state: .closed)
        let level1 = GameTag(name: "d", text: nil, attrs: [:], children: [level2], state: .closed)

        #expect(level1.children.count == 1)
        #expect(level1.children.first?.children.count == 1)
        #expect(level1.children.first?.children.first?.text == "gem")
    }

    @Test("GameTag with no children has empty array")
    func test_gameTagWithNoChildren() {
        let tag = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)

        #expect(tag.children.isEmpty, "Tag without children should have empty array")
    }

    // MARK: - Attribute Storage Tests

    @Test("GameTag stores attributes as dictionary")
    func test_attributeStorage() {
        let attrs = ["exist": "12345", "noun": "gem", "cmd": "look at gem"]
        let tag = GameTag(name: "a", text: "a blue gem", attrs: attrs, children: [], state: .closed)

        #expect(tag.attrs["exist"] == "12345")
        #expect(tag.attrs["noun"] == "gem")
        #expect(tag.attrs["cmd"] == "look at gem")
    }

    @Test("GameTag with empty attributes dictionary")
    func test_gameTagWithEmptyAttributes() {
        let tag = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)

        #expect(tag.attrs.isEmpty, "Tag with no attributes should have empty dictionary")
    }

    @Test("GameTag attributes can be mutated")
    func test_attributeMutation() {
        var tag = GameTag(name: "a", text: "gem", attrs: [:], children: [], state: .open)

        tag.attrs["exist"] = "12345"
        tag.attrs["noun"] = "gem"

        #expect(tag.attrs.count == 2)
        #expect(tag.attrs["exist"] == "12345")
    }

    // MARK: - TagState Tests

    @Test("TagState enum supports open and closed states")
    func test_tagStateBehavior() {
        let openTag = GameTag(name: "stream", text: nil, attrs: ["id": "thoughts"], children: [], state: .open)
        let closedTag = GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)

        #expect(openTag.state == .open)
        #expect(closedTag.state == .closed)
    }

    @Test("TagState can be mutated")
    func test_tagStateMutation() {
        var tag = GameTag(name: "stream", text: nil, attrs: [:], children: [], state: .open)

        #expect(tag.state == .open)

        tag.state = .closed

        #expect(tag.state == .closed)
    }

    // MARK: - Optional Text Tests

    @Test("GameTag with no text has nil text property")
    func test_gameTagWithNoText() {
        let tag = GameTag(name: "stream", text: nil, attrs: ["id": "main"], children: [], state: .open)

        #expect(tag.text == nil, "Tag without text should have nil text property")
    }

    @Test("GameTag text can be mutated")
    func test_textMutation() {
        var tag = GameTag(name: "a", text: nil, attrs: [:], children: [], state: .open)

        #expect(tag.text == nil)

        tag.text = "a blue gem"

        #expect(tag.text == "a blue gem")
    }
}
