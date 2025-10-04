Awesome—this is a great starting point. Here’s a first-pass requirements draft based on your mockup + current UI, followed by focused questions so we can lock the spec.

Draft requirements (v0)
1) App shell & layout

Electron desktop app (Mac/Win/Linux) with single main window.

Three primary regions:

Top “Streams” bar (horizontal, fixed height, scrollable horizontally if overflow).

Center: Game Log (dominant area) with virtualized scrolling + inline ANSI/links.

Bottom area: Prompt display (readonly last server prompt) + Command Input (single-line with history & multiline expand), spanning between side columns.

Side columns (left & right): stackable Panels that are re-orderable via drag & drop; panels can be moved between columns.

Resizable gutters for: left column width, right column width, streams height, input height (if multiline).

2) Panels (left/right columns)

Interchangeable Panels (examples: Hands, Room, Vitals, Injuries, Spells, Mini-map, Inventory, Targets, Scripts Console).

Each panel has:

Title bar with drag handle, collapse/expand, context menu (close, pin, settings, duplicate).

Optional fixed or floating height; otherwise flexes within column.

Drop zones between panels and at top/bottom of each column.

Persistence of order, column, collapsed state, per-character/profile.

Panel registry (see Components below) for dynamic creation and lazy loading.

3) Streams (top bar)

A stream = named message channel (e.g., Room, Combat, Says, System, GM, Debug).

Stream tabs/chips with unread counts & color accents; click to filter/focus.

Optional multi-select filters (e.g., show Room+Combat in Game Log).

Right-click stream → mute, pop-out to its own panel, color, routing rules.

4) Game Log

Virtualized message list with smooth autoscroll when at bottom; non-scrolling if user scrolled up.

Inline formatting: ANSI colors, hyperlinks, hover cards for items/players, copy selection.

Structured messages (room headers, exits, item lists) with subtle grouping.

Search-in-log (⌘F) with highlights and next/prev.

Timestamps, toggleable.

Log to file (per session/day), with rotation.

5) Prompt & Input

Prompt display: last prompt from server (e.g., “>” or custom), supports inline status.

Command input:

History (↑/↓), fuzzy recall by prefix.

Aliases/macros, variable interpolation.

Multiline mode (Shift+Enter), indicator of lines/characters.

Send on Enter, configurable.

Optional parse preview area (e.g., what script/alias will expand to).

6) Drag & drop UX

Panel drag handle → ghost preview and drop indicators in both columns.

Keyboard reordering (accessibility).

Animate on drop; persist layout immediately.

7) Profiles & persistence

Profile = connection + layout + theme + routing rules + keybinds.

Auto-save layout changes; explicit “Reset to default.”

Local storage (Electron appData) with export/import of profile JSON.

8) Routing & filters

Routing rules map incoming lines/events → streams and/or panels.

Rules configurable (regex, tags, message type).

Optional priority & stop-propagation logic.

9) Theming & accessibility

Light/Dark + high-contrast.

Adjustable fonts (mono for log/input), size scaling, line spacing.

Full keyboard navigation; screen-reader labels on controls.

Color-blind-friendly stream accents.

10) Performance

Log virtualization (windowing), incremental parsing.

Offload heavy parsing to worker.

Efficient state updates (batched), frame budget friendly animations.

11) Components/tech choices

Web components with Lit:

<app-shell>, <streams-bar>, <game-log>, <panel-column>, <hud-panel>, <prompt-bar>, <command-input>.

Panel implementations like <panel-vitals>, <panel-minimap>, etc.

Shoelace for primitives: sl-tab, sl-dropdown, sl-menu, sl-dialog, sl-input, sl-button, sl-switch, sl-select, sl-tooltip.

State: minimal observable store (e.g., Lit signals/context or tiny Redux-like), IPC-safe serialization for Electron main/renderer.

IPC: Electron ipcRenderer for network layer and file logging; consider Node side for telnet/websocket & TLS.

12) Scripting & extensibility (phase 2)

Plugin API to register panels, add routing rules, define commands/aliases, intercept messages.

Sandboxed plugin execution (e.g., isolate via worker).

13) Networking

Telnet/MSSP/MCCP/GMCP support (as needed), heartbeat, reconnect, per-profile host/port/TLS.

Line normalization, keepalive, back-pressure handling.

14) Testing & telemetry

Component storybook (or pure web component demo page).

Playwright E2E for drag/drop & persistence.

Optional opt-in crash logs (no game content).

Questions to finalize scope
Layout & behavior

Panel sizing: should panels have user-set heights within a column (drag to resize), or do we keep fixed heights per panel and let the column scroll?

Streams bar: do you want stream tabs (one active at a time) or chips that act as filters (multi-select)? Your mockup reads as tabs—but you mentioned “streams in the top section.”

Pop-out panels: should any panel be detachable into its own window (Electron BrowserWindow) for multi-monitor setups?

Minimum sizes for columns/streams/input—any constraints you want enforced?

Routing & log

Do we split output (e.g., Combat stream shows in its own panel while the Game Log still shows everything), or does selecting a stream filter the main log by default?

Should routing rules be user-editable UI (regex + test harness), or for v1 do we ship a fixed set (Room, Says, Combat, System)?

Do you want timestamps always on, or toggled per stream/log?

Input & commands

Required features for v1: alias expansion, variables, command history, multiline—anything else (e.g., keybinds like F-keys to send hot commands, snippets)?

Should the prompt area support small status widgets (hp/stam/mana) or keep it text-only?

Panels catalogue (v1)

Which initial panels are must-have for MVP? From the screenshot I infer:

Hands, Room (compass), Vitals, Injuries, Active Spells.

Any others (Inventory, Targets, Effects, Mini-map, Party, Scripts Console)?

Any panel need context actions (e.g., click a spell to re-cast; click a room exit to move)?

Persistence & profiles

Do you want multiple profiles with switcher, or one active profile with “Save as…”?

Where should we store profiles: appData JSON is fine, but do you want Cloud sync later?

Theming & visuals

Provide a base font preference? (Monaco, JetBrains Mono, Fira Code, system mono)

Do you want ansi → theme color mapping configurable by the user?

Electron & packaging

Target OSes for MVP (Mac first? Apple Silicon?). Any auto-update requirement (Squirrel/AutoUpdater)?

Do you want a single instance lock or allow multiple instances?

Extensibility

Priority for a plugin API in v1 vs. v2? If v1, what’s the smallest viable surface (register panel + command + stream rule)?

Data & privacy

Any requirements around PII/redaction in logs or when exporting?

Proposed component map (Lit + Shoelace)

<app-shell>: owns regions, layout persistence.

<streams-bar>: chips/tabs with unread badges; emits stream-select/stream-toggle.

<panel-column side="left|right">: manages panel stack + drop zones.

<hud-panel> (base): title bar, actions, drag handle; content slot.

<game-log>: virtualized list, ANSI renderer, search overlay.

<prompt-bar>: renders last prompt/status.

<command-input>: history, alias expansion, multiline; emits send.

Panel implementations: <panel-vitals>, <panel-room>, <panel-spells>, etc.

Utilities: ansi-to-dom, router, store, persist, ipc-client.

If you answer the questions above, I’ll turn this into a tight MVP spec + tickets (structure, component API, data models, and a week-by-week build plan).

You said:
1: panels within columns have fixed height for now (thats how it works today)
2: i like your chips idea with multi select, thats a great idea
3: that can be a future improvement
4: some reasonable number based roughly on the size of the panels today but smaller to clear out any whitespace, thats probably as small as i would go on width on columns
5: we can have a setting that lets you choose whether to send to both or just streams when streams are open, for example -- something like that
6: what are routing rules?
7: toggle per stream/log
8: yes, keybinds and snippets, as well as typical readline cmds in the input bar
9: i like the idea of exploring it
10: for mvp just the panels i have now
11: not for now
12: for now, just one
13: json is fine
14: jetbrains mono
15: yes
16: mac, mps
17: multiple instances, but we can ignore for now
18: not for now
19: no
ChatGPT said:

Perfect—thanks! I folded your answers into a crisp MVP spec and explained “routing rules.” If this looks right, I’ll turn it into scoped tickets next.

MUD Client HUD — MVP Requirements (Electron + Web Components + Lit + Shoelace)
1) App shell & layout

Electron desktop app (macOS first; Apple Silicon + MPS-enabled build).

Regions:

Streams bar (top): multi-select “chips” that act as filters; shows unread counts.

Center: Game Log (dominant).

Bottom: Prompt (readonly) and Command Input.

Left/Right columns: vertical stacks of fixed-height Panels (MVP).

Resizable: left/right column widths, streams bar height.

Column min widths: set “a bit smaller than today’s panels” to remove whitespace; enforce min so content doesn’t break.

2) Columns & panels

Each column is a stack of fixed-height Panels (no per-panel resizing in MVP).

Panels support: drag between columns, reorder within a column, collapse/expand, close.

MVP panel set (parity with today):

Hands

Room/Compass

Vitals

Injuries

Active Spells

No pop-out windows yet (future).

Persist: column (L/R), order index, collapsed state.

3) Streams (top chips)

Multi-select chips (e.g., Room, Combat, Says, System).

Unread badge on each chip; unread clears when scrolled to bottom or chip toggled off.

Filtering behavior:

Default: when any chips are ON, Game Log shows only those streams.

Setting: “Also mirror to main log when chips are on” (ON/OFF) → matches your “send to both or just streams” idea.

Context menu per chip: mute, color, “route only to chip (hide from main)”, clear unread.

4) Game Log

Virtualized list with smooth autoscroll (pauses when user scrolls up).

ANSI colors, inline links, copy selection.

Grouping for room headers; optional timestamps (toggle per stream/log).

Find-in-log (⌘F) with next/prev.

Log to file per day/session (JSONL or text), rotation.

5) Prompt & Command Input

Prompt: last server prompt text; future: small status widgets explore-later.

Input:

History (↑/↓) w/ prefix search.

Readline basics: Ctrl-A/E, Ctrl-U/K/W, Meta-B/F, etc.

Multiline with Shift+Enter (send on Enter).

Aliases / snippets (e.g., #hunt → sends a sequence).

Keybinds: map hotkeys to commands/snippets (F-keys or custom).

Optional preview of alias/snippet expansion.

6) “Routing rules” (what they are + MVP scope)

Routing rules decide where an incoming line/event goes (which stream(s) and/or panels).
Think: “if a line matches X, tag it as ‘Combat’; if it’s a room title, tag ‘Room’; if it’s a whisper, tag ‘Says’”.

MVP approach: ship a built-in set of heuristics (no editor UI yet).

Examples:

Lines starting with [room name] → tag Room.

Damage/attack verbs → tag Combat.

says, / whispers, → tag Says.

System notices (connect/reconnect, errors) → tag System.

Each message can carry multiple tags; the streams chips filter by these tags.

Future (post-MVP): user-editable rules (regex + test harness, priorities, stop-propagation).

7) Persistence & profile

Single profile for MVP.

Stored in appData as JSON:

layout (column sizes; panel order/column; collapsed flags),

streams config (colors, muted),

input settings (send on Enter, timestamps per stream/log),

aliases/snippets, keybinds.

Export/import JSON later (simple file pickers).

8) Theming & accessibility

Light/Dark themes; JetBrains Mono for log/input.

User-configurable ANSI → theme color mapping.

Font size and line-height sliders.

Keyboard navigable drag/drop and search.

9) Performance & plumbing

Log windowing; parsing off main thread (Web Worker).

Electron IPC for network I/O and file logging.

Target macOS; auto-update optional later.

Component map (Lit + Shoelace)

<app-shell>: owns layout, sizes, persistence.

<streams-bar>: chips with unread; emits streams-changed.

<panel-column side="left|right"> + <hud-panel> (base shell with drag handle, collapse).

<game-log>: virtualized list, ANSI renderer, search overlay.

<prompt-bar> and <command-input>.

Panels: <panel-hands>, <panel-room>, <panel-vitals>, <panel-injuries>, <panel-spells>.

Shoelace usage: sl-button, sl-input, sl-badge (unread), sl-switch, sl-dropdown/sl-menu, sl-dialog, sl-tooltip.

State & data (sketch)
type Msg = {
  id: string;
  ts: number;
  text: string;           // raw
  html?: string;          // parsed/ANSI-rendered
  tags: string[];         // e.g., ["room","system"]
};

type Layout = {
  left: string[];         // panel ids in order
  right: string[];
  collapsed: Record<string, boolean>;
  colWidth: { left: number; right: number };
  streamsHeight: number;
};

type Settings = {
  timestamps: { gameLog: boolean; perStream?: Record<string, boolean> };
  mirrorFilteredToMain: boolean; // your “both or just streams” toggle
  input: { sendOnEnter: boolean; multilineOnShiftEnter: boolean };
  keybinds: Record<string, string>; // key -> command/snippet
  snippets: Record<string, string>; // name -> expansion
  aliases: Record<string, string>;  // alias -> expansion
  ansiTheme: Record<string, string>; // color name -> hex
};

type Profile = { layout: Layout; settings: Settings; streams: StreamConfig[]; };

Keyboard defaults (proposal)

Log: PgUp/PgDn, Home/End, g/G (top/bottom), ⌘F search.

Input: standard readline (Ctrl-A/E/U/K/W, Alt-B/F, Alt-Backspace).

Streams: 1..9 toggle chips 1..9, 0 = clear selection.

Panels: when a panel header is focused, ⌘↑/⌘↓ reorder within column.

Acceptance criteria (MVP)

Reorder panels by drag; move across columns; state persists on restart.

Streams chips filter the Game Log; unread counters behave correctly.

Setting mirrorFilteredToMain switches between “only filtered” vs “also show in main.”

Timestamps togglable independently for Game Log and each stream.

Fixed panel heights; columns scroll when overflow.

Input supports history, readline basics, snippets, aliases, keybinds; Shift+Enter makes multiline.

Logs write to disk; app remains smooth at large log sizes (virtualized).

Open items to confirm (quick yes/no is fine)

Timestamp format preference: HH:mm:ss 24-hour ok?

Log file format: plain text, or JSONL (safer round-tripping)? (I can do both.)

Keybind storage: human-readable strings like "Cmd+Shift+1" acceptable?

Default stream set: room, combat, says, system—add/remove any?

If this all matches your vision, I’ll break it into a short milestone plan with tasks (week 1: shell + columns + panels; week 2: streams/filtering; week 3: log/search; week 4: input + aliases/snippets + persistence).

You said:
Read online about the gemstone 4 xml spec and wrayth xml spec and how lich 5 outputs the data stream, that’s what we use now to know what to do with what and what goes where. Read more to learn more and then ask me more questions 
ChatGPT said:
Thought for 3m 6s

Awesome—did a quick dive on the Wrayth / GemStone IV XML and how Lich sits in the middle. Here’s the distilled picture, then I’ll fire a few focused questions so we can lock the MVP.

What I learned (TL;DR)

Wrayth protocol = the XML stream GSIV sends to a front end. Core tags include:

<pushStream id="...">…</popStream> to route text to a named window; <clearStream id="..."/> to wipe one. Example ids in docs include things like logons. 
GemStone IV Wiki

<prompt time="...">R&gt;</prompt> marks the game prompt. 
GemStone IV Wiki

<left>…</left> / <right>…</right> update the hand panels. 
GemStone IV Wiki

<spell exist="spell">…</spell> updates the prepared spell readout; <inv id="stow">…</inv> appends to a container window. 
GemStone IV Wiki

<a …>text</a> / <d cmd="…">text</d> render clickable links / actions. 
GemStone IV Wiki

There are also dynamic window bits the wiki talk page mentions—<openDialog>, <dialogData>, and widgets like <progressBar>, <label>, <image>, <cmdButton>, plus injuries UI bits (<radio>, <skin>). These power “injuries”, “map”, “encumbrance”, etc. 
GemStone IV Wiki

Lich 5 acts as a proxy between FE and server. It consumes the XML stream, fixes occasional malformed bits, exposes downstream events to scripts, and forwards XML + stripped text on to the FE. You can see code paths like Script.new_downstream_xml(...), strip_xml(...) and notes about quote-fixing for bad XML in community posts. 
GitHub
+1

The wiki explicitly frames the protocol as used by Wrayth and also other FEs (Nexus/EclipseFE), which aligns with the idea that we can implement our own FE (Electron + Web Components) by parsing the same tag set. 
GemStone IV Wiki

Clarifying questions (so we wire this up exactly how you play)

Which streams should appear as “chips” in the top Streams bar by default? (e.g., logons, thoughts, death, exp, familiar, spellfront, whispers, group…?) If you have your current IDs, drop me that list and I’ll map them 1:1.

For the Active Spells panel in your left column: do you want us to drive it from the spellfront stream (i.e., render whatever the server puts there via <pushStream id="spellfront">…) or synthesize it from other tags like <spell>? (The XML supports both patterns.) 
GemStone IV Wiki

For Hands / Vitals / Injuries:

Hands: we’ll listen for <left> / <right>. ✅ 
GemStone IV Wiki

Vitals / Injuries: do you want MVP to parse dynamic window widgets (e.g., <openDialog> → <dialogData> with <progressBar>, <radio>, <skin>) or should we keep it simple and pull from text/streams for now? The dynamic route is more accurate but adds a parser pass up front. 
GemStone IV Wiki

Routing rules (my term): can I lock these defaults?

Center = story window (anything not inside a pushStream, plus <prompt> handling).

Top chips = any stream id you enable; clicking a chip shows/hides that stream’s buffer.

Left/Right column panels:

Left: Hands, Vitals, Injuries, Active Spells (fixed heights).

Right: your current “ROOM”/mini-map style panel + any other single stream?
You can override via a JSON map like:

{
  "routes": {
    "story": "center",
    "spellfront": "left.activeSpells",
    "logons": "top:chips",
    "thoughts": "top:chips"
  }
}


Sound good?

Clickable links & menus: should we implement <a> hover / context menu and <d cmd> click-to-send on day one? (It’s very doable in the story + stream panes.) 
GemStone IV Wiki

Prompt + input echo: when we see <prompt>, do you want us to:

finalize the current line, render the prompt, and keep your input after it (like your current UI), and

optionally echo your sent command into center, active stream, or both based on your “send to both or just streams” toggle? (Matches your #5 answer.) 
GemStone IV Wiki

Unknown streams: if we see a new id in <pushStream id="…">, should we:

auto-add a chip (off by default), or

keep it hidden unless you whitelist it in settings?

Persistence shape: you said JSON is fine. Any constraints/preferences for where/how we save it (per-character file vs global), or should I default to:

~/.sceotan/{account}/{character}/settings.json with per-char overrides?

Styling: we’ll honor <output class="mono"> (switch to JetBrains Mono) vs normal body font. OK to apply that class at the span level inside lines? 
GemStone IV Wiki

Error cases: if the XML is malformed (it happens), Lich typically “resets” and continues. Are you okay with us:

logging the bad chunk (dev console + optional file),

showing a tiny ⚠︎ in the status bar,

then resyncing on the next <prompt>?

If you can answer those, I’ll turn this into a concrete MVP spec (parsers, events, components, and the JSON config schema) tailored to your exact streams/panels.

You said:
1: look at the other clients and see which streams they typically put in the streams panel 
2: I want the most control and ability to update quickly 
3: dynamic 
4: looks good
5: yes 
6: echo 
7: log and ignore 
8: that’s good 
9: yes
10: yes

Any more?
ChatGPT said:
Thought for 2m 45s

Love it. Here’s what I found other clients commonly surface as separate “windows/streams”, plus a few tight confirm/clarify questions to keep us moving.

Common streams other FEs surface

These come straight from the Wrayth/StormFront XML docs and FE pages (so we can pre-register chips for them).

Thoughts (ESP) — explicitly called out as a dedicated “Thoughts window.” 
Gemstone

Speech / Whispers — StormFront routes these to a Speech window; whispers were updated to land there too. 
GemStone IV TownCrier

Logons — example stream id shown in the protocol docs (<pushStream id="logons">). 
GemStone IV Wiki

Experience — the Experience window exists and its id is expr. 
GemStone IV Wiki

Familiar — “Familiar window” is explicitly supported by XML-aware front ends. 
Gemstone

Active Spells — often a separate window (spellfront is the id used in examples), though we’ll render this as your left-column panel by default. 
GemStone IV Wiki

Injuries / Encumbrance / Map / Combat — these are dynamic windows driven by <openDialog>/<dialogData> with widgets like <progressBar>, <image>, <cmdButton>, etc. (We’ll parse and paint them into your panels.) 
GemStone IV Wiki

Notes
• The “streams bar” should therefore ship with pre-registered chips for: Thoughts, Speech, Whispers, Logons, Experience, Familiar. Active Spells is routed to a panel, not a chip, by default.
• Unknown/new stream ids: we’ll log + ignore (your preference), and let you opt-in later.

A few focused questions (based on your answers)

Default chips: OK to ship with these ON by default? → Thoughts, Speech, Whispers, Logons. Leave Experience and Familiar OFF but available?

Chip ordering & colors: Any preferred order? If not, I’ll do: Thoughts · Speech · Whispers · Logons · (Experience · Familiar hidden by default).

Mirror setting default: When any chips are active, should Game Log also mirror those messages by default (ON) or show only filtered (OFF)?

Timestamps default: You said toggle per stream/log; should Game Log = ON and chips = OFF be our defaults?

Echo format: When we echo commands, do you want a simple > command in the Game Log, or a styled echo (dim + monospace, no timestamp)?

Dynamic windows → panels:

Map, Injuries, Encumbrance, Combat: confirm we’ll render these in panels (fixed heights) and ignore any “location” hint from <openDialog> (you control placement). 
GemStone IV Wiki

Any of those you want hidden by default?

Clickable actions: We’ll implement <a> menus and <d cmd> click-to-send. OK to also add right-click → “copy command text”? 
GemStone IV Wiki

Lich connection mode: Do you want us to connect via Lich’s detachable client socket (like Profanity does) or attach as the “front end” that Lich proxies to? (Both are doable; detachable is nice for reconnects.) 
GemStone IV Wiki
+1

Column min widths: I’ll set min 240px for L/R columns and min 56px for the Streams bar; sound good?

ANSI theme defaults: We’ll ship a sensible palette and let you remap. Any preference (e.g., One Dark-ish) or go neutral?

If you give quick thumbs on those, I’ll lock the stream registry + dynamic-window renderer plan and turn this into concrete tasks (parsers, events, component APIs, and the default JSON config).

You said:
1: yes
2: yes
3: mirror by default
4: timestamp off by default
5: styled echo
6: confirmed and not hidden by default 
7: yes
8: yes detachable 
9: ok
10: catpuccin mocha 
ChatGPT said:
Thought for 49s

Amazing—locking your choices in. Here’s the concise MVP spec update plus a tiny set of final, targeted questions.

✅ Locked decisions (from you)

Streams bar = multi-select chips; default chips ON: Thoughts, Speech, Whispers, Logons. Experience & Familiar available but OFF.

Mirror filtered messages to main Game Log by default (toggleable).

Timestamps OFF by default (per log/stream toggles).

Panels: fixed height; same set as today (Hands, Room/Compass, Vitals, Injuries, Active Spells). Render dynamic windows (map/injuries/encumbrance/combat) into those panels; not hidden by default.

Clickable <a> + <d cmd> links; right-click → copy command text.

Echo sent commands to log with styled echo.

Unknown streams: log & ignore.

Connection: Lich detachable client mode.

Min widths: columns ≈ 240px; streams bar ≈ 56px.

Theme: Catppuccin Mocha; base font JetBrains Mono.

Profile: single profile; JSON in ~/.sceotan/{account}/{character}/settings.json.

Implementation outline (MVP)
Data flow

Lich (detachable) → Electron main (socket) → XML chunker (SAX) → message bus →

router (by <pushStream id>, <prompt>, <left>/<right>, dynamic windows) →

stores for streams, panels, log.

Parsers

Core tags: pushStream/popStream/clearStream, prompt, left/right, spell, inv, a, d.

Dynamic windows: openDialog / dialogData widgets we’ll support in v1:

progressBar, label, image, cmdButton, radio, skin (enough for injuries/encumbrance).

Unknown tags → capture raw + warn (status icon) + continue.

Components (Lit + Shoelace)

<app-shell>, <streams-bar>, <panel-column>, <hud-panel>, <game-log>, <prompt-bar>, <command-input>.

Panels: <panel-hands>, <panel-room>, <panel-vitals>, <panel-injuries>, <panel-spells>.

Shoelace: sl-badge (unread), sl-dropdown/menu, sl-switch, sl-input, sl-dialog, sl-tooltip, sl-button.

Streams registry (config-driven)
{
  "streams": [
    {"id":"thoughts","label":"Thoughts","defaultOn":true,"color":"var(--ctp-mocha-sapphire)","aliases":[]},
    {"id":"speech","label":"Speech","defaultOn":true,"color":"var(--ctp-mocha-green)","aliases":["says"]},
    {"id":"whispers","label":"Whispers","defaultOn":true,"color":"var(--ctp-mocha-mauve)","aliases":[]},
    {"id":"logons","label":"Logons","defaultOn":true,"color":"var(--ctp-mocha-yellow)","aliases":[]},
    {"id":"expr","label":"Experience","defaultOn":false,"color":"var(--ctp-mocha-peach)","aliases":["experience"]},
    {"id":"familiar","label":"Familiar","defaultOn":false,"color":"var(--ctp-mocha-sky)","aliases":[]}
  ]
}


(Unknown ids are logged and ignored; you can add them later via settings.)

Routing & mirroring

When any chips are ON → show those streams in the main Game Log (mirror = true by default). Toggle flips to “filter-only”.

Per-stream timestamps toggle; Game Log timestamp toggle separate.

Echo & prompt

On send: echo as a dim, monospace line (no timestamp), prefixed with › (configurable).

<prompt> updates <prompt-bar> and acts as a parse resync point.

Persistence (single profile)
{
  "layout": { "left":["hands","room","vitals"], "right":["injuries","spells"], "colWidth":{"left":280,"right":280}, "streamsHeight":112, "collapsed":{} },
  "settings": {
    "mirrorFilteredToMain": true,
    "timestamps": {"gameLog": false, "streams": {"thoughts": false, "speech": false}},
    "input": {"sendOnEnter": true, "multilineOnShiftEnter": true},
    "ansiTheme": "catppuccin-mocha",
    "keybinds": {"Cmd+K":"clear-log"},
    "aliases": {"#hunt":"stance offensive;attack"},
    "snippets": {"heal":"cast 1101 @${target}"}
  },
  "streams": { /* registry override if needed */ }
}

Styling & theme

Catppuccin Mocha tokens as CSS vars (expose in :root), map ANSI → theme vars; JetBrains Mono for log/input.

Acceptance (MVP)

Drag/reorder/move fixed-height panels across columns; state persists.

Chips toggle streams; unread counts; mirror/filter toggle works.

Dynamic windows render into panels (injuries/encumbrance/combat/map).

Styled command echo; clickable <a> and <d cmd>; right-click copy.

Detachable Lich connection works; reconnect without losing layout.

Timestamps togglable per stream/log; defaults OFF.

Final quick questions

Lich detachable details: host/port and any auth? (Default 127.0.0.1:port—what port are you using now?)

Log files: plain text, JSONL, or both? (And any retention—e.g., keep last 30 days?)

Panel heights: give me your current px heights for each (or I’ll default: Hands 140, Room 160, Vitals 160, Injuries 180, Spells 180).

Echo prefix: is › good, or prefer >?

Alias/snippet syntax: keep your current conventions? (e.g., aliases start with #, variables ${name}, snippet multiline delimiter?)

Keybinds: any must-have defaults (e.g., F1..F4 for common scripts, Cmd+L focus input, Cmd+Shift+F open streams filter)?

Dynamic windows beyond the four (map/injuries/encumbrance/combat): if the server opens an unknown dynamic window, should we render it in a generic “Dynamic” panel or log & ignore like other unknowns?

Give me those and I’ll freeze the spec + config schema and start carving it into build tickets.

You said:
Ok big out of left field change. We are going to lean into native macOS and use swift ui with maximally up to date SDK usage and design language for macOS 26. Read more online and ask me follow up questions 
ChatGPT said:
Thought for 37s

Love the pivot. I did a fast sweep of WWDC25 + current docs to align with native macOS 26 (Tahoe) and the new “Liquid Glass” design language, plus SwiftUI’s latest windowing, materials, App Intents, and rich text updates. Highlights below, then laser-focused questions so we can lock our macOS plan.

What “maximally up-to-date” means for us

Design language: adopt “Liquid Glass” look (transparent, glassy surfaces + dynamic materials) where it helps readability—e.g., streams bar & panel chrome—using updated materials guidance and APIs. 
Apple Developer
+1

SwiftUI-first app structure: modern Scenes & Windows (multi-window via WindowGroup/Window, toolbar and state-restoration customization on macOS 15+), with native window behaviors and zoom/drag regions. 
Apple Developer
+1

Rich text & web content: leverage the WWDC25 SwiftUI enhancements (rich text editing, integrated web content) for the game log and link handling; fall back to TextKit 2 via NSViewRepresentable for extreme performance cases. 
Apple Developer

Pointer & keyboard: use new pointer APIs and modifier-key change hooks (for command UI affordances and pro-level shortcuts). 
Apple Developer

System integration via App Intents: expose verbs like “Connect to <profile>”, “Send command…”, “Toggle streams filter” to Spotlight/Siri, and adopt new interactive App Intent snippets for quick actions. 
Apple Developer
+1

HIG compliance: follow updated macOS HIG for window structure, color, and materials so it feels native—not a ported web app. 
Apple Developer
+2
Apple Developer
+2

SwiftUI-native plan for your MUD client

Layout: HSplitView-like three-column layout (left panels · center log · right panels), resizable gutters, top Streams bar using native toolbar/secondary bar styling with material background; bottom Prompt + Input as a persistent accessory bar.

Streams chips: multi-select “filter chips” as Toggle buttons with badges; unread counts via Badge. (Mirror to main log = default.)

Panels: fixed-height stacks implemented as SwiftUI views; dynamic windows (injuries/encumbrance/map/combat) rendered from XML into native controls (progress indicators, images, radio groups) using SwiftUI.

Log: virtualized SwiftUI list with attributed text & link actions; clickable <d cmd> behaves like native action links; styled echo line; timestamps off by default (per-log/stream toggles).

Lich detachable client: Network.framework (NWConnection) with streaming XML parse (XMLParser) → event bus (actors) → UI stores.

Persistence: keep your JSON layout/settings on disk; optionally mirror to SwiftData models for live binding in UI.

Quick follow-ups to lock targets

Minimum OS: okay to require macOS 26 (Tahoe) for release? (Gives us all the window/material/App Intents goodies without shims.) 
The Verge

Liquid Glass intensity: should we apply the glass material to just chrome (streams bar, panel headers, toolbar) or also to the log background (with careful contrast)? 
Apple Developer

Distribution: Mac App Store, notarized DMG, or both? (Impacts sandboxing/entitlements, file logging, and Lich socket access.)

Menu Bar utility: want a Menu Bar Extra for quick connect, status, and recent servers? (Super handy for a client.)

Spotlight/Intents scope: which verbs first—Connect/Disconnect, Send command, Toggle stream, Switch profile? (We’ll model these as App Intents so Spotlight can run them.) 
Apple Developer

Game log engine: prefer pure SwiftUI rich text first (fastest to build), with a fallback to TextKit 2 wrapper only if we hit perf limits on huge logs? 
Apple Developer

Windowing: do you want secondary windows for things like a full “Map” or “Scripts Console,” or keep everything in the main window for MVP? (SwiftUI Window scenes make this clean.) 
SerialCoder

Theming: keep Catppuccin Mocha as an optional theme alongside system appearance & accent colors? (Native-first, theme optional.)

Accessibility goals: any must-haves beyond VoiceOver labels and full keyboard navigation? (We can align with 2025 HIG accessibility guidance.) 
Apple Developer

Telemetry/crash reports: okay to integrate Apple’s unified logging + crash reports (no content), opt-in?

If you give me thumbs on these, I’ll turn this into a SwiftUI-native MVP spec (scenes, view hierarchy, models, intents, materials) that matches macOS 26’s look and APIs.

You said:
1: yes 
2: just chrome 
3: not sure yet 
4: future idea
5: future idea 
6: no fall back we will be smart about scroll back buffer 
7: for now one window 
8: native but theme able and catpuccin mocha is the default 
9: future idea
10: no
ChatGPT said:
Thought for 44s

Love the pivot—here’s a tight SwiftUI-native MVP plan mapped to the Wrayth XML protocol and Lich 5 detachable client, then just a few laser follow-ups.

What I read (essentials)

Wrayth XML tags that drive FEs: <pushStream id>…</popStream>, <clearStream id>, <prompt time>…</prompt>, <left> / <right> (hands), <spell>, <inv id>, clickable <a> and <d cmd>; examples include id="logons" and id="spellfront". 
GemStone IV Wiki

Protocol purpose: XML between game and FE; used by Wrayth and other clients (Nexus/EclipseFE). 
GemStone IV Wiki

Lich 5 detachable client: run Lich with --without-frontend --detachable-client=<port> and connect your FE to 127.0.0.1:<port> (commonly 8000). 
GSPlayers
+1

macOS 26 / SwiftUI: Apple’s new Liquid Glass design language + refreshed SwiftUI surfaces; adopt via latest SDKs/Xcode. 
Apple Developer
+2
Swift with Majid
+2

SwiftUI MVP (macOS 26, “chrome-only glass”)

App & windowing: single main window (@main App + WindowGroup), left/center/right columns with resizable split views; Streams Bar at top (material background), Prompt+Input accessory at bottom.

Streams chips (multi-select): Toggle-style chips with Badge unread counts. Default ON: Thoughts, Speech, Whispers, Logons; Experience/Familiar available but OFF. Mirror to Game Log ON by default (toggleable).

Panels (fixed height): Hands, Room/Compass, Vitals, Injuries, Active Spells.

Dynamic windows (<openDialog>/<dialogData> patterns like injuries/encumbrance/map/combat) get rendered as native SwiftUI controls inside these panels; we ignore any server “placement hints”—you control layout.

Game Log: high-performance SwiftUI list (LazyVStack in a ScrollView with smart scrollback cap instead of TextKit fallback, per your call). Styled command echo lines; timestamps OFF by default (per-log/stream toggles). Clickable <a> menus + <d cmd> send actions; right-click “Copy command.” 
GemStone IV Wiki

Networking: NWConnection → streaming XML SAX parse (XMLParser) → actor-based event bus → SwiftData/Observable state.

Persistence: native look & feel, but config stays JSON (~/.sceotan/{account}/{character}/settings.json).

Theming: Native first with system accent; Catppuccin Mocha as default theme (user can switch).

Keyboard: macOS-standard readline shortcuts; configurable keybinds/snippets; styled prompt and echo behavior.

Unknown streams: log & ignore.

No telemetry/crash uploads.

XML → UI routing (concrete)

Story/Main Log: plain text + any content outside a pushStream. <prompt> updates the prompt bar and acts as a resync boundary. 
GemStone IV Wiki

Streams Bar: buffer by id from <pushStream id="…">…</popStream>; support <clearStream id>. 
GemStone IV Wiki

Panels:

Hands from <left> / <right>.

Active Spells from <spell> and/or id="spellfront" stream (we’ll support both). 
GemStone IV Wiki

Containers (e.g., stow/inventory snippets) via <inv id> / <clearContainer id>. 
GemStone IV Wiki

Links & actions: <a> (menus/objects) + <d cmd> (click-to-send) integrated with the input pipeline. 
GemStone IV Wiki

Lich: connect to the detachable port; multiple characters = multiple ports. 
GSPlayers
+1

A few final decisions (quick picks)

Detachable port: use 8000 as the default? (We’ll allow override per profile.) 
GSPlayers

Scrollback cap: start with 10,000 lines per buffer (streams + main), prune oldest—sound right?

Fixed panel heights (px): can I set initial defaults like Hands 140, Room 160, Vitals 160, Injuries 180, Spells 180 (you can tweak later)?

Distribution: while you decide, I’ll keep both paths viable (MAS-ready sandboxing off by build flag, and a notarized DMG target). Want that?

Default keybinds: okay to ship these?

⌘L focus input • ⌘K clear log • ⌘F find-in-log • ⌘1…⌘6 toggle chips 1…6 • ⇧↩ multiline.

If you’re good with those, I’ll lock the SwiftUI spec + config schema and outline build tickets next.

You said:
All sounds good. Let’s write it all up in detail now 
ChatGPT said:
Thought for 30s

Got it. Here’s a complete, “ship-ready” SwiftUI (macOS 26) MUD Client spec tailored to Wrayth XML + Lich 5 (detachable). I’ve locked in everything you decided and filled in the details so we can cut tickets straight from this.

Product spec — macOS 26 MUD Client (SwiftUI)
0) Goal & scope (MVP)

A native, modern macOS client for GemStone IV that:

Connects to Lich 5 in detachable client mode.

Consumes Wrayth XML to drive UI (streams, prompt, hands, spells, dynamic windows).

Uses a three-pane layout with a top Streams bar, center Game Log, left/right fixed-height panels, and a bottom Prompt + Input.

Defaults to native look with Catppuccin Mocha as the default theme, and clean macOS interactions.

Non-goals (MVP): multi-window, menu bar extra, App Intents, cloud sync, plugin API, telemetry upload.

References (key facts): Wrayth is the XML protocol used by official and unofficial FEs; dynamic panes use tags like <openDialog> / <dialogData>; Lich can run with --without-frontend --detachable-client=<port>. 
GemStone IV Wiki
+2
GemStone IV Wiki
+2

1) Platform & distribution

Target OS: macOS 26+ only.

Architecture: Apple Silicon first, Intel not required.

Builds:

Notarized DMG (default dev/test distribution).

App Store–ready target behind a build flag (sandbox adjustments), decision later.

2) Architecture
2.1 Process & data flow
Lich (detachable TCP) → NWConnection (Actor) → XMLParser (SAX)
   → EventBus (actors) → Stores (Observable/SwiftData-lite)
       → SwiftUI Views (Streams/Log/Panels/Prompt/Input)


Network: NWConnection reads a continuous UTF-8 XML stream from Lich on 127.0.0.1:<port>. Default port 8000, configurable per profile. Lich typical launch:
ruby lich.rb[w] --login <char> --without-frontend --detachable-client=8000 
GemStone IV Wiki

Parsing: XMLParser in non-blocking chunks (SAX). We preserve element order and accumulate text nodes within current context (story vs. stream vs. dialog).

Event bus: actor-based fan-out (no main-thread work until we hit the stores).

Stores: thin observable models for:

StreamStore (buffers, unread, filters)

LogStore (main/story buffer)

PanelStore (hands, vitals, injuries, spells, room/compass)

SettingsStore (layout, keybinds, theme, toggles)

Persistence: JSON on disk (per account/character), see §8.

2.2 XML → feature map
XML tag / concept	Behavior / target
<pushStream id="…">…</popStream>	Append to named stream buffer; show via chip when selected. Supports <clearStream id="…"/>. 
GemStone IV Wiki

Content outside a pushStream	Goes to Game Log (“story”). 
GemStone IV Wiki

<prompt …>…</prompt>	Updates Prompt bar, marks parse resync; triggers autoscroll decisions. 
GemStone IV Wiki

<left>…</left> / <right>…</right>	Hands panel. 
GemStone IV Wiki

<spell …>…</spell> and/or stream spellfront	Active Spells panel (we support both). 
GemStone IV Wiki

<inv id="…">…</inv> / <clearContainer id="…">	Parsed and stored; not surfaced as MVP panel.
<openDialog> / <dialogData> (widgets)	Drives dynamic panels (Injuries, Encumbrance, Map, Combat). We render supported widgets and ignore server placement hints. 
GemStone IV Wiki

<a …> and <d cmd="…">	Clickable links and click-to-send actions in log and streams. 
GemStone IV Wiki
3) UI & interaction
3.1 Window layout (single main window)

Top: Streams bar (material “chrome only”).

Middle: Three columns via resizable split:

Left column: stack of fixed-height panels.

Center: Game Log (dominant).

Right column: stack of fixed-height panels.

Bottom: Prompt (read-only) + Command Input bar.

Minimums: Left/Right columns min width 240 px; Streams bar min height 56 px.

3.2 Streams bar (chips)

Multi-select chips with unread badges; order: Thoughts, Speech, Whispers, Logons (ON by default). Experience, Familiar available but OFF by default.

Mirror mode: when any chip is ON, its messages also appear in the Game Log (default = ON; user can toggle to “filter-only”).

Per-chip context menu: Mute, Clear Unread, Color, Timestamp toggle.

3.3 Panels (fixed height; MVP set)

Left column: Hands, Room/Compass, Vitals

Right column: Injuries, Active Spells

Actions per panel: Collapse/expand; drag to reorder/move across columns; close (removes from layout but not from registry).

Initial heights (px): Hands 140 · Room 160 · Vitals 160 · Injuries 180 · Spells 180 (editable in Settings).

Dynamic windows (from <openDialog>/<dialogData>):

Supported widgets: progressBar, label, image, cmdButton, radio, skin (enough for Injuries/Encumbrance/Combat/Map).

We ignore server “placement” and map content to our panels.

Unknown dialog types: render best-effort (labels/buttons/progress) inside the relevant panel; if completely unknown, log a warning and continue.

3.4 Game Log

SwiftUI-native rendering (no TextKit fallback) with:

Virtualized rendering via ScrollView + LazyVStack.

Styled echo lines (dim, monospace, prefix ›; configurable).

Timestamps OFF by default; toggleable for Game Log and per stream.

Find in Log (⌘F), next/prev, highlight all.

Autoscroll only when user is at bottom; preserve position otherwise.

Scrollback cap: 10,000 lines per buffer (Game Log + each stream). Oldest lines pruned.

3.5 Prompt & Input

Prompt shows last <prompt> string; can include inline status later.

Input supports:

Readline: Ctrl-A/E/U/K/W, ⌥B/⌥F, ⌥⌫, etc.

History with prefix search (↑/↓).

Multiline with ⇧↩; send on ↩ (configurable).

Aliases (e.g., #hunt) and Snippets (templated commands with ${var}).

Keybinds (user-mapped hotkeys to commands/snippets).

Default keybinds

⌘L focus input · ⌘K clear log · ⌘F find · ⌘1…⌘6 toggle chips 1…6 · ⇧↩ multiline.

3.6 Clickable content

<a> opens context menu (copy, inspect, future actions).

<d cmd="…"> sends command immediately on click (with confirm preference).

Right-click Copy command text always available.

4) Routing, filters, unknowns
4.1 Routing rules (built-in, editable later)

Messages get tags from XML context:

Story (default), plus any stream:<id> when inside a pushStream.

Prompt lines marked separately for UI behavior.

The Streams bar filters by stream tags; mirror toggle controls duplication to Game Log.

4.2 Unknowns & errors

Unknown streams: log (debug console + session log) and ignore.

Malformed XML: capture raw chunk (debug), show brief ⚠︎ in status, resync on next <prompt>.

5) Theming & typography

Default theme: Catppuccin Mocha mapped to semantic tokens: text, background, selection, badges, chip accents, panel chrome.

System-first: adopt system accent and vibrancy where appropriate (chrome only).

ANSI mapping: configurable palette → theme tokens; apply to log text spans.

Fonts: JetBrains Mono for log/input; system SF for chrome/labels.

6) Networking
6.1 Lich detachable client (default)

Host 127.0.0.1, default port 8000, editable per profile; multiple characters = unique ports.

Typical launch (user managed):
ruby ~/lich5/lich.rb[w] --login <char> --without-frontend --detachable-client=8000 
GemStone IV Wiki

Reconnect strategy: exponential backoff (0.5→8s), manual reconnect from toolbar, soft reset parser on connect.

7) Logging

Session files: per day & character.

Formats:

Text (.log): human-readable lines.

JSONL (.jsonl): structured {ts, source, streamId?, html?, text, tags} for tooling.

Rotation: keep 30 days (configurable).

Privacy: no external upload; stored locally.

8) Persistence (single profile)

Location: ~/.sceotan/{account}/{character}/settings.json

Schema (MVP)

{
  "layout": {
    "left":   ["hands","room","vitals"],
    "right":  ["injuries","spells"],
    "colWidth": { "left": 280, "right": 280 },
    "streamsHeight": 112,
    "collapsed": { "hands": false, "room": false, "vitals": false, "injuries": false, "spells": false }
  },
  "streams": {
    "registry": [
      {"id":"thoughts","label":"Thoughts","defaultOn":true,"color":"accent.thoughts","aliases":[]},
      {"id":"speech","label":"Speech","defaultOn":true,"color":"accent.speech","aliases":["says"]},
      {"id":"whispers","label":"Whispers","defaultOn":true,"color":"accent.whispers","aliases":[]},
      {"id":"logons","label":"Logons","defaultOn":true,"color":"accent.logons","aliases":[]},
      {"id":"expr","label":"Experience","defaultOn":false,"color":"accent.experience","aliases":["experience"]},
      {"id":"familiar","label":"Familiar","defaultOn":false,"color":"accent.familiar","aliases":[]}
    ],
    "mirrorFilteredToMain": true,
    "timestamps": { "gameLog": false, "perStream": { "thoughts": false, "speech": false } }
  },
  "input": {
    "sendOnEnter": true,
    "multilineOnShiftEnter": true,
    "echo": { "styled": true, "prefix": "›" },
    "history": { "size": 500 }
  },
  "bindings": {
    "keys": { "Cmd+K": "clear-log", "Cmd+L": "focus-input" },
    "aliases": { "#hunt": "stance offensive;attack" },
    "snippets": { "heal": "cast 1101 @${target}" }
  },
  "theme": { "name": "catppuccin-mocha", "ansiMap": "default" },
  "network": { "host": "127.0.0.1", "port": 8000 }
}

9) Component breakdown (SwiftUI)

App: MudApp (@main)

Scenes: MainScene (single WindowGroup)

Views

AppChromeView (toolbar/status/connection)

StreamsBarView (chips, unread badges)

MainSplitView (Left/Center/Right columns)

PanelColumnView(side:) → PanelHost + concrete panels:

HandsPanel, RoomPanel, VitalsPanel, InjuriesPanel, SpellsPanel

GameLogView (virtualized attributed rows, search overlay)

PromptBarView, CommandInputView

Models / Stores

StreamStore, LogStore, PanelStore, SettingsStore

Services

LichConnection (NWConnection, actor)

XMLStreamParser (SAX, actor)

EventBus (actor)

Persistence (JSON read/write)

ThemeManager (ANSI→theme mapping)

Utilities

AttributedLineBuilder (ANSI + link/action spans)

DialogRenderer (maps <openDialog>/<dialogData> to SwiftUI controls)

KeybindingEngine (string ↔︎ shortcut mapping)

10) Performance & stability

Render budget: keep row composition < 1 ms avg at steady state; batch incoming lines (16–24 ms frames).

Backpressure: if input spikes, buffer lines and coalesce UI updates.

Memory: scrollback cap per buffer (10k lines); image caching for dialog <image> widgets.

Error handling: malformed chunks logged; auto-resync on <prompt>.

11) Accessibility

Full keyboard navigation:

Cycle focus between Streams/Log/Panels/Input (⌥Tab).

Reorder panels with shortcuts (⌘↑/⌘↓ when header focused).

VoiceOver labels on all chip/panel controls and actionable spans.

Adjustable fonts/line height; color-blind-safe chip accents.

12) QA & testing

Parser unit tests: fixtures for representative XML (story, stream, prompt, hands, spells, dialogs).

UI snapshot tests: panels and log rows (light/dark + Mocha).

Performance tests: ingest 50k lines in 2 minutes without dropped frames (with scrollback cap).

E2E smoke: connect to local Lich, run canned session, validate buffers, timestamps, echo, mirror toggle.

13) Roadmap & milestones (4 sprints)

Sprint 1 — Foundations (network, parser, stores)

NWConnection client (reconnects)

SAX parser + event types

Stores (log, streams, panels, settings)

JSON persistence (read/write)

Sprint 2 — Shell & layout

Window + split layout; Streams bar; Prompt + Input

Game Log (virtualized, timestamps, echo)

Streams chips (unread, mirror toggle)

Fixed-height panels with drag/reorder/move

Sprint 3 — Dynamic windows & actions

<openDialog>/<dialogData> renderer (injuries/encumbrance/combat/map)

<a> menus + <d cmd> click-to-send

Search overlay; keybindings; alias/snippet engine

Sprint 4 — Polish

Theme (Catppuccin Mocha) + ANSI mapping

Settings UI; file logging (text + JSONL + rotation)

Accessibility pass; crash-safe error handling

Packaging (DMG) + basic updater (optional)

14) Risks & mitigations

Malformed XML from upstream → strict SAX w/ recovery on <prompt>, robust logging.

SwiftUI list perf on huge logs → enforced scrollback cap; batched updates.

Dialog coverage (unknown widgets) → best-effort renderer, logged gaps, add cases iteratively.

Shortcut conflicts → editable keybindings, macOS-standard defaults.

15) Open knobs (defaults we’ll ship)

Detachable port: 8000

Scrollback cap: 10k lines per buffer

Echo prefix: ›

Log formats: Text ON, JSONL ON (both)

Panel heights: Hands 140 · Room 160 · Vitals 160 · Injuries 180 · Spells 180

16) What to run

Start Lich (example):
ruby ~/lich5/lich.rbw --login <char> --without-frontend --detachable-client=8000 
GemStone IV Wiki

Launch the app; set host 127.0.0.1, port 8000.

If this matches what you want, I’ll immediately break it into a ticket set (by sprint, component, and acceptance criteria) so you can drop it into your tracker. Anything you want me to tweak (e.g., different scrollback cap, alternate defaults for timestamps/echo), say the word.
