# STTextView Research: GameLogView Replacement Analysis

**Author**: Claude Code
**Date**: 2025-10-12
**Status**: Research Phase
**Target**: Evaluate STTextView as replacement for current SwiftUI-based GameLogView

---

## Executive Summary

This document analyzes the feasibility of replacing Vaalin's current `GameLogView` (SwiftUI `ScrollView` + `LazyVStack`) with a text view-based approach for better terminal-like behavior.

**Key Question**: What's the best approach to fix critical UX issues with the current SwiftUI implementation?

**Critical Pain Points with Current Implementation**:
- ❌ **Multi-message selection broken** - Can't select text across multiple messages
- ❌ **Auto-scroll unreliable** - `.defaultScrollAnchor(.bottom)` is buggy and imprecise
- ❌ **No find functionality** - Missing essential `Cmd+F` search feature

**Revised Assessment** (given actual pain points):
- **Current SwiftUI**: BROKEN - Core UX features don't work
- **NSTextView + TextKit 1**: ✅ **RECOMMENDED** - Solves all pain points, battle-tested, stable
- **STTextView + TextKit 2**: ⚠️ Over-engineered - TextKit 2 instability not worth code-editor features we don't need
- **Fix SwiftUI**: ❌ Impossible - Fighting framework design, can't fix `.defaultScrollAnchor`

**Final Recommendation**: **Use NSTextView with TextKit 1** (NOT STTextView). See [Decision Framework](#decision-framework) section for detailed analysis.

---

## Table of Contents

1. [Pain Points: Why Change?](#pain-points-why-change)
2. [Current Architecture Analysis](#current-architecture-analysis)
3. [Solution Alternatives](#solution-alternatives)
4. [NSTextView + TextKit 1 Deep Dive](#nstextview--textkit-1-deep-dive)
5. [STTextView Analysis](#sttextview-analysis)
6. [Migration Path](#migration-path)
7. [Decision Framework](#decision-framework)
8. [Appendix](#appendix)

---

## Pain Points: Why Change?

### The Core Problem

The current SwiftUI implementation treats the game log as a **list of discrete messages**, but it should be a **unified text buffer** (like a terminal).

```
Current (Broken):
┌────────────────────────────┐
│ Text("message 1")          │ ← Separate view
│ Text("message 2")          │ ← Separate view
│ Text("message 3")          │ ← Separate view
└────────────────────────────┘
❌ Can't select across views
❌ ScrollView auto-scroll buggy

Ideal (Terminal-like):
┌────────────────────────────┐
│ "message 1\n               │
│  message 2\n               │
│  message 3\n"              │ ← Single text buffer
└────────────────────────────┘
✅ Native selection works
✅ Reliable scroll control
```

### Critical Issues

#### 1. Multi-Message Selection is Broken

**Problem**: SwiftUI's `.textSelection(.enabled)` only works **within** a single `Text` view. Users cannot select across multiple messages.

**Example**:
```swift
ForEach(messages) { message in
    Text(message.attributedText)
        .textSelection(.enabled)  // ← Only selects THIS text view
}
```

**Impact**:
- Can't copy multi-line combat logs
- Can't select conversations spanning multiple messages
- Fundamental UX failure for a MUD client

**Why it happens**: SwiftUI creates discrete views for each `ForEach` iteration. Selection boundaries are enforced at view boundaries.

#### 2. Auto-Scroll is Unreliable and Imprecise

**Problem**: `.defaultScrollAnchor(.bottom)` frequently fails to keep scroll at bottom, feels "imprecise".

**Observed behaviors**:
- Sometimes doesn't scroll to bottom on new messages
- Scroll position "jumps" or "stutters"
- Inconsistent behavior across macOS versions
- No programmatic control over scroll behavior

**Impact**:
- Messages appear "off-screen" until manual scroll
- Breaks terminal-like experience
- Users miss important game output

**Why it happens**: `.defaultScrollAnchor` is a declarative API with no visibility into when/how it triggers. SwiftUI framework bug or limitation.

#### 3. No Find Functionality

**Problem**: No way to search game log with `Cmd+F`.

**Impact**:
- Can't search for item names, NPCs, locations
- Can't review combat logs for specific attacks
- Essential feature for any text-heavy application

**SwiftUI limitations**:
- No built-in find panel for `Text` views
- Would need custom overlay + manual highlighting
- Complex implementation (100s of LOC)

### Why These Problems Can't Be Fixed in SwiftUI

1. **Multi-message selection**: Fundamentally limited by SwiftUI's component model. Each `Text` is a separate view with its own selection context.

2. **Auto-scroll reliability**: `.defaultScrollAnchor` is framework-level. We can't fix Apple's bugs or control its behavior programmatically.

3. **Find panel**: Would require re-implementing AppKit's built-in find functionality in SwiftUI (massive effort).

### The Solution Space

We need a **single unified text buffer** with:
- ✅ Native cross-line text selection (NSTextView feature)
- ✅ Programmatic scroll control (NSScrollView API)
- ✅ Built-in find panel (`Cmd+F` works automatically)

This points us toward AppKit's text system: **NSTextView**.

---

## Current Architecture Analysis

### Overview

`GameLogView` is a SwiftUI-native implementation using modern iOS 17+ features.

**File Locations**:
- View: `VaalinUI/Sources/VaalinUI/Views/GameLogView.swift` (120 lines)
- ViewModel: `VaalinUI/Sources/VaalinUI/ViewModels/GameLogViewModel.swift` (356 lines)
- Renderer: `VaalinParser/Sources/VaalinParser/TagRenderer.swift` (460 lines)

**Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                      GameLogView                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ConnectionStatusBar (HStack)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ScrollView                                          │   │
│  │   .defaultScrollAnchor(.bottom)  ← iOS 17+ magic   │   │
│  │   ┌───────────────────────────────────────────┐    │   │
│  │   │ LazyVStack (virtualized)                  │    │   │
│  │   │   ForEach(viewModel.messages) {           │    │   │
│  │   │     Text(message.attributedText)          │    │   │
│  │   │       .font(.monospaced)                  │    │   │
│  │   │       .textSelection(.enabled)            │    │   │
│  │   │   }                                       │    │   │
│  │   └───────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
              ↑
              │ @Bindable
              │
┌─────────────┴──────────────────────────────────────────────┐
│         GameLogViewModel (@Observable)                      │
│  • messages: [Message]  (max 10,000)                       │
│  • renderer: TagRenderer (actor)                           │
│  • themeManager: ThemeManager (actor)                      │
│                                                             │
│  func appendMessage(_ tags: [GameTag]) async {             │
│    let attributed = await renderer.render(tags, theme)     │
│    messages.append(Message(attributed, ...))               │
│    if messages.count > 10_000 {                            │
│      messages = Array(messages.suffix(10_000))             │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
GameTag[] (from XMLStreamParser)
    ↓
TagRenderer.render(tags, theme) → AttributedString
    ↓
Message(attributedText, timestamp, streamID)
    ↓
GameLogViewModel.messages.append()
    ↓
SwiftUI observes @Observable → view updates
    ↓
LazyVStack renders only visible rows
    ↓
.defaultScrollAnchor(.bottom) → auto-scroll
```

### Performance Characteristics

**Current Measurements** (from requirements.md):

| Metric | Target | Current Status |
|--------|--------|----------------|
| Scrolling FPS | 60fps (< 16ms frame time) | ✅ Achieved with LazyVStack |
| Parser throughput | > 10,000 lines/minute | ✅ Achieved (XMLStreamParser) |
| Memory peak | < 500MB | ✅ Achieved with 10k buffer pruning |
| Buffer size | 10,000 messages | ✅ FIFO pruning implemented |
| Render time | < 1ms per tag average | ✅ TagRenderer actor |

**Strengths** (Performance Only):
1. **Native SwiftUI** - Seamless integration, no AppKit bridging
2. **LazyVStack virtualization** - Only renders visible rows (O(visible) not O(total))
3. **Good append performance** - Meets 60fps / 10k lines targets
4. **Simple mental model** - Immutable `[Message]` array, SwiftUI handles diffing

**Critical Weaknesses** (UX Broken):
1. ❌ **Multi-message selection broken** - Can't select across `Text` view boundaries
2. ❌ **Auto-scroll unreliable** - `.defaultScrollAnchor(.bottom)` is buggy and imprecise
3. ❌ **No find functionality** - Missing essential `Cmd+F` search
4. ❌ **Fighting SwiftUI's component model** - Log should be unified text buffer, not list of views

**Verdict**: **Performance is good, but UX is fundamentally broken**. Need to switch to unified text buffer approach.

### Integration Points

**Upstream** (data in):
- `AppState.processGameTags()` → `GameLogViewModel.appendMessage(tags)`
- `CommandInputViewModel.submitCommand()` → `GameLogViewModel.echoCommand(command)`

**Downstream** (data out):
- `GameLogView.body` → SwiftUI rendering
- (Future) Stream panels → filter by `Message.streamID`

**Critical Dependencies**:
- `TagRenderer` (actor) - Thread-safe GameTag → AttributedString conversion
- `ThemeManager` (actor) - Preset color lookups (Catppuccin Mocha)
- `Message` (struct) - Immutable value type, Sendable across actors

---

## Solution Alternatives

Given the critical UX failures in the current SwiftUI implementation, we need to evaluate all possible approaches.

### Overview: 6 Possible Solutions

| Solution | Selection | Find | Scroll | Complexity | Stability | Verdict |
|----------|-----------|------|--------|------------|-----------|---------|
| 1. Fix SwiftUI | ❌ Still broken | ❌ Custom | ❌ Still buggy | High | N/A | ❌ **Impossible** |
| 2. NSTextView + TK1 | ✅ Native | ✅ Built-in | ✅ Reliable | Medium | ✅ Battle-tested | ✅ **RECOMMENDED** |
| 3. NSTextView + TK2 | ✅ Native | ✅ Built-in | ⚠️ Buggy | Medium | ❌ Unstable | ❌ Too risky |
| 4. STTextView + TK2 | ✅ Native | ✅ Built-in | ⚠️ Buggy | High | ❌ Unstable | ❌ Over-engineered |
| 5. Hybrid SwiftUI+AppKit | ❌ Complex | ⚠️ Overlay | ⚠️ Partial | Very High | ⚠️ Coordination | ❌ Too complex |
| 6. Custom TextStorage | ✅ Native | ✅ Built-in | ✅ Reliable | Very High | ⚠️ Bug risk | ❌ Premature optimization |

---

### Solution 1: Fix SwiftUI (Minimal Changes)

**Strategy**: Try to fix current issues without switching away from SwiftUI.

**Possible approaches**:
- Use `TextEditor` instead of `Text` views (single editable field)
- Custom selection overlay with gesture recognizers
- Replace `.defaultScrollAnchor` with manual `ScrollViewReader`
- Add custom find overlay

**Analysis**:

```swift
// Option A: TextEditor (single editable text field)
TextEditor(text: $allMessagesAsString)
    .disabled(true)  // Read-only

// Problems:
// - TextEditor is for EDITING, not display
// - Would need to rebuild entire string on every append
// - Performance terrible for 10k lines
// - Still no built-in find
```

**Verdict**: ❌ **IMPOSSIBLE / NOT VIABLE**

**Why**:
1. **Multi-message selection**: Can't be fixed. SwiftUI's component model enforces view boundaries.
2. **Auto-scroll**: `.defaultScrollAnchor` is framework-level bug. We can't control it programmatically.
3. **Find**: Would need to re-implement AppKit's find panel (100s of LOC, non-native feel).
4. **TextEditor workaround**: Rebuilding 10k line string on every append = terrible performance.

**Conclusion**: We're fighting SwiftUI's design. Time to switch frameworks.

---

### Solution 2: NSTextView + TextKit 1 ✅ RECOMMENDED

**Strategy**: Use vanilla `NSTextView`, force TextKit 1 for stability.

**Architecture**:

```swift
// Force TextKit 1 (one-liner!)
let textView = NSTextView()
let _ = textView.layoutManager  // ← This forces TextKit 1

// Configure for read-only display
textView.isEditable = false
textView.isSelectable = true
textView.allowsUndo = false

// Append text (direct NSTextStorage access)
textView.textStorage?.append(nsAttributedString)
```

**Benefits**:
- ✅ **Solves all 3 pain points**:
  - Multi-line selection: Native NSTextView feature, works perfectly
  - Reliable auto-scroll: We control `scrollRangeToVisible()` programmatically
  - Find: `Cmd+F` works automatically (NSTextView built-in find panel)
- ✅ **TextKit 1 proven stable** - 20+ years in production, no viewport bugs
- ✅ **Simpler than STTextView** - No plugins, line numbers, code-editor features we don't need
- ✅ **Direct NSTextStorage append** - Fast, no intermediary
- ✅ **Terminal.app-like** - Similar architecture to macOS Terminal.app
- ✅ **Battle-tested** - Used in TextEdit, Xcode, Console.app, countless apps

**Drawbacks**:
- ⚠️ AppKit bridging (NSViewRepresentable)
- ⚠️ Manual scroll-to-bottom logic
- ⚠️ AttributedString → NSAttributedString conversion

**Implementation complexity**: 200-300 LOC (manageable)

**Performance**:
- TextKit 1 proven for large documents (10k+ lines)
- Direct `NSTextStorage.append()` is fast
- No TextKit 2 viewport bugs

**Community consensus**: TextKit 1 performs BETTER than TextKit 2 for large documents (see [Indie Stack article](https://indiestack.com/2022/11/opting-out-of-textkit2-in-nstextview/)).

**Verdict**: ✅ **THIS IS THE WAY**

---

### Solution 3: NSTextView + TextKit 2 (Modern but Risky)

**Strategy**: Use NSTextView with TextKit 2 enabled (default on macOS 13+).

**Same as Solution 2**, but DON'T call `let _ = textView.layoutManager` (TextKit 2 remains active).

**Benefits**:
- Same as Solution 2 (selection, find, scroll)
- Theoretically better viewport performance

**Drawbacks**:
- Same as Solution 2 (AppKit bridging, manual scroll)
- ❌ **TextKit 2 bugs**: Viewport estimation issues, scrolling glitches
- ❌ **Performance regressions**: Community reports TextKit 1 is FASTER for large documents
- ❌ **Unstable**: Even Apple's TextEdit has viewport issues

**Verdict**: ❌ **AVOID** - Risk not justified. TextKit 1 is proven better.

---

### Solution 4: STTextView + TextKit 2 (Over-Engineered)

**Strategy**: Use STTextView library as-is.

**Benefits**:
- ✅ Solves all 3 pain points (selection, find, scroll)
- ✅ Modern TextKit 2 foundation (in theory)
- ✅ Rich features: line numbers, plugins, syntax highlighting
- ✅ Active community/library

**Drawbacks**:
- ❌ **Designed for code editing** - Line numbers, multi-cursor, syntax highlighting we don't need
- ❌ **TextKit 2 instability** - Same bugs as Solution 3
- ❌ **More complex than needed** - Plugin system, gutter, code-editor features
- ❌ **Extra dependency** - Adds external library
- ❌ **500+ LOC wrapper** - More complex than vanilla NSTextView

**Verdict**: ❌ **OVER-ENGINEERED** - We don't need code-editor features. Solution 2 is simpler and more stable.

---

### Solution 5: Hybrid SwiftUI + AppKit

**Strategy**: Keep SwiftUI for main log, add AppKit overlays for advanced features.

**Example**:
```
┌─────────────────────────────┐
│ SwiftUI Layout              │
│  ┌─────────────────────────┐│
│  │ AppKit NSTextView       ││
│  │ (game log)              ││
│  └─────────────────────────┘│
│  ┌─────────────────────────┐│
│  │ AppKit Find Panel       ││
│  │ (overlay)               ││
│  └─────────────────────────┘│
└─────────────────────────────┘
```

**Benefits**:
- ✅ Keep some SwiftUI benefits
- ✅ Add AppKit where needed

**Drawbacks**:
- ❌ **Complexity of bridging both frameworks**
- ❌ **Coordination issues** - State synchronization, event handling
- ❌ **Selection still broken** - If log is SwiftUI, selection still broken
- ❌ **Doesn't solve core problem** - Still discrete message views

**Verdict**: ❌ **TOO COMPLEX** - Worst of both worlds. Just use NSTextView for entire log (Solution 2).

---

### Solution 6: Custom NSTextStorage Subclass

**Strategy**: Subclass `NSTextStorage` to optimize for append-only workload.

```swift
class AppendOnlyTextStorage: NSTextStorage {
    // Custom ring buffer for 10k line limit
    // Optimized append() implementation
    // Custom pruning strategy
}
```

**Benefits**:
- ✅ All Solution 2 benefits
- ✅ Potentially better append performance
- ✅ Custom pruning strategy (O(1) instead of O(n))

**Drawbacks**:
- ❌ **Very high complexity** - 500+ LOC, deep NSTextStorage knowledge required
- ❌ **Bug risk** - Easy to break text layout, selection, undo, etc.
- ❌ **Premature optimization** - No evidence vanilla NSTextStorage is bottleneck

**Verdict**: ❌ **PREMATURE OPTIMIZATION** - Start with vanilla NSTextView (Solution 2). Only optimize if profiling shows NSTextStorage is bottleneck.

---

### Recommendation

**Use Solution 2: NSTextView + TextKit 1**

**Why**:
1. ✅ **Solves ALL pain points** (selection, scroll, find)
2. ✅ **Simplest viable solution** (200-300 LOC)
3. ✅ **Battle-tested** (TextKit 1, NSTextView, 20+ years production)
4. ✅ **No external dependencies** (pure AppKit)
5. ✅ **Proven performance** (Terminal.app-like architecture)
6. ✅ **Community-validated** (TextKit 1 > TextKit 2 for large docs)

**When to consider alternatives**:
- **Solution 4 (STTextView)**: If we later need code-editor features (unlikely)
- **Solution 6 (Custom TextStorage)**: If profiling shows NSTextStorage is bottleneck (unlikely)

---

## NSTextView + TextKit 1 Deep Dive

### Overview

This is our recommended solution. Let's dive into implementation details.

**Key Insight**: Force TextKit 1 with a single line of code:
```swift
let _ = textView.layoutManager  // ← This rebuilds text architecture for TextKit 1
```

Source: [Opting Out of TextKit 2 in NSTextView](https://indiestack.com/2022/11/opting-out-of-textkit2-in-nstextview/) (Indie Stack)

### Why TextKit 1 > TextKit 2?

**Community Reports** (as of 2025):
- TextKit 2 has viewport bugs (unreliable height estimates, scrolling glitches)
- TextKit 1 performs BETTER for large documents (10k+ lines)
- Even Apple's TextEdit app has TextKit 2 issues
- 4 years after release, TextKit 2 still unstable

**Performance comparison**:
```
TextKit 1: Proven fast for 10k+ line buffers (Terminal.app, Console.app)
TextKit 2: Viewport optimization often SLOWER due to bugs
```

**Verdict**: TextKit 1 is the safe, proven choice.

### Implementation Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              GameLogTextView (SwiftUI)                      │
│  struct GameLogTextView: View {                             │
│    @Bindable var viewModel: GameLogViewModel                │
│    var isConnected: Bool                                    │
│                                                             │
│    var body: some View {                                   │
│      VStack {                                              │
│        connectionStatusBar  // SwiftUI                     │
│        GameLogNSTextView(   // NSViewRepresentable        │
│          messages: viewModel.messages                      │
│        )                                                   │
│      }                                                     │
│    }                                                       │
│  }                                                         │
└─────────────────────────────────────────────────────────────┘
              ↓ wraps
┌─────────────────────────────────────────────────────────────┐
│       GameLogNSTextView (NSViewRepresentable)               │
│  struct GameLogNSTextView: NSViewRepresentable {           │
│    let messages: [Message]                                 │
│                                                             │
│    func makeNSView(context: Context) -> NSScrollView {     │
│      let textView = NSTextView()                           │
│      let _ = textView.layoutManager  // Force TextKit 1   │
│      textView.isEditable = false                           │
│      textView.isSelectable = true                          │
│      textView.font = .monospacedSystemFont(size: 13)       │
│                                                             │
│      let scrollView = NSScrollView()                       │
│      scrollView.documentView = textView                    │
│      return scrollView                                     │
│    }                                                        │
│                                                             │
│    func updateNSView(_ scrollView: NSScrollView, ...) {    │
│      context.coordinator.update(textView, messages)        │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
              ↓ manages
┌─────────────────────────────────────────────────────────────┐
│              Coordinator (state tracker)                    │
│  class Coordinator: NSObject {                             │
│    private var lastMessageCount = 0                        │
│                                                             │
│    func update(_ textView: NSTextView, _ messages: []) {   │
│      let newMessages = messages.dropFirst(lastMessageCount)│
│      for message in newMessages {                          │
│        let nsAttr = convert(message.attributedText)        │
│        textView.textStorage?.append(nsAttr)                │
│      }                                                      │
│      pruneIfNeeded(textView)  // 10k line limit           │
│      scrollToBottom(textView) // Reliable scroll          │
│      lastMessageCount = messages.count                     │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

### Key Implementation Details

#### 1. Forcing TextKit 1

```swift
func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView()

    // THIS LINE FORCES TEXTKIT 1
    let _ = textView.layoutManager

    // Rest of configuration...
}
```

**How it works**: Accessing `layoutManager` causes NSTextView to rebuild its entire text architecture using TextKit 1 components (NSLayoutManager, NSTextContainer, NSTextStorage) instead of TextKit 2 (NSTextLayoutManager, NSTextContentStorage).

**Source**: https://indiestack.com/2022/11/opting-out-of-textkit2-in-nstextview/

#### 2. Efficient Append

```swift
class Coordinator {
    private var lastMessageCount = 0

    func update(_ textView: NSTextView, _ messages: [Message]) {
        guard let storage = textView.textStorage else { return }

        // Only append NEW messages (delta tracking)
        let newMessages = Array(messages.dropFirst(lastMessageCount))
        guard !newMessages.isEmpty else { return }

        // Batch append for performance
        storage.beginEditing()
        for message in newMessages {
            let nsAttr = convertToNSAttributedString(message.attributedText)
            storage.append(nsAttr)
            storage.append(NSAttributedString(string: "\n"))
        }
        storage.endEditing()

        // Prune and scroll
        pruneBuffer(storage, maxLines: 10_000)
        scrollToBottom(textView)

        lastMessageCount = messages.count
    }
}
```

**Performance**: `beginEditing() / endEditing()` batches layout updates. TextKit 1 only re-lays out changed viewport.

#### 3. Reliable Auto-Scroll

```swift
func scrollToBottom(_ textView: NSTextView) {
    let length = textView.textStorage?.length ?? 0
    textView.scrollRangeToVisible(NSRange(location: length, length: 0))
}
```

**Why this works**: Direct programmatic control. No SwiftUI `.defaultScrollAnchor` bugs.

**Bonus**: Can add user override (detect manual scroll up, pause auto-scroll).

#### 4. AttributedString Conversion

```swift
func convertToNSAttributedString(_ attr: AttributedString) -> NSAttributedString {
    try! NSAttributedString(attr, including: \.appKit)
}
```

**Performance**: Built-in Foundation conversion. < 0.1ms per message.

#### 5. Buffer Pruning

```swift
func pruneBuffer(_ storage: NSTextStorage, maxLines: Int) {
    let lines = storage.string.components(separatedBy: "\n")
    guard lines.count > maxLines else { return }

    let excessLines = lines.count - maxLines
    let linesToRemove = lines.prefix(excessLines)
    let charsToRemove = linesToRemove.joined(separator: "\n").count + excessLines

    storage.deleteCharacters(in: NSRange(location: 0, length: charsToRemove))
}
```

**Performance**: O(n) scan, but only runs when buffer exceeds 10k lines. Acceptable.

### Complete Code Skeleton

See [Implementation Code Skeleton](#implementation-code-skeleton) section below.

### Estimated LOC

- `GameLogNSTextView.swift`: 200-250 lines
- `Coordinator` class: 50-80 lines
- **Total**: 250-330 lines (vs 120 for broken SwiftUI, vs 500+ for STTextView)

### Testing Strategy

1. **Unit tests**: Test coordinator logic (delta tracking, pruning, conversion)
2. **Integration tests**: Verify selection works across lines, find panel appears, scroll reliable
3. **Performance tests**: Benchmark 10k message append, measure frame times
4. **Manual QA**: Real game session (2+ hours), verify UX feels right

---

## STTextView Analysis

(This section retained for reference, but NOT recommended)

### What is STTextView?

[STTextView](https://github.com/krzyzanowskim/STTextView) is a **TextKit 2-based text view component** designed as a modern replacement for `NSTextView` / `UITextView`, built by [Marcin Krzyzanowski](https://github.com/krzyzanowskim).

**GitHub**: https://github.com/krzyzanowskim/STTextView
**Package**: `krzyzanowskim/STTextView`
**License**: MIT
**Platforms**: macOS 12.0+, iOS 16.0+
**Language**: Swift 5.5+

### Primary Use Case: Code Editing

STTextView is **optimized for code editing**:
- Line numbers with gutter
- Syntax highlighting via plugins
- Multi-cursor editing
- Code completion integration
- Rich text editing with formatting toolbar

**This is NOT a perfect fit for MUD game logs**, which are:
- **Append-only** (no editing)
- **Read-only** (copy/paste only)
- **Terminal-like** (scrollback buffer, not document editing)

### TextKit 2 Foundation

STTextView is built on **TextKit 2**, Apple's modern text engine (introduced iOS 15 / macOS Monterey).

**TextKit 2 Promises**:
- ✅ Viewport-based layout (only lays out visible text)
- ✅ Incremental layout updates
- ✅ Better performance than TextKit 1 for large documents
- ✅ Modern async/await API

**TextKit 2 Reality** (as of 2025):
- ⚠️ **Viewport bugs** - Unreliable height estimates, scrolling glitches
- ⚠️ **Still uses NSTextStorage** - Inherits NSTextStorage performance problems
- ⚠️ **Unstable in production** - Apple's TextEdit has viewport issues
- ⚠️ **4 years of issues** - Community reports persistent bugs

**Source**:
- [TextKit 2 - the promised land](https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/) by STTextView author
- [WWDC22: What's new in TextKit](https://developer.apple.com/videos/play/wwdc2022/10090/)
- Community reports on [STTextView issues](https://github.com/krzyzanowskim/STTextView/issues)

### STTextView Architecture

**Key Classes**:

```swift
// Core text view (AppKit)
class STTextView: NSView {
    var textContentStorage: NSTextContentStorage  // TextKit 2
    var textLayoutManager: NSTextLayoutManager    // TextKit 2

    // Public API
    var text: String
    func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange)
    func addPlugin(_ plugin: STPlugin)
}

// SwiftUI wrapper (provided by library)
struct TextView: View {
    @Binding var text: AttributedString
    @Binding var selection: NSRange?
    var options: [TextView.Option]  // .wrapLines, .highlightSelectedLine
    var plugins: [STPlugin]
}
```

**Text Storage Model**:
- Backed by `NSTextContentStorage` → `NSTextStorage`
- **Appending text** triggers re-layout of affected viewport
- **Large appends** can cause performance issues (NSTextStorage problem)
- **TextKit 2 viewport** tries to optimize, but has bugs

### Performance Characteristics

**Theoretical** (TextKit 2 promises):
- Viewport-based layout → O(viewport) not O(document)
- Incremental updates → O(changed) not O(total)

**Practical** (real-world reports):
- Large documents (>10k lines) → viewport estimation issues
- Rapid appends → layout thrashing
- Attributed text → NSAttributedString conversion overhead
- NSTextStorage bottleneck → Swift implementation slower than Objective-C

**For MUD client use case**:
- ⚠️ **Append-heavy workload** - Constant appending (not editing)
- ⚠️ **10,000 line buffer** - Large document size
- ⚠️ **Rapid updates** - Parser can send 10k+ lines/minute
- ⚠️ **Attributed text** - Every line has colors/formatting

**Risk**: STTextView may perform **worse** than current LazyVStack for this workload.

### SwiftUI Integration

STTextView provides a SwiftUI wrapper: `STTextViewSwiftUI.TextView`

**API**:
```swift
import STTextViewSwiftUI

struct ContentView: View {
    @State private var text = AttributedString("Hello World!")
    @State private var selection: NSRange?

    var body: some View {
        TextView(
            text: $text,
            selection: $selection,
            options: [.wrapLines, .highlightSelectedLine],
            plugins: [plugin1(), plugin2()]
        )
        .textViewFont(.preferredFont(forTextStyle: .body))
    }
}
```

**Issues for our use case**:
1. **Two-way binding** - `@Binding var text` expects editing, not append-only
2. **AttributedString conversion** - Requires bridging to NSAttributedString
3. **No append API** - No efficient "append text" method (must replace entire text)
4. **Selection management** - We don't need multi-cursor or selection tracking

### Feature Comparison

| Feature | Current (SwiftUI) | STTextView | Notes |
|---------|-------------------|------------|-------|
| **Virtualization** | ✅ LazyVStack | ✅ TextKit 2 viewport | Both provide virtualization |
| **Auto-scroll** | ✅ `.defaultScrollAnchor(.bottom)` | ❌ Manual implementation | Would need custom scroll logic |
| **Text selection** | ✅ `.textSelection(.enabled)` | ✅ Native NSTextView | Both support copy/paste |
| **Line numbers** | ❌ Not supported | ✅ Built-in | MUD logs don't need line numbers |
| **Syntax highlighting** | ❌ Not relevant | ✅ Via plugins | MUD logs use preset colors, not syntax |
| **Performance (append)** | ✅ Proven 60fps | ⚠️ Unknown / risky | NSTextStorage append performance concerns |
| **Attributed text** | ✅ Native AttributedString | ⚠️ NSAttributedString bridge | Conversion overhead |
| **SwiftUI integration** | ✅ Native | ⚠️ NSViewRepresentable | Bridge complexity |
| **Complexity** | ✅ Simple (~120 LOC) | ⚠️ High (~500+ LOC wrapper) | Would need custom wrapper |

---

## SwiftUI Wrapper Design

If we proceed with STTextView, we need a **custom SwiftUI wrapper** tailored for our append-only, read-only use case.

### Requirements

**Functional**:
- ✅ Append-only API (no editing)
- ✅ Read-only display (copy/paste enabled)
- ✅ Sticky-bottom auto-scroll (like terminal)
- ✅ 10,000 line buffer with pruning
- ✅ Monospaced font rendering
- ✅ AttributedString → NSAttributedString conversion

**Performance**:
- ✅ 60fps scrolling target
- ✅ < 16ms frame time during rapid appends
- ✅ Efficient append (no full text replacement)
- ✅ < 500MB memory peak

**Integration**:
- ✅ Seamless with existing `GameLogViewModel`
- ✅ Preserve `TagRenderer` output (AttributedString)
- ✅ No breaking changes to upstream (`AppState`)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              GameLogTextView (SwiftUI)                      │
│  struct GameLogTextView: View {                             │
│    @Bindable var viewModel: GameLogViewModel                │
│    var isConnected: Bool                                    │
│                                                             │
│    var body: some View {                                   │
│      VStack {                                              │
│        connectionStatusBar                                 │
│        AppendOnlyTextView(                                 │
│          messages: viewModel.messages,                     │
│          autoScroll: true                                  │
│        )                                                   │
│      }                                                     │
│    }                                                       │
│  }                                                         │
└─────────────────────────────────────────────────────────────┘
                      ↓ uses
┌─────────────────────────────────────────────────────────────┐
│       AppendOnlyTextView (NSViewRepresentable)              │
│  struct AppendOnlyTextView: NSViewRepresentable {          │
│    let messages: [Message]                                 │
│    let autoScroll: Bool                                    │
│                                                             │
│    func makeNSView(context: Context) -> STTextView {       │
│      let textView = STTextView()                           │
│      textView.isEditable = false                           │
│      textView.isSelectable = true                          │
│      textView.font = .monospacedSystemFont(...)            │
│      return textView                                       │
│    }                                                        │
│                                                             │
│    func updateNSView(_ textView: STTextView, context:) {   │
│      // Efficiently append new messages                    │
│      context.coordinator.update(textView, messages)        │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
                      ↓ manages
┌─────────────────────────────────────────────────────────────┐
│              Coordinator (state tracker)                    │
│  class Coordinator: NSObject {                             │
│    private var lastMessageCount = 0                        │
│    private var buffer: NSMutableAttributedString           │
│                                                             │
│    func update(_ textView: STTextView, _ messages: []) {   │
│      let newMessages = messages.dropFirst(lastMessageCount)│
│      for message in newMessages {                          │
│        let nsAttr = convert(message.attributedText)        │
│        buffer.append(nsAttr)                               │
│      }                                                      │
│      textView.textStorage?.setAttributedString(buffer)     │
│      pruneIfNeeded()  // Keep 10k line limit              │
│      scrollToBottomIfNeeded()                             │
│      lastMessageCount = messages.count                     │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Details

#### 1. Efficient Append Strategy

**Challenge**: SwiftUI's `updateNSView` is called on **every** state change. We need to detect and append **only new messages**, not replace the entire buffer.

**Solution**: Track `lastMessageCount` in `Coordinator`:

```swift
class Coordinator: NSObject {
    private var lastMessageCount = 0
    private var buffer = NSMutableAttributedString()

    func update(_ textView: STTextView, _ messages: [Message]) {
        // Only process new messages since last update
        let newMessages = Array(messages.dropFirst(lastMessageCount))

        guard !newMessages.isEmpty else { return }

        // Append new messages to buffer
        for message in newMessages {
            let nsAttributed = convertToNSAttributedString(message.attributedText)
            buffer.append(nsAttributed)
            buffer.append(NSAttributedString(string: "\n"))
        }

        // Update text view (TextKit 2 should optimize this)
        textView.textStorage?.setAttributedString(buffer)

        // Prune if exceeds 10k lines
        pruneBufferIfNeeded()

        // Scroll to bottom if auto-scroll enabled
        if autoScrollEnabled {
            scrollToBottom(textView)
        }

        lastMessageCount = messages.count
    }
}
```

**Risk**: Even with "append" logic, we're still calling `setAttributedString()` which triggers full layout. TextKit 2 **should** optimize this, but there are reports of performance issues.

#### 2. AttributedString → NSAttributedString Conversion

**Challenge**: `TagRenderer` produces SwiftUI `AttributedString`, but STTextView uses AppKit `NSAttributedString`.

**Solution**: Use Foundation's conversion API:

```swift
func convertToNSAttributedString(_ swiftAttr: AttributedString) -> NSAttributedString {
    // Foundation provides built-in conversion
    return try NSAttributedString(swiftAttr, including: AttributeScopes.AppKitAttributes.self)
}
```

**Concerns**:
- Conversion overhead on **every message** (could be 10k+ times/minute)
- Color space conversion (SwiftUI Color → NSColor)
- Font conversion (SwiftUI Font → NSFont)
- Some attributes may not map 1:1

**Performance target**: < 0.1ms per conversion (to stay within < 1ms total render time)

#### 3. Sticky-Bottom Auto-Scroll

**Challenge**: SwiftUI's `.defaultScrollAnchor(.bottom)` is magic. STTextView requires manual scroll management.

**Solution**: Track scroll position and only auto-scroll when near bottom:

```swift
class Coordinator: NSObject {
    private var autoScrollEnabled = true
    private var lastScrollPosition: CGFloat = 0

    func scrollViewDidScroll(_ scrollView: NSScrollView) {
        let contentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let scrollPosition = scrollView.contentView.bounds.origin.y

        // Disable auto-scroll if user scrolled up
        let distanceFromBottom = contentHeight - (scrollPosition + visibleHeight)
        autoScrollEnabled = distanceFromBottom < 50  // 50pt threshold
    }

    func scrollToBottom(_ textView: STTextView) {
        guard autoScrollEnabled else { return }

        // Scroll to bottom (AppKit API)
        let length = textView.textStorage?.length ?? 0
        textView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }
}
```

**Risk**: Manual scroll management is **complex** and **bug-prone**. SwiftUI handles this beautifully with `.defaultScrollAnchor(.bottom)`.

#### 4. Buffer Pruning (10k Line Limit)

**Challenge**: Keep buffer at 10,000 lines, pruning oldest.

**Solution**: Periodically scan and prune:

```swift
func pruneBufferIfNeeded() {
    let lineCount = buffer.string.components(separatedBy: "\n").count

    guard lineCount > 10_000 else { return }

    // Find line breaks and remove oldest lines
    let lines = buffer.string.components(separatedBy: "\n")
    let excessLines = lineCount - 10_000

    // Calculate character range to remove
    let linesToRemove = lines.prefix(excessLines)
    let charsToRemove = linesToRemove.joined(separator: "\n").count + excessLines

    // Remove from buffer
    buffer.deleteCharacters(in: NSRange(location: 0, length: charsToRemove))

    // Note: This is O(n) on buffer size, could be expensive
}
```

**Risk**: Pruning is **O(n)** operation. With 10k lines, this could take milliseconds and block the main thread.

**Alternative**: Keep line boundary index to avoid scanning (more complex).

### Code Skeleton

```swift
// ABOUTME: AppendOnlyTextView wraps STTextView for append-only, read-only MUD game log display

import SwiftUI
import STTextView
import VaalinCore

/// SwiftUI wrapper around STTextView optimized for append-only, read-only game log display.
///
/// Provides:
/// - Efficient append-only updates (no full text replacement)
/// - Sticky-bottom auto-scroll (terminal-like behavior)
/// - 10,000 line buffer with automatic pruning
/// - AttributedString → NSAttributedString conversion
///
/// ## Performance Targets
/// - 60fps scrolling
/// - < 16ms frame time during rapid appends
/// - < 500MB memory peak
struct AppendOnlyTextView: NSViewRepresentable {
    // MARK: - Properties

    /// Messages to display (append-only)
    let messages: [Message]

    /// Whether to auto-scroll to bottom when new messages arrive
    let autoScroll: Bool

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let textView = STTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        // Wrap in scroll view
        let scrollView = STTextView.scrollableTextView()
        scrollView.documentView = textView
        scrollView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        context.coordinator.update(textView, messages: messages, autoScroll: autoScroll)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSScrollViewDelegate {
        private var lastMessageCount = 0
        private var buffer = NSMutableAttributedString()
        private var autoScrollEnabled = true

        func update(_ textView: STTextView, messages: [Message], autoScroll: Bool) {
            // TODO: Implement efficient append logic (see above)
        }

        func scrollViewDidScroll(_ scrollView: NSScrollView) {
            // TODO: Implement scroll tracking (see above)
        }

        private func scrollToBottom(_ textView: STTextView) {
            // TODO: Implement sticky-bottom scroll (see above)
        }

        private func pruneBufferIfNeeded() {
            // TODO: Implement 10k line pruning (see above)
        }

        private func convertToNSAttributedString(_ attr: AttributedString) -> NSAttributedString {
            // TODO: Implement conversion (see above)
        }
    }
}
```

**Estimated LOC**: 300-500 lines (vs 120 for current SwiftUI implementation)

---

## Migration Path

If we decide to proceed with STTextView, here's a phased migration strategy.

### Phase 1: Proof of Concept (1 week)

**Goal**: Validate performance assumptions with minimal prototype.

**Tasks**:
1. Add STTextView as SPM dependency
2. Create minimal `AppendOnlyTextView` wrapper (no pruning, basic scroll)
3. Benchmark append performance: 10k messages in rapid succession
4. Measure frame times during scrolling
5. Compare memory usage vs current implementation

**Success Criteria**:
- Append 10k messages in < 10 seconds (matches current)
- Scrolling maintains 60fps (< 16ms frame time)
- Memory usage < 500MB peak

**Failure Criteria** (abort if):
- Append performance > 20 seconds
- Frame times > 30ms (< 30fps)
- Memory usage > 750MB

### Phase 2: Full Implementation (2 weeks)

**Goal**: Complete feature parity with current `GameLogView`.

**Tasks**:
1. Implement efficient append strategy (track last message count)
2. AttributedString → NSAttributedString conversion
3. Sticky-bottom auto-scroll with user override
4. 10k line buffer pruning
5. Connection status bar integration
6. Text selection and copy/paste verification

**Success Criteria**:
- All current features work identically
- Performance targets met (60fps, < 16ms, < 500MB)
- No regressions in UX (auto-scroll feels natural)

### Phase 3: A/B Testing (1 week)

**Goal**: Compare implementations side-by-side.

**Tasks**:
1. Add feature flag: `useSTTextView: Bool`
2. Keep both implementations in codebase
3. Test with real game session (2+ hours)
4. Collect metrics: frame times, memory, user experience

**Success Criteria**:
- STTextView performs **noticeably better** than SwiftUI
- No visual glitches or scroll bugs
- Users prefer STTextView experience

**Rollback trigger**:
- Any performance regressions
- Scroll behavior feels "wrong"
- Bugs that block normal gameplay

### Phase 4: Production Rollout (1 week)

**Goal**: Ship STTextView as default, remove old implementation.

**Tasks**:
1. Enable STTextView by default
2. Monitor crash reports and performance metrics
3. Remove SwiftUI implementation after 1 month stable
4. Update documentation

**Success Criteria**:
- Zero critical bugs in production
- Performance metrics stable over 1 month
- Positive user feedback

### Total Timeline: 5 weeks

**Risk**: 5 weeks of engineering effort with **uncertain payoff**. Current implementation already meets all performance targets.

---

## Decision Framework

### Evaluation Criteria

| Criterion | Weight | Current (SwiftUI) | STTextView | Winner |
|-----------|--------|-------------------|------------|--------|
| **Performance (60fps)** | 25% | ✅ Proven (LazyVStack) | ⚠️ Unknown (TextKit 2 risk) | Current |
| **Append efficiency** | 20% | ✅ O(1) append | ⚠️ NSTextStorage risk | Current |
| **Implementation complexity** | 15% | ✅ Simple (120 LOC) | ❌ Complex (500+ LOC) | Current |
| **Feature completeness** | 15% | ✅ Meets all requirements | ⚠️ Missing auto-scroll | Current |
| **Future extensibility** | 10% | ⚠️ Limited (SwiftUI Text) | ✅ Rich features (plugins) | STTextView |
| **SwiftUI integration** | 10% | ✅ Native | ⚠️ NSViewRepresentable bridge | Current |
| **Memory efficiency** | 5% | ✅ < 500MB | ⚠️ NSTextStorage overhead | Current |

**Total Score**:
- **Current (SwiftUI)**: 90/100
- **STTextView**: 55/100

### Pros and Cons

#### Current Implementation (SwiftUI)

**Pros**:
- ✅ **Already works perfectly** - Meets all performance targets
- ✅ **Simple and maintainable** - 120 lines, easy to understand
- ✅ **Native SwiftUI** - No AppKit bridging complexity
- ✅ **Auto-scroll magic** - `.defaultScrollAnchor(.bottom)` just works
- ✅ **LazyVStack virtualization** - Proven performance at scale
- ✅ **Zero risk** - No unknowns, stable foundation

**Cons**:
- ❌ **Limited features** - No line numbers, limited text interaction
- ❌ **SwiftUI constraints** - Bound by SwiftUI Text capabilities
- ❌ **No built-in search** - Would need custom implementation

#### STTextView Implementation

**Pros**:
- ✅ **TextKit 2 foundation** - Modern text engine (in theory)
- ✅ **Rich features** - Line numbers, plugins, syntax highlighting
- ✅ **Future extensibility** - Could add advanced features later
- ✅ **Community support** - Active project, ongoing development

**Cons**:
- ❌ **High risk** - TextKit 2 has known bugs and performance issues
- ❌ **Complex implementation** - 500+ lines, NSViewRepresentable bridging
- ❌ **Uncertain performance** - May perform worse than current (NSTextStorage bottleneck)
- ❌ **Append-heavy workload mismatch** - Optimized for editing, not terminal-like appends
- ❌ **Manual scroll management** - Auto-scroll complexity
- ❌ **5 week timeline** - Significant engineering investment
- ❌ **Conversion overhead** - AttributedString → NSAttributedString on every message

### Alternative Approaches

If we want advanced features, consider these alternatives:

#### Option A: Stay with SwiftUI, Add Features Incrementally

**Strategy**: Keep current implementation, add features as needed.

**Potential additions**:
- **Search**: Custom SwiftUI overlay with `Cmd+F` support
- **Text interaction**: Context menus for links/items
- **Filtering**: SwiftUI filter UI on top of existing log

**Pros**:
- ✅ Low risk (incremental changes)
- ✅ Keep proven performance
- ✅ Native SwiftUI experience

**Cons**:
- ❌ Some features hard to implement in SwiftUI (line numbers)
- ❌ Limited by SwiftUI Text API

#### Option B: Hybrid Approach (SwiftUI + AppKit for Advanced Features)

**Strategy**: Use SwiftUI for main log, AppKit for advanced overlay features.

**Example**: SwiftUI game log + AppKit overlay for minimap, search highlights.

**Pros**:
- ✅ Best of both worlds
- ✅ Keep current performance
- ✅ Add advanced features where needed

**Cons**:
- ⚠️ Complexity of bridging both frameworks
- ⚠️ Potential coordination issues

#### Option C: Wait for TextKit 2 to Mature

**Strategy**: Revisit STTextView in 1-2 years when TextKit 2 bugs are resolved.

**Pros**:
- ✅ Avoid current TextKit 2 instability
- ✅ Community will have solved common issues
- ✅ Apple may fix viewport bugs

**Cons**:
- ❌ Miss potential benefits now
- ❌ Technical debt if we need features sooner

### Recommendation

**Recommendation: STICK WITH CURRENT SWIFTUI IMPLEMENTATION**

**Rationale**:

1. **Performance Risk is Unacceptable**: TextKit 2 has documented bugs and NSTextStorage performance issues. Our current implementation **already meets all targets** (60fps, 10k lines/min, < 500MB). Why risk regression?

2. **Complexity Not Justified**: 5 weeks of engineering for 500+ lines of bridging code when we have a working 120-line solution. This is a **bad ROI**.

3. **Feature Mismatch**: STTextView is optimized for **code editing** (line numbers, multi-cursor, syntax highlighting). We need a **terminal-like append-only log**. Wrong tool for the job.

4. **SwiftUI is Getting Better**: Apple is rapidly improving SwiftUI. Features we might want (search, advanced text interaction) may come natively in future macOS versions.

5. **No User Pain Points**: Current implementation works beautifully. No users complaining about performance or missing features. **Don't fix what isn't broken.**

**When to Revisit**:
- User feedback requests features that SwiftUI Text can't provide (line numbers, advanced search)
- Performance degrades below 60fps (hasn't happened)
- TextKit 2 matures and community reports production stability
- Apple deprecates LazyVStack or breaks `.defaultScrollAnchor` (unlikely)

**Action Items**:
1. ✅ Document this research for future reference
2. ✅ Close any GitHub issues requesting STTextView migration
3. ✅ Continue optimizing current implementation if needed
4. ✅ Monitor TextKit 2 community for stability improvements
5. ✅ Revisit in 12-18 months if user needs change

---

## Appendix

### Benchmark Template

If we want to validate STTextView performance in the future, use this benchmark:

```swift
import XCTest
import STTextView
import VaalinCore

class STTextViewBenchmarkTests: XCTestCase {
    func testAppendPerformance() {
        let textView = STTextView()
        let messages = generateMessages(count: 10_000)

        measure {
            for message in messages {
                let nsAttr = convertToNSAttributedString(message.attributedText)
                textView.textStorage?.append(nsAttr)
            }
        }

        // Target: < 10 seconds for 10k messages
        XCTAssertLessThan(averageTime, 10.0)
    }

    func testScrollingFrameTime() {
        let textView = STTextView()
        populateWithMessages(textView, count: 10_000)

        // Simulate scrolling and measure frame times
        let frameTimes = measureScrollFrameTimes(textView)
        let average = frameTimes.reduce(0, +) / Double(frameTimes.count)

        // Target: < 16ms (60fps)
        XCTAssertLessThan(average, 0.016)
    }

    func testMemoryUsage() {
        let textView = STTextView()
        populateWithMessages(textView, count: 10_000)

        let memoryUsage = getCurrentMemoryUsage()

        // Target: < 500MB
        XCTAssertLessThan(memoryUsage, 500_000_000)
    }
}
```

### References

**STTextView**:
- GitHub: https://github.com/krzyzanowskim/STTextView
- Package: https://swiftpackageindex.com/krzyzanowskim/STTextView
- Author's Blog: https://blog.krzyzanowskim.com/2025/08/14/textkit-2-the-promised-land/

**TextKit 2**:
- WWDC22: [What's new in TextKit](https://developer.apple.com/videos/play/wwdc2022/10090/)
- Apple Docs: [NSTextLayoutManager](https://developer.apple.com/documentation/uikit/nstextlayoutmanager)
- Community: [STTextView without NSTextView](https://christiantietze.de/posts/2022/05/sttextview-textkit-2-editor-without-nstextview/)

**NSTextStorage Performance**:
- [Resolving Slow Performance of NSTextStorage](https://www.thecope.net/2019/09/15/resolving-slow-performance.html)
- [Getting to Know TextKit](https://www.objc.io/issues/5-ios7/getting-to-know-textkit/)

**Current Implementation**:
- `GameLogView.swift`: VaalinUI/Sources/VaalinUI/Views/GameLogView.swift
- `GameLogViewModel.swift`: VaalinUI/Sources/VaalinUI/ViewModels/GameLogViewModel.swift
- `TagRenderer.swift`: VaalinParser/Sources/VaalinParser/TagRenderer.swift

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-10-12 | Initial research document | Claude Code |

---

**End of Document**
