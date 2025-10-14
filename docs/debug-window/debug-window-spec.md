# Debug Window Specification - Vaalin XML Stream Viewer

**Version:** 1.0
**Date:** 2025-10-12
**Status:** Ready for Implementation
**Target:** macOS 26+ (Tahoe) with SwiftUI

---

## Executive Summary

This document specifies a **debug window** for Vaalin that displays raw XML chunks received from Lich 5 in real-time. The window provides developers with visibility into the XML protocol for debugging parser issues, understanding game behavior, and validating Lich integration.

**Key Features:**
- Real-time XML stream display with syntax highlighting
- Regex filtering and search capabilities
- Circular buffer (5000 entry limit) to prevent memory growth
- Command integration (`:debug` or `:raw` to toggle)
- Export to file for offline analysis
- Zero overhead in Release builds (`#if DEBUG`)

**Technical Approach:**
- SwiftUI `Window` scene (single instance, auxiliary window)
- `List` + `ForEach` for virtualized scrolling (10x faster than LazyVStack)
- `AttributedString` for per-row XML syntax highlighting
- Actor-based state management (DebugWindowManager)
- Automatic data interception before parsing

---

## Table of Contents

1. [Requirements](#requirements)
2. [Architecture](#architecture)
3. [UI/UX Design](#uiux-design)
4. [Technical Specification](#technical-specification)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Performance Requirements](#performance-requirements)
8. [Future Enhancements](#future-enhancements)

---

## Requirements

### Functional Requirements

#### FR1: Real-Time XML Display
- **Description:** Display raw XML chunks as received from Lich 5
- **Priority:** P0 (Critical)
- **Acceptance Criteria:**
  - XML appears within 100ms of receipt
  - Chunks displayed in order received
  - No data loss (all chunks captured)
  - Timestamps accurate to milliseconds

#### FR2: Syntax Highlighting
- **Description:** Colorize XML tags, attributes, and values
- **Priority:** P1 (High)
- **Acceptance Criteria:**
  - Tags highlighted in blue (#89b4fa)
  - Attributes highlighted in teal (#94e2d5)
  - Values highlighted in peach (#fab387)
  - Comments highlighted in green (#a6e3a1)
  - Colors match Catppuccin Mocha theme

#### FR3: Regex Filtering
- **Description:** Filter log entries by regex pattern
- **Priority:** P1 (High)
- **Acceptance Criteria:**
  - Case-insensitive by default
  - Live filtering (updates as you type)
  - Invalid regex shows error (no crash)
  - Clear filter button

#### FR4: Circular Buffer
- **Description:** Limit buffer to prevent unbounded memory growth
- **Priority:** P0 (Critical)
- **Acceptance Criteria:**
  - Max 5000 entries (configurable)
  - Oldest entries removed automatically (FIFO)
  - Fixed memory footprint (< 10MB)
  - No performance degradation as buffer fills

#### FR5: Command Integration
- **Description:** Toggle window via game commands
- **Priority:** P1 (High)
- **Acceptance Criteria:**
  - `:debug` or `:raw` command toggles window
  - `:debug clear` clears buffer
  - Confirmation message in game log
  - Window state persists during session

#### FR6: Copy and Export
- **Description:** Copy filtered logs to clipboard or export to file
- **Priority:** P2 (Medium)
- **Acceptance Criteria:**
  - Copy button copies filtered entries
  - Export button saves to .xml or .txt file
  - Export includes timestamps and session name
  - Native file picker (NSSavePanel)

#### FR7: Auto-Scroll
- **Description:** Automatically scroll to latest entry
- **Priority:** P2 (Medium)
- **Acceptance Criteria:**
  - Enabled by default
  - Toggle button to pause
  - Smooth animation (easeOut)
  - Resumes when toggled back on

#### FR8: Statistics
- **Description:** Display entry count and data rate
- **Priority:** P3 (Low)
- **Acceptance Criteria:**
  - Entry count (current / max)
  - Bytes/second (rolling average)
  - Chunks/second (rolling average)
  - Updates in real-time

### Non-Functional Requirements

#### NFR1: Performance
- Display 1000 entries in < 50ms
- Filter 1000 entries in < 10ms
- Syntax highlight per row in < 5ms
- 60fps scrolling (16ms per frame)
- Memory overhead < 10MB

#### NFR2: Accessibility
- Full keyboard navigation
- VoiceOver support
- Adequate contrast ratios (WCAG AA)
- Resizable text

#### NFR3: Maintainability
- Pure SwiftUI (no AppKit bridging unless necessary)
- Declarative, readable code
- Comprehensive unit tests
- Documented public APIs

#### NFR4: Compatibility
- macOS 26+ (Tahoe)
- Swift 5.9+
- Dark mode support (Catppuccin Mocha)
- Light mode optional (future)

---

## Architecture

### High-Level Overview

```
┌───────────────────────────────────────────────────────────┐
│ Game Server (GemStone IV)                                 │
│ Sends raw XML via TCP                                     │
└────────────────────┬──────────────────────────────────────┘
                     ↓
┌───────────────────────────────────────────────────────────┐
│ Lich 5 (Middleware)                                       │
│ Cleans XML, forwards to detachable clients                │
└────────────────────┬──────────────────────────────────────┘
                     ↓ (TCP localhost:8000, processed XML)
┌───────────────────────────────────────────────────────────┐
│ LichConnection (VaalinNetwork actor)                      │
│ Receives Data chunks via NWConnection                     │
└────────────────────┬──────────────────────────────────────┘
                     ↓ (Data → String, UTF-8)
┌───────────────────────────────────────────────────────────┐
│ LichConnection.handleIncomingData()                       │
│ ├─ Send to DebugWindowManager (if window open)           │
│ └─ Continue to XMLStreamParser (normal flow)             │
└────────────────────┬──────────────────────────────────────┘
                     ↓ #if DEBUG only
┌───────────────────────────────────────────────────────────┐
│ DebugWindowManager (@MainActor, singleton)               │
│ ├─ Circular buffer: [DebugLogEntry] (max 5000)           │
│ ├─ @Published var isOpen: Bool                           │
│ └─ func addEntry(_ data: String, session: String)        │
└────────────────────┬──────────────────────────────────────┘
                     ↓ (SwiftUI @Published updates)
┌───────────────────────────────────────────────────────────┐
│ DebugConsoleView (SwiftUI Window scene)                  │
│ ├─ Toolbar: filter, clear, copy, export                  │
│ ├─ List + ForEach: virtualized log entries               │
│ └─ DebugLogEntryRow: timestamp, session, highlighted XML │
└───────────────────────────────────────────────────────────┘
                     ↓ (user interaction)
┌───────────────────────────────────────────────────────────┐
│ User (Developer)                                          │
│ Views raw XML, filters, exports, debugs parser issues    │
└───────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. DebugWindowManager (State Manager)

**Type:** `@MainActor class` (singleton)

**Responsibilities:**
- Manage circular buffer of log entries
- Track window open/close state
- Provide entries to SwiftUI view
- Handle clear/export operations

**File:** `VaalinUI/Sources/VaalinUI/ViewModels/Debug/DebugWindowManager.swift`

**API:**
```swift
@MainActor
class DebugWindowManager: ObservableObject {
    static let shared = DebugWindowManager()

    @Published var isOpen: Bool = false
    @Published var entries: [DebugLogEntry] = []

    private let maxEntries: Int = 5000

    func toggle()
    func open()
    func close()
    func addEntry(_ data: String, session: String)
    func clear()
    func exportToFile() -> String  // Returns formatted export
}
```

#### 2. DebugLogEntry (Data Model)

**Type:** `struct` (Identifiable, Sendable)

**Responsibilities:**
- Store single log entry data
- Provide computed properties (byteCount, etc.)

**File:** `VaalinUI/Sources/VaalinUI/Models/DebugLogEntry.swift`

**API:**
```swift
struct DebugLogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let session: String
    let data: String
    let byteCount: Int

    init(data: String, session: String)
}
```

#### 3. DebugConsoleView (Main Window View)

**Type:** SwiftUI `View`

**Responsibilities:**
- Render debug console UI
- Handle user interactions
- Coordinate filtering and scrolling

**File:** `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift`

**Structure:**
```swift
struct DebugConsoleView: View {
    @StateObject private var manager = DebugWindowManager.shared
    @State private var filterText = ""
    @State private var autoScroll = true

    var body: some View {
        VStack {
            DebugToolbarView(...)
            Divider()
            DebugLogListView(...)
        }
    }
}
```

#### 4. DebugLogEntryRow (Single Entry View)

**Type:** SwiftUI `View`

**Responsibilities:**
- Render single log entry
- Apply syntax highlighting
- Enable text selection

**File:** `VaalinUI/Sources/VaalinUI/Views/Debug/DebugLogEntryView.swift`

**Structure:**
```swift
struct DebugLogEntryRow: View {
    let entry: DebugLogEntry

    var body: some View {
        HStack {
            Text(entry.timestamp, style: .time)
            Text("[\(entry.session)]")
            Text(highlightedXML(entry.data))
        }
    }

    private func highlightedXML(_ xml: String) -> AttributedString
}
```

#### 5. XMLSyntaxHighlighter (Utility)

**Type:** `struct` (static methods)

**Responsibilities:**
- Apply regex-based XML highlighting
- Use Catppuccin Mocha colors

**File:** `VaalinUI/Sources/VaalinUI/Views/Debug/XMLSyntaxHighlighter.swift`

**API:**
```swift
struct XMLSyntaxHighlighter {
    static func highlight(_ xml: String) -> AttributedString
}
```

---

## UI/UX Design

### Window Layout

```
┌───────────────────────────────────────────────────────────────┐
│ Debug Console - Raw XML Stream                         [× ]  │  ← Title bar
├───────────────────────────────────────────────────────────────┤
│ [Filter: regex...]  [🔍]  [📌 Pin]  [📋 Copy]  [💾 Export]  │  ← Toolbar
│                                         [🗑️ Clear]  [Close]   │
├───────────────────────────────────────────────────────────────┤
│ 22:14:32.123  [Teej]  <pushStream id="thoughts"/>           │  ← Log entries
│ 22:14:32.145  [Teej]  You think, "This is interesting."      │
│ 22:14:32.167  [Teej]  <popStream/>                           │
│ 22:14:33.201  [Teej]  <prompt>&gt;</prompt>                │
│ 22:14:35.334  [Teej]  <progressBar id="health" value="100"/> │
│ 22:14:36.112  [Teej]  <pushBold/><preset id="speech">       │
│ 22:14:36.134  [Teej]  You say, "Hello!"</preset><popBold/>  │
│                                                               │
│                    ↓ (virtualized scrolling)                  │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ [☑ Auto-scroll]            1,234 / 5,000 entries  42.3 KB/s │  ← Status bar
└───────────────────────────────────────────────────────────────┘
```

### Visual Design Specifications

#### Colors (Catppuccin Mocha)

```swift
enum DebugColors {
    static let background = Color(hex: "#1e1e2e")      // Base
    static let foreground = Color(hex: "#cdd6f4")      // Text
    static let secondary = Color(hex: "#6c7086")       // Overlay0
    static let border = Color(hex: "#313244")          // Surface0

    // Syntax highlighting
    static let tag = Color(hex: "#89b4fa")            // Sapphire (blue)
    static let attribute = Color(hex: "#94e2d5")      // Sky (teal)
    static let value = Color(hex: "#fab387")          // Peach (orange)
    static let comment = Color(hex: "#a6e3a1")        // Green
}
```

#### Typography

```swift
enum DebugFonts {
    static let timestamp = Font.system(.caption, design: .monospaced)
    static let session = Font.system(.caption, design: .monospaced)
    static let xmlData = Font.system(.body, design: .monospaced)
    static let toolbar = Font.system(.body)
}
```

#### Spacing

```swift
enum DebugSpacing {
    static let toolbarPadding: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 2
    static let columnSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 0
}
```

#### Sizing

```swift
enum DebugSizing {
    static let defaultWidth: CGFloat = 900
    static let defaultHeight: CGFloat = 600
    static let minWidth: CGFloat = 600
    static let minHeight: CGFloat = 400
    static let timestampWidth: CGFloat = 100
    static let sessionWidth: CGFloat = 120
}
```

### Interaction Patterns

#### Opening the Window

**Method 1: Keyboard Shortcut**
- Press `Command-Shift-D`
- Window appears at bottom-right of screen
- Starts capturing data immediately

**Method 2: Menu Command**
- Window menu → "Show Debug Console"
- Same behavior as keyboard shortcut

**Method 3: Game Command**
- Type `:debug` or `:raw` in game input
- Confirmation message: "Debug window opened"
- Window appears

#### Filtering Logs

1. Click filter text field (or press `Command-F`)
2. Type regex pattern (e.g., `pushStream|popStream`)
3. Logs update live (as you type)
4. Invalid regex shows red border + error message
5. Clear filter: click [×] button or delete all text

#### Copying Logs

1. Click "Copy" button
2. Filtered logs copied to clipboard (one per line)
3. Brief success indicator (green checkmark, 1 second)
4. Can paste into text editor

#### Exporting Logs

1. Click "Export" button
2. Native save panel appears
3. Default filename: `vaalin-debug-{timestamp}.xml`
4. File includes:
   - JSON metadata (session, timestamps, entry count)
   - Raw XML chunks (one per line)
5. Success/error feedback

#### Clearing Logs

**Method 1: Clear button**
- Click "Clear" button
- Confirmation dialog: "Clear all log entries?"
- Clears buffer, updates UI immediately

**Method 2: Game command**
- Type `:debug clear` or `:raw clear`
- Confirmation message: "Debug window cleared"
- No confirmation dialog (immediate)

#### Auto-Scroll

- Enabled by default (checkbox checked)
- When enabled: automatically scrolls to latest entry
- When disabled: stays at current scroll position
- Re-enabling: resumes auto-scroll
- Smooth animation (easeOut, 0.2s)

#### Closing the Window

**Method 1: Close button**
- Click "Close" button in toolbar

**Method 2: Window controls**
- Click [×] in title bar

**Method 3: Keyboard**
- Press `Command-W`

**Method 4: Game command**
- Type `:debug` or `:raw` again (toggles off)

### Accessibility

- **Keyboard navigation:** Full support (Tab, arrows, Enter)
- **VoiceOver:** All buttons labeled, row count announced
- **Contrast:** Exceeds WCAG AA (4.5:1 for text)
- **Resizable:** Allow user to resize text (respects system prefs)
- **Focus indicators:** Visible keyboard focus

---

## Technical Specification

### SwiftUI Window Scene

**File:** `Vaalin/VaalinApp.swift`

```swift
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            DebugWindowCommands()
        }

        #if DEBUG
        Window("Debug Console", id: "vaalin-debug-console") {
            DebugConsoleView()
        }
        .defaultSize(width: 900, height: 600)
        .defaultPosition(.bottomTrailing)
        .windowStyle(.hiddenTitleBar)        // Clean look, keep buttons
        .restorationBehavior(.disabled)       // Don't restore on launch
        .windowResizability(.automatic)       // Allow flexible resizing
        #endif
    }
}

struct DebugWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            #if DEBUG
            Divider()

            Button("Show Debug Console") {
                openWindow(id: "vaalin-debug-console")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            #endif
        }
    }
}
```

**Rationale:**
- `Window` scene: Single instance (appropriate for debug console)
- Hidden title bar: Clean look, still shows close/minimize buttons
- Disabled restoration: Debug window shouldn't restore on app launch
- Bottom-trailing position: Out of the way, common for debug tools

### Data Interception

**File:** `VaalinNetwork/Sources/VaalinNetwork/LichConnection.swift`

**Modification:**
```swift
actor LichConnection {
    private var sessionName: String = "Unknown"

    func handleIncomingData(_ data: Data) async {
        guard let text = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode data as UTF-8")
            return
        }

        // DEBUG ONLY: Send to debug window BEFORE parsing
        #if DEBUG
        await MainActor.run {
            DebugWindowManager.shared.addEntry(text, session: sessionName)
        }
        #endif

        // Continue normal flow: emit to parser
        dataContinuation?.yield(data)
    }

    func setSessionName(_ name: String) {
        sessionName = name
    }
}
```

**Key points:**
- Intercept **before** parsing (see raw data from Lich)
- `#if DEBUG` guard: Zero overhead in Release builds
- `await MainActor.run`: DebugWindowManager is @MainActor
- `sessionName`: Track which character (for multi-session future)

### Circular Buffer Implementation

**File:** `VaalinUI/Sources/VaalinUI/ViewModels/Debug/DebugWindowManager.swift`

```swift
@MainActor
class DebugWindowManager: ObservableObject {
    static let shared = DebugWindowManager()

    @Published var isOpen: Bool = false
    @Published var entries: [DebugLogEntry] = []

    private let maxEntries: Int = 5000

    private init() {}

    func toggle() {
        isOpen ? close() : open()
    }

    func open() {
        isOpen = true
    }

    func close() {
        isOpen = false
    }

    func addEntry(_ data: String, session: String) {
        // Only add if window is open (performance optimization)
        guard isOpen else { return }

        let entry = DebugLogEntry(data: data, session: session)
        entries.append(entry)

        // Circular buffer: Remove oldest
        if entries.count > maxEntries {
            entries.removeFirst()
        }
    }

    func clear() {
        entries.removeAll()
    }

    func exportToJSON() -> String {
        let metadata: [String: Any] = [
            "session": entries.first?.session ?? "Unknown",
            "start_time": entries.first?.timestamp.ISO8601Format() ?? "",
            "end_time": entries.last?.timestamp.ISO8601Format() ?? "",
            "entry_count": entries.count
        ]

        let chunks = entries.map { entry in
            [
                "timestamp": entry.timestamp.ISO8601Format(),
                "bytes": entry.byteCount,
                "data": entry.data
            ]
        }

        let export: [String: Any] = [
            "metadata": metadata,
            "chunks": chunks
        ]

        if let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return "{}"
    }
}
```

**Complexity:**
- Time: O(1) for append, O(1) for removeFirst (amortized)
- Space: O(maxEntries) = O(5000) = constant

### Syntax Highlighting

**File:** `VaalinUI/Sources/VaalinUI/Views/Debug/XMLSyntaxHighlighter.swift`

```swift
import SwiftUI

struct XMLSyntaxHighlighter {
    static func highlight(_ xml: String) -> AttributedString {
        var attributed = AttributedString(xml)

        // Define colors
        let tagColor = DebugColors.tag
        let attrColor = DebugColors.attribute
        let valueColor = DebugColors.value
        let commentColor = DebugColors.comment

        // Regex patterns (compiled once, reused)
        let patterns: [(NSRegularExpression, Color, Int?)] = [
            (try! NSRegularExpression(pattern: "</?[\\w-]+", options: []), tagColor, nil),
            (try! NSRegularExpression(pattern: "\\s([\\w-]+)=", options: []), attrColor, 1),
            (try! NSRegularExpression(pattern: "\"([^\"]*)\"", options: []), valueColor, nil),
            (try! NSRegularExpression(pattern: "<!--.*?-->", options: [.dotMatchesLineSeparators]), commentColor, nil)
        ]

        // Apply each pattern
        for (regex, color, group) in patterns {
            let range = NSRange(xml.startIndex..., in: xml)
            regex.enumerateMatches(in: xml, range: range) { match, _, _ in
                guard let match = match else { return }

                let matchRange = group.map { match.range(at: $0) } ?? match.range
                if let swiftRange = Range(matchRange, in: xml) {
                    attributed[swiftRange].foregroundColor = color
                }
            }
        }

        return attributed
    }
}
```

**Performance:**
- Regex compiled once (static patterns)
- Applied per-row (lazy, only visible rows)
- Typical row: ~100 chars → ~5ms (well under 16ms budget)

### Filtering

**File:** `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift`

```swift
struct DebugConsoleView: View {
    @StateObject private var manager = DebugWindowManager.shared
    @State private var filterText = ""
    @State private var filterError: String? = nil

    var filteredEntries: [DebugLogEntry] {
        if filterText.isEmpty {
            return manager.entries
        }

        // Try to compile regex
        guard let regex = try? NSRegularExpression(pattern: filterText, options: .caseInsensitive) else {
            // Invalid regex: show error, return empty
            DispatchQueue.main.async {
                filterError = "Invalid regex pattern"
            }
            return []
        }

        // Clear error if valid
        filterError = nil

        // Filter entries
        return manager.entries.filter { entry in
            let range = NSRange(entry.data.startIndex..., in: entry.data)
            return regex.firstMatch(in: entry.data, range: range) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with filter
            HStack {
                TextField("Filter (regex)...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .border(filterError != nil ? .red : .clear, width: 2)
                    .help(filterError ?? "")
                    .frame(maxWidth: 300)

                // ... rest of toolbar
            }
            .padding()

            // Log list
            // ...
        }
    }
}
```

**Error handling:**
- Invalid regex: Red border on text field
- Tooltip shows error message
- Returns empty array (no crash)

---

## Implementation Plan

### Phase 1: Minimal Window (2-3 hours) ✅

**Goal:** Basic window that opens/closes

**Tasks:**
1. Add `Window` scene to `VaalinApp.swift`
2. Create `DebugConsoleView.swift` with placeholder text
3. Create `DebugWindowCommands.swift` with keyboard shortcut
4. Test: Window opens with Cmd-Shift-D, closes with Cmd-W

**Deliverable:** Empty debug window that opens/closes

**Files:**
- `Vaalin/VaalinApp.swift` (modified)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift` (new)

**Testing:**
- Manual: Open with Cmd-Shift-D
- Manual: Close with Cmd-W
- Manual: Window menu shows command

---

### Phase 2: Data Flow (3-4 hours) ✅

**Goal:** Raw XML appears in window

**Tasks:**
1. Create `DebugLogEntry.swift` model
2. Create `DebugWindowManager.swift` actor
3. Modify `LichConnection.swift` to intercept data
4. Display entries in `List` with plain text
5. Implement circular buffer (5000 max)

**Deliverable:** Raw XML chunks appear in real-time

**Files:**
- `VaalinUI/Sources/VaalinUI/Models/DebugLogEntry.swift` (new)
- `VaalinUI/Sources/VaalinUI/ViewModels/Debug/DebugWindowManager.swift` (new)
- `VaalinNetwork/Sources/VaalinNetwork/LichConnection.swift` (modified)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift` (modified)

**Testing:**
- Unit: Circular buffer removes oldest entries
- Unit: DebugLogEntry initializes correctly
- Integration: Connect to Lich, see XML appear
- Performance: 5000 entries doesn't lag

---

### Phase 3: Core Features (4-6 hours) ✅

**Goal:** Usable debug tool

**Tasks:**
1. Implement regex filtering with error handling
2. Add clear button
3. Add copy button (clipboard)
4. Implement auto-scroll with toggle
5. Create `DebugLogEntryRow.swift` with layout
6. Add toolbar with all buttons

**Deliverable:** Functional debug window

**Files:**
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugLogEntryView.swift` (new)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugToolbarView.swift` (new)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift` (modified)

**Testing:**
- Unit: Regex filtering with valid/invalid patterns
- Unit: Clear removes all entries
- Integration: Copy to clipboard works
- Integration: Auto-scroll follows latest entry

---

### Phase 4: Syntax Highlighting (3-4 hours) ✅

**Goal:** XML color-coded for readability

**Tasks:**
1. Create `XMLSyntaxHighlighter.swift`
2. Implement regex-based highlighting (tags, attrs, values, comments)
3. Use Catppuccin Mocha colors
4. Apply highlighting per-row in `DebugLogEntryRow`
5. Profile performance (< 5ms per row)

**Deliverable:** Color-coded XML

**Files:**
- `VaalinUI/Sources/VaalinUI/Views/Debug/XMLSyntaxHighlighter.swift` (new)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugLogEntryView.swift` (modified)

**Testing:**
- Unit: Highlight returns correct AttributedString
- Visual: Colors match Catppuccin Mocha
- Performance: Profile 1000 row scrolling (60fps)

---

### Phase 5: Command Integration (2-3 hours) ✅

**Goal:** Toggle window from game commands

**Tasks:**
1. Modify `CommandInputViewModel.swift` to handle `:debug` and `:raw`
2. Handle `:debug clear` and `:raw clear`
3. Show confirmation messages in game log
4. Test with Lich connection

**Deliverable:** Commands work in-game

**Files:**
- `VaalinUI/Sources/VaalinUI/ViewModels/CommandInputViewModel.swift` (modified)

**Testing:**
- Integration: Type `:debug`, window opens
- Integration: Type `:debug clear`, buffer clears
- Integration: Confirmation messages appear in game log

---

### Phase 6: Export and Polish (3-4 hours) ✅

**Goal:** Production-ready debug tool

**Tasks:**
1. Implement export to file (JSON format)
2. Add status bar (entry count, bytes/sec)
3. Add keyboard shortcuts (Cmd-K clear, Cmd-F filter)
4. Polish UI (spacing, colors, fonts)
5. Write unit tests
6. Write integration tests
7. Update CLAUDE.md with debug window usage

**Deliverable:** Complete, polished debug window

**Files:**
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugConsoleView.swift` (modified)
- `VaalinUI/Sources/VaalinUI/Views/Debug/DebugStatusBar.swift` (new)
- `VaalinUI/Tests/VaalinUITests/ViewModels/Debug/DebugWindowManagerTests.swift` (new)
- `docs/CLAUDE.md` (modified)

**Testing:**
- Unit: All DebugWindowManager methods
- Unit: Export JSON format correct
- Integration: Full workflow (open, filter, export, close)
- Performance: 60fps with 5000 entries

---

### Phase 7: Optional Enhancements (6-10 hours, future) ⏳

**Goal:** Advanced features (not MVP)

**Tasks:**
1. Parse status annotations (success/error per chunk)
2. Statistics panel (chunks/sec, tag frequency)
3. Search within results with highlighting
4. Performance metrics (memory, CPU)
5. Pin-to-top toggle (floating window)

**Deliverable:** Comprehensive debugging suite

**Priority:** Low (implement based on usage feedback)

---

## Testing Strategy

### Unit Tests

**File:** `VaalinUI/Tests/VaalinUITests/ViewModels/Debug/DebugWindowManagerTests.swift`

```swift
import Testing
@testable import VaalinUI

struct DebugWindowManagerTests {
    @Test func test_addEntry_appendsToBuffer() async {
        let manager = DebugWindowManager()

        await MainActor.run {
            manager.open()
            manager.addEntry("<test/>", session: "Teej")
        }

        await MainActor.run {
            #expect(manager.entries.count == 1)
            #expect(manager.entries[0].data == "<test/>")
            #expect(manager.entries[0].session == "Teej")
        }
    }

    @Test func test_circularBuffer_removesOldest() async {
        let manager = DebugWindowManager()

        await MainActor.run {
            manager.open()

            // Add 5001 entries (exceeds max of 5000)
            for i in 0...5000 {
                manager.addEntry("<entry\(i)/>", session: "Teej")
            }
        }

        await MainActor.run {
            // Should have exactly 5000 entries
            #expect(manager.entries.count == 5000)

            // First entry should be entry #1 (entry #0 removed)
            #expect(manager.entries[0].data == "<entry1/>")

            // Last entry should be entry #5000
            #expect(manager.entries.last?.data == "<entry5000/>")
        }
    }

    @Test func test_clear_removesAllEntries() async {
        let manager = DebugWindowManager()

        await MainActor.run {
            manager.open()
            manager.addEntry("<test/>", session: "Teej")
            manager.clear()
        }

        await MainActor.run {
            #expect(manager.entries.isEmpty)
        }
    }

    @Test func test_filtering_withValidRegex() {
        let entries = [
            DebugLogEntry(data: "<pushStream id='thoughts'/>", session: "Teej"),
            DebugLogEntry(data: "You think, 'Test'", session: "Teej"),
            DebugLogEntry(data: "<popStream/>", session: "Teej"),
            DebugLogEntry(data: "<prompt>&gt;</prompt>", session: "Teej")
        ]

        let pattern = "push|pop"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        let filtered = entries.filter { entry in
            let range = NSRange(entry.data.startIndex..., in: entry.data)
            return regex.firstMatch(in: entry.data, range: range) != nil
        }

        #expect(filtered.count == 2)
        #expect(filtered[0].data.contains("pushStream"))
        #expect(filtered[1].data.contains("popStream"))
    }
}
```

### Integration Tests

**File:** `VaalinAppTests/IntegrationTests/DebugWindowIntegrationTests.swift`

```swift
import Testing
@testable import Vaalin
@testable import VaalinUI
@testable import VaalinNetwork

struct DebugWindowIntegrationTests {
    @Test func test_dataFlowFromLichToDebugWindow() async throws {
        // 1. Setup
        let manager = DebugWindowManager.shared
        await MainActor.run { manager.open() }

        // 2. Simulate LichConnection receiving data
        let connection = LichConnection()
        connection.setSessionName("Teej")

        let testXML = "<pushStream id='thoughts'/>"
        let testData = testXML.data(using: .utf8)!

        // 3. Trigger data handling
        await connection.handleIncomingData(testData)

        // 4. Verify debug window received it
        await MainActor.run {
            #expect(manager.entries.count == 1)
            #expect(manager.entries[0].data == testXML)
            #expect(manager.entries[0].session == "Teej")
        }
    }

    @Test func test_commandToggle() async {
        // 1. Setup
        let manager = DebugWindowManager.shared
        let viewModel = CommandInputViewModel()

        // 2. Initially closed
        await MainActor.run {
            #expect(manager.isOpen == false)
        }

        // 3. Type `:debug` command
        // (Would need to simulate command submission)
        await MainActor.run {
            viewModel.command = ":debug"
        }
        await viewModel.submitCommand { _ in }

        // 4. Verify window opened
        await MainActor.run {
            #expect(manager.isOpen == true)
        }
    }
}
```

### Performance Tests

**File:** `VaalinAppTests/PerformanceTests/DebugWindowPerformanceTests.swift`

```swift
import Testing
import XCTest  // For XCTMetric
@testable import VaalinUI

struct DebugWindowPerformanceTests {
    @Test func test_scrollingPerformance() async {
        // Test that scrolling 5000 entries maintains 60fps

        let manager = DebugWindowManager.shared

        await MainActor.run {
            manager.open()

            // Populate with 5000 entries
            for i in 0..<5000 {
                let xml = "<entry id='\(i)'>Data for entry \(i)</entry>"
                manager.addEntry(xml, session: "Teej")
            }
        }

        // Measure scrolling time
        // (Would use Instruments or custom timing)
        // Target: < 1 second to scroll from top to bottom
    }

    @Test func test_filteringPerformance() async {
        let manager = DebugWindowManager.shared

        await MainActor.run {
            manager.open()

            // Populate with 1000 entries
            for i in 0..<1000 {
                manager.addEntry("<entry id='\(i)'/>", session: "Teej")
            }
        }

        // Measure filtering time
        let start = Date()

        let pattern = "entry id='5'"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        await MainActor.run {
            let filtered = manager.entries.filter { entry in
                let range = NSRange(entry.data.startIndex..., in: entry.data)
                return regex.firstMatch(in: entry.data, range: range) != nil
            }

            _ = filtered.count  // Force evaluation
        }

        let duration = Date().timeIntervalSince(start)

        // Target: < 10ms for 1000 entries
        #expect(duration < 0.010)
    }
}
```

### Manual Testing Checklist

- [ ] Window opens with Cmd-Shift-D
- [ ] Window closes with Cmd-W
- [ ] Window appears bottom-right by default
- [ ] Raw XML appears in real-time
- [ ] Timestamps accurate to milliseconds
- [ ] Syntax highlighting colors correct
- [ ] Regex filtering works (valid patterns)
- [ ] Regex filtering shows error (invalid patterns)
- [ ] Clear button empties buffer
- [ ] Copy button copies to clipboard
- [ ] Export button saves to file
- [ ] Auto-scroll follows latest entry
- [ ] Auto-scroll toggle works
- [ ] Circular buffer limits to 5000 entries
- [ ] `:debug` command toggles window
- [ ] `:debug clear` clears buffer
- [ ] 60fps scrolling with 5000 entries
- [ ] Memory usage < 10MB
- [ ] Dark mode colors (Catppuccin Mocha)
- [ ] VoiceOver announces rows correctly
- [ ] Keyboard navigation works (Tab, arrows)

---

## Performance Requirements

### Response Times

| Operation | Target | Measured |
|-----------|--------|----------|
| Window open | < 100ms | - |
| Display 1000 entries | < 50ms | - |
| Filter 1000 entries | < 10ms | - |
| Syntax highlight (per row) | < 5ms | - |
| Scroll frame time | < 16ms (60fps) | - |
| Auto-scroll animation | 200ms | - |
| Copy to clipboard | < 50ms | - |
| Export to file | < 500ms | - |

### Memory

| Scenario | Target | Measured |
|----------|--------|----------|
| Empty buffer | < 1MB | - |
| 5000 entries | < 10MB | - |
| Peak usage | < 15MB | - |

### CPU

| Operation | Target | Measured |
|-----------|--------|----------|
| Idle (window open) | < 1% | - |
| Receiving data | < 5% | - |
| Filtering | < 10% (transient) | - |
| Scrolling | < 20% (transient) | - |

### Testing Tools

- **Xcode Instruments:** Time Profiler, Allocations, Leaks
- **SwiftUI Performance:** `TimelineView`, `_printChanges()`
- **Manual:** Activity Monitor, visual inspection

---

## Future Enhancements

### Priority: Low (Post-MVP)

#### 1. Parse Status Annotations
- Annotate chunks with parse success/error
- Show error messages inline
- Highlight problematic XML

#### 2. Statistics Panel
- Real-time metrics (chunks/sec, bytes/sec)
- Tag frequency histogram
- Error rate graph
- Memory usage graph

#### 3. Search with Highlighting
- Find within results
- Highlight matches
- Navigate between matches (Next/Prev buttons)

#### 4. Performance Metrics
- Parser timing per chunk
- UI render time
- Memory profiling integration

#### 5. Advanced Filtering
- Multiple regex patterns (OR logic)
- Preset filters (stream control, metadata, etc.)
- Save filter history

#### 6. Export Formats
- Plain text (current timestamp format)
- JSON (structured, with metadata)
- CSV (spreadsheet-friendly)
- HTML (styled, for sharing)

#### 7. Session Management
- Multi-session support (multiple characters)
- Session switcher dropdown
- Per-session filtering

#### 8. Parser Inspector
- Visualize parser state (stream stack, etc.)
- Show GameTag output alongside raw XML
- Side-by-side comparison (raw → parsed → rendered)

---

## Appendix

### Research References

All research findings documented in:
- `docs/debug-window/agent-report-illthorn.md` - Illthorn debug window analysis
- `docs/debug-window/agent-report-lich5-protocol.md` - Lich 5 protocol specification
- `docs/debug-window/agent-report-swiftui-windows.md` - SwiftUI multi-window patterns
- `docs/debug-window/agent-report-swiftui-components.md` - SwiftUI component performance

### Dependencies

**Zero external dependencies required.**

All components use native SwiftUI and AppKit (when necessary).

Optional (future): STTextView for line numbers (SPM package)

### Estimated Effort

| Phase | Hours | Priority |
|-------|-------|----------|
| Phase 1: Minimal Window | 2-3 | P0 (Critical) |
| Phase 2: Data Flow | 3-4 | P0 (Critical) |
| Phase 3: Core Features | 4-6 | P0 (Critical) |
| Phase 4: Syntax Highlighting | 3-4 | P1 (High) |
| Phase 5: Command Integration | 2-3 | P1 (High) |
| Phase 6: Export and Polish | 3-4 | P1 (High) |
| Phase 7: Optional Enhancements | 6-10 | P3 (Low) |
| **Total (MVP)** | **17-24 hours** | - |
| **Total (Full)** | **23-34 hours** | - |

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Performance degradation with large logs | High | Medium | Circular buffer + virtualized List |
| AttributedString performance issues | Medium | Low | Lazy per-row highlighting, profile early |
| Regex compilation overhead | Low | Medium | Pre-compile patterns, cache |
| Memory leak in circular buffer | High | Low | Unit tests, Instruments Leaks |
| Window positioning quirks | Low | Medium | Fallback to NSWindow if needed |
| Dark mode only (no light mode) | Low | High | Accept, add light mode in future |

### Success Criteria

**MVP Complete When:**
- ✅ Window opens/closes with Cmd-Shift-D
- ✅ Raw XML appears in real-time
- ✅ Syntax highlighting works (Catppuccin Mocha)
- ✅ Regex filtering works (with error handling)
- ✅ Circular buffer limits to 5000 entries
- ✅ Clear and copy buttons work
- ✅ 60fps scrolling with 5000 entries
- ✅ Memory usage < 10MB
- ✅ `:debug` command toggles window
- ✅ All unit tests pass

**Production-Ready When:**
- ✅ Export to file works
- ✅ Statistics in status bar
- ✅ Keyboard shortcuts (Cmd-K, Cmd-F)
- ✅ Full test coverage (unit + integration)
- ✅ Documentation in CLAUDE.md
- ✅ Performance benchmarks pass
- ✅ VoiceOver accessible

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Authors:** Claude (General-Purpose, SwiftUI Expert, GemStone XML Expert)
**Status:** ✅ Ready for Implementation
**Next Steps:** Create GitHub issue, implement Phase 1
