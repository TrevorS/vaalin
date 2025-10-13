# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vaalin is a native macOS SwiftUI application for playing GemStone IV (a text-based MUD) via Lich 5's detachable client mode. This is a complete rewrite of the Illthorn Electron/TypeScript client using modern Swift technologies.

**Target**: macOS 26+ (Tahoe) with Liquid Glass design language
**Language**: Swift 5.9+ with strict concurrency
**Architecture**: Actor-based SwiftUI with Swift Package Manager modular structure

## Key Architectural Decisions

- **SwiftUI + @Observable**: State management using Swift 5.9+ Observable macro
- **Swift Actors**: Thread-safe concurrent operations for parser, network, categorizer
- **Event Bus Pattern**: Cross-component communication via actor-based pub/sub
- **Native XMLParser**: SAX-based streaming XML parsing with persistent state
- **NWConnection**: Modern async networking via Network.framework
- **Liquid Glass**: macOS 26 translucent material design for panels and chrome

## Development Commands

### Prerequisites

**Required Tools:**
- **Xcode 16.0+** (required for macOS 26 Liquid Glass APIs and Swift 5.9+)
- **SwiftLint**: `brew install swiftlint`

**Build System Architecture:**
- Uses **pure Swift Package Manager** (no `.xcodeproj` file)
- Modern approach: `Package.swift` defines all targets and schemes
- Xcode auto-generates schemes from `Package.swift` (no manual sharing needed)
- Cleaner git history: no Xcode project file churn
- Superior CLI/CI compatibility: `swift build` and `xcodebuild` both work seamlessly

### Project Status

**Current State:** Active development (44 open issues)
- Foundation complete (Issue #1-19)
- Phase 1 complete (Parser + Network + Basic UI)
- Phase 2 in progress (MVP development)

### Standard Commands (via Makefile)

Aligned with global development standards from `~/.claude/CLAUDE.md`:

```bash
make run                 # Build and launch Vaalin.app (uses scripts/run-app.sh)
make format              # Auto-fix SwiftLint issues
make lint                # Check SwiftLint compliance (CI mode)
make test                # Run all tests with coverage
make build               # Build for development (Debug)
make clean               # Clean build artifacts and derived data
make help                # Show all available commands
```

### Direct xcodebuild Commands

When you need more control or for CI/CD integration:

```bash
# Build for development
xcodebuild -scheme Vaalin -destination 'platform=macOS' -configuration Debug build

# Build for release (Phase 6)
xcodebuild -scheme Vaalin -destination 'platform=macOS' -configuration Release build

# Run tests with coverage
xcodebuild test \
  -scheme Vaalin \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# View coverage report
xcrun xccov view --report TestResults.xcresult

# Export coverage for CI (JSON format)
xcrun xccov view --report --json TestResults.xcresult > coverage.json

# Build documentation
xcodebuild docbuild -scheme Vaalin -destination 'platform=macOS'

# Clean build artifacts
xcodebuild clean -scheme Vaalin

# Clean derived data (nuclear option)
rm -rf ~/Library/Developer/Xcode/DerivedData/Vaalin-*

# Archive for distribution (Phase 6)
xcodebuild archive \
  -scheme Vaalin \
  -archivePath build/Vaalin.xcarchive \
  -destination 'platform=macOS'
```

### Swift Package Manager Commands

All package targets are defined in the root `Package.swift`:

```bash
# Build all packages
swift build

# Test all packages
swift test

# Build in release mode
swift build -c release

# Run the executable
swift run Vaalin
```

**Architecture**: Single `Package.swift` at repository root defines all targets (Vaalin, VaalinParser, VaalinNetwork, VaalinCore) with proper dependency relationships.

### SwiftLint Commands

```bash
# Check compliance (fails on violations)
swiftlint

# Auto-fix issues
swiftlint --fix

# Alternative auto-fix syntax
swiftlint autocorrect

# Lint specific files
swiftlint lint --path Vaalin/VaalinApp.swift

# Use in CI (strict mode)
swiftlint --strict
```

### Xcode GUI Workflows

```bash
# Open project in Xcode
open Package.swift
# Xcode recognizes Package.swift and opens the workspace automatically

# Alternative: Open specific file in Xcode
open -a Xcode Vaalin/VaalinApp.swift

# Run app: Cmd+R in Xcode
# (Select "Vaalin" scheme in Xcode toolbar)

# Run tests: Cmd+U in Xcode

# Xcode Previews: Cmd+Option+P
# (Previews cannot be run from CLI - Xcode-only feature)

# Build documentation: Product > Build Documentation
# (Opens in Xcode's DocC viewer)
```

### Automated Preview Screenshots

**`scripts/capture-preview.sh`** - Automates capturing screenshots of Xcode SwiftUI previews:

```bash
# Capture a preview screenshot
./scripts/capture-preview.sh \
  VaalinUI/Sources/VaalinUI/Views/Panels/Previews/VitalsPanel/VitalsPanelPopulatedState.swift \
  /tmp/vaalin-vitals-populated.png
```

**How it works**:
1. Opens the preview file in Xcode
2. Ensures Canvas is visible (toggles if needed)
3. Refreshes the preview (Cmd+Option+P)
4. Captures Xcode window geometry
5. Takes screenshot of just the Xcode window
6. Returns focus to previous application

**Requirements**:
- Xcode must be installed
- System Events accessibility permissions enabled for Terminal/Ghostty
  (System Settings → Privacy & Security → Accessibility)

**Use cases**:
- Generating documentation screenshots
- Visual regression testing
- Design reviews and QA validation
- Capturing all preview states for issue documentation

**Preview file organization**: All preview files are organized in component-specific directories:
```
VaalinUI/Sources/VaalinUI/Views/
├── Panels/Previews/
│   ├── HandsPanel/
│   │   ├── HandsPanelEmptyState.swift
│   │   ├── HandsPanelPopulatedState.swift
│   │   └── HandsPanelLongNamesState.swift
│   └── VitalsPanel/
│       ├── VitalsPanelEmptyState.swift
│       ├── VitalsPanelPopulatedState.swift
│       └── VitalsPanelCriticalState.swift
└── Previews/
    ├── CommandInputView/
    ├── GameLogView/
    ├── PanelContainer/
    └── PromptView/
```

### Build Output Locations

```bash
# Debug builds (xcodebuild)
.build/xcode/Build/Products/Debug/Vaalin.app

# Debug builds (swift build)
.build/arm64-apple-macosx/debug/Vaalin

# Release builds
.build/xcode/Build/Products/Release/Vaalin.app

# Archives (Phase 6)
build/Vaalin.xcarchive

# Test results
TestResults.xcresult

# Derived data (ephemeral)
~/Library/Developer/Xcode/DerivedData/Vaalin-{hash}/
```

### Automation Scripts

**`scripts/run-app.sh`** - Build and launch Vaalin as proper macOS .app:
- Uses xcodebuild with proper scheme and destination
- Creates complete .app bundle structure (Contents/MacOS, Contents/Resources, Info.plist)
- Copies executable and resource bundle into proper locations
- Launches via `open` command
- Use via `make run` or `./scripts/run-app.sh` directly

**`scripts/capture-preview.sh`** - Automated preview screenshots (documented above)

## Project Structure

**Organization**: Pure Swift Package Manager architecture (no `.xcodeproj` file).

**Current structure** (as of Issue #140):

```
Vaalin/
├── Package.swift                  # Root package manifest (defines all targets)
├── Makefile                       # Standard development commands
├── .swiftlint.yml                 # SwiftLint configuration
├── .gitignore                     # Git ignore (Xcode, SwiftPM, build artifacts)
├── scripts/                       # Build and automation scripts
│   ├── run-app.sh                 # Build and launch Vaalin.app with proper bundle
│   └── capture-preview.sh         # Automated Xcode preview screenshots
├── Vaalin/                        # Main app target (macOS application)
│   ├── VaalinApp.swift            # @main entry point
│   ├── Resources/                 # Bundled resources
│   ├── Assets.xcassets/           # App icon, images
│   └── Vaalin.entitlements        # Sandboxing, network access (Phase 6)
├── VaalinUI/                      # Swift Package: SwiftUI views and view models
│   ├── Sources/VaalinUI/
│   │   ├── Views/                 # All SwiftUI views
│   │   │   ├── MainView.swift     # Root layout (panels + log + input)
│   │   │   ├── GameLogView.swift
│   │   │   ├── CommandInputView.swift
│   │   │   ├── PromptView.swift
│   │   │   ├── StreamsBarView.swift
│   │   │   ├── ConnectionControlsView.swift
│   │   │   ├── Panels/
│   │   │   │   ├── PanelContainer.swift
│   │   │   │   ├── HandsPanel.swift
│   │   │   │   ├── VitalsPanel.swift
│   │   │   │   ├── CompassPanel.swift
│   │   │   │   ├── CompassRose.swift
│   │   │   │   ├── InjuriesPanel.swift
│   │   │   │   └── SpellsPanel.swift
│   │   │   └── Previews/          # Organized preview files
│   │   │       ├── CommandInputView/
│   │   │       ├── GameLogView/
│   │   │       ├── Panels/
│   │   │       │   ├── HandsPanel/
│   │   │       │   ├── VitalsPanel/
│   │   │       │   ├── CompassPanel/
│   │   │       │   ├── InjuriesPanel/
│   │   │       │   └── SpellsPanel/
│   │   │       └── ...
│   │   ├── ViewModels/            # @Observable view models
│   │   │   ├── AppState.swift     # Root application state
│   │   │   ├── GameLogViewModel.swift
│   │   │   ├── CommandInputViewModel.swift
│   │   │   ├── PromptViewModel.swift
│   │   │   └── Panels/
│   │   │       ├── PanelViewModelBase.swift
│   │   │       ├── HandsPanelViewModel.swift
│   │   │       ├── VitalsPanelViewModel.swift
│   │   │       ├── CompassPanelViewModel.swift
│   │   │       ├── InjuriesPanelViewModel.swift
│   │   │       └── SpellsPanelViewModel.swift
│   │   ├── Models/                # UI-specific models
│   │   │   ├── ActiveSpell.swift
│   │   │   ├── BodyPart.swift
│   │   │   └── InjuryStatus.swift
│   │   └── Extensions/
│   │       └── ViewExtensions.swift
│   └── Tests/VaalinUITests/       # View and ViewModel tests
├── VaalinParser/                  # Swift Package: XML parsing (actor-based)
│   ├── Sources/VaalinParser/
│   │   ├── XMLStreamParser.swift  # Actor - stateful SAX parser
│   │   └── TagRenderer.swift      # GameTag → AttributedString
│   └── Tests/VaalinParserTests/
│       └── XMLStreamParserTests.swift
├── VaalinNetwork/                 # Swift Package: Lich TCP connection
│   ├── Sources/VaalinNetwork/
│   │   ├── LichConnection.swift          # Actor - NWConnection wrapper
│   │   ├── ConnectionState.swift         # Connection state enum
│   │   ├── CommandSending.swift          # Protocol - dependency injection
│   │   └── ParserConnectionBridge.swift  # Actor - integrates connection + parser
│   └── Tests/VaalinNetworkTests/
│       ├── LichConnectionTests.swift
│       └── ParserConnectionBridgeTests.swift
├── VaalinCore/                    # Swift Package: shared models/utilities
│   ├── Sources/VaalinCore/
│   │   ├── GameTag.swift          # Parsed XML element model
│   │   ├── Message.swift          # Rendered game log entry with AttributedString
│   │   ├── EventBus.swift         # Actor - pub/sub events
│   │   ├── StreamRegistry.swift   # Actor - thread-safe stream metadata (Issue #49)
│   │   ├── PanelRegistry.swift    # Actor - panel state management
│   │   ├── Settings.swift         # Codable settings model
│   │   ├── CommandHistory.swift   # Command history buffer
│   │   ├── ThemeManager.swift     # Preset color theme loader
│   │   └── Theme/
│   │       └── CatppuccinMocha.swift
│   └── Tests/VaalinCoreTests/
│       ├── GameTagTests.swift
│       ├── MessageTests.swift
│       ├── EventBusTests.swift
│       └── SettingsTests.swift
├── VaalinAppTests/                # App-level integration tests
│   ├── IntegrationTests/
│   ├── PerformanceTests/
│   └── Mocks/
├── TestTools/                     # Standalone test executables
│   └── TestLichConnection/        # Manual Lich connection testing
└── TestResults.xcresult           # Test coverage results (gitignored)
```

**Package Structure** (Implemented in Issue #1):

**Single `Package.swift` at repository root** - All targets defined in one manifest:
- ✅ Modern SPM approach with proper target organization
- ✅ Clean module boundaries via target dependencies
- ✅ Works seamlessly with both `swift` CLI and `xcodebuild`
- ✅ No `.xcodeproj` file - Xcode auto-generates workspace from `Package.swift`
- ✅ Cleaner git history without Xcode project file churn

**Target organization:**
- `Vaalin` (executable) → depends on VaalinUI, VaalinParser, VaalinNetwork, VaalinCore
- `VaalinUI` (library) → depends on VaalinCore, VaalinNetwork, VaalinParser
- `VaalinParser` (library) → depends on VaalinCore
- `VaalinNetwork` (library) → depends on VaalinCore, VaalinParser
- `VaalinCore` (library) → no dependencies (foundational models and utilities)

**Key architectural principle**: UI concerns are isolated in VaalinUI package, main app target is minimal.

**File Naming Conventions**:
- Swift files: `PascalCase.swift` (e.g., `GameLogView.swift`)
- Test files: `{FileName}Tests.swift` (e.g., `XMLStreamParserTests.swift`)
- Preview files: `{ComponentName}{StateName}.swift` (e.g., `VitalsPanelPopulatedState.swift`)
  - Organized in `Views/Previews/{ComponentName}/` directories
  - Captured via `scripts/capture-preview.sh` automation

## Critical Implementation Details

### XML Parser - Stateful Chunked Parsing

The game server sends XML in incomplete chunks over TCP. The parser **must maintain state between parse calls**:

```swift
actor XMLStreamParser: NSObject, XMLParserDelegate {
    // CRITICAL: These persist across parse() calls
    private var currentStream: String?  // Tracks active stream ID
    private var inStream: Bool = false  // Stream context flag

    // Per-parse state
    private var tagStack: [GameTag] = []

    func parse(_ chunk: String) async -> [GameTag] {
        // Parse incomplete XML, maintain stream state
    }
}
```

**Stream control tags** (`<pushStream id="X">`, `<popStream>`) must update `currentStream` and persist across chunks.

### Command Sending Integration (Issue #29)

**CommandSending Protocol** enables dependency injection for sending commands:

```swift
/// Protocol for actors that can send commands to the game server
public protocol CommandSending: Actor {
    /// Send a command to the server
    /// - Parameter command: The command string to send
    /// - Throws: Connection errors if send fails
    func send(command: String) async throws
}
```

**Usage in ViewModels**:
```swift
@Observable
@MainActor
class CommandInputViewModel {
    private let connection: (any CommandSending)?

    func submitCommand(handler: (String) -> Void) async {
        // Send via connection if available
        if let connection = connection {
            try? await connection.send(command: command)
        }
        handler(command)
    }
}
```

**Benefits**:
- Clean dependency injection (real connection in production, mock in tests)
- Actor constraint enforces thread safety at compile time
- Testable without network calls

### Parser-Connection Integration (Issue #17)

**ParserConnectionBridge** acts as the integration layer between network and parsing:

```swift
// Architecture
LichConnection (AsyncStream<Data>)
       ↓
ParserConnectionBridge (decode UTF-8, coordinate)
       ↓
XMLStreamParser (parse XML chunks)
       ↓
[GameTag] (accumulated results)
```

**Usage pattern**:
```swift
let connection = LichConnection()
let parser = XMLStreamParser()
let bridge = ParserConnectionBridge(connection: connection, parser: parser)

// Connect to Lich
try await connection.connect(host: "127.0.0.1", port: 8000)

// Start data flow
await bridge.start()

// Access parsed tags periodically
let tags = await bridge.getParsedTags()
// Process tags in UI...

// Clear processed tags
await bridge.clearParsedTags()

// Stop when done
await bridge.stop()
```

**Key responsibilities**:
- Iterates `connection.dataStream` (AsyncStream<Data>)
- Decodes `Data` → `String` (UTF-8) with error handling
- Calls `parser.parse(chunk)` for each chunk
- Accumulates resulting `GameTag` arrays
- Thread-safe via actor isolation
- Resilient error handling (logs & continues on malformed data)

**Error handling**:
- Malformed UTF-8: Logged and skipped
- Parser errors: Logged and continued (returns empty array)
- Connection errors: Logged and stream finished

**Testing**: See `ParserConnectionBridgeTests.swift` and `TestLichConnection` executable.

### Preset-Based Color System

The game server sends styled text via XML preset tags, **not ANSI escape codes**.

**Example XML from server**:
```xml
<preset id="speech">You say, "Hello!"</preset>
<preset id="damage">You take 50 damage!</preset>
<preset id="thought">You ponder the situation</preset>
```

**Architecture**:
1. XMLStreamParser extracts `GameTag(name: "preset", attrs: ["id": "speech"])`
2. ThemeManager loads `Vaalin/Resources/themes/catppuccin-mocha.json` with preset mappings
3. TagRenderer converts `GameTag` → `AttributedString` with colors:
   ```swift
   let presetID = tag.attrs["id"] as? String
   let color = theme.color(forPreset: presetID)
   attributedString.foregroundColor = color
   ```

**Common Preset IDs**:
- `speech`, `whisper`, `thought` - communication
- `damage`, `heal` - combat
- `roomName`, `roomDesc` - navigation
- `bold`, `watching`, `link` - formatting

**Color Mapping** (Catppuccin Mocha):
- `speech` → Green (#a6e3a1)
- `whisper` → Teal (#94e2d5)
- `thought` → Text (#cdd6f4)
- `damage` → Red (#f38ba8)
- `heal` → Green (#a6e3a1)

**Reference**: Illthorn uses same approach - see `src/frontend/styles/_vars.scss` (lines 41-48) for preset-to-color mappings.

### Event Bus - Cross-Component Communication

Critical events emitted by parser:

- `metadata/left`, `metadata/right`, `metadata/spell` → Hands panel
- `metadata/progressBar/{id}` → Vitals panel (health, mana, etc.)
- `metadata/prompt` → Prompt display
- `stream/{id}` → Stream buffers (thoughts, speech, etc.)

Panels subscribe to events via `EventBus` actor.

### Item Categorization - Performance Critical

Item highlighting uses regex patterns on **every item tag** in game output:

```swift
actor ItemCategorizer {
    // 1. Fast O(1) noun lookup for common items
    private var nounLookup: [String: String] = [:]

    // 2. Fallback regex matching for complex patterns
    // 3. LRU cache (1000 entries) for recent categorizations

    // Performance target: < 1ms average per item
    func categorize(noun: String, fullName: String?) async -> ItemCategory?
}
```

Categories: gem, jewelry, weapon, armor, clothing, food, reagent, valuable, box, junk

### Settings Persistence - Atomic Writes

All settings persist to `~/Library/Application Support/Vaalin/settings.json`:

```swift
actor SettingsManager {
    // Debounced auto-save (500ms)
    // Atomic write: temp file + rename
    // Corrupt JSON → fallback to defaults
}
```

Structure: layout, streams, input, theme, network configs

## Reference Implementation

**Illthorn source** at `/Users/trevor/Projects/illthorn/` contains TypeScript reference implementations:

- Parser: `src/frontend/parser/saxophone-parser.ts`
- Hands panel: `src/frontend/components/session/hands/hands-container.lit.ts`
- Vitals panel: `src/frontend/components/session/vitals/vitals-container.lit.ts`
- Item highlighting: `src/frontend/components/game-elements/item-highlighting.ts`
- Command input: `src/frontend/components/command-bar/cli.lit.ts`

**Consult for behavior/edge cases, but reimplement in Swift - do not directly port TypeScript.**

## Task Management

**All tasks tracked as GitHub issues**: https://github.com/TrevorS/vaalin/issues

- 93 total issues organized by phase
- MVP = Issues #1-32 (Foundation + Phase 1 + Phase 2)
- Labels: `component:*`, `type:*`, `complexity:*`

**Integration checkpoints** (mandatory milestones):
- #20: Phase 1 - Parser + Network + Basic UI working
- #32: Phase 2 - Fully playable game
- #47: Phase 3 - All HUD panels updating live
- #58: Phase 4 - Stream filtering working
- #71: Phase 5 - Advanced features functional
- #86: Phase 6 - Production ready

**Do not skip checkpoints** - ensure full integration before proceeding to next phase.

## Development Workflow

1. **Start with Issue #1** - Create Xcode project structure
2. **Follow TDD** - Write tests first when issue indicates TDD approach
3. **Use Xcode Previews** - All SwiftUI views require minimum 2 preview states
4. **SwiftLint compliance** - Code must pass linting
5. **Performance budgets**:
   - Parser: > 10,000 lines/minute throughput
   - Game log: 60fps scrolling performance
   - Memory: < 500MB peak usage
   - Item categorization: < 1ms average

## Testing

### Test Framework

**Swift Testing framework** (not XCTest) for all tests. Swift Testing provides modern async/await support and better integration with Swift concurrency.

### Running Tests

**From Xcode**: `Cmd+U` runs all tests

**From CLI**:
```bash
# Standard: Run all tests with coverage
make test

# Direct xcodebuild: Full control
xcodebuild test \
  -scheme Vaalin \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# Run specific test target
xcodebuild test \
  -scheme Vaalin \
  -destination 'platform=macOS' \
  -only-testing:VaalinParserTests

# Run specific test
xcodebuild test \
  -scheme Vaalin \
  -destination 'platform=macOS' \
  -only-testing:VaalinParserTests/XMLStreamParserTests/test_parseNestedTags
```

### Coverage Reports

**View in terminal**:
```bash
xcrun xccov view --report TestResults.xcresult
```

**Export for CI** (JSON format):
```bash
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

**View in Xcode**: After running tests, open Report Navigator (Cmd+9) → select test run → Coverage tab

### Coverage Requirements

Required coverage by component:
- **Parser logic**: 100% (critical path, complex state management)
- **Business logic** (categorizer, settings, macros): > 80%
- **UI tests**: Critical paths (connect, send command, receive output)

### Performance Testing

Performance tests must assert benchmarks:
- **Parser throughput**: > 10,000 lines/minute
- **Game log scrolling**: 60fps (< 16ms frame time)
- **Memory usage**: < 500MB peak
- **Item categorization**: < 1ms average

**Example performance test**:
```swift
@Test func test_parsePerformance() async throws {
    let parser = XMLStreamParser()
    let largeXML = generateLargeXMLChunk(lineCount: 10_000)

    let start = Date()
    let tags = await parser.parse(largeXML)
    let duration = Date().timeIntervalSince(start)

    #expect(duration < 60.0) // 10k lines in < 60 seconds = > 10k lines/min
}
```

### Test Organization

```
VaalinAppTests/                         # App-level integration tests
├── IntegrationTests/                   # End-to-end flows (Phase checkpoints)
│   ├── Phase1IntegrationTests.swift
│   └── Phase2IntegrationTests.swift
├── PerformanceTests/                   # Benchmark assertions
│   └── ParserPerformanceTests.swift
└── Mocks/                              # Mock data for integration tests

VaalinUI/Tests/VaalinUITests/           # View and ViewModel tests
├── ViewModels/
│   ├── AppStateIntegrationTests.swift
│   ├── GameLogViewModelTests.swift
│   ├── CommandInputViewModelTests.swift
│   ├── PromptViewModelTests.swift
│   └── Panels/
│       ├── HandsPanelViewModelTests.swift
│       ├── VitalsPanelViewModelTests.swift
│       ├── CompassPanelViewModelTests.swift
│       ├── InjuriesPanelViewModelTests.swift
│       └── SpellsPanelViewModelTests.swift
└── Views/
    ├── MainViewTests.swift
    └── Panels/
        ├── VitalsPanelTests.swift
        ├── HandsPanelTests.swift
        └── InjuriesPanelTests.swift

VaalinParser/Tests/VaalinParserTests/
└── XMLStreamParserTests.swift          # Parser unit tests

VaalinNetwork/Tests/VaalinNetworkTests/
├── LichConnectionTests.swift
└── ParserConnectionBridgeTests.swift

VaalinCore/Tests/VaalinCoreTests/
├── GameTagTests.swift
├── MessageTests.swift
├── EventBusTests.swift
└── SettingsTests.swift

TestTools/
└── TestLichConnection/                 # Standalone manual testing tool
```

### CI/CD Integration

For GitHub Actions (TASK-T07):

```yaml
# Example .github/workflows/ci.yml snippet
- name: Run tests with coverage
  run: make test

- name: Generate coverage report
  run: xcrun xccov view --report --json TestResults.xcresult > coverage.json

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.json
```

### Test-Driven Development (TDD)

Tasks marked "TDD" in GitHub issues follow this workflow:
1. Write failing test first
2. Implement minimal code to pass test
3. Refactor for clarity/performance
4. Repeat

TDD is **required** for:
- All parser logic (TASK-P1 series)
- Business logic actors (categorizer, settings manager, event bus)
- Complex algorithms (item categorization, preset color mapping)

## Critical Dependencies

**Lich 5 Connection**: App connects to `localhost:8000` (Lich detachable client mode)

Start Lich with: `lich --without-frontend --detachable-client=8000`

**GemStone IV XML Protocol**: Server sends XML tags like:
- `<pushStream id="thoughts">`, `<popStream>` - Stream routing
- `<a exist="12345" noun="gem">a blue gem</a>` - Interactive objects
- `<prompt>&gt;</prompt>` - Game prompt
- `<progressBar id="health" value="100" left="100" right="100" text="100%">` - Vitals

See GemStone IV Wiki for protocol details: https://gswiki.play.net/Lich_XML_Data_and_Tags

## Code Style

- **SwiftLint**: Configuration enforces style
- **Swift API Design Guidelines**: Follow Apple's conventions
- **Actors for shared mutable state**: Use `actor` keyword, not locks
- **@Observable for view models**: Use macro, not ObservableObject protocol
- **DocC comments**: Required for all public APIs
- **Type annotations**: Always annotate function parameters and return types

## Code Conventions

**File Organization**:
- **ABOUTME comments**: Start all code files with `// ABOUTME: {description}` explaining the file's purpose (aligns with global CLAUDE.md standards)
- **File headers**: Use Xcode default header with project name and copyright
- **Import order**: Foundation/SwiftUI first, then project modules, then third-party (if any)
- **Extensions**: Group in `// MARK: - {Name}` sections

**Naming**:
- **Swift files**: `PascalCase.swift` (e.g., `GameLogView.swift`)
- **Test files**: `{FileName}Tests.swift` (e.g., `XMLStreamParserTests.swift`)
- **View models**: `{Feature}ViewModel.swift` (e.g., `GameLogViewModel.swift`)
- **Actors**: Prefix intention in comments (e.g., `actor XMLStreamParser // Thread-safe XML parser`)

**SwiftUI Specifics**:
- **Previews**: Organized in separate files in component-specific directories (see "Automated Preview Screenshots")
- **Preview requirement**: Minimum 2 states per view (e.g., empty state, populated state)
- **Preview naming**: `{ComponentName}{StateName}.swift` (e.g., `VitalsPanelPopulatedState.swift`)
- **Preview automation**: Use `scripts/capture-preview.sh` for screenshot capture
- **View modifiers**: Chain on separate lines for readability
- **@Observable**: Use for all view models (not `@ObservableObject` or `@StateObject`)

**Testing**:
- **Framework**: Swift Testing (not XCTest)
- **Test naming**: `test_{functionality}()` (e.g., `test_parseNestedTags()`)
- **Async tests**: Use `async` test functions naturally
- **Mocking**: Use protocol-based dependency injection for testability

**Documentation**:
- **Public APIs**: DocC comments required (`///` style)
- **Complex algorithms**: Inline comments explaining "why", not "what"
- **Actor isolation**: Document thread-safety guarantees
- **Performance-critical code**: Document performance targets (e.g., "< 1ms average")

**Example File Structure**:

Main view file (clean, no previews):
```swift
// ABOUTME: GameLogView displays the virtualized scrolling game log with themed preset colors

import SwiftUI
import VaalinParser
import VaalinCore

/// Displays the game log with virtualized scrolling and preset color rendering.
///
/// Performance target: 60fps scrolling with 10,000 line buffer
struct GameLogView: View {
    @Bindable var viewModel: GameLogViewModel

    var body: some View {
        // Implementation...
    }
}
```

Separate preview file (`Views/Previews/GameLogView/GameLogViewStates.swift`):
```swift
// ABOUTME: Preview states for GameLogView

import SwiftUI
@testable import VaalinUI

#Preview("Empty State") {
    GameLogView(viewModel: GameLogViewModel())
}

#Preview("Populated State") {
    GameLogView(viewModel: GameLogViewModel.sampleData())
}
```

## Troubleshooting

### Build Issues

**"No such module" errors**:
```bash
# Clean build and derived data
make clean
rm -rf ~/Library/Developer/Xcode/DerivedData

# Rebuild
make build
```

**"Scheme not found" in CI**:
- Ensure scheme is **Shared** (checked in Xcode: Product → Scheme → Manage Schemes)
- Verify scheme file exists in git: `Vaalin.xcodeproj/xcshareddata/xcschemes/Vaalin.xcscheme`
- Commit and push: `git add Vaalin.xcodeproj/xcshareddata/ && git commit -m "Share Vaalin scheme"`

**Build succeeds in Xcode but fails from CLI**:
- Check xcodebuild command includes `-destination 'platform=macOS'`
- Verify Xcode command-line tools: `xcode-select -p` (should show Xcode.app path)
- Reset command-line tools: `sudo xcode-select --reset`

**KeyPath Sendable warnings (Expected, can be ignored)**:
```
<unknown>:0: warning: cannot form key path that captures non-Sendable type 'KeyPath<AttributeScopes.SwiftUIAttributes, ...>'
Swift.KeyPath:1:14: note: generic class 'KeyPath' does not conform to the 'Sendable' protocol
```

These warnings are **harmless and expected** during Swift 6 migration:
- They originate from Apple's Swift standard library, not our code (note `<unknown>:0` location)
- Occur because `KeyPath` hasn't been made `Sendable` yet in Swift's AttributedString APIs
- Do not indicate actual concurrency safety problems in our code
- Cannot be fixed by us - waiting on Apple to update Swift's standard library
- Will disappear in a future Swift release when Apple makes `KeyPath` conform to `Sendable`
- Safe to ignore - they're warnings, not errors, and don't affect runtime behavior

### Xcode Previews Not Working

**Previews failing to load**:
1. Ensure scheme is set to `Vaalin` (top-left in Xcode)
2. Clean build folder: `Product → Clean Build Folder` (Cmd+Shift+K)
3. Restart Xcode
4. If still failing, check Preview diagnostics: `Editor → Canvas → Diagnostics`

**"Cannot preview in this file" error**:
- Ensure view file imports SwiftUI
- Verify `{ViewName}_Previews` struct conforms to `PreviewProvider`
- Check that preview is defined at file scope (not nested in other types)

### SwiftLint Issues

**Auto-fix violations**:
```bash
make format
# or
swiftlint --fix
```

**Disable specific rule for one line**:
```swift
// swiftlint:disable:next line_length
let veryLongString = "This is an exceptionally long string that would normally trigger a line length violation"
```

**Disable rule for entire file**:
```swift
// swiftlint:disable line_length
// File contents...
```

**Check which rules are enabled**:
```bash
swiftlint rules
```

### Test Failures

**Tests pass locally but fail in CI**:
- Ensure scheme is shared (see "Build Issues" above)
- Check destination platform matches: `-destination 'platform=macOS'`
- Verify SwiftLint passes: `make lint`
- Run tests with exact CI command locally to reproduce

**Async test timeouts**:
- Increase timeout for slow operations: `#expect(timeout: .seconds(10))`
- Check for deadlocks in actor code
- Ensure Task priorities are set correctly

**Flaky tests** (intermittent failures):
- Identify race conditions in test setup/teardown
- Use actors properly for shared mutable state
- Add explicit synchronization points
- Consider marking as `@available(*, deprecated, message: "Flaky test - needs investigation")`

### Performance Issues

**Slow Xcode indexing**:
```bash
# Delete derived data and restart
rm -rf ~/Library/Developer/Xcode/DerivedData
killall Xcode
```

**Slow test execution**:
- Check if tests are running in Debug configuration (slower than Release but needed for debugging)
- Profile tests in Instruments: `Product → Profile` in Xcode
- Reduce test data size for non-performance tests

**Build times too long**:
- Enable parallel builds: Xcode → Preferences → Build → check "Parallelize Build"
- Reduce module interdependencies
- Use `@testable import` only when necessary

### Swift Package Manager Issues

**"Package resolution failed"**:
```bash
# Clear SPM caches
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build/

# In Xcode: File → Packages → Reset Package Caches
```

**"Cannot find type in scope" for package types**:
- Verify package is added to target dependencies in Xcode
- Clean and rebuild: `make clean && make build`
- Check import statements match package names exactly

### Runtime Issues

**App crashes on launch** (after project is created):
- Check entitlements are configured correctly (network access, sandboxing)
- Verify app bundle is code-signed (will be required in Phase 6)
- Check Console.app for crash logs: filter by "Vaalin"

**Connection to Lich fails**:
- Verify Lich is running: `lich --without-frontend --detachable-client=8000`
- Check port is 8000 (or custom port in settings)
- Ensure firewall allows localhost connections
- Test with `nc -v localhost 8000` to verify port is open

### Getting Help

1. Check this Troubleshooting section
2. Search GitHub issues: https://github.com/TrevorS/vaalin/issues
3. Review Apple documentation for Xcode errors
4. Check SwiftLint rules: `swiftlint rules`

## Specialized Agents

Project-specific agents in `.claude/agents/` provide domain expertise:

- **gemstone-xml-expert** - GemStone IV protocol, XML parsing, Lich 5 integration
- **swiftui-macos-expert** - SwiftUI views, macOS 26 Liquid Glass design
- **macos-glass-designer** - UI/UX decisions, visual design, aesthetic reviews
- **swift-test-specialist** - Test writing, coverage analysis, TDD workflow

**When to use:**
- `component:parser` or `component:xml` → gemstone-xml-expert
- `component:ui` or `component:view` → swiftui-macos-expert + macos-glass-designer
- `type:test` or TDD tasks → swift-test-specialist
- Use multiple agents in sequence for comprehensive quality

## Workflow Automation

**`/next-issue` command** - Complete development workflow:
1. Finds next unassigned issue (oldest first)
2. Plans implementation with appropriate agents
3. Writes tests (TDD when specified)
4. Implements feature with specialized agents
5. Runs validation (format, lint, test, build)
6. Creates PR with git-message-crafter agent
7. QA review with domain experts
8. Updates documentation
9. Generates comprehensive summary

Use this for systematic, high-quality issue completion.

## Documentation Files

- `docs/requirements.md` - Complete functional and technical requirements (1438 lines)
- `docs/tasks.md` - Detailed task breakdown (source for GitHub issues) (2620 lines)
- `docs/QUICKSTART.md` - GitHub issues quickstart guide
- `docs/github-issues-summary.md` - Summary of issue conversion
- `/Users/trevor/Projects/illthorn/` - TypeScript reference implementation (consult for behavior, reimplement in Swift)