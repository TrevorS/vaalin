// ABOUTME: DebugLogEntry model stores a single raw XML chunk received from Lich 5 for debugging

import Foundation

/// A single log entry in the debug console, representing one chunk of raw XML data
/// received from Lich 5.
///
/// Each entry captures:
/// - The raw XML data string
/// - Pretty-printed formatted XML (cached for performance)
/// - Session name (character name)
/// - Timestamp of receipt
/// - Computed byte count for statistics
struct DebugLogEntry: Identifiable, Sendable {
    /// Unique identifier for SwiftUI List identification
    let id: UUID

    /// Timestamp when this chunk was received
    let timestamp: Date

    /// Session/character name that received this data
    let session: String

    /// Raw XML data as received from Lich 5
    let data: String

    /// Pretty-printed formatted XML (cached from async formatting)
    /// This is computed in the background when entries are added to avoid UI thread blocking
    let formattedData: String

    /// Byte count of the data (UTF-8 encoding)
    let byteCount: Int

    /// Initialize a new debug log entry
    /// - Parameters:
    ///   - data: Raw XML string from Lich 5
    ///   - formattedData: Pretty-printed formatted XML
    ///   - session: Session/character name
    init(data: String, formattedData: String, session: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.session = session
        self.data = data
        self.formattedData = formattedData
        self.byteCount = data.utf8.count
    }
}
