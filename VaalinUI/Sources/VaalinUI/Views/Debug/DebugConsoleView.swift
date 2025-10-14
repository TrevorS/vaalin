// ABOUTME: DebugConsoleView displays raw XML chunks from Lich 5 in real-time for debugging

import SwiftUI

/// Debug console window for viewing raw XML stream from Lich 5.
///
/// Displays:
/// - Timestamp, session name, and raw XML per entry
/// - Toolbar with filter, clear, copy, export buttons
/// - Status bar with entry count and data rate
/// - Syntax-highlighted XML (in later phase)
///
/// Performance targets:
/// - 60fps scrolling with 5000 entries
/// - < 10ms filtering
/// - < 5ms per-row highlighting
public struct DebugConsoleView: View {
    @StateObject private var manager = DebugWindowManager.shared
    @State private var filterText: String = ""
    @State private var filterError: String?
    @State private var autoScroll: Bool = true
    @State private var prettyPrint: Bool = false  // OFF by default
    @FocusState private var isFilterFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Debug Console - Raw XML Stream")
                .font(.headline)
                .padding()

            Divider()

            // Toolbar
            DebugToolbarView(
                filterText: $filterText,
                filterError: $filterError,
                filterFocusState: $isFilterFocused,
                onClear: {
                    manager.clear()
                },
                onCopy: {
                    copyToClipboard()
                },
                onExport: {
                    exportToFile()
                }
            )

            Divider()

            // List-based log display with virtualized scrolling
            ScrollViewReader { proxy in
                List(filteredEntries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        // Timestamp
                        Text(entry.timestamp, style: .time)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)

                        // Session name
                        Text("[\(entry.session)]")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.teal)
                            .frame(width: 80, alignment: .leading)

                        // XML data with optional pretty printing and syntax highlighting
                        Text(XMLSyntaxHighlighter.highlight(prettyPrint ? entry.formattedData : entry.data))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .id(entry.id)
                }
                .listStyle(.plain)
                .onChange(of: manager.entries.count) { _, _ in
                    if autoScroll, let lastEntry = filteredEntries.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Status bar
            HStack {
                Text("\(filteredEntries.count) / \(manager.entries.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 12)

                // Data rate statistics
                Text(String(format: "%.1f B/s", manager.getBytesPerSecond()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("Bytes per second (rolling average)")

                Divider()
                    .frame(height: 12)

                Text(String(format: "%.1f chunks/s", manager.getChunksPerSecond()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help("Chunks per second (rolling average)")

                Spacer()

                // Pretty print toggle
                Button {
                    prettyPrint.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: prettyPrint ? "text.alignleft" : "text.alignleft")
                            .foregroundColor(prettyPrint ? .blue : .secondary)
                        Text("Pretty")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle XML pretty printing (formatted in background, no UI blocking)")

                Divider()
                    .frame(height: 12)

                // Auto-scroll toggle
                Button {
                    autoScroll.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundColor(autoScroll ? .blue : .secondary)
                        Text("Auto-scroll")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .help("Toggle auto-scroll to bottom")
            }
            .padding(8)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            manager.open()
        }
        .onDisappear {
            manager.close()
        }
        .background {
            // Hidden buttons for keyboard shortcuts
            Button("") {
                isFilterFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()

            Button("") {
                manager.clear()
            }
            .keyboardShortcut("k", modifiers: .command)
            .hidden()
        }
    }

    // MARK: - Computed Properties

    /// Filtered entries based on current filter text
    private var filteredEntries: [DebugLogEntry] {
        guard !filterText.isEmpty else {
            return manager.entries
        }

        // Try to compile regex
        guard let regex = try? NSRegularExpression(pattern: filterText, options: [.caseInsensitive]) else {
            // Invalid regex - show error and return all entries
            DispatchQueue.main.async {
                filterError = "Invalid regex"
            }
            return manager.entries
        }

        // Clear error if regex is valid
        DispatchQueue.main.async {
            filterError = nil
        }

        // Filter entries that match regex
        return manager.entries.filter { entry in
            let range = NSRange(entry.data.startIndex..., in: entry.data)
            return regex.firstMatch(in: entry.data, options: [], range: range) != nil
        }
    }

    // MARK: - Actions

    /// Copy filtered entries to clipboard
    private func copyToClipboard() {
        let text = filteredEntries.map { entry in
            "\(entry.timestamp.ISO8601Format()) [\(entry.session)] \(entry.data)"
        }.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Export entries to JSON file via save panel
    private func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "vaalin-debug-\(Date().ISO8601Format()).json"
        panel.title = "Export Debug Log"
        panel.message = "Choose where to save the debug log"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let json = manager.exportToJSON()
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

#Preview("Empty State") {
    DebugConsoleView()
}

#Preview("With Entries") {
    let manager = DebugWindowManager.shared
    // Add some sample entries for preview
    Task { @MainActor in
        manager.open()
        manager.addEntry("<pushStream id=\"thoughts\"/>", session: "Teej")
        manager.addEntry("You think, \"This is interesting.\"", session: "Teej")
        manager.addEntry("<popStream/>", session: "Teej")
        manager.addEntry("<prompt>&gt;</prompt>", session: "Teej")
    }
    return DebugConsoleView()
}
