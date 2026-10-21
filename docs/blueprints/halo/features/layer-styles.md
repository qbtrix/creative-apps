# Feature packet: layer-styles (Halo)

**Feature:** layer styles on Halo's layers, keyable where Halo's keys reach.
Layer > Layer Style… (and the Layers panel's `fx` button and row menu, once
they land) opens SuiteUI's `LayerStylePanel` on the selected layer; the
frame renderer draws the style on every frame, in the viewer and in a render.
The drop shadow's distance, size and opacity and the outer glow's size and
opacity are Halo properties with stopwatches in the inspector, so they take
keys and ease like position and opacity. Everything else in a style is
static over time.
**Line:** `line:halo` · **Wave:** W5 (`waves.md`) · **Lead branch:** `lead/layer-styles`
**Beta:** captain, 2026-10-21. Labels `beta` and `p1` when filed.

**Covers:** feature map S2's Halo adopter (`halo/layer-styles`); real job
RJ-H43 (new). RJ-H17 (blur and glow) stays open: its blur is Halo's effects
stack (#39), not a layer style.

**Depends on:** `suiteui/layer-styles` **LS-a** (cross-line: the model,
`LayerStyleTarget`, the specs, the panel stub); HY-5 needs **LS-m**, HY-6
**LS-m**'s `StyleProgram`, HY-7 **LS-gpu**; suite-imaging **IM-a** (IM-1
links SuiteImaging into HaloModel). Same line: `placed-images` (PH-a, PH-u
and PH-m own `HaloLayer.swift`, `HaloLayerInspector.swift` and
`LiveFrameRendering.swift` first, after stroke-style's `HaloValues.swift`
edit) and `file-flow` **HF-m** (the catalog and `Tests/command-ids/halo.txt`)
and **HF-z** (`halo.md`).

**Rule 20.** No Halo style type, renderer or key engine. `HaloLayer.style` is
SuiteImaging's `LayerStyle`; `HaloStyle+Kernel.swift` is the adapter; the
pixels are `StyleProgram`'s; the five keyable numbers are `HaloProperty`
cases, so the kernel's `Keys` and Halo's existing keying and easing animate
them with no new key code. Colour keys wait on creative-core's colour keys
(animate-properties).

**Render path.** `LiveFrameRendering` composites a styled layer as
`StyleProgram.render` of its own raster at the frame (padded), with the five
keyed numbers sampled at the frame first. The viewer's live frame uses
`StyleRoute` on macOS (HY-7); a render to a movie or PNG runs the CPU path, so
the viewer and the render share one rule.

Blueprint sections: halo.md (Layers, Inspector, Render).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HY-a | Layers hold a `LayerStyle`, the five style properties exist, the `style.*` commands are in Halo's catalog on stubs, and Layer > Layer Style… opens the panel. | HY-1, HY-2 | MJ-HY | placed-images; file-flow:HF-m (HY-1); suiteui layer-styles LS-a (cross-line) |
| HY-u | The inspector shows the style properties with stopwatches for a styled layer, with snapshots, a render budget and the journey written. | HY-3, HY-4 | HJ-Y1 | HY-a |
| HY-m | Every style command is one undo step, the five properties key and ease, and the frame renderer draws styles with keyed values at each frame. | HY-5, HY-6 | MJ-HY | HY-a; LS-m (cross-line) |
| HY-z | The viewer draws styles through the live route, the journey passes on live, and halo.md lists the feature as built. | HY-7, HY-8 | HJ-Y1 | HY-u, HY-m; file-flow:HF-z (HY-8); LS-gpu (HY-7, cross-line) |

HY-u waits only on HY-a (rule 18); HY-m never waits on HY-u. MJ-HY is
`HaloLayerStyleTests` and `HaloStyleRenderTests` on Linux.

## Journey steps

1. Open `shapes`, select the title (HY-2,
   `HaloLayerStyleJourneyTests.testKeyedGlow`), Layer > Layer Style…, turn
   on Outer Glow: the viewer shows the glow.
2. In the inspector, Glow Size has a stopwatch (HY-3); at frame 0 set it to 0
   and turn the stopwatch on; at frame 30 set 20: two keys on the timeline.
3. Scrub the playhead: the glow grows from nothing to 20 px.
4. Render frames 0 and 30 as PNG: frame 0 has no glow, frame 30 does.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H43 | adds, closes with S2 | Cm | `Tests/RealJobs/halo/keyed-glow/keyed-glow.jobs.json`: `style.add` outer glow on the title, `key.set` Glow Size 0 at frame 0 and 20 at frame 30 (key-editing's commands), `render.frame` 0, 15 and 30 as PNG | `input/title.halo` |

Trap: the glow is baked into the layer (one size for every frame), or the
keys are ignored in the render though the viewer shows them. Assertion: the
glow's reach past the title is 0 at frame 0, 20 ± 1 px at frame 30, and
strictly between at frame 15 (the easing's value within 1 px). Mutation:
`HaloModel.LiveFrameRendering.json` (style drawn from the base value, not
the frame's → `.keyedStyleFollowsFrame`). `Cm` because Halo's text raster is
CoreText on macOS.

## Screens and states

`halo-layer-style-panel` (Outer Glow), `halo-style-keys` (the inspector's
style rows with stopwatches and the timeline's keys), `halo-glow-frame`
(light and dark).

## Contract slice

```swift
// Sources/HaloModel/HaloLayer.swift (HY-1): nil for none, so old projects open and re-save unchanged
public var style: LayerStyle?
// Sources/HaloModel/Contracts/HaloValues.swift (HY-1)
public enum HaloProperty { ...; case shadowDistance, shadowSize, shadowOpacity, glowSize, glowOpacity }
// rows show only for a layer whose style has that effect; values read from and write to the style when not keyed
// Sources/HaloModel/HaloStyle+Kernel.swift (HY-1 stubs, HY-5 bodies)
extension HaloProject: LayerStyleTarget { ... }
```

`HaloCommandCatalog` adds `+ StyleCommands.specs(HaloProject.self)`;
`Tests/command-ids/halo.txt` gains the eleven ids.

## Pseudocode

- **Keyed values.** At frame f, a style property with keys takes its sampled
  value (Halo's keying and easing, as for opacity); without keys, the
  style's own value. `setValue` on an unkeyed style property writes the style
  (one step); on a keyed one it sets the key at f.
- **Rows.** `rows(for:)` lists the five only when the layer's style has an
  enabled drop shadow (three) or outer glow (two); removing the effect keeps
  its keys in the file (restored if the effect comes back).
- **Render.** For each styled item: its raster as today, then
  `StyleProgram.render(style at f, layer:, scale:)`, composited at the padded
  origin with the item's blend and opacity.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HY-1 | – | `HaloLayer.style`; the five properties; the adapter as stubs; the specs and ids; `HaloLayerStyleTests` written, disabled | `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/Contracts/HaloValues.swift`, `Sources/HaloModel/HaloStyle+Kernel.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloLayerStyleTests.swift` | LS-a | ~280, 6 |
| HY-2 | – | Layer menu items (Layer Style…, Copy, Paste, Clear Layer Style) by id; the panel as a sheet while `stylePanel` is set | `Sources/HaloApp/HaloCommands.swift`, `Sources/HaloApp/HaloWindow+Styling.swift`, `Sources/HaloApp/HaloWindow.swift` | HY-1 | ~160, 3 |
| HY-3 | – | The inspector's style rows with stopwatches | `Sources/HaloApp/HaloLayerInspector.swift`, `Tests/AppSnapshotTests/HaloLayerStyleSnapshots.swift` | HY-2 | ~160, 2 |
| HY-4 | – | The render budget test; the journey written and skipped (`XCTSkip("waits on HY-7")`) | `Tests/AppSnapshotTests/RenderBudgetHaloLayerStyleTests.swift`, `UITests/HaloJourneyTests+LayerStyle.swift` | HY-3 | ~180, 2 |
| HY-5 | – | The adapter's bodies; the five properties' read, write and rows; turns on `HaloLayerStyleTests` | `Sources/HaloModel/HaloStyle+Kernel.swift`, `Tests/HaloModelTests/HaloLayerStyleTests.swift`, `Tests/mutations/HaloModel.HaloStyle+Kernel.json` | HY-1, LS-m | ~300, 3 |
| HY-6 | – | The frame renderer draws styles with keyed values; `HaloStyleRenderTests`; RJ-H43's job folder | `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Tests/HaloModelTests/HaloStyleRenderTests.swift`, `Tests/mutations/HaloModel.LiveFrameRendering.json`, `Tests/RealJobs/halo/keyed-glow/keyed-glow.jobs.json`, `Tests/RealJobs/halo/keyed-glow/input/title.halo` | HY-5 | ~300, 5 |
| HY-7 | – | The viewer's live frame through `StyleRoute`; the journey turned on | `Sources/HaloApp/HaloViewerCanvas.swift`, `UITests/HaloJourneyTests+LayerStyle.swift` | HY-4, HY-6, LS-gpu | ~140, 2 |
| HY-8 | – | halo.md: layer styles in Layers and Inspector; `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/layer-styles.wave.json` | HY-7 | ~20, 2 |

## Build waves

- Wave 1: HY-1. Independent in this wave: HY-1 alone.
- Wave 2: HY-2, HY-5. Independent in this wave: both.
- Wave 3: HY-3, HY-6. Independent in this wave: both.
- Wave 4: HY-4. Independent in this wave: HY-4 alone.
- Wave 5: HY-7. Independent in this wave: HY-7 alone.
- Wave 6: HY-8 (shared prose, `feature-done`, final). Independent in this wave: HY-8 alone.

Longest chain: HY-1 → HY-2 → HY-3 → HY-4 → HY-7 → HY-8 (6). Chain of 6:
the sheet needs the ids, the inspector rows sit beside the sheet, the budget
and journey time the rows, HY-7 turns the journey on live, HY-8 is the prose
task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HY-1 | `HaloLayerStyleTests` compiles, disabled; the command-id list matches the catalog; an old project re-saves byte for byte | an id is missing or an old file changes | – (stub) |
| HY-2 | `HaloLayerStyleSnapshots.panel` (HY-3's, first in the slice PR) | the sheet or a menu item is missing | – (UI) |
| HY-3 | `HaloLayerStyleSnapshots.styleRows`: Glow Size shows with a stopwatch only on a layer with an outer glow | a row shows without its effect | – (UI) |
| HY-4 | `RenderBudgetHaloLayerStyleTests.glowScrubInThreeBodies`; the journey compiles, skipped | budget over | – (UI) |
| HY-5 | `HaloLayerStyleTests`: setting Glow Size unkeyed writes the style in one step; keyed, it sets a key at the playhead; the rows follow the effects; keys survive removing and re-adding the glow | a value goes to the wrong place | `HaloModel.HaloStyle+Kernel`: keyed write goes to the style → `.keyedWritesAKey`; rows shown without the effect → `.rowsFollowEffects` |
| HY-6 | `HaloStyleRenderTests`: a glow keyed 0 to 20 over 30 frames reaches 0, about 10 and 20 px at 0, 15, 30; an unkeyed shadow is the same on every frame; RJ-H43 passes in the `Cm` group | a frame draws the base value or the style is clipped | `HaloModel.LiveFrameRendering`: base value used → `.keyedStyleFollowsFrame`; no padding → `.glowIsNotClipped` |
| HY-7 | `HaloLayerStyleJourneyTests.testKeyedGlow` steps 1 to 4 | a step fails | – (route call) |
| HY-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Glow Size scrub in the inspector | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHaloLayerStyleTests.glowScrubInThreeBodies` |
| Playback with a styled 1080p layer | 30 fps held on the GPU route (reported) | `RenderBudgetHaloLayerStyleTests.playStyled` |
| One gesture, one step | a scrub is one step, keyed or not | `HaloLayerStyleTests` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HY-m merged-done on the Linux job with
`Mutate:` clean, RJ-H43 green in the scoped run; HY-a and HY-u through the
feel gate with `Mac-Finish:`; HY-z's journey on live. Then
`Belt-Contact-Sheet:` with `halo-layer-style-*` and `halo-glow-frame-*`.

## Not in this packet

Keys on style colours, angles and the other effects' numbers, styles on
nulls and precomps, Halo's effects stack (#39: blur, fill, levels).
