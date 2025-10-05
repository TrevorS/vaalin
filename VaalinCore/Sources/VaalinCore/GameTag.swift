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
public struct GameTag: Identifiable, Equatable, Sendable {
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

    /// Stream ID if tag was parsed inside a stream context.
    ///
    /// Set to the active stream ID (e.g., "thoughts", "speech", "combat") when parsed
    /// between `<pushStream id="X">` and `<popStream>` tags. `nil` for tags outside streams.
    ///
    /// Used by EventBus to route stream content to appropriate subscribers, enabling
    /// stream filtering in the UI (thoughts panel, speech panel, etc.).
    ///
    /// ## Example
    /// ```swift
    /// // Tag parsed inside <pushStream id="thoughts">...</pushStream>
    /// let tag = GameTag(name: "output", text: "You think...", streamId: "thoughts")
    ///
    /// // Tag parsed outside any stream context
    /// let tag = GameTag(name: "prompt", text: ">", streamId: nil)
    /// ```
    public var streamId: String?

    /// Creates a new GameTag with the specified properties.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Tag name (e.g., "a", "stream", ":text")
    ///   - text: Optional text content
    ///   - attrs: Attribute dictionary (defaults to empty)
    ///   - children: Nested child tags (defaults to empty)
    ///   - state: Tag parsing state
    ///   - streamId: Stream context ID (nil if outside stream)
    public init(
        id: UUID = UUID(),
        name: String,
        text: String? = nil,
        attrs: [String: String] = [:],
        children: [GameTag] = [],
        state: TagState,
        streamId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.attrs = attrs
        self.children = children
        self.state = state
        self.streamId = streamId
    }

    // MARK: - Equatable

    /// Custom equality implementation that compares content, not identity.
    /// ID is excluded from comparison following standard Identifiable pattern.
    public static func == (lhs: GameTag, rhs: GameTag) -> Bool {
        lhs.name == rhs.name &&
        lhs.text == rhs.text &&
        lhs.attrs == rhs.attrs &&
        lhs.children == rhs.children &&
        lhs.state == rhs.state &&
        lhs.streamId == rhs.streamId
    }
}

/// Tracks whether an XML tag is complete or still being parsed.
///
/// Used by XMLStreamParser to handle incomplete XML chunks received
/// over TCP connection. Tags transition from `.open` to `.closed` when
/// the closing tag is encountered.
public enum TagState: Equatable, Sendable {
    /// Tag has been opened but closing tag not yet received.
    /// Example: After parsing `<stream id="thoughts">` but before `</stream>`
    case open

    /// Tag is complete with both opening and closing tags received.
    /// Example: After parsing `<prompt>></prompt>` or self-closing `<a/>`
    case closed
}
