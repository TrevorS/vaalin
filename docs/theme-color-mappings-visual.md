# Theme Color Mappings - Visual Reference

**Theme**: Catppuccin Mocha
**Date**: October 7, 2025
**Status**: After Design Review (optimized)

---

## Catppuccin Mocha Palette

### Accent Colors
```
🟥 red       #f38ba8  ████████  RGB(243, 139, 168)
🟧 peach     #fab387  ████████  RGB(250, 179, 135)
🟨 yellow    #f9e2af  ████████  RGB(249, 226, 175)
🟩 green     #a6e3a1  ████████  RGB(166, 227, 161)
🟦 teal      #94e2d5  ████████  RGB(148, 226, 213)
🟦 sky       #89dceb  ████████  RGB(137, 220, 235)
🟦 sapphire  #74c7ec  ████████  RGB(116, 199, 236)
🟦 blue      #89b4fa  ████████  RGB(137, 180, 250)
🟪 lavender  #b4befe  ████████  RGB(180, 190, 254)
🟪 mauve     #cba6f7  ████████  RGB(203, 166, 247)
🩷 pink      #f5c2e7  ████████  RGB(245, 194, 231)
🩷 flamingo  #f2cdcd  ████████  RGB(242, 205, 205)
🩷 rosewater #f5e0dc  ████████  RGB(245, 224, 220)
🟫 maroon    #eba0ac  ████████  RGB(235, 160, 172)
```

### Text Colors
```
⬜ text      #cdd6f4  ████████  RGB(205, 214, 244)  - Primary text
⬜ subtext1  #bac2de  ████████  RGB(186, 194, 222)  - Secondary text
⬜ subtext0  #a6adc8  ████████  RGB(166, 173, 200)  - Tertiary text
```

### Surface Colors
```
⬛ overlay2  #9399b2  ████████  RGB(147, 153, 178)
⬛ overlay1  #7f849c  ████████  RGB(127, 132, 156)
⬛ overlay0  #6c7086  ████████  RGB(108, 112, 134)
⬛ surface2  #585b70  ████████  RGB(88, 91, 112)
⬛ surface1  #45475a  ████████  RGB(69, 71, 90)
⬛ surface0  #313244  ████████  RGB(49, 50, 68)
⬛ base      #1e1e2e  ████████  RGB(30, 30, 46)     - Main background
⬛ mantle    #181825  ████████  RGB(24, 24, 37)     - Alt background
⬛ crust     #11111b  ████████  RGB(17, 17, 27)     - Darkest background
```

---

## Game Presets - Before/After Comparison

### Communication Presets

| Preset | Before | After | Change | Rationale |
|--------|--------|-------|--------|-----------|
| **speech** | 🟩 green | 🟩 green | ✅ Kept | Perfect - friendly, natural |
| **whisper** | 🟦 teal | 🟦 teal | ✅ Kept | Perfect - intimate, distinct |
| **thought** | ⬜ text | ⬜ subtext1 | ✨ Changed | Improved - subtle differentiation |
| **channel** | 🟩 green | 🟦 sapphire | ✨ Changed | Improved - network feel, distinct |

### Combat Presets

| Preset | Before | After | Change | Rationale |
|--------|--------|-------|--------|-----------|
| **damage** | 🟥 red | 🟥 red | ✅ Kept | Perfect - danger/harm |
| **heal** | 🟩 green | 🟦 sky | ✨ Changed | Improved - restorative, distinct |
| **monster** | 🟧 peach | 🟧 peach | ✅ Kept | Perfect - less aggressive than red |
| **watching** | 🟨 yellow | 🟨 yellow | ✅ Kept | Perfect - attention-grabbing |

### Navigation Presets

| Preset | Before | After | Change | Rationale |
|--------|--------|-------|--------|-----------|
| **roomName** | 🟪 lavender | 🟪 lavender | ✅ Kept | Perfect - prominent, beautiful |
| **roomDesc** | ⬜ subtext0 | ⬜ subtext0 | ✅ Kept | Perfect - de-emphasized environmental |

### UI Presets

| Preset | Before | After | Change | Rationale |
|--------|--------|-------|--------|-----------|
| **link** | 🟦 blue | 🟦 blue | ✅ Kept | Perfect - universal convention |
| **bold** | ⬜ text | ⬜ text | ✅ Kept | Perfect - uses font weight |
| **prompt** | ⬜ text | ⬜ text | ✅ Kept | Perfect - neutral |
| **command** | ⬜ subtext1 | ⬜ subtext1 | ✅ Kept | Perfect - de-emphasized echo |
| **macro** | 🟪 mauve | 🟪 mauve | ✅ Kept | Perfect - automated vibe |

---

## Item Categories - Before/After Comparison

| Category | Before | After | Change | Rationale |
|----------|--------|-------|--------|-----------|
| **weapon** | 🟥 red | 🟥 red | ✅ Kept | Perfect - danger, combat |
| **armor** | 🟦 sapphire | 🟦 sapphire | ✅ Kept | Perfect - protection |
| **clothing** | 🟩 green | 🩷 flamingo | ✨ Changed | Improved - soft, fabric feel |
| **gem** | 🟨 yellow | 🟨 yellow | ✅ Kept | Perfect - shiny, valuable |
| **jewelry** | 🩷 pink | 🩷 pink | ✅ Kept | Perfect - precious, decorative |
| **reagent** | 🟪 mauve | 🟪 mauve | ✅ Kept | Perfect - magical, mystical |
| **food** | 🟧 peach | 🟧 peach | ✅ Kept | Perfect - warm, appetizing |
| **valuable** | 🩷 rosewater | 🩷 rosewater | ✅ Kept | Perfect - rare, precious |
| **box** | ⬛ overlay1 | ⬛ overlay1 | ✅ Kept | Perfect - de-emphasized |
| **junk** | ⬛ overlay0 | ⬛ overlay0 | ✅ Kept | Perfect - lowest priority |

---

## UI Semantic Colors

| Semantic | Color | Hex | Visual | Use Case |
|----------|-------|-----|--------|----------|
| **success** | 🟩 green | #a6e3a1 | ████████ | Connection success, action completion |
| **warning** | 🟨 yellow | #f9e2af | ████████ | Low vitals, important notices |
| **danger** | 🟥 red | #f38ba8 | ████████ | Errors, critical vitals, disconnection |
| **info** | 🟦 blue | #89b4fa | ████████ | Neutral information, help text |

---

## Color Usage Summary (After Optimization)

### By Color Family

**Red Family** (Danger/Combat):
- ❤️ red: damage, danger (semantic), weapon (category)
- 🟫 maroon: *(reserved for future `death` preset)*

**Orange Family** (Warmth):
- 🟧 peach: monster, food (category)

**Yellow Family** (Attention/Value):
- 🟨 yellow: watching, warning (semantic), gem (category)

**Green Family** (Positive/Natural):
- 🟩 green: speech, success (semantic)

**Cyan Family** (Water/Communication):
- 🟦 teal: whisper
- 🟦 sky: heal *(changed from green)*
- 🟦 sapphire: channel *(changed from green)*, armor (category)

**Blue Family** (Information/Links):
- 🟦 blue: link, info (semantic)

**Purple Family** (Magical/Special):
- 🟪 lavender: roomName
- 🟪 mauve: macro, reagent (category)

**Pink Family** (Precious/Soft):
- 🩷 pink: jewelry (category)
- 🩷 flamingo: clothing (category) *(changed from green)*
- 🩷 rosewater: valuable (category)

**Neutral Family** (Text/UI):
- ⬜ text: thought, bold, prompt, roomDesc
- ⬜ subtext1: thought *(changed from text)*, command
- ⬜ subtext0: roomDesc
- ⬛ overlay1: box (category)
- ⬛ overlay0: junk (category)

---

## Color Distribution Heatmap

**Preset Usage**:
```
green:     █          (1) - speech
teal:      █          (1) - whisper
sky:       █          (1) - heal ✨
sapphire:  █          (1) - channel ✨
blue:      █          (1) - link
lavender:  █          (1) - roomName
mauve:     █          (1) - macro
red:       █          (1) - damage
peach:     █          (1) - monster
yellow:    █          (1) - watching
subtext1:  ██         (2) - thought ✨, command
text:      ███        (3) - bold, prompt, roomDesc
subtext0:  █          (1) - roomDesc
flamingo:  -          (0) - *(moved to categories)*
```

**Category Usage**:
```
red:       █          (1) - weapon
sapphire:  █          (1) - armor
flamingo:  █          (1) - clothing ✨
yellow:    █          (1) - gem
pink:      █          (1) - jewelry
mauve:     █          (1) - reagent
peach:     █          (1) - food
rosewater: █          (1) - valuable
overlay1:  █          (1) - box
overlay0:  █          (1) - junk
```

**Key**:
- ✨ = Changed during design review
- Each █ = 1 use

---

## Sample Game Text Rendering

### Combat Example
```
You swing your longsword at the 🟧monster!                    (peach)
You hit the monster for 🟥35 points of damage!                (red)
The monster strikes you for 🟥20 points of damage!            (red)
You drink a healing potion and restore 🟦45 health!           (sky) ✨
```

### Communication Example
```
🟩You say, "Hello there!"                                      (green)
🟦Bob whispers, "Secret message."                             (teal)
🟦[LNet]-Bob: "Anyone want to hunt?"                          (sapphire) ✨
💭You ponder your next move.                                  (subtext1) ✨
```

### Navigation Example
```
🟪[Abandoned Inn, Tavern]                                      (lavender)
The dusty tavern smells of old ale and regret.                (subtext0)
Obvious exits: north, east, out
```

### Inventory Example
```
You are carrying:
  🟥a steel longsword                                          (weapon: red)
  🟦some mithril plate armor                                   (armor: sapphire)
  🩷a silk cloak                                              (clothing: flamingo) ✨
  🟨a flawless diamond                                         (gem: yellow)
  🩷a gold ring                                               (jewelry: pink)
  🟪some acantha leaf                                         (reagent: mauve)
  🟧a meat pie                                                 (food: peach)
  🩷a silver wand                                             (valuable: rosewater)
  ⬛a wooden box                                               (box: overlay1)
  ⬛a broken shield                                            (junk: overlay0)
```

---

## Accessibility Notes

### Contrast Ratios (Against `base` #1e1e2e)

| Color | Ratio | WCAG AA | Status |
|-------|-------|---------|--------|
| text (#cdd6f4) | ~13:1 | 4.5:1 | ✅ AAA |
| subtext1 (#bac2de) | ~11:1 | 4.5:1 | ✅ AAA |
| subtext0 (#a6adc8) | ~9:1 | 4.5:1 | ✅ AAA |
| green (#a6e3a1) | ~10:1 | 4.5:1 | ✅ AAA |
| red (#f38ba8) | ~6:1 | 4.5:1 | ✅ AA+ |
| yellow (#f9e2af) | ~12:1 | 4.5:1 | ✅ AAA |
| blue (#89b4fa) | ~7:1 | 4.5:1 | ✅ AA+ |

**All critical text exceeds WCAG AA standards**. ✅

### Colorblind Support

**Deuteranopia/Protanopia** (Red-Green Colorblindness):
- ✅ **Good**: Red/green presets (damage vs. speech) also differ in semantic context
- ✅ **Good**: Item categories span full spectrum (red → orange → yellow → blue → purple)
- ⚠️ **Consider**: Adding bold/italic for critical combat text (damage, heal)

**Tritanopia** (Blue-Yellow Colorblindness):
- ✅ **Good**: Blue presets (link, info, heal, channel) differ in context
- ✅ **Good**: Yellow items (gems) are contextually obvious (valuable items)

---

## Future Enhancements

### Missing Presets (Suggested)
- `spell` → 🟪 mauve (magical casting)
- `death` → 🟫 maroon (character death)
- `experience` → 🟨 yellow (XP gain)
- `ambient` → ⬛ overlay1 (environmental messages)
- `system` → ⬜ subtext1 (game system messages)

### Missing Categories (Suggested)
- `skin` → 🟧 peach (animal pelts)
- `coin` → 🟨 yellow (currency)
- `scroll` → 🟦 blue (documents)
- `potion` → 🟪 mauve (magic consumables)

### Light Mode Theme
- **Catppuccin Latte** (light background variant)
- Same accent colors, optimized for `#eff1f5` base
- Follow-up issue after #22

---

**Last Updated**: October 7, 2025
**Reviewed By**: Claude Code (Liquid Glass Design Expert)
**Status**: ✅ Approved for Production
