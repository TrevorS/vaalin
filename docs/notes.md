# Vaalin Development Notes

Working notes and decisions. See `old-docs-summary.md` for consolidated review findings.

## Refinements Applied (2026-02-04)

### Code changes
- **AppState.swift**: Removed unnecessary `as? String` downcast
- **InjuriesPanelViewModel**: Changed logger from `static let` to instance `let` (consistency with other panels)
- **StreamViewModel**: Extracted `renderMessage(_:theme:)` helper, eliminating ~35 lines of duplication between `loadStreamContent()` and `reloadContentWithTheme()`

### Preview consolidation
Deleted 35+ separate preview files. Moved all previews to inline `#Preview` macros in main view files. Simpler organization, easier maintenance.

### Test additions
- XMLStreamParserTests: 5 buffer overflow protection tests
- LichConnectionTests: 7 reconnection logic tests
- MockLichServerScenarioTests: Fixed 2 timing-sensitive tests (200ms -> 500ms timeout)

## Open Improvement Ideas (non-blocking)

These came up during review but aren't blockers:

1. **Generic Registry** — StreamRegistry and PanelRegistry are ~80% identical. Could extract `GenericRegistry<T: Identifiable>` actor.
2. **CommandHistory indexing** — Uses negative indices (0=newest, -1=previous) which is confusing. Standard array indexing or named methods (`previous()`, `next()`) would be clearer.
3. **ThemeManager simplification** — Actor isolation is over-engineered for a read-only cache. Could be a struct with synchronous lookups.
4. **MessageBuffer extraction** — StreamBufferManager and GameLogViewModel both implement circular buffer logic. Extract shared `MessageBuffer<T>`.
5. **`extractTextContent()`** — Appears in both AppState and GameLogViewModel. Could move to GameTag extension if needed elsewhere.

## Liquid Glass Design Notes

Chrome vs content classification used throughout the UI:

**Chrome (translucent .ultraThinMaterial)**: StreamsBarView, CommandInputView, PromptView, ConnectionStatusBar, StreamChip, PanelContainer header

**Content (opaque)**: GameLogView (#1e1e2e), StreamView (#1e1e2e), MainView (.windowBackgroundColor), panel content areas (.controlBackgroundColor)

**Controls (system native)**: ConnectionControlsView (.controlBackgroundColor, .roundedBorder, .borderedProminent)

## Architecture Observations

- All 12 ViewModels use @Observable + @MainActor correctly
- All panel ViewModels use PanelViewModelBase protocol (eliminates ~150 lines of duplication)
- GameLogView and StreamView both use NSViewRepresentable with TextKit 1 for 10k+ line performance
- EventBus uses value-type Handler struct — no retain cycles possible
- Only one [weak self] needed in the entire codebase (GameLogView auto-scroll Task)
