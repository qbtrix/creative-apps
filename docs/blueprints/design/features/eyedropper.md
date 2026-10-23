# Feature packet: eyedropper (Design)

**Feature:** Design gets an Eyedropper tool (I). A click on the canvas sets
the selection's fill to the colour under the pointer, Option-click sets its
stroke colour; SuiteUI's `SampleLoupe` shows the colour first. The colour is
what the document paints there: the topmost visible layer's fill, its
gradient's colour at that point, or a stroke. Every inspector colour row gets
SuiteUI's eyedropper button with no Design change (it picks anywhere on
screen). `color.sample` gives an agent the same reading, and Design's own
`color.pick {x, y, to}` (Pick Colour, edit) samples and applies in one step,
as the tool's click does.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/eyedropper`
**Beta:** captain, 2026-10-20. Labels `beta` and `p2` when filed.

**Covers:** feature map `design/eyedropper` (adopter of S13); real job RJ-D34
(new: pick one shape's colour onto another). RJ-D23 (from a placed photo)
needs S20's image layers too and closes with S20.

**Depends on:** `suiteui/eyedropper` **EY-a** (cross-line); DY-5 needs
**EY-m**, DY-4 **EY-u**. Same line: transform's **DT-m** before DY-5 and DY-6 (the catalog, the id
list, `DesignCanvasEditing.swift`'s tool dispatch after select-several). Built or earlier: design-window, canvas-basics, style-rows,
gradient-fill's `DesignNode.gradient` (DG-m) for the gradient colour.

**Rule 20.** The adapter is `DesignSample+Kernel.swift`; the gradient colour
at a point is `GradientRules.color(of:at:)` on the line's projection, never a
Design copy.

**Render path.** None: sampling reads the document, not pixels.

Blueprint sections: design.md 5.2 (tools), 6 (colour rows).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DY-a | The Eyedropper tool exists on the palette and the adapter is declared as stubs. | DY-1, DY-2 | MJ-DY | – |
| DY-u | The loupe follows the pointer while the tool is active, a click and an Option-click send their picks, and the snapshots and render budget hold. | DY-3, DY-4 | J-DY | DY-a |
| DY-m | A pick reads the topmost visible layer's colour at the point and applies it to the selection's fill or stroke as one step, by the tool or by command. | DY-5, DY-6 | MJ-DY | DY-a, transform:DT-m |
| DY-z | The journey picks a fill and a stroke on live services, and the feature is built. | DY-7, DY-8 | J-DY | DY-u, DY-m |

DY-u waits only on DY-a (rule 18); DY-m never waits on DY-u. MJ-DY is the
Model walk in `DesignSampleTests` (Linux).

## Journey steps

1. Select a white rectangle, click the palette's Eyedropper (`design.tool.eyedropper`; DY-2,
   `DesignEyedropperJourneyTests.testPickFillFromShape`): it is selected, the status line reads
   Eyedropper; the loupe follows the pointer.
2. Click a red ellipse: the rectangle's fill turns red (one "Fill" step).
3. Option-click a blue text: the rectangle's stroke turns blue.
4. Click the palette's Move (`design.tool.move`): it is selected, the status line reads Move, the
   rectangle still selected.
5. Keyboard parity: press I, the Eyedropper is selected; press V, Move is back.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D34 | adds, closes with `design/eyedropper` | C | `Tests/RealJobs/design/pick-fill/pick-fill.jobs.json`: `color.sample` at the overlap, `edit.select` the rectangle, `color.pick {"x": …, "y": …, "to": "fill"}` at the same point, save | `input/two-shapes.design` (a red ellipse over part of a white rectangle) |

Trap: the sample reads the selected rectangle (white) rather than the ellipse
on top. Assertion: `color.sample` at the overlap reads `#FF0000`; after the
apply the saved rectangle's fill is `#FF0000`. Mutation:
`DesignModel.DesignSample+Kernel.json` (selection read instead of the topmost
→ `.samplesTopmost`).

## Screens and states

`design-eyedropper-loupe` (light and dark), `-stroke` (Option held).

## Contract slice

```swift
// Sources/DesignModel/DesignSample+Kernel.swift (DY-1 stubs, DY-5 bodies)
extension DesignWorkspace: SampleTarget {
    public var sampleHelp: String? { get }                  // "Open a design first."
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor?   // topmost visible painted layer
    public mutating func applySample(at point: Point, toStroke: Bool) throws    // one "Fill" or "Stroke" step
}
// Sources/DesignModel/DesignWorkspace.swift (DY-1): DesignTool gains `.eyedropper`.
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DY-1 | – | `DesignTool.eyedropper`; the adapter as stubs; `DesignSampleTests` written, disabled | `Sources/DesignModel/DesignSample+Kernel.swift`, `Sources/DesignModel/DesignWorkspace.swift`, `Tests/DesignModelTests/DesignSampleTests.swift` | – | ~120, 3 |
| DY-2 | – | The Eyedropper on the palette (I) on the stubs; the journey written, skipped | `Sources/DesignApp/DesignIntent.swift`, `UITests/DesignJourneyTests+Eyedropper.swift` | DY-1 | ~100, 2 |
| DY-3 | – | The loupe over the canvas while the tool is active; click and Option-click intents; the tool's options (sample size, Fill or Stroke) in the inspector's Eyedropper section, held by the Model (`DesignLoupe`), never on the artboard | `Sources/DesignApp/DesignSampleLoupe.swift`, `Sources/DesignApp/DesignCanvasFeedback.swift`, `Sources/DesignModel/DesignLoupe.swift`, `Tests/AppSnapshotTests/DesignEyedropperOverlayTests.swift` | DY-2 | ~180, 3 |
| DY-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignEyedropperSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignEyedropperTests.swift` | DY-3 | ~160, 2 |
| DY-5 | – | Adapter bodies (topmost visible painted node, gradient colour at the point, the apply step) and the tool's dispatch; turns on `DesignSampleTests` | `Sources/DesignModel/DesignSample+Kernel.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Sources/DesignModel/DesignWorkspace.swift` (the Eyedropper's `unavailableHelp` set to nil, #3987), `Tests/DesignModelTests/DesignSampleTests.swift`, `Tests/mutations/DesignModel.DesignSample+Kernel.json` | DY-1 | ~220, 5 |
| DY-6 | – | `color.sample` and `color.pick` in the catalog and id list; RJ-D34's job folder | `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/DesignModelTests/DesignSampleCommandTests.swift`, `Tests/RealJobs/design/pick-fill/pick-fill.jobs.json`, `Tests/RealJobs/design/pick-fill/input/two-shapes.design` | DY-5 | ~120, 5 |
| DY-7 | – | The journey turned on, on live services | `UITests/DesignJourneyTests+Eyedropper.swift` | DY-4, DY-6 | ~50, 1 |
| DY-8 | – | `status: built`; `feature-done` | `docs/blueprints/design/features/eyedropper.wave.json` | DY-7 | ~10, 1 |

## Build waves

- Wave 1: DY-1. Independent in this wave: DY-1 alone.
- Wave 2: DY-2, DY-5. Independent in this wave: both.
- Wave 3: DY-3, DY-6. Independent in this wave: both.
- Wave 4: DY-4. Independent in this wave: DY-4 alone.
- Wave 5: DY-7. Independent in this wave: DY-7 alone.
- Wave 6: DY-8 (`feature-done`, final). Independent in this wave: DY-8 alone.

Longest chain: DY-1 → DY-2 → DY-3 → DY-4 → DY-7 → DY-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DY-1 | `DesignSampleTests` compiles, disabled; the tool enum has `.eyedropper` | – | – (stub) |
| DY-2 | `DesignToolPaletteSnapshots`: the Eyedropper shows on the palette with I, enabled | the tool is missing | – (UI) |
| DY-3 | `DesignEyedropperOverlayTests`: the loupe tracks the pointer; a click emits one apply, an Option-click one stroke apply; with Stroke chosen the two swap; the options sit in the inspector, inside the window, clear of the artboard. `DesignLoupeTests`: no loupe for a non-finite pointer; the size and the target are the Model's | a pick is doubled, or the options cover the canvas | `DesignModel.DesignLoupe`: finite guard, tool guard, the target and Option, the two setters |
| DY-4 | `DesignEyedropperSnapshots`; `RenderBudgetDesignEyedropperTests.loupeTrackInThreeBodies` | budget over | – (UI) |
| DY-5 | `DesignSampleTests`: the topmost visible node wins; a hidden one is skipped; a gradient reads its colour at the point; empty canvas is nil; an apply is one step and a locked selection refuses; the chosen sample size reaches the pick (`sizeChangesThePick`); the Eyedropper is enabled on the palette | a layer, a colour or a step is wrong | `DesignModel.DesignSample+Kernel`: selection read → `.samplesTopmost`; hidden nodes counted → `.skipsHidden`; first stop used → `.gradientAtPoint` |
| DY-6 | `color.sample` and `color.pick` listed and run; RJ-D34 passes on Linux | the id is missing | – (registration) |
| DY-7 | `testPickFillFromShape` steps 1 to 5 on live | a step fails | – |
| DY-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample loupe track over the canvas | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignEyedropperTests.loupeTrackInThreeBodies` |
| One gesture, one step | a pick is one step | `DesignSampleTests.applyIsOneStep` |
| No dead controls; keyboard parity | a palette click picks the tool and Move leaves it (steps 1, 4); I and V do the same (step 5) | `testPickFillFromShape` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DY-m merged-done with RJ-D34 green in the
Linux job; DY-u's feel gate and `Mac-Finish:`; DY-z's journey on live. Then
`Belt-Contact-Sheet:` with `design-eyedropper-*`.

## Not in this packet

Sampling placed photos (S20 adds image layers; the screen pick on every colour
row covers them meanwhile), copying a whole style from one layer to another.
