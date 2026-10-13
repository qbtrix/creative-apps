# Design rules

How every app in the suite looks and behaves. These are Apple's Human Interface
Guidelines for macOS 26 (the Liquid Glass design) in our own words, plus the
suite's own taste. When an API name or size matters, check the current HIG
(https://developer.apple.com/design/human-interface-guidelines/); it changes
every June.

## The suite's taste

- **Only the outer edge is glass.** The window chrome (toolbar, sidebar,
  inspector) is system Liquid Glass, and a few floating controls over the
  canvas (a tool palette, a transport bar) may be glass. Everything inside,
  the canvas, lists, cards, panels of settings, stays flat.
- **Quiet chrome, loud content.** The artwork is the most colorful thing on
  screen. Chrome is monochrome; color marks state (the selected tool, the one
  primary action).
- **Five apps, one family.** Same window shell, same spacing, same type, same
  tool palette. SuiteUI holds all of it; an app that needs something different
  asks for it there (`needs-ui`).

## Journeys first, no dead controls

- **The core loop comes first.** For each app: open or create a document, see
  it, edit it with each tool shown, undo, save. Panels and polish come after
  that loop works end to end.
- **No dead controls.** Every button, tool and menu item on screen does
  something. One that can't act yet is disabled, and its tooltip says why
  (`ToolbarAction`'s `unavailableHelp`; a menu item gets a nil action). A
  control that looks live and does nothing is a bug.

## Component order

Every view is built from, in this order:

1. **Apple's own SwiftUI and system components and design resources.** Native
   controls (`Button`, `Toggle`, `Slider`, `Stepper`, `Picker`, `ColorPicker`,
   `List`, `Table`, `OutlineGroup`, `Form`, `.inspector`,
   `NavigationSplitView`, toolbar items, `Menu`, `.searchable`), SF Symbols,
   system fonts and text styles, semantic system colors, system materials and
   glass.
2. **Then SuiteUI** components and tokens.
3. **Never a hand-rolled look-alike** of either. SuiteUI's restyled
   controls (the bar slider, the keyframe button) are the one sanctioned
   replacement for a system control; they keep its keyboard and VoiceOver
   behavior, and an app never draws its own.

Apple's design resources are the source of truth: SF Symbols for icons, the
macOS 26 Human Interface Guidelines for behavior and layout. This file only
restates them for the suite.

| Need | Use |
|---|---|
| Window with sidebar, content, inspector | `SuiteWindow` (a `NavigationSplitView` with `.inspector`) |
| Selection properties | `.inspector`, through `SuiteWindow`'s inspector slot |
| List of items, rows with columns, a tree | `List`, `Table`, `OutlineGroup` (sidebar rows: `SidebarItem`) |
| Settings or a group of options | `Form` (app settings in a `Settings` scene) |
| On/off | `Toggle` (`.toggleStyle(.checkbox)` in inspectors) |
| A value in a range | In an inspector, the bar slider (`InspectorSliderRow`); elsewhere `Slider`. Exact coordinates: `ScrubField` (no `Stepper` in inspectors) |
| Inspector layout | `InspectorHeader`, `InspectorSection`, `InspectorRow` and the `Inspector…Row`s |
| Keyframe toggle beside a property | `KeyframeButton` |
| Presets, chips, a full-width action | `PresetGrid`, `ChipRow`, `InspectorAction` |
| Layers or scenes in a panel | `LayerList` (built on `SidebarRow`) |
| Zoom, size and status under a viewer | `ViewerStatusBar` (drawn as status pills) |
| One of a few choices | `Picker` (segmented, menu or radio style) |
| A color | `ColorPicker` |
| Commands | `Menu`, menu bar commands, toolbar items (`ToolbarAction`) |
| Search and filter | `.searchable` |
| Timeline | `TimelineStrip`, with `TransportCapsule` for play controls |
| Tool palette over a canvas | `ToolbarGroup` |
| Floating readout or transport bar | `GlassPanel` |
| Card in the content layer | `SurfaceCard` (never in an inspector) |
| Empty pane | `EmptyStateView` (`ContentUnavailableView`) |
| Icon | SF Symbols by name (`systemImage:`) |
| Color, type, spacing, radius, size | `SuiteColor`, `SuiteFont`, `SuiteSpacing`, `SuiteRadius`, `SuiteSize` |

Gate: the design lint in `scripts/ci` fails on raw colors, custom fonts,
literal radii, paddings and frame sizes, hand-made blur or materials, and a
`struct` in an app named like a system control (`...Button`, `...Slider`,
`...Toggle`, `...Picker`, `...Stepper`, `...Sidebar`). Raw values live only in
SuiteUI's `Tokens.swift`; glass only in its `Glass.swift`.

## Visual language

The editors should feel like premium Mac tools: dark graphite panels, values
you can read at a glance, controls the right size for a pointer, and color
that always means something. Framework-default sliders, bordered pop-ups and
grey checkbox columns read as unfinished. This section sets the look once,
as tokens and restyled SuiteUI components, so apps never style a control
themselves. It supersedes the older Pro density values; the table in
"What this replaces" at the end lists each change. It applies to every app;
Flare is the first to use all of it (`docs/blueprints/flare.md`).

### Tokens

Every value below lives in `Sources/SuiteUI/Tokens.swift`, as literal hex
per appearance (Light, Dark, and each with Increase Contrast) through
`NSColor(name:dynamicProvider:)`. The ladder steps are written out, never
computed at run time: `Color.mix(with:by:)` mixes in a perceptual space by
default and would not give these values. The design lint fails on a raw
color, font or size anywhere else, so a value that is not here cannot be
used.

**Surfaces and the ladder.** Editors (`EditorShell`) render Dark in both
system appearances, on purpose, so the artwork is the brightest thing on
screen. The Light values serve `SuiteWindow` apps and any editor the captain
later lets follow the system. The ladder is the text color laid over the
panel at fixed amounts (row 5%, card 4%, hover 10%, value fill 7% over the
row, drag fill the accent over the row at 18% Dark and 14% Light); Increase
Contrast doubles the steps.

| Token | Dark | Light | Dark + IC | Light + IC |
|---|---|---|---|---|
| `canvasSurround` | `#18191B` | `#E4E5E8` | `#121314` | `#DCDDE0` |
| `ground` | `#1E1F22` | `#EDEEF0` | `#18191B` | `#F2F2F3` |
| `panel` | `#26272B` | `#F6F6F7` | `#202124` | `#FFFFFF` |
| `card` | `#2F3033` | `#ECECED` | `#323336` | `#EBEBEB` |
| `row` | `#313236` | `#EAEAEB` | `#36373A` | `#E6E6E6` |
| `rowHover` | `#3C3D40` | `#DDDDDE` | `#444547` | `#D6D6D6` |
| `valueFill` | `#3F4044` | `#DADADB` | `#4E4F52` | `#CACACA` |
| `dragFill` | `#2D3E58` | `#CDDAEC` | `#3A485C` | `#C7D3E3` |
| `fieldActive` | `#1B1B1E` | `#FFFFFF` | `#161719` | `#FFFFFF` |
| `hairline` | `#333438` | `#E7E7E8` | `#3B3C3E` | `#E0E0E0` |
| `outline` | `#404144` | `#D8D8D9` | `#636466` | `#B2B2B2` |
| `tick` | `#56575A` | `#C0C0C1` | `#6A6A6C` | `#ABABAB` |
| `marker` | `#9D9EA0` | `#6F6F6F` | `#C7C8C8` | `#404040` |
| `laneBed` | `#2D2D31` | `#EFEFF0` | `#2D2E31` | `#F0F0F0` |
| `accent` | `#1877F2` | `#1877F2` | `#4A94F7` | `#0A5FD0` |

`hairline` goes between bars and panels only, never inside a panel.
`outline` is the 1 pt edge of outlined buttons and presets. `tick` and
`laneBed` are decoration, so they carry no contrast minimum. `rowHover`
against `row` is only 1.18:1 in Dark, so hover is never shown by fill alone:
a bar slider also shows a dotted underline under its value and the pointer
changes. `fieldActive` is darker than the row in Dark (white in Light), so a
field being typed in reads as an inset well, clearly apart from the value
fill (1.66:1 Dark, 1.40:1 Light) and always with the focus ring.

**Text and state colors.** Ratios are WCAG contrast, computed with the same
formula `TokensTests.contrast` uses. Each is the lowest over the panel, card,
row and hover row, and, for the strong state colors, over the color's own
tint. The colors that can sit inside a bar slider (primary and secondary
text, accent text, keyed) are also checked over `valueFill` and `dragFill`,
because the slider's label sits on the left where the fill starts.

| Token | Dark | Light | Dark + IC | Light + IC | min ratio D / L / D+IC / L+IC |
|---|---|---|---|---|---|
| `textPrimary` | `#EDEEF0` | `#1D1D1F` | `#FFFFFF` | `#000000` | 8.92 / 11.89 / 8.19 / 12.81 |
| `textSecondary` | `#B4B8BF` | `#50545C` | `#D2D5DA` | `#3A3D43` | 5.20 / 5.37 / 5.57 / 6.64 |
| `textTertiary` | `#80848C` | `#7C8088` | `#9A9EA6` | `#5E626A` | 3.41 / 3.30 / 4.43 / 4.90 |
| `accentText` | `#8DBDFF` | `#0A4FA6` | `#A8CCFF` | `#08408A` | 5.35 / 5.53 / 4.97 / 6.07 |
| `stateKeyed` | `#F4C542` | `#664900` | `#FFD666` | `#4F3800` | 6.32 / 5.89 / 5.87 / 6.75 |
| `stateSelected` | `#8DBDFF` | `#0A4FA6` | `#A8CCFF` | `#08408A` | 5.50 / 5.77 / 5.83 / 6.85 |
| `stateRecording` | `#FF8A82` | `#A3110B` | `#FFA39C` | `#870E09` | 4.76 / 5.86 / 5.01 / 6.89 |
| `stateSuggested` | `#C4A8FF` | `#5C31B3` | `#D2BCFF` | `#4A2694` | 5.29 / 6.08 / 5.66 / 7.24 |
| `stateWarning` | `#FFA552` | `#7F3E00` | `#FFB673` | `#663100` | 5.51 / 5.97 / 5.57 / 7.21 |
| `stateError` | `#FF8F8F` | `#9E1F1F` | `#FFA3A3` | `#821818` | 4.95 / 5.80 / 5.04 / 6.90 |
| `stateSuccess` | `#3DD68C` | `#105C35` | `#5CE0A0` | `#0B4A2A` | 5.70 / 5.94 / 5.77 / 7.13 |
| `onionBefore` | `#F7A0AD` | `#9A2A40` | `#FAB3BE` | `#7E2134` | 5.44 / 5.57 / 5.60 / 6.71 |
| `onionAfter` | `#4CC9A0` | `#0F5E47` | `#6BD6B2` | `#0B4C39` | 5.26 / 5.70 / 5.43 / 6.86 |

- Every text and state color clears 4.5:1 everywhere it is used, in all four
  appearances. `textTertiary` is for placeholders and disabled text only,
  which WCAG exempts, so it carries no minimum; never put information a
  person needs in it.
- Non-text marks need 3:1. The selection stroke and focus ring (`accent`)
  measure 3.02:1 on a Dark row and 3.52:1 on the Dark panel. The bar slider's
  marker at rest (`marker`) measures 3.86:1 on the Dark value fill. While
  dragging, the marker is white in Dark (10.82:1 on the drag fill) and
  `accentText` in Light (5.53:1), never the plain accent, which measures only
  2.3:1 on the drag fill.
- `accentFill` (`#156BDB`) fills the one primary button and the playhead time
  pill under white text, at 5.05:1. Brand blue `#1877F2` under white text is
  4.23:1, which fails small text. The trade-off is visible: the Export button
  reads a shade deeper than the selection outline and playhead, which stay
  brand blue. (Captain decision 7 in the Flare blueprint.)
- A state's tint is its strong color at 16% over the panel in Dark and 12% in
  Light.

**Radii.** `SuiteRadius.field` 4 (a field inside a row, a swatch inset),
`.small` 6 (top-bar buttons), `.control` 8 (presets, chips), `.medium` 10
(inspector rows, the info card, the action button), `.lane` 12 (timeline
lane beds, clip blocks), `.large` 16 (stage frame, sheets); capsules for
pills, transport, tabs and the keyframe button. Nested shapes step down one
radius so corners stay concentric.

**Spacing and insets** (4 pt grid, 2 pt half-steps):

| Token | Value | Use |
|---|---|---|
| `SuiteSpacing.row` | 6 | Gap between inspector rows |
| `SuiteSpacing.m` | 12 | Row inner padding, panel padding |
| `SuiteSpacing.l` | 16 | Space above a section header |
| `SuiteInset.barButton` | 4 × 8 | Top-bar button padding |
| `SuiteInset.pill` | 2 × 8 | Status pill padding |
| `SuiteInset.card` | 8 × 12 | Info card padding |
| `SuiteSpacing.pillGap` | 4 | Between status pills |
| `SuiteSpacing.markerInset` | 6 | Slider marker inset, top and bottom |

**Sizes.** Visual size first, hit size second. Hit areas are at least 28 pt
where the layout allows and never under 20 pt (the rule in "Symbols and
controls").

| Token | Visual | Hit | Use |
|---|---|---|---|
| `SuiteSize.inspectorBar` | 34 | 34 | Every inspector row, bar slider, dropdown and toggle row |
| `SuiteSize.keyframeButton` | 28 | 28 | Keyframe button (a circle) and the key-here diamond slot beside it |
| `SuiteSize.chip` | 28 | 28 | Chips and timeline toggle chips |
| `SuiteSize.preset` | 24 | 28 | Preset buttons (2 pt hit inset each side) |
| `SuiteSize.actionButton` | 32 | 32 | Full-width outlined action |
| `SuiteSize.pill` | 20 | 24 | Status pills |
| `SuiteSize.transportButton` | 32, play 36 | same | Transport capsule |
| `SuiteSize.swatch` | 24 × 16 | the row | Swatch inside a color row |
| `SuiteSize.selectionHandle` | 8 | 12 | Stage selection handles |
| `SuiteSize.anchor` | 6 | 12 | Pen and direct-select anchors and handle ends |
| `SuiteSize.statusDot` | 6 | – | Unsaved and recording dots |
| `SuiteSize.editorTopBar` | 48 | – | Top bar (was 40) |
| `SuiteSize.editorPanelWidth` | 280 | – | Right panel (unchanged) |
| `SuiteSize.timelineLane` | 32 | 32 | One layer lane (was 28) |
| `SuiteSize.timelineKeyframe` | 10 | 16 | Key diamond |

Symbols take their size from text styles and `.imageScale`, never a point
size: `.imageScale(.small)` in rows and pills, `.medium` in the top bar.

**Type.** System text styles only (SF Pro and SF Mono through the system),
never a custom font or `.system(size:)`. macOS sizes in brackets.

| Token | Style | Use |
|---|---|---|
| `SuiteFont.inspectorTitle` | `.callout.weight(.semibold)` (12) | Inspector title (the file or selection name) |
| `SuiteFont.inspectorLabel` | `.subheadline` (11) | Row labels |
| `SuiteFont.inspectorValue` | `.subheadline.weight(.semibold).monospacedDigit()` (11) | Every value, units included |
| `SuiteFont.inspectorSection` | `.caption2.weight(.semibold)` (10), uppercased, tracking 0.7 | Section headers: TRANSFORM, FILL |
| `SuiteFont.pill` | `.caption2.weight(.semibold).monospacedDigit()` (10) | Pills, chips, preset labels |
| `SuiteFont.editorBar` | `.callout` (12) | Top-bar buttons |
| `SuiteFont.timecode` | `.caption.monospaced()` (10) | Timecode and frame readouts |

Nothing goes below 10 pt.

**Motion.** Hover and state changes fade background, color and border over
0.14 s, ease in and out (`SuiteMotion.state`). Under Reduce Motion they
change at once. No other chrome animates; the artwork is the only thing that
moves.

### State colors

Color always means a state and is never the only cue: each state pairs its
color with a symbol, a shape or a label.

| State | Token | Meaning | Where it shows | Shape cue |
|---|---|---|---|---|
| Selected | `stateSelected` (stroke `accent`) | What the next edit acts on | Stage selection box, selected row, selected key, chosen preset or chip | 1–2 pt outline |
| Keyframed | `stateKeyed` | Animated; a key sits here | Keyframe button, key diamonds, a bar slider's marker and value on a key | Filled diamond |
| Recording | `stateRecording` | Auto-key is on: edits write keys | 2 pt ring round the stage and timeline, dot in the top bar | Dot plus ring (the dot is static under Reduce Motion) |
| AI suggestion | `stateSuggested` | Proposed by Assist, not yet accepted | Proposal rows, suggested keys, preview outline | Hollow diamond (a 1.5 pt outline, no fill) on the timeline; the sparkles symbol on rows |
| Warning | `stateWarning` | Will work, but something is lost or odd | Export warnings, unreachable states, the preview-data and text pills | Triangle symbol |
| Error | `stateError` | Refused or failed; nothing changed | Refusal text, failed save, failed open | Exclamation or xmark symbol |
| Success | `stateSuccess` | Done, and it worked | Export finished, saved | Checkmark symbol |
| Disabled | 40% opacity | Can't act now; the tooltip says why | Any control | No hover, not focusable |
| Dragging | `dragFill`, marker white (Dark) or `accentText` (Light) | A value is changing right now | Bar slider fill, curve handle | Solid marker |
| Onion before | `onionBefore` | A frame before the playhead | Ghosts, the before marker | Left-pointing marker |
| Onion after | `onionAfter` | A frame after the playhead | Ghosts, the after marker | Right-pointing marker |

Some pairs are close for people with color-vision deficiency: recording,
error and onion-before are all reds; selected and suggestion are a blue and
a violet; keyed and warning are a yellow and an orange. The shape cues carry
the difference, which is why the suggestion diamond is hollow (a shape no
other key uses) rather than a dashed edge too small to see at 10 pt.

### Anatomy of the controls

Every control has a keyboard focus ring: 2 pt `accent`, 1 pt outside its
shape, following its radius.

**Bar slider (`InspectorSliderRow`).** The row is the slider; there is no
separate track or knob.

```
╭──────────────────────────────────────────────╮  ◯  ◇
│ Rotation ░░░░░░░░░░░▌ ·    ·    ·        45° │  ⏱  key
╰──────────────────────────────────────────────╯
 label      value fill │ marker  ticks     value   keyframe slots
```

- `inspectorBar` tall, the panel width minus the keyframe slots, radius
  `medium`, background `row`.
- Value fill from the left edge to the value, `valueFill`, clipped by the
  row's radius.
- Value marker: 2 pt wide, inset `markerInset` top and bottom, `marker`.
- Ticks: 6 dots, 2 pt, evenly spaced, never at the ends, `tick`.
- Label: left, `SuiteSpacing.m` in, `inspectorLabel`, `textSecondary`
  (5.20:1 even over the fill and 5.43:1 over the drag fill in Dark).
- Value: right, `SuiteSpacing.m` in, `inspectorValue`, `textPrimary`, units
  in the same string ("1.00×", "45°", "100%", "0.0 pt"). A multi-selection
  with different values shows "Mixed" and no marker.
- States: hover `rowHover` plus a dotted underline under the value;
  dragging `dragFill` and the dragging marker; editing (click the value or
  press Return) swaps the value for a right-aligned field on `fieldActive`
  with the focus ring; keyed here: marker and value in `stateKeyed`;
  disabled 40%.
- Input: press and drag scrubs relative to the current value, one step per
  point, Shift ×10, Option ×0.1 (ScrubField's rules). Click the value to
  type; Return commits, Escape cancels. With focus, ←/→ and ↑/↓ step,
  Shift coarse, Option fine, Home and End jump to the ends. The whole drag
  is one undo step.
- Accessibility: adjustable; the label is the row label and the value is
  spoken with its unit ("45 degrees").

**Keyframe button (`KeyframeButton`).** A `keyframeButton` circle on `row`
with the stopwatch symbol. Idle (`textSecondary`): not animated. Animated:
the symbol filled, `stateKeyed`. Keyed here: a `stateKeyed` tint behind it.
Beside it sits a second slot for the key-here diamond (hollow: add a key at
the playhead; filled: remove it). The slot is always reserved for any
property that can animate, empty while the property is not animated, so the
row never changes width while you scrub the timeline. Hover `rowHover`;
disabled 40%. VoiceOver values: "Not animated", "Animated", "Keyed at this
frame".

**Section header (`InspectorSection`).** `inspectorSection`, uppercase,
`textSecondary`, 16 pt above, 8 pt below. No hairline, no background. The
header still toggles the section (the chevron shows on hover) and still
carries the Reset icon while the section differs from its defaults.

**Inspector title and info card (`InspectorHeader`).** Title: the file or
selection name, `inspectorTitle`, one line, truncated in the middle. Below it
the info card: radius `medium`, `card`, inset `SuiteInset.card`, a
two-column grid with labels left in `textSecondary` and values right in
`inspectorValue` `textPrimary`. Not interactive.

**Dropdown, color and toggle rows.** All share the bar's shape: `inspectorBar`
tall, radius `medium`, `row`, label left in `textSecondary`, hover
`rowHover`.

- Dropdown (`InspectorPickerRow`): the value right-aligned in
  `inspectorValue` with a chevron; it is a real `Menu`, so keyboard and
  VoiceOver work.
- Color (`InspectorColorRow`): a `swatch` capsule with a 1 pt `outline`,
  then the hex value; clicking opens the system color panel. This is the one
  color row: `InspectorColorWellRow` becomes a thin wrapper over it.
- Toggle row: a checkbox (`.toggleStyle(.checkbox)`) with its title, inside
  the filled row. Switches stay out of inspectors.

**Presets, chips and the action button.**

- Preset grid (`PresetGrid`): two equal columns, 4 pt gap, `preset` tall,
  radius `control`, 1 pt `outline`, transparent, label `textSecondary`.
  Hover `rowHover` and `textPrimary`; on: `stateSelected` tint, no outline,
  `textPrimary` semibold. Arrow keys move within the grid.
- Chips (`ChipRow`): `chip` tall, radius `control`, `row`, `pill` type. On: 1
  pt `accent` outline and the `stateSelected` tint. The timeline's toolbar is
  a row of toggle chips.
- Action button (`InspectorAction`): full width, `actionButton` tall, radius
  `medium`, 1 pt `outline` on `row`, a leading symbol and a semibold title,
  centered. Hover `rowHover`; disabled 40%.

**Top bar.** `editorTopBar` tall, `ground`, a `hairline` below. Buttons
(`EditorBarItem`) are outlined at rest: 1 pt `outline`, radius `small`, inset
`barButton`, symbol then the label in `editorBar` `textPrimary`; icon-only
for Undo and Redo. Hover `rowHover`; disabled 40%. One primary
(`EditorBarItem(.primary)`) at the far right: `accentFill`, white symbol and
label, no outline; hover lightens toward `accent`, pressed darkens 8%; it
never turns grey. Save status after the document name: "Saved" in
`textSecondary`, a `statusDot` in `accent` for unsaved changes, "Not saved"
in `stateError` with a triangle.

**Status pills and transport (`ViewerStatusBar`, `TransportCapsule`).**
`ViewerStatusBar` keeps its name and API and now draws its facts as pills:
`pill` tall capsules on `row`, inset `SuiteInset.pill`, `pill` type in
`textSecondary`, right-aligned on the row under the stage, `pillGap` apart.
Toggle pills take the `stateSelected` tint with `accentText` when on;
warning pills take the warning tint, color and triangle. Transport: a `row`
capsule of round icon buttons (`textSecondary`, hover `rowHover`) and a
larger round play button in `accentFill` with a white glyph. Timecode in
`timecode`: the current value `textPrimary`, the total `textSecondary`.

**Tabs and the tool rail.** Segmented tabs (`SegmentedTabs`): a `row`
capsule with 2 pt padding and `chip`-tall pills, labels `textSecondary`; the
selected pill is the `stateSelected` tint with `textPrimary`. It stays a
`Picker` underneath. Tool rail (`ToolbarGroup(style: .rail)`): idle symbols
in `textSecondary`, hover `rowHover`, selected on the `stateSelected` tint
with the symbol in `accentText`.

**Timeline.** Lane bed `laneBed`, radius `lane`, `timelineLane` per layer.
A name chip on the left with eye and lock buttons. Key diamonds: idle
`textSecondary`, selected `accent` with a 1 pt light edge, at the playhead
`stateKeyed`, suggested a hollow `stateSuggested` diamond. A tween segment is
a 2 pt line between keys; an eased segment shows a small curve glyph.
Playhead: a 2 pt `accent` line with a time pill (`accentFill`, white `pill`
text). While recording, a 2 pt `stateRecording` ring frames the timeline.
Clip lanes (Halo) use the same bed with clip blocks at radius `lane`, slate
blue for clips (the accent at 24% into the panel).

**Stage marks.** Selection box: a 1 device pixel `accent` line on the pixel
grid, eight `selectionHandle` squares (white fill, accent edge), and a
rotate zone just outside each corner. Anchors: `anchor` squares for corners
and circles for smooth points; handles as 1 px lines ending in `anchor`
circles. Motion path: a dotted `textSecondary` line with a tick per frame.
Onion ghosts: the artwork at falling opacity, tinted `onionBefore` and
`onionAfter`.

**Layer lists.** Layers and scenes in a panel use `LayerList`, which wraps
the existing `SidebarRow` and `SidebarItem` rows (eye and lock toggles,
rename, children) in a container that works outside a split view. Hidden and
locked rows draw dimmed, implemented once in `SidebarRow` (#146). There is
no second row component.

### How it stays Apple

- **Type:** SF through system text styles, monospaced digits for every
  number, nothing under 10 pt.
- **Targets:** the 4 pt grid; hit areas at least 28 pt where the layout
  allows, never under 20 pt, with the hit size in the token table.
- **Menus and shortcuts:** every command is in the menu bar in the standard
  order with standard shortcuts; the top bar only repeats them.
- **Focus:** full keyboard access; Tab moves through panel rows; the focus
  ring follows each shape. Canvas tools keep their one-key shortcuts while
  the canvas has focus.
- **Accessibility:** every control has a label and, where it holds a value,
  an adjustable value with units. Color is never alone. Differentiate
  Without Color adds the shape cues on the stage too.
- **Reduce Motion:** state fades become instant, the recording dot stops,
  the curve editor's preview dot stops.
- **Increase Contrast:** the Dark + IC and Light + IC columns above: the
  ladder steps double, `outline` goes to 30%, secondary text moves toward
  primary, and the state colors brighten (Dark) or deepen (Light).
- **Reduce Transparency:** the floating glass palette becomes solid
  `ground`.
- **Materials:** glass only on controls that float over the artwork (the
  floating tool palette, a HUD). Panels, bars and rows are flat; no glass on
  glass.
- **Goldens:** SuiteUI components are recorded in all four appearances;
  editor screens in Dark and Dark + Increase Contrast, since editors render
  Dark; `SuiteWindow` app screens in Light, Dark and both with Increase
  Contrast.

### What this replaces

| Rule today | Becomes | Why |
|---|---|---|
| Color, type, spacing: "Semantic colors only … never hard-code a hex value for a system role", and the `Tokens.swift` header saying the same | Panels, rows, text and states are fixed graphite hex values per appearance in `Tokens.swift`, with Increase Contrast values; the hex lives only there | System greys can't give the filled-row look or a contrast table we can test; fixed values per appearance can, and Increase Contrast is still covered by its own column |
| Component order: "A value in a range → `Slider`; exact numbers: `ScrubField` (plus `Stepper`)" | In an inspector, the bar slider (`InspectorSliderRow`); elsewhere `Slider`. Exact coordinates (X, Y, W, H) stay `ScrubField`; no `Stepper` in inspectors | The default slider and stepper are the biggest "unfinished" tell. The bar slider keeps keyboard stepping, typing, VoiceOver adjust and one undo per drag, so behavior parity holds |
| Component order: "Never a hand-rolled look-alike" | Unchanged for apps. SuiteUI's bar slider and keyframe button are the sanctioned replacements, built once with the system behaviors | Apps still can't draw their own |
| Pro density row height 22 pt, no gap | 34 pt rows, 6 pt gaps | A pointer-sized, readable row |
| Labels right-aligned in an 88 pt column | The label inside the row on the left, the value on the right | The reference look; no column to align |
| One hairline above each section; no borders, rounded cards or shadows inside an inspector | No hairlines inside panels; rows, the info card and chips are filled rounded shapes; presets and actions are outlined; still no shadows | Structure from fills, not lines |
| One accent | One accent for selection and focus, plus the state colors, each with a shape cue | States need names, not just "selected" |
| Grey ramp mixed from system colors, no near-black fills | The graphite ladder above (literal hex per appearance) | As above |
| Accent text `#1260C9` Light, `#5A9DF6` Dark | `accentText` `#0A4FA6` Light, `#8DBDFF` Dark | The new rows and fills need 4.5:1 over the value and drag fills too |
| Every number is a ScrubField | Slider-like numbers are bar sliders; exact coordinates stay ScrubFields | As above |
| Viewer status line: a 22 pt flat band | Status pills under the stage, same `ViewerStatusBar` API | The reference look; no new component |
| Editor top bar 40 pt, flat accessory buttons | 48 pt, outlined buttons and one filled primary | As above |

Kept as is: `.small` control size, checkboxes not switches (the design lint
enforces it), monospaced numbers, glass placement, one prominent action per
toolbar.

## Pro density

Inspectors, panels and viewer chrome follow the dense layout of professional
Mac editors, not the airy layout of a phone or tablet app. The canvas is the
loud part; the chrome around it is small, grey and exact. Values live in
`Tokens.swift` and the SuiteUI components below; the type scale and grey
ladder match the Ripple tokens.

| Rule | Value |
|---|---|
| Control size | `.small` (`SuiteSize.compactControl`), set once by `InspectorRow` and `ViewerStatusBar`. Never `.regular` or `.large` in an inspector. |
| Type | The Visual language type tokens: 11 pt labels and semibold values, 10 pt uppercase section headers, 12 pt semibold title. System text styles, never `.system(size:)`. Every number uses `.monospacedDigit()`. |
| Rows | 34 pt filled rounded rows (`SuiteSize.inspectorBar`, `row`), 6 pt apart (`SuiteSpacing.row`). |
| Labels | Inside the row on the left in `textSecondary`; the value on the right in `textPrimary`. No label column. |
| Surfaces | The graphite ladder in Visual language: `panel`, `card`, `row`, `rowHover`, `valueFill`, `fieldActive`, with Light, Dark and Increase Contrast values. |
| Separators | Hairlines only between bars and panels. Inside a panel, structure comes from filled rows and the info card; presets and actions are outlined. No drop shadows. |
| Accent | One accent, brand blue #1877F2 (`SuiteColor.accent`), for selection, focus, the active tool and the playhead. Accent text uses `SuiteColor.accentText` (#0A4FA6 Light, #8DBDFF Dark). The primary button fill is `accentFill` (#156BDB). States use the state colors, each with its shape cue. |

**The inspector pattern.** From the top: an `InspectorHeader` (the
selection's name, then the info card of facts such as size, frame or keys),
then `InspectorSection`s. A section is an uppercase header (the whole header
toggles it) and its filled rows. Every row is an `InspectorRow`: label left,
value right, inside the row. Use the ready rows
(`InspectorSliderRow`, `InspectorStepperRow`, `InspectorColorRow`,
`InspectorPickerRow`) where they fit. With nothing selected the inspector
says so (`EmptyStateView`).

**Checkbox, not switch.** On/off in an inspector is a `Toggle` with
`.toggleStyle(.checkbox)`, its title beside the box inside the filled row
(pass `""` as the row label). A section's enable box sits in its first row. Switches
are for settings that act at once on a whole mode, never for a property.
Gate: the design lint fails on a `Toggle` without the checkbox style in any
app file named `*Inspector*` or using an `Inspector…Row`.

**Scrub fields.** Slider-like numbers in an inspector are bar sliders
(Visual language); exact coordinates (X, Y, W, H) are `ScrubField`s: the
value right-aligned in monospaced digits on the row, the unit after it. Both
share these rules.

- Drag sideways to change it: one step per point, Shift for ten steps, Option
  for a tenth. Changing a key mid-drag continues from the current value. The
  pointer is the column-resize cursor.
- Click to type an exact value; Return or clicking away commits, Escape
  cancels. Typed text that isn't a number keeps the old value.
- With keyboard focus, Up and Down arrows nudge by one step; VoiceOver can
  adjust it the same way.
- Values always arrive clamped to the range and snapped to the step
  (`ScrubValue`); the Model clamps again. A field without a step uses the
  largest power of ten not above a hundredth of its range.

**Viewer chrome.** A canvas or viewer ends in a `ViewerStatusBar`: the zoom
percent (`ViewerZoom.percentText`, from `ViewerZoom.fitScale` while the
canvas fits the window), the document size, and a trailing slot for a View
menu, timecode or a selection count. It draws its facts as status pills on
the row under the canvas, with no band. A bare canvas with no readout is not finished.

**Where glass goes.** Only on the outer window chrome (toolbar, sidebar and
inspector columns, which the system draws) and on the floating tool palette
or transport over the canvas (`ToolbarGroup`, `GlassPanel`). Never inside an
inspector, on a section, a header band, a field, the status line or any panel
of settings. Those are flat fills from the graphite ladder.

```
[ ] 34 pt filled rows, 6 pt gaps, label left, value right in semibold tabular digits
[ ] Section headers small, uppercase, tracked; no hairlines inside panels
[ ] Every animatable property has a keyframe button; keyed values show in the keyed color
[ ] States use the state colors with their shape cue; nothing is color-only
[ ] Checkboxes, not switches; exact coordinates are ScrubFields, other numbers bar sliders
[ ] Inspector starts with the title and info card; the canvas ends in status pills
[ ] Fills from the graphite ladder; one accent; glass only on the outer chrome and palettes
[ ] Goldens in every appearance the Visual language section names
```

## Editor shell

A canvas editor may use `EditorShell` instead of `SuiteWindow`. It is the
layout of our Studio photo editor (Ripple's editor parts), rebuilt as native
SwiftUI in SuiteUI. Photo and Design use it.

| Region | Component | Rules |
|---|---|---|
| Top bar | `EditorTopBar`, `EditorBarItem`, `EditorBarMenu`, `EditorBarDivider` | 48 pt. The app name, then the document name as a menu. Outlined icon-and-label commands and one filled primary (Export); undo and redo as icons; the save status. Every command here is also in the menu bar. |
| Tool rail | `ToolbarGroup(style: .rail)` | Docked, flat, vertical. The selected tool sits on an accent well. Tooltips name the one-key shortcut ("Brush (B)"), which works while the canvas has focus. |
| Canvas | `CanvasViewport`, `SelectionOutline`, `CropShade` | Rulers in document pixels along the top and left, a checkerboard behind the image, centered while it fits, scrolling with a 32 pt margin once it doesn't. Drags arrive in document pixels. With the canvas focused, a drag that starts with Space held pans it (grab pointer) instead of reaching the tool, and an arrow key the app doesn't use pans a tenth of the view (Shift: a whole view), never past the scrollable area. The image is clipped to the artboard; selection marks and handles in the overlay are not, so they show past its edge. |
| Right panel | `SegmentedTabs`, then `InspectorSection`s | 280 pt, the tabs (Adjust, Layers) on top. A section's Reset icon shows only while the section differs from its defaults. A color is `InspectorColorRow`: the swatch plus its hex code, opening the system color panel. |
| Status line | `ViewerStatusBar` | Status pills: zoom, document size, and the trailing slot for the render time. |
| Timeline (optional) | `EditorShell(timeline:)`, `TimelineStrip`, `TransportCapsule` | A resizable, collapsible bottom slot. |

- **Dark in both appearances, on purpose.** The shell sets the dark scheme on
  its window, like the Studio editor, so the image is the brightest thing on
  screen. Colors come from the graphite ladder in Visual language (`ground`
  for bars, `panel` for panels, `canvasSurround` around the image), which
  resolve to their Dark values.
- **Hidden title bar.** The scene uses `.windowStyle(.hiddenTitleBar)`; the top
  bar leaves `SuiteSize.windowControlsInset` for the window's buttons and drags
  the window from its empty stretches. Still set `.navigationTitle` to the
  document name for the Window menu.
- **No glass inside.** Bars, rail, rulers and panel are flat bands with
  hairlines between them.
- **Numbers show their field's precision:** whole for percent and degrees, one
  decimal for pixels and EV (`decimals:` on `ScrubField` and the slider row).
- **Fits the window minimum.** Rail, content minimum and panel add up to no
  more than `SuiteSize.windowMinimum` (TokensTests checks it).

## Studio rows and chips

Every inspector in the suite uses the Studio look of Flare's easing editor:
rounded, filled controls instead of the Pro density rows. The bar slider,
`InspectorRow` and the rows built on it, section headers and preset chips
all draw as this table says; where Visual language gives them another size,
radius or fill (34 pt bars, 6 pt gaps, outlined presets), this section wins.
They are flat controls, never glass, and their rounding is a deliberate
exception to "no rounded cards inside an inspector".

| Part | Component | Rules |
|---|---|---|
| Group header | `Text` in `SuiteFont.sectionCaps`, `.textCase(.uppercase)`, `.tracking(SuiteSize.capsTracking)` | Secondary color; 12 pt above, 4 pt below. |
| Number row | `StudioScrubRow` | The bar slider (`InspectorSliderRow`) showing two decimals: 28 pt, full width, radius `SuiteRadius.row`. Label inside on the left, value right in tabular figures. The fill runs to the value over five faint ticks; the marker turns accent while dragged. Drag, click to type, arrows step, Home and End. |
| Presets | `ChoiceChips`, `PresetGrid`, `ChipRow` | 24 pt filled chips (`ChipRow`'s toggle chips 28 pt), radius `SuiteRadius.row`, secondary text. `ChoiceChips` is `PresetGrid` in three columns. One on at most in a grid: the selected well plus a 1 pt accent border, primary text. |
| Curve | `CurveEditor` | 180 pt well. Handles are 10 pt with a 28 pt hit target; the focused or dragged one is accent with a ring 2 pt out. Arrow keys nudge 0.01, Shift 0.1; Tab moves between handles; a drag focuses the handle it moved. |

Color carries meaning only: accent is selected or active, `SuiteColor.keyframed`
(amber) is a keyframe. Each drag, nudge or typed value ends in one `onEnd`, so
the host makes it one undo step.

## Layers: content vs. control

For every screen, name what is content and what is control before you build.

- **Content** (the document, canvas, artboard, photo grid, timeline tracks,
  cards, the app background): no glass. Use flat fills and, when you need
  structure, the standard materials (blur, vibrancy) through a SuiteUI
  component; apps never apply a material themselves.
- **Control** (toolbars, sidebars, inspectors, floating palettes, popovers,
  sheets, menus): system components, which bring their own glass.
- **No glass on glass.** Never put a glass view inside another glass view or
  over system glass. Group related custom glass controls into one glass shape
  (`ToolbarGroup` puts its whole group in one capsule), or into one
  `GlassEffectContainer` when they must stay separate shapes.
- **Use custom glass sparingly.** Only the few most important floating
  controls. Regular glass for anything with text; the clear variant only over
  photos or video, with a dark dim behind it if the media is bright.
- **Let content run under the chrome.** Don't give toolbars or sidebars an
  opaque or tinted background; content scrolls beneath them.
- **Use the system APIs**: `.glassEffect`, `GlassEffectContainer`,
  `.buttonStyle(.glass)` / `.glassProminent`, the standard materials. Never a
  hand-made blur.

## Window structure

- One `WindowGroup` (or `DocumentGroup` once files open and save) per app,
  showing `SuiteWindow` (a canvas editor may show `EditorShell` instead; see
  Editor shell): a `NavigationSplitView` with the sidebar on the leading
  edge, the content in the middle and an inspector on the trailing edge.
- **Title** names the open document, not the app. Show the app name only when
  nothing is open.
- **Sidebar**: top-level places or the document's structure (scenes, pages,
  layers, collections, compositions). At most two levels; SF Symbol per row;
  row height follows the system setting. Nothing critical at its bottom.
- **Inspector**: properties of the current selection only. Simple controls
  (fields, sliders, steppers, pop-ups, color wells), no deep navigation. The
  user can hide it from the toolbar and with Option-Command-I. With nothing
  selected it says so ("No Selection").
- Windows resize freely; set sensible minimums. Nothing critical along the
  bottom edge of a window, which is often off-screen.
- Settings go in a `Settings` scene (Command-comma), with few options and good
  defaults. Task options belong in the inspector, not in Settings.

## Canvas apps (Flare, Design, Photo, Halo)

| Region | Layer | Treatment |
|---|---|---|
| Canvas surround and artboard | content | Flat. Neutral surround so artwork color reads true; the artboard centered and scaled to fit (`CanvasSurface`). |
| Tool palette | control | One compact glass group of SF Symbol buttons on the canvas edge (`ToolbarGroup`). The active tool uses the filled symbol and the accent color. Each tool has a tooltip and a single-key shortcut when the canvas has focus. |
| Inspector | control | Trailing pane, selection properties only. |
| Timeline | control frame, content tracks | The bar and transport controls are controls; keyframes and tracks are content with no glass. |
| Toolbar | control | Document title, the few most-used commands, the inspector toggle. One prominent action at most (Export). |

- No modal dialog for an adjustment that needs a live preview; use the
  inspector or a panel.
- Precision input: arrow keys nudge, Shift-arrow nudges more, Shift constrains,
  Option-drag duplicates, Space-drag pans.
- Every canvas edit is undoable with a named action ("Undo Move Layer").
  Scrubbing and playback are not undo steps.
- Full screen keeps the essential tools reachable; hiding chrome for focus is
  fine if hovering brings it back.

## Commands

- **Every command is in the menu bar.** People learn a Mac app by its menus,
  and they can hide the toolbar. Toolbar buttons and context menus are extra
  routes, never the only one.
- Standard menus in the standard order: App, File, Edit, View, app menus
  (Object, Animate, Image, ...), Window, Help. Disable unavailable items rather
  than hiding them. Toggle items say what they will do ("Hide Inspector").
- Keep the standard shortcuts on their standard commands (New, Open, Save,
  Undo, Redo, Copy, Paste, Select All, Find, Settings, Close, Quit). Add custom
  shortcuts only for the most frequent app commands.
- Export lives at File > Export, opening a sheet on the document window.

## Color, type, spacing

- **Token colors only** (`SuiteColor`). Panels, rows, text and state colors
  are the fixed graphite values of Visual language, one per appearance
  including Increase Contrast, and they live only in `Tokens.swift`. Never
  write a hex value anywhere else. Document content (an artboard, a swatch)
  is the exception.
- Never carry meaning with color alone; pair it with a symbol, a shape or a
  label. Text contrast at least 4.5:1 (3:1 for large or bold text).
- **System text styles** (`SuiteFont`): macOS body is 13 pt; inspectors and
  viewer chrome use 11 pt (Pro density); don't go under 10 pt. Build hierarchy with weight and color, not many sizes. No light or
  thin weights at small sizes. Monospaced digits for timecode and counters.
- **Spacing on the 4-point grid** (`SuiteSpacing`). Corners nest concentric:
  an inner shape uses the next smaller radius (`SuiteRadius`). Fixed sizes
  (window minimums, column widths, palette buttons) come from `SuiteSize`.
- Follow the system's Light/Dark setting; no in-app appearance switch. A
  fixed dark canvas surround is allowed for a media app if chosen on purpose,
  but standard controls still follow the system.

## Symbols and controls

- SF Symbols for every standard action, with the standard symbol (plus for
  add, trash for delete, square-and-arrow-up for share). Outline in toolbars
  and lists, filled for the selected state.
- Every icon-only control has a tooltip (`.help`) and an accessibility label.
- Hit targets at least 28x28 points (20x20 minimum).
- Buttons say what they do with a verb ("Export", "New Animation"). Title case
  for menu items and buttons. An ellipsis when more input follows ("Export…").

## Empty states and messages

- An empty pane says what goes there and how to get started, and offers the
  button that does it as the one prominent action (`EmptyStateView`).
- Errors appear near the problem, say how to fix it, and don't blame anyone.
  Alerts only for destructive or critical cases; never at launch.

## Motion and accessibility

- Every animation has a job (feedback, orientation, status), is short, and
  never blocks input. Under Reduce Motion, fade instead of slide.
- Check each screen with Increase Contrast and Reduce Transparency on; glass
  changes under both.
- Everything works from the keyboard (Full Keyboard Access, a sensible focus
  order, Escape and Command-period cancel).

## Review checklist

Walk this against the snapshots (Light and Dark) before you open a UI PR, fix
what fails, and walk it again.

```
[ ] Content vs control named; no glass on content; no glass on glass
[ ] Content runs under the chrome; no custom bar backgrounds
[ ] System components and SuiteUI used where one exists
[ ] At most one prominent action per view; never a destructive one
[ ] SuiteColor / SuiteFont / SuiteSpacing only; Light and Dark both right
[ ] Every state shown uses its state color and shape cue (Visual language)
[ ] Every icon-only control has a tooltip and an accessibility label
[ ] Every shown button, tool and menu item acts, or is disabled saying why
[ ] Every new command is (or has an issue to be) in the menu bar
[ ] Edits are undoable with named actions
[ ] Empty states say what to do next
```
