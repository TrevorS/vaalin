# Phase 1 Integration Checkpoint - Manual QA Test Guide

## 🎯 Overview

This guide validates that **all Phase 1 components work together end-to-end** with a real Lich server and live GemStone IV game connection.

**What this tests:**
- End-to-end data flow: Lich → LichConnection → ParserConnectionBridge → XMLStreamParser → GameLogViewModel → GameLogView
- Real-world protocol handling (actual GemStone IV XML from live server)
- Application stability under normal gameplay conditions
- Memory management during extended sessions
- Connection lifecycle (connect, run, disconnect)

**Automated tests validate:** Mock server scenarios, unit logic, performance benchmarks
**Manual tests validate:** Real-world behavior, user experience, live gameplay integration

---

## 📋 Prerequisites

### Required Software

1. **Lich 5** - GemStone IV scripting engine
   - Installation: https://lichproject.org/
   - Verify: `lich --version` shows 5.x.x

2. **GemStone IV Account** - Active subscription with logged-in character
   - Free trial available at: https://www.play.net/gs4/

3. **Xcode 16.0+** - For building Vaalin
   - macOS 26 (Tahoe) SDK required
   - Command Line Tools installed

4. **Activity Monitor** - For memory tracking (pre-installed on macOS)

### Build Requirements

```bash
# Navigate to project
cd /Users/trevor/Projects/vaalin

# Verify build system
swift --version  # Should show Swift 5.9+
swiftlint --version  # Should show swiftlint installed

# Clean build
make clean
```

---

## 🚀 Test Procedure

### Step 1: Start Lich Detachable Client Server

Lich must be running in detachable client mode for Vaalin to connect.

```bash
# Start Lich with detachable client on port 8000
lich --without-frontend --detachable-client=8000
```

**Expected output:**
```
[Lich] Starting Lich 5.x.x
[Lich] Detachable client server listening on 127.0.0.1:8000
[Lich] Waiting for client connection...
```

**⚠️ Important:** Leave this terminal window open - Lich must stay running throughout testing.

**Troubleshooting:**
- Port 8000 already in use? Try: `lich --without-frontend --detachable-client=8001` (update port in Step 3)
- Lich not found? Check installation: `which lich`
- Connection refused? Verify Lich started successfully and shows "listening" message

---

### Step 2: Build Vaalin

Build the Debug configuration for testing:

```bash
# From project root
make build
```

**Expected output:**
```
🔨 Building Vaalin (Debug)...
swift build
Building for debugging...
Build complete! (2.07s)
```

**Verify build succeeded:**
```bash
ls -lh .build/debug/Vaalin
```

Should show `Vaalin` executable ~500KB-1MB.

**Troubleshooting:**
- Build errors? Run `make lint` to check for code issues
- Missing dependencies? Run `swift package resolve`
- Xcode version issues? Verify `xcodebuild -version` shows 16.0+

---

### Step 3: Launch Vaalin App

Open the built application:

```bash
open .build/debug/Vaalin.app
```

**Expected behavior:**
- Vaalin.app window appears (1200x800 default size)
- Connection controls visible at top (host, port, Connect button)
- Empty game log area below
- No crashes or error dialogs

**Initial UI state:**
- **Host field:** Shows `127.0.0.1` (default)
- **Port field:** Shows `8000` (default)
- **Status:** Red circle / "Disconnected" indicator
- **Connect button:** Enabled, ready to click
- **Game log:** Empty (gray background)

**Troubleshooting:**
- App crashes on launch? Check Console.app for crash logs (filter: "Vaalin")
- Window doesn't appear? Check if app is hidden (Cmd+H toggles)
- Permission issues? macOS may block unsigned apps - Right-click → Open

---

### Step 4: Connect to Lich

Click the **Connect** button in Vaalin.

**Expected sequence:**
1. Button changes to "Connecting..." (briefly, ~0.5-1 second)
2. Lich terminal shows: `[Lich] Client connected from 127.0.0.1`
3. Vaalin status indicator changes to green circle / "Connected"
4. Initial game XML appears in log (connection handshake, room description, etc.)
5. Connect button changes to "Disconnect" button

**First data received (typical):**
```
<mode id="GAME"/>
<settingsInfo ... />
<streamWindow id="main" ... />
[Current room description]
> (prompt)
```

**✅ Success indicators:**
- Green status indicator visible
- Lich reports client connected
- Game text appears in log within 1-2 seconds
- Text is readable (not garbled XML or encoding errors)
- Disconnect button now available

**❌ Failure indicators:**
- Error message appears: "Connection failed" or "Connection timeout"
- Status stays red / "Disconnected"
- Lich terminal shows no connection message
- App crashes

**Troubleshooting:**
- **Connection timeout**: Verify Lich is running and listening on correct port
- **Connection refused**: Check firewall settings (localhost should be allowed)
- **"Connecting..." forever**: Check Lich terminal for errors, restart Lich
- **Connected but no data**: Verify Lich is logged into GemStone IV character

---

### Step 5: Verify Real-Time Game Output

With connection established, verify live game data flows correctly.

#### 5.1: Prompt Verification

**Action:** Press Enter in Lich terminal (or via Lich's input method)

**Expected:**
- Prompt character `>` appears in Vaalin game log
- Appears within 100-200ms of pressing Enter
- Formatted correctly (not showing XML tags like `<prompt>`)

#### 5.2: Movement Commands

**Action:** Send movement command via Lich (e.g., type `go door` or `north`)

**Expected:**
- Room description appears in Vaalin log
- Exit list visible (e.g., "Obvious exits: north, south, east")
- No XML tags visible in output (tags should be parsed)
- Text appears within 200-500ms of command

**Example expected output:**
```
[Wehnimer's Landing, Town Square]
The tree-lined streets of Wehnimer's Landing converge at this central point.
Obvious exits: north, east, south, west
>
```

#### 5.3: Combat Spam

**Action:** Enter combat via Lich (or observe existing combat)

**Expected:**
- Rapid combat messages appear in Vaalin log
- Messages scroll smoothly (60fps)
- No lag or freezing
- All messages visible (no data loss)

**Example expected output:**
```
You swing at the kobold!
The kobold dodges!
The kobold attacks!
You parry!
>
```

#### 5.4: Stream Management

**Action:** Send commands that trigger different streams (thoughts, speech, etc.)

**Expected:**
- Stream-specific content appears correctly
- No mixing of streams in output
- Parser maintains stream state across chunks

**Example (thoughts):**
```
You think to yourself, "This is a test."
>
```

#### 5.5: Item Highlighting

**Action:** Look at room with items (e.g., `look`)

**Expected:**
- Items appear in log with correct formatting
- Item nouns extractable (e.g., "gem", "coin")
- Attributes preserved (exist ID, noun)

**Example:**
```
You see a blue gem and some silver coins here.
>
```

**✅ Pass criteria:**
- All 5 scenarios display correctly
- Text appears in real-time (< 500ms delay)
- No XML tags visible in output
- No crashes or freezes

**❌ Fail criteria:**
- Raw XML tags visible (e.g., `<pushStream>`)
- Missing messages (data loss)
- Garbled text or encoding issues
- App freezes during combat spam

---

### Step 6: Stability Test (5 Minutes)

Leave Vaalin connected and observe behavior during normal gameplay.

#### 6.1: Setup Monitoring

**Open Activity Monitor:**
1. Launch Activity Monitor.app
2. Search for "Vaalin" in process list
3. Double-click Vaalin process → Memory tab
4. Note initial memory usage (should be < 100MB)

**Baseline metrics:**
- **Initial memory:** ~50-100MB (typical for empty log)
- **CPU:** < 5% when idle, < 20% during combat

#### 6.2: Active Gameplay

**Action:** Play GemStone IV normally for 5 minutes via Lich:
- Walk around rooms
- Look at objects
- Enter/exit combat
- Use skills or spells
- Talk to NPCs

**Monitoring checklist (check every ~1 minute):**

**Minute 1:**
- [ ] Memory: < 150MB
- [ ] CPU: Reasonable (< 30% average)
- [ ] Game log scrolling smoothly
- [ ] No visual glitches

**Minute 2:**
- [ ] Memory: < 200MB
- [ ] No crashes or hangs
- [ ] All text still appearing
- [ ] Scroll performance good (60fps)

**Minute 3:**
- [ ] Memory: < 250MB
- [ ] Connection indicator still green
- [ ] No error messages in log
- [ ] App responsive (not beachballing)

**Minute 4:**
- [ ] Memory: < 300MB
- [ ] Game log still updating in real-time
- [ ] No memory leaks visible (not growing unbounded)
- [ ] Lich connection stable

**Minute 5:**
- [ ] Memory: < 350MB (**must be < 500MB per requirements**)
- [ ] App still running smoothly
- [ ] No crashes during entire 5-minute session
- [ ] Final stability check passed

**Performance targets:**
- **Memory:** Must stay below 500MB (requirement)
- **Typical:** 200-350MB for 5 minutes of gameplay
- **Scrolling:** Smooth 60fps during combat spam
- **Latency:** < 500ms from command to visible output

**✅ Pass criteria:**
- No crashes for entire 5 minutes
- Memory stays below 500MB
- Scrolling remains smooth throughout
- Connection never drops

**❌ Fail criteria:**
- App crashes at any point
- Memory exceeds 500MB
- Scrolling becomes choppy (< 30fps)
- Connection drops without user action
- App becomes unresponsive

---

### Step 7: Disconnect Test

Verify clean disconnection without crashes.

**Action:** Click the **Disconnect** button in Vaalin

**Expected sequence:**
1. Button changes to "Disconnecting..." (briefly)
2. Status indicator changes to red circle / "Disconnected"
3. Lich terminal shows: `[Lich] Client disconnected`
4. Button changes to "Connect" (ready to reconnect)
5. Game log stops updating (no new messages)
6. **No crashes or error dialogs**

**✅ Success indicators:**
- Clean disconnect (< 1 second)
- Status changes to red
- App remains running (no crash)
- Lich reports disconnect
- UI still responsive

**❌ Failure indicators:**
- App crashes on disconnect
- Disconnect hangs (> 5 seconds)
- Status doesn't change
- Memory leak (memory doesn't release)

**Optional: Reconnection test**
1. Click "Connect" again
2. Should reconnect successfully
3. Game log starts updating again

---

### Step 8: Memory Release Verification

After disconnecting, verify memory is released properly.

**Action in Activity Monitor:**
1. Note memory usage while connected (from Step 6)
2. Disconnect (Step 7)
3. Wait 10 seconds
4. Note memory usage after disconnect

**Expected:**
- Memory drops by 50-80% after disconnect
- Example: 300MB → 50-100MB
- Indicates proper cleanup (no major leaks)

**✅ Pass:** Memory drops significantly (buffer pruning works)
**⚠️ Warning:** Memory stays high (> 80% of connected value) - possible leak
**❌ Fail:** Memory increases or doesn't drop at all

---

## ✅ Success Criteria Checklist

All 5 acceptance criteria from Issue #20 must be validated:

### Criterion 1: Can connect to Lich on localhost:8000
- [ ] Connect button works
- [ ] Connection established within 2 seconds
- [ ] Green status indicator appears
- [ ] Lich reports client connected

### Criterion 2: Receives XML data from game
- [ ] Initial handshake data received (mode, settings, streams)
- [ ] Room descriptions appear
- [ ] Commands echo and responses visible
- [ ] All data appears in real-time

### Criterion 3: Parser produces GameTag structures
- [ ] XML tags are parsed (not visible in output)
- [ ] Text content extracted correctly
- [ ] Attributes preserved (item exist/noun)
- [ ] Stream management works (pushStream/popStream)

### Criterion 4: Tags displayed in GameLogView
- [ ] Game text appears in UI
- [ ] Text is readable and formatted
- [ ] Scrolling works correctly
- [ ] Auto-scroll to bottom functions

### Criterion 5: No crashes during 5-minute connection
- [ ] App runs for 5+ minutes without crash
- [ ] Memory stays below 500MB
- [ ] Connection remains stable
- [ ] Performance stays good (60fps scrolling)

**All 5 criteria must pass for Phase 1 checkpoint to be considered COMPLETE.** ✅

---

## 📊 Test Results Template

Copy this template to document your results:

```markdown
# Phase 1 Integration Checkpoint - Manual QA Results

**Date:** YYYY-MM-DD
**Tester:** [Your name]
**Lich Version:** [e.g., 5.8.3]
**Vaalin Build:** [git commit hash from `git rev-parse --short HEAD`]
**macOS Version:** [e.g., macOS 26.0]

## Environment
- Lich Port: 8000
- Character: [Character name]
- Test Duration: [e.g., 7 minutes total]

## Test Results

### Step 1: Lich Startup
- [x] Lich started successfully on port 8000
- [x] No errors in Lich terminal

### Step 2: Build
- [x] Clean build completed in [X.XX]s
- [x] No warnings or errors

### Step 3: App Launch
- [x] Vaalin.app launched without crash
- [x] UI loaded correctly

### Step 4: Connection
- [x] Connected to Lich successfully
- [x] Initial data received within 2 seconds
- Connection time: [X.XX]s

### Step 5: Real-Time Output
- [x] Prompts display correctly
- [x] Movement commands work
- [x] Combat spam flows smoothly
- [x] Stream management correct
- [x] Item highlighting works

### Step 6: Stability Test (5 Minutes)
- [x] No crashes during session
- [x] Memory stayed below 500MB (peak: [XXX]MB)
- [x] Scrolling smooth throughout
- [x] Connection stable

**Performance Metrics:**
- Initial memory: [XX]MB
- Peak memory (5 min): [XXX]MB
- Final memory: [XXX]MB
- CPU average: [XX]%
- Scrolling FPS: [XX] (estimated)

### Step 7: Disconnect
- [x] Clean disconnect (no crash)
- [x] Lich reported disconnect
- Disconnect time: [X.XX]s

### Step 8: Memory Release
- [x] Memory dropped after disconnect
- Before: [XXX]MB → After: [XX]MB
- Release: [XX]%

## Acceptance Criteria
- [x] **Criterion 1:** Connect to localhost:8000 ✅
- [x] **Criterion 2:** Receives XML data ✅
- [x] **Criterion 3:** Parser produces GameTags ✅
- [x] **Criterion 4:** Tags displayed in GameLogView ✅
- [x] **Criterion 5:** No crashes for 5+ minutes ✅

## Overall Result
**STATUS:** ✅ PASSED / ❌ FAILED

## Notes
[Any observations, edge cases, or issues discovered]

## Screenshots
[Optional: Include screenshots of connected app, game log, memory usage]

## Sign-Off
Phase 1 Integration Checkpoint: ✅ COMPLETE

Tester Signature: ________________________ Date: __________
```

---

## 🐛 Troubleshooting

### Issue: Connection Fails

**Symptoms:** "Connection timeout" or "Connection refused" error

**Solutions:**
1. Verify Lich is running: Check terminal for "listening" message
2. Check port number matches: Default is 8000 in both Lich and Vaalin
3. Test Lich port manually: `nc -v localhost 8000` (should connect)
4. Restart Lich: Kill and restart detachable client server
5. Check firewall: Ensure localhost connections allowed

### Issue: App Crashes on Launch

**Symptoms:** Vaalin.app quits immediately after opening

**Solutions:**
1. Check Console.app for crash logs (search "Vaalin")
2. Verify macOS version is 26+ (Tahoe required for Liquid Glass APIs)
3. Rebuild: `make clean && make build`
4. Check entitlements: App should have network access permission

### Issue: No Data Appears After Connection

**Symptoms:** Connected (green) but game log stays empty

**Solutions:**
1. Verify Lich is logged into character (not at login screen)
2. Send a command via Lich (`look` or movement)
3. Check Lich terminal for errors
4. Disconnect and reconnect
5. Check Activity Monitor - if CPU is high, parser may be stuck

### Issue: Garbled Text or XML Tags Visible

**Symptoms:** Raw XML like `<pushStream id="room"/>` appears in log

**Solutions:**
1. This is a **critical bug** - parser is not working
2. Report to development team with screenshot
3. Check git branch - ensure on correct branch
4. Verify build is up-to-date: `git pull && make clean && make build`

### Issue: Memory Grows Unbounded

**Symptoms:** Memory exceeds 500MB and keeps growing

**Solutions:**
1. This indicates a **memory leak** - critical bug
2. Document exact steps to reproduce
3. Note memory usage at 1, 2, 3, 4, 5 minutes
4. Report with Activity Monitor screenshot
5. Check for buffer pruning - should cap at 10,000 messages

### Issue: Scrolling Becomes Choppy

**Symptoms:** Game log stutters or lags during combat

**Solutions:**
1. Check Activity Monitor CPU usage - should be < 30%
2. Verify combat spam rate isn't excessive (100+ lines/sec)
3. Check memory - if high, pruning may be slow
4. This may be a **performance regression** - report to dev team

### Issue: Disconnect Hangs

**Symptoms:** Clicking Disconnect freezes app or takes > 5 seconds

**Solutions:**
1. Wait up to 10 seconds - some cleanup is async
2. If still hung, Force Quit (Cmd+Opt+Esc)
3. Check Lich terminal - may show errors
4. Report timing details (how long until freeze)

---

## 📚 Additional Resources

### Lich Documentation
- Official site: https://lichproject.org/
- Detachable client guide: https://lichproject.org/docs/detachable-client

### GemStone IV XML Protocol
- Protocol reference: https://gswiki.play.net/Lich_XML_Data_and_Tags
- Tag documentation: Lists all XML tags, attributes, and semantics

### Vaalin Project Documentation
- Requirements: `/Users/trevor/Projects/vaalin/docs/requirements.md`
- Architecture: `/Users/trevor/Projects/vaalin/CLAUDE.md`
- Issue #20 details: https://github.com/TrevorS/vaalin/issues/20

### Automated Tests
- Run full test suite: `make test`
- Integration tests: `swift test --filter Phase1IntegrationTests`
- See test coverage: Review `TestResults.xcresult` after running tests

---

## 🎯 Next Steps After Passing

Once all acceptance criteria pass:

1. **Document results** using the template above
2. **Take screenshots** (optional but recommended)
3. **Update PR #115** with QA results:
   ```bash
   gh pr comment 115 --body "✅ Manual QA passed - [link to results doc]"
   ```
4. **Mark Issue #20 as complete** - Ready for merge
5. **Proceed to Phase 2** (Issues #21-32)

---

**Questions or issues during testing?**
- Check troubleshooting section above
- Review automated test results: `make test`
- Consult CLAUDE.md for architecture details
- Report bugs: https://github.com/TrevorS/vaalin/issues

**Happy testing!** 🚀
