#!/bin/bash
# ABOUTME: Script to capture screenshots of Xcode SwiftUI previews
#
# This script automates the process of opening a preview file in Xcode,
# ensuring the canvas is visible, refreshing it, capturing a screenshot,
# and returning focus to the previously active application.
#
# USAGE:
#   ./scripts/capture-preview.sh <preview-file-path> <output-screenshot-path>
#
# EXAMPLE:
#   ./scripts/capture-preview.sh \
#     VaalinUI/Sources/VaalinUI/Views/Panels/Previews/VitalsPanel/VitalsPanelPopulatedState.swift \
#     /tmp/vaalin-vitals-populated.png
#
# REQUIREMENTS:
#   - Xcode must be installed
#   - System Events accessibility permissions must be enabled for Terminal/Ghostty
#     (System Settings → Privacy & Security → Accessibility)
#
# HOW IT WORKS:
#   1. Captures the currently focused application (to return to it later)
#   2. Opens the specified Swift preview file in Xcode
#   3. Checks if the Canvas is already visible (to avoid toggling it off)
#   4. Shows the Canvas if it's not visible (Cmd+Option+Return)
#   5. Refreshes the Canvas preview (Cmd+Option+P)
#   6. Waits for the preview to render
#   7. Captures just the Xcode window using its geometry
#   8. Saves the screenshot to the specified output path
#   9. Returns focus to the previously active application
#
# ABOUT APPLESCRIPT:
#   AppleScript is macOS's scripting language for automating applications.
#   It uses English-like syntax with "tell" blocks to send commands to apps.
#
#   Key concepts used in this script:
#   - "tell application" - sends commands to a specific app
#   - "System Events" - provides access to UI elements and keyboard/mouse automation
#   - "process" - represents a running application's UI
#   - "menu item" - represents a menu option (like Editor → Canvas)
#   - "attribute" - properties of UI elements (like checkmarks on menu items)
#   - "keystroke" - simulates keyboard input
#   - "window" - represents an application window
#   - "position/size" - window geometry for screenshots

set -e  # Exit on any error

# Validate arguments
if [ $# -ne 2 ]; then
    echo "❌ Error: Exactly 2 arguments required"
    echo ""
    echo "Usage: $0 <preview-file-path> <output-screenshot-path>"
    echo ""
    echo "Example:"
    echo "  $0 \\"
    echo "    VaalinUI/Sources/VaalinUI/Views/Panels/Previews/VitalsPanel/PopulatedState.swift \\"
    echo "    /tmp/vaalin-vitals-populated.png"
    exit 1
fi

# Get absolute path for the preview file
# POSIX file format is required for AppleScript file operations
PREVIEW_FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUTPUT_PATH="$2"

echo "📸 Capturing Xcode preview..."
echo "   Preview: $PREVIEW_FILE"
echo "   Output:  $OUTPUT_PATH"

# Run the AppleScript automation
# The <<'EOF' syntax is a "heredoc" - it allows multi-line strings in bash
# The quotes around 'EOF' prevent variable expansion (we want literal AppleScript)
osascript <<EOF
-- STEP 1: Capture the currently focused application
-- We'll return to this app at the end so the user knows we're done
tell application "System Events"
    set frontmostApp to name of first application process whose frontmost is true
end tell

-- STEP 2: Open the workspace and then the preview file in Xcode
-- "tell application" activates and sends commands to the specified app
tell application "Xcode"
    -- Activate brings Xcode to the front
    activate

    -- First, open the workspace/project
    -- This gives us the full Xcode environment needed for previews
    open POSIX file "/Users/trevor/Projects/vaalin/Package.swift"

    -- Wait for workspace to load
    delay 3

    -- Then open the specific preview file within the project
    -- POSIX file converts Unix paths to AppleScript file references
    open POSIX file "$PREVIEW_FILE"

    -- Wait for file to open and Xcode to settle
    delay 3
end tell

-- STEP 3: Show the Canvas
-- System Events provides access to UI elements via the Accessibility API
-- Note: We always toggle the canvas open to ensure it's visible
-- If it's already open, toggling twice will keep it open
tell application "System Events"
    tell process "Xcode"
        -- First toggle - this will open if closed, or close if open
        keystroke return using {command down, option down}
        delay 1

        -- Second toggle - this ensures canvas ends up open
        -- If it was closed: first opens it, second closes it → we'll open again
        -- If it was open: first closes it, second opens it → ends open
        keystroke return using {command down, option down}
        delay 5

        -- STEP 4: Refresh the canvas preview
        -- Cmd+Option+P refreshes the preview (forces re-render)
        keystroke "p" using {command down, option down}

        -- Wait for preview to re-compile and render
        -- This delay ensures the preview has time to compile and display
        delay 4

        -- STEP 5: Get window geometry for screenshot
        -- We'll use these coordinates to capture just the Xcode window
        set frontWindow to window 1

        -- Position is {x, y} from top-left of screen
        set windowPosition to position of frontWindow
        -- Size is {width, height} in pixels
        set windowSize to size of frontWindow

        -- Extract individual values
        -- AppleScript lists are 1-indexed (item 1, item 2)
        set xPos to item 1 of windowPosition
        set yPos to item 2 of windowPosition
        set windowWidth to item 1 of windowSize
        set windowHeight to item 2 of windowSize
    end tell
end tell

-- STEP 6: Ensure Xcode is still focused and capture screenshot
tell application "Xcode"
    activate
    delay 0.5
end tell

-- Capture screenshot using window geometry
-- screencapture is macOS's built-in screenshot utility
-- -R captures a rectangle with format: x,y,width,height
-- -x disables the camera sound
-- do shell script executes shell commands from AppleScript
do shell script "screencapture -R" & xPos & "," & yPos & "," & windowWidth & "," & windowHeight & " -x '$OUTPUT_PATH'"

-- STEP 7: Return focus to the previously active application
-- This lets the user know the automation is complete
tell application frontmostApp
    activate
end tell

-- Return success message
return "Screenshot saved to $OUTPUT_PATH"
EOF

echo "✅ Screenshot captured successfully!"
echo "   Saved to: $OUTPUT_PATH"
