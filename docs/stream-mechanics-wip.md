# GemStone IV Stream Mechanics - Implementation Notes

**Status:** Work in Progress
**Date:** 2025-01-12
**Author:** Research from Illthorn and profanityfe implementations

## Executive Summary

GemStone IV uses XML stream control tags (`<pushStream>`, `<popStream>`) to route content to different display contexts (main log, speech panel, room window, etc.). Understanding stream mechanics is critical to preventing duplicate content and implementing proper UI routing.

## Core Concepts

### Stream Control Tags

The server sends three control directives:

```xml
<pushStream id="speech"/>     <!-- Enter speech stream context -->
<!-- All content here goes to speech stream -->
<popStream/>                   <!-- Exit stream context -->

<clearStream id="room"/>       <!-- Clear specific stream (less common) -->
```

**Key insight:** These are **control directives**, not content tags. They don't create visible output.

### Stream Context

Between `<pushStream>` and `<popStream>`, ALL content belongs to that stream:

```xml
<pushStream id="thoughts"/>
<output>You think about magic.</output>
<output>Deep thoughts continue...</output>
<popStream/>
```

Both `<output>` tags belong to the "thoughts" stream.

## The Duplication Problem

### Why Content Duplicates

The GemStone IV server sometimes sends the **same content multiple ways**:

1. **Wrapped in a stream:**
   ```xml
   <pushStream id="speech"/>
   <preset id="speech">Devo says, "Hello"</preset>
   <popStream/>
   ```

2. **As regular output** (no stream wrapper):
   ```xml
   <preset id="speech">Devo says, "Hello"</preset>
   ```

If you display both contexts, the user sees the message twice.

### Common Duplication Scenarios

- **Speech:** Sent in `speech` stream AND as regular output
- **Room descriptions:** Sent in `room` streams AND as regular output on movement
- **"You also see":** Appears in `room objs` stream AND in room description text

## Reference Implementations

### Illthorn's Approach (TypeScript)

**Architecture:** Stream Wrapper Pattern

```typescript
// When <pushStream id="X"> is encountered, create synthetic wrapper:
{
  name: "stream",
  attrs: { id: "X" },
  state: TagState.OPEN,
  children: []  // Collect content here
}

// ALL subsequent content becomes children until <popStream>
```

**Filtering strategy:**

```typescript
// 1. Extract metadata (includes stream wrapper tags)
const metadata = extractMetadata(parsed);

// 2. Filter content (removes metadata)
const contentTags = parsed.filter(tag => !metadata.includes(tag));

// 3. Conditional routing based on panel visibility
if (!streamsPanelVisible) {
  // Add SOME stream content to main feed (thoughts, logon, logoff, death)
  // But NOT speech (speech always goes to panel only)
  const mainFeedStreamTypes = ["thoughts", "logon", "logoff", "death"];
  const streamTags = metadata.filter(tag =>
    tag.name === "stream" && mainFeedStreamTypes.includes(tag.attrs.id)
  );
  for (const streamTag of streamTags) {
    contentTags.push(...streamTag.children); // Add CHILDREN, not wrapper
  }
}
```

**Key insights:**
- Stream wrapper tags are classified as **metadata**, not content
- `speech` stream NEVER appears in main feed (prevents duplication)
- Other streams conditionally appear in main feed when panel is closed
- 200ms deduplication window catches rapid duplicates

### Profanityfe's Approach (Ruby)

**Architecture:** Window-Based Exclusive Routing

```ruby
# Route based on stream handler configuration
if (window = stream_handler[current_stream])
  # Has dedicated window → goes ONLY there
  window.add_string(text, line_colors)
elsif current_stream =~ /^(?:death|logons|thoughts|...)$/
  # Fallback to main window (only if no dedicated window)
  main_window.add_string(text, line_colors)
end
```

**Multi-stream pattern:** Some content goes to BOTH locations:

```ruby
# Room content appears in both room window AND main
multi_stream.add('roomName')
multi_stream.add('roomDesc')

# But room window strips "You also see..." to prevent redundancy
window.add_string(room_desc.sub(/ You also see.*/, ''), colors)
```

**Key insights:**
- **Exclusive routing:** If stream has dedicated window, content goes ONLY there
- **Multi-stream exception:** Room content deliberately duplicated (with modification)
- No client-side deduplication - relies on exclusive routing

## Vaalin's Implementation

### Architecture

**Hybrid approach:** Stream wrappers + selective filtering

```swift
// Parser wraps stream content in synthetic tags (like Illthorn)
GameTag(name: "stream", attrs: ["id": "speech"], children: [
  GameTag(name: "preset", text: "Devo says..."),
  GameTag(name: ":text", text: "\n")
])
```

### Filtering Strategy

```swift
// 1. Filter metadata tags (prompt, progressBar, etc.)
let metadataIDs = extractMetadataIDs(tags)

// 2. Selective stream filtering by "id" attribute
let excludedStreamIDs: Set<String> = [
  // Communication streams (for future StreamsPanel)
  "speech", "thoughts", "logon", "logoff", "death", "arrivals",

  // Room streams (for future RoomPanel)
  "room", "roomName", "roomDesc", "room objs", "room players", "room exits"
]

return tags.filter { tag in
  // Not metadata
  guard !metadataIDs.contains(tag.id) else { return false }

  // Stream wrapper tags: filter by "id" attribute
  if tag.name == "stream" {
    if let streamID = tag.attrs["id"] as? String {
      return !excludedStreamIDs.contains(streamID)
    }
  }

  // Non-stream tags: also filter by streamId
  if let streamId = tag.streamId {
    return !excludedStreamIDs.contains(streamId)
  }

  return true // Pass through
}
```

### Deduplication Layer

**200ms time window** (matching Illthorn):

```swift
private var recentMessages: [String: [(text: String, timestamp: Date)]] = [:]
private let deduplicationWindow: TimeInterval = 0.2

func isDuplicate(_ tags: [GameTag]) -> Bool {
  let textContent = extractTextContent(tags)
  let streamType = tags.first?.streamId ?? "main"
  let now = Date()

  // Check recent messages for exact match within 200ms
  let recentForType = recentMessages[streamType] ?? []
  return recentForType.contains { message in
    message.text == textContent &&
    now.timeIntervalSince(message.timestamp) <= deduplicationWindow
  }
}
```

## Stream Types Reference

### Communication Streams

| Stream ID | Content | Routing |
|-----------|---------|---------|
| `speech` | "Devo says..." | StreamsPanel (future) |
| `thoughts` | "You think..." | StreamsPanel (future) |
| `whisper` | "(Devo whispers...)" | StreamsPanel (future) |
| `logon` | "X just arrived." | StreamsPanel (future) |
| `logoff` | "X just left." | StreamsPanel (future) |
| `death` | "X just died." | StreamsPanel (future) |
| `arrivals` | Movement messages | StreamsPanel (future) |

### Room Streams

| Stream ID | Content | Routing |
|-----------|---------|---------|
| `room` | Wrapper for all room content | RoomPanel (future) |
| `roomName` | "[Town Square, East - 229]" | RoomPanel (future) |
| `roomDesc` | "Here in the center..." | RoomPanel (future) |
| `room objs` | "You also see..." | RoomPanel (future) |
| `room players` | "Also here: ..." | RoomPanel (future) |
| `room exits` | "Obvious paths: ..." | RoomPanel (future) |

### Combat/General Streams

| Stream ID | Content | Routing |
|-----------|---------|---------|
| `combat` | Combat messages | Main log (for now) |
| `experience` | Experience messages | Main log (for now) |
| `inventory` | Inventory updates | Main log (for now) |
| *others* | Misc game output | Main log (for now) |

## Three-Layer Defense Strategy

### 1. Parser Layer (XMLStreamParser)

**Responsibility:** Wrap stream content in parent tags

```swift
// Enter stream context
if elementName == "pushStream" {
  let streamTag = GameTag(name: "stream", attrs: ["id": streamID], ...)
  activeStreamTag = streamTag
}

// All content goes to activeStreamTag.children
if let activeStream = activeStreamTag {
  var streamTag = activeStream
  streamTag.children.append(tag)
  activeStreamTag = streamTag
}

// Exit stream context
if elementName == "popStream" {
  currentParsedTags.append(activeStreamTag!)
  activeStreamTag = nil
}
```

**Benefits:**
- Content wrapped ONCE in parent tag
- Filtering removes entire parent (all children at once)
- Server can't send same content in different contexts

### 2. Session Layer (AppState)

**Responsibility:** Filter metadata and excluded streams

```swift
// Remove metadata tags
let metadataIDs = extractMetadataIDs(tags)

// Remove streams destined for dedicated panels
let excludedStreamIDs: Set<String> = [...]

let contentTags = tags.filter { tag in
  !metadataIDs.contains(tag.id) &&
  !isExcludedStream(tag)
}

// Check for duplicates within 200ms window
if !isDuplicate(contentTags) {
  await gameLogViewModel.appendMessage(contentTags)
}
```

**Benefits:**
- Clean separation of concerns
- Ready for future panels (just add to EventBus subscriptions)
- Deduplication catches remaining edge cases

### 3. View Layer (GameLogViewModel)

**Responsibility:** Final safety check for empty content

```swift
func hasContentRecursive(_ tag: GameTag) -> Bool {
  if tag.text != nil && !tag.text!.isEmpty {
    return true
  }
  return tag.children.contains(where: hasContentRecursive)
}

// Only append messages with actual content
if hasContentRecursive(tag) {
  messages.append(Message(tags: [tag]))
}
```

**Benefits:**
- Prevents blank lines in UI
- Catches any edge cases that slip through earlier layers
- UI remains clean even if filtering has bugs

## Testing Strategy

### Unit Tests

**Parser tests** (XMLStreamParserTests):
```swift
@Test func test_streamTagMarking() async throws {
  let xml = "<pushStream id=\"thoughts\"/><output>You think...</output><popStream/>"
  let tags = await parser.parse(xml)

  // Should get stream wrapper
  #expect(tags.count == 1)
  #expect(tags[0].name == "stream")
  #expect(tags[0].attrs["id"] == "thoughts")
  #expect(tags[0].children.count == 1)
}
```

**Filtering tests** (AppStateTests):
```swift
@Test func test_filtersSpeechStream() async throws {
  let tags = [
    GameTag(name: "stream", attrs: ["id": "speech"], ...),
    GameTag(name: "stream", attrs: ["id": "combat"], ...)
  ]

  let filtered = appState.filterContentTags(tags)

  // Speech filtered, combat passed through
  #expect(filtered.count == 1)
  #expect(filtered[0].attrs["id"] == "combat")
}
```

### Integration Tests

**Duplicate detection:**
```swift
@Test func test_preventsDuplicateSpeech() async throws {
  // Send speech in stream
  await server.send("<pushStream id=\"speech\"/>Hello<popStream/>")
  await Task.sleep(milliseconds: 50)

  // Send same speech as regular output
  await server.send("<output>Hello</output>")
  await Task.sleep(milliseconds: 50)

  // Should only appear once (speech filtered)
  #expect(gameLog.messages.count == 0)
}
```

## Future Work

### Phase 3: StreamsPanel (Issue #52)

When implementing StreamsPanel:

1. **Subscribe to stream events:**
   ```swift
   await eventBus.subscribe("stream/speech") { (tag: GameTag) in
     await streamsPanelViewModel.appendSpeech(tag)
   }
   ```

2. **Unwrap stream wrapper:**
   ```swift
   func appendSpeech(_ streamTag: GameTag) {
     // Extract children from wrapper
     for child in streamTag.children {
       messages.append(Message(tags: [child]))
     }
   }
   ```

3. **Consider conditional routing:**
   - When panel closed: show thoughts/logon/logoff in main log?
   - When panel open: all communication goes to panel exclusively
   - Matches Illthorn's behavior

### Phase 3: RoomPanel (Issue #44)

When implementing RoomPanel:

1. **Subscribe to room stream events:**
   ```swift
   await eventBus.subscribe("stream/roomName") { ... }
   await eventBus.subscribe("stream/roomDesc") { ... }
   await eventBus.subscribe("stream/room objs") { ... }
   ```

2. **Strip "You also see" from description:**
   ```swift
   let cleanedDesc = roomDesc.replacingOccurrences(
     of: / You also see.*/,
     with: ""
   )
   ```

3. **Rebuild room display on any update:**
   - Room panel shows: [Name] + [Desc] + [Objects] + [Players] + [Exits]
   - Cache components and rebuild entire panel on each update
   - Matches profanityfe's approach

## Common Pitfalls

### ❌ Don't Filter ALL Stream Wrappers

```swift
// WRONG: Filters everything
if tag.name == "stream" {
  return false
}
```

**Problem:** Server wraps most content in streams. Filtering all of them means nothing shows up.

**Fix:** Filter by `attrs["id"]` to be selective.

### ❌ Don't Reset activeStreamTag Every Parse

```swift
// WRONG: Loses stream context across chunks
public func parse(_ chunk: String) async -> [GameTag] {
  activeStreamTag = nil  // ⚠️ Bug!
  ...
}
```

**Problem:** Stream tags can span multiple TCP chunks. Resetting loses context.

**Fix:** Only reset per-parse state (currentTagStack, currentParsedTags), not persistent state.

### ❌ Don't Display Stream Content Twice

```swift
// WRONG: Shows content in both main log and panel
if tag.name == "stream" && tag.attrs["id"] == "speech" {
  await speechPanel.append(tag)
  // Also falls through to main log! ⚠️
}
```

**Problem:** Duplicates speech in two locations.

**Fix:** Filter stream wrapper BEFORE it reaches main log.

## Performance Considerations

### Parser Performance

**Target:** > 10,000 lines/minute throughput

Stream wrapper creation adds minimal overhead:
- One additional GameTag allocation per stream
- Children stored as references (not copies)
- Typical cost: < 0.1ms per stream

### Filtering Performance

**Overhead per poll cycle:**
- Metadata extraction: O(n) where n = tag count
- Stream filtering: O(n) with Set lookups (O(1))
- Deduplication: O(m) where m = recent messages (bounded at ~10)
- **Total:** < 1ms for typical batches (< 100 tags)

### Memory Footprint

**Deduplication state:**
- 200ms window = ~2 messages per stream type
- ~10 active stream types
- Text storage: ~200 bytes per message
- **Total:** < 5KB for deduplication tracking

## References

- **Illthorn source:** `/Users/trevor/Projects/illthorn/`
  - Parser: `src/frontend/parser/saxophone-parser.ts` (lines 30-307)
  - Session: `src/frontend/session/index.ts` (lines 183-208)
  - Streams panel: `src/frontend/components/session/streams-container.lit.ts`

- **profanityfe source:** `/Users/trevor/Projects/profanityfe/profanity.rb`
  - Stream routing: lines 1366-1853
  - Multi-stream: lines 2217-2229
  - Room window: lines 1340-1357

- **GemStone IV Wiki:** https://gswiki.play.net/Lich_XML_Data_and_Tags

## Changelog

- **2025-01-12:** Initial document created
  - Documented stream wrapper architecture
  - Explained duplication problem and solutions
  - Added reference implementation analysis
  - Defined Vaalin's approach with selective filtering
