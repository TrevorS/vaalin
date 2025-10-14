# SwiftUI Multi-Window Patterns for macOS Debug/Log Viewer

**Research Date:** 2025-10-12
**Target:** macOS 26+ (Tahoe) with SwiftUI
**Purpose:** Auxiliary debug/log viewer window for Vaalin

---

## Table of Contents

1. [SwiftUI Window APIs: WindowGroup vs Window vs Scene](#swiftui-window-apis-windowgroup-vs-window-vs-scene)
2. [Creating Auxiliary Windows](#creating-auxiliary-windows)
3. [Window Management: Position, Size, Persistence](#window-management-position-size-persistence)
4. [Best Practices: Apple's Recommendations](#best-practices-apples-recommendations)
5. [Code Examples: Practical Patterns](#code-examples-practical-patterns)
6. [macOS HIG: Design Guidelines](#macos-hig-design-guidelines)
7. [Recommendations for Vaalin](#recommendations-for-vaalin)

---

## SwiftUI Window APIs: WindowGroup vs Window vs Scene

### Scene Types Overview

SwiftUI provides five primary scene types for macOS applications:

#### 1. WindowGroup
- **Purpose:** Creates a group of identically structured windows
- **Use Case:** Document-based applications, multiple instances of same content
- **Key Features:**
  - Users can create unlimited windows with same UI
  - Each window maintains separate state
  - macOS automatically provides tab grouping
  - Supports `Settings` and `CommandGroup` for preferences/menus
  - State isolation: Each window gets separate storage for `@State` variables

```swift
WindowGroup {
    ContentView()
}

// Named with identifier
WindowGroup(id: "editor") {
    EditorView()
}

// Typed for specific data
WindowGroup(for: Item.ID.self) { $itemId in
    ItemView(itemId: itemId ?? UUID())
}
```

**When to use:**
- Text editors where users open multiple documents
- Drawing apps with multiple canvases
- Any app where users might want multiple windows of the same type

#### 2. Window Scene
- **Purpose:** Single, unique window with specific identifier
- **Use Case:** Utility windows, inspector panels, statistics views
- **Key Features:**
  - Only one instance can exist
  - Assigned unique identifier
  - Perfect for auxiliary/supplementary windows
  - App quits when main window closes (if only window type)

```swift
Window("Statistics", id: "stats") {
    StatisticsView()
}

Window("Debug Console", id: "debug-console") {
    DebugConsoleView()
}
```

**When to use:**
- Debug/log viewer windows (our use case!)
- About windows
- Inspector panels
- Statistics dashboards
- Preference windows (though `Settings` scene is better)

#### 3. Settings Scene
- **Purpose:** Dedicated settings/preferences window
- **Use Case:** App configuration and preferences
- **Key Features:**
  - Automatically adds "Settings..." menu item (Command-,)
  - Manages app preferences lifecycle
  - Standard macOS settings window behavior

```swift
Settings {
    SettingsView()
}
```

#### 4. DocumentGroup
- **Purpose:** File-based document applications
- **Use Case:** Apps that create/open/save documents
- **Key Features:**
  - Document lifecycle management
  - Native file operations (New, Open, Save)
  - Integration with macOS document handling

```swift
DocumentGroup(newDocument: MyDocument()) { file in
    DocumentView(document: file.$document)
}
```

#### 5. MenuBarExtra
- **Purpose:** System menu bar integration
- **Use Case:** Background apps, quick utilities
- **Key Features:**
  - Renders control in menu bar
  - Can show menu or window on click
  - Customizable icon and behavior

```swift
MenuBarExtra("Vaalin", systemImage: "gamecontroller") {
    MenuBarView()
}
.menuBarExtraStyle(.window)
```

### WindowGroup vs Window: Decision Matrix

| Feature | WindowGroup | Window |
|---------|-------------|--------|
| Multiple instances | Yes | No (single instance) |
| Tab grouping (macOS) | Yes | No |
| State isolation per window | Yes | N/A |
| Document-based apps | Perfect | No |
| Utility windows | Possible but overkill | Perfect |
| Requires unique ID | Optional | Required |
| Memory overhead | Higher (multiple) | Lower (single) |
| Menu integration | Full support | Limited |

**For debug/log viewer:** `Window` scene is the clear choice.

---

## Creating Auxiliary Windows

### Basic Implementation Pattern

#### 1. Define Window Scene in App

```swift
@main
struct VaalinApp: App {
    var body: some Scene {
        // Main application window
        WindowGroup {
            MainView()
        }

        // Debug/log viewer window
        Window("Debug Console", id: "debug-console") {
            DebugConsoleView()
        }
        #if DEBUG
        .defaultSize(width: 800, height: 600)
        .defaultPosition(.bottomTrailing)
        .restorationBehavior(.disabled) // Don't restore debug window
        #endif
    }
}
```

#### 2. Open Window Programmatically

```swift
struct MainView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            // Your main UI

            #if DEBUG
            Button("Open Debug Console") {
                openWindow(id: "debug-console")
            }
            #endif
        }
    }
}
```

#### 3. Close Window from Within

```swift
struct DebugConsoleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            // Debug content

            Button("Close") {
                dismiss()
            }
        }
    }
}
```

### Opening Windows with Keyboard Shortcuts

Add keyboard shortcuts via `CommandGroup`:

```swift
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Show Debug Console") {
                    openWindow(id: "debug-console")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Window("Debug Console", id: "debug-console") {
            DebugConsoleView()
        }
    }
}
```

**Standard keyboard shortcuts for debug windows:**
- Command-Shift-D (common in IDEs)
- Command-Option-D
- Command-0 (like Xcode's navigator toggle)

### Checking Multi-Window Support

```swift
struct ContentView: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    var body: some View {
        if supportsMultipleWindows {
            // Show window management controls
        }
    }
}
```

---

## Window Management: Position, Size, Persistence

### Initial Size and Position

#### Using defaultSize and defaultPosition

```swift
Window("Debug Console", id: "debug-console") {
    DebugConsoleView()
}
.defaultSize(width: 800, height: 600)
.defaultPosition(.bottomTrailing)
```

**Available positions:**
- `.topLeading`, `.top`, `.topTrailing`
- `.leading`, `.center`, `.trailing`
- `.bottomLeading`, `.bottom`, `.bottomTrailing`

#### Custom Window Placement (macOS 15+)

```swift
.defaultWindowPlacement { content, context in
    let displayBounds = context.defaultDisplay.visibleRect
    let size = content.sizeThatFits(.unspecified)
    let position = CGPoint(
        x: displayBounds.midX - (size.width / 2),
        y: displayBounds.maxY - size.height - 20
    )
    return WindowPlacement(position, size: size)
}
```

### Window Resizability

```swift
// Allow any resizing (default)
.windowResizability(.automatic)

// Lock to content size
.windowResizability(.contentSize)

// Minimum content size only
.windowResizability(.contentMinSize)
```

**For debug windows:** Use `.automatic` to allow flexible resizing.

### Window Persistence and Restoration

macOS automatically persists window size/position via `UserDefaults` using "frame autosave name".

#### Controlling Restoration Behavior

```swift
// Disable restoration (good for debug/utility windows)
Window("Debug Console", id: "debug-console") {
    DebugConsoleView()
}
.restorationBehavior(.disabled)

// Enable restoration (default)
.restorationBehavior(.enabled)

// Automatic based on window type
.restorationBehavior(.automatic)
```

**Key stored in UserDefaults:** `"NSWindow Frame {window-id}"`

**Format:** `"x y width height screenX screenY screenWidth screenHeight"`

#### Manual Persistence (if needed)

If automatic persistence doesn't work or you need custom behavior:

```swift
// Save window frame
let frame = window.frame
UserDefaults.standard.set(frame.origin.x, forKey: "DebugWindowX")
UserDefaults.standard.set(frame.origin.y, forKey: "DebugWindowY")
UserDefaults.standard.set(frame.size.width, forKey: "DebugWindowWidth")
UserDefaults.standard.set(frame.size.height, forKey: "DebugWindowHeight")

// Restore window frame
if let x = UserDefaults.standard.value(forKey: "DebugWindowX") as? CGFloat,
   let y = UserDefaults.standard.value(forKey: "DebugWindowY") as? CGFloat,
   let width = UserDefaults.standard.value(forKey: "DebugWindowWidth") as? CGFloat,
   let height = UserDefaults.standard.value(forKey: "DebugWindowHeight") as? CGFloat {
    window.setFrame(CGRect(x: x, y: y, width: width, height: height), display: true)
}
```

### Floating Windows (Always On Top)

#### Modern Approach (macOS 15+)

```swift
Window("Debug Console", id: "debug-console") {
    DebugConsoleView()
}
.windowLevel(.floating)
```

**Available levels:**
- `.normal` (default)
- `.floating` (above normal windows)
- `.modalPanel` (above floating)
- `.popUpMenu` (above modal panels)

#### Legacy Approach (macOS < 15)

Access underlying `NSWindow`:

```swift
// In a ViewModifier or helper
if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-console" }) {
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
}
```

### Window Styles

```swift
// Hide title bar
.windowStyle(.hiddenTitleBar)

// Plain window (no chrome)
.windowStyle(.plain)

// Automatic (default)
.windowStyle(.automatic)
```

**For debug windows:** `.hiddenTitleBar` provides clean, modern look while keeping close/minimize buttons.

### Window Toolbar Styles

```swift
.windowToolbarStyle(.automatic)
.windowToolbarStyle(.expanded)
.windowToolbarStyle(.unified)
.windowToolbarStyle(.unifiedCompact)
```

### Other Useful Modifiers

```swift
// Allow dragging window by background
.windowBackgroundDragBehavior(.enabled)

// Window manager role (macOS 15+)
.windowManagerRole(.associated) // Linked to main window
.windowManagerRole(.panel) // Utility panel behavior
```

---

## Best Practices: Apple's Recommendations

### From WWDC22 "Bring multiple windows to your SwiftUI app"

1. **Use `Window` for single-instance utility windows**
   - Inspector panels
   - Statistics views
   - Debug consoles
   - About windows

2. **Use `WindowGroup` for document-style apps**
   - Text editors
   - Image viewers
   - Any app where users create/open multiple similar items

3. **Each window maintains independent state**
   - Don't share `@State` between windows
   - Use `@Environment` for app-wide state
   - Consider actor-based state management for thread safety

4. **Leverage keyboard shortcuts**
   - Add shortcuts for opening windows
   - Follow macOS conventions (Command-Shift-D for debug)
   - Show shortcuts in Window menu

5. **Consider window lifecycle**
   - Should window restore on app launch?
   - Should it float above other windows?
   - Should multiple instances be allowed?

### From WWDC24 "Tailor macOS windows with SwiftUI"

1. **Use restoration behavior appropriately**
   - Utility windows: `.disabled`
   - Document windows: `.enabled`
   - Let system decide: `.automatic`

2. **Set sensible default sizes**
   - Provide initial size via `.defaultSize()`
   - Allow user resizing unless there's good reason not to
   - Consider screen size when positioning

3. **Use window manager roles (macOS 15+)**
   - `.associated` for windows tied to main window
   - `.panel` for utility panels that should behave like NSPanel

4. **Respect user preferences**
   - Don't force window positions
   - Allow resizing/minimizing
   - Persist user's size/position choices

### SwiftUI vs AppKit Trade-offs

**SwiftUI Advantages:**
- Declarative, easy to read
- Automatic state management
- Cross-platform (with limitations)
- Keyboard shortcut integration

**SwiftUI Limitations:**
- Less fine-grained control
- Some features require AppKit bridging
- `defaultPosition` doesn't always work reliably
- WindowGroup state sharing issues (reported bugs)

**When to drop to NSWindow/NSPanel:**
- Need precise window positioning
- Complex window behaviors (always on top in fullscreen)
- Custom window chrome
- Window-level gesture handling

---

## Code Examples: Practical Patterns

### Example 1: Basic Debug Window

```swift
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            DebugCommands()
        }

        #if DEBUG
        Window("Debug Console", id: "debug-console") {
            DebugConsoleView()
        }
        .defaultSize(width: 800, height: 600)
        .defaultPosition(.bottomTrailing)
        .windowStyle(.hiddenTitleBar)
        .restorationBehavior(.disabled)
        #endif
    }
}

struct DebugCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            #if DEBUG
            Button("Show Debug Console") {
                NSWorkspace.shared.open(URL(string: "vaalin://open-debug-console")!)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            #endif
        }
    }
}
```

### Example 2: Debug Console with Logging

```swift
import SwiftUI
import OSLog

struct DebugConsoleView: View {
    @State private var logEntries: [LogEntry] = []
    @State private var filterText: String = ""
    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "com.vaalin", category: "DebugConsole")

    var filteredEntries: [LogEntry] {
        if filterText.isEmpty {
            return logEntries
        }
        return logEntries.filter { $0.message.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Filter logs...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Button("Clear") {
                    logEntries.removeAll()
                }

                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredEntries) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: logEntries.count) { _, _ in
                    if let lastEntry = logEntries.last {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadLogs()
        }
    }

    private func loadLogs() {
        // Load logs from OSLog or custom logging system
        // This is a simplified example
        logger.info("Debug console opened")
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let subsystem: String
    let category: String
}

enum LogLevel {
    case debug, info, warning, error

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(entry.level.description)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(entry.level.color)
                .frame(width: 60, alignment: .leading)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(entry.level.color)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
```

### Example 3: Floating Debug Panel (macOS 15+)

```swift
@main
struct VaalinApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }

        #if DEBUG
        WindowGroup(id: "floating-debug", for: UUID.self) { $sessionId in
            FloatingDebugPanel(sessionId: sessionId)
        }
        .windowManagerRole(.associated)
        .windowLevel(.floating)
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultWindowPlacement { content, context in
            let displayBounds = context.defaultDisplay.visibleRect
            let size = content.sizeThatFits(.unspecified)
            let position = CGPoint(
                x: displayBounds.maxX - size.width - 20,
                y: displayBounds.maxY - size.height - 20
            )
            return WindowPlacement(position, size: size)
        }
        #endif
    }
}

struct FloatingDebugPanel: View {
    let sessionId: UUID?
    @State private var fps: Double = 60.0
    @State private var memoryUsage: Double = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Stats")
                .font(.headline)

            HStack {
                Text("FPS:")
                Spacer()
                Text(String(format: "%.1f", fps))
                    .foregroundColor(fps >= 55 ? .green : .red)
            }

            HStack {
                Text("Memory:")
                Spacer()
                Text(String(format: "%.0f MB", memoryUsage))
            }

            if let sessionId = sessionId {
                Text("Session: \(sessionId.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .onAppear {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        // Start FPS and memory monitoring
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateStats()
        }
    }

    private func updateStats() {
        // Update FPS and memory usage
        // This would integrate with your actual monitoring code
    }
}
```

### Example 4: Custom NSPanel for Advanced Control

```swift
import SwiftUI
import AppKit

// Custom NSPanel subclass for SwiftUI content
class FloatingPanel<Content: View>: NSPanel {
    init(
        contentRect: NSRect,
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = NSHostingView(rootView: content())
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .clear
    }
}

// ViewModifier for presenting floating panel
struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let panelContent: PanelContent
    @State private var panel: FloatingPanel<PanelContent>?

    init(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> PanelContent
    ) {
        self._isPresented = isPresented
        self.panelContent = content()
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    openPanel()
                } else {
                    closePanel()
                }
            }
    }

    private func openPanel() {
        guard panel == nil else { return }

        let newPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200)
        ) {
            panelContent
        }

        newPanel.center()
        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }

    private func closePanel() {
        panel?.close()
        panel = nil
    }
}

extension View {
    func floatingPanel<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(FloatingPanelModifier(isPresented: isPresented, content: content))
    }
}

// Usage
struct MainView: View {
    @State private var showDebugPanel = false

    var body: some View {
        VStack {
            Button("Toggle Debug Panel") {
                showDebugPanel.toggle()
            }
        }
        .floatingPanel(isPresented: $showDebugPanel) {
            DebugPanelContent()
        }
    }
}
```

---

## macOS HIG: Design Guidelines

### Panels (from Apple HIG)

**Definition:** In a macOS app, a panel typically floats above other open windows, providing supplementary controls, options, or information related to the active window or current selection.

**Key Characteristics:**
- Floats above normal windows
- Provides supplementary functionality
- Related to active window or selection
- Can be dismissed without closing main app

**When to Use Panels:**
- Inspector panels (show properties of selection)
- Color pickers
- Font panels
- Tool palettes
- **Debug/log viewers**

**Design Principles:**
1. **Keep panels focused and lightweight**
   - Single purpose
   - Don't overwhelm with controls
   - Easy to dismiss

2. **Make panels non-modal when possible**
   - User can interact with main window
   - Panel stays visible for quick access
   - Use modals only when blocking is necessary

3. **Position panels thoughtfully**
   - Default to sensible location (not center)
   - Remember user's position
   - Don't obscure main content

4. **Use appropriate window level**
   - Floating for most utility panels
   - Normal for document-like windows
   - Modal only when necessary

### Auxiliary Windows Best Practices

**From "Designing for macOS" (HIG):**

1. **Respect user's workspace**
   - Don't force window positions
   - Remember user preferences
   - Allow rearrangement

2. **Use standard controls**
   - Native close/minimize/zoom buttons
   - Standard keyboard shortcuts
   - Menu integration

3. **Consider full-screen mode**
   - Utility windows should be accessible in full-screen
   - Use `.fullScreenAuxiliary` collection behavior
   - Test with split-view

4. **Visual consistency**
   - Match main app's design language
   - Use system materials (vibrancy)
   - Follow macOS appearance (light/dark mode)

5. **Accessibility**
   - Full keyboard navigation
   - VoiceOver support
   - Adequate contrast and sizing

### Debug Windows Specifically

While Apple HIG doesn't have specific guidance for debug windows, common patterns from Apple's tools:

**From Xcode:**
- Command-Shift-Y: Show/hide debug area
- Command-0: Show/hide navigator
- Floating debug windows stay on top
- Console auto-scrolls to latest
- Clear button prominently placed
- Filter/search prominently available

**From Console.app:**
- Filter bar at top
- Timestamp + level + message layout
- Color coding by log level
- Monospace font for technical content
- Pause/resume logging controls

**Best practices for debug windows:**
- Only available in Debug builds (`#if DEBUG`)
- Keyboard shortcut for quick access
- Auto-scroll to latest logs
- Filtering/searching capability
- Clear logs functionality
- Export logs to file
- Don't restore on app launch (`.restorationBehavior(.disabled)`)
- Can float above main window if desired

---

## Recommendations for Vaalin

### Recommended Architecture

Based on research, here's the optimal approach for Vaalin's debug/log viewer:

#### 1. Use `Window` Scene (Single Instance)

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
        .windowStyle(.hiddenTitleBar) // Clean look, keep controls
        .restorationBehavior(.disabled) // Don't restore debug window
        .windowResizability(.automatic) // Allow flexible resizing
        #endif
    }
}
```

**Rationale:**
- Single instance appropriate for debug console
- No need for multiple debug windows
- Clean, simple API
- Matches Xcode console behavior

#### 2. Add Keyboard Shortcut (Command-Shift-D)

```swift
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
- Command-Shift-D common for debug consoles
- Appears in Window menu automatically
- Easy discoverability

#### 3. Debug Console View Structure

```swift
import SwiftUI
import OSLog
import VaalinCore

struct DebugConsoleView: View {
    @State private var debugLogs: [DebugLogEntry] = []
    @State private var filterText: String = ""
    @State private var selectedLevel: LogLevel? = nil
    @State private var autoScroll: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(
                filterText: $filterText,
                selectedLevel: $selectedLevel,
                autoScroll: $autoScroll,
                onClear: clearLogs,
                onExport: exportLogs,
                onClose: { dismiss() }
            )

            Divider()

            // Log viewer
            LogScrollView(
                logs: filteredLogs,
                autoScroll: autoScroll
            )
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            subscribeToDebugEvents()
        }
    }

    private var filteredLogs: [DebugLogEntry] {
        debugLogs
            .filter { selectedLevel == nil || $0.level == selectedLevel }
            .filter { filterText.isEmpty || $0.message.localizedCaseInsensitiveContains(filterText) }
    }

    private func subscribeToDebugEvents() {
        // Subscribe to EventBus debug events
        // Task {
        //     for await event in await eventBus.subscribe(to: "debug/*") {
        //         handleDebugEvent(event)
        //     }
        // }
    }

    private func clearLogs() {
        debugLogs.removeAll()
    }

    private func exportLogs() {
        // Export to file via NSSavePanel
    }
}
```

#### 4. Integration with Vaalin's EventBus

```swift
// In VaalinCore/EventBus.swift
extension EventBus {
    /// Emit debug event (only in DEBUG builds)
    func emitDebug(level: LogLevel, message: String, subsystem: String = "Vaalin") async {
        #if DEBUG
        await emit(Event(
            name: "debug/log",
            data: [
                "level": level,
                "message": message,
                "subsystem": subsystem,
                "timestamp": Date()
            ]
        ))
        #endif
    }
}

// Usage throughout Vaalin
await eventBus.emitDebug(level: .info, message: "Parser received \(chunk.count) bytes")
await eventBus.emitDebug(level: .warning, message: "Stream buffer at 90% capacity")
await eventBus.emitDebug(level: .error, message: "Failed to parse XML: \(error)")
```

#### 5. Optional: Floating Mode Toggle

For users who want debug console always visible:

```swift
struct DebugConsoleView: View {
    @AppStorage("DebugConsoleFloating") private var isFloating: Bool = false

    var body: some View {
        VStack {
            // Console content...

            Toggle("Keep on Top", isOn: $isFloating)
                .onChange(of: isFloating) { _, newValue in
                    setWindowFloating(newValue)
                }
        }
    }

    private func setWindowFloating(_ floating: Bool) {
        // Access NSWindow and set level
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "vaalin-debug-console" }) {
            window.level = floating ? .floating : .normal
        }
    }
}
```

### Implementation Phases

#### Phase 1: Basic Window (Minimal)
- [x] Research complete
- [ ] Add `Window` scene to VaalinApp
- [ ] Create basic DebugConsoleView
- [ ] Add keyboard shortcut (Cmd-Shift-D)
- [ ] Test opening/closing

**Effort:** 2-3 hours
**Value:** Immediate debug capability

#### Phase 2: Log Collection (Core)
- [ ] EventBus integration for debug events
- [ ] DebugLogEntry model
- [ ] Emit debug events from parser, network, categorizer
- [ ] Display logs in console with filtering

**Effort:** 4-6 hours
**Value:** Actually useful for debugging

#### Phase 3: Advanced Features (Polish)
- [ ] Export logs to file
- [ ] Auto-scroll toggle
- [ ] Color coding by level
- [ ] Performance stats panel
- [ ] Search/regex filtering

**Effort:** 4-6 hours
**Value:** Production-quality tool

#### Phase 4: Optional Enhancements
- [ ] Floating mode toggle
- [ ] Log to OSLog integration
- [ ] Graphing performance metrics
- [ ] Network traffic inspector

**Effort:** 6-10 hours
**Value:** Nice to have

### Testing Considerations

**Unit tests:**
- DebugLogEntry filtering logic
- EventBus debug event emission
- Log export formatting

**Integration tests:**
- Window opens with keyboard shortcut
- Logs appear when debug events emitted
- Clear logs functionality
- Filter/search accuracy

**Manual testing:**
- Window position/size persistence
- Performance with 1000+ log entries
- Keyboard shortcuts work system-wide
- Dark mode appearance
- VoiceOver accessibility

### Performance Budget

**For debug console window:**
- Initial open: < 100ms
- Display 1000 log entries: < 50ms
- Filter 1000 entries: < 10ms
- Auto-scroll update: < 5ms
- Memory overhead: < 10MB

**Note:** Debug features only in DEBUG builds, zero overhead in Release.

---

## Additional Resources

### Apple Documentation
- [Bringing multiple windows to your SwiftUI app](https://developer.apple.com/documentation/swiftui/bringing_multiple_windows_to_your_swiftui_app)
- [Window management in SwiftUI (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10061/)
- [Tailor macOS windows with SwiftUI (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10148/)
- [WindowGroup Documentation](https://developer.apple.com/documentation/swiftui/windowgroup)
- [Window Documentation](https://developer.apple.com/documentation/swiftui/window)
- [macOS HIG: Panels](https://developer.apple.com/design/human-interface-guidelines/panels)
- [macOS HIG: Windows](https://developer.apple.com/design/human-interface-guidelines/components/presentation/windows/)

### Articles & Tutorials
- [Window management in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2022/11/02/window-management-in-swiftui/)
- [Scenes types in a SwiftUI Mac app - Nil Coalescing](https://nilcoalescing.com/blog/ScenesTypesInASwiftUIMacApp/)
- [Presenting secondary windows on macOS with SwiftUI - SerialCoder.dev](https://serialcoder.dev/text-tutorials/swiftui/presenting-secondary-windows-on-macos-with-swiftui/)
- [Creating a floating window using SwiftUI in macOS 15 - Pol Piella](https://www.polpiella.dev/creating-a-floating-window-using-swiftui-in-macos-15)
- [Make a floating panel in SwiftUI for macOS - Cindori](https://cindori.com/developer/floating-panel)
- [Customizing windows in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2024/08/06/customizing-windows-in-swiftui/)

### GitHub Examples
- [LogView](https://github.com/alexejn/LogView) - Modern SwiftUI log viewer
- [SwiftUILogger](https://github.com/0xLeif/SwiftUILogger) - Debug logger view
- [xLogViewer](https://github.com/K3TZR/xLogViewer) - macOS SwiftUI log viewer app
- [SwiftUI-macos-HandleWindow](https://github.com/pd95/SwiftUI-macos-HandleWindow) - Window handling examples
- [SwiftUIWindowStyles](https://github.com/martinlexow/SwiftUIWindowStyles) - Window style showcase

---

## Conclusion

For Vaalin's debug/log viewer, the optimal approach is:

1. **Use `Window` scene** with unique identifier
2. **Keyboard shortcut** (Command-Shift-D) for quick access
3. **Disable restoration** (`.restorationBehavior(.disabled)`)
4. **Default position** bottom-trailing, 900x600
5. **Hidden title bar** for clean look
6. **EventBus integration** for debug events
7. **Optional floating mode** for power users

This provides:
- ✅ Native macOS behavior
- ✅ Minimal code complexity
- ✅ Excellent developer experience
- ✅ Zero overhead in Release builds
- ✅ Extensible for future enhancements

**Next steps:**
1. Implement Phase 1 (basic window)
2. Add to appropriate GitHub issue
3. Test with real debug events
4. Iterate based on usage

---

**Report compiled by:** Claude (SwiftUI macOS Expert)
**For project:** Vaalin - Native macOS GemStone IV Client
**Target platform:** macOS 26+ (Tahoe) with SwiftUI
