# Feature packet: layer-styles (Photo)

**Feature:** layer styles on Photo's pixel and text layers (`photo/text-layers` adds `PhotoLayerKind.text`; the style is a `PhotoLayer` field, so a text layer takes it with no extra code, its glyph raster styled like any pixels). Layer > Layer Style… (and
the Layers panel's `fx` button and row menu, once they land) opens SuiteUI's
`LayerStylePanel` on the selected layer; drop shadow, inner shadow, glows,
stroke, colour and gradient overlays and bevel and emboss draw live on the
canvas, never touch the layer's pixels, save in the `.ora`, export in every
format and undo as one step each. Copy, Paste and Clear Layer Style work on
the selection. An agent runs the same `style.*` commands from the CLI.
**Line:** `line:photo` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/layer-styles`
**Beta:** captain, 2026-10-21 (photo.md had layer styles as Tier 3, out of
v2). Labels `beta` and `p1` when filed.

**Covers:** feature map S2's Photo adopter (`photo/layer-styles`); real jobs
RJ-P44 (new) and RJ-X51's check (the shared packet's job, run on Photo).

**Depends on:** `suiteui/layer-styles` **LS-a** (cross-line: the model,
`LayerStyleTarget`, the specs, the panel stub); PY-5 needs **LS-m** (the real
rules and commands), PY-6 **LS-m**'s `StyleProgram`, PY-7 **LS-gpu** (the
route). Same line: `multi-layer-select` (its PM-g owns `PhotoLayer.swift`,
`PhotoLayerComposite.swift`, `PhotoCommands+Layer.swift` and
`PhotoDocumentFile.swift` before this packet) and `file-flow` **PF-m** (the
last owner of `PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt`).

**Hand-offs:** PY-7 edits `PhotoRenderRoute.swift`, which suite-imaging's
IM-photo also lists (cross-line); PY-7 starts after IM-photo's
`Belt-Slice-Done:`. The Layers panel's action bar and row menu are SuiteUI's (merged), but
Photo builds its own items in `PhotoLayerList.swift`: PY-2 moves its `fx`
button off the disabled `LayerActionBar.effects(identifier:)` placeholder onto
the `style.panel` spec, and SuiteUI's LS-13 then deletes the placeholder
(#5327).

**Rule 20.** No Photo style type, panel, pasteboard code or renderer.
`PhotoLayer.style` is SuiteImaging's `LayerStyle`; `PhotoStyle+Kernel.swift` is
the adapter (`check-dup-logic` allows the suffix); the pixels come from
`StyleProgram` (CPU) and `StyleRoute` (GPU); copy and paste go through
`LayerStylePasteboard`.

**Render path.** `PhotoLayerComposite`, the per-layer hook every render calls,
draws a styled layer as `StyleProgram.render` (padded by `StyleRules.reach`)
for export, thumbnails and headless runs. The live canvas sends the same style
as one `.style` op through `StyleRoute` on the resident layer, so a slider
step redraws nothing else. Adjustment layers take no style.

Blueprint sections: photo.md 4 (Layers), 6 (inspector), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PY-a | Image layers hold a `LayerStyle`, the `style.*` commands are in Photo's catalog on stubs, and Layer > Layer Style… opens the panel on the selected layer. | PY-1, PY-2 | MJ-PY | multi-layer-select; file-flow:PF-m (PY-1); suiteui layer-styles LS-a (cross-line) |
| PY-u | The panel over the canvas has snapshots, a render budget and its journey written. | PY-3, PY-4 | PJ-Y1 | PY-a |
| PY-m | Every style command sets each selected image layer's style as one undo step and refuses adjustment layers, the composite draws styles padded on the CPU, and the `.ora` keeps them. | PY-5, PY-6 | MJ-PY | PY-a; LS-m (cross-line) |
| PY-z | The canvas draws styles live through the shared route, the journey passes on live, and photo.md lists the feature as built. | PY-7, PY-8 | PJ-Y1 | PY-u, PY-m; text-layers:TX-z (PY-8, the last earlier owner of `photo.md`); LS-gpu and IM-photo (PY-7, cross-line) |

PY-u waits only on PY-a (rule 18); PY-m never waits on PY-u. MJ-PY is
`PhotoLayerStyleTests` and `PhotoStyleRenderTests` on Linux.

## Journey steps

1. Open the `layered` fixture, select "Paint" (PY-2,
   `PhotoLayerStyleJourneyTests.testDropShadowAndStroke`), choose Layer >
   Layer Style…: the panel opens on Drop Shadow, off.
2. Turn Drop Shadow on, drag Distance to 20: the shadow follows on the canvas
   while dragging; Edit > Undo once removes the drag.
3. Turn Stroke on, Outside, 4 px, white; Done.
4. Layer > Copy Layer Style, select "Background", Layer > Paste Layer Style:
   both rows' styles match.
5. Select "Curves 1": Layer Style… is disabled with "Layer styles go on pixel
   and text layers."
6. Save, close, reopen: the styles are there and still editable.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P44 | adds, closes with S2 | C | `Tests/RealJobs/photo/outline-cutout/outline-cutout.jobs.json`: `style.add` stroke (outside, 4 px, white) and drop shadow on the cut-out, `doc.save` as `.ora`, `doc.open` it again, `style.set {kind: dropShadow, opacity: 0.2}`, `file.export` PNG | `input/cutout.ora` |
| RJ-X51 | its check (the shared packet's job) | C | `Tests/RealJobs/photo/style-drop-shadow/style-drop-shadow.jobs.json` (see `suiteui/layer-styles.md`, Jobs) | `input/cutout.ora` |

RJ-P44's trap: the style is flattened into the pixels on save (no longer
editable), or the stroke lands inside the disc. Assertion: after the reopen
`style.read` lists both effects; in the PNG the ring from r to r+4 px round
the disc is white within 2 levels and the disc's own edge pixels are
unchanged; the shadow's opacity at its darkest pixel reads 0.2 within 0.02.
Mutations: `PhotoModel.PhotoDocumentFile.json` (style not written →
`.styleSurvivesSave`), `PhotoModel.PhotoLayerComposite.json` (style drawn
before the layer's own opacity → `.fillOpacityThenEffects`).

## Screens and states

`photo-layer-style-panel` (Drop Shadow, light and dark), `-stroke` (the
stroke rows), `-canvas` (a styled layer on the canvas), `-disabled` (an
adjustment layer selected, the menu item's help).

## Contract slice

```swift
// Sources/PhotoModel/PhotoLayer.swift (PY-1)
public internal(set) var style: LayerStyle = .none          // pixel and text layers; adjustment layers keep .none
// Sources/PhotoModel/PhotoStyle+Kernel.swift (PY-1 stubs, PY-5 bodies)
extension PhotoWorkspace: LayerStyleTarget {
    public var styleSelection: LayerStyle? { get }           // the primary layer's, nil for none or an adjustment layer
    public var styleHelp: String? { get }                    // StyleRules.noLayerHelp, or "Layer styles go on pixel and text layers."
    public var stylePanel: StyleKind? { get }
    public mutating func showStylePanel(_ kind: StyleKind?)  // state only, real from PY-1
    public mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws   // NotBuilt until PY-5
}
```

`PhotoCommandCatalog` adds `+ StyleCommands.specs(PhotoWorkspace.self)`;
`Tests/command-ids/photo.txt` gains the eleven `style.*` ids.

## Pseudocode

- **setStyle.** Clamp through `StyleRules.clamped`; write it on every
  selected image layer (adjustment layers skipped; none left throws with
  `styleHelp`); record one layer-list step named `name` (Photo's step kind for
  opacity and blend, no tiles), folding steps under one `drag` token.
- **Composite.** For a layer with `style.isVisible`: pad its buffer by
  `reach`, `StyleProgram.render` at the document's scale 1, then composite
  the result at the padded origin with the layer's blend and opacity. A
  hidden layer draws nothing, its style included.
- **File.** `photo/document.json` gains `"style"` per layer, written only when
  not `.none`, so files without styles re-save byte for byte; a malformed
  style opens as `.none` with the open's warning naming the layer.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PY-1 | – | `PhotoLayer.style`; the adapter as stubs (`showStylePanel` real); the specs in the catalog and the ids; `PhotoLayerStyleTests` written, disabled | `Sources/PhotoModel/PhotoLayer.swift`, `Sources/PhotoModel/PhotoStyle+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoLayerStyleTests.swift` | LS-a | ~250, 5 |
| PY-2 | – | Layer menu items (Layer Style…, Copy, Paste, Clear Layer Style) bound by id; the panel as a sheet while `stylePanel` is set, intents run through the catalog, copy and paste through `LayerStylePasteboard`; the Layers bar's `fx` button runs `style.panel` (`PhotoLayerList.bar` builds it from the spec, no longer `LayerActionBar.effects`) | `Sources/PhotoApp/PhotoCommands+Layer.swift`, `Sources/PhotoApp/PhotoWindow+Styling.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Sources/PhotoApp/PhotoLayerList.swift`, `Tests/AppSnapshotTests/PhotoLayerRowSnapshots.swift` | PY-1 | ~180, 5 |
| PY-3 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoLayerStyleSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoLayerStyleTests.swift` | PY-2 | ~180, 2 |
| PY-4 | – | The journey written and skipped (`XCTSkip("waits on PY-8")`) | `UITests/PhotoJourneyTests+LayerStyle.swift` | PY-2 | ~120, 1 |
| PY-5 | – | The adapter's bodies; turns on `PhotoLayerStyleTests` | `Sources/PhotoModel/PhotoStyle+Kernel.swift`, `Tests/PhotoModelTests/PhotoLayerStyleTests.swift`, `Tests/mutations/PhotoModel.PhotoStyle+Kernel.json` | PY-1, LS-m | ~260, 3 |
| PY-6 | – | Styles in the composite and the `.ora`; `PhotoStyleRenderTests`; RJ-P44's and RJ-X51's job folders | `Sources/PhotoModel/PhotoLayerComposite.swift`, `Sources/PhotoModel/PhotoDocumentFile.swift`, `Tests/PhotoModelTests/PhotoStyleRenderTests.swift`, `Tests/mutations/PhotoModel.PhotoLayerComposite.json`, `Tests/mutations/PhotoModel.PhotoDocumentFile.json`, `Tests/RealJobs/photo/outline-cutout/outline-cutout.jobs.json`, `Tests/RealJobs/photo/outline-cutout/input/cutout.ora`, `Tests/RealJobs/photo/style-drop-shadow/style-drop-shadow.jobs.json`, `Tests/RealJobs/photo/style-drop-shadow/input/cutout.ora` | PY-1, LS-m | ~340, 9 |
| PY-7 | – | The live canvas draws styled layers through `StyleRoute`; the journey turned on | `Sources/PhotoModel/PhotoRenderRoute.swift`, `UITests/PhotoJourneyTests+LayerStyle.swift` | PY-4, PY-5, PY-6, LS-gpu, IM-photo | ~200, 2 |
| PY-8 | – | photo.md: layer styles move into the Layers row; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/layer-styles.wave.json` | PY-7, PY-3 | ~20, 2 |

## Build waves

- Wave 1: PY-1. Independent in this wave: PY-1 alone.
- Wave 2: PY-2, PY-5, PY-6. Independent in this wave: all three.
- Wave 3: PY-3, PY-4. Independent in this wave: both.
- Wave 4: PY-7. Independent in this wave: PY-7 alone.
- Wave 5: PY-8 (shared prose, `feature-done`, final). Independent in this wave: PY-8 alone.

Longest chain: PY-1 → PY-2 → PY-4 → PY-7 → PY-8 (5). Chain of 5: the menu
needs the catalog's ids, the journey drives the menu, PY-7 turns it on live,
PY-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PY-1 | `PhotoLayerStyleTests` compiles, disabled; the command-id list matches the catalog; `style.panel` sets `stylePanel` | an id is missing | – (stub) |
| PY-2 | `PhotoLayerStyleSnapshots.panel` (PY-3's, first in the slice PR); `PhotoLayerRowSnapshots.barMatchesTheLayerMenu`: `fx` matches the Layer Style… menu item and running it sets `stylePanel` | the sheet or a menu item is missing, or `fx` stays disabled | – (UI) |
| PY-3 | `PhotoLayerStyleSnapshots`; `RenderBudgetPhotoLayerStyleTests.distanceScrubInThreeBodies` | budget over | – (UI) |
| PY-4 | compiles, skipped | – | – |
| PY-5 | `PhotoLayerStyleTests`: `style.add` on two selected image layers is one step; an adjustment layer in the selection is skipped, alone it refuses with its help; 120 `style.set` under one token undo in one | a layer is missed, an adjustment layer takes a style, or a drag is many steps | `PhotoModel.PhotoStyle+Kernel`: adjustment layers not skipped → `.adjustmentLayersRefuse`; drag not passed → `.dragIsOneStep` |
| PY-6 | `PhotoStyleRenderTests`: a disc with a 12 px outer glow composites unclipped (the glow reaches 12 px past the layer's bounds); fill opacity 0 hides the disc and keeps its stroke; a hidden layer draws no shadow; the `.ora` round-trips a style and an old file re-saves byte for byte; RJ-P44 and RJ-X51 pass on Linux | a style is clipped, baked, lost on save, or an old file changes | `PhotoModel.PhotoLayerComposite`: no padding → `.glowIsNotClipped`; style drawn for a hidden layer → `.hiddenDrawsNothing`; `PhotoModel.PhotoDocumentFile`: style not written → `.styleSurvivesSave`; `.none` written → `.oldFileUnchanged` |
| PY-7 | `PhotoLayerStyleJourneyTests.testDropShadowAndStroke` steps 1 to 6; `PhotoAdjustSliderLatencyTests` unchanged | a step fails, or the route regresses | – (route call; LS-9's plan covers the route) |
| PY-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Distance scrub with the panel over the canvas | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPhotoLayerStyleTests.distanceScrubInThreeBodies` |
| Live style step on a 4K layer | one `.style` pass, p95 ≤ 16 ms (release, reported) | `StyleRouteLatencyTests` (shared) |
| One gesture, one step | a scrub is one "Change Layer Style" step | `PhotoLayerStyleTests` |
| No dead controls | Layer Style… disabled with help on an adjustment layer or none | `PhotoLayerStyleTests`, the journey step 5 |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PY-m merged-done on the Linux job with
`Mutate:` clean and RJ-P44 and RJ-X51 green there; PY-a and PY-u through the
feel gate (`mouse`, `taste`, `job`) with `Mac-Finish:`; PY-z's journey on
live. Then `Belt-Contact-Sheet:` with `photo-layer-style-*`.

## Not in this packet

Styles on adjustment layers and groups, a styles thumbnail or `fx` badge in
the row (the Layers-panel crew's), PSD import of effects
(`photo/psd-effects`), rasterize layer style.
