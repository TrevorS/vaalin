// ABOUTME: DebugToolbarView provides filter input and action buttons for the debug console

import SwiftUI

/// Toolbar for the debug console with filter and action buttons.
///
/// Features:
/// - Filter text field with regex support
/// - Clear button to remove all entries
/// - Copy button to copy filtered entries to clipboard
/// - Export button to save entries to JSON file
/// - Visual feedback for invalid regex patterns
struct DebugToolbarView: View {
    @Binding var filterText: String
    @Binding var filterError: String?
    var filterFocusState: FocusState<Bool>.Binding

    let onClear: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Filter text field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Filter (regex supported)", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 200)
                    .focused(filterFocusState)

                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                        filterError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(filterError != nil ? Color.red : Color.clear, lineWidth: 1)
            )

            // Error indicator
            if let error = filterError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Clear button
                Button {
                    onClear()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Clear all entries (⌘K)")

                // Copy button
                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy filtered entries to clipboard")

                // Export button
                Button {
                    onExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Export entries to JSON file")
            }
        }
        .padding(8)
    }
}

#Preview("Empty Filter") {
    @Previewable @FocusState var focused: Bool
    DebugToolbarView(
        filterText: .constant(""),
        filterError: .constant(nil),
        filterFocusState: $focused,
        onClear: {},
        onCopy: {},
        onExport: {}
    )
}

#Preview("With Filter Text") {
    @Previewable @FocusState var focused: Bool
    DebugToolbarView(
        filterText: .constant("pushStream.*thoughts"),
        filterError: .constant(nil),
        filterFocusState: $focused,
        onClear: {},
        onCopy: {},
        onExport: {}
    )
}

#Preview("With Error") {
    @Previewable @FocusState var focused: Bool
    DebugToolbarView(
        filterText: .constant("[invalid(regex"),
        filterError: .constant("Invalid regex"),
        filterFocusState: $focused,
        onClear: {},
        onCopy: {},
        onExport: {}
    )
}
