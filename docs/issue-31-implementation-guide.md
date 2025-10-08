# Issue #31: EventBus Integration Implementation Guide

## Overview

This document provides guidance for implementing EventBus integration in XMLStreamParser based on the comprehensive test suite written in TDD fashion.

## Test Coverage

The test suite includes **30 comprehensive tests** covering:

### 1. Initialization Tests (2 tests)
- `test_parserAcceptsEventBus()` - Parser accepts EventBus in init
- `test_parserWorksWithoutEventBus()` - EventBus parameter is optional

### 2. Metadata Event Publishing (4 tests)
- `test_leftHandEventPublished()` - `<left>` publishes to `metadata/left`
- `test_rightHandEventPublished()` - `<right>` publishes to `metadata/right`
- `test_spellEventPublished()` - `<spell>` publishes to `metadata/spell`
- `test_leftHandEmptyEventPublished()` - Empty tags publish events

### 3. Progress Bar Events (4 tests)
- `test_progressBarHealthEventPublished()` - Progress bars with id publish to `metadata/progressBar/{id}`
- `test_progressBarManaEventPublished()` - Different IDs route to different events
- `test_progressBarWithoutIdDoesNotCrash()` - Graceful handling of missing id
- `test_multipleProgressBarsPublishSeparateEvents()` - Multiple bars route correctly

### 4. Prompt Events (2 tests)
- `test_promptEventPublished()` - `<prompt>` publishes to `metadata/prompt`
- `test_promptWithComplexContentEventPublished()` - Complex prompts with attributes

### 5. Stream Events (3 tests)
- `test_pushStreamThoughtsEventPublished()` - `<pushStream>` publishes to `stream/{id}`
- `test_pushStreamSpeechEventPublished()` - Different stream IDs route correctly
- `test_pushStreamWithoutIdDoesNotCrash()` - Graceful handling of missing id

### 6. Multiple Event Publishing (2 tests)
- `test_multipleMetadataEventsPublished()` - Multiple metadata tags publish multiple events
- `test_mixedTagsOnlyPublishMetadataEvents()` - Regular tags don't trigger events

### 7. No Event Publishing (4 tests)
- `test_outputTagNoEvent()` - Regular `<output>` tags don't publish
- `test_anchorTagNoEvent()` - Interactive `<a>` tags don't publish
- `test_boldTagNoEvent()` - Formatting `<b>` tags don't publish
- `test_presetTagNoEvent()` - Styling `<preset>` tags don't publish

### 8. Nested Tags (1 test)
- `test_nestedTagsOnlyPublishParentEvent()` - Only parent metadata tags publish

### 9. Chunked Parsing (2 tests)
- `test_splitMetadataTagPublishesEventOnceWhenComplete()` - Events only when tag closes
- `test_eventsPublishedInParseOrder()` - Events maintain parse order

### 10. Error Handling (1 test)
- `test_eventPublishingFailureDoesNotBreakParsing()` - Parser continues if handler throws

### 11. Real-World Scenarios (1 test)
- `test_realWorldGameOutput()` - Full simulation with mixed metadata types

## Implementation Requirements

### 1. Constructor Change

Update `XMLStreamParser.swift` to accept optional EventBus:

```swift
public actor XMLStreamParser: NSObject, XMLParserDelegate {
    // Add property
    private let eventBus: EventBus?

    // Update init
    public init(eventBus: EventBus? = nil) {
        self.eventBus = eventBus
        super.init()
    }
}
```

**Key points:**
- EventBus is **optional** - parser works without it
- Store as immutable `let` property
- Default parameter value = `nil` for backward compatibility

### 2. Event Publishing Logic

Add event publishing in `didEndElement()` after tag is fully constructed and closed:

```swift
nonisolated public func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
) {
    // ... existing tag construction logic ...

    // After tag is complete and added to currentParsedTags or parent:
    publishEventIfNeeded(for: tag)
}
```

### 3. Event Publishing Helper Method

Create helper method to determine event name and publish:

```swift
/// Publishes EventBus event for metadata tags
/// - Parameter tag: The completed GameTag to potentially publish
nonisolated private func publishEventIfNeeded(for tag: GameTag) {
    guard let eventBus = eventBus else { return }

    // Determine event name based on tag type
    let eventName: String? = {
        switch tag.name {
        // Hands metadata
        case "left": return "metadata/left"
        case "right": return "metadata/right"
        case "spell": return "metadata/spell"

        // Progress bars - dynamic event name with id
        case "progressBar":
            if let id = tag.attrs["id"] {
                return "metadata/progressBar/\(id)"
            }
            return nil // No id - don't publish

        // Prompt
        case "prompt": return "metadata/prompt"

        // Stream control - NOTE: these might not create GameTags
        // Handle in didStartElement instead if needed
        case "pushStream":
            if let id = tag.attrs["id"] {
                return "stream/\(id)"
            }
            return nil

        // Default: no event for regular tags
        default: return nil
        }
    }()

    guard let eventName = eventName else { return }

    // Publish asynchronously - don't block parsing
    Task {
        await eventBus.publish(eventName, data: tag)
    }
}
```

**Key points:**
- Check `eventBus != nil` first (early return if not set)
- Only metadata tags trigger events
- Progress bars and streams use dynamic event names with `id` attribute
- Use `Task { }` to publish async without blocking parser
- Graceful handling when attributes are missing (return `nil`)

### 4. Handle Stream Control Tags

For `<pushStream>` tags, you may need special handling since they're control directives that might not create GameTags. Consider publishing in `didStartElement()` instead:

```swift
nonisolated public func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    ...
) {
    // Handle pushStream
    if elementName == "pushStream" {
        currentStream = attributeDict["id"]
        inStream = true

        // Publish stream event
        if let eventBus = eventBus, let streamId = attributeDict["id"] {
            let streamTag = GameTag(
                name: "pushStream",
                text: nil,
                attrs: attributeDict,
                children: [],
                state: .closed,
                streamId: streamId
            )
            Task {
                await eventBus.publish("stream/\(streamId)", data: streamTag)
            }
        }

        return
    }

    // ... rest of implementation ...
}
```

### 5. Testing Strategy

Run tests incrementally:

```bash
# Test basic initialization
swift test --filter XMLStreamParserTests.test_parserAcceptsEventBus
swift test --filter XMLStreamParserTests.test_parserWorksWithoutEventBus

# Test metadata events
swift test --filter XMLStreamParserTests.test_leftHandEventPublished
swift test --filter XMLStreamParserTests.test_rightHandEventPublished
swift test --filter XMLStreamParserTests.test_spellEventPublished

# Test progress bars
swift test --filter XMLStreamParserTests.test_progressBarHealthEventPublished
swift test --filter XMLStreamParserTests.test_progressBarManaEventPublished

# Test prompt
swift test --filter XMLStreamParserTests.test_promptEventPublished

# Test streams
swift test --filter XMLStreamParserTests.test_pushStreamThoughtsEventPublished

# Test negative cases (no events for regular tags)
swift test --filter XMLStreamParserTests.test_outputTagNoEvent
swift test --filter XMLStreamParserTests.test_anchorTagNoEvent

# Run all EventBus tests
swift test --filter XMLStreamParserTests | grep "test_.*Event"

# Full test suite
make test
```

## Event Naming Conventions

Follow these conventions **exactly** as tests expect:

| Tag Type | Event Name Pattern | Example |
|----------|-------------------|---------|
| Left hand | `metadata/left` | `metadata/left` |
| Right hand | `metadata/right` | `metadata/right` |
| Spell | `metadata/spell` | `metadata/spell` |
| Progress bar | `metadata/progressBar/{id}` | `metadata/progressBar/health` |
| Prompt | `metadata/prompt` | `metadata/prompt` |
| Stream | `stream/{id}` | `stream/thoughts` |

**Important:**
- No trailing slashes
- Use exact casing (lowercase)
- Dynamic parts use attribute values (`{id}` = value of `id` attribute)

## Coverage Requirements

- **Parser logic: 100%** - This is parser logic, critical path
- All event publishing paths must be tested
- All negative cases (no event) must be tested
- Edge cases (missing attributes) must be tested

## Performance Considerations

1. **Non-blocking**: Use `Task { }` to publish events asynchronously
2. **Early exit**: Check `eventBus != nil` before any processing
3. **Minimal overhead**: Single switch statement for event name lookup
4. **No parsing impact**: EventBus errors don't affect parsing

## Verification Checklist

After implementation, verify:

- [ ] All 30 tests pass
- [ ] `make lint` passes (SwiftLint compliance)
- [ ] `make test` shows 100% coverage for event publishing code
- [ ] Parser works without EventBus (backward compatible)
- [ ] Events published in correct order
- [ ] No events for regular tags (output, a, b, preset, etc.)
- [ ] Progress bars route to correct event based on id
- [ ] Streams route to correct event based on id
- [ ] Missing attributes handled gracefully (no crash)
- [ ] EventBus errors don't break parsing

## Common Pitfalls to Avoid

1. **Publishing before tag is closed** - Events should only fire when tag reaches `.closed` state
2. **Publishing for all tags** - Only metadata tags should publish events
3. **Blocking the parser** - Use `Task { }` to publish async
4. **Ignoring missing attributes** - Gracefully handle missing `id` attributes
5. **Publishing child events** - Only parent metadata tags publish, not nested children
6. **Wrong event names** - Follow naming conventions exactly

## Related Files

- **Implementation**: `/Users/trevor/Projects/vaalin/VaalinParser/Sources/VaalinParser/XMLStreamParser.swift`
- **Tests**: `/Users/trevor/Projects/vaalin/VaalinParser/Tests/VaalinParserTests/XMLStreamParserTests.swift`
- **EventBus**: `/Users/trevor/Projects/vaalin/VaalinCore/Sources/VaalinCore/EventBus.swift`
- **GameTag**: `/Users/trevor/Projects/vaalin/VaalinCore/Sources/VaalinCore/GameTag.swift`

## Next Steps

1. Implement constructor change (simplest - gets 2 tests passing)
2. Add event publishing helper method
3. Call helper from `didEndElement()`
4. Handle special case for `pushStream` (if needed)
5. Run tests incrementally to verify each category
6. Check coverage with `make test` and view report
7. Ensure SwiftLint compliance with `make lint`

## Success Criteria

✅ All 30 EventBus integration tests pass
✅ 100% coverage on event publishing code
✅ SwiftLint compliance maintained
✅ Parser performance unaffected (< 1ms overhead per tag)
✅ Backward compatible (works without EventBus)
✅ Documentation updated with usage examples

---

**Written by:** swift-test-specialist agent
**Date:** 2025-10-08
**Issue:** #31 - Emit Tag Events to EventBus
