// ABOUTME: DebugWindowManager manages the debug console state with a circular buffer for raw XML chunks

import Foundation
import SwiftUI
import VaalinCore

/// Manages the debug console window state and log entries.
///
/// This singleton manages:
/// - Circular buffer of log entries (max 5000)
/// - Window open/close state
/// - Export functionality
/// - Statistics tracking
///
/// Thread-safety: @MainActor ensures all UI updates happen on main thread
@MainActor
final class DebugWindowManager: ObservableObject {
    /// Shared singleton instance
    static let shared = DebugWindowManager()

    /// Whether the debug window is currently open
    @Published var isOpen: Bool = false

    /// Log entries in the circular buffer
    @Published var entries: [DebugLogEntry] = []

    /// Maximum number of entries to keep (circular buffer limit)
    private let maxEntries: Int = 5000

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Toggle the window open/close state
    func toggle() {
        isOpen.toggle()
    }

    /// Open the debug window
    func open() {
        isOpen = true
    }

    /// Close the debug window
    func close() {
        isOpen = false
    }

    /// Add a new log entry to the buffer
    ///
    /// Only adds entries when the window is open to avoid unnecessary memory usage.
    /// Implements circular buffer: oldest entries are removed when buffer is full.
    ///
    /// XML formatting happens asynchronously on a background thread to avoid blocking
    /// the UI. Entries are added to the buffer once formatting completes.
    ///
    /// - Parameters:
    ///   - data: Raw XML string from Lich 5
    ///   - session: Session/character name
    func addEntry(_ data: String, session: String) {
        // Performance optimization: Only add entries if window is open
        guard isOpen else { return }

        // Format XML asynchronously on background thread
        Task.detached {
            let formattedData = await XMLPrettyPrinter.format(data)

            // Return to MainActor to update entries array
            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // Double-check window is still open
                guard self.isOpen else { return }

                let entry = DebugLogEntry(data: data, formattedData: formattedData, session: session)
                self.entries.append(entry)

                // Circular buffer: Remove oldest entry if over limit
                if self.entries.count > self.maxEntries {
                    self.entries.removeFirst()
                }
            }
        }
    }

    /// Clear all log entries
    func clear() {
        entries.removeAll()
    }

    /// Export log entries to JSON format
    ///
    /// Format includes metadata (session, timestamps, entry count) and all log entries
    /// with their timestamps, byte counts, and raw data.
    ///
    /// - Returns: JSON string representation of all entries with metadata
    func exportToJSON() -> String {
        guard !entries.isEmpty else {
            return "{\"metadata\": {\"entry_count\": 0}, \"chunks\": []}"
        }

        // Build metadata
        let metadata: [String: Any] = [
            "session": entries.first?.session ?? "Unknown",
            "start_time": entries.first?.timestamp.ISO8601Format() ?? "",
            "end_time": entries.last?.timestamp.ISO8601Format() ?? "",
            "entry_count": entries.count
        ]

        // Build chunks array
        let chunks = entries.map { entry -> [String: Any] in
            [
                "timestamp": entry.timestamp.ISO8601Format(),
                "bytes": entry.byteCount,
                "data": entry.data
            ]
        }

        // Combine into export object
        let export: [String: Any] = [
            "metadata": metadata,
            "chunks": chunks
        ]

        // Serialize to JSON
        if let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        // Fallback on serialization failure
        return "{\"error\": \"Failed to serialize\"}"
    }

    /// Get current statistics about the buffer
    ///
    /// - Returns: Tuple of (current entry count, max entry count)
    func getStatistics() -> (currentCount: Int, maxCount: Int) {
        return (entries.count, maxEntries)
    }

    /// Calculate bytes per second over recent entries
    ///
    /// Looks at the last 100 entries (or all entries if fewer) to calculate
    /// the average data rate.
    ///
    /// - Returns: Bytes per second (rolling average)
    func getBytesPerSecond() -> Double {
        guard entries.count >= 2 else { return 0 }

        // Use last 100 entries or all if fewer
        let recentCount = min(100, entries.count)
        let recentEntries = entries.suffix(recentCount)

        guard let first = recentEntries.first,
              let last = recentEntries.last else {
            return 0
        }

        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        guard duration > 0 else { return 0 }

        let totalBytes = recentEntries.reduce(0) { $0 + $1.byteCount }
        return Double(totalBytes) / duration
    }

    /// Calculate chunks per second over recent entries
    ///
    /// Looks at the last 100 entries (or all entries if fewer) to calculate
    /// the average chunk rate.
    ///
    /// - Returns: Chunks per second (rolling average)
    func getChunksPerSecond() -> Double {
        guard entries.count >= 2 else { return 0 }

        // Use last 100 entries or all if fewer
        let recentCount = min(100, entries.count)
        let recentEntries = entries.suffix(recentCount)

        guard let first = recentEntries.first,
              let last = recentEntries.last else {
            return 0
        }

        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        guard duration > 0 else { return 0 }

        return Double(recentCount) / duration
    }
}

// MARK: - DebugDataIntercepting Conformance

extension DebugWindowManager: DebugDataIntercepting {
    /// Intercept raw data from LichConnection
    ///
    /// Called immediately when data is received from Lich 5, before parsing.
    /// Adds the data to the circular buffer for display in the debug console.
    ///
    /// - Parameters:
    ///   - data: Raw XML string
    ///   - session: Session/character name
    nonisolated func interceptData(_ data: String, session: String) async {
        await MainActor.run {
            self.addEntry(data, session: session)
        }
    }
}
