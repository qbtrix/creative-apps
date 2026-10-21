# Feature packet: gradient-fill (Photo)

**Feature:** Photo's Gradient tool. Pick it in the palette (G), set its
stops and Linear or Radial in Tool Options with SuiteUI's `GradientEditor`,
then drag on the canvas: the drag's start and end are the gradient's line
(or centre and edge), and the gradient is drawn into the selected layer,
inside the selection when there is one, as one undo step. The pixels come
from creative-core's `PixelBuffer.gradient`, dithered so an 8-bit export
doesn't band. An agent runs the same thing as the `image.gradient` command.
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/gradient-fill`
**Beta:** captain, 2026-10-20 (photo.md had the Gradient tool as v2 Out).
Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/gradient-fill` (adopter of S24, and of E6's
raster gradient, which the pinned core already has); real job RJ-P19 (fill a
selection with a sky gradient: smooth, no banding, inside the selection).

**Depends on:** `suiteui/gradient-fill` **GF-a** (cross-line: `Fill`,
`GradientRules`, `GradientIntent`, the editor stub); PG-4 needs **GF-5**
(the real rules), PG-5 **GF-3** (the real view). Same line: photo-seams
(built; it owns `PhotoSelection.swift` and the tool files).

**Hand-offs:** `PhotoCommandCatalog.swift`, its plan and
`Tests/command-ids/photo.txt` are adopt-command-catalog's (#2999), and
`ToolOptions.swift`, `PhotoStroke.swift` and `PhotoToolOptions.swift` are
also listed by adopt-kernel-brush (closed) and the cut adopt-suiteui-chrome:
PG-1 and PG-3 start after AC-photo's `Belt-Slice-Done:`. Adding
`PhotoTool.gradient` makes `tool.gradient` a command at once (the catalog
lists `PhotoTool.allCases`), so PG-1 adds that id.

**Rule 20.** No Photo gradient type: the tool's options hold the kernel's
`Fill`, edited by `GradientRules`; the pixels are creative-core's.
`PhotoGradientTool+Kernel.swift` is the adapter (the name `check-dup-logic`
allows).

**Render path.** The gradient is a pixel edit, like Fill: it writes the
layer's tiles through the selection-mask path `editSelection` uses, and the
canvas draws those tiles through `PhotoRenderRoute`'s dispatcher as it draws
every other edit. No new route.

Blueprint sections: photo.md 4 (tools), 6 (Tool Options), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PG-a | `PhotoTool.gradient` is in the palette with its help ("Not built yet (PG-3).") and its options hold a `Fill`, and Tool Options shows the editor on the stubs. | PG-1, PG-2 | MJ-PG | suiteui/gradient-fill GF-a (cross-line); AC-photo (PG-1) |
| PG-u | A drag shows its line on the canvas, the options have snapshots and a render budget, and the journey is written. | PG-5, PG-6 | PJ-G1 | PG-a; GF-3 (PG-5, cross-line) |
| PG-m | A drag draws the dithered gradient into the selected layer inside the selection as one undo step, and the options take each editor intent. | PG-3, PG-4 | MJ-PG | PG-a; GF-5 (PG-4, cross-line) |
| PG-z | The tool runs on live services, the journey passes on live, and the blueprint has the tool in. | PG-7, PG-8 | PJ-G1 | PG-u, PG-m |

PG-u waits only on PG-a (rule 18); PG-m never waits on PG-u. MJ-PG is the
Model walk in `PhotoGradientToolTests` (Linux).

## Journey steps

1. Open the sample, marquee the top half (PG-2,
   `PhotoGradientJourneyTests.testSkyGradient`), press G: Tool Options shows
   the stop bar, no angle row.
2. Set the first stop deep blue and the last pale blue.
3. Drag from the selection's top to its bottom (PG-3): the selection fills
   blue to pale blue; the bottom half is unchanged.
4. Undo: the layer is back, in one step.
5. Switch to Radial and drag from the centre outwards: a radial fill.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P19 | closes (now `photo/gradient-fill`) | C | `Tests/RealJobs/photo/sky-gradient/sky-gradient.jobs.json`: `select.rect` the top half, `image.gradient` linear deep blue to pale blue from the top edge to the middle, export PNG | `input/grey-256.png` (256 × 256 flat grey) |

Trap: the solid Fill works but there is no gradient, or the gradient bands
in 8-bit, or it spills past the selection. Assertion: in the exported PNG
each row of the top half is one step brighter or equal (no run of more than
4 equal rows, so no banding), the first row is within 2/255 of deep blue,
and every bottom-half pixel is the original grey. Mutations:
`PhotoModel.PhotoGradientTool+Kernel.json`, dither off → `.noBanding`;
selection ignored → `.staysInSelection`.

## Screens and states

`photo-gradient-options` (linear, radial), `photo-gradient-drag` (the line
on the canvas), `photo-gradient-done` (light and dark).

## Contract slice

```swift
// Sources/PhotoModel/PhotoWorkspace.swift (PG-1)
public enum PhotoTool { ...; case gradient }          // "Not built yet (PG-3)." until PG-3
// Sources/PhotoModel/ToolOptions.swift (PG-1)
public var gradient: Fill                             // stops and type; default black to white, linear
// Sources/PhotoModel/PhotoGradientTool+Kernel.swift (PG-1 stubs, PG-3 and PG-4 bodies)
extension PhotoWorkspace {
    public mutating func drawGradient(from a: PixelPoint, to b: PixelPoint) throws   // one "Gradient" step
    public mutating func runGradientOption(_ intent: GradientIntent)                 // edits toolOptions.gradient
}
```

`image.gradient` params: `{type, stops: [{offset, r, g, b, a}], from: {x,
y}, to: {x, y}}`; unavailable with `noImage` or `noLayer`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PG-1 | – | `PhotoTool.gradient` with its help, symbol and G shortcut; the drag routed to the stub; `ToolOptions.gradient`; the adapter as stubs; `tool.gradient` in the id list; the exhaustive test switches; `PhotoGradientToolTests` written, disabled | `Sources/PhotoModel/PhotoWorkspace.swift`, `Sources/PhotoModel/PhotoStroke.swift`, `Sources/PhotoModel/ToolOptions.swift`, `Sources/PhotoModel/PhotoGradientTool+Kernel.swift`, `Sources/PhotoApp/PhotoIntent.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoToolsTests.swift`, `Tests/PhotoModelTests/PhotoGradientToolTests.swift` | GF-a, AC-photo | ~240, 9 |
| PG-2 | – | `PhotoFillToolOptions`: the editor (`showsAngle: false`, linear and radial) in Tool Options, intents to `runGradientOption` | `Sources/PhotoApp/PhotoFillToolOptions.swift` | PG-1 | ~100, 1 |
| PG-3 | – | `drawGradient` and the drag: `PixelBuffer.gradient` over the layer, stops from sRGB to linear, dithered, written through a positional `editSelection`; the `image.gradient` spec; the tool's help cleared; RJ-P19's job folder; turns on the tool tests | `Sources/PhotoModel/PhotoGradientTool+Kernel.swift`, `Sources/PhotoModel/PhotoSelection.swift`, `Tests/PhotoModelTests/PhotoGradientToolTests.swift`, `Tests/mutations/PhotoModel.PhotoGradientTool+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/RealJobs/photo/sky-gradient/sky-gradient.jobs.json`, `Tests/RealJobs/photo/sky-gradient/input/grey-256.png` | PG-1 | ~320, 8 |
| PG-4 | – | `runGradientOption` through `GradientRules` (type limited to linear and radial; angle ignored) | `Sources/PhotoModel/ToolOptions.swift`, `Tests/PhotoModelTests/PhotoGradientOptionsTests.swift`, `Tests/mutations/PhotoModel.ToolOptions.json` | PG-1, GF-5 | ~120, 3 |
| PG-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoGradientSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoGradientTests.swift` | PG-2, GF-3 | ~160, 2 |
| PG-6 | – | The drag's line on the canvas overlay; the journey written and skipped (`XCTSkip("waits on PG-7")`) | `Sources/PhotoApp/PhotoCanvasOverlay.swift`, `UITests/PhotoJourneyTests+Gradient.swift` | PG-2 | ~140, 2 |
| PG-7 | – | Live: the journey turned on, on live services | `UITests/PhotoJourneyTests+Gradient.swift` | PG-6, PG-3, PG-4 | ~40, 1 |
| PG-8 | – | photo.md: the Gradient tool moves from v2 Out to the tools; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/gradient-fill.wave.json` | PG-7, PG-5 | ~30, 2 |

## Build waves

- Wave 1: PG-1. Independent in this wave: PG-1 alone.
- Wave 2: PG-2, PG-3, PG-4. Independent in this wave: all three.
- Wave 3: PG-5, PG-6. Independent in this wave: both.
- Wave 4: PG-7. Independent in this wave: PG-7 alone.
- Wave 5: PG-8 (shared prose, `feature-done`, final). Independent in this wave: PG-8 alone.

Longest chain: PG-1 → PG-2 → PG-6 → PG-7 → PG-8 (5). Chain of 5: the
options need the tool, the journey drives the options, PG-7 turns it on
live, PG-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PG-1 | `PhotoToolsTests`: the gradient tool is disabled with its help; the command-id list matches the catalog | a tool has no help or an id is missing | – (stub) |
| PG-2 | `PhotoGradientSnapshots.options` (PG-5's, first in the slice PR) | the editor is missing | – (UI) |
| PG-3 | `PhotoGradientToolTests`: a top-to-bottom drag inside a marquee writes deep blue at the top row and leaves the rest; no selection fills the layer; 8-bit rows never repeat more than 4 times; one undo restores; `image.gradient` with one stop is malformed; RJ-P19 passes on Linux | a pixel, the mask, banding or the step is wrong | `PhotoModel.PhotoGradientTool+Kernel`: dither off → `.noBanding`; selection ignored → `.staysInSelection`; stops not decoded to linear → `.firstRowIsDeepBlue` |
| PG-4 | `PhotoGradientOptionsTests`: `.add` at 0.5 adds a stop, `.remove` at two stops keeps two, `.type(.solid)` is ignored | an option edit is wrong | `PhotoModel.ToolOptions`: solid allowed → `.toolIsNeverSolid`; remove below two → `.keepsTwoStops` |
| PG-5 | `PhotoGradientSnapshots`; `RenderBudgetPhotoGradientTests.gradientDragInThreeBodies` | budget over | – (UI) |
| PG-6 | compiles, skipped | – | – |
| PG-7 | `PhotoGradientJourneyTests.testSkyGradient` steps 1 to 5 | a step fails | – |
| PG-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample gradient drag (the line only, pixels on release) | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetPhotoGradientTests.gradientDragInThreeBodies` |
| Release cost | a 4K layer's gradient lands in ≤ 250 ms (reported) | `PhotoGradientToolTests.fourKCost` |
| One gesture, one step | a drag is one "Gradient" step | `PhotoGradientToolTests` |
| No dead controls | the tool is disabled with help until PG-3 | `PhotoToolsTests` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PG-m merged-done with RJ-P19 green in the
Linux job; PG-u's feel gate and `Mac-Finish:`; PG-z's journey on live. Then
`Belt-Contact-Sheet:` with `photo-gradient-*`.

## Not in this packet

A gradient-fill layer (a live, re-editable gradient layer: not cheap, it
needs a new layer kind), diamond, angle and reflected shapes (CoreRaster has
them; the shared editor offers linear and radial), gradient presets, a
gradient map adjustment.
