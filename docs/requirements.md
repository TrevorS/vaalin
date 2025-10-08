# Vaalin Requirements Document

**Project**: Port of Illthorn MUD client from Electron/TypeScript/Lit to native macOS SwiftUI
**Target Platform**: macOS 26 (Tahoe) with Liquid Glass design language
**Architecture**: Native SwiftUI with Swift Concurrency (async/await, actors)
**Game Protocol**: GemStone IV via Lich 5 detachable client mode

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Functional Requirements by Phase](#functional-requirements-by-phase)
3. [Non-Functional Requirements](#non-functional-requirements)
4. [Technical Specifications](#technical-specifications)
5. [Data Models](#data-models)
6. [Integration Requirements](#integration-requirements)
7. [Testing Requirements](#testing-requirements)
8. [Requirement Dependencies](#requirement-dependencies)

---

## Project Overview

Vaalin is a native macOS application for playing GemStone IV, a text-based MUD. It connects to Lich (a Ruby-based scripting framework) and provides a modern, native UI with streaming XML parsing, HUD panels, command input, and advanced features like item highlighting and macros.

**Key Architectural Decisions:**
- SwiftUI for UI layer with `@Observable` macro for state management (Swift 5.9+) [^1]
- Swift actors for thread-safe concurrent operations [^2]
- Native `XMLParser` for SAX-based XML streaming [^3]
- `NWConnection` from Network.framework for TCP connectivity [^4]
- Liquid Glass design language for chrome elements (panels, toolbars) [^5]
- Xcode Previews as replacement for Storybook component development [^6]

[^1]: https://developer.apple.com/documentation/Observation/Observable()
[^2]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors
[^3]: https://developer.apple.com/documentation/foundation/xmlparser
[^4]: https://developer.apple.com/documentation/network/nwconnection
[^5]: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
[^6]: https://developer.apple.com/documentation/swiftui/previews-in-xcode

---

## Functional Requirements by Phase

### Phase 1: Core Parser & Network with Basic UI Integration

**Purpose**: Establish the foundational parsing and networking layer with immediate visual feedback.

#### FR-1.1: XML Stream Parser (Actor-Based)

**Description**: Implement a thread-safe, stateful XML parser that consumes chunked game data from Lich and produces structured `GameTag` objects.

**Rationale**: The game server sends XML in incomplete chunks over TCP. Parser must maintain state (current stream context) across parse calls.

**Acceptance Criteria**:
- Parser implemented as Swift `actor XMLStreamParser`
- Handles incomplete XML fragments across multiple `parse()` calls
- Maintains stream state: `currentStream` and `inStream` flags persist between calls
- Produces array of `GameTag` structures with nested children
- Handles malformed XML gracefully (logs error, attempts resync on `<prompt>`)
- Supports critical tags: `<pushStream>`, `<popStream>`, `<prompt>`, `<left>`, `<right>`, `<a>`, `<d>`, `<b>`

**Technical Constraints**:
- Use Swift Foundation's `XMLParser` (SAX-based) [^3]
- Parser must be async/await compatible
- Zero-copy parsing where possible for performance

**Dependencies**: None (foundational)

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/parser/saxophone-parser.ts`

---

#### FR-1.2: Lich Detachable Client Connection

**Description**: Establish TCP connection to Lich's detachable client port and stream XML data to parser.

**Acceptance Criteria**:
- Connect to `127.0.0.1:8000` (configurable) using `NWConnection` [^4]
- Handle connection states: connecting, ready, failed, cancelled
- Stream UTF-8 data chunks to parser
- Implement reconnect logic with exponential backoff (0.5s → 8s)
- Send commands to server via same connection
- Graceful disconnect on app termination

**Technical Constraints**:
- Must use `NWConnection` from Network.framework for modern async networking
- Buffer management: handle partial reads, line boundaries

**Dependencies**: FR-1.1 (parser must exist to consume data)

**Reference**: Lich detachable mode runs with `--without-frontend --detachable-client=8000` [^7]

[^7]: https://gswiki.play.net/Lich_(software)

---

#### FR-1.3: Basic Game Tag Rendering (Integration Checkpoint)

**Description**: Minimal SwiftUI view that displays parsed tags as text to verify parser correctness.

**Acceptance Criteria**:
- Simple `GameLogView` that renders `GameTag` array
- Displays text content with basic preset color support
- Auto-scrolls as new content arrives
- Renders `<a>`, `<d>`, `<b>` tags as styled text (no interaction yet)
- Shows connection status (connected/disconnected)

**Purpose**: **Integration checkpoint** - ensures parser and network layer work end-to-end before building complex UI.

**Dependencies**: FR-1.1, FR-1.2

---

#### FR-1.4: GameTag Data Model

**Description**: Swift structures representing parsed game content.

**Acceptance Criteria**:
```swift
struct GameTag: Identifiable {
    let id: UUID
    let name: String          // tag name: "a", "b", "d", ":text", "stream", etc.
    var text: String?         // text content
    var attrs: [String: String] // attributes (exist, noun, cmd, id, etc.)
    var children: [GameTag]   // nested tags
    var state: TagState       // open, closed
}

enum TagState {
    case open, closed
}
```

**Dependencies**: None

---

### Phase 2: Game Log & Command Input (Full Interaction)

**Purpose**: Enable actual gameplay - users can see game output and send commands.

#### FR-2.1: Virtualized Game Log

**Description**: High-performance scrollable game log using SwiftUI with attributed text rendering.

**Acceptance Criteria**:
- Uses `LazyVStack` or `List` for virtualization [^8]
- Renders attributed text with preset colors mapped to theme
- Maintains 10,000 line scrollback buffer (oldest pruned)
- Auto-scrolls when at bottom, pauses when user scrolls up
- Smooth 60fps scrolling
- Supports text selection and copy
- Displays timestamps (toggleable, default OFF)

**Technical Constraints**:
- Must handle 50,000 lines in 2 minutes without frame drops
- Use `AttributedString` for rich text [^9]

**Dependencies**: FR-1.1, FR-1.4

[^8]: https://developer.apple.com/documentation/swiftui/lazyvstack
[^9]: https://developer.apple.com/documentation/foundation/attributedstring

---

#### FR-2.2: Preset-Based Color Rendering

**Description**: Map XML preset IDs to Catppuccin Mocha theme colors for styled game text.

**Rationale**: GemStone IV sends `<preset id="speech">` tags for styling, not ANSI codes. Parser already handles these tags.

**Acceptance Criteria**:
- Parses preset tags via XMLStreamParser (✅ already implemented)
- Maps preset IDs to theme colors:
  - `speech` → Catppuccin Green (#a6e3a1)
  - `whisper` → Catppuccin Teal (#94e2d5)
  - `thought` → Catppuccin Text (#cdd6f4)
  - `damage` → Catppuccin Red (#f38ba8)
  - `heal` → Catppuccin Green (#a6e3a1)
- Themeable: colors defined in JSON config, mapped at runtime
- Bold, italic, underline support via `<b>`, `<i>`, `<u>` tags
- Falls back to default text color for unknown preset IDs

**Technical Constraints**:
- Use AttributedString for styled runs [^9]
- Theme loaded from `Vaalin/Resources/themes/catppuccin-mocha.json`
- Environment-accessible theme manager for view access

**Dependencies**: FR-2.1, FR-6.2

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/styles/_vars.scss` (lines 41-48, preset colors)

[^10]: https://developer.apple.com/documentation/swift/regex

---

#### FR-2.3: Command Input with History ✅ IMPLEMENTED (Issue #27, PR #121)

**Description**: Single-line text input with readline-style navigation and command history.

**Acceptance Criteria**:
- ✅ SwiftUI `TextField` with custom key handling (`VaalinUI/Sources/VaalinUI/Views/CommandInputView.swift`)
- ✅ Up/Down arrows navigate command history (500 item buffer) via `CommandHistory` actor
- ⏸️ Prefix-based history search (deferred to future enhancement)
- ✅ Readline shortcuts:
  - ✅ `Ctrl-A`: Beginning of line
  - ✅ `Ctrl-E`: End of line
  - ✅ `Ctrl-K`: Delete to end
  - ✅ `Ctrl-P`: Previous command (history up)
  - ✅ `Ctrl-N`: Next command (history down)
  - ✅ `Option-B/F`: Word backward/forward
  - ✅ `Option-Delete`: Delete word backward
- ✅ Enter sends command, clears input
- ⏸️ Shift-Enter for multiline (future enhancement, not Phase 2)
- ⏸️ Command echo to game log (future enhancement, requires game log integration)

**Technical Constraints**:
- ✅ Use SwiftUI `.onKeyPress()` for custom key handling [^11]
- ✅ History persisted to JSON on disk (via `CommandHistory.save()`)

**Implementation Details** (Issue #27, PR #121):
- `VaalinUI/Sources/VaalinUI/ViewModels/CommandInputViewModel.swift` - @Observable view model with readline operations
- `VaalinUI/Sources/VaalinUI/Views/CommandInputView.swift` - SwiftUI view with Liquid Glass design
- `VaalinUI/Tests/VaalinUITests/CommandInputViewModelTests.swift` - 49 comprehensive tests (100% coverage)
- Integrated into `AppState` with `commandInputViewModel` and `sendCommand()` method

**Dependencies**: FR-2.1 (echo requires game log)

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/components/command-bar/cli.lit.ts`

[^11]: https://developer.apple.com/documentation/swiftui/view/onkeypress(_:action:)

---

#### FR-2.4: Prompt Display

**Description**: Readonly display of the last server prompt (e.g., `>` or custom prompt).

**Acceptance Criteria**:
- Parses `<prompt>` tags from server
- Displays prompt text above command input
- Updates in real-time as server sends new prompts
- Supports inline status widgets (future enhancement)

**Dependencies**: FR-1.1, FR-2.1

---

#### FR-2.5: Integration Checkpoint - Playable Game

**Purpose**: At end of Phase 2, user can connect to Lich, see game output, and send commands.

**Acceptance Criteria**:
- User can launch app, connect to Lich, play game end-to-end
- Commands echo correctly
- Game log updates in real-time
- No crashes or data loss during 30-minute play session

**Dependencies**: All FR-2.x requirements

---

### Phase 3: HUD Panels (Visual Feedback)

**Purpose**: Display game state (health, items in hands, room exits, etc.) in dedicated panels.

#### FR-3.1: Panel Container System

**Description**: Reusable panel chrome for left/right columns with Liquid Glass styling.

**Acceptance Criteria**:
- SwiftUI view: `PanelContainer(title:content:)`
- Liquid Glass material for panel header [^5]
- Collapse/expand toggle (persistent state)
- Fixed height per panel (configurable in settings)
- Drag handle for reordering (Phase 3: no drag, just static layout)
- Panel registry system: panels declare themselves and can be shown/hidden

**Technical Constraints**:
- Use `.containerBackground(.glass)` or similar Liquid Glass modifiers
- Fixed heights: Hands 140pt, Room 160pt, Vitals 160pt, Injuries 180pt, Spells 180pt

**Dependencies**: None

---

#### FR-3.2: Hands Panel

**Description**: Displays items in left/right hands and prepared spell.

**Acceptance Criteria**:
- Listens for `<left>`, `<right>`, `<spell>` tags via event bus
- Displays: "Left: <item>", "Right: <item>", "Prepared: <spell>"
- Defaults: "Empty", "Empty", "None"
- State persists across reconnects (loaded from JSON)
- Xcode Preview showing various states (empty, items held, spell prepared)

**Technical Constraints**:
- Use `@Observable` view model [^1]
- Subscribe to events via event bus (port from Illthorn's bus system)

**Dependencies**: FR-1.1 (tags), FR-3.1 (panel container)

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/components/session/hands/hands-container.lit.ts`

---

#### FR-3.3: Vitals Panel

**Description**: Displays health, mana, stamina, spirit, mind as progress bars with stance and encumbrance as text.

**Acceptance Criteria**:
- Listens for `<progressBar>` tags: `health`, `mana`, `stamina`, `spirit`, `mindState`, `pbarStance`, `encumlevel`
- Renders as labeled progress bars (5 bars + 2 text fields)
- Progress bar colors: health (red→green gradient), mana (blue), stamina (yellow), spirit (purple), mind (teal)
- Handles indeterminate state (no data yet)
- Calculates percentage from fractions if server sends incorrect value (current bug workaround)
- State persists across reconnects
- Xcode Preview showing various vitals states (full, damaged, empty)

**Technical Constraints**:
- Use SwiftUI `ProgressView` with custom styling [^12]
- `@Observable` view model

**Dependencies**: FR-1.1, FR-3.1

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/components/session/vitals/vitals-container.lit.ts`

[^12]: https://developer.apple.com/documentation/swiftui/progressview

---

#### FR-3.4: Room/Compass Panel

**Description**: Displays current room name and compass rose showing available exits.

**Acceptance Criteria**:
- Listens for `<nav>` or `<compass>` tags (research current tag structure)
- Renders compass rose with 8 directions (N, NE, E, SE, S, SW, W, NW) + up/down/out
- Highlights available exits
- Clickable exits send movement command (e.g., click "north" → sends "north")
- Displays room name/title above compass
- Xcode Preview showing various exit combinations

**Technical Constraints**:
- Custom SwiftUI shape drawing for compass rose
- Accessible: VoiceOver reads available exits

**Dependencies**: FR-1.1, FR-3.1

**Reference**: Examine Illthorn's compass implementation for exit tag structure

---

#### FR-3.5: Injuries Panel

**Description**: Displays character injuries/wounds parsed from dynamic window tags.

**Acceptance Criteria**:
- Listens for `<openDialog>` + `<dialogData>` with injury widgets [^13]
- Parses: `<progressBar>`, `<label>`, `<radio>`, `<skin>` widgets
- Renders injury locations (head, torso, arms, legs) with severity
- Color-coded: minor (yellow), moderate (orange), severe (red), critical (dark red)
- Handles empty state (no injuries)
- Xcode Preview showing injury states

**Technical Constraints**:
- Dynamic window renderer: maps XML widgets → SwiftUI views

**Dependencies**: FR-1.1, FR-3.1

**Reference**: GemStone IV Wiki - Dynamic Windows [^13]

[^13]: https://gswiki.play.net/Lich_XML_Data_and_Tags#Dynamic_Windows

---

#### FR-3.6: Active Spells Panel

**Description**: Displays currently active spells/effects with durations.

**Acceptance Criteria**:
- Listens for `<spell>` tags or `spellfront` stream
- Displays spell name, duration countdown (if available)
- Handles multiple spells
- Removes expired spells
- Xcode Preview showing spell list

**Dependencies**: FR-1.1, FR-3.1

---

#### FR-3.7: Integration Checkpoint - Full HUD While Playing

**Purpose**: All panels update correctly during live gameplay.

**Acceptance Criteria**:
- User plays game for 30 minutes: all panels update accurately
- Vitals reflect damage/healing
- Hands update when items picked up/dropped
- Spells appear/disappear correctly
- No memory leaks or performance degradation

**Dependencies**: All FR-3.x requirements

---

### Phase 4: Streams & Filtering (Content Organization)

**Purpose**: Multi-select stream filtering to organize game output by type.

#### FR-4.1: Stream Registry

**Description**: Configuration-driven stream definitions.

**Acceptance Criteria**:
- JSON config defines streams: `thoughts`, `speech`, `whispers`, `logons`, `expr`, `familiar`
- Each stream has: `id`, `label`, `defaultOn` (bool), `color` (hex), `aliases` (array)
- Unknown stream IDs logged and ignored (not auto-created)
- User can edit stream config via JSON file

**Dependencies**: None

---

#### FR-4.2: Stream Chips (Multi-Select Filter)

**Description**: Horizontal bar of toggleable chips at top of window.

**Acceptance Criteria**:
- Renders chip for each stream (default ON: thoughts, speech, whispers, logons)
- Chips show unread badge count
- Click chip toggles ON/OFF
- Keyboard shortcuts: `Cmd+1` through `Cmd+6` toggle chips 1-6
- Liquid Glass styling for chips bar [^5]
- Chip colors from stream config

**Technical Constraints**:
- Use SwiftUI `Toggle` with custom button style
- Badge implemented with SwiftUI overlay

**Dependencies**: FR-4.1

---

#### FR-4.3: Stream Buffering

**Description**: Parser directs content into stream buffers based on `<pushStream>` tags.

**Acceptance Criteria**:
- Parser tracks current stream via `currentStream` state
- Content between `<pushStream id="X">` and `<popStream>` goes to stream buffer `X`
- Each stream has independent 10,000 line buffer
- Buffers managed by `@Observable` stream store

**Dependencies**: FR-1.1, FR-4.1

---

#### FR-4.4: Mirror Mode Toggle

**Description**: Setting to control whether stream content also appears in main game log.

**Acceptance Criteria**:
- Default: ON (mirror enabled - stream content shows in both stream buffer AND main log)
- Toggle in settings: "Also show stream content in main log"
- When OFF: stream content only in stream buffer
- Per-stream override (future enhancement, not Phase 4)

**Dependencies**: FR-4.1, FR-4.3

---

#### FR-4.5: Stream View

**Description**: When chip is ON, user can view that stream's buffer.

**Acceptance Criteria**:
- Clicking chip with stream ON opens stream view (replaces or overlays game log)
- Stream view shows only that stream's content
- Multiple chips can be ON: union of their content shown
- Back button returns to main game log
- Unread count clears when stream viewed

**Technical Constraints**:
- Use SwiftUI navigation or sheet presentation

**Dependencies**: FR-4.2, FR-4.3

---

#### FR-4.6: Integration Checkpoint - Stream Filtering While Playing

**Purpose**: Streams correctly filter and display during gameplay.

**Acceptance Criteria**:
- Thoughts stream captures tells correctly
- Speech stream captures says/whispers
- Logons stream shows arrivals/departures
- Mirror mode toggle works as expected
- No content loss or duplication

**Dependencies**: All FR-4.x requirements

---

### Phase 5: Advanced Features (Polish)

**Purpose**: Item highlighting, macros, settings persistence, search.

#### FR-5.1: Item Highlighting System

**Description**: Automatic categorization and highlighting of game objects (gems, weapons, armor, etc.) based on noun and name.

**Rationale**: Port Illthorn's XML-based categorization to native Swift using JSON + Swift Regex.

**Acceptance Criteria**:
- JSON data file defines categories: `gem`, `jewelry`, `weapon`, `armor`, `clothing`, `food`, `reagent`, `valuable`, `box`, `junk`
- Each category has:
  - `nounPatterns`: array of Swift regex patterns [^10]
  - `namePatterns`: array of Swift regex patterns
  - `excludePatterns`: array of Swift regex patterns (exclude false positives)
  - `color`: theme color key
  - `displayName`: human-readable name
- Categorization engine:
  ```swift
  actor ItemCategorizer {
      func categorize(noun: String, fullName: String?) async -> Category?
  }
  ```
- Categories applied to `<a exist="..." noun="...">` tags
- Highlighted items rendered with category color in game log
- User can add custom regex patterns via settings (per-category)
- Xcode Preview showing highlighted items in different categories

**Technical Implementation**:
- JSON data file at `Resources/item-categories.json`
- Swift structures:
  ```swift
  struct ItemCategory: Codable {
      let id: String
      let displayName: String
      let nounPatterns: [String]    // regex strings
      let namePatterns: [String]
      let excludePatterns: [String]
      let colorKey: String
  }
  ```
- Compile regex patterns at load time, cache in actor
- Fast lookup via noun dictionary, fallback to pattern matching
- Exclude patterns checked last (override false positives)

**Performance Requirements**:
- Categorization < 1ms per item (average)
- JSON load time < 100ms

**Dependencies**: FR-2.1 (game log rendering), FR-5.4 (settings for custom patterns)

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/components/game-elements/item-highlighting.ts`

**Research Notes**: Swift Regex is highly performant and type-safe [^10]. JSON is more accessible than XML for user editing. Actor-based caching prevents concurrent modification issues.

---

#### FR-5.2: Macro System

**Description**: User-defined keyboard shortcuts that send game commands.

**Acceptance Criteria**:
- JSON config file: `macros.json`
  ```json
  {
    "settings": {
      "enabled": true,
      "echo_commands": true
    },
    "combat": {
      "Cmd+1": "attack",
      "Cmd+Shift+H": "stance defensive;retreat"
    },
    "movement": {
      "F1": "north",
      "F2": "south"
    }
  }
  ```
- Macros organized by category (arbitrary user-defined)
- SwiftUI keyboard handling via `.onKeyPress()` or `NSEvent` monitoring [^11]
- Supports: `Cmd`, `Option`, `Shift`, `Ctrl`, function keys, number keys
- Multi-command macros: `cmd1;cmd2` executes in sequence
- Echo override: `!command` prefix disables echo for that command
- Global enable/disable toggle
- Settings UI to add/edit/remove macros (future enhancement, not Phase 5 - just JSON editing)

**Technical Constraints**:
- Use SwiftUI `.keyboardShortcut()` where possible [^14]
- Fallback to `NSEvent.addLocalMonitorForEvents()` for complex shortcuts [^15]
- Macro manager singleton: validates shortcuts, prevents conflicts

**Dependencies**: FR-2.3 (command input), FR-5.4 (settings persistence)

**Reference Implementation**: `/Users/trevor/Projects/illthorn/src/frontend/macros/manager.ts`

[^14]: https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)
[^15]: https://developer.apple.com/documentation/appkit/nsevent/1534971-addlocalmonitorforevents

---

#### FR-5.3: Search in Game Log

**Description**: Find text in game log with highlighting and next/prev navigation.

**Acceptance Criteria**:
- Keyboard shortcut: `Cmd+F` opens search overlay
- Search field with case-insensitive matching (toggle for case-sensitive)
- Highlights all matches in log
- Next/Prev buttons (keyboard: `Cmd+G`, `Cmd+Shift+G`)
- Match count display: "3 of 47 matches"
- Scrolls log to current match
- ESC or close button dismisses search

**Technical Constraints**:
- Use SwiftUI `.searchable()` modifier [^16]
- AttributedString for match highlighting

**Dependencies**: FR-2.1 (game log)

[^16]: https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:)

---

#### FR-5.4: Settings Persistence

**Description**: JSON-based settings storage for all app configuration.

**Acceptance Criteria**:
- Settings stored in `~/Library/Application Support/Vaalin/settings.json`
- Structure:
  ```json
  {
    "layout": {
      "left": ["hands", "room", "vitals"],
      "right": ["injuries", "spells"],
      "colWidth": {"left": 280, "right": 280},
      "streamsHeight": 112,
      "collapsed": {"hands": false}
    },
    "streams": {
      "mirrorFilteredToMain": true,
      "timestamps": {
        "gameLog": false,
        "perStream": {"thoughts": false}
      }
    },
    "input": {
      "sendOnEnter": true,
      "echoPrefix": "›"
    },
    "theme": {
      "name": "catppuccin-mocha",
      "ansiMap": "default"
    },
    "network": {
      "host": "127.0.0.1",
      "port": 8000
    }
  }
  ```
- Codable Swift structures for type-safe encoding/decoding
- Settings manager singleton: `SettingsManager` actor for thread-safe access
- Auto-save on changes (debounced 500ms)
- Graceful handling of missing/corrupt JSON (fallback to defaults)

**Technical Constraints**:
- Use `FileManager` for file I/O [^17]
- `Codable` protocol for JSON serialization [^18]

**Dependencies**: None (foundational)

[^17]: https://developer.apple.com/documentation/foundation/filemanager
[^18]: https://developer.apple.com/documentation/swift/codable

---

#### FR-5.5: Integration Checkpoint - Advanced Features Working

**Purpose**: Item highlighting, macros, search all functional during gameplay.

**Acceptance Criteria**:
- Items correctly highlighted by category during exploration
- Macros execute commands correctly
- Search finds text in log
- Settings persist across app restarts
- No performance degradation

**Dependencies**: All FR-5.x requirements

---

### Phase 6: Polish & Distribution

**Purpose**: Final touches, theming, accessibility, packaging.

#### FR-6.1: Liquid Glass Materials

**Description**: Apply Liquid Glass design language to panel headers, toolbars, and chrome.

**Acceptance Criteria**:
- Panel headers use `.containerBackground(.glass)` or equivalent [^5]
- Streams bar uses glass material
- Command input background uses subtle glass effect
- Contrast ratios meet accessibility guidelines (4.5:1 minimum) [^19]
- Glass intensity adjustable in settings (future enhancement)

**Technical Constraints**:
- Requires macOS 26 APIs
- Test on both light and dark system appearances

**Dependencies**: All UI phases (FR-3.x, FR-4.x)

[^19]: https://developer.apple.com/design/human-interface-guidelines/accessibility

---

#### FR-6.2: Catppuccin Mocha Theme

**Description**: Default color theme using Catppuccin Mocha palette with preset ID mappings.

**Acceptance Criteria**:
- Color tokens defined in theme JSON (26 Catppuccin colors)
- Maps to SwiftUI semantic colors
- Preset IDs mapped to Catppuccin palette [^20]:
  - Speech/communication: greens, teals
  - Damage/danger: reds, maroons
  - Healing: greens
  - Thoughts: text colors
- Item categories mapped (weapons→red, gems→yellow, etc.)
- User can customize via theme JSON editing
- Theme applied consistently across all views

**Reference**: Catppuccin Mocha palette [^20]

**Dependencies**: FR-5.4 (settings for theme config)

[^20]: https://github.com/catppuccin/catppuccin

---

#### FR-6.3: Accessibility

**Description**: VoiceOver support, keyboard navigation, high contrast mode.

**Acceptance Criteria**:
- All interactive elements have accessibility labels
- Full keyboard navigation (tab order logical)
- VoiceOver announces panel updates (vitals, hands, etc.)
- Supports system high contrast mode
- Font size respects system text size settings
- Color-blind safe color choices for highlights

**Technical Constraints**:
- Use SwiftUI accessibility modifiers [^21]
- Test with VoiceOver enabled

**Dependencies**: All UI phases

[^21]: https://developer.apple.com/documentation/swiftui/view-accessibility

---

#### FR-6.4: DMG Packaging

**Description**: Distributable .dmg file for direct download.

**Acceptance Criteria**:
- Codesigned with Apple Developer ID
- Notarized by Apple
- DMG includes:
  - Vaalin.app
  - Applications folder symlink
  - Background image with drag instructions
  - EULA/README
- Install process: drag to Applications
- First launch: Gatekeeper allows without warnings

**Technical Constraints**:
- Use `create-dmg` or manual `hdiutil` [^22]
- Xcode Archive → Export for distribution

**Dependencies**: All features complete

[^22]: https://github.com/create-dmg/create-dmg

---

#### FR-6.5: Session Logging

**Description**: Optional logging of game sessions to disk.

**Acceptance Criteria**:
- User can enable logging in settings
- Log formats:
  - Plain text: `YYYY-MM-DD-HH-MM-SS.log`
  - JSONL: `YYYY-MM-DD-HH-MM-SS.jsonl` with structured data
- Rotation: keep last 30 days (configurable)
- No PII logged (game content only)
- Log location: `~/Library/Application Support/Vaalin/logs/`

**Dependencies**: FR-5.4 (settings)

---

## Non-Functional Requirements

### NFR-1: Performance

**NFR-1.1: Rendering Performance**
- Maintain 60fps during normal gameplay
- Game log scrolling: < 16ms frame time (60fps)
- Parser throughput: > 10,000 lines/minute
- Handle 50,000 lines in 2 minutes without frame drops

**NFR-1.2: Memory Management**
- Scrollback buffer limit: 10,000 lines per buffer
- Prune oldest entries when limit exceeded
- No memory leaks over 8-hour session
- Peak memory usage < 500MB

**NFR-1.3: Startup Time**
- Cold launch: < 2 seconds to window display
- Hot launch: < 500ms

---

### NFR-2: Reliability

**NFR-2.1: Error Handling**
- Parser errors logged, app continues
- Network errors trigger reconnect
- Malformed JSON settings: fallback to defaults, log warning
- Crash recovery: restore last session state

**NFR-2.2: Data Integrity**
- Settings writes atomic (temp file + rename)
- No data loss on unexpected termination
- Command history persisted immediately after send

---

### NFR-3: Maintainability

**NFR-3.1: Code Quality**
- Swift API Design Guidelines [^23]
- SwiftLint configuration for style enforcement [^24]
- Modular architecture: UI, Parser, Network, Models as separate targets (Swift Package Manager)
- All public APIs documented with DocC comments [^25]

**NFR-3.2: Testing**
- Unit test coverage: > 80% for business logic (parser, categorizer, settings manager)
- UI tests: critical paths (connect, send command, receive output)
- Use Swift Testing framework [^26]

**NFR-3.3: Documentation**
- README with build instructions
- DocC documentation for all public APIs
- Xcode Previews for all views (minimum 2 states per view)

[^23]: https://www.swift.org/documentation/api-design-guidelines/
[^24]: https://github.com/realm/SwiftLint
[^25]: https://developer.apple.com/documentation/docc
[^26]: https://developer.apple.com/documentation/testing

---

### NFR-4: Security

**NFR-4.1: Network Security**
- No TLS required (Lich is localhost only)
- Validate port range: 1024-65535
- No arbitrary code execution from game data

**NFR-4.2: Sandboxing**
- Prepared for App Store sandbox (not required for Phase 6 DMG)
- Network entitlement: localhost connections only
- File access: limited to app support directory

---

### NFR-5: Usability

**NFR-5.1: Onboarding**
- First launch: helpful dialog explaining Lich connection
- Default port (8000) pre-filled
- Clear error messages for connection failures

**NFR-5.2: Discoverability**
- Keyboard shortcuts shown in menus
- Tooltips on panel collapse buttons
- Settings organized by category

---

## Technical Specifications

### State Management Architecture

**Observable Macro Pattern** [^1]

All view models use `@Observable` macro (Swift 5.9+):

```swift
@Observable
final class GameLogViewModel {
    var messages: [GameTag] = []
    var scrollToBottom: Bool = true
    var timestamps: Bool = false

    func appendMessage(_ tag: GameTag) {
        messages.append(tag)
        if messages.count > 10000 {
            messages.removeFirst()
        }
    }
}
```

**Event Bus Pattern**

Port Illthorn's event bus for cross-component communication:

```swift
actor EventBus {
    typealias EventHandler = (Any) async -> Void

    private var handlers: [String: [EventHandler]] = [:]

    func subscribe(_ event: String, handler: @escaping EventHandler) {
        handlers[event, default: []].append(handler)
    }

    func publish(_ event: String, data: Any) async {
        for handler in handlers[event, default: []] {
            await handler(data)
        }
    }
}
```

Events:
- `metadata/left`, `metadata/right`, `metadata/spell` → Hands panel
- `metadata/progressBar/health`, etc. → Vitals panel
- `metadata/compass` → Compass panel
- `stream/<id>` → Stream buffers

---

### Project Structure

```
Vaalin/
├── Vaalin/                    # Main app target
│   ├── VaalinApp.swift        # @main entry point
│   ├── Views/                 # SwiftUI views
│   │   ├── GameLogView.swift
│   │   ├── CommandInputView.swift
│   │   ├── Panels/
│   │   │   ├── HandsPanel.swift
│   │   │   ├── VitalsPanel.swift
│   │   │   └── ...
│   │   └── StreamsBarView.swift
│   ├── ViewModels/            # @Observable models
│   │   ├── GameLogViewModel.swift
│   │   └── ...
│   └── Resources/
│       ├── item-categories.json
│       └── themes/
├── VaalinParser/              # Swift Package: XML parsing
│   ├── XMLStreamParser.swift  # actor
│   ├── GameTag.swift
│   └── TagRenderer.swift
├── VaalinNetwork/             # Swift Package: Lich connection
│   ├── LichConnection.swift   # NWConnection wrapper
│   └── ConnectionState.swift
├── VaalinCore/                # Swift Package: shared models
│   ├── EventBus.swift
│   ├── Settings.swift
│   ├── ItemCategorizer.swift
│   └── MacroManager.swift
└── VaalinTests/               # Tests
    ├── ParserTests.swift
    ├── CategorizerTests.swift
    └── ...
```

---

### XML Parsing Details

**Parser State Machine**

```swift
actor XMLStreamParser: NSObject, XMLParserDelegate {
    // Persistent stream state
    private var currentStream: String?
    private var inStream: Bool = false

    // Per-parse state
    private var tagStack: [GameTag] = []
    private var completed: [GameTag] = []

    func parse(_ chunk: String) async -> [GameTag] {
        // Create XMLParser instance
        // Parse chunk (may be incomplete)
        // Return completed tags
        // Maintain currentStream/inStream across calls
    }

    // XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, ...) {
        if elementName == "pushStream" {
            currentStream = attributes["id"]
            inStream = true
        }
        // ... handle other tags
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, ...) {
        if elementName == "popStream" {
            currentStream = nil
            inStream = false
        }
        // ... close tags
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Append text to current tag
    }
}
```

**Tag Types**:
- Content tags: `<a>`, `<b>`, `<d>`, `:text`, `<preset>`, `<style>`, `<output>`
- Metadata tags: `<stream>`, `<prompt>`, `<left>`, `<right>`, `<spell>`, `<progressBar>`, `<nav>`, `<compass>`, `<inv>`
- Stream control: `<pushStream>`, `<popStream>`, `<clearStream>`

---

### Network Layer

**NWConnection Wrapper**

```swift
actor LichConnection {
    private var connection: NWConnection?
    private var state: ConnectionState = .disconnected

    func connect(host: String, port: UInt16) async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        connection = NWConnection(to: endpoint, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] newState in
            Task { await self?.handleState(newState) }
        }

        connection?.start(queue: .main)

        // Start receiving data
        await receiveData()
    }

    private func receiveData() async {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let text = String(data: data, encoding: .utf8) ?? ""
                Task {
                    await self?.parser.parse(text)
                }
            }
            if !isComplete {
                Task { await self?.receiveData() }
            }
        }
    }

    func send(_ command: String) async throws {
        let data = "\(command)\n".data(using: .utf8)!
        connection?.send(content: data, completion: .idempotent)
    }
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}
```

---

### Item Categorization Engine

**Data Model**

```swift
struct ItemCategory: Codable, Identifiable {
    let id: String
    let displayName: String
    let nounPatterns: [String]
    let namePatterns: [String]
    let excludePatterns: [String]
    let colorKey: String

    // Compiled regex (not encoded)
    var nounRegex: [Regex<AnyRegexOutput>] = []
    var nameRegex: [Regex<AnyRegexOutput>] = []
    var excludeRegex: [Regex<AnyRegexOutput>] = []
}
```

**Categorization Algorithm**

```swift
actor ItemCategorizer {
    private var categories: [ItemCategory] = []
    private var nounLookup: [String: String] = [:] // noun -> category ID

    func load() async throws {
        // Load JSON, compile regexes, build lookup table
    }

    func categorize(noun: String, fullName: String?) async -> ItemCategory? {
        // 1. Fast noun lookup
        if let categoryID = nounLookup[noun.lowercased()] {
            return categories.first { $0.id == categoryID }
        }

        // 2. Pattern matching
        for category in categories {
            // Try noun patterns
            for pattern in category.nounRegex {
                if noun.contains(pattern) {
                    if !isExcluded(fullName ?? noun, category) {
                        return category
                    }
                }
            }

            // Try name patterns
            if let name = fullName {
                for pattern in category.nameRegex {
                    if name.contains(pattern) {
                        if !isExcluded(name, category) {
                            return category
                        }
                    }
                }
            }
        }

        return nil
    }

    private func isExcluded(_ text: String, _ category: ItemCategory) -> Bool {
        category.excludeRegex.contains { text.contains($0) }
    }
}
```

**Data File Structure** (`item-categories.json`):

```json
{
  "categories": [
    {
      "id": "gem",
      "displayName": "Gem",
      "nounPatterns": ["gem", "diamond", "ruby", "emerald", "sapphire"],
      "namePatterns": ["\\bstar \\w+ gem\\b"],
      "excludePatterns": ["fake", "glass"],
      "colorKey": "item-gem"
    },
    {
      "id": "weapon",
      "displayName": "Weapon",
      "nounPatterns": ["sword", "dagger", "axe", "mace", "bow"],
      "namePatterns": [],
      "excludePatterns": ["wooden sword"],
      "colorKey": "item-weapon"
    }
  ]
}
```

**Performance Optimization**:
- Precompile all regexes at load time
- Build noun lookup dictionary for O(1) common cases
- Pattern matching only for rare/complex cases
- Cache recent categorizations (LRU cache, 1000 entries)

---

### Macro System

**Key Handling**

```swift
struct MacroManager {
    private var bindings: [String: String] = [:] // "Cmd+1" -> "attack"

    func load() async throws {
        // Load macros.json
    }

    func handle(key: KeyEquivalent, modifiers: EventModifiers) async -> String? {
        let shortcut = formatShortcut(key, modifiers)
        return bindings[shortcut]
    }
}

// In SwiftUI view:
.onKeyPress { press in
    if let command = await macroManager.handle(key: press.key, modifiers: press.modifiers) {
        await sendCommand(command)
        return .handled
    }
    return .ignored
}
```

---

## Data Models

### Core Data Structures

```swift
// GameTag: Parsed XML element
struct GameTag: Identifiable, Equatable {
    let id: UUID
    let name: String
    var text: String?
    var attrs: [String: String]
    var children: [GameTag]
    var state: TagState

    enum TagState {
        case open, closed
    }
}

// Message: Rendered game log entry
struct Message: Identifiable {
    let id: UUID
    let timestamp: Date
    let attributedText: AttributedString
    let tags: [GameTag]
    let streamID: String?
}

// Settings: App configuration
struct Settings: Codable {
    var layout: Layout
    var streams: StreamSettings
    var input: InputSettings
    var theme: ThemeSettings
    var network: NetworkSettings

    struct Layout: Codable {
        var left: [String]
        var right: [String]
        var colWidth: [String: CGFloat]
        var streamsHeight: CGFloat
        var collapsed: [String: Bool]
    }

    struct StreamSettings: Codable {
        var mirrorFilteredToMain: Bool
        var timestamps: TimestampSettings

        struct TimestampSettings: Codable {
            var gameLog: Bool
            var perStream: [String: Bool]
        }
    }

    struct InputSettings: Codable {
        var sendOnEnter: Bool
        var echoPrefix: String
    }

    struct ThemeSettings: Codable {
        var name: String
        var ansiMap: String
    }

    struct NetworkSettings: Codable {
        var host: String
        var port: UInt16
    }
}
```

---

## Integration Requirements

### Integration Milestones

**Phase 1 Integration**: Basic end-to-end flow
- Connect to Lich → Parse XML → Display in basic view
- User sees raw game output
- **Success Criteria**: Can log in and see text

**Phase 2 Integration**: Playable game
- Full game log + command input + echo
- **Success Criteria**: Can play game for 30 minutes

**Phase 3 Integration**: HUD panels update live
- All panels reflect game state during play
- **Success Criteria**: Panels accurate over 30-minute session

**Phase 4 Integration**: Stream filtering works
- Streams correctly filter and buffer
- **Success Criteria**: No content loss, correct filtering

**Phase 5 Integration**: Advanced features functional
- Highlighting, macros, search all work together
- **Success Criteria**: No feature conflicts or performance issues

**Phase 6 Integration**: Complete app polish
- Theming, accessibility, distribution
- **Success Criteria**: App feels native and polished

---

## Testing Requirements

### Unit Tests (Swift Testing Framework)

**Parser Tests**:
- `test_parseSimpleTag()`
- `test_parseNestedTags()`
- `test_parseIncompleteXML()`
- `test_streamStatePersistedAcrossCalls()`
- `test_malformedXMLRecovery()`

**Categorizer Tests**:
- `test_categorizationByNoun()`
- `test_categorizationByName()`
- `test_excludePatterns()`
- `test_performanceWithLargeDataset()`

**Settings Tests**:
- `test_loadSettings()`
- `test_saveSettings()`
- `test_corruptJSONFallback()`

**Macro Tests**:
- `test_loadMacros()`
- `test_executeMacro()`
- `test_multiCommandMacro()`

### UI Tests

- `test_connectToLich()`
- `test_sendCommand()`
- `test_gameLogScrolling()`
- `test_panelCollapseExpand()`
- `test_streamChipToggle()`

### Performance Tests

- `test_parsePerformance()` - Assert < 100ms for 10,000 lines
- `test_renderPerformance()` - Assert 60fps during scrolling
- `test_memoryUsage()` - Assert no leaks over 8-hour session

---

## Requirement Dependencies

### Dependency Graph

```
FR-1.1 (Parser)
  ├─> FR-1.3 (Basic Rendering)
  ├─> FR-2.1 (Game Log)
  ├─> FR-3.2 (Hands)
  ├─> FR-3.3 (Vitals)
  └─> FR-4.3 (Stream Buffering)

FR-1.2 (Network)
  └─> FR-1.3 (Basic Rendering)

FR-2.1 (Game Log)
  ├─> FR-2.2 (Preset Colors)
  └─> FR-5.3 (Search)

FR-2.3 (Command Input)
  └─> FR-5.2 (Macros)

FR-3.1 (Panel Container)
  ├─> FR-3.2 (Hands)
  ├─> FR-3.3 (Vitals)
  ├─> FR-3.4 (Compass)
  ├─> FR-3.5 (Injuries)
  └─> FR-3.6 (Spells)

FR-5.4 (Settings)
  ├─> FR-5.1 (Item Highlighting)
  ├─> FR-5.2 (Macros)
  └─> FR-6.2 (Theme)
```

### Critical Path

1. **Parser + Network** (FR-1.1, FR-1.2) - Nothing works without this
2. **Basic UI** (FR-1.3) - Verify data flow
3. **Game Log + Input** (FR-2.1, FR-2.3) - Make game playable
4. **Settings** (FR-5.4) - Required for persistence
5. **Panels** (FR-3.x) - Progressive enhancement
6. **Advanced Features** (FR-5.x) - Polish

---

## Glossary

- **Lich**: Ruby-based scripting framework for GemStone IV, acts as proxy between game server and front-end client
- **MUD**: Multi-User Dungeon, text-based multiplayer game
- **SAX**: Simple API for XML, event-driven parsing
- **GameTag**: Swift structure representing parsed XML element
- **Stream**: Named channel for game messages (e.g., "thoughts", "combat")
- **Panel**: Fixed-height UI component displaying specific game state (vitals, hands, etc.)
- **Liquid Glass**: macOS 26 design language featuring translucent, glassy materials
- **@Observable**: Swift 5.9+ macro for declarative state management

---

## References

All citations are inline with footnotes linking to official documentation. Key references:

- Swift Evolution Proposals (concurrency, regex, observation)
- Apple Developer Documentation (SwiftUI, Network.framework, XMLParser)
- GemStone IV Wiki (XML protocol, Lich integration)
- Catppuccin Theme Specification
- Swift API Design Guidelines
- macOS Human Interface Guidelines

---

**Document Version**: 1.0
**Last Updated**: 2025-10-04
**Status**: Ready for Implementation
