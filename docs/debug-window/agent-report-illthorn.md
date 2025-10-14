# Illthorn Debug Window Implementation Analysis

**Research Date:** 2025-10-12
**Source:** `/Users/trevor/Projects/illthorn/` (TypeScript reference implementation)
**Purpose:** Understand debug/raw XML viewing patterns for Vaalin

---

## Table of Contents

1. [Overview - What Exists](#overview---what-exists)
2. [Implementation Details](#implementation-details)
3. [Features](#features)
4. [UI/UX](#uiux)
5. [Code Examples](#code-examples)
6. [Planned Enhancements](#planned-enhancements)
7. [Recommendations for Vaalin](#recommendations-for-vaalin)

---

## Overview - What Exists

Illthorn has **two debug window implementations**:

### 1. Simple Raw Data Viewer (Implemented)
A fully functional debug window that displays raw XML from the game server in real-time.

**Location:** `src/frontend/dev-panel.{ts,html}`

**Status:** ✅ Production-ready and actively used

**Purpose:** View raw XML stream for debugging parser issues and understanding protocol

### 2. Advanced Parser Inspector (Planned)
A comprehensive debugging tool with parser state visualization and performance metrics.

**Location:** `docs/debug-window-plan.md`

**Status:** 📋 Planned, not yet implemented

**Purpose:** Deep parser debugging with side-by-side input/parsed/rendered comparison

---

## Implementation Details

### Architecture Overview

```
Game Server
    ↓ (raw XML via TCP)
Session.onMessage()
    ↓ (intercept BEFORE parsing)
DevWindow.sendRawData() [IPC]
    ↓ (Electron IPC channel)
DevPanel (separate BrowserWindow)
    ↓ (render with highlighting)
User views in floating window
```

**Key architectural decision:** Raw data is intercepted **before parsing** to show exactly what the game server sends.

### Window Creation

**File:** `backend/dev-window/index.ts`

```typescript
export function createDevWindow() {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;
  const preloadPath = path.join(__dirname, "../../preload/index.js");

  devWindow = new BrowserWindow({
    width: 600,
    height: 800,
    x: width - 620,  // Right side of screen with margin
    y: Math.max(0, (height - 800) / 2),  // Vertically centered
    title: "Illthorn Dev Panel - Raw Game Logs",
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  devWindow.loadFile("src/frontend/dev-panel.html");

  devWindow.on("closed", () => {
    devWindow = null;
  });
}
```

**Positioning:** Right side of screen, vertically centered, 600x800 px

**Security:** Context isolation enabled, no node integration (secure by default)

### Data Flow - Automatic Interception

**File:** `backend/session/index.ts:97-113`

**Critical implementation:** Every incoming message is automatically sent to dev window if open:

```typescript
async onMessage(incoming: string) {
  // STEP 1: Send to dev window FIRST (if open)
  const devWindowStatus = await window.DevWindow.isOpen();
  if (devWindowStatus.isOpen) {
    await window.DevWindow.sendRawData(incoming, this.name);
  }

  // STEP 2: Parse for game display
  const parsed = this.parser.parse(incoming);

  // STEP 3: Process parsed tags
  for (const tag of parsed) {
    // ... normal processing
  }
}
```

**Key insight:** No "debug mode" flag needed - if window is open, it automatically receives data.

### IPC Communication

**File:** `backend/dev-window/methods.ts`

```typescript
enum DevWindowMethods {
  Open = "DevWindow.Open",
  Close = "DevWindow.Close",
  IsOpen = "DevWindow.IsOpen",
  SendRawData = "DevWindow.SendRawData",
  Clear = "DevWindow.Clear",
  TogglePin = "DevWindow.TogglePin",
}

export const devWindowMethods = {
  async open() {
    if (!devWindow) {
      createDevWindow();
    }
    devWindow?.show();
  },

  async close() {
    devWindow?.close();
  },

  async isOpen() {
    return { isOpen: devWindow !== null && !devWindow.isDestroyed() };
  },

  async sendRawData(data: string, sessionName: string) {
    if (devWindow && !devWindow.isDestroyed()) {
      devWindow.webContents.send("dev:raw-data", {
        data,
        sessionName,
        timestamp: Date.now(),
      });
    }
  },

  async clear() {
    devWindow?.webContents.send("dev:clear");
  },

  async togglePin() {
    if (devWindow) {
      const isAlwaysOnTop = devWindow.isAlwaysOnTop();
      devWindow.setAlwaysOnTop(!isAlwaysOnTop);
      return { isPinned: !isAlwaysOnTop };
    }
    return { isPinned: false };
  },
};
```

### Frontend Implementation

**File:** `src/frontend/dev-panel.ts`

**Key features:**
- Circular buffer (max 1000 entries)
- Regex filtering with try/catch
- XML syntax highlighting via string replacement
- Auto-scroll with pause capability
- Copy to clipboard
- Dark VS Code theme

```typescript
interface LogEntry {
  data: string;
  sessionName: string;
  timestamp: number;
  id: string;
}

class DevPanel {
  private logs: LogEntry[] = [];
  private maxLogs = 1000;
  private filterRegex: RegExp | null = null;
  private autoScroll = true;

  constructor() {
    this.setupIPC();
    this.setupUI();
  }

  private setupIPC() {
    // Receive raw data from main process
    window.api.on("dev:raw-data", (entry) => {
      this.addLog(entry);
    });

    // Handle clear command
    window.api.on("dev:clear", () => {
      this.clearLogs();
    });
  }

  private addLog(entry: Omit<LogEntry, "id">) {
    const logEntry: LogEntry = {
      ...entry,
      id: crypto.randomUUID(),
    };

    this.logs.push(logEntry);

    // Circular buffer - remove oldest if over limit
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }

    this.render();
  }

  private render() {
    const filtered = this.getFilteredLogs();
    const container = document.getElementById("logs");

    if (!container) return;

    // Render logs with syntax highlighting
    container.innerHTML = filtered
      .map((log) => this.renderLogEntry(log))
      .join("");

    // Auto-scroll to bottom
    if (this.autoScroll) {
      container.scrollTop = container.scrollHeight;
    }
  }

  private renderLogEntry(log: LogEntry): string {
    const highlighted = this.highlightXML(log.data);
    const time = new Date(log.timestamp).toLocaleTimeString();

    return `
      <div class="log-entry" data-id="${log.id}">
        <span class="timestamp">${time}</span>
        <span class="session">[${log.session}]</span>
        <span class="data">${highlighted}</span>
      </div>
    `;
  }

  private highlightXML(xml: string): string {
    return xml
      // Comments
      .replace(/(&lt;!--.*?--&gt;)/g, '<span class="xml-comment">$1</span>')
      // Opening tags
      .replace(/(&lt;\w+)/g, '<span class="xml-tag">$1</span>')
      // Closing tags
      .replace(/(&lt;\/\w+&gt;)/g, '<span class="xml-tag">$1</span>')
      // Tag endings
      .replace(/(\/&gt;|&gt;)/g, '<span class="xml-tag">$1</span>')
      // Attribute names
      .replace(/(\w+)=/g, '<span class="xml-attr">$1</span>=')
      // Attribute values
      .replace(/="([^"]*)"/g, '=<span class="xml-value">"$1"</span>');
  }

  private getFilteredLogs(): LogEntry[] {
    if (!this.filterRegex) {
      return this.logs;
    }

    return this.logs.filter((log) => this.filterRegex!.test(log.data));
  }

  private setFilter(pattern: string) {
    if (!pattern) {
      this.filterRegex = null;
      this.render();
      return;
    }

    try {
      this.filterRegex = new RegExp(pattern, "i");
      this.render();
    } catch (error) {
      console.error("Invalid regex pattern:", error);
      // Show error to user
      this.showError("Invalid regex pattern");
    }
  }

  private copyToClipboard() {
    const filtered = this.getFilteredLogs();
    const text = filtered.map((log) => log.data).join("\n");

    navigator.clipboard.writeText(text).then(
      () => this.showSuccess("Copied to clipboard"),
      (err) => this.showError("Failed to copy: " + err)
    );
  }

  private clearLogs() {
    this.logs = [];
    this.render();
  }

  private togglePin() {
    window.DevWindow.togglePin().then((result) => {
      const button = document.getElementById("pin-button");
      if (button) {
        button.textContent = result.isPinned ? "📌 Pinned" : "📌 Pin";
      }
    });
  }
}

// Initialize on load
new DevPanel();
```

### Styling

**File:** `src/frontend/dev-panel.html` (inline styles)

**Theme:** Dark VS Code colors (monaco theme)

```css
body {
  background: #1e1e1e;
  color: #d4d4d4;
  font-family: 'Consolas', 'Monaco', monospace;
  margin: 0;
  padding: 0;
}

.header {
  background: #252526;
  padding: 10px;
  border-bottom: 1px solid #3e3e42;
}

.filter-input {
  background: #3c3c3c;
  border: 1px solid #3e3e42;
  color: #cccccc;
  padding: 5px 10px;
  width: 300px;
}

.button {
  background: #0e639c;
  border: none;
  color: white;
  padding: 5px 15px;
  cursor: pointer;
}

.button:hover {
  background: #1177bb;
}

#logs {
  height: calc(100vh - 60px);
  overflow-y: auto;
  padding: 10px;
}

.log-entry {
  margin-bottom: 8px;
  line-height: 1.5;
}

.timestamp {
  color: #858585;
  font-size: 0.9em;
}

.session {
  color: #4ec9b0;
  font-weight: bold;
}

.xml-tag {
  color: #569cd6;  /* Blue */
}

.xml-attr {
  color: #9cdcfe;  /* Cyan */
}

.xml-value {
  color: #ce9178;  /* Orange */
}

.xml-comment {
  color: #6a9955;  /* Green */
}
```

---

## Features

### ✅ Implemented Features

1. **Real-time Raw XML Display**
   - Shows every chunk received from game server
   - Displayed in order received
   - No parsing or modification

2. **XML Syntax Highlighting**
   - Tags: Blue (#569cd6)
   - Attributes: Cyan (#9cdcfe)
   - Values: Orange (#ce9178)
   - Comments: Green (#6a9955)

3. **Regex Filtering**
   - Case-insensitive by default
   - Live filtering (updates as you type)
   - Error handling for invalid patterns
   - Shows only matching entries

4. **Auto-scroll with Pause**
   - Automatically scrolls to latest entry
   - Can disable for examining history
   - Re-enables when scrolled to bottom

5. **Circular Buffer (1000 entries)**
   - Prevents memory bloat
   - Oldest entries removed automatically
   - Fixed memory footprint

6. **Copy to Clipboard**
   - Copies filtered entries only
   - One entry per line
   - Success/error feedback

7. **Clear Buffer**
   - Removes all log entries
   - Instant UI update
   - Can be triggered via command

8. **Pin Window (Always on Top)**
   - Toggle floating behavior
   - Stays above other windows
   - Useful during active debugging

9. **Session Tracking**
   - Shows which character sent the data
   - Useful when multiple sessions active
   - Displayed in header of each entry

10. **Command Integration**
    - `:dev` - Toggle window open/close
    - `:dev clear` - Clear all logs
    - Executed in main game input

11. **Keyboard Shortcuts**
    - Ctrl+Shift+D - Close window
    - (More can be added easily)

### 📋 Planned Features (Not Implemented)

From `docs/debug-window-plan.md`:

1. **Three-pane Layout**
   - Raw logs viewer
   - Parser inspector (state visualization)
   - Controls dashboard

2. **Parser State Visualization**
   - Raw XML → GameTag → DOM transformation
   - Tag tree visualization
   - Current parser state (stream stack, etc.)

3. **Performance Metrics**
   - Parse timing per chunk
   - Tag counts by type
   - Error rates
   - Memory usage

4. **Debug Namespace Toggles**
   - Enable/disable debug categories
   - `illthorn:*` namespace filtering
   - Per-module debug levels

5. **Export Functionality**
   - Save session as JSON
   - Export filtered logs
   - Include metadata

6. **Advanced Search**
   - Search within results
   - Highlight matches
   - Navigate between results

7. **Side-by-side Comparison**
   - Raw input
   - Parsed GameTag
   - Rendered DOM
   - Synchronized scrolling

8. **Parse Tree Visualization**
   - Tree component for nested tags
   - Expand/collapse nodes
   - Click to view details

---

## UI/UX

### Layout

```
┌─────────────────────────────────────────────────────────┐
│ Illthorn Dev Panel - Raw Game Logs               [×]    │
├─────────────────────────────────────────────────────────┤
│ [Filter: regex...] [📌 Pin] [📋 Copy] [Clear]          │
├─────────────────────────────────────────────────────────┤
│ 22:14:32  [Teej]  <pushStream id="thoughts">           │
│ 22:14:32  [Teej]  You think, "This is interesting."    │
│ 22:14:32  [Teej]  <popStream>                          │
│ 22:14:33  [Teej]  <prompt>&gt;</prompt>               │
│ 22:14:35  [Teej]  <streamWindow id="main" title="">   │
│ 22:14:35  [Teej]  You swing at the troll!             │
│ 22:14:36  [Teej]  <pushBold/><preset id="damage">      │
│ 22:14:36  [Teej]  You hit the troll for 45 damage!    │
│                                                         │
│                    ↓ (auto-scroll)                      │
│                                                         │
│ [Auto-scroll: ON]                      847 entries     │
└─────────────────────────────────────────────────────────┘
```

### User Interactions

**Opening the window:**
1. Type `:dev` in game command input
2. Window appears on right side of screen
3. Starts capturing raw data immediately

**Filtering logs:**
1. Click filter input
2. Type regex pattern (e.g., `pushStream|popStream`)
3. Logs update live to show only matches
4. Invalid regex shows error message

**Copying logs:**
1. Click "Copy" button
2. Filtered logs copied to clipboard
3. Success message shown
4. Can paste into text editor for analysis

**Clearing logs:**
1. Click "Clear" button, OR
2. Type `:dev clear` in game
3. All logs removed
4. Buffer reset to empty

**Pinning window:**
1. Click "Pin" button
2. Window floats above all others
3. Button text changes to "Pinned"
4. Click again to unpin

**Closing window:**
1. Click [×] button, OR
2. Type `:dev` again in game, OR
3. Press Ctrl+Shift+D

### Visual Feedback

- **Success:** Green notification (brief)
- **Error:** Red notification with message
- **Loading:** Spinner (not used currently - instant)
- **Empty state:** "No logs yet. Waiting for data..."
- **Filtered empty:** "No logs match filter."

---

## Code Examples

### Example 1: Intercepting Raw Data

**File:** `backend/session/index.ts`

```typescript
export class Session {
  private parser: SaxophoneParser;
  private name: string;

  constructor(name: string) {
    this.name = name;
    this.parser = new SaxophoneParser();
    this.setupNetworkHandlers();
  }

  async onMessage(incoming: string) {
    // DEV WINDOW: Send raw data FIRST
    const devWindowStatus = await window.DevWindow.isOpen();
    if (devWindowStatus.isOpen) {
      await window.DevWindow.sendRawData(incoming, this.name);
    }

    // THEN parse for game display
    const parsed = this.parser.parse(incoming);

    // Process tags
    for (const tag of parsed) {
      this.processTag(tag);
    }
  }
}
```

### Example 2: IPC Setup

**File:** `backend/dev-window/index.ts`

```typescript
import { ipcMain, BrowserWindow } from "electron";

let devWindow: BrowserWindow | null = null;

// Register IPC handlers
export function registerDevWindowHandlers() {
  ipcMain.handle("DevWindow.Open", async () => {
    if (!devWindow) {
      devWindow = createDevWindow();
    }
    devWindow.show();
  });

  ipcMain.handle("DevWindow.Close", async () => {
    devWindow?.close();
    devWindow = null;
  });

  ipcMain.handle("DevWindow.IsOpen", async () => {
    return { isOpen: devWindow !== null && !devWindow.isDestroyed() };
  });

  ipcMain.handle("DevWindow.SendRawData", async (_, data: string, sessionName: string) => {
    if (devWindow && !devWindow.isDestroyed()) {
      devWindow.webContents.send("dev:raw-data", {
        data,
        sessionName,
        timestamp: Date.now(),
      });
    }
  });

  ipcMain.handle("DevWindow.Clear", async () => {
    devWindow?.webContents.send("dev:clear");
  });

  ipcMain.handle("DevWindow.TogglePin", async () => {
    if (devWindow) {
      const isAlwaysOnTop = devWindow.isAlwaysOnTop();
      devWindow.setAlwaysOnTop(!isAlwaysOnTop);
      return { isPinned: !isAlwaysOnTop };
    }
    return { isPinned: false };
  });
}
```

### Example 3: Command Handler

**File:** `frontend/illthorn.ts`

```typescript
export class Illthorn {
  async handleCommand(command: string): Promise<boolean> {
    const trimmed = command.trim().toLowerCase();

    switch (trimmed) {
      case ":dev":
        return this.toggleDevWindow();

      case ":dev clear":
        return this.clearDevWindow();

      // ... other commands

      default:
        return false;  // Not a recognized command
    }
  }

  private async toggleDevWindow(): Promise<boolean> {
    const status = await window.DevWindow.isOpen();

    if (status.isOpen) {
      await window.DevWindow.close();
      this.showMessage("Dev window closed");
    } else {
      await window.DevWindow.open();
      this.showMessage("Dev window opened");
    }

    return true;
  }

  private async clearDevWindow(): Promise<boolean> {
    await window.DevWindow.clear();
    this.showMessage("Dev window cleared");
    return true;
  }
}
```

### Example 4: Preload Script (IPC Bridge)

**File:** `preload/index.ts`

```typescript
import { contextBridge, ipcRenderer } from "electron";

// Expose safe IPC methods to renderer
contextBridge.exposeInMainWorld("DevWindow", {
  open: () => ipcRenderer.invoke("DevWindow.Open"),
  close: () => ipcRenderer.invoke("DevWindow.Close"),
  isOpen: () => ipcRenderer.invoke("DevWindow.IsOpen"),
  sendRawData: (data: string, sessionName: string) =>
    ipcRenderer.invoke("DevWindow.SendRawData", data, sessionName),
  clear: () => ipcRenderer.invoke("DevWindow.Clear"),
  togglePin: () => ipcRenderer.invoke("DevWindow.TogglePin"),
});

// Expose event listeners
contextBridge.exposeInMainWorld("api", {
  on: (channel: string, callback: (data: any) => void) => {
    ipcRenderer.on(channel, (_, data) => callback(data));
  },
});
```

---

## Planned Enhancements

### Advanced Debug Window (from docs/debug-window-plan.md)

**Not implemented because:** "Debug window provides immediate value for current development... will be invaluable for testing saxophone integration. Full advanced version can be built incrementally as needs arise."

#### Planned Architecture

```
┌───────────────────────────────────────────────────────────┐
│ Illthorn Advanced Debug Window                      [×]   │
├───────────────────────────────────────────────────────────┤
│ [Raw Logs] [Parser Inspector] [Performance] [Controls]   │ ← Tabs
├─────────────────┬─────────────────┬───────────────────────┤
│                 │                 │                       │
│   Raw Logs      │ Parser State    │   Performance Stats   │
│   (current      │ Visualization   │   Parse time: 2ms     │
│   implementation│                 │   Tag count: 47       │
│   enhanced)     │  Raw → GameTag  │   Errors: 0           │
│                 │       ↓         │   Memory: 2.3MB       │
│                 │    Rendered     │                       │
│                 │                 │                       │
│                 │ [Tag Tree]      │   [Export JSON]       │
│                 │ └─ pushStream   │   [Clear Stats]       │
│                 │    ├─ text      │                       │
│                 │    └─ popStream │                       │
└─────────────────┴─────────────────┴───────────────────────┘
```

#### Planned Components

**Using Lit + Shoelace UI:**

1. **`debug-app.lit.ts`**
   - Main coordinator
   - Three-pane layout with `<sl-split-panel>`
   - Tab navigation

2. **`debug-log-viewer.lit.ts`**
   - Enhanced log viewer (current functionality + more)
   - Search with highlighting
   - Export filtered results

3. **`debug-parser-inspector.lit.ts`**
   - Parser state visualization
   - Tag tree using `<sl-tree>`
   - Side-by-side comparison (raw → parsed → rendered)

4. **`debug-controls-panel.lit.ts`**
   - Debug namespace toggles
   - Performance monitoring
   - Statistics dashboard

#### Planned Features Priority

1. **High Priority:**
   - Parser state visualization (raw → GameTag → DOM)
   - Performance timing metrics
   - Tag tree visualization

2. **Medium Priority:**
   - Side-by-side comparison view
   - Export to JSON
   - Debug namespace toggles

3. **Low Priority:**
   - Advanced search with highlighting
   - Memory profiling
   - Network traffic inspector

**Timeline:** "Build when parser migration happens and we need deeper debugging."

---

## Recommendations for Vaalin

### What to Adopt from Illthorn

#### 1. Automatic Raw Data Interception ⭐⭐⭐

**High value, easy to implement**

```swift
// In LichConnection actor
actor LichConnection {
  func handleIncomingData(_ data: Data) async {
    guard let text = String(data: data, encoding: .utf8) else { return }

    // FIRST: Send to debug window if open
    #if DEBUG
    await DebugWindowManager.shared.sendRawData(text, sessionName: sessionName)
    #endif

    // THEN: Process normally
    dataContinuation?.yield(data)
  }
}
```

**Benefits:**
- No manual "debug mode" flag
- Zero impact when window closed
- Captures everything automatically

#### 2. Separate Window Architecture ⭐⭐⭐

**SwiftUI `Window` scene instead of Electron BrowserWindow**

```swift
@main
struct VaalinApp: App {
  var body: some Scene {
    WindowGroup {
      MainView()
    }

    #if DEBUG
    Window("Debug Console", id: "vaalin-debug-console") {
      DebugConsoleView()
    }
    .defaultSize(width: 600, height: 800)
    .defaultPosition(.bottomTrailing)
    .windowStyle(.hiddenTitleBar)
    .restorationBehavior(.disabled)
    #endif
  }
}
```

**Benefits:**
- Native macOS behavior
- No IPC complexity (single process)
- Much simpler than Electron multi-window

#### 3. Simple UI First ⭐⭐⭐

**Start minimal, add features incrementally**

Illthorn proves that even the simple version is **incredibly valuable**:
> "Debug window provides immediate value for current development... will be invaluable for testing"

Don't over-engineer - basic version is highly useful.

#### 4. Circular Buffer (1000-5000 entries) ⭐⭐⭐

**Prevents memory bloat**

```swift
actor DebugWindowManager {
  private var entries: [DebugLogEntry] = []
  private let maxEntries = 5000

  func addEntry(_ entry: DebugLogEntry) {
    entries.append(entry)
    if entries.count > maxEntries {
      entries.removeFirst()
    }
  }
}
```

**Benefits:**
- Fixed memory footprint
- No manual cleanup needed
- Simple FIFO queue

#### 5. Regex Filtering ⭐⭐

**With error handling**

```swift
private func setFilter(_ pattern: String) {
  if pattern.isEmpty {
    filterRegex = nil
    return
  }

  do {
    filterRegex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
  } catch {
    // Show error to user
    showError("Invalid regex pattern")
  }
}
```

#### 6. XML Syntax Highlighting ⭐⭐

**Use Catppuccin Mocha colors to match main app**

```swift
let colors: [String: Color] = [
  "tag": Color(hex: "#89b4fa"),      // Blue
  "attribute": Color(hex: "#94e2d5"), // Teal
  "value": Color(hex: "#fab387"),    // Peach
  "comment": Color(hex: "#a6e3a1"),  // Green
  "text": Color(hex: "#cdd6f4")      // Text
]
```

#### 7. Command Integration ⭐⭐

**`:debug` or `:raw` commands**

```swift
@Observable
class CommandInputViewModel {
  func submitCommand() async {
    let command = command.trimmingCharacters(in: .whitespaces)

    if command == ":debug" || command == ":raw" {
      DebugWindowManager.shared.toggle()
      handler("Debug window \(DebugWindowManager.shared.isOpen ? "opened" : "closed")")
      return
    }

    if command == ":debug clear" {
      DebugWindowManager.shared.clear()
      handler("Debug window cleared")
      return
    }

    // ... normal command handling
  }
}
```

#### 8. Always-on-Top Toggle ⭐

**Optional but useful**

```swift
// Modern approach (macOS 15+)
Window("Debug Console", id: "debug-console") {
  DebugConsoleView()
}
.windowLevel(.floating)  // Always on top

// Legacy approach
if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-console" }) {
  window.level = .floating
}
```

### What to Adapt (Not Direct Port)

#### SwiftUI Instead of Lit/HTML

**Illthorn:** HTML with inline styles, DOM manipulation
**Vaalin:** SwiftUI with declarative views, no DOM

```swift
// SwiftUI approach
struct DebugLogEntryView: View {
  let entry: DebugLogEntry

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text(entry.timestamp, style: .time)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.secondary)

      Text("[\(entry.session)]")
        .foregroundColor(.teal)

      Text(highlightedXML(entry.data))
        .font(.system(.body, design: .monospaced))
    }
  }

  private func highlightedXML(_ xml: String) -> AttributedString {
    // Use AttributedString instead of HTML spans
  }
}
```

#### Actor-Based State Instead of IPC

**Illthorn:** Electron IPC between main/renderer processes
**Vaalin:** Swift actors for thread-safe state

```swift
@MainActor
class DebugWindowManager: ObservableObject {
  static let shared = DebugWindowManager()

  @Published var isOpen = false
  @Published var entries: [DebugLogEntry] = []

  func sendRawData(_ data: String, sessionName: String) {
    // Direct method call, no IPC needed
    let entry = DebugLogEntry(data: data, session: sessionName, timestamp: Date())
    entries.append(entry)
    // ... circular buffer logic
  }
}
```

#### List Instead of DOM Rendering

**Illthorn:** Manual DOM manipulation with `innerHTML`
**Vaalin:** SwiftUI List with ForEach (virtualized, efficient)

```swift
ScrollViewReader { proxy in
  List(filteredEntries) { entry in
    DebugLogEntryView(entry: entry)
      .id(entry.id)
  }
  .onChange(of: entries.count) { _, _ in
    if autoScroll, let last = entries.last {
      proxy.scrollTo(last.id, anchor: .bottom)
    }
  }
}
```

### Implementation Priority for Vaalin

#### Phase 1: MVP (2-3 hours) ⭐⭐⭐
- Basic window with SwiftUI `Window` scene
- DebugWindowManager actor
- Intercept raw data from LichConnection
- Display with monospace text
- Command integration (`:debug`)

**Deliverable:** Can view raw XML in separate window

#### Phase 2: Core Features (4-6 hours) ⭐⭐⭐
- Circular buffer (5000 entries)
- Regex filtering
- Clear and copy buttons
- Auto-scroll toggle
- Session name in entries

**Deliverable:** Usable debug tool

#### Phase 3: Polish (4-6 hours) ⭐⭐
- XML syntax highlighting (AttributedString)
- Status bar (entry count, filter status)
- Export to file (NSSavePanel)
- Keyboard shortcuts (Cmd-K clear, Cmd-F focus filter)

**Deliverable:** Production-quality tool

#### Phase 4: Advanced (6-10 hours, optional) ⭐
- Parse status annotations (success/error per chunk)
- Statistics panel (bytes/sec, tags/sec, errors)
- Search with result highlighting
- Performance metrics

**Deliverable:** Comprehensive debugging suite

### Key Differences from Illthorn

| Aspect | Illthorn | Vaalin |
|--------|----------|--------|
| **Platform** | Electron (multi-process) | Native macOS (single process) |
| **UI Framework** | HTML/CSS + Lit | SwiftUI |
| **Communication** | IPC (main ↔ renderer) | Direct actor calls |
| **Text Display** | DOM manipulation | List + ForEach |
| **Highlighting** | HTML spans | AttributedString |
| **Scrolling** | Manual scrollTop | ScrollViewReader |
| **Buffer** | Array + shift() | Circular buffer |
| **State** | Class + events | @Observable + @Published |

---

## Conclusion

**Key Takeaways:**

1. **Simple is valuable** - Illthorn's basic debug window is production-ready and highly useful
2. **Intercept early** - Send raw data to debug window BEFORE parsing
3. **Circular buffer** - Essential for memory management
4. **Command integration** - `:debug` toggle is convenient
5. **Start minimal** - Advanced features can wait

**Proof of concept:** Illthorn uses its simple debug window daily for parser development and issue debugging. The planned "advanced" version isn't needed yet.

**For Vaalin:** Implement Phase 1-2 first (6-9 hours), validate with real usage, then decide if Phase 3-4 are worth the effort.

**Estimated total effort:** 12-20 hours for full-featured debug window (Phases 1-3)

---

**Report compiled by:** Claude (General-Purpose Agent)
**Source codebase:** Illthorn v0.x (TypeScript/Electron)
**For project:** Vaalin - Native macOS GemStone IV Client
**Target platform:** macOS 26+ (Tahoe) with SwiftUI
