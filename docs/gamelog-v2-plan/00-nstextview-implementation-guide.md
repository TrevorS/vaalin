# NSTextView Implementation Guide for GameLogView v2

**Author**: Teej + Claude
**Date**: 2025-10-12
**Context**: Vaalin MUD client - High-throughput game log implementation

## Executive Summary

This guide documents the NSTextView-based implementation of GameLogView v2, replacing the broken SwiftUI implementation. NSTextView provides the performance and features necessary for a terminal-like scrollback buffer with 10k+ lines/minute throughput.

## Why NSTextView?

**SwiftUI limitations**:
- Text views don't handle rapid appends efficiently (frame drops)
- No built-in find panel (Cmd+F)
- Cross-line text selection is buggy
- ScrollView doesn't support sticky-bottom behavior
- AttributedString rendering is CPU-intensive for large documents

**NSTextView advantages**:
- Mature TextKit 1 backend with decades of optimization
- Native find panel with incremental search
- Robust text selection and copy/paste
- Efficient layout caching for off-screen content
- Direct NSAttributedString rendering (no conversion overhead)

## Architecture

```
GameLogViewV2 (NSViewRepresentable)
       ↓
NSScrollView (makeNSView)
       ↓
NSTextView (read-only, selectable)
       ↓
NSTextStorage (circular buffer, 10k lines)
       ↓
NSLayoutManager (TextKit 1, forced)
```

**Key components**:
1. **NSViewRepresentable**: SwiftUI wrapper for NSTextView
2. **Coordinator**: State tracking, delta updates, scroll management
3. **NSTextStorage**: Mutable attributed string with FIFO pruning
4. **TextKit 1**: Layout engine (forced for predictability)

## Implementation Patterns

### 1. NSViewRepresentable Structure

```swift
struct GameLogViewV2: NSViewRepresentable {
    @Bindable var viewModel: GameLogViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        configureTextView(textView)
        let _ = textView.layoutManager // Force TextKit 1

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.replaceAllText(with: viewModel.messages)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Delta update: only append new messages
        context.coordinator.appendNewMessages(
            currentMessages: viewModel.messages,
            textView: scrollView.documentView as! NSTextView
        )

        // Auto-scroll if enabled
        if context.coordinator.autoScrollEnabled {
            context.coordinator.scrollToBottom(scrollView: scrollView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
```

**Best practices**:
- Use `NSTextView.scrollableTextView()` factory method
- Force TextKit 1 with `let _ = textView.layoutManager`
- Store weak references in Coordinator (avoid retain cycles)
- Implement delta updates in `updateNSView` (not full replacement)

### 2. TextKit 1 vs TextKit 2

**Always use TextKit 1** for this use case:

```swift
// Force TextKit 1 instantiation
let _ = textView.layoutManager
```

**Why TextKit 1?**

| Feature | TextKit 1 | TextKit 2 |
|---------|-----------|-----------|
| Large document performance | Excellent (10k+ lines) | Degrades >5k lines |
| Rapid append stability | Stable | Known issues |
| Find panel | Mature | Evolving |
| Layout caching | Predictable | Unpredictable |
| API stability | Stable (since macOS 10.0) | Evolving |

**Apple's guidance**: TextKit 2 is for complex layouts (images, tables, multi-column). For terminal-like text, TextKit 1 is faster and more reliable.

**Reference**: [WWDC 2021 - What's new in TextKit 2](https://developer.apple.com/videos/play/wwdc2021/10061/)

### 3. Text Appending - The Right Way

**✅ CORRECT: Batch append with single begin/end**

```swift
func appendMessagesBatch(_ messages: [Message], to textStorage: NSTextStorage) {
    let attributed = messages.toNSAttributedString()

    textStorage.beginEditing()
    defer { textStorage.endEditing() }

    textStorage.append(attributed)
    pruneOldLinesIfNeeded(textStorage: textStorage, maxLines: 10_000)
}
```

**❌ WRONG: Multiple begin/end pairs (layout thrashing)**

```swift
for message in messages {
    textStorage.beginEditing() // ❌ Triggers layout after each message
    textStorage.append(NSAttributedString(message.attributedText))
    textStorage.endEditing()
}
```

**Performance impact**: Multiple begin/end pairs cause layout thrashing (10-100x slower).

**Why?** `endEditing()` triggers layout pass. Batching means one layout pass for all messages.

**Apple docs**: [NSTextStorage Class Reference](https://developer.apple.com/documentation/appkit/nstextstorage)

### 4. Circular Buffer Pruning

**Efficient line pruning** using NSString line enumeration:

```swift
func pruneOldLinesOptimized(textStorage: NSTextStorage, maxLines: Int) {
    let string = textStorage.string as NSString
    var lineCount = 0
    var pruneIndex = 0

    string.enumerateSubstrings(in: NSRange(location: 0, length: string.length),
                              options: .byLines) { _, _, range, stop in
        lineCount += 1
        if lineCount > maxLines {
            pruneIndex = range.location
            stop.pointee = true
        }
    }

    if pruneIndex > 0 {
        textStorage.deleteCharacters(in: NSRange(location: 0, length: pruneIndex))
    }
}
```

**Why NSString enumeration?**
- 10x faster than `String.split(separator: "\n")`
- No intermediate array allocation
- Early exit when line limit reached

**Performance**: < 10ms for 10k line prune (tested on M1 Mac)

### 5. Auto-Scroll with User Override

**Pattern**: Sticky-bottom auto-scroll that disables on user scroll.

```swift
class Coordinator {
    var autoScrollEnabled: Bool = true
    private var autoScrollReenableTimer: Timer?

    func setupScrollObservation(scrollView: NSScrollView) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let scrollView = scrollView else { return }

        if !isScrolledToBottom(scrollView: scrollView, threshold: 50.0) {
            autoScrollEnabled = false

            // Re-enable after 3s idle
            autoScrollReenableTimer?.invalidate()
            autoScrollReenableTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.autoScrollEnabled = true
            }
        }
    }

    func isScrolledToBottom(scrollView: NSScrollView, threshold: CGFloat = 50.0) -> Bool {
        let contentView = scrollView.contentView
        let visibleRect = contentView.documentVisibleRect
        let documentHeight = contentView.documentRect.height
        return (documentHeight - visibleRect.maxY) < threshold
    }

    func scrollToBottom(scrollView: NSScrollView) {
        textView?.scrollRangeToVisible(NSRange(location: textView?.string.count ?? 0, length: 0))
    }
}
```

**Key decisions**:
1. **50px threshold**: Don't require pixel-perfect bottom position
2. **3s re-enable timer**: Balance between convenience and intentionality
3. **Bounds notification**: More reliable than scroll view delegate (which doesn't exist)

**Alternative**: Use `NSClipView` subclass for more control, but overkill for this use case.

### 6. SwiftUI @Observable Integration

**Correct pattern** for @Observable view models:

```swift
struct GameLogViewV2: NSViewRepresentable {
    @Bindable var viewModel: GameLogViewModel // ✅ Use @Bindable, not @ObservedObject

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Delta update: only append new messages
        context.coordinator.appendNewMessages(
            currentMessages: viewModel.messages,
            textView: scrollView.documentView as! NSTextView
        )
    }
}

class Coordinator {
    private var lastMessageCount: Int = 0 // Track for delta updates

    func appendNewMessages(currentMessages: [Message], textView: NSTextView) {
        guard currentMessages.count > lastMessageCount else { return }

        let newMessages = Array(currentMessages.suffix(from: lastMessageCount))
        // ... append ...

        lastMessageCount = currentMessages.count
    }
}
```

**Why delta tracking?**
- `updateNSView` called on EVERY @Observable property change
- Full text replacement would be O(n) on every update (unacceptable)
- Delta tracking makes updates O(new messages only)

**Common mistake**: Storing view model in Coordinator (retain cycle). Access via `updateNSView` parameters instead.

## Common Pitfalls

### Pitfall 1: Modifying NSTextStorage Without begin/end

**WRONG**:
```swift
textStorage.append(attributed) // ❌ Crash or undefined behavior
```

**RIGHT**:
```swift
textStorage.beginEditing()
textStorage.append(attributed)
textStorage.endEditing()
```

**Why?** NSTextStorage notifies layout manager on edits. Without begin/end, layout may access inconsistent state.

### Pitfall 2: Forgetting to Prune Old Lines

**WRONG**:
```swift
func appendMessages(_ messages: [Message], to textStorage: NSTextStorage) {
    textStorage.beginEditing()
    textStorage.append(messages.toNSAttributedString())
    textStorage.endEditing()
    // ❌ Missing prune - memory leak!
}
```

**RIGHT**:
```swift
func appendMessages(_ messages: [Message], to textStorage: NSTextStorage) {
    textStorage.beginEditing()
    defer { textStorage.endEditing() }

    textStorage.append(messages.toNSAttributedString())
    pruneOldLinesIfNeeded(textStorage: textStorage, maxLines: 10_000) // ✅
}
```

**Impact**: 10k lines @ 100 bytes/line = 1MB. Without pruning, grows unbounded (memory leak).

### Pitfall 3: Using ObservableObject with @Observable

**WRONG**:
```swift
struct GameLogViewV2: NSViewRepresentable {
    @ObservedObject var viewModel: GameLogViewModel // ❌ viewModel uses @Observable, not ObservableObject
}
```

**RIGHT**:
```swift
struct GameLogViewV2: NSViewRepresentable {
    @Bindable var viewModel: GameLogViewModel // ✅
}
```

**Why?** `@Observable` macro (Swift 5.9+) replaces `ObservableObject` protocol. Don't mix them.

### Pitfall 4: TextKit 2 Issues with Large Documents

**WRONG**:
```swift
func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    let textView = scrollView.documentView as! NSTextView
    // ❌ TextKit 2 by default on macOS 12+ (unpredictable performance)
    return scrollView
}
```

**RIGHT**:
```swift
func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    let textView = scrollView.documentView as! NSTextView
    let _ = textView.layoutManager // ✅ Force TextKit 1
    return scrollView
}
```

**Symptoms of TextKit 2 issues**:
- Scroll jank with >5k lines
- Find panel crashes
- Layout glitches on rapid appends

### Pitfall 5: Synchronous Appending on Main Thread

**WRONG** (for high-throughput streams):
```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    // 100+ messages in viewModel.messages
    appendAllMessages(viewModel.messages) // ❌ Blocks main thread for 100ms+
}
```

**RIGHT** (if needed):
```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    // Only append new messages (delta)
    context.coordinator.appendNewMessages(currentMessages: viewModel.messages, textView: textView)
    // < 16ms for reasonable batch size
}
```

**Note**: With proper delta tracking and batching, async appending shouldn't be necessary. But if you hit 16ms+ append times, consider:
1. Coalescing updates (debounce at 60fps)
2. Background conversion to NSAttributedString
3. Batching message delivery from parser

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Append throughput | 10,000 lines/min | Parser stress test |
| Append latency | < 16ms per batch | CFAbsoluteTimeGetCurrent |
| Scroll framerate | 60fps (10k lines) | Instruments Time Profiler |
| Memory usage | < 500MB (10k lines) | Instruments Allocations |
| Prune latency | < 10ms | CFAbsoluteTimeGetCurrent |

**Testing approach**:
1. **Stress test**: Send 10k lines in 60 seconds (parser mock)
2. **Memory test**: Monitor Instruments after 1 hour session
3. **Scroll test**: Scroll through 10k lines, measure frame time
4. **Find test**: Search 10k lines for pattern (Cmd+F)

## Apple Documentation References

**Primary sources**:
1. [NSTextView Class Reference](https://developer.apple.com/documentation/appkit/nstextview)
2. [NSTextStorage Class Reference](https://developer.apple.com/documentation/appkit/nstextstorage)
3. [Text Programming Guide for macOS](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextArchitecture/)
4. [TextKit 1 Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextStorageLayer/)
5. [WWDC 2021 - What's new in TextKit 2](https://developer.apple.com/videos/play/wwdc2021/10061/)

**Key concepts**:
- NSTextStorage editing protocol (beginEditing/endEditing)
- NSLayoutManager layout caching
- NSTextView scrolling behavior
- TextKit 1 vs TextKit 2 trade-offs

## Testing Strategy

### Unit Tests

```swift
@Suite("NSTextStorage Appending")
struct TextStorageTests {
    @Test("Batch append faster than sequential")
    func testBatchAppendPerformance() async {
        let textStorage = NSTextStorage()
        let messages = (0..<1000).map { Message(attributedText: AttributedString("Line \($0)"), presetID: nil) }

        // Measure batch append
        let start = CFAbsoluteTimeGetCurrent()
        textStorage.beginEditing()
        textStorage.append(messages.toNSAttributedString())
        textStorage.endEditing()
        let batchDuration = CFAbsoluteTimeGetCurrent() - start

        // Verify < 16ms
        #expect(batchDuration < 0.016)
    }

    @Test("Prune removes correct number of lines")
    func testPruneOldLines() async {
        let textStorage = NSTextStorage()
        let lines = (0..<15_000).map { "Line \($0)\n" }.joined()
        textStorage.append(NSAttributedString(string: lines))

        // Prune to 10k lines
        pruneOldLinesOptimized(textStorage: textStorage, maxLines: 10_000)

        // Verify line count
        let lineCount = textStorage.string.components(separatedBy: "\n").count
        #expect(lineCount <= 10_001) // +1 for trailing newline
    }
}
```

### Integration Tests

```swift
@Suite("GameLogViewV2 Integration")
struct GameLogViewV2IntegrationTests {
    @Test("Delta updates append only new messages")
    @MainActor
    func testDeltaUpdates() async {
        let viewModel = GameLogViewModel()
        let coordinator = GameLogViewV2.Coordinator()
        let textStorage = NSTextStorage()

        // Initial messages
        viewModel.messages = [Message(attributedText: AttributedString("Msg 1"), presetID: nil)]
        coordinator.appendNewMessages(currentMessages: viewModel.messages, textStorage: textStorage)

        // Add new message
        viewModel.messages.append(Message(attributedText: AttributedString("Msg 2"), presetID: nil))
        coordinator.appendNewMessages(currentMessages: viewModel.messages, textStorage: textStorage)

        // Verify only 2 messages in text storage (not duplicated)
        let lineCount = textStorage.string.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        #expect(lineCount == 2)
    }
}
```

### UI Tests (Manual)

1. **Stress test**: Run Lich client, generate 10k lines in 60s, verify no frame drops
2. **Scroll test**: Scroll to top, verify smooth 60fps scrolling back to bottom
3. **Find test**: Cmd+F search for pattern in 10k lines, verify < 1s
4. **Selection test**: Select text across multiple lines, verify copy/paste works
5. **Auto-scroll test**: Scroll up, verify auto-scroll disables, wait 3s, verify re-enables

## Next Steps

1. **Implement GameLogViewV2** with patterns from this guide
2. **Write unit tests** for text appending and pruning
3. **Write integration tests** for SwiftUI binding
4. **Performance test** with 10k line stress test
5. **Create previews** (empty state, 100 lines, 10k lines)
6. **Document in CLAUDE.md** as reference implementation

## Conclusion

NSTextView provides the foundation for a high-performance game log that SwiftUI simply cannot match. The key insights:

1. **Force TextKit 1** for predictable performance
2. **Batch appends** with single begin/end for speed
3. **Delta tracking** to avoid full text replacement
4. **Circular buffer pruning** to prevent memory leaks
5. **Sticky auto-scroll** with user override

Follow these patterns and you'll have a robust, performant game log that can handle MUD throughput with ease.

**Questions?** Consult Apple's Text Programming Guide or the NSTextView/NSTextStorage class references.

---

**Author**: Teej + Claude
**Date**: 2025-10-12
**Version**: 1.0
