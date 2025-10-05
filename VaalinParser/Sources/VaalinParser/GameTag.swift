// ABOUTME: GameTag represents a parsed XML element from GemStone IV protocol

import Foundation

/// Represents a parsed XML element from the GemStone IV game server.
///
/// GameTag supports nested structures, attributes, and state tracking for
/// incomplete XML chunks received over TCP connection. Each tag represents
/// an element like `<a>`, `<stream>`, `<prompt>`, or special `:text` nodes.
///
/// ## Example Usage
/// ```swift
/// // Create a simple prompt tag
/// let prompt = GameTag(
///     name: "prompt",
///     text: ">",
///     attrs: [:],
///     children: [],
///     state: .closed
/// )
///
/// // Create a nested structure (bold text inside a link)
/// let boldTag = GameTag(name: "b", text: "gem", attrs: [:], children: [], state: .closed)
/// let linkTag = GameTag(
///     name: "a",
///     text: nil,
///     attrs: ["exist": "12345", "noun": "gem"],
///     children: [boldTag],
///     state: .closed
/// )
/// ```
///
/// ## Thread Safety
/// GameTag is a value type (struct) and is safe to pass across actor boundaries.
///
/// ## Performance
/// Designed for high-throughput parsing: > 10,000 lines/minute.
/// Uses value semantics to avoid reference counting overhead.
///
/// ## Equality Semantics
/// Two GameTags are considered equal if their content (name, text, attrs, children, state)
/// is identical, even if their IDs differ. This follows the standard Identifiable pattern
/// where ID is used for identity tracking in SwiftUI, not logical equality.
public struct GameTag: Identifiable, Equatable {
    /// Unique identifier for SwiftUI list rendering and tracking.
    /// Generated on initialization and remains stable across property mutations.
    public let id: UUID

    /// Tag name: "a", "b", "d", "stream", "prompt", ":text", etc.
    /// Represents the XML element name or special node type.
    public let name: String

    /// Optional text content within the tag.
    /// `nil` for container tags like `<stream>` or `<d>`.
    /// Contains parsed text for text nodes and inline tags.
    public var text: String?

    /// Attributes from XML element as key-value pairs.
    /// Examples: `["exist": "12345", "noun": "gem", "cmd": "look at gem"]`
    /// Empty dictionary for tags without attributes.
    public var attrs: [String: String]

    /// Nested child tags for hierarchical XML structures.
    /// Empty array for leaf nodes. Supports arbitrary nesting depth.
    public var children: [GameTag]

    /// Tracks whether the XML tag is complete or still being parsed.
    /// Used by XMLStreamParser to handle chunked TCP data.
    public var state: TagState

    /// Creates a new GameTag with the specified properties.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Tag name (e.g., "a", "stream", ":text")
    ///   - text: Optional text content
    ///   - attrs: Attribute dictionary (defaults to empty)
    ///   - children: Nested child tags (defaults to empty)
    ///   - state: Tag parsing state
    public init(
        id: UUID = UUID(),
        name: String,
        text: String? = nil,
        attrs: [String: String] = [:],
        children: [GameTag] = [],
        state: TagState
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.attrs = attrs
        self.children = children
        self.state = state
    }

    // MARK: - Equatable

    /// Custom equality implementation that compares content, not identity.
    /// ID is excluded from comparison following standard Identifiable pattern.
    public static func == (lhs: GameTag, rhs: GameTag) -> Bool {
        lhs.name == rhs.name &&
        lhs.text == rhs.text &&
        lhs.attrs == rhs.attrs &&
        lhs.children == rhs.children &&
        lhs.state == rhs.state
    }
}

/// Tracks whether an XML tag is complete or still being parsed.
///
/// Used by XMLStreamParser to handle incomplete XML chunks received
/// over TCP connection. Tags transition from `.open` to `.closed` when
/// the closing tag is encountered.
public enum TagState: Equatable {
    /// Tag has been opened but closing tag not yet received.
    /// Example: After parsing `<stream id="thoughts">` but before `</stream>`
    case open

    /// Tag is complete with both opening and closing tags received.
    /// Example: After parsing `<prompt>></prompt>` or self-closing `<a/>`
    case closed
}
