# Feature packet: layer-styles (Design)

**Feature:** layer styles on Design's shapes, text and frames. Object > Layer
Style… (and the Layers panel's `fx` button and row menu, once they land)
opens SuiteUI's `LayerStylePanel` on the selection; a drop shadow, glows, an
inner shadow, a stroke, overlays and bevel and emboss draw live on the canvas
and change later. Exports keep them: SVG as a filter on the element, PNG and
PDF through the shared style renderer with the shape itself still vector in
the PDF. This closes Design's failing drop-shadow job RJ-D14.
**Line:** `line:design` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/layer-styles`
**Beta:** captain, 2026-10-21. Labels `beta` and `p1` when filed.

**Covers:** feature map S2's Design adopter (`design/layer-styles`); real
jobs RJ-D14 (closes: the SVG half on Linux) and RJ-D43 (new: the PNG and PDF
half on macOS).

**Depends on:** `suiteui/layer-styles` **LS-a** (cross-line: the model,
`LayerStyleTarget`, the specs, the panel stub); DL-5 needs **LS-m**, DL-6
**LS-m**'s `LayerStyleSVG`, DL-3 and DL-7 **LS-m**'s `StyleProgram` and
**LS-gpu**'s route; suite-imaging **IM-a** (IM-1 links SuiteImaging into
DesignModel). Same line: `design-seams-2` (S2-a and S2-b own `DesignNode.swift`,
`DesignCanvas.swift`, `DesignObjectMenu.swift` and `DesignWindow.swift`
first), `pen-paths` **DP-m** (the last owner of `DesignSVG.swift`,
`DesignCommandCatalog.swift` and `Tests/command-ids/design.txt`) and **DP-z**
(`design.md`), `export-pack` **DX-m** (`DesignRasterizer.swift`).

**Rule 20.** No Design shadow type and no Design effect renderer.
`DesignNode.style` is SuiteImaging's `LayerStyle`; `DesignStyle+Kernel.swift`
is the adapter; SVG comes from `LayerStyleSVG`, pixels from `StyleProgram`
and `StyleRoute`. The canvas only rasterizes a styled node's own alpha (its
existing painter) and hands it to the route. SwiftUI's `.shadow` is not used
for layer styles.

**Render path.** On the canvas, each styled node keeps a cached alpha raster at
the canvas scale; a style edit sends one `.style` op through `StyleRoute` and
draws its under and over parts around the vector node; a geometry edit
re-rasterizes that node only. PNG export does the same at the export scale on
the CPU (`StyleProgram.render`); PDF draws the effect parts as images and the
node as vector paths.

Blueprint sections: design.md (Inspector, Export).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DL-a | Shapes, text and frames hold a `LayerStyle`, the `style.*` commands are in Design's catalog on stubs, and Object > Layer Style… opens the panel on the selection. | DL-1, DL-2 | MJ-DL | design-seams-2; pen-paths:DP-m (DL-1); suiteui layer-styles LS-a (cross-line) |
| DL-u | The canvas draws a styled node's effects from the stub program, and the panel and canvas have snapshots, a render budget and the journey written. | DL-3, DL-4 | DJ-L1 | DL-a |
| DL-m | Every style command sets each selected node's style as one undo step, SVG export writes the style as a filter with its warnings, and PNG and PDF export draw it padded. | DL-5, DL-6, DL-7 | MJ-DL | DL-a; export-pack:DX-m (DL-7); LS-m (cross-line) |
| DL-z | The canvas draws through the live route, the journey passes on live, and design.md lists the feature as built. | DL-8, DL-9 | DJ-L1 | DL-u, DL-m; pen-paths:DP-z (DL-9); LS-gpu (DL-8, cross-line) |

DL-u waits only on DL-a (rule 18); DL-m never waits on DL-u. MJ-DL is
`DesignLayerStyleTests` and `DesignStyleExportTests` on Linux.

## Journey steps

1. Open the `card` fixture, select the card (DL-2,
   `DesignLayerStyleJourneyTests.testCardShadow`), Object > Layer Style…:
   the panel opens on Drop Shadow, off.
2. Turn on Drop Shadow, scrub Size to 24: the shadow softens on the canvas
   while scrubbing; one undo step.
3. Close the panel, move the card: the shadow moves with it.
4. Reopen with the Layers row's menu (where it has landed) and lower Opacity
   to 20%: the shadow fades.
5. Export the frame as SVG and PNG: both files exist; the SVG's card element
   has a `filter`.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D14 | closes (with S2) | C | `Tests/RealJobs/design/card-shadow/card-shadow.jobs.json`: `style.add` drop shadow on the card, `style.set {distance: 12, size: 24}`, save, reopen, `style.set {opacity: 0.2}`, `file.export` SVG | `input/card.design` (one frame, one rounded card) |
| RJ-D43 | adds, closes with S2 | Cm | `Tests/RealJobs/design/card-shadow-raster/card-shadow-raster.jobs.json`: the same style, `file.export` PNG at 2x and PDF | the same fixture |

RJ-D14's trap (its row): the SVG export drops the shadow silently.
Assertion: the SVG has one `<filter>` whose `feGaussianBlur` and `feOffset`
carry the edited values (σ = 8, dx and dy from 135° and 12 px, y down) and
`feFlood flood-opacity="0.2"`, referenced by the card's element, and the
filter region is larger than the card by the style's reach. Mutation:
`DesignModel.DesignSVG.json` (filter written but not referenced →
`.cardUsesTheFilter`). RJ-D43's trap: the shadow is cut at the card's
bounds in the PNG, or the PDF rasterizes the card itself. Assertion: the PNG
has shadow pixels past the card's edge by the reach at 2x; the PDF's page
holds the card as a path and the shadow as one image under it.

## Screens and states

`design-layer-style-panel` (Drop Shadow on the card), `design-card-shadow`
(the canvas, light and dark), `design-layer-style-bevel` (bevel on text).

## Contract slice

```swift
// Sources/DesignModel/DesignNode.swift (DL-1): nil for none, so old files open and re-save unchanged
public internal(set) var style: LayerStyle?
// Sources/DesignModel/DesignStyle+Kernel.swift (DL-1 stubs, DL-5 bodies)
extension DesignWorkspace: LayerStyleTarget { ... }   // shapes, text and frames; groups refuse ("Layer styles go on shapes, text and frames.")
```

`DesignCommandCatalog` adds `+ StyleCommands.specs(DesignWorkspace.self)`;
`Tests/command-ids/design.txt` gains the eleven `style.*` ids.

## Pseudocode

- **setStyle.** Clamp; set on every selected shape, text and frame; one
  history step named `name`; drag folds.
- **Canvas.** For a node with `style.isVisible`: rasterize its fill and own
  stroke's alpha at the canvas scale (the painter's existing path to a
  bitmap), pad by `reach × scale`, draw `StyleRoute`'s under part, the vector
  node, then the over part. The cache key is (node id, geometry, scale);
  a style edit reuses the alpha.
- **SVG.** `LayerStyleSVG.filter(style, id: "style-<node id>", box:)` goes in
  `<defs>`; the node's element gets `filter="url(#style-<node id>)"`; its
  warnings join the export's warnings.
- **PNG and PDF.** The rasterizer draws each styled node as on the canvas,
  on the CPU (`StyleProgram.render`) at the export scale; in a PDF the node
  stays vector and only the effect parts are images.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DL-1 | – | `DesignNode.style`; the adapter as stubs; the specs and ids; `DesignLayerStyleTests` written, disabled | `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignStyle+Kernel.swift`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/DesignModelTests/DesignLayerStyleTests.swift` | LS-a | ~240, 5 |
| DL-2 | – | Object menu items (Layer Style…, Copy, Paste, Clear Layer Style) by id; the panel as a sheet while `stylePanel` is set; copy and paste through `LayerStylePasteboard` | `Sources/DesignApp/DesignObjectMenu.swift`, `Sources/DesignApp/DesignWindow+Styling.swift`, `Sources/DesignApp/DesignWindow.swift` | DL-1 | ~160, 3 |
| DL-3 | – | The canvas draws styled nodes: alpha cache and the under and over parts from `StyleProgram` (CPU) until DL-8 | `Sources/DesignApp/DesignCanvas+Styles.swift`, `Sources/DesignApp/DesignCanvas.swift` | DL-2 | ~220, 2 |
| DL-4 | – | Snapshots, the render budget, the journey written and skipped (`XCTSkip("waits on DL-8")`) | `Tests/AppSnapshotTests/DesignLayerStyleSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignLayerStyleTests.swift`, `UITests/DesignJourneyTests+LayerStyle.swift` | DL-3 | ~260, 3 |
| DL-5 | – | The adapter's bodies; turns on `DesignLayerStyleTests` | `Sources/DesignModel/DesignStyle+Kernel.swift`, `Tests/DesignModelTests/DesignLayerStyleTests.swift`, `Tests/mutations/DesignModel.DesignStyle+Kernel.json` | DL-1, LS-m | ~220, 3 |
| DL-6 | – | SVG export with the style filter; RJ-D14's job folder | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignStyleExportTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Tests/RealJobs/design/card-shadow/card-shadow.jobs.json`, `Tests/RealJobs/design/card-shadow/input/card.design` | DL-1, LS-m | ~260, 5 |
| DL-7 | – | PNG and PDF export draw styles; RJ-D43's job folder; macOS rasterizer tests | `Sources/DesignApp/DesignRasterizer.swift`, `Tests/AppSnapshotTests/DesignStyleRasterTests.swift`, `Tests/RealJobs/design/card-shadow-raster/card-shadow-raster.jobs.json`, `Tests/RealJobs/design/card-shadow-raster/input/card.design` | DL-1, DX-m, LS-m | ~240, 4 |
| DL-8 | – | The canvas uses `StyleRoute` (one GPU op per style edit); the journey turned on | `Sources/DesignApp/DesignCanvas+Styles.swift`, `UITests/DesignJourneyTests+LayerStyle.swift` | DL-4, DL-5, LS-gpu | ~140, 2 |
| DL-9 | – | design.md: layer styles in the inspector and export sections; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/layer-styles.wave.json` | DL-8, DL-6, DL-7 | ~20, 2 |

## Build waves

- Wave 1: DL-1. Independent in this wave: DL-1 alone.
- Wave 2: DL-2, DL-5, DL-6, DL-7. Independent in this wave: all four.
- Wave 3: DL-3. Independent in this wave: DL-3 alone.
- Wave 4: DL-4. Independent in this wave: DL-4 alone.
- Wave 5: DL-8. Independent in this wave: DL-8 alone.
- Wave 6: DL-9 (shared prose, `feature-done`, final). Independent in this wave: DL-9 alone.

Longest chain: DL-1 → DL-2 → DL-3 → DL-4 → DL-8 → DL-9 (6). Chain of 6:
the sheet needs the catalog's ids, the canvas draws what the sheet edits, the
budget and journey time the canvas, DL-8 swaps the canvas onto the route, and
DL-9 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DL-1 | `DesignLayerStyleTests` compiles, disabled; the command-id list matches the catalog; an old file decodes with `style == nil` and re-saves byte for byte | an id is missing or an old file changes | – (stub) |
| DL-2 | `DesignLayerStyleSnapshots.panel` (DL-4's, first in the slice PR) | the sheet or a menu item is missing | – (UI) |
| DL-3 | `DesignLayerStyleSnapshots.cardShadow`: the shadow sits under the card, offset down-right | the shadow draws over the card or is clipped | – (UI) |
| DL-4 | `RenderBudgetDesignLayerStyleTests.sizeScrubInThreeBodies`; the journey compiles, skipped | budget over | – (UI) |
| DL-5 | `DesignLayerStyleTests`: two selected shapes take one step; a group refuses with its help; a scrub is one step | a node is missed or a group takes a style | `DesignModel.DesignStyle+Kernel`: groups not refused → `.groupsRefuse`; drag not passed → `.dragIsOneStep` |
| DL-6 | `DesignStyleExportTests`: the card's SVG has the filter with the values RJ-D14 names and references it; a disabled shadow writes no filter; a linear-dodge glow adds one export warning; RJ-D14 passes on Linux | the filter is missing, unreferenced or wrong | `DesignModel.DesignSVG`: filter not referenced → `.cardUsesTheFilter`; warnings dropped → `.warningsReachTheExport` |
| DL-7 | `DesignStyleRasterTests` (macOS): the PNG at 2x has shadow pixels past the card by the reach; the PDF has the card as a path and one image; RJ-D43 passes in the `Cm` group | the shadow is clipped or the card rasterized | – (App target; `DesignRasterizer` has no Linux plan) |
| DL-8 | `DesignLayerStyleJourneyTests.testCardShadow` steps 1 to 5 | a step fails | – (route call) |
| DL-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Size scrub with the panel over the canvas | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignLayerStyleTests.sizeScrubInThreeBodies` |
| render: drag a styled card 120 samples | ≤ 3 window bodies; the alpha cache is reused (no re-rasterize on a move) | `RenderBudgetDesignLayerStyleTests.styledDragReusesAlpha` |
| One gesture, one step | a scrub is one "Change Layer Style" step | `DesignLayerStyleTests` |
| Never silent | every style SVG can't express exactly is in the export's warnings | `DesignStyleExportTests` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DL-m merged-done on the Linux job with
`Mutate:` clean and RJ-D14 green there, RJ-D43 green in the scoped run;
DL-a and DL-u through the feel gate (`mouse`, `taste`, `job`) with
`Mac-Finish:`; DL-z's journey on live. Then `Belt-Contact-Sheet:` with
`design-layer-style-*` and `design-card-shadow-*`.

## Not in this packet

Styles on groups and components, SVG text with styles beyond the filter
(text stays as `<text>` with the filter), Design's own PNG writer on Linux
(RJ-D43 stays `Cm` until one exists).
