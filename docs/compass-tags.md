# Compass and Navigation XML Tags

**Research Issue**: #39
**Date**: 2025-10-09
**Status**: Documented

This document describes the XML tag structure used by GemStone IV to communicate room navigation and compass data to the client.

---

## Overview

GemStone IV uses **three separate XML tags** to communicate room navigation information:

1. **`<nav>`** - Room identification (UID/room number)
2. **`<compass>`** - Available exits (directions player can move)
3. **`<streamWindow id="main">`** - Room title/name

These tags work together to provide complete room context for navigation UI components.

---

## Tag Specifications

### 1. `<nav>` Tag - Room Identification

**Purpose**: Identifies the current room by unique ID (UID).

**Structure**: Self-closing tag with attributes
```xml
<nav rm="12345"/>
```

**Attributes**:
- `rm` (required): Room UID as integer (e.g., `12345`)

**Timing**: Sent when entering a new room, **before** the `<compass>` tag

**Event Bus Mapping** (for Vaalin):
- Event name: `metadata/nav`
- Payload: `GameTag` with `attrs["rm"]` containing room ID

**Lich 5 Reference**:
```ruby
# From lib/common/xmlparser.rb:248
if name == 'nav'
  @previous_nav_rm = @room_id
  @room_id = attributes['rm'].to_i
end
```

**Usage Notes**:
- Room ID persists across reconnects for map tracking
- Used by navigation scripts (e.g., `go2`) for pathfinding
- In rooms without official IDs, Lich generates MD5 hash of room description

---

### 2. `<compass>` Tag - Available Exits

**Purpose**: Lists all available movement directions from current room.

**Structure**: Container tag with `<dir>` children
```xml
<compass>
  <dir value="n"/>
  <dir value="ne"/>
  <dir value="e"/>
  <dir value="se"/>
  <dir value="s"/>
  <dir value="sw"/>
  <dir value="w"/>
  <dir value="nw"/>
  <dir value="up"/>
  <dir value="down"/>
  <dir value="out"/>
</compass>
```

**Child Elements**:
- `<dir>`: Represents one available exit
  - Attribute `value`: Short direction code (see **Direction Values** below)

**Timing**: Sent **after** the `<nav>` tag when entering a new room

**Event Bus Mapping** (for Vaalin):
- Event name: `metadata/compass`
- Payload: `GameTag` with `children` array of `<dir>` tags
- Extract exits: `tag.children.map { $0.attrs["value"] }`

**Illthorn Reference**:
```typescript
// From compass-rose-container.lit.ts:42-47
{
  eventName: "metadata/compass",
  handler: (tag: GameTag) => {
    if (tag?.children) {
      this._activeDirs = tag.children
        .map(({ attrs }) => attrs.value)
        .filter((value): value is string => typeof value === "string");
    }
  }
}
```

**Lich 5 Reference**:
```ruby
# From lib/common/xmlparser.rb:572-574
if @room_window_disabled and (name == 'dir') and @active_tags.include?('compass')
  @room_exits.push(LONGDIR[attributes['value']])
end
```

**Empty Compass**:
```xml
<compass/>
```
Indicates no available exits (dead end, or all exits hidden).

---

### 3. `<streamWindow>` Tag - Room Title

**Purpose**: Provides the formatted room title/name.

**Structure**: Tag with `subtitle` attribute
```xml
<streamWindow id="main" subtitle=" - [Town Square, Market] - 12345" ifClosed="" resident="true"/>
```

**Attributes**:
- `id`: Stream window identifier (typically `"main"`)
- `subtitle`: Formatted room title with pattern `" - [Room Name] - {room_id}"`
- `ifClosed`: (optional) behavior when window closed
- `resident`: (optional) whether window is permanent

**Event Bus Mapping** (for Vaalin):
- Event name: `metadata/streamWindow/room`
- Payload: `GameTag` with `attrs["subtitle"]` containing formatted title

**Illthorn Reference**:
```typescript
// From compass-rose-container.lit.ts:57-65
{
  eventName: "metadata/streamWindow/room",
  handler: (tag: GameTag) => {
    let title = (tag.attrs?.subtitle || "").toString();
    // Remove leading hyphen and spaces
    while (title.startsWith("-") || title.startsWith(" ")) {
      title = title.substring(1);
    }
    this._roomTitle = title;
  }
}
```

**Lich 5 Parsing**:
```ruby
# From lib/common/xmlparser.rb:353-356
if Lich.display_uid == false && attributes['subtitle'][3..-1] =~ / - \d+$/
  Lich.display_uid = true
end
@room_title = '[' + attributes['subtitle'][3..-1].gsub(/ - \d+$/, '') + ']'
```

**Formatted Title Examples**:
- `" - [Town Square] - 228"`
- `" - [Moonstone Creek Bridge] - 5024"`
- `" - [Temple Courtyard] - 1001"`

**Extracted Title** (after parsing):
- `"[Town Square]"`
- `"[Moonstone Creek Bridge]"`
- `"[Temple Courtyard]"`

---

## Direction Values

**Standard Directions** (from Lich 5 `LONGDIR` constant):

| Short Code | Full Name    | Category   |
|------------|--------------|------------|
| `n`        | north        | Cardinal   |
| `e`        | east         | Cardinal   |
| `s`        | south        | Cardinal   |
| `w`        | west         | Cardinal   |
| `ne`       | northeast    | Diagonal   |
| `se`       | southeast    | Diagonal   |
| `sw`       | southwest    | Diagonal   |
| `nw`       | northwest    | Diagonal   |
| `up`       | up           | Vertical   |
| `down`     | down         | Vertical   |
| `out`      | out          | Special    |

**Usage Notes**:
- All values are **lowercase**
- No other direction values are used in GemStone IV
- Custom movement commands (e.g., `climb tree`) are not sent as compass directions

---

## Complete Example

**Entering a new room with multiple exits:**

```xml
<!-- Room identification -->
<nav rm="228"/>

<!-- Room description stream -->
<pushStream id="room"/>
<style id=""/>
<streamWindow id="main" subtitle=" - [Town Square, Market] - 228" ifClosed="" resident="true"/>
[Town Square, Market]
<style id=""/>A large bronze statue stands in the center of the square, depicting a warrior in battle gear. Cobblestone paths lead off in several directions.
<style id=""/>Obvious exits: <d>north</d>, <d>south</d>, <d>east</d>, <d>west</d>, <d>up</d>
<popStream/>

<!-- Available exits for compass UI -->
<compass>
  <dir value="n"/>
  <dir value="s"/>
  <dir value="e"/>
  <dir value="w"/>
  <dir value="up"/>
</compass>
```

**Parsed Result**:
- **Room ID**: `228`
- **Room Title**: `"[Town Square, Market]"`
- **Available Exits**: `["n", "s", "e", "w", "up"]`

---

## Tag Sequence

**Typical sequence when entering a new room:**

1. `<nav rm="..."/>` - Room ID established
2. `<pushStream id="room"/>` - Room description stream begins
3. `<streamWindow>` - Room title announced
4. Room description text (with styling)
5. `<popStream/>` - Room description stream ends
6. `<compass>...</compass>` - Available exits announced

**Special Cases**:

### Room with Disabled Room Window
Some locations disable the graphical room window (e.g., special areas):
```xml
<nav rm="0"/>
<style id=""/>
[Room window disabled at this location.]
<style id=""/>
<compass>
  <dir value="out"/>
</compass>
```

In this case:
- Room ID is `0` (or generated hash by Lich)
- Room description is text-only
- Compass still provides exit data

### DragonRealms Differences
DragonRealms (DR) uses slightly different formatting:
```xml
<streamWindow id="main" subtitle="[Bosque Deriel, Hermit's Shacks] (230008)"/>
```
- Format: `[Room Name] (UID)` instead of ` - [Room Name] - UID`
- Requires different regex parsing

---

## Implementation Guidance for Vaalin

### Event Bus Integration

Based on Illthorn's architecture, Vaalin should emit these events:

```swift
// VaalinParser/XMLStreamParser.swift

// When <nav> tag is parsed:
eventBus.publish("metadata/nav", data: navTag)

// When <compass> tag is parsed:
eventBus.publish("metadata/compass", data: compassTag)

// When <streamWindow id="main"> is parsed:
eventBus.publish("metadata/streamWindow/room", data: streamWindowTag)
```

### Compass Panel View Model

```swift
// VaalinUI/ViewModels/CompassPanelViewModel.swift

@Observable
@MainActor
class CompassPanelViewModel {
    var roomId: Int = 0
    var roomTitle: String = ""
    var availableExits: [String] = []

    init(eventBus: EventBus) {
        Task {
            // Subscribe to nav events
            await eventBus.subscribe("metadata/nav") { tag in
                if let roomIdStr = tag.attrs["rm"] as? String,
                   let roomId = Int(roomIdStr) {
                    await MainActor.run {
                        self.roomId = roomId
                    }
                }
            }

            // Subscribe to compass events
            await eventBus.subscribe("metadata/compass") { tag in
                let exits = tag.children
                    .compactMap { $0.attrs["value"] as? String }
                await MainActor.run {
                    self.availableExits = exits
                }
            }

            // Subscribe to room title events
            await eventBus.subscribe("metadata/streamWindow/room") { tag in
                if let subtitle = tag.attrs["subtitle"] as? String {
                    var title = subtitle
                    // Remove leading " - " and trailing " - {room_id}"
                    if title.hasPrefix(" - ") {
                        title = String(title.dropFirst(3))
                    }
                    if let range = title.range(of: #" - \d+$"#, options: .regularExpression) {
                        title.removeSubrange(range)
                    }
                    await MainActor.run {
                        self.roomTitle = title
                    }
                }
            }
        }
    }
}
```

### Direction Mapping for Compass Rose

```swift
// VaalinCore/DirectionMapping.swift

enum CompassDirection: String, CaseIterable {
    case north = "n"
    case northeast = "ne"
    case east = "e"
    case southeast = "se"
    case south = "s"
    case southwest = "sw"
    case west = "w"
    case northwest = "nw"
    case up = "up"
    case down = "down"
    case out = "out"

    var fullName: String {
        switch self {
        case .north: return "north"
        case .northeast: return "northeast"
        case .east: return "east"
        case .southeast: return "southeast"
        case .south: return "south"
        case .southwest: return "southwest"
        case .west: return "west"
        case .northwest: return "northwest"
        case .up: return "up"
        case .down: return "down"
        case .out: return "out"
        }
    }

    var angle: Double? {
        switch self {
        case .north: return 0
        case .northeast: return 45
        case .east: return 90
        case .southeast: return 135
        case .south: return 180
        case .southwest: return 225
        case .west: return 270
        case .northwest: return 315
        default: return nil  // up, down, out not on compass
        }
    }
}
```

---

## Testing Recommendations

### Parser Tests

```swift
// VaalinParser/Tests/XMLStreamParserTests.swift

@Test func test_parseNavTag() async throws {
    let parser = XMLStreamParser()
    let xml = "<nav rm=\"228\"/>"

    let tags = await parser.parse(xml)

    #expect(tags.count == 1)
    #expect(tags[0].name == "nav")
    #expect(tags[0].attrs["rm"] as? String == "228")
}

@Test func test_parseCompassTag() async throws {
    let parser = XMLStreamParser()
    let xml = """
    <compass>
      <dir value="n"/>
      <dir value="s"/>
      <dir value="e"/>
    </compass>
    """

    let tags = await parser.parse(xml)

    #expect(tags.count == 1)
    #expect(tags[0].name == "compass")
    #expect(tags[0].children.count == 3)

    let exits = tags[0].children.compactMap { $0.attrs["value"] as? String }
    #expect(exits == ["n", "s", "e"])
}

@Test func test_parseStreamWindow() async throws {
    let parser = XMLStreamParser()
    let xml = #"<streamWindow id="main" subtitle=" - [Town Square] - 228"/>"#

    let tags = await parser.parse(xml)

    #expect(tags.count == 1)
    #expect(tags[0].name == "streamWindow")
    #expect(tags[0].attrs["id"] as? String == "main")
    #expect((tags[0].attrs["subtitle"] as? String)?.contains("[Town Square]") == true)
}
```

---

## References

**Primary Sources**:
- Lich 5 source: `/Users/trevor/Projects/lich-5/lib/common/xmlparser.rb`
- Lich 5 constants: `/Users/trevor/Projects/lich-5/lib/constants.rb`
- Illthorn compass container: `/Users/trevor/Projects/illthorn/src/frontend/components/session/compass/compass-rose-container.lit.ts`
- Illthorn event bus types: `/Users/trevor/Projects/illthorn/src/frontend/util/bus.ts`

**GemStone IV Resources**:
- GemStone IV Wiki: https://gswiki.play.net
- Lich Scripting Reference: https://gswiki.play.net/Lich:Software/Scripting_reference

---

## Changelog

**2025-10-09** - Initial documentation
- Researched tag structure from Lich 5 source code
- Documented `<nav>`, `<compass>`, and `<streamWindow>` tags
- Provided Swift implementation guidance
- Added complete examples and test recommendations
