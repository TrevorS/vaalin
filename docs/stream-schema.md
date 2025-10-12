# Stream Configuration Schema

**File**: `Vaalin/Resources/stream-config.json`
**Purpose**: Defines available game streams for filtering and organization
**Related Issues**: #48, #49, #50, #51, #52, #53 (Phase 4 - Streams & Filtering)

## Overview

The stream configuration file defines how different types of game messages are categorized, displayed, and filtered in the Vaalin UI. Each stream represents a distinct category of game content (thoughts, speech, combat messages, etc.) that can be selectively shown or hidden.

## Schema Specification

The configuration file contains a single array of stream definitions:

```json
{
  "streams": [ /* array of stream objects */ ]
}
```

### Stream Object Fields

Each stream object has the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Unique identifier matching `<pushStream id="...">` XML tags from game server |
| `label` | string | ✅ | Human-readable display name shown in UI (e.g., stream chips, settings) |
| `defaultOn` | boolean | ✅ | Whether stream is visible by default on first launch |
| `color` | string | ✅ | Color key from `catppuccin-mocha.json` palette (e.g., "green", "teal", "subtext1") |
| `aliases` | array | ✅ | Alternative stream IDs that should be treated as this stream (empty array if none) |

### Field Details

#### `id` (string)

The primary identifier for the stream. Must exactly match the `id` attribute in `<pushStream id="...">` tags sent by the game server.

**Examples**: `"thoughts"`, `"speech"`, `"whispers"`, `"logons"`, `"expr"`, `"familiar"`

**Usage**: When parser encounters `<pushStream id="thoughts">`, content is routed to the "thoughts" stream buffer.

#### `label` (string)

Display name shown to users in the UI.

**Examples**: `"Thoughts"`, `"Speech"`, `"Whispers"`, `"Logons"`, `"Experience"`, `"Familiar"`

**Usage**: Appears in stream filter chips, settings panels, and context menus.

#### `defaultOn` (boolean)

Controls initial visibility when user first launches Vaalin or resets stream settings.

**Values**:
- `true`: Stream visible by default (e.g., important streams like "thoughts", "speech")
- `false`: Stream hidden by default (e.g., verbose streams like "expr")

**User Override**: Users can change visibility in settings; this only affects first launch.

#### `color` (string)

Color key referencing the Catppuccin Mocha palette defined in `Vaalin/Resources/themes/catppuccin-mocha.json`.

**Valid Keys**:
- Base colors: `"rosewater"`, `"flamingo"`, `"pink"`, `"mauve"`, `"red"`, `"maroon"`, `"peach"`, `"yellow"`, `"green"`, `"teal"`, `"sky"`, `"sapphire"`, `"blue"`, `"lavender"`
- Text colors: `"text"`, `"subtext1"`, `"subtext0"`
- Surface colors: `"overlay2"`, `"overlay1"`, `"overlay0"`, `"surface2"`, `"surface1"`, `"surface0"`, `"base"`, `"mantle"`, `"crust"`

**Usage**: Stream chip background color, stream view accent color, unread badge color.

**Example Color Mappings**:
- `"thoughts"` → `"subtext1"` (muted text color for introspection)
- `"speech"` → `"green"` (friendly, communicative)
- `"whispers"` → `"teal"` (private, distinct)
- `"logons"` → `"yellow"` (attention-grabbing but not alarming)

#### `aliases` (array of strings)

Alternative stream IDs that should be treated as the same stream. Useful for:
- Server inconsistencies (e.g., `"whisper"` vs `"whispers"`)
- Related events (e.g., `"logon"`, `"logoff"`, `"death"` all route to `"logons"`)
- Backwards compatibility with Lich variants

**Example**:
```json
{
  "id": "whispers",
  "aliases": ["whisper"]
}
```

When parser encounters `<pushStream id="whisper">`, it treats it as `"whispers"`.

**Empty Array**: `[]` if no aliases exist (most common case).

## Default Streams

Vaalin ships with six default streams based on common GemStone IV gameplay patterns:

### 1. Thoughts (`thoughts`)
- **Label**: "Thoughts"
- **Default**: ON
- **Color**: Subtext1 (muted gray)
- **Content**: Character thoughts, internal dialogue, tells from other players
- **XML Tags**: `<pushStream id="thoughts">`

### 2. Speech (`speech`)
- **Label**: "Speech"
- **Default**: ON
- **Color**: Green
- **Content**: Spoken dialogue in room, says, shouts
- **XML Tags**: `<pushStream id="speech">`

### 3. Whispers (`whispers`)
- **Label**: "Whispers"
- **Default**: ON
- **Color**: Teal
- **Content**: Whispered messages, private communication
- **XML Tags**: `<pushStream id="whispers">`, `<pushStream id="whisper">`
- **Aliases**: `["whisper"]`

### 4. Logons (`logons`)
- **Label**: "Logons"
- **Default**: ON
- **Color**: Yellow
- **Content**: Player arrivals, departures, deaths, disconnects
- **XML Tags**: `<pushStream id="logons">`, `<pushStream id="logon">`, `<pushStream id="logoff">`, `<pushStream id="death">`
- **Aliases**: `["logon", "logoff", "death"]`

### 5. Experience (`expr`)
- **Label**: "Experience"
- **Default**: OFF (verbose)
- **Color**: Sapphire
- **Content**: Experience gain messages, skill increases, level ups
- **XML Tags**: `<pushStream id="expr">`, `<pushStream id="experience">`
- **Aliases**: `["experience"]`

### 6. Familiar (`familiar`)
- **Label**: "Familiar"
- **Default**: OFF
- **Color**: Mauve
- **Content**: Familiar-related messages, companion actions
- **XML Tags**: `<pushStream id="familiar">`

## Usage in Code

### Loading Configuration (Phase 4 - Issue #49)

```swift
import Foundation

struct StreamConfig: Codable {
    let streams: [StreamDefinition]
}

struct StreamDefinition: Codable, Identifiable {
    let id: String
    let label: String
    let defaultOn: Bool
    let color: String
    let aliases: [String]
}

// Load from bundle
func loadStreamConfig() throws -> StreamConfig {
    guard let url = Bundle.main.url(forResource: "stream-config", withExtension: "json") else {
        throw ConfigError.fileNotFound
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(StreamConfig.self, from: data)
}
```

### Color Resolution (Phase 4 - Issue #50)

```swift
// Resolve color key to actual Color
func resolveStreamColor(colorKey: String, theme: Theme) -> Color {
    return theme.palette[colorKey] ?? theme.palette["text"]!
}
```

### Alias Matching (Phase 4 - Issue #49)

```swift
// Find stream definition by ID or alias
func findStream(byID id: String, config: StreamConfig) -> StreamDefinition? {
    return config.streams.first { stream in
        stream.id == id || stream.aliases.contains(id)
    }
}
```

## Adding Custom Streams

Users can edit `stream-config.json` to add custom streams for Lich scripts or game events:

```json
{
  "id": "combat",
  "label": "Combat",
  "defaultOn": true,
  "color": "red",
  "aliases": ["attack", "defend"]
}
```

**Requirements**:
- `id` must match `<pushStream id="...">` tags from Lich/game
- `color` must be valid Catppuccin Mocha palette key
- File must remain valid JSON (use validator before saving)

**Limitations**:
- Unknown stream IDs logged and ignored (not auto-created)
- Maximum recommended streams: 10-12 (UI space constraints)
- Duplicate IDs or aliases will cause undefined behavior

## Integration with Phase 4 Features

This configuration file is foundational for Phase 4 stream filtering features:

- **Issue #49**: Stream Registry (loads this config)
- **Issue #50**: Stream Chips (renders UI based on config)
- **Issue #51**: Stream Buffering (routes content to buffers)
- **Issue #52**: Mirror Mode Toggle (uses defaultOn for initial state)
- **Issue #53**: Stream View (displays stream names and colors)

## Related Files

- `Vaalin/Resources/themes/catppuccin-mocha.json` - Color palette reference
- `docs/requirements.md` - FR-4.1 through FR-4.6 (Stream Requirements)
- `docs/tasks.md` - TASK-S1 through TASK-S6 (Stream Implementation Tasks)

## Validation

To validate `stream-config.json`:

1. **JSON Syntax**: Use `jsonlint` or online validators
2. **Color Keys**: Verify all `color` values exist in `catppuccin-mocha.json` palette
3. **Required Fields**: Ensure all streams have `id`, `label`, `defaultOn`, `color`, `aliases`
4. **Unique IDs**: No duplicate `id` values across streams
5. **Alias Conflicts**: No alias appears in multiple streams

## Example Configuration

Complete example showing all default streams:

```json
{
  "streams": [
    {
      "id": "thoughts",
      "label": "Thoughts",
      "defaultOn": true,
      "color": "subtext1",
      "aliases": []
    },
    {
      "id": "speech",
      "label": "Speech",
      "defaultOn": true,
      "color": "green",
      "aliases": []
    },
    {
      "id": "whispers",
      "label": "Whispers",
      "defaultOn": true,
      "color": "teal",
      "aliases": ["whisper"]
    },
    {
      "id": "logons",
      "label": "Logons",
      "defaultOn": true,
      "color": "yellow",
      "aliases": ["logon", "logoff", "death"]
    },
    {
      "id": "expr",
      "label": "Experience",
      "defaultOn": false,
      "color": "sapphire",
      "aliases": ["experience"]
    },
    {
      "id": "familiar",
      "label": "Familiar",
      "defaultOn": false,
      "color": "mauve",
      "aliases": []
    }
  ]
}
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-12
**Status**: Implemented (Issue #48)
