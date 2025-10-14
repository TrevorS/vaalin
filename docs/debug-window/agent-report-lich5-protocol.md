# Lich 5 Detachable Client Protocol Analysis

**Research Date:** 2025-10-12
**Source:** `/Users/trevor/Projects/lich-5/` (Ruby implementation)
**Purpose:** Understand exactly what XML data Lich sends to detachable clients
**Relevance:** Critical for debug window design - shows what we'll be displaying

---

## Table of Contents

1. [Protocol Overview](#protocol-overview)
2. [Data Flow Architecture](#data-flow-architecture)
3. [XML Format and Encoding](#xml-format-and-encoding)
4. [XML Cleaning and Processing](#xml-cleaning-and-processing)
5. [Initialization Sequence](#initialization-sequence)
6. [Frontend Detection and Behavior](#frontend-detection-and-behavior)
7. [Debug Mode Discovery](#debug-mode-discovery)
8. [Session Files](#session-files)
9. [Critical Code Locations](#critical-code-locations)
10. [Recommendations for Debug Window](#recommendations-for-debug-window)
11. [Testing with Lich](#testing-with-lich)

---

## Protocol Overview

### What is Lich?

Lich is a **man-in-the-middle proxy** between GemStone IV/DragonRealms game servers and client frontends.

```
Game Server (simutronics.com)
    ↓ (raw XML + SGE protocol)
Lich (middleware/proxy)
    ↓ (processed XML)
Frontend (Vaalin, Illthorn, Stormfront, etc.)
```

### Detachable Client Mode

When started with `--detachable-client=8000`, Lich:

1. **Creates TCP server** on localhost:8000
2. **Accepts one client connection** at a time
3. **Forwards processed XML** from game to client
4. **Forwards commands** from client to game
5. **Runs user scripts** that can modify the data flow

### Key Architectural Decision

**Lich sends CLEANED, PROCESSED XML** - not raw game output.

This means:
- Invalid characters fixed
- Malformed tags corrected
- User scripts can modify output (DownstreamHook)
- Some tags added/removed based on game quirks

**Implication for debug window:** The XML we display is what Lich sends (post-processing), not what the game server originally sent.

---

## Data Flow Architecture

### Complete Flow

```
┌─────────────────────────────────────────────────────────┐
│ Game Server (GemStone IV / DragonRealms)               │
│ Sends raw XML via TCP socket                           │
└────────────────────┬────────────────────────────────────┘
                     ↓ (TCP socket, raw XML + SGE)
┌────────────────────────────────────────────────────────┐
│ Lich Main Thread (lib/games.rb: start_main_thread)    │
│ - Receives raw server string                          │
│ - process_server_string()                             │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│ XMLCleaner Module (lib/games.rb:98-170)               │
│ - clean_nested_quotes()                                │
│ - fix_invalid_characters()                             │
│ - fix_xml_tags()                                       │
└────────────────────┬───────────────────────────────────┘
                     ↓ (cleaned XML string)
┌────────────────────────────────────────────────────────┐
│ REXML::Document.parse_stream()                         │
│ - Parses XML, updates XMLData state                    │
│ - Fires callbacks for tag events                       │
└────────────────────┬───────────────────────────────────┘
                     ↓ (state updated)
┌────────────────────────────────────────────────────────┐
│ DownstreamHook.run() (lib/games.rb:445-472)           │
│ - User scripts can modify output                       │
│ - Can add/remove/change text                           │
└────────────────────┬───────────────────────────────────┘
                     ↓ (potentially modified)
┌────────────────────────────────────────────────────────┐
│ send_to_client() (lib/games.rb:484-498)               │
│ - $_DETACHABLE_CLIENT_.write(alt_string)              │
└────────────────────┬───────────────────────────────────┘
                     ↓ (TCP socket, processed XML)
┌────────────────────────────────────────────────────────┐
│ Detachable Client (Vaalin, Illthorn, etc.)            │
│ Receives cleaned XML via TCP                           │
└────────────────────────────────────────────────────────┘
```

### Critical Points

1. **Cleaning happens first** - XML is fixed before parsing
2. **State is updated** - XMLData global stores current state
3. **Scripts can modify** - DownstreamHook allows user modifications
4. **Same output for all frontends** - Detachable clients get same XML as Stormfront

---

## XML Format and Encoding

### Character Encoding

**Encoding:** UTF-8 (Ruby's default string encoding)

**Line Terminator:** `\r\n` (CRLF)

**Entities:** HTML entities used (`&lt;`, `&gt;`, `&amp;`, etc.), not raw UTF-8 characters

### Chunking Behavior

Lich uses `socket.gets`, so XML is **line-based**:
- Each `write()` corresponds to one logical line
- Tags can span multiple lines
- Parser must handle incomplete tags

**Example:**
```
<pushStream id="thoughts">\r\n
You think, "This is a test."\r\n
<popStream>\r\n
```

### Buffering

```ruby
# lib/main/main.rb:702
$_DETACHABLE_CLIENT_.sync = true
```

**`sync = true`** means:
- No Ruby-level buffering
- Immediate transmission (no batching)
- Each write() sent immediately to TCP socket

**Implication:** Debug window will see data in small chunks, not large batches.

### What Gets Sent

Detachable clients receive:

✅ **Included:**
- Stormfront XML tags (`<pushStream>`, `<preset>`, `<progressBar>`, etc.)
- Game text (between tags)
- XML comments (rarely used, but valid)
- Cleaned/corrected XML

❌ **Not included:**
- GSL tags (Wizard-specific, `\034GSx...` escapes)
- SGE protocol overhead (handled by Lich)
- Invalid/malformed XML (cleaned before sending)

---

## XML Cleaning and Processing

Lich performs **extensive XML cleanup** to work around game server bugs and inconsistencies.

### XMLCleaner Module

**File:** `lib/games.rb:98-170`

Three main cleaning functions:

#### 1. clean_nested_quotes

**Problem:** Game server sometimes sends improperly escaped quotes in attributes.

**Example:**
```xml
<a noun='gem'>a blue 'sapphire' gem</a>
```

**Fix:**
```xml
<a noun='gem'>a blue &apos;sapphire&apos; gem</a>
```

**Code:**
```ruby
def self.clean_nested_quotes(xml)
  xml.gsub(/<([^<>]*)>/) do |match|
    tag = match
    tag.gsub!(/(['"])([^\1]*)\1/) do |attr|
      quote = $1
      value = $2
      if value =~ /#{quote}/
        value.gsub!(quote, '&apos;')
      end
      "#{quote}#{value}#{quote}"
    end
    tag
  end
end
```

#### 2. fix_invalid_characters

**Problem:** Game server sends invalid XML characters.

**Fixes:**
- Unescaped `&` → `&amp;`
- Bell characters `\a` → removed
- Poorly encoded apostrophes `\x92` → `'`
- Other control characters → escaped or removed

**Code:**
```ruby
def self.fix_invalid_characters(xml)
  # Escape unescaped ampersands
  xml.gsub!(/&(?!(?:lt|gt|amp|apos|quot|#\d+|#x[0-9a-fA-F]+);)/, '&amp;')

  # Remove bell characters
  xml.gsub!(/\a/, '')

  # Fix poorly encoded apostrophes
  xml.gsub!(/\x92/, "'")

  # Remove other control characters (except \t, \n, \r)
  xml.gsub!(/[\x00-\x08\x0B-\x0C\x0E-\x1F]/, '')

  xml
end
```

#### 3. fix_xml_tags

**Problem:** Game server sometimes sends incomplete or broken tags.

**Fixes:**
- Open-ended `<dynaStream>` gets closing tag
- Open-ended `<component>` gets closing tag
- Dangling closing tags removed
- Broken empath appraisal tags fixed

**Code:**
```ruby
def self.fix_xml_tags(xml)
  # Close open dynaStream tags
  if xml =~ /<dynaStream[^>]*>/ && xml !~ /<\/dynaStream>/
    xml += '</dynaStream>'
  end

  # Close open component tags
  if xml =~ /<component[^>]*>/ && xml !~ /<\/component>/
    xml += '</component>'
  end

  # Remove dangling closing tags
  xml.gsub!(/<\/(\w+)>/) do |match|
    tag_name = $1
    if xml !~ /<#{tag_name}[^>]*>/
      ''  # Remove dangling close tag
    else
      match
    end
  end

  xml
end
```

### Game-Specific Fixes

#### GemStone IV

**Problem:** Combat stream tags sometimes missing `<popStream>`

**Fix:**
```ruby
if $game_name == 'GemStone'
  if xml =~ /<pushStream id="combat">/ && xml !~ /<popStream>/
    # Insert missing popStream after combat text
    xml.sub!(/<pushStream id="combat">(.*?)(?=<(?:push|pop)Stream|$)/m) do
      "#{$&}<popStream>"
    end
  end
end
```

#### DragonRealms

**Problem:** Duplicate combat stream tags

**Fix:**
```ruby
if $game_name == 'DragonRealms'
  # Remove duplicate pushStream tags
  xml.gsub!(/<pushStream id="combat">.*?<pushStream id="combat">/, '<pushStream id="combat">')
end
```

---

## Initialization Sequence

When a detachable client connects, Lich sends an **initialization burst** with current game state.

### Purpose

Ensures client has current state immediately, not just incremental updates.

### What's Sent

**File:** `lib/main/main.rb:718-751`

```ruby
init_str = ""

# Vitals (health, mana, spirit, stamina)
init_str.concat "<progressBar id='mana' value='0' text='mana #{XMLData.mana}/#{XMLData.max_mana}'/>"
init_str.concat "<progressBar id='health' value='0' text='health #{XMLData.health}/#{XMLData.max_health}'/>"
init_str.concat "<progressBar id='spirit' value='0' text='spirit #{XMLData.spirit}/#{XMLData.max_spirit}'/>"
init_str.concat "<progressBar id='stamina' value='0' text='stamina #{XMLData.stamina}/#{XMLData.max_stamina}'/>"

# Active spell
init_str.concat "<spell>#{XMLData.spell}</spell>"

# Indicators (bleeding, poisoned, etc.)
XMLData.indicators.each { |name, value|
  init_str.concat "<indicator id='#{name}' visible='#{value}'/>"
}

# Stance, mind state, encumbrance
init_str.concat "<progressBar id='pbarStance' value='#{XMLData.stance_value}'/>"
init_str.concat "<progressBar id='mindState' value='#{XMLData.mind_value}' text='#{XMLData.mind_text}'/>"
init_str.concat "<progressBar id='encumlevel' value='#{XMLData.encumbrance_value}' text='#{XMLData.encumbrance_text}'/>"

# Hands (left/right items)
init_str.concat "<right>#{XMLData.right_hand}</right>"
init_str.concat "<left>#{XMLData.left_hand}</left>"

# Injuries (wounds to body parts)
XMLData.injuries.each { |part, level|
  init_str.concat "<image id='#{part}' name='Injury#{level}'/>"
}

# Compass (available exits)
init_str.concat "<compass>"
XMLData.room_exits.each { |dir|
  init_str.concat "<dir value='#{dir}'/>"
}
init_str.concat "</compass>"

# Send initialization string
$_DETACHABLE_CLIENT_.puts init_str
```

### Example Initialization

```xml
<progressBar id='mana' value='0' text='mana 45/55'/>
<progressBar id='health' value='0' text='health 120/120'/>
<progressBar id='spirit' value='0' text='spirit 10/10'/>
<progressBar id='stamina' value='0' text='stamina 90/90'/>
<spell>None</spell>
<indicator id='IconBLEEDING' visible='n'/>
<indicator id='IconPOISONED' visible='n'/>
<indicator id='IconSTUNNED' visible='n'/>
<progressBar id='pbarStance' value='60'/>
<progressBar id='mindState' value='80' text='clear'/>
<progressBar id='encumlevel' value='20' text='light'/>
<right>an iron sword</right>
<left>a wooden shield</left>
<image id="leftArm" name="Injury2"/>
<image id="rightLeg" name="Injury1"/>
<compass>
  <dir value='n'/>
  <dir value='e'/>
  <dir value='s'/>
  <dir value='out'/>
</compass>
```

### Timing

**When:** Immediately after client connects and before any game data

**Why:** Client needs current state to render UI correctly

**Debug window implication:** First chunk received will be large initialization burst, not incremental game output

---

## Frontend Detection and Behavior

### Frontend Type Detection

**File:** `lib/main/main.rb:716-717`

```ruby
unless ARGV.include?('--genie')
  $frontend = 'profanity'  # Detachable client mode
end
```

**`$frontend = 'profanity'`** means:
- Use Stormfront XML format
- No GSL tag translation (Wizard-specific)
- No `sf_to_wiz()` conversion

### Frontend-Specific Behavior

#### Profanity Mode (Detachable Clients)

**Characteristics:**
- Sends Stormfront-compatible XML
- No escape sequences for Wizard
- Direct pass-through of cleaned XML

#### Wizard Mode (`--genie` flag)

**Different behavior:**
- Translates Stormfront tags to GSL
- Adds `\034GSx...` escape sequences
- Different tag structure

**Example:**
```
# Stormfront: <pushBold/>Bold text<popBold/>
# Wizard GSL: \034GSL<b>Bold text\034GSL</b>
```

#### Stormfront Mode (via eAccess)

**Not relevant for detachable clients** - only when Lich connects via eAccess

---

## Debug Mode Discovery

Lich has a **built-in debug mode** via Ruby global variable.

### Enabling Debug Mode

**In a Lich script:**
```ruby
$deep_debug = true
```

**Effect:**
```ruby
# In lib/games.rb:308
pp server_string if defined?($deep_debug) && $deep_debug
```

**Output:** Pretty-prints every server string before processing (uses Ruby's `pp` method)

### Example Debug Output

```
"<pushStream id=\"thoughts\"/>\nYou think, \"This is interesting.\"\n<popStream/>\n"
"<prompt>&gt;</prompt>\n"
"<pushBold/><preset id=\"speech\">You say, \"Hello!\"</preset><popBold/>\n"
```

### Using for Testing

```ruby
# In autostart script
if CharSettings['debug_raw_xml']
  $deep_debug = true
  echo "Deep debug mode enabled - all server strings will be logged"
end
```

---

## Session Files

### Purpose

Allows clients to discover active Lich sessions programmatically.

### Location

```ruby
# File: lib/common/front-end.rb
@tmp_session_dir = File.join(Dir.tmpdir, "simutronics", "sessions")
# Result: /tmp/simutronics/sessions/
```

### File Format

**Filename:** `{CharacterName}.session`

**Format:** JSON

**Content:**
```json
{
  "name": "CharacterName",
  "host": "127.0.0.1",
  "port": 8000,
  "key": "optional-auth-key"
}
```

### Usage

Clients can:
1. Scan `/tmp/simutronics/sessions/` for `.session` files
2. Parse JSON to get connection details
3. Connect to `host:port`
4. No authentication required (localhost only)

### Example Code (Swift)

```swift
func discoverLichSessions() -> [LichSession] {
  let sessionDir = "/tmp/simutronics/sessions"
  let fm = FileManager.default

  guard let files = try? fm.contentsOfDirectory(atPath: sessionDir) else {
    return []
  }

  return files
    .filter { $0.hasSuffix(".session") }
    .compactMap { filename in
      let path = "\(sessionDir)/\(filename)"
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONDecoder().decode(LichSession.self, from: data) else {
        return nil
      }
      return json
    }
}

struct LichSession: Codable {
  let name: String
  let host: String
  let port: Int
  let key: String?
}
```

---

## Critical Code Locations

All paths relative to `/Users/trevor/Projects/lich-5/`

### Main Files

**`lib/main/main.rb`**
- Line 693-782: Detachable client server loop
- Line 718-751: Initialization string generation
- Line 755-765: Client command reading

**`lib/games.rb`**
- Line 98-170: XMLCleaner module (cleaning functions)
- Line 266-332: Server string processing (entry point)
- Line 445-472: DownstreamHook execution
- Line 484-498: send_to_client() (output to client)

**`lib/common/xmlparser.rb`**
- REXML::StreamListener implementation
- Tag parsing callbacks
- XMLData state updates

**`lib/common/front-end.rb`**
- Session file creation
- Frontend initialization

### Key Functions

**`start_main_thread`** (lib/games.rb:266-332)
- Main game loop
- Receives from server
- Processes and sends to client

**`process_server_string`** (called from start_main_thread)
- Entry point for all server data
- Calls XMLCleaner
- Parses with REXML
- Runs downstream hooks

**`send_to_client`** (lib/games.rb:484-498)
- Final output function
- Writes to `$_DETACHABLE_CLIENT_` socket
- Error handling for disconnects

**`XMLCleaner.clean_nested_quotes`** (lib/games.rb:98-123)
- Fixes quote escaping

**`XMLCleaner.fix_invalid_characters`** (lib/games.rb:125-145)
- Escapes/removes invalid chars

**`XMLCleaner.fix_xml_tags`** (lib/games.rb:147-170)
- Fixes structural issues

---

## Recommendations for Debug Window

### What to Display

Based on this protocol research, the debug window should show:

1. **Raw XML chunks** (exactly as received from Lich's TCP socket)
   - Post-cleaning, not pre-cleaning
   - What your parser actually receives

2. **Timestamp** (local receive time)
   - Format: `HH:MM:SS.mmm` (milliseconds useful for timing)

3. **Byte count** (per chunk)
   - Track data rate (bytes/sec)

4. **Parse status** (success/error from your XMLStreamParser)
   - Annotate chunks that fail to parse
   - Show parse errors inline

5. **Stream context** (current stream ID from parser state)
   - Shows which stream is active
   - Helps debug stream state bugs

6. **Session name** (if multiple sessions)
   - When supporting multi-session (future)

### Tag Highlighting Priority

Based on protocol analysis, prioritize highlighting for:

**1. Stream control tags** (most important for debugging):
```xml
<pushStream id="thoughts">
<popStream>
<clearStream id="thoughts">
```

**2. Metadata tags** (state updates):
```xml
<progressBar id="health" value="100" ...>
<indicator id="IconBLEEDING" visible="y">
<prompt>&gt;</prompt>
<compass><dir value="n"/></compass>
```

**3. Interactive tags** (clickable elements):
```xml
<a exist="12345" noun="gem">a blue gem</a>
<d cmd="look">a wooden table</d>
```

**4. Formatting tags** (visual styling):
```xml
<preset id="speech">You say, "Hello!"</preset>
<pushBold/>, <popBold/>
<output class="mono">Roundtime: 3 seconds</output>
```

### Statistics to Track

**Real-time metrics:**
- Chunks/second (current rate)
- Bytes/second (bandwidth)
- Parse errors (count + rate)
- Tag frequency (top 10 most common)

**Historical metrics:**
- Total chunks received
- Total bytes received
- Uptime (connection duration)
- Average chunk size

### Error Annotations

When parse errors occur, annotate with:
- **Error message** (from XMLStreamParser)
- **Byte offset** (where error occurred)
- **Context** (surrounding XML)
- **Recovery status** (did parser resync?)

**Example display:**
```
22:14:35.123  [ERROR] Failed to parse chunk (malformed tag)
              <pushStream id="thoughts>  ← Missing closing quote
                                       ^
              Parser state: IN_STREAM (thoughts)
              Recovery: Yes (resynced on next tag)
```

### Filtering Recommendations

**Common useful filters:**
- `pushStream|popStream` - Stream control only
- `progressBar` - Vitals updates only
- `preset id="(speech|whisper)"` - Communication only
- `exist=` - Interactive items only
- `error|warn` - Errors and warnings (if annotating)

### Export Format

When exporting logs, include:
- Timestamp (ISO 8601 format)
- Chunk size (bytes)
- Parse status (success/error)
- Raw XML (escaped)
- Session name

**JSON format:**
```json
{
  "session": "Teej",
  "start_time": "2025-10-12T22:14:30.000Z",
  "chunks": [
    {
      "timestamp": "2025-10-12T22:14:32.123Z",
      "bytes": 47,
      "status": "success",
      "data": "<pushStream id=\"thoughts\"/>\n"
    },
    {
      "timestamp": "2025-10-12T22:14:32.145Z",
      "bytes": 35,
      "status": "success",
      "data": "You think, \"This is a test.\"\n"
    }
  ]
}
```

---

## Testing with Lich

### Basic Testing Setup

**1. Start Lich in detachable mode:**
```bash
cd /Users/trevor/Projects/lich-5
lich --login Teej --detachable-client=8000 --without-frontend
```

**2. Enable deep debug (optional):**

Create `scripts/autostart.lic`:
```ruby
$deep_debug = true if CharSettings['enable_debug']
echo "Lich started in debug mode" if $deep_debug
```

**3. Connect Vaalin to localhost:8000**

**4. Compare output:**
- Terminal: Lich's `pp` output (if `$deep_debug = true`)
- Debug window: What Vaalin receives
- Should be **identical**

### Test Scenarios

**Test 1: Initialization burst**
- Disconnect/reconnect Vaalin
- Debug window should show large initial chunk
- Verify all current state sent

**Test 2: Normal gameplay**
- Walk around, fight, talk
- Verify XML appears in real-time
- Check for any dropped chunks

**Test 3: High-volume output**
- Use `;e 1000.times { _respond "<pushStream id='test'/>Test<popStream/>" }`
- Verify circular buffer works
- Check performance (should handle 1000 chunks easily)

**Test 4: Malformed XML**
- Intentionally send bad XML via Lich script
- Verify Lich cleans it before sending
- Check debug window shows cleaned version

**Test 5: Stream nesting**
- Test `<pushStream>` → `<pushStream>` → `<popStream>` → `<popStream>`
- Verify parser maintains correct stream state
- Debug window should show parse status

### Debugging Checklist

- [ ] Raw XML matches Lich's deep debug output
- [ ] Initialization burst appears correctly
- [ ] No chunks dropped during high volume
- [ ] Circular buffer prevents memory growth
- [ ] Syntax highlighting renders correctly
- [ ] Filtering works with complex regex
- [ ] Export includes all metadata
- [ ] Parse errors annotated clearly
- [ ] Performance: 60fps scrolling with 1000+ entries

---

## Protocol Gotchas

### 1. No Protocol Versioning

**Issue:** Lich doesn't send version handshake

**Implication:** Can't detect Lich version from protocol

**Workaround:** Assume latest Lich 5.x behavior

### 2. No Keep-Alive

**Issue:** TCP connection maintained, but no explicit ping/pong

**Implication:** Must detect disconnect via socket errors

**Workaround:** Monitor socket state, reconnect on error

### 3. No Compression

**Issue:** All XML is plain text (no gzip/deflate)

**Implication:** High bandwidth for verbose output

**Benefit:** Easy to debug (human-readable)

### 4. HTML Entities, Not UTF-8

**Issue:** `&lt;`, `&gt;`, `&amp;` used instead of raw characters

**Implication:** Must unescape entities for display

**Benefit:** No encoding issues (pure ASCII + entities)

### 5. No Explicit Chunk Boundaries

**Issue:** XML can span multiple reads

**Implication:** Parser must handle incomplete tags

**Solution:** XMLStreamParser maintains state across chunks

### 6. Cleaning is Opaque

**Issue:** Can't tell what Lich changed (pre-cleaning not visible)

**Implication:** Debug window shows post-cleaning only

**Workaround:** Test with `$deep_debug` to see what Lich receives

---

## Conclusion

### Key Takeaways

1. **Lich sends cleaned XML** - Not raw game output
2. **Initialization burst first** - Large chunk on connect
3. **Line-based chunks** - One write() per logical line
4. **UTF-8 + HTML entities** - Standard encoding
5. **No protocol versioning** - Assume current Lich behavior
6. **Built-in debug mode** - `$deep_debug = true` in scripts

### Debug Window Implications

**Must display:**
- Post-cleaning XML (what parser receives)
- Initialization burst (first large chunk)
- Per-chunk timestamps and sizes
- Parse status (success/error)
- Stream context (active stream ID)

**Must handle:**
- Line-based chunking (incomplete tags)
- High volume (1000+ chunks without lag)
- Circular buffer (prevent memory growth)
- Regex filtering (safe error handling)

**Nice to have:**
- Statistics (chunks/sec, bytes/sec, errors)
- Export to JSON (with metadata)
- Comparison with `$deep_debug` output
- Parse error annotations

### Estimated Complexity

**For debug window:**
- **Low complexity:** Display raw chunks with timestamps
- **Medium complexity:** Syntax highlighting, filtering
- **High complexity:** Parse status annotations, statistics

**Recommendation:** Start simple (raw display), add features incrementally based on usage.

---

**Report compiled by:** Claude (GemStone XML Expert)
**Source:** Lich 5 Ruby codebase (`/Users/trevor/Projects/lich-5/`)
**For project:** Vaalin - Native macOS GemStone IV Client
**Target platform:** macOS 26+ (Tahoe) with SwiftUI
