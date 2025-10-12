# Liquid Glass Implementation Guide for Vaalin

**Last Updated**: 2025-10-11
**Target Platform**: macOS 26+ (Tahoe)
**Xcode**: 16.0+
**Swift**: 5.9+

## Table of Contents

- [Overview](#overview)
- [Official Documentation](#official-documentation)
- [SwiftUI API Reference](#swiftui-api-reference)
- [AppKit Integration](#appkit-integration)
- [Design Principles](#design-principles)
- [Material Variants](#material-variants)
- [Code Examples](#code-examples)
- [Backward Compatibility](#backward-compatibility)
- [Accessibility](#accessibility)
- [Performance](#performance)
- [Vaalin Implementation Guide](#vaalin-implementation-guide)
- [Common Pitfalls](#common-pitfalls)
- [Resources](#resources)

---

## Overview

Liquid Glass is Apple's new design language introduced at WWDC 2025, extending across iOS 26, iPadOS 26, macOS Tahoe 26, watchOS 26, and tvOS 26. It's a translucent material that **reflects and refracts its surroundings** while dynamically transforming to help bring greater focus to content.

### What Makes Liquid Glass Different

**Traditional Materials** (`.ultraThinMaterial`, `.thinMaterial`):
- Static blur that doesn't adapt to content
- No reflection effects
- No interactive states
- Available pre-macOS 26

**Liquid Glass** (`.glassEffect()`):
- **Dynamic blur & reflection** that adapts to background in real-time
- **Interactive states** responding to hover/touch with fluid animations
- **Morphing transitions** with `glassEffectID` for seamless shape changes
- **Lensing effect** with authentic depth perception
- **Real-time rendering** with specular highlights and refractions
- **Requires macOS 26+**

### Core Philosophy

> "Liquid Glass controls float above content as a distinct functional layer, creating depth while reducing visual complexity."

- **Hierarchy First**: Content is king, controls are glass
- **Navigation, Not Content**: Glass for navigation layer, never content layer
- **Sparingly Applied**: Use only for top-level functional elements
- **Don't Stack Glass**: Avoid glass on top of glass

---

## Official Documentation

### Apple Developer Resources

**Primary Documentation:**
- macOS Tahoe 26 Release Notes: https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes
- Xcode 26 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
- Liquid Glass Overview: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Adopting Liquid Glass: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
- Human Interface Guidelines - Materials: https://developer.apple.com/design/human-interface-guidelines/materials

**API Documentation:**
- `glassEffect(_:in:)`: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- `glassEffect(_:in:isEnabled:)`: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:isenabled:)
- `GlassEffectContainer`: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- `Glass` structure: https://developer.apple.com/documentation/swiftui/glass
- `NSGlassEffectView`: https://developer.apple.com/documentation/appkit/nsglasseffectview

**Design Resources:**
- Apple Design Resources: macOS 26 UI kits for Sketch, Figma, Photoshop, Illustrator
- SF Symbols 7: 6,900+ symbols designed for Liquid Glass

### WWDC 2025 Sessions

1. **Session 219: "Meet Liquid Glass"**
   - Core design principles and philosophy
   - Optical and physical properties
   - When and where to use Liquid Glass
   - https://developer.apple.com/videos/play/wwdc2025/219/

2. **Session 323: "Build a SwiftUI app with the new design"**
   - SwiftUI implementation details
   - Custom UI elements with glass effects
   - Landmarks sample app walkthrough
   - https://developer.apple.com/videos/play/wwdc2025/323/

3. **Session 310: "Build an AppKit app with the new design"**
   - AppKit/NSKit integration
   - NSGlassEffectView usage
   - Migration from NSVisualEffectView
   - https://developer.apple.com/videos/play/wwdc2025/310/

4. **Session 356: "Get to know the new design system"**
   - Best practices and patterns
   - Cross-platform consistency
   - https://developer.apple.com/videos/play/wwdc2025/356/

---

## SwiftUI API Reference

### Basic Glass Effect

```swift
// Default glass effect (Capsule shape)
Text("Hello, Liquid Glass!")
    .padding()
    .glassEffect()

// Regular glass style (explicit)
Text("Hello, Liquid Glass!")
    .padding()
    .glassEffect(.regular)
```

### Interactive Glass

Responds to user interactions (hover, touch) with dynamic visual feedback:

```swift
Button {
    // Action
} label: {
    Label("Home", systemImage: "house")
        .labelStyle(.iconOnly)
        .foregroundColor(.white)
}
.glassEffect(.regular.interactive())
```

### Tinted Glass

Adds color overlay for emphasis:

```swift
Text("Important")
    .padding()
    .glassEffect(.regular.tint(.purple.opacity(0.8)))

// Combined: Interactive + Tinted
Button("Action") {
    // Action
}
.glassEffect(.regular.tint(.blue.opacity(0.6)).interactive())
```

### Custom Shapes

Define the geometric area of the glass effect:

```swift
// Rounded rectangle
VStack {
    // Content
}
.padding()
.glassEffect(.regular, in: .rect(cornerRadius: 12))

// Circle
Image(systemName: "star.fill")
    .frame(width: 80, height: 80)
    .glassEffect(.regular, in: .circle)

// Capsule (default shape)
HStack {
    // Content
}
.padding()
.glassEffect(.regular, in: .capsule)
```

### Conditional Glass Effect

Enable/disable glass effect dynamically:

```swift
struct PanelView: View {
    @State private var useGlass = true

    var body: some View {
        VStack {
            // Content
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12), isEnabled: useGlass)
    }
}
```

### Button Styles

SwiftUI provides built-in glass button styles:

```swift
// Subtle glass for secondary actions
Button("Cancel") {
    // Action
}
.buttonStyle(.glass)

// High emphasis glass for primary actions
Button("Save") {
    // Action
}
.buttonStyle(.glassProminent)
```

### Glass Effect Container

Group multiple glass elements for consistent visual results and morphing transitions:

```swift
struct MultiPanelView: View {
    var body: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 40) {
                // Panel 1
                VStack {
                    Text("Health")
                }
                .glassEffect()

                // Panel 2
                VStack {
                    Text("Mana")
                }
                .glassEffect()
            }
        }
    }
}
```

**Why use GlassEffectContainer?**
- Glass cannot sample other glass (visual artifacts)
- Container ensures consistent rendering
- Required for morphing transitions
- Prevents visual conflicts between overlapping glass elements

### Morphing Transitions

Create fluid shape-changing animations between glass elements:

```swift
struct MorphingDemo: View {
    @State private var expanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 40) {
                Image(systemName: "sun.max.fill")
                    .frame(width: 80, height: 80)
                    .glassEffect()
                    .glassEffectID("sun", in: namespace)

                if expanded {
                    Image(systemName: "moon.fill")
                        .frame(width: 80, height: 80)
                        .glassEffect()
                        .glassEffectID("moon", in: namespace)
                }
            }
        }

        Button("Toggle") {
            withAnimation(.bouncy) {
                expanded.toggle()
            }
        }
        .buttonStyle(.glass)
    }
}
```

**Key Points:**
- Use `@Namespace` to create shared animation context
- Each morphing element needs unique `glassEffectID`
- Wrap elements in `GlassEffectContainer`
- Use `withAnimation` for smooth transitions
- Elements will morph smoothly instead of appearing/disappearing

---

## AppKit Integration

### NSGlassEffectView (New API)

The new AppKit API for Liquid Glass:

```swift
import AppKit

class MyViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let glassView = NSGlassEffectView(frame: view.bounds)
        glassView.cornerRadius = 12
        glassView.tintColor = .systemPurple.withAlphaComponent(0.3)

        view.addSubview(glassView)
    }
}
```

**Properties:**
- `cornerRadius`: Corner radius for glass shape
- `tintColor`: Optional color overlay

### NSGlassEffectContainerView

Groups multiple glass elements:

```swift
let container = NSGlassEffectContainerView()
container.spacing = 40.0

let panel1 = NSGlassEffectView()
let panel2 = NSGlassEffectView()

container.addArrangedSubview(panel1)
container.addArrangedSubview(panel2)
```

### Migration from NSVisualEffectView

**Legacy Approach (Pre-macOS 26):**
```swift
// ❌ Don't use NSVisualEffectView for sidebars in macOS 26
let oldBlur = NSVisualEffectView()
oldBlur.material = .sidebar
```

**Modern Approach (macOS 26+):**
```swift
// ✅ Use NSGlassEffectView instead
let glassView = NSGlassEffectView()
```

**Why migrate?**
- `NSVisualEffectView` prevents glass from showing through
- `NSGlassEffectView` integrates with window chrome
- Better performance and visual consistency

---

## Design Principles

### Layer Hierarchy

Apps made with Liquid Glass should showcase **hierarchy between content and controls**:

1. **Solid Layer** (Bottom)
   - Critical text, icons, buttons
   - Must always remain readable and accessible
   - Placed on top of glass for maximum contrast
   - Example: Game log text, chat messages, body content

2. **Glass Layer** (Middle)
   - Semi-transparent panels, modals, containers
   - Floats above background
   - Creates spatial depth
   - Allows background to show through
   - Example: HUD panels, toolbars, tab bars, sidebars

3. **Dynamic Layer** (Top)
   - Floating overlays, context menus, alerts
   - Appears/shifts based on user interaction
   - Example: Popovers, inline action menus, tooltips

### Visual Hierarchy Rules

**✅ DO:**
- Use glass for **navigation layer** (toolbars, sidebars, HUD)
- Keep **content layer solid** (game log, text, images)
- Place critical text **on top of glass** for legibility
- Create depth by layering glass above solid backgrounds

**❌ DON'T:**
- Apply glass to both content AND navigation layers
- Stack glass on top of glass (causes visual artifacts)
- Use glass for body content or reading areas
- Mix glass material variants (Regular + Clear)

### Golden Rules

1. **Hierarchy First**: Liquid Glass for navigation layer, NOT content layer
2. **Don't Stack Glass**: Avoid glass on top of glass - breaks depth perception
3. **Sparingly**: Use only for top-level functional elements
4. **Content Focus**: Glass should enhance, not distract from content
5. **Never Mix Variants**: Don't mix Regular and Clear in same view
6. **Accessibility**: Always provide fallbacks for reduced transparency

---

## Material Variants

### Regular Glass

**Most common and versatile variant:**
- Standard blur and reflection properties
- Provides all visual and adaptive effects
- Maintains legibility regardless of context
- Use for 90% of glass implementations

```swift
VStack {
    // Panel content
}
.glassEffect(.regular, in: .rect(cornerRadius: 12))
```

**When to use:**
- Toolbars and navigation bars
- HUD panels (Vitals, Hands, Compass)
- Sidebars and floating panels
- Tab bars and bottom bars
- Context menus and popovers

### Clear Glass

**Minimal blur for subtle transparency:**
- Less visual prominence than Regular
- Best over media-rich content
- Content layer won't be negatively affected by dimming

```swift
// Note: .clear variant not yet available in current Xcode builds
// Expected in future releases
VStack {
    // Overlay content
}
.glassEffect(.clear, in: .rect(cornerRadius: 12))
```

**When to use:**
- Elements over full-screen images or video
- Photo/video editing overlays
- Media player controls
- Content that needs maximum see-through

**When NOT to use:**
- Over complex UI backgrounds
- When legibility is critical
- In accessibility-focused contexts

### Interactive Glass

**Responds to user interactions:**
- Dynamic visual feedback on hover/touch
- Fluid animations during interaction
- Enhanced engagement

```swift
Button("Action") {
    // Action
}
.glassEffect(.regular.interactive())
```

**When to use:**
- Buttons and interactive controls
- Draggable panels
- Expandable sections
- Touch-sensitive elements

### Tinted Glass

**Adds color overlay for emphasis:**
- Use subtle opacity (0.3-0.8)
- Maintains glass properties
- Adds visual hierarchy

```swift
VStack {
    // Content
}
.glassEffect(.regular.tint(.purple.opacity(0.6)))
```

**When to use:**
- Highlight important panels
- Status indicators (health critical = red tint)
- Contextual grouping (damage = red, healing = green)
- Branding elements

---

## Code Examples

### Basic Panel Implementation

```swift
// VitalsPanel.swift
struct VitalsPanel: View {
    @Bindable var viewModel: VitalsPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vitals")
                .font(.headline)
                .foregroundStyle(.primary)

            ProgressBarView(
                label: "Health",
                value: viewModel.health,
                maxValue: viewModel.maxHealth,
                color: .red
            )

            ProgressBarView(
                label: "Mana",
                value: viewModel.mana,
                maxValue: viewModel.maxMana,
                color: .blue
            )
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
```

### Interactive Button Panel

```swift
struct ActionPanel: View {
    var body: some View {
        HStack(spacing: 16) {
            Button {
                // Attack action
            } label: {
                Label("Attack", systemImage: "flame.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glassProminent)

            Button {
                // Defend action
            } label: {
                Label("Defend", systemImage: "shield.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
        }
        .padding()
    }
}
```

### Grouped Panels with Container

```swift
struct HUDView: View {
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                VitalsPanel(viewModel: vitalsViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                HandsPanel(viewModel: handsViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                CompassPanel(viewModel: compassViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
        }
    }
}
```

### Tinted Status Panel

```swift
struct HealthPanel: View {
    @Bindable var viewModel: VitalsPanelViewModel

    var healthTint: Color {
        if viewModel.healthPercentage < 0.25 {
            return .red.opacity(0.4)
        } else if viewModel.healthPercentage < 0.5 {
            return .orange.opacity(0.3)
        } else {
            return .clear
        }
    }

    var body: some View {
        VStack {
            Text("Health: \(viewModel.health)")
            ProgressView(value: viewModel.healthPercentage)
        }
        .padding()
        .glassEffect(
            .regular.tint(healthTint),
            in: .rect(cornerRadius: 12)
        )
    }
}
```

### Morphing Panel Expansion

```swift
struct ExpandablePanel: View {
    @State private var expanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                // Header (always visible)
                HStack {
                    Text("Spells")
                    Spacer()
                    Button {
                        withAnimation(.bouncy) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .glassEffectID("header", in: namespace)

                // Expanded content
                if expanded {
                    VStack {
                        SpellRow(spell: "Fireball")
                        SpellRow(spell: "Ice Storm")
                        SpellRow(spell: "Lightning")
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    .glassEffectID("content", in: namespace)
                }
            }
        }
    }
}
```

### Toolbar with Glass Buttons

```swift
struct GameToolbar: View {
    var body: some View {
        HStack(spacing: 8) {
            Button("Settings") {
                // Action
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)

            Spacer()

            Button("Inventory") {
                // Action
            }
            .labelStyle(.toolbar)
            .buttonStyle(.glass)

            Button("Map") {
                // Action
            }
            .labelStyle(.toolbar)
            .buttonStyle(.glass)
        }
        .padding(.horizontal)
    }
}
```

---

## Backward Compatibility

### SwiftUI Fallback Pattern

Create a custom modifier that gracefully degrades on pre-macOS 26:

```swift
import SwiftUI

extension View {
    @ViewBuilder
    func glassedEffect(
        in shape: some Shape = Capsule(),
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(macOS 26.0, *) {
            var style = Glass.regular
            if interactive {
                style = style.interactive()
            }
            if let tint = tint {
                style = style.tint(tint)
            }
            self.glassEffect(style, in: shape)
        } else {
            // Fallback for macOS 25 and earlier
            self.background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    }
                    .overlay {
                        if let tint = tint {
                            shape.fill(tint)
                        }
                    }
            }
        }
    }
}
```

**Usage:**

```swift
// Works on macOS 26+ with glass effect
// Falls back to ultraThinMaterial on older versions
VStack {
    Text("Cross-platform panel")
}
.padding()
.glassedEffect(in: .rect(cornerRadius: 12), interactive: true)
```

### AppKit Compatibility Check

```swift
import AppKit

class GlassCompatibleView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if #available(macOS 26.0, *) {
            setupGlassEffect()
        } else {
            setupLegacyEffect()
        }
    }

    @available(macOS 26.0, *)
    private func setupGlassEffect() {
        let glassView = NSGlassEffectView(frame: bounds)
        glassView.autoresizingMask = [.width, .height]
        addSubview(glassView, positioned: .below, relativeTo: nil)
    }

    private func setupLegacyEffect() {
        let blurView = NSVisualEffectView(frame: bounds)
        blurView.material = .sidebar
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.autoresizingMask = [.width, .height]
        addSubview(blurView, positioned: .below, relativeTo: nil)
    }
}
```

---

## Accessibility

### Built-in Support

Liquid Glass automatically respects system accessibility settings:

**Reduce Transparency:**
- Settings → Accessibility → Display → Reduce Transparency
- Glass effects automatically fade to solid materials
- System handles this for standard SwiftUI/AppKit components

**Increase Contrast:**
- Adjusts glass opacity and tint for better legibility
- Enhances border visibility

**Reduce Motion:**
- Disables morphing animations
- Simplifies transitions to cross-fades

**Solid Menu Bar:**
- Settings → Menu Bar → Use solid color
- User preference for non-transparent menu bar

### Developer Responsibilities

**Use Standard Components:**
```swift
// ✅ Automatic accessibility support
Button("Action") {
    // Action
}
.buttonStyle(.glass)
```

**Provide Fallbacks for Custom Glass:**
```swift
struct CustomGlassPanel: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    var body: some View {
        VStack {
            // Content
        }
        .padding()
        .if(reduceTransparency) { view in
            view.background(.regularMaterial)
        } else: { view in
            view.glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }
}

// Helper extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform,
        else elseTransform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}
```

**Test with Accessibility Settings:**
1. Enable Reduce Transparency
2. Enable Increase Contrast
3. Enable Reduce Motion
4. Verify UI remains usable and legible

---

## Performance

### Optimization

**Apple Silicon Optimized:**
- Liquid Glass uses GPU shaders optimized for Apple silicon
- Real-time rendering of reflections, refractions, specular highlights
- Metal framework for hardware acceleration
- Minimal CPU overhead

**Memory Efficiency:**
- Comparable to traditional materials (`.ultraThinMaterial`)
- Efficient caching of blur passes
- GPU memory managed automatically

**Frame Rate:**
- Maintains 60fps on macOS displays
- Supports ProMotion (120Hz) on compatible Macs
- Dynamic quality scaling under load

### Best Practices

**Do:**
- Use `GlassEffectContainer` for grouped elements (single render pass)
- Prefer standard button styles (`.glass`, `.glassProminent`)
- Limit morphing animations to user-initiated actions
- Reuse glass shapes when possible

**Don't:**
- Create deeply nested glass hierarchies
- Apply glass to frequently updating content
- Use glass for large scrolling areas
- Stack multiple `GlassEffectContainer` instances

### Performance Testing

```swift
import SwiftUI

struct PerformanceTestView: View {
    @State private var panelCount = 10

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 8) {
                ForEach(0..<panelCount, id: \.self) { index in
                    VStack {
                        Text("Panel \(index)")
                    }
                    .padding()
                    .frame(height: 100)
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack {
                Text("Panel Count: \(panelCount)")
                Stepper("Adjust", value: $panelCount, in: 1...100)
            }
            .padding()
            .buttonStyle(.glass)
        }
    }
}
```

**Expected Performance:**
- 10 panels: 60fps
- 50 panels: 60fps
- 100 panels: 50-60fps (depends on content complexity)

---

## Vaalin Implementation Guide

### Panel Architecture

All HUD panels should use Liquid Glass for consistent macOS 26 design:

**Panel Structure:**
```swift
// VitalsPanelView.swift
struct VitalsPanel: View {
    @Bindable var viewModel: VitalsPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Panel header
            Text("Vitals")
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            // Progress bars
            VStack(spacing: 4) {
                ProgressBarView(
                    label: "Health",
                    value: viewModel.health,
                    maxValue: viewModel.maxHealth,
                    color: .red
                )

                ProgressBarView(
                    label: "Mana",
                    value: viewModel.mana,
                    maxValue: viewModel.maxMana,
                    color: .blue
                )

                ProgressBarView(
                    label: "Spirit",
                    value: viewModel.spirit,
                    maxValue: viewModel.maxSpirit,
                    color: .cyan
                )

                ProgressBarView(
                    label: "Stamina",
                    value: viewModel.stamina,
                    maxValue: viewModel.maxStamina,
                    color: .green
                )
            }
        }
        .padding(12)
        .frame(minWidth: 200)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
```

### Main Layout Structure

```swift
// MainView.swift
struct MainView: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Left panel column (HUD)
            leftPanelColumn

            // Center content (game log + input)
            centerContentColumn

            // Right panel column (expandable)
            if appState.showRightPanel {
                rightPanelColumn
            }
        }
        .padding(12)
        .background {
            // Solid background for content layer
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        }
    }

    private var leftPanelColumn: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                VitalsPanel(viewModel: appState.vitalsViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                HandsPanel(viewModel: appState.handsViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                InjuriesPanel(viewModel: appState.injuriesViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                Spacer()
            }
            .frame(width: 220)
        }
    }

    private var centerContentColumn: some View {
        VStack(spacing: 0) {
            // Game log (NO glass - content layer)
            GameLogView(viewModel: appState.gameLogViewModel)

            // Command input (glass toolbar)
            CommandInputView(viewModel: appState.commandInputViewModel)
                .padding(8)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
        }
    }

    private var rightPanelColumn: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                SpellsPanel(viewModel: appState.spellsViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                CompassPanel(viewModel: appState.compassViewModel)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                Spacer()
            }
            .frame(width: 220)
        }
    }
}
```

### Critical Health Tinting

```swift
// VitalsPanelView.swift (enhanced)
struct VitalsPanel: View {
    @Bindable var viewModel: VitalsPanelViewModel

    private var healthTint: Color {
        let percentage = Double(viewModel.health) / Double(viewModel.maxHealth)
        if percentage < 0.25 {
            return .red.opacity(0.5)
        } else if percentage < 0.5 {
            return .orange.opacity(0.3)
        }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Content...
        }
        .padding(12)
        .frame(minWidth: 200)
        .glassEffect(
            .regular.tint(healthTint),
            in: .rect(cornerRadius: 12)
        )
    }
}
```

### Interactive Macro Buttons

```swift
// MacroButtonView.swift
struct MacroButtonView: View {
    let macro: Macro
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: macro.icon)
                    .font(.title2)
                Text(macro.name)
                    .font(.caption)
            }
            .frame(width: 60, height: 60)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
    }
}
```

### Toolbar Implementation

```swift
// GameToolbarView.swift
struct GameToolbarView: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button {
                appState.showSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gear")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)

            Spacer()

            Button {
                appState.showLeftPanel.toggle()
            } label: {
                Label("Left Panel", systemImage: "sidebar.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)

            Button {
                appState.showRightPanel.toggle()
            } label: {
                Label("Right Panel", systemImage: "sidebar.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
```

### Game Log (No Glass)

**Critical**: The game log is **content**, not navigation - do NOT apply glass:

```swift
// GameLogView.swift
struct GameLogView: View {
    @Bindable var viewModel: GameLogViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.messages) { message in
                    Text(message.attributedText)
                        .textSelection(.enabled)
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        // ❌ NO .glassEffect() here - content layer
    }
}
```

### Stream Filtering Chips

```swift
// StreamChipView.swift
struct StreamChip: View {
    let stream: StreamConfig
    @Binding var isActive: Bool

    var body: some View {
        Button {
            isActive.toggle()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(stream.color)
                    .frame(width: 8, height: 8)
                Text(stream.name)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .glassEffect(
            .regular.interactive(),
            in: .capsule,
            isEnabled: isActive
        )
    }
}
```

---

## Common Pitfalls

### 1. Stacking Glass on Glass

**❌ Wrong:**
```swift
VStack {
    VStack {
        Text("Nested")
    }
    .glassEffect() // Inner glass
}
.glassEffect() // Outer glass - BREAKS VISUALS
```

**✅ Correct:**
```swift
GlassEffectContainer {
    VStack {
        VStack {
            Text("Nested")
        }
        .glassEffect()
        .glassEffectID("inner", in: namespace)
    }
}
```

### 2. Applying Glass to Content Layer

**❌ Wrong:**
```swift
ScrollView {
    Text("Game log text...")
}
.glassEffect() // Content should be solid
```

**✅ Correct:**
```swift
ScrollView {
    Text("Game log text...")
}
.background(Color(nsColor: .textBackgroundColor))
```

### 3. Mixing Material Variants

**❌ Wrong:**
```swift
VStack {
    // Panel 1
}
.glassEffect(.regular)

VStack {
    // Panel 2
}
.glassEffect(.clear) // Different variant
```

**✅ Correct:**
```swift
// Stick to one variant throughout the app
VStack {
    // Panel 1
}
.glassEffect(.regular)

VStack {
    // Panel 2
}
.glassEffect(.regular) // Same variant
```

### 4. Forgetting GlassEffectContainer

**❌ Wrong:**
```swift
VStack {
    // Panel 1
}
.glassEffect()

VStack {
    // Panel 2 - will sample Panel 1's glass
}
.glassEffect()
```

**✅ Correct:**
```swift
GlassEffectContainer {
    VStack {
        // Panel 1
    }
    .glassEffect()

    VStack {
        // Panel 2
    }
    .glassEffect()
}
```

### 5. Overusing Glass Effects

**❌ Wrong:**
```swift
VStack {
    Text("Title").glassEffect()
    Text("Subtitle").glassEffect()
    Button("Action").glassEffect()
    Divider().glassEffect()
}
.glassEffect() // Too much glass!
```

**✅ Correct:**
```swift
VStack {
    Text("Title")
    Text("Subtitle")
    Button("Action")
        .buttonStyle(.glass)
    Divider()
}
.glassEffect() // Single glass container
```

### 6. Missing Accessibility Fallbacks

**❌ Wrong:**
```swift
// Custom glass with no accessibility support
VStack {
    // Content
}
.background(.ultraThinMaterial)
.overlay(.white.opacity(0.1))
```

**✅ Correct:**
```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

VStack {
    // Content
}
.if(reduceTransparency) { view in
    view.background(.regularMaterial)
} else: { view in
    view.glassEffect(.regular)
}
```

---

## Resources

### Official Apple Resources

- **WWDC 2025 Videos**: https://developer.apple.com/wwdc25/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/
- **Apple Design Resources**: https://developer.apple.com/design/resources/
- **SF Symbols 7**: https://developer.apple.com/sf-symbols/

### Community Resources

**Tutorials:**
- Livsy Code: "Implementing the glassEffect in SwiftUI": https://livsycode.com/swiftui/implementing-the-glasseffect-in-swiftui/
- Donny Wals: "Designing custom UI with Liquid Glass": https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/
- Create with Swift: "Morphing glass effects with glassEffectID": https://www.createwithswift.com/morphing-glass-effect-elements-into-one-another-with-glasseffectid/
- Swift with Majid: "Glassifying toolbars in SwiftUI": https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/

**Sample Code:**
- mertozseven/LiquidGlassSwiftUI: https://github.com/mertozseven/LiquidGlassSwiftUI
- artemnovichkov/iOS-26-by-Examples: https://github.com/artemnovichkov/iOS-26-by-Examples
- GonzaloFuentes28/LiquidGlassCheatsheet: https://github.com/GonzaloFuentes28/LiquidGlassCheatsheet

**Design Guidance:**
- LogRocket: "Adopting Liquid Glass: Examples and best practices": https://blog.logrocket.com/ux-design/adopting-liquid-glass-examples-best-practices/
- MockFlow: "Designing iOS 26 Screens with Liquid Glass Design": https://mockflow.com/blog/designing-ios-26-screens-with-liquid-glass-design

### Vaalin-Specific

- **GemStone IV Wiki**: https://gswiki.play.net/ (Game context for UI design)
- **Illthorn Reference**: `/Users/trevor/Projects/illthorn/` (TypeScript reference implementation)
- **CLAUDE.md**: `/Users/trevor/Projects/vaalin/CLAUDE.md` (Project guidelines)

---

## Version History

- **2025-10-11**: Initial guide created with comprehensive macOS 26 Liquid Glass implementation details
- Target: Vaalin MUD client development for macOS 26+

---

## Next Steps

1. **Review Existing Panels**: Audit current panel implementations (VitalsPanel, HandsPanel, etc.)
2. **Apply Glass Effects**: Add `.glassEffect()` to navigation layer components
3. **Group with Containers**: Wrap related panels in `GlassEffectContainer`
4. **Test Accessibility**: Verify behavior with Reduce Transparency enabled
5. **Optimize Performance**: Use Instruments to profile glass rendering
6. **Add Polish**: Implement tinted glass for status indicators
7. **Create Previews**: Build preview files for all glass states

**Priority Issues:**
- Update panel views with glass effects (#48, #49, #50, etc.)
- Implement toolbar with glass button styles
- Add morphing animations for expandable panels
- Test on macOS 26 beta devices

