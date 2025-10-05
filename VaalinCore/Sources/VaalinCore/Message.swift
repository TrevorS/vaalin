// ABOUTME: Message represents a rendered game log entry with attributed text

import Foundation

/// Represents a rendered game log entry with attributed text and metadata.
///
/// Message is the primary data structure for displaying game output in the log view.
/// Each message represents one or more GameTags that have been rendered into
/// styled AttributedString for display with ANSI colors, item highlighting, etc.
///
/// ## Example Usage
/// ```swift
/// // Create a message from parsed tags
/// let tags = [
///     GameTag(name: "prompt", text: ">", attrs: [:], children: [], state: .closed)
/// ]
/// let message = Message(from: tags, streamID: "main")
///
/// // Display in SwiftUI
/// Text(message.attributedText)
/// ```
///
/// ## Thread Safety
/// Message is a value type (struct) and is safe to pass across actor boundaries.
///
/// ## Performance
/// Designed for efficient virtualized scrolling in game log view (60fps target).
/// AttributedString creation is typically done by TagRenderer before Message creation.
public struct Message: Identifiable {
    /// Unique identifier for SwiftUI list rendering and tracking.
    /// Generated on initialization and remains stable.
    public let id: UUID

    /// Timestamp when this message was created (received from server).
    /// Used for log timestamps and message ordering.
    public let timestamp: Date

    /// Rendered attributed text ready for display.
    /// Contains styled text with ANSI colors, item highlights, bold/italic, etc.
    public let attributedText: AttributedString

    /// Original GameTag array that this message was rendered from.
    /// Preserved for potential re-rendering or inspection.
    public let tags: [GameTag]

    /// Stream ID this message belongs to (e.g., "thoughts", "speech", "main").
    /// `nil` for messages not associated with a specific stream.
    public let streamID: String?

    /// Creates a new Message with the specified properties.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - timestamp: Message timestamp (defaults to current time)
    ///   - attributedText: Styled text for display
    ///   - tags: Original GameTag array
    ///   - streamID: Optional stream identifier
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        attributedText: AttributedString,
        tags: [GameTag],
        streamID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.attributedText = attributedText
        self.tags = tags
        self.streamID = streamID
    }

    /// Creates a new Message from GameTag array with basic text concatenation.
    ///
    /// This is a convenience initializer for simple cases. For full rendering
    /// with ANSI colors and item highlighting, use TagRenderer before Message creation.
    ///
    /// - Parameters:
    ///   - tags: GameTag array to convert to message
    ///   - streamID: Optional stream identifier
    ///   - timestamp: Message timestamp (defaults to current time)
    /// - Returns: New Message with concatenated plain text
    public init(
        from tags: [GameTag],
        streamID: String? = nil,
        timestamp: Date = Date()
    ) {
        // Concatenate all text from tags and children recursively
        func extractText(from tag: GameTag) -> String {
            var result = tag.text ?? ""
            for child in tag.children {
                result += extractText(from: child)
            }
            return result
        }

        let plainText = tags.map { extractText(from: $0) }.joined()
        let attributedString = AttributedString(plainText)

        self.init(
            timestamp: timestamp,
            attributedText: attributedString,
            tags: tags,
            streamID: streamID
        )
    }
}
