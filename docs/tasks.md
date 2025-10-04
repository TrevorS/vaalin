# Vaalin Implementation Tasks

**Source**: `docs/requirements.md`
**Last Updated**: 2025-10-04
**Project**: Native macOS SwiftUI MUD client for GemStone IV via Lich 5

---

## Table of Contents

1. [Foundational Tasks](#foundational-tasks)
2. [Phase 1: Core Parser & Network](#phase-1-core-parser--network)
3. [Phase 2: Game Log & Command Input](#phase-2-game-log--command-input)
4. [Phase 3: HUD Panels](#phase-3-hud-panels)
5. [Phase 4: Streams & Filtering](#phase-4-streams--filtering)
6. [Phase 5: Advanced Features](#phase-5-advanced-features)
7. [Phase 6: Polish & Distribution](#phase-6-polish--distribution)
8. [Testing Tasks](#testing-tasks)
9. [Task Dependencies](#task-dependencies)

---

## Foundational Tasks

### TASK-F01: Create Xcode Project Structure

**Description**: Initialize Xcode project with proper Swift Package Manager structure for modular architecture.

**Acceptance Criteria**:
- Xcode project created targeting macOS 26+
- Swift 5.9+ with concurrency enabled
- Four Swift package targets created:
  - `VaalinParser` (XML parsing)
  - `VaalinNetwork` (Lich connection)
  - `VaalinCore` (shared models, event bus)
  - `Vaalin` (main app target)
- SwiftLint configuration added
- `.gitignore` configured for Xcode

**Implementation Approach**: New project setup

**Required Components**:
- `Vaalin.xcodeproj`
- `Package.swift` (for package targets)
- `.swiftlint.yml`
- `Vaalin/VaalinApp.swift` (main entry point)

**Test Requirements**: N/A (foundational setup)

**Configuration Changes**:
- Target SDK: macOS 26
- Swift version: 5.9+
- Enable strict concurrency checking

**Dependencies**: None

---

### TASK-F02: Define Core GameTag Data Model

**Description**: Implement the foundational `GameTag` structure representing parsed XML elements.

**Acceptance Criteria**:
- `GameTag` struct created with all required fields
- Conforms to `Identifiable`, `Equatable`
- `TagState` enum defined (open/closed)
- Supports nested children array
- Attributes stored as dictionary

**Implementation Approach**: TDD - write tests first for GameTag equality, ID uniqueness, nested structures

**Required Components**:
- `VaalinParser/Sources/GameTag.swift`
- `VaalinParser/Tests/GameTagTests.swift`

**Test Requirements**:
```swift
test_gameTagEquality()
test_gameTagIdentifiability()
test_nestedTagStructure()
test_attributeStorage()
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:121-134`

---

### TASK-F03: Define Settings Data Model

**Description**: Implement Codable settings structures for app configuration persistence.

**Acceptance Criteria**:
- `Settings` struct with nested sub-structs (Layout, StreamSettings, InputSettings, ThemeSettings, NetworkSettings)
- All structs conform to `Codable`
- Default values provided for all settings
- Supports JSON encoding/decoding

**Implementation Approach**: TDD - test encoding/decoding, defaults

**Required Components**:
- `VaalinCore/Sources/Settings.swift`
- `VaalinCore/Tests/SettingsTests.swift`

**Test Requirements**:
```swift
test_settingsEncoding()
test_settingsDecoding()
test_defaultValues()
test_partialDecoding() // missing fields use defaults
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:1245-1285`

---

### TASK-F04: Implement EventBus Actor

**Description**: Create thread-safe event bus for cross-component communication using Swift actors.

**Acceptance Criteria**:
- `EventBus` implemented as Swift actor
- Subscribe/publish pattern with type-safe handlers
- Async event handling
- Support for multiple handlers per event
- Unsubscribe capability

**Implementation Approach**: TDD - test subscription, publishing, handler invocation order

**Required Components**:
- `VaalinCore/Sources/EventBus.swift`
- `VaalinCore/Tests/EventBusTests.swift`

**Test Requirements**:
```swift
test_subscribeAndPublish()
test_multipleHandlersSameEvent()
test_asyncHandlerExecution()
test_unsubscribe()
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:908-927`

---

### TASK-F05: Create Message Data Model

**Description**: Define rendered game log entry structure with attributed text.

**Acceptance Criteria**:
- `Message` struct with UUID, timestamp, AttributedString, tags array, stream ID
- Conforms to `Identifiable`
- Supports initialization from GameTag array

**Implementation Approach**: New data model

**Required Components**:
- `VaalinCore/Sources/Message.swift`

**Test Requirements**: Basic initialization tests

**Dependencies**: TASK-F02

**Reference**: `requirements.md:1236-1243`

---

## Phase 1: Core Parser & Network

### TASK-P1-01: Implement XMLStreamParser Actor Skeleton

**Description**: Create actor-based XML parser with state management for chunked parsing.

**Acceptance Criteria**:
- `XMLStreamParser` actor created with NSObject/XMLParserDelegate conformance
- Persistent state fields: `currentStream`, `inStream`
- Per-parse state: `tagStack`, `completed` arrays
- `parse(_ chunk: String) async -> [GameTag]` method signature
- Async/await compatible

**Implementation Approach**: TDD - start with simple test cases

**Required Components**:
- `VaalinParser/Sources/XMLStreamParser.swift`
- `VaalinParser/Tests/XMLStreamParserTests.swift`

**Test Requirements**:
```swift
test_parserInitialization()
test_emptyChunkReturnsNoTags()
```

**Dependencies**: TASK-F02

**Reference**: `requirements.md:50-72`, `requirements.md:981-1020`

---

### TASK-P1-02: Implement Simple Tag Parsing

**Description**: Parse basic XML tags without nesting (`:text`, `<prompt>`, `<left>`, `<right>`).

**Acceptance Criteria**:
- Parser handles simple open/close tags
- Text content extracted correctly
- Attributes stored in GameTag.attrs dictionary
- Self-closing tags supported

**Implementation Approach**: TDD - incrementally add tag types

**Required Components**:
- Update `VaalinParser/Sources/XMLStreamParser.swift`
- Add tests in `XMLStreamParserTests.swift`

**Test Requirements**:
```swift
test_parseTextNode()
test_parsePromptTag()
test_parseLeftHandTag()
test_parseRightHandTag()
test_parseAttributes()
test_parseSelfClosingTag()
```

**Dependencies**: TASK-P1-01

**Reference**: Implementation reference at `/Users/trevor/Projects/illthorn/src/frontend/parser/saxophone-parser.ts`

---

### TASK-P1-03: Implement Nested Tag Parsing

**Description**: Support nested tag structures (children array).

**Acceptance Criteria**:
- Tag stack correctly manages open tags
- Children added to parent tag
- Nested depth unlimited
- Tag closure closes correct parent

**Implementation Approach**: TDD - test various nesting scenarios

**Required Components**:
- Update `XMLStreamParser.swift` delegate methods
- Add nested tag tests

**Test Requirements**:
```swift
test_parseNestedTags()
test_deepNesting()
test_multipleSiblings()
test_mixedNesting()
```

**Dependencies**: TASK-P1-02

---

### TASK-P1-04: Implement Chunked/Incomplete XML Handling

**Description**: Parse XML fragments that arrive across multiple chunks.

**Acceptance Criteria**:
- Parser maintains state between `parse()` calls
- Incomplete tags buffered until complete
- Stream state (`currentStream`, `inStream`) persists
- Handles mid-tag breaks, mid-attribute breaks

**Implementation Approach**: TDD - test chunk boundaries

**Required Components**:
- Add buffering logic to `XMLStreamParser`
- Add chunking tests

**Test Requirements**:
```swift
test_parseIncompleteTag()
test_parseTagAcrossChunks()
test_parseAttributeAcrossChunks()
test_streamStatePersistsAcrossChunks()
```

**Dependencies**: TASK-P1-03

**Reference**: Critical for streaming protocol

---

### TASK-P1-05: Implement Stream Control Tags

**Description**: Handle `<pushStream>`, `<popStream>`, `<clearStream>` tags for content routing.

**Acceptance Criteria**:
- `<pushStream id="X">` sets `currentStream` to X, `inStream = true`
- `<popStream>` resets `currentStream` to nil, `inStream = false`
- Stream state persists across parse calls
- Tags between push/pop marked with correct stream ID

**Implementation Approach**: TDD - test stream state transitions

**Required Components**:
- Update `XMLStreamParser` delegate methods
- Add stream control tests

**Test Requirements**:
```swift
test_pushStream()
test_popStream()
test_streamStateAcrossCalls()
test_nestedStreams() // edge case
```

**Dependencies**: TASK-P1-04

**Reference**: `requirements.md:1000-1012`

---

### TASK-P1-06: Implement Critical Game Tags

**Description**: Add support for critical game tags: `<a>`, `<b>`, `<d>`, `<preset>`, `<style>`, `<output>`.

**Acceptance Criteria**:
- All critical tags parsed with attributes
- `<a exist="..." noun="...">` captures item data
- `<b>`, `<d>` mark styled text
- `<preset>`, `<style>`, `<output>` handled

**Implementation Approach**: Extend existing parsing logic, add tests per tag

**Required Components**:
- Update `XMLStreamParser.swift`
- Add tag-specific tests

**Test Requirements**:
```swift
test_parseAnchorTag()
test_parseBoldTag()
test_parseDialogTag()
test_parsePresetTag()
```

**Dependencies**: TASK-P1-05

**Reference**: `requirements.md:1023-1025`

---

### TASK-P1-07: Implement Malformed XML Recovery

**Description**: Gracefully handle parsing errors without crashing.

**Acceptance Criteria**:
- Parser logs errors on malformed XML
- Attempts resync on next `<prompt>` tag
- Returns completed tags before error
- Doesn't crash on invalid input

**Implementation Approach**: Add error handling in delegate methods

**Required Components**:
- Update `XMLStreamParser.swift` with error logging
- Add malformed XML tests

**Test Requirements**:
```swift
test_malformedXMLLogsError()
test_resyncOnPrompt()
test_continuesAfterError()
```

**Dependencies**: TASK-P1-06

**Reference**: `requirements.md:61`

---

### TASK-P1-08: Implement LichConnection Actor

**Description**: Create TCP connection to Lich using NWConnection from Network.framework.

**Acceptance Criteria**:
- `LichConnection` actor created
- `connect(host: String, port: UInt16) async throws` method
- Connection state tracking: disconnected, connecting, connected, failed
- State update handler implemented
- Async/await compatible

**Implementation Approach**: Network programming, state machine

**Required Components**:
- `VaalinNetwork/Sources/LichConnection.swift`
- `VaalinNetwork/Sources/ConnectionState.swift`
- `VaalinNetwork/Tests/LichConnectionTests.swift`

**Test Requirements**:
```swift
test_connectionStateTransitions()
test_connectToLocalhost()
test_connectionFailure()
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:75-96`, `requirements.md:1032-1081`

---

### TASK-P1-09: Implement Data Reception in LichConnection

**Description**: Stream UTF-8 data chunks from TCP connection to parser.

**Acceptance Criteria**:
- `receiveData()` method implemented with recursive receive
- Handles partial reads (minimumIncompleteLength: 1, maximumLength: 65536)
- UTF-8 decoding of received data
- Data passed to parser via callback/delegate
- Handles connection closure

**Implementation Approach**: Async networking with callbacks

**Required Components**:
- Update `LichConnection.swift`
- Add receive tests

**Test Requirements**:
```swift
test_receiveData()
test_partialDataHandling()
test_utf8Decoding()
```

**Dependencies**: TASK-P1-08

**Reference**: `requirements.md:1055-1067`

---

### TASK-P1-10: Implement Command Sending in LichConnection

**Description**: Send game commands to Lich server.

**Acceptance Criteria**:
- `send(_ command: String) async throws` method
- Appends newline to command
- UTF-8 encoding
- Uses `.idempotent` completion

**Implementation Approach**: Simple send wrapper

**Required Components**:
- Update `LichConnection.swift`
- Add send tests

**Test Requirements**:
```swift
test_sendCommand()
test_commandNewlineAppended()
```

**Dependencies**: TASK-P1-09

**Reference**: `requirements.md:1069-1073`

---

### TASK-P1-11: Implement Reconnection Logic

**Description**: Auto-reconnect on connection failure with exponential backoff.

**Acceptance Criteria**:
- Reconnect triggered on connection failure
- Exponential backoff: 0.5s → 1s → 2s → 4s → 8s max
- Reconnection attempts logged
- Manual disconnect doesn't trigger reconnect
- Cancellable reconnection

**Implementation Approach**: Retry logic with Task.sleep

**Required Components**:
- Update `LichConnection.swift`
- Add reconnection tests

**Test Requirements**:
```swift
test_reconnectOnFailure()
test_exponentialBackoff()
test_manualDisconnectNoReconnect()
```

**Dependencies**: TASK-P1-10

**Reference**: `requirements.md:83`

---

### TASK-P1-12: Integrate Parser with Connection

**Description**: Wire LichConnection to XMLStreamParser for end-to-end data flow.

**Acceptance Criteria**:
- Connection passes received chunks to parser
- Parser produces GameTag arrays
- Parsed tags made available to UI layer
- Thread-safe communication between actors

**Implementation Approach**: Actor integration

**Required Components**:
- Update `LichConnection.swift` to hold parser reference
- Integration tests

**Test Requirements**:
```swift
test_connectionToParserDataFlow()
test_parsedTagsAvailable()
```

**Dependencies**: TASK-P1-11

---

### TASK-P1-13: Create Basic GameLogViewModel

**Description**: Observable view model to hold parsed game messages for display.

**Acceptance Criteria**:
- `GameLogViewModel` class with `@Observable` macro
- `messages: [GameTag]` array
- `appendMessage(_ tag: GameTag)` method
- 10,000 line buffer with pruning
- Thread-safe updates

**Implementation Approach**: SwiftUI state management

**Required Components**:
- `Vaalin/ViewModels/GameLogViewModel.swift`
- Basic tests

**Test Requirements**:
```swift
test_appendMessage()
test_bufferPruning()
```

**Dependencies**: TASK-F02

**Reference**: `requirements.md:893-906`

---

### TASK-P1-14: Create Basic GameLogView (Integration Checkpoint)

**Description**: Minimal SwiftUI view to display parsed tags as text.

**Acceptance Criteria**:
- `GameLogView` renders `GameTag` array from view model
- Displays text content only (no styling yet)
- Auto-scrolls to bottom
- Shows connection status (connected/disconnected)
- Xcode Preview with sample data

**Implementation Approach**: SwiftUI view with List/LazyVStack

**Required Components**:
- `Vaalin/Views/GameLogView.swift`
- Xcode Preview

**Test Requirements**: Manual testing via preview

**Dependencies**: TASK-P1-13

**Reference**: `requirements.md:99-113` (FR-1.3)

---

### TASK-P1-15: End-to-End Integration Test (Phase 1 Checkpoint)

**Description**: Verify parser + network + basic UI work together.

**Acceptance Criteria**:
- Can connect to Lich on localhost:8000
- Receives XML data from game
- Parser produces GameTag structures
- Tags displayed in GameLogView
- No crashes during 5-minute connection

**Implementation Approach**: Manual integration testing

**Test Requirements**: Manual QA session

**Dependencies**: TASK-P1-14

**Reference**: `requirements.md:1294-1297` (Phase 1 Integration)

---

## Phase 2: Game Log & Command Input

### TASK-P2-01: Implement ANSI Color Parser

**Description**: Parse ANSI escape codes from game text into color/style information.

**Acceptance Criteria**:
- Swift Regex patterns for ANSI codes
- Supports: reset (`\033[0m`), 16-color palette, bold, italic, underline
- Extracts color/style runs from text
- Returns array of styled text ranges

**Implementation Approach**: TDD - test ANSI parsing

**Required Components**:
- `VaalinCore/Sources/ANSIParser.swift`
- `VaalinCore/Tests/ANSIParserTests.swift`

**Test Requirements**:
```swift
test_parseResetCode()
test_parseColorCode()
test_parseBoldCode()
test_parseMultipleCodes()
test_parseComplexString()
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:168-186`

---

### TASK-P2-02: Load Catppuccin Mocha Color Theme

**Description**: Load theme colors from JSON config and map to SwiftUI colors.

**Acceptance Criteria**:
- `themes/catppuccin-mocha.json` created with color palette
- Theme loader reads JSON, creates SwiftUI Color instances
- ANSI codes mapped to theme colors
- Theme accessible via environment/singleton

**Implementation Approach**: JSON loading, color mapping

**Required Components**:
- `Vaalin/Resources/themes/catppuccin-mocha.json`
- `VaalinCore/Sources/ThemeManager.swift`
- Tests for theme loading

**Test Requirements**:
```swift
test_loadTheme()
test_ansiColorMapping()
```

**Dependencies**: TASK-F03

**Reference**: `requirements.md:711-727`, Catppuccin palette spec

---

### TASK-P2-03: Implement TagRenderer for AttributedString

**Description**: Convert GameTag to AttributedString with ANSI colors applied.

**Acceptance Criteria**:
- `TagRenderer` class/actor
- `render(_ tag: GameTag) -> AttributedString` method
- Applies ANSI colors from theme
- Handles nested tags recursively
- Supports `<a>`, `<b>`, `<d>` tag styling

**Implementation Approach**: TDD - test rendering various tag types

**Required Components**:
- `VaalinParser/Sources/TagRenderer.swift`
- `VaalinParser/Tests/TagRendererTests.swift`

**Test Requirements**:
```swift
test_renderPlainText()
test_renderWithANSI()
test_renderBoldTag()
test_renderNestedTags()
```

**Dependencies**: TASK-P2-01, TASK-P2-02

**Reference**: `requirements.md:159-164`

---

### TASK-P2-04: Implement Virtualized Game Log with AttributedString

**Description**: Replace basic GameLogView with high-performance virtualized list.

**Acceptance Criteria**:
- Uses `LazyVStack` or `List` for virtualization
- Renders AttributedString messages
- 10,000 line scrollback buffer
- Auto-scroll when at bottom, pauses when scrolled up
- Smooth 60fps scrolling
- Supports text selection/copy

**Implementation Approach**: SwiftUI optimization

**Required Components**:
- Update `Vaalin/Views/GameLogView.swift`
- Performance testing

**Test Requirements**:
```swift
test_scrollPerformance() // 60fps assertion
test_autoScroll()
test_scrollPause()
```

**Dependencies**: TASK-P2-03

**Reference**: `requirements.md:144-165`

---

### TASK-P2-05: Add Timestamp Support to Game Log

**Description**: Optional timestamps for each log line.

**Acceptance Criteria**:
- Timestamps toggleable (default OFF)
- Setting persisted in Settings
- Format: `[HH:MM:SS]` prefix
- Dimmed color (theme-based)

**Implementation Approach**: Extend rendering logic

**Required Components**:
- Update `TagRenderer.swift`
- Update `Settings.swift` with timestamp flag
- UI toggle (future)

**Test Requirements**:
```swift
test_timestampRendering()
test_timestampToggle()
```

**Dependencies**: TASK-P2-04, TASK-F03

**Reference**: `requirements.md:155`

---

### TASK-P2-06: Implement Command History Manager

**Description**: Maintain command history with persistence.

**Acceptance Criteria**:
- `CommandHistory` class with 500-item buffer
- Circular buffer (oldest pruned)
- Navigate up/down through history
- Prefix-based search (type "look", up shows matching)
- Persist to JSON on disk (`~/Library/Application Support/Vaalin/command-history.json`)
- Load on app start

**Implementation Approach**: TDD - test buffer, search, persistence

**Required Components**:
- `VaalinCore/Sources/CommandHistory.swift`
- `VaalinCore/Tests/CommandHistoryTests.swift`

**Test Requirements**:
```swift
test_addCommand()
test_navigateHistory()
test_prefixSearch()
test_persistenceRoundTrip()
test_bufferPruning()
```

**Dependencies**: TASK-F01

**Reference**: `requirements.md:189-218`

---

### TASK-P2-07: Create CommandInputView

**Description**: SwiftUI TextField with readline-style keyboard shortcuts.

**Acceptance Criteria**:
- Single-line `TextField`
- Custom key handling via `.onKeyPress()`
- Readline shortcuts:
  - Ctrl-A: Beginning of line
  - Ctrl-E: End of line
  - Ctrl-U: Delete to beginning
  - Ctrl-K: Delete to end
  - Ctrl-W: Delete word backward
  - Option-B/F: Word backward/forward
  - Option-Delete: Delete word backward
- Enter sends command, clears input
- Integrates with CommandHistory (up/down arrows)

**Implementation Approach**: SwiftUI custom key handling

**Required Components**:
- `Vaalin/Views/CommandInputView.swift`
- `Vaalin/ViewModels/CommandInputViewModel.swift`

**Test Requirements**: UI testing for key shortcuts

**Dependencies**: TASK-P2-06

**Reference**: `requirements.md:189-218`, Reference implementation at `/Users/trevor/Projects/illthorn/src/frontend/components/command-bar/cli.lit.ts`

---

### TASK-P2-08: Implement Command Echo to Game Log

**Description**: Echo sent commands to game log with styling.

**Acceptance Criteria**:
- Commands echoed with `›` prefix
- Dimmed/styled to distinguish from game output
- Echo happens before command sent to server
- Respects echo setting (can be disabled)

**Implementation Approach**: Extend GameLogViewModel

**Required Components**:
- Update `GameLogViewModel.swift`
- Add echo setting to Settings

**Test Requirements**:
```swift
test_commandEcho()
test_echoPrefix()
test_echoDisabled()
```

**Dependencies**: TASK-P2-07

**Reference**: `requirements.md:207`

---

### TASK-P2-09: Wire CommandInputView to LichConnection

**Description**: Send commands from input to network layer.

**Acceptance Criteria**:
- Enter key sends command via LichConnection
- Command added to history
- Input cleared after send
- Error handling for send failures

**Implementation Approach**: View model integration

**Required Components**:
- Update `CommandInputViewModel.swift`
- Wire to LichConnection

**Test Requirements**:
```swift
test_sendCommandToServer()
test_commandAddedToHistory()
test_inputCleared()
```

**Dependencies**: TASK-P2-08, TASK-P1-10

---

### TASK-P2-10: Implement Prompt Display

**Description**: Parse and display server prompt above command input.

**Acceptance Criteria**:
- Listens for `<prompt>` tags via EventBus
- Displays prompt text (e.g., `>`) above input
- Updates in real-time
- Readonly display

**Implementation Approach**: EventBus subscription

**Required Components**:
- `Vaalin/Views/PromptView.swift`
- `Vaalin/ViewModels/PromptViewModel.swift`

**Test Requirements**:
```swift
test_promptUpdate()
test_promptRendering()
```

**Dependencies**: TASK-F04, TASK-P1-06

**Reference**: `requirements.md:222-232`

---

### TASK-P2-11: Emit Tag Events to EventBus

**Description**: Parser publishes GameTag events to EventBus for panel subscriptions.

**Acceptance Criteria**:
- `<left>`, `<right>`, `<spell>` → `metadata/left`, `metadata/right`, `metadata/spell` events
- `<progressBar>` → `metadata/progressBar/{id}` events
- `<prompt>` → `metadata/prompt` event
- `<pushStream>` → `stream/{id}` event
- Tag data published after parsing

**Implementation Approach**: Extend XMLStreamParser to publish events

**Required Components**:
- Update `XMLStreamParser.swift` with EventBus integration
- Add event publishing tests

**Test Requirements**:
```swift
test_leftHandEventPublished()
test_vitalsEventPublished()
test_streamEventPublished()
```

**Dependencies**: TASK-F04, TASK-P1-07

**Reference**: `requirements.md:930-934`

---

### TASK-P2-12: End-to-End Playable Game Test (Phase 2 Checkpoint)

**Description**: Verify game is fully playable with log and input.

**Acceptance Criteria**:
- User can connect to Lich
- See game output with ANSI colors
- Send commands via input
- Commands echoed correctly
- Prompt displays correctly
- Can play for 30 minutes without issues

**Implementation Approach**: Manual QA session

**Test Requirements**: Manual playthrough

**Dependencies**: TASK-P2-11

**Reference**: `requirements.md:235-246` (FR-2.5)

---

## Phase 3: HUD Panels

### TASK-P3-01: Create PanelContainer View Component

**Description**: Reusable panel chrome with Liquid Glass styling.

**Acceptance Criteria**:
- `PanelContainer(title:content:)` SwiftUI view
- Liquid Glass material for header
- Collapse/expand toggle button
- Collapsed state persisted in Settings
- Fixed height passed as parameter
- Xcode Preview showing expanded/collapsed states

**Implementation Approach**: SwiftUI component

**Required Components**:
- `Vaalin/Views/Panels/PanelContainer.swift`
- Xcode Preview

**Test Requirements**: Visual verification via preview

**Dependencies**: TASK-F03

**Reference**: `requirements.md:253-270`

---

### TASK-P3-02: Create Panel Registry System

**Description**: Central registry for panels to declare themselves and manage visibility.

**Acceptance Criteria**:
- `PanelRegistry` singleton/actor
- Panels register with ID, title, default visibility
- Settings track panel visibility
- Support for left/right column assignment

**Implementation Approach**: Registry pattern

**Required Components**:
- `VaalinCore/Sources/PanelRegistry.swift`
- Update Settings with panel configuration

**Test Requirements**:
```swift
test_registerPanel()
test_panelVisibility()
```

**Dependencies**: TASK-F03

**Reference**: `requirements.md:263`

---

### TASK-P3-03: Implement HandsPanel ViewModel

**Description**: ViewModel for hands panel (left, right, prepared spell).

**Acceptance Criteria**:
- `HandsPanelViewModel` with `@Observable` macro
- Fields: `leftHand`, `rightHand`, `preparedSpell` (all optional String)
- Defaults: "Empty", "Empty", "None"
- Subscribes to `metadata/left`, `metadata/right`, `metadata/spell` events
- Updates state on events

**Implementation Approach**: TDD - test event handling

**Required Components**:
- `Vaalin/ViewModels/Panels/HandsPanelViewModel.swift`
- Tests

**Test Requirements**:
```swift
test_leftHandUpdate()
test_rightHandUpdate()
test_spellUpdate()
test_defaults()
```

**Dependencies**: TASK-F04, TASK-P2-11

**Reference**: `requirements.md:273-291`

---

### TASK-P3-04: Create HandsPanel View

**Description**: SwiftUI view displaying hands panel.

**Acceptance Criteria**:
- Displays: "Left: {item}", "Right: {item}", "Prepared: {spell}"
- Uses PanelContainer
- Fixed height: 140pt
- Xcode Preview with various states

**Implementation Approach**: SwiftUI view

**Required Components**:
- `Vaalin/Views/Panels/HandsPanel.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P3-01, TASK-P3-03

**Reference**: Implementation reference at `/Users/trevor/Projects/illthorn/src/frontend/components/session/hands/hands-container.lit.ts`

---

### TASK-P3-05: Implement VitalsPanel ViewModel

**Description**: ViewModel for vitals panel (health, mana, stamina, spirit, mind, stance, encumbrance).

**Acceptance Criteria**:
- `VitalsPanelViewModel` with `@Observable` macro
- Fields for 5 progress bars: health, mana, stamina, spirit, mindState (all 0-100)
- Fields for stance, encumbrance (String)
- Subscribes to `metadata/progressBar/*` events
- Calculates percentage from fraction if server sends incorrect value
- Indeterminate state handling

**Implementation Approach**: TDD - test event subscriptions, calculations

**Required Components**:
- `Vaalin/ViewModels/Panels/VitalsPanelViewModel.swift`
- Tests

**Test Requirements**:
```swift
test_healthBarUpdate()
test_percentageCalculation()
test_stanceUpdate()
test_indeterminateState()
```

**Dependencies**: TASK-F04, TASK-P2-11

**Reference**: `requirements.md:293-316`

---

### TASK-P3-06: Create VitalsPanel View

**Description**: SwiftUI view with 5 progress bars and 2 text fields.

**Acceptance Criteria**:
- 5 labeled progress bars (health, mana, stamina, spirit, mind)
- Color-coded: health (red→green), mana (blue), stamina (yellow), spirit (purple), mind (teal)
- 2 text labels: stance, encumbrance
- Uses PanelContainer
- Fixed height: 160pt
- Xcode Preview with various vitals states

**Implementation Approach**: SwiftUI custom ProgressView styling

**Required Components**:
- `Vaalin/Views/Panels/VitalsPanel.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P3-01, TASK-P3-05

**Reference**: Implementation reference at `/Users/trevor/Projects/illthorn/src/frontend/components/session/vitals/vitals-container.lit.ts`

---

### TASK-P3-07: Research Compass Tag Structure

**Description**: Investigate current compass/nav tag format from game.

**Acceptance Criteria**:
- Document tag structure (is it `<nav>` or `<compass>`?)
- Identify attributes for exits (N, NE, E, SE, S, SW, W, NW, up, down, out)
- Sample XML captured from live game session

**Implementation Approach**: Research via game connection

**Required Components**:
- Documentation notes in `docs/compass-tags.md`

**Test Requirements**: N/A (research)

**Dependencies**: TASK-P1-15 (need working connection)

**Reference**: `requirements.md:324`

---

### TASK-P3-08: Implement CompassPanel ViewModel

**Description**: ViewModel for compass/room panel.

**Acceptance Criteria**:
- `CompassPanelViewModel` with `@Observable` macro
- Fields: `roomName` (String), `exits` (Set of directions)
- Subscribes to compass/nav events
- Updates on new room data

**Implementation Approach**: TDD - test event handling

**Required Components**:
- `Vaalin/ViewModels/Panels/CompassPanelViewModel.swift`
- Tests

**Test Requirements**:
```swift
test_roomNameUpdate()
test_exitsUpdate()
test_exitSet()
```

**Dependencies**: TASK-F04, TASK-P3-07

**Reference**: `requirements.md:318-339`

---

### TASK-P3-09: Create CompassPanel View with Compass Rose

**Description**: SwiftUI view with custom-drawn compass rose.

**Acceptance Criteria**:
- Displays room name at top
- Compass rose with 8 directions + up/down/out
- Available exits highlighted
- Clickable exits send movement command
- Custom SwiftUI shape for compass
- VoiceOver reads available exits
- Uses PanelContainer
- Fixed height: 160pt
- Xcode Preview with exit combinations

**Implementation Approach**: SwiftUI custom drawing

**Required Components**:
- `Vaalin/Views/Panels/CompassPanel.swift`
- `Vaalin/Views/Panels/CompassRose.swift` (custom shape)
- Xcode Preview

**Test Requirements**: Visual verification, accessibility testing

**Dependencies**: TASK-P3-01, TASK-P3-08

**Reference**: Examine Illthorn compass for design inspiration

---

### TASK-P3-10: Implement InjuriesPanel ViewModel

**Description**: ViewModel for injuries panel from dynamic window data.

**Acceptance Criteria**:
- `InjuriesPanelViewModel` with `@Observable` macro
- Subscribes to `<openDialog>` + `<dialogData>` events with injury widgets
- Parses: `<progressBar>`, `<label>`, `<radio>`, `<skin>` widgets
- Stores injury locations with severity
- Empty state support

**Implementation Approach**: TDD - test widget parsing

**Required Components**:
- `Vaalin/ViewModels/Panels/InjuriesPanelViewModel.swift`
- Tests

**Test Requirements**:
```swift
test_parseInjuryWidgets()
test_injuryLocationSeverity()
test_emptyState()
```

**Dependencies**: TASK-F04, TASK-P1-06

**Reference**: `requirements.md:341-361`, GemStone IV Wiki - Dynamic Windows

---

### TASK-P3-11: Create InjuriesPanel View

**Description**: SwiftUI view displaying injury widgets.

**Acceptance Criteria**:
- Renders injury locations (head, torso, arms, legs)
- Color-coded severity: minor (yellow), moderate (orange), severe (red), critical (dark red)
- Empty state: "No injuries"
- Uses PanelContainer
- Fixed height: 180pt
- Xcode Preview with injury states

**Implementation Approach**: SwiftUI dynamic widget rendering

**Required Components**:
- `Vaalin/Views/Panels/InjuriesPanel.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P3-01, TASK-P3-10

---

### TASK-P3-12: Implement SpellsPanel ViewModel

**Description**: ViewModel for active spells panel.

**Acceptance Criteria**:
- `SpellsPanelViewModel` with `@Observable` macro
- Subscribes to `<spell>` tags or `spellfront` stream
- Stores active spells with optional durations
- Removes expired spells
- Handles multiple spells

**Implementation Approach**: TDD - test spell tracking

**Required Components**:
- `Vaalin/ViewModels/Panels/SpellsPanelViewModel.swift`
- Tests

**Test Requirements**:
```swift
test_addSpell()
test_removeExpiredSpell()
test_multipleSpells()
```

**Dependencies**: TASK-F04, TASK-P2-11

**Reference**: `requirements.md:364-376`

---

### TASK-P3-13: Create SpellsPanel View

**Description**: SwiftUI view listing active spells.

**Acceptance Criteria**:
- Displays spell name, duration countdown (if available)
- List format
- Empty state: "No active spells"
- Uses PanelContainer
- Fixed height: 180pt
- Xcode Preview with spell list

**Implementation Approach**: SwiftUI list view

**Required Components**:
- `Vaalin/Views/Panels/SpellsPanel.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P3-01, TASK-P3-12

---

### TASK-P3-14: Create Main Layout with Panel Columns

**Description**: Main app window with left/right panel columns and central game log.

**Acceptance Criteria**:
- Three-column layout: left panels, center game log + input, right panels
- Fixed column widths from settings (default: 280pt each)
- Panels stacked vertically in columns
- Panel order from settings
- Resizable columns (future enhancement)

**Implementation Approach**: SwiftUI layout

**Required Components**:
- `Vaalin/Views/MainView.swift`
- Update VaalinApp.swift to use MainView

**Test Requirements**: Visual verification

**Dependencies**: All TASK-P3 panel views

**Reference**: `requirements.md:625-633` (layout settings)

---

### TASK-P3-15: End-to-End HUD Test (Phase 3 Checkpoint)

**Description**: Verify all panels update correctly during gameplay.

**Acceptance Criteria**:
- Play game for 30 minutes
- Vitals reflect damage/healing
- Hands update when items picked/dropped
- Spells appear/disappear correctly
- Compass shows exits
- No memory leaks or performance degradation

**Implementation Approach**: Manual QA session

**Test Requirements**: Manual playthrough with monitoring

**Dependencies**: TASK-P3-14

**Reference**: `requirements.md:379-391` (FR-3.7)

---

## Phase 4: Streams & Filtering

### TASK-P4-01: Define Stream Configuration Schema

**Description**: JSON schema for stream definitions.

**Acceptance Criteria**:
- Schema defined: `id`, `label`, `defaultOn`, `color`, `aliases`
- JSON file created: `Resources/stream-config.json`
- Default streams: thoughts, speech, whispers, logons, expr, familiar

**Implementation Approach**: Configuration design

**Required Components**:
- `Vaalin/Resources/stream-config.json`
- `docs/stream-schema.md` (documentation)

**Test Requirements**: JSON validation

**Dependencies**: None

**Reference**: `requirements.md:398-408`

---

### TASK-P4-02: Implement StreamRegistry

**Description**: Load and manage stream definitions.

**Acceptance Criteria**:
- `StreamRegistry` actor/singleton
- Loads `stream-config.json` at startup
- Provides stream lookup by ID
- Unknown stream IDs logged and ignored (not created)
- Supports aliases

**Implementation Approach**: TDD - test loading, lookup

**Required Components**:
- `VaalinCore/Sources/StreamRegistry.swift`
- `VaalinCore/Tests/StreamRegistryTests.swift`

**Test Requirements**:
```swift
test_loadStreamConfig()
test_streamLookup()
test_unknownStreamLogged()
test_aliasLookup()
```

**Dependencies**: TASK-P4-01

---

### TASK-P4-03: Implement Stream Buffers

**Description**: Separate message buffers for each stream.

**Acceptance Criteria**:
- `StreamBufferManager` actor
- Each stream has independent 10,000 line buffer
- Buffers prune oldest when full
- Thread-safe access
- Unread count tracking per stream

**Implementation Approach**: TDD - test buffering, pruning

**Required Components**:
- `VaalinCore/Sources/StreamBufferManager.swift`
- Tests

**Test Requirements**:
```swift
test_addToStreamBuffer()
test_bufferPruning()
test_unreadCount()
test_multipleStreams()
```

**Dependencies**: TASK-P4-02

**Reference**: `requirements.md:432-443`

---

### TASK-P4-04: Route Content to Stream Buffers

**Description**: Parser directs content to appropriate stream buffers based on `<pushStream>` tags.

**Acceptance Criteria**:
- XMLStreamParser tracks `currentStream`
- Content between `<pushStream id="X">` and `<popStream>` goes to stream buffer X
- Main game log always receives content (mirror mode)
- Stream buffer manager updated via events

**Implementation Approach**: Extend parser logic

**Required Components**:
- Update `XMLStreamParser.swift`
- Update `StreamBufferManager.swift`

**Test Requirements**:
```swift
test_contentRoutedToStream()
test_streamAndMainLogBothReceive()
```

**Dependencies**: TASK-P4-03, TASK-P1-05

**Reference**: `requirements.md:432-443`

---

### TASK-P4-05: Implement Mirror Mode Toggle

**Description**: Setting to control whether stream content appears in main log.

**Acceptance Criteria**:
- `mirrorFilteredToMain` setting (default: true)
- When ON: stream content in both stream buffer and main log
- When OFF: stream content only in stream buffer
- Per-stream override (future, not Phase 4)

**Implementation Approach**: Settings integration

**Required Components**:
- Update Settings.swift
- Update stream routing logic

**Test Requirements**:
```swift
test_mirrorModeOn()
test_mirrorModeOff()
```

**Dependencies**: TASK-P4-04, TASK-F03

**Reference**: `requirements.md:446-457`

---

### TASK-P4-06: Create StreamChip View Component

**Description**: Individual chip for stream filtering.

**Acceptance Criteria**:
- `StreamChip` SwiftUI view
- Displays stream label
- Unread badge count overlay
- Toggle ON/OFF state
- Chip color from stream config
- Liquid Glass styling

**Implementation Approach**: SwiftUI component

**Required Components**:
- `Vaalin/Views/Streams/StreamChip.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P4-02

**Reference**: `requirements.md:412-429`

---

### TASK-P4-07: Create StreamsBarView

**Description**: Horizontal bar of stream chips at top of window.

**Acceptance Criteria**:
- `StreamsBarView` with HStack of chips
- Renders chip for each default-ON stream
- Chips show unread counts
- Click toggles chip ON/OFF
- Liquid Glass material for bar background
- Fixed height from settings (default: 112pt)

**Implementation Approach**: SwiftUI layout

**Required Components**:
- `Vaalin/Views/Streams/StreamsBarView.swift`
- Xcode Preview

**Test Requirements**: Visual verification

**Dependencies**: TASK-P4-06

**Reference**: `requirements.md:412-429`

---

### TASK-P4-08: Implement Stream Keyboard Shortcuts

**Description**: Keyboard shortcuts to toggle stream chips.

**Acceptance Criteria**:
- `Cmd+1` through `Cmd+6` toggle chips 1-6
- Shortcuts work globally in app
- Visual feedback on toggle

**Implementation Approach**: SwiftUI keyboard shortcuts

**Required Components**:
- Update `StreamsBarView.swift` with `.keyboardShortcut()` modifiers

**Test Requirements**: Manual keyboard testing

**Dependencies**: TASK-P4-07

**Reference**: `requirements.md:420`

---

### TASK-P4-09: Create StreamView for Filtered Content

**Description**: View to display content from selected stream(s).

**Acceptance Criteria**:
- `StreamView` similar to GameLogView
- Shows content from stream buffer
- Multiple chips ON: union of content shown
- Back button returns to main log
- Clears unread count when viewed
- Navigation or sheet presentation

**Implementation Approach**: SwiftUI navigation

**Required Components**:
- `Vaalin/Views/Streams/StreamView.swift`
- Update navigation structure

**Test Requirements**: Manual navigation testing

**Dependencies**: TASK-P4-07

**Reference**: `requirements.md:460-475`

---

### TASK-P4-10: Integrate StreamsBar into Main Layout

**Description**: Add streams bar to top of main window.

**Acceptance Criteria**:
- Streams bar positioned above game log
- Layout: StreamsBar → GameLog → CommandInput
- Panels remain on left/right

**Implementation Approach**: Update layout

**Required Components**:
- Update `Vaalin/Views/MainView.swift`

**Test Requirements**: Visual verification

**Dependencies**: TASK-P4-09, TASK-P3-14

---

### TASK-P4-11: End-to-End Stream Filtering Test (Phase 4 Checkpoint)

**Description**: Verify streams filter correctly during gameplay.

**Acceptance Criteria**:
- Thoughts stream captures tells correctly
- Speech stream captures says/whispers
- Logons stream shows arrivals/departures
- Mirror mode toggle works
- No content loss or duplication
- Unread counts accurate

**Implementation Approach**: Manual QA session

**Test Requirements**: Manual playthrough with stream monitoring

**Dependencies**: TASK-P4-10

**Reference**: `requirements.md:478-490` (FR-4.6)

---

## Phase 5: Advanced Features

### TASK-P5-01: Design Item Category JSON Schema

**Description**: Define schema for item categorization data.

**Acceptance Criteria**:
- Schema: `id`, `displayName`, `nounPatterns`, `namePatterns`, `excludePatterns`, `colorKey`
- Categories: gem, jewelry, weapon, armor, clothing, food, reagent, valuable, box, junk
- Pattern syntax: Swift Regex strings

**Implementation Approach**: Configuration design

**Required Components**:
- `docs/item-category-schema.md`

**Test Requirements**: N/A (design)

**Dependencies**: None

**Reference**: `requirements.md:498-548`

---

### TASK-P5-02: Create Item Categories Data File

**Description**: JSON file with item categorization rules.

**Acceptance Criteria**:
- `Resources/item-categories.json` created
- 10 categories defined with patterns
- Patterns ported from Illthorn XML data
- Extensive noun/name pattern lists
- Exclude patterns for false positives

**Implementation Approach**: Data porting

**Required Components**:
- `Vaalin/Resources/item-categories.json`

**Test Requirements**: JSON validation

**Dependencies**: TASK-P5-01

**Reference**: Implementation reference at `/Users/trevor/Projects/illthorn/src/frontend/components/game-elements/item-highlighting.ts`

---

### TASK-P5-03: Implement ItemCategory Model

**Description**: Codable structure for item categories with compiled regex.

**Acceptance Criteria**:
- `ItemCategory` struct conforms to Codable, Identifiable
- Fields match schema
- Compiles regex patterns at load time
- Patterns stored as `Regex<AnyRegexOutput>` arrays

**Implementation Approach**: TDD - test encoding/decoding, regex compilation

**Required Components**:
- `VaalinCore/Sources/ItemCategory.swift`
- Tests

**Test Requirements**:
```swift
test_itemCategoryDecoding()
test_regexCompilation()
test_invalidRegexHandling()
```

**Dependencies**: TASK-P5-01

**Reference**: `requirements.md:1088-1103`

---

### TASK-P5-04: Implement ItemCategorizer Actor

**Description**: Actor for thread-safe item categorization with caching.

**Acceptance Criteria**:
- `ItemCategorizer` actor
- `load() async throws` loads JSON and compiles regexes
- `categorize(noun: String, fullName: String?) async -> ItemCategory?`
- Fast noun lookup dictionary (O(1) common cases)
- Pattern matching for complex cases
- Exclude patterns checked last
- LRU cache for recent categorizations (1000 entries)
- Performance: < 1ms per item average

**Implementation Approach**: TDD - test categorization logic, caching

**Required Components**:
- `VaalinCore/Sources/ItemCategorizer.swift`
- `VaalinCore/Tests/ItemCategorizerTests.swift`

**Test Requirements**:
```swift
test_categorizationByNoun()
test_categorizationByName()
test_excludePatterns()
test_nounLookupPerformance()
test_caching()
test_performanceWithLargeDataset()
```

**Dependencies**: TASK-P5-03

**Reference**: `requirements.md:1105-1151`, `requirements.md:1179-1184`

---

### TASK-P5-05: Integrate Item Highlighting in TagRenderer

**Description**: Apply category colors to `<a exist="..." noun="...">` tags.

**Acceptance Criteria**:
- TagRenderer uses ItemCategorizer to categorize items
- Category color applied to item text in AttributedString
- Handles uncategorized items (no highlight)
- Performance: no frame drops during rendering

**Implementation Approach**: Extend TagRenderer

**Required Components**:
- Update `VaalinParser/Sources/TagRenderer.swift`

**Test Requirements**:
```swift
test_renderHighlightedItem()
test_renderUncategorizedItem()
test_highlightPerformance()
```

**Dependencies**: TASK-P5-04, TASK-P2-03

**Reference**: `requirements.md:543`

---

### TASK-P5-06: Add Custom Item Pattern Settings UI (Future)

**Description**: Settings UI to add custom regex patterns per category (deferred to future release).

**Acceptance Criteria**: N/A (future enhancement)

**Implementation Approach**: Placeholder for future work

**Required Components**: N/A

**Test Requirements**: N/A

**Dependencies**: TASK-P5-05

**Reference**: `requirements.md:519` (mentioned as future enhancement)

---

### TASK-P5-07: Design Macro Configuration Schema

**Description**: Define JSON schema for macro definitions.

**Acceptance Criteria**:
- Schema: `settings` (enabled, echo_commands), categories (arbitrary user-defined)
- Category: mapping of keyboard shortcut → command(s)
- Multi-command support: `cmd1;cmd2`
- Echo override: `!command` prefix

**Implementation Approach**: Configuration design

**Required Components**:
- `docs/macro-schema.md`
- Example `macros.json` file

**Test Requirements**: N/A (design)

**Dependencies**: None

**Reference**: `requirements.md:550-589`

---

### TASK-P5-08: Implement MacroManager

**Description**: Load and execute macros.

**Acceptance Criteria**:
- `MacroManager` class/actor
- Loads `macros.json` at startup
- `handle(key: KeyEquivalent, modifiers: EventModifiers) async -> String?` returns command
- Validates shortcuts, prevents conflicts
- Supports: Cmd, Option, Shift, Ctrl, function keys, number keys
- Multi-command macros execute in sequence
- Echo override support
- Global enable/disable

**Implementation Approach**: TDD - test loading, execution, conflicts

**Required Components**:
- `VaalinCore/Sources/MacroManager.swift`
- `VaalinCore/Tests/MacroManagerTests.swift`

**Test Requirements**:
```swift
test_loadMacros()
test_executeMacro()
test_multiCommandMacro()
test_echoOverride()
test_shortcutConflict()
test_globalDisable()
```

**Dependencies**: TASK-P5-07

**Reference**: `requirements.md:1187-1213`

---

### TASK-P5-09: Integrate Macros with CommandInput

**Description**: Wire macro key handling to command input.

**Acceptance Criteria**:
- `.onKeyPress()` handler in CommandInputView
- Macro commands sent to LichConnection
- Echo behavior respects macro settings
- Macros work globally (not just when input focused)

**Implementation Approach**: Extend CommandInputView

**Required Components**:
- Update `Vaalin/Views/CommandInputView.swift`

**Test Requirements**: Manual keyboard testing

**Dependencies**: TASK-P5-08, TASK-P2-09

**Reference**: `requirements.md:574-578`

---

### TASK-P5-10: Implement Search in Game Log

**Description**: Find text in game log with highlighting.

**Acceptance Criteria**:
- `Cmd+F` opens search overlay
- Search field with case-insensitive matching (toggle for case-sensitive)
- Highlights all matches in log
- Next/Prev buttons (keyboard: `Cmd+G`, `Cmd+Shift+G`)
- Match count: "3 of 47 matches"
- Scrolls log to current match
- ESC or close button dismisses

**Implementation Approach**: SwiftUI `.searchable()` modifier

**Required Components**:
- `Vaalin/Views/SearchOverlay.swift`
- Update `GameLogView.swift` with search integration

**Test Requirements**: Manual search testing

**Dependencies**: TASK-P2-04

**Reference**: `requirements.md:595-616`

---

### TASK-P5-11: Implement SettingsManager Actor

**Description**: Thread-safe settings persistence to JSON.

**Acceptance Criteria**:
- `SettingsManager` actor
- Loads from `~/Library/Application Support/Vaalin/settings.json`
- Auto-saves on changes (debounced 500ms)
- Atomic writes (temp file + rename)
- Graceful handling of missing/corrupt JSON (fallback to defaults)
- Thread-safe access

**Implementation Approach**: TDD - test loading, saving, atomicity, corruption

**Required Components**:
- `VaalinCore/Sources/SettingsManager.swift`
- `VaalinCore/Tests/SettingsManagerTests.swift`

**Test Requirements**:
```swift
test_loadSettings()
test_saveSettings()
test_atomicWrite()
test_corruptJSONFallback()
test_debouncedSave()
```

**Dependencies**: TASK-F03

**Reference**: `requirements.md:617-668`, `requirements.md:656-663`

---

### TASK-P5-12: Wire All Components to SettingsManager

**Description**: Connect all app components to use centralized settings.

**Acceptance Criteria**:
- Panel collapsed states persist
- Stream mirror mode persists
- Timestamp settings persist
- Network host/port persist
- Theme selection persists
- Macro settings persist
- Settings load on app start
- Changes auto-save

**Implementation Approach**: Settings integration across app

**Required Components**:
- Update all view models to use SettingsManager
- App initialization loads settings

**Test Requirements**: Manual settings persistence testing

**Dependencies**: TASK-P5-11

---

### TASK-P5-13: End-to-End Advanced Features Test (Phase 5 Checkpoint)

**Description**: Verify highlighting, macros, search all work during gameplay.

**Acceptance Criteria**:
- Items correctly highlighted by category
- Macros execute commands
- Search finds text in log
- Settings persist across app restarts
- No performance degradation
- 30-minute play session without issues

**Implementation Approach**: Manual QA session

**Test Requirements**: Manual playthrough

**Dependencies**: TASK-P5-12

**Reference**: `requirements.md:671-683` (FR-5.5)

---

## Phase 6: Polish & Distribution

### TASK-P6-01: Apply Liquid Glass to Panel Headers

**Description**: Apply macOS 26 Liquid Glass materials to panel chrome.

**Acceptance Criteria**:
- Panel headers use `.containerBackground(.glass)` or equivalent
- Contrast ratios meet 4.5:1 accessibility minimum
- Works in both light and dark appearances
- Glass intensity configurable (future enhancement)

**Implementation Approach**: SwiftUI material application

**Required Components**:
- Update `Vaalin/Views/Panels/PanelContainer.swift`

**Test Requirements**: Visual verification on macOS 26

**Dependencies**: TASK-P3-01

**Reference**: `requirements.md:690-708`, Apple Liquid Glass documentation

---

### TASK-P6-02: Apply Liquid Glass to Streams Bar

**Description**: Liquid Glass material for streams bar.

**Acceptance Criteria**:
- Streams bar uses glass material
- Consistent with panel headers
- Accessibility contrast maintained

**Implementation Approach**: SwiftUI material

**Required Components**:
- Update `Vaalin/Views/Streams/StreamsBarView.swift`

**Test Requirements**: Visual verification

**Dependencies**: TASK-P4-07

**Reference**: `requirements.md:696`

---

### TASK-P6-03: Apply Liquid Glass to Command Input Background

**Description**: Subtle glass effect on command input area.

**Acceptance Criteria**:
- Command input background uses glass material
- Doesn't interfere with text readability
- Consistent theming

**Implementation Approach**: SwiftUI material

**Required Components**:
- Update `Vaalin/Views/CommandInputView.swift`

**Test Requirements**: Visual verification

**Dependencies**: TASK-P2-07

**Reference**: `requirements.md:697`

---

### TASK-P6-04: Finalize Catppuccin Mocha Theme

**Description**: Complete theme with all color tokens mapped.

**Acceptance Criteria**:
- All ANSI colors mapped to Catppuccin palette
- Semantic colors defined for UI elements
- Item category colors defined
- Theme JSON complete
- Consistent application across all views

**Implementation Approach**: Theme completion

**Required Components**:
- Update `Vaalin/Resources/themes/catppuccin-mocha.json`
- Verify all color references

**Test Requirements**: Visual verification across all views

**Dependencies**: TASK-P2-02

**Reference**: `requirements.md:711-727`, Catppuccin spec

---

### TASK-P6-05: Add Accessibility Labels

**Description**: Add accessibility labels to all interactive elements.

**Acceptance Criteria**:
- All buttons, toggles, inputs have labels
- Panel headers labeled
- Stream chips labeled
- Compass directions labeled
- Progress bars labeled with current values

**Implementation Approach**: SwiftUI accessibility modifiers

**Required Components**:
- Update all SwiftUI views with `.accessibilityLabel()` modifiers

**Test Requirements**: VoiceOver testing

**Dependencies**: All UI tasks

**Reference**: `requirements.md:732-748`

---

### TASK-P6-06: Implement Full Keyboard Navigation

**Description**: Ensure all UI accessible via keyboard.

**Acceptance Criteria**:
- Tab order logical
- All interactive elements keyboard-navigable
- Focus indicators visible
- Keyboard shortcuts shown in menus

**Implementation Approach**: SwiftUI focus management

**Required Components**:
- Review and update focus order across views

**Test Requirements**: Manual keyboard-only navigation

**Dependencies**: All UI tasks

**Reference**: `requirements.md:736`

---

### TASK-P6-07: Support System High Contrast Mode

**Description**: Ensure app works in high contrast mode.

**Acceptance Criteria**:
- Theme adapts to system high contrast setting
- Colors remain distinguishable
- Text readable
- No information lost

**Implementation Approach**: SwiftUI environment-based theming

**Required Components**:
- Update ThemeManager to detect high contrast
- Adjust colors accordingly

**Test Requirements**: Testing with high contrast enabled

**Dependencies**: TASK-P6-04

**Reference**: `requirements.md:738`

---

### TASK-P6-08: Support Dynamic Type (Font Scaling)

**Description**: Respect system text size settings.

**Acceptance Criteria**:
- All text scales with system font size
- Layout adapts to larger text
- No text truncation
- Readability maintained

**Implementation Approach**: SwiftUI dynamic type

**Required Components**:
- Use `.font(.body)` etc. instead of fixed sizes

**Test Requirements**: Testing with various text sizes

**Dependencies**: All UI tasks

**Reference**: `requirements.md:739`

---

### TASK-P6-09: Implement Session Logging

**Description**: Optional logging of game sessions to disk.

**Acceptance Criteria**:
- User can enable logging in settings
- Two formats: plain text (`.log`), JSONL (`.jsonl`)
- Filenames: `YYYY-MM-DD-HH-MM-SS.{log|jsonl}`
- Rotation: keep last 30 days (configurable)
- Location: `~/Library/Application Support/Vaalin/logs/`
- No PII logged
- Logging toggle in settings

**Implementation Approach**: File I/O with rotation logic

**Required Components**:
- `VaalinCore/Sources/SessionLogger.swift`
- Update Settings with logging options
- Tests

**Test Requirements**:
```swift
test_logSession()
test_logRotation()
test_jsonlFormat()
```

**Dependencies**: TASK-P5-11

**Reference**: `requirements.md:777-792`

---

### TASK-P6-10: Create App Icon and Assets

**Description**: Design and add app icon and marketing assets.

**Acceptance Criteria**:
- App icon in all required sizes
- Icon follows macOS design guidelines
- Assets added to Xcode asset catalog
- Launch screen (if applicable)

**Implementation Approach**: Design work

**Required Components**:
- `Vaalin/Assets.xcassets/AppIcon.appiconset/`

**Test Requirements**: Visual verification

**Dependencies**: None

---

### TASK-P6-11: Code Signing Setup

**Description**: Configure Xcode project for code signing with Apple Developer ID.

**Acceptance Criteria**:
- Code signing identity configured
- Hardened runtime enabled
- Entitlements configured (network, file access)
- Provisioning profile set up

**Implementation Approach**: Xcode configuration

**Required Components**:
- Xcode project settings
- `Vaalin.entitlements`

**Test Requirements**: Build verification

**Dependencies**: TASK-F01

**Reference**: `requirements.md:757`

---

### TASK-P6-12: Notarization Setup

**Description**: Prepare app for Apple notarization.

**Acceptance Criteria**:
- App notarized via Xcode
- Notarization succeeds
- Stapled notarization ticket
- App passes Gatekeeper without warnings

**Implementation Approach**: Notarization workflow

**Required Components**:
- Xcode Archive settings

**Test Requirements**: Notarization verification

**Dependencies**: TASK-P6-11

**Reference**: `requirements.md:758`

---

### TASK-P6-13: Create DMG Installer

**Description**: Build distributable DMG with app bundle.

**Acceptance Criteria**:
- DMG includes Vaalin.app
- Applications folder symlink
- Background image with drag instructions
- EULA/README included
- DMG code-signed and notarized

**Implementation Approach**: Use `create-dmg` tool or manual `hdiutil`

**Required Components**:
- DMG creation script
- Background image asset

**Test Requirements**: Installation testing

**Dependencies**: TASK-P6-12

**Reference**: `requirements.md:753-775`

---

### TASK-P6-14: Write User Documentation

**Description**: Create user-facing documentation.

**Acceptance Criteria**:
- README with installation instructions
- Usage guide (connecting to Lich, basic features)
- Keyboard shortcuts reference
- Troubleshooting section
- MacDown or similar format

**Implementation Approach**: Documentation writing

**Required Components**:
- `README.md`
- `docs/user-guide.md`
- `docs/keyboard-shortcuts.md`

**Test Requirements**: Peer review

**Dependencies**: All features complete

---

### TASK-P6-15: Final QA and Polish

**Description**: Comprehensive testing and polish pass.

**Acceptance Criteria**:
- All features tested end-to-end
- Performance targets met (60fps, < 500MB memory)
- No crashes during extended play
- All accessibility features work
- Theme consistent across views
- Edge cases handled gracefully

**Implementation Approach**: QA session

**Test Requirements**: Full test plan execution

**Dependencies**: All TASK-P6 tasks

**Reference**: `requirements.md:1315-1318` (Phase 6 Integration)

---

## Testing Tasks

### TASK-T01: Write Parser Unit Tests

**Description**: Comprehensive unit tests for XMLStreamParser.

**Acceptance Criteria**:
- All test cases from requirements covered:
  - `test_parseSimpleTag()`
  - `test_parseNestedTags()`
  - `test_parseIncompleteXML()`
  - `test_streamStatePersistedAcrossCalls()`
  - `test_malformedXMLRecovery()`
- Additional edge cases covered
- 100% coverage of parser logic

**Implementation Approach**: TDD throughout Phase 1

**Required Components**:
- `VaalinParser/Tests/XMLStreamParserTests.swift`

**Test Requirements**: CI integration

**Dependencies**: TASK-P1-07

**Reference**: `requirements.md:1325-1331`

---

### TASK-T02: Write Categorizer Unit Tests

**Description**: Unit tests for ItemCategorizer.

**Acceptance Criteria**:
- Tests from requirements:
  - `test_categorizationByNoun()`
  - `test_categorizationByName()`
  - `test_excludePatterns()`
  - `test_performanceWithLargeDataset()`
- Performance benchmarks
- 80%+ coverage

**Implementation Approach**: TDD during Phase 5

**Required Components**:
- `VaalinCore/Tests/ItemCategorizerTests.swift`

**Test Requirements**: Benchmark assertions

**Dependencies**: TASK-P5-04

**Reference**: `requirements.md:1332-1336`

---

### TASK-T03: Write Settings Persistence Tests

**Description**: Unit tests for SettingsManager.

**Acceptance Criteria**:
- Tests from requirements:
  - `test_loadSettings()`
  - `test_saveSettings()`
  - `test_corruptJSONFallback()`
- Atomic write verification
- Debouncing tests

**Implementation Approach**: TDD during Phase 5

**Required Components**:
- `VaalinCore/Tests/SettingsManagerTests.swift`

**Test Requirements**: File I/O mocking

**Dependencies**: TASK-P5-11

**Reference**: `requirements.md:1338-1342`

---

### TASK-T04: Write Macro System Tests

**Description**: Unit tests for MacroManager.

**Acceptance Criteria**:
- Tests from requirements:
  - `test_loadMacros()`
  - `test_executeMacro()`
  - `test_multiCommandMacro()`
- Conflict detection tests

**Implementation Approach**: TDD during Phase 5

**Required Components**:
- `VaalinCore/Tests/MacroManagerTests.swift`

**Test Requirements**: Keyboard event mocking

**Dependencies**: TASK-P5-08

**Reference**: `requirements.md:1343-1347`

---

### TASK-T05: Write UI Tests for Critical Paths

**Description**: UI tests for essential user flows.

**Acceptance Criteria**:
- Tests from requirements:
  - `test_connectToLich()`
  - `test_sendCommand()`
  - `test_gameLogScrolling()`
  - `test_panelCollapseExpand()`
  - `test_streamChipToggle()`
- Automated UI testing via XCUITest

**Implementation Approach**: UI testing throughout development

**Required Components**:
- `VaalinUITests/` target
- UI test cases

**Test Requirements**: CI integration

**Dependencies**: All UI features

**Reference**: `requirements.md:1349-1355`

---

### TASK-T06: Write Performance Tests

**Description**: Performance benchmarks for critical operations.

**Acceptance Criteria**:
- Tests from requirements:
  - `test_parsePerformance()` - < 100ms for 10,000 lines
  - `test_renderPerformance()` - 60fps during scrolling
  - `test_memoryUsage()` - no leaks over 8-hour session
- XCTest performance measurements
- CI performance regression detection

**Implementation Approach**: Performance testing in each phase

**Required Components**:
- `VaalinPerformanceTests/` target
- Benchmark suite

**Test Requirements**: Baseline metrics established

**Dependencies**: Critical components complete

**Reference**: `requirements.md:1357-1361`, `requirements.md:796-813`

---

### TASK-T07: Set Up Continuous Integration

**Description**: CI pipeline for automated testing.

**Acceptance Criteria**:
- GitHub Actions or similar CI
- Runs on every commit
- Executes: SwiftLint, unit tests, UI tests, performance tests
- Build verification
- Code coverage reporting (target: 80%)

**Implementation Approach**: CI configuration

**Required Components**:
- `.github/workflows/ci.yml`

**Test Requirements**: CI pipeline green

**Dependencies**: All test tasks

**Reference**: `requirements.md:839-842` (NFR-3.2)

---

## Task Dependencies

### Critical Path (Minimum Viable Product)

1. **TASK-F01** → TASK-F02, TASK-F03, TASK-F04, TASK-F05
2. **TASK-F02** → TASK-P1-01
3. **TASK-P1-01** → TASK-P1-02 → TASK-P1-03 → TASK-P1-04 → TASK-P1-05 → TASK-P1-06 → TASK-P1-07
4. **TASK-P1-08** → TASK-P1-09 → TASK-P1-10 → TASK-P1-11 → TASK-P1-12
5. **TASK-P1-13** → TASK-P1-14 → **TASK-P1-15** (Phase 1 Checkpoint)
6. **TASK-P2-01** → TASK-P2-03 → TASK-P2-04
7. **TASK-P2-06** → TASK-P2-07 → TASK-P2-08 → TASK-P2-09
8. **TASK-P2-10**, TASK-P2-11 → **TASK-P2-12** (Phase 2 Checkpoint - Playable)

### Full Feature Path

9. **TASK-P3-01** → All panel tasks (TASK-P3-03 to TASK-P3-13)
10. **TASK-P3-14** → **TASK-P3-15** (Phase 3 Checkpoint)
11. **TASK-P4-01** → TASK-P4-02 → TASK-P4-03 → TASK-P4-04
12. **TASK-P4-06** → TASK-P4-07 → TASK-P4-09 → TASK-P4-10 → **TASK-P4-11** (Phase 4 Checkpoint)
13. **TASK-P5-01** → TASK-P5-02 → TASK-P5-03 → TASK-P5-04 → TASK-P5-05
14. **TASK-P5-07** → TASK-P5-08 → TASK-P5-09
15. **TASK-P5-11** → TASK-P5-12 → **TASK-P5-13** (Phase 5 Checkpoint)
16. **TASK-P6-01** to TASK-P6-09 (Polish)
17. **TASK-P6-11** → TASK-P6-12 → TASK-P6-13 (Distribution)
18. **TASK-P6-15** (Final QA)

### Parallel Work Opportunities

- **UI and Logic**: Can develop panel view models (TASK-P3-03, P3-05, etc.) in parallel with views (TASK-P3-04, P3-06, etc.)
- **Parser and Network**: Can be developed independently until TASK-P1-12 integration
- **Theming and Accessibility**: Can be applied incrementally throughout development
- **Testing**: Should proceed in parallel with feature development (TDD approach)

---

## Task Metadata

**Total Tasks**: 107 (6 foundational, 101 phase-specific)
**Integration Checkpoints**: 6 (one per phase)
**Estimated Complexity**: High (native platform port with advanced features)
**Key Technologies**: Swift 5.9+, SwiftUI, Network.framework, XMLParser, Swift Concurrency (actors, async/await)

---

## Notes for Implementation

### Test-Driven Development (TDD)

Tasks marked with "TDD" should follow this workflow:
1. Write failing tests first
2. Implement minimal code to pass tests
3. Refactor for clarity/performance
4. Repeat

### Integration Checkpoints

Integration checkpoints (TASK-P1-15, P2-12, P3-15, P4-11, P5-13, P6-15) are **mandatory** milestones. Do not proceed to next phase until checkpoint passes.

### Reference Implementations

Many tasks reference Illthorn source code at `/Users/trevor/Projects/illthorn/`. Consult these files for behavior/edge cases but **reimplement in Swift**, don't directly port TypeScript.

### Performance Budget

Keep these targets in mind throughout development:
- Parser: > 10,000 lines/minute
- Game log: 60fps scrolling
- Memory: < 500MB peak
- Startup: < 2 seconds cold, < 500ms hot
- Item categorization: < 1ms average

### Documentation

DocC comments required for:
- All public APIs
- Complex algorithms (parser state machine, categorization, etc.)
- Actor isolation boundaries

Xcode Previews required for:
- All SwiftUI views (minimum 2 states per view)

---

**End of Task Breakdown**
