# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vaalin is a native macOS SwiftUI application for playing GemStone IV (a text-based MUD) via Lich 5's detachable client mode. It replaces the Illthorn Electron/TypeScript client with modern Swift.

**Target**: macOS 26+ (Tahoe) with Liquid Glass design language
**Language**: Swift 5.9+ with strict concurrency (`StrictConcurrency` enabled in Package.swift)
**Architecture**: Actor-based SwiftUI with Swift Package Manager modular structure
**Build system**: Pure SPM (no `.xcodeproj` — Xcode auto-generates workspace from `Package.swift`)

## Development Commands

```bash
make build     # swift build (Debug)
make test      # swift test --enable-code-coverage
make format    # swiftlint --fix
make lint      # swiftlint (fails on violations)
make run       # Build and launch Vaalin.app bundle (scripts/run-app.sh)
make clean     # Remove .build/ and DerivedData
```

**Run a single test target:**
```bash
swift test --filter VaalinParserTests
```

**Run a single test by name:**
```bash
swift test --filter "test_parseNestedTags"
```

**Prerequisites**: Xcode 16.0+, SwiftLint (`brew install swiftlint`)

## Architecture

### Package Structure

Single `Package.swift` at root defines all targets:

```
Vaalin (executable) → VaalinUI, VaalinParser, VaalinNetwork, VaalinCore
VaalinUI (library)  → VaalinCore, VaalinNetwork, VaalinParser
VaalinParser        → VaalinCore
VaalinNetwork       → VaalinCore, VaalinParser
VaalinCore          → (no dependencies — foundational models/utilities)
```

### Data Flow

```
Lich 5 (TCP :8000)
       ↓
LichConnection (actor, NWConnection, AsyncStream<Data>)
       ↓
ParserConnectionBridge (actor, UTF-8 decode, coordinate)
       ↓
XMLStreamParser (actor, SAX-based, stateful across chunks)
       ↓
[GameTag] → EventBus (metadata events for panels)
       ↓
AppState (MainActor, polls bridge every 100ms)
  ├─ StreamRouter → StreamBufferManager (stream content)
  ├─ GameLogViewModel → GameLogView (main log)
  ├─ Panel ViewModels (subscribe to EventBus events)
  └─ CommandInputViewModel → LichConnection.send()
```

### Key Patterns

- **Actors for shared state**: `XMLStreamParser`, `LichConnection`, `ParserConnectionBridge`, `EventBus`, `StreamRegistry`, `PanelRegistry`, `StreamBufferManager`, `StreamRouter` are all actors
- **@Observable for view models**: All view models use the `@Observable` macro (not `ObservableObject`), are `@MainActor`
- **EventBus pub/sub**: Parser publishes metadata events (`metadata/left`, `metadata/right`, `metadata/progressBar/{id}`, `metadata/prompt`, `stream/{id}`); panel view models subscribe
- **CommandSending protocol**: Actor-constrained protocol for dependency injection of command sending (real connection vs. mock in tests)
- **Polling bridge**: AppState decouples actor-based components from @Observable view models by polling ParserConnectionBridge on the main thread

### XML Parser — Stateful Chunked Parsing

The game server sends incomplete XML chunks over TCP. The parser **maintains state between parse() calls** — `currentStream` and `inStream` persist across chunks. Stream control tags (`<pushStream id="X">`, `<popStream>`) update this persistent state.

### Stream Routing

StreamRouter routes parsed stream content to StreamBufferManager buffers. Mirror mode (default ON) shows stream content in both the stream buffer and the main game log. When OFF, stream content only appears in the dedicated stream view.

### Preset-Based Color System

The server sends styled text via XML preset tags (not ANSI): `<preset id="speech">`, `<preset id="damage">`, etc. ThemeManager loads color mappings (Catppuccin Mocha), and TagRenderer converts GameTag → AttributedString with colors.

### Three-Layer Tag Filtering

Metadata tags (vitals, hands, spells, etc.) must not appear as blank lines in the game log:
1. **Parser layer**: Publishes metadata events to EventBus for panel consumption
2. **AppState layer**: Filters metadata tags from the game log feed
3. **View layer**: `GameLogViewModel.hasContentRecursive()` catches remaining empties

## Testing

**Framework**: Swift Testing (not XCTest). Use `@Test`, `#expect`, `async` test functions.

**Test naming**: `test_{functionality}()` (e.g., `test_parseNestedTags()`)

**Test targets**: `VaalinCoreTests`, `VaalinParserTests`, `VaalinNetworkTests`, `VaalinUITests`, `VaalinTests` (app-level integration)

**Coverage targets**: Parser logic 100%, business logic >80%, UI critical paths covered.

**Performance budgets**: Parser >10k lines/min, game log 60fps, memory <500MB, item categorization <1ms.

## Code Conventions

- **ABOUTME comments**: Every file starts with `// ABOUTME: {description}`
- **Import order**: Foundation/SwiftUI first, then project modules
- **SwiftLint**: Config in `.swiftlint.yml` — 120 char line warning, 150 error; tests excluded from linting; `print()` forbidden (use `os.Logger`)
- **@Observable**: Always use this macro, never `@ObservableObject` or `@StateObject`
- **Actors**: Use for all shared mutable state, never locks

## GemStone IV Protocol Reference

**Connection**: `localhost:8000` (Lich detachable client mode)
Start Lich: `lich --without-frontend --detachable-client=8000`

**Key XML tags from server**:
- `<pushStream id="thoughts">` / `<popStream>` — Stream routing
- `<a exist="12345" noun="gem">a blue gem</a>` — Interactive objects
- `<prompt>&gt;</prompt>` — Game prompt
- `<progressBar id="health" value="100">` — Vitals
- `<preset id="speech">You say, "Hello!"</preset>` — Styled text

Protocol docs: https://gswiki.play.net/Lich_XML_Data_and_Tags

## Reference Implementation

Illthorn source at `/Users/trevor/Projects/illthorn/` has TypeScript reference implementations for parser, panels, item highlighting, and command input. Consult for behavior/edge cases but reimplement in Swift — do not port TypeScript directly.

## Task Management

All tasks tracked as GitHub issues: https://github.com/TrevorS/vaalin/issues

**Integration checkpoints** (mandatory milestones):
- #20: Phase 1 — Parser + Network + Basic UI
- #32: Phase 2 — Fully playable game
- #47: Phase 3 — All HUD panels updating live
- #58: Phase 4 — Stream filtering working
- #71: Phase 5 — Advanced features functional
- #86: Phase 6 — Production ready

Do not skip checkpoints.

## Troubleshooting

**"No such module" errors**: `make clean && rm -rf ~/Library/Developer/Xcode/DerivedData && make build`

**KeyPath Sendable warnings**: Harmless Apple stdlib issue (`<unknown>:0` location). Cannot be fixed by us, safe to ignore.

**SPM resolution failed**: `rm -rf ~/Library/Caches/org.swift.swiftpm .build/`

**Connection to Lich fails**: Verify `lich --without-frontend --detachable-client=8000` is running, test with `nc -v localhost 8000`

## Specialized Agents

Project-specific agents in `.claude/agents/`:

- **gemstone-xml-expert** — GemStone IV protocol, XML parsing, Lich 5 integration
- **swiftui-macos-expert** — SwiftUI views, macOS 26 Liquid Glass design
- **macos-glass-designer** — UI/UX decisions, visual design, aesthetic reviews
- **swift-test-specialist** — Test writing, coverage analysis, TDD workflow

## Documentation

- `docs/requirements.md` — Functional and technical requirements
- `docs/tasks.md` — Detailed task breakdown (source for GitHub issues)
