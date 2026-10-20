# Feature packet: stroke-style (Design)

**Feature:** Design's strokes get joins, caps and dashes. The inspector's
Stroke section becomes SuiteUI's `StrokeEditor` (no trim rows in Design),
under the gradient editor in the same paint area; `DesignStroke` is replaced
by the kernel's `VectorStroke`, and old files open with their colour and
width. The canvas, PNG, PDF and SVG draw the dashes through
`StrokeRules.paintedPath`. Every edit is one of SuiteKernel's stroke commands.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/stroke-style`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `design/stroke-style` (adopter of S17); real job
RJ-D36 (new: a dashed 2 pt border with round caps, exported to SVG).

**Depends on:** `suiteui/stroke-style` **SS-a** (cross-line); DK-5 needs
**SS-m**, DK-7 **SS-d** (dashes, after the creative-core bump), DK-4 **SS-u**.
Same line: shape-tools' **DS-u**
before DK-3 (`DesignCanvasMarks.swift`), **DS-m** before DK-5 (`DesignNode.swift`,
the catalog, the id list, `DesignSVG.swift`). style-rows (the Stroke section and
`LiveStyling`), design-window, design-export.

**Rule 20.** `DesignStroke` (colour and width, `StyleTypes.swift`) is the one
app copy of a stroke. DK-1 gives the views a `vectorStroke` accessor so the
editor (DK-2) and the canvas (DK-3) never read `DesignStroke`'s fields; DK-5
then makes it `typealias DesignStroke = VectorStroke` across the Model, and
`DesignNode`'s decoder reads the old `{color, width}` shape. App code that
reads only `width` compiles unchanged. The adapter is
`DesignStroke+Kernel.swift`; `trimHelp` is "Trim paths are for animation, in
Flare and Halo."

**Render path.** `paintArtwork` strokes `StrokeRules.paintedPath` with the
join and cap; SVG writes `StrokeSVG.attributes`. No new route.

Blueprint sections: design.md 6 (Properties: Stroke), 8.2.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DK-a | The adapter and the views' stroke accessor are declared as stubs, and the inspector's Stroke section is the shared editor on them. | DK-1, DK-2 | MJ-DK | – |
| DK-u | The canvas strokes dashes, joins and caps, and the snapshots and render budget hold. | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u |
| DK-m | Design's stroke is the kernel's with old files read, every stroke command is one step for the whole selection, and the SVG writes joins, caps and dashes. | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m |
| DK-z | The journey dashes a border on live services, and the feature is built. | DK-8, DK-9 | J-DK | DK-u, DK-m |

DK-u waits only on DK-a (rule 18); DK-m never waits on DK-u. MJ-DK is the
Model walk in `DesignStrokeTests` (Linux).

## Journey steps

1. Select a rectangle with no stroke, click Add Stroke (DK-2, `DesignStrokeJourneyTests.testDashedBorder`):
   a 1 pt black stroke; the editor shows Width, Join, Cap, Dash.
2. Scrub Width to 2, pick Round cap, pick Dashed: the border dashes at 8 on, 4
   off with round ends; one step per gesture.
3. Undo three times: back to a plain 1 pt stroke.
4. Open `old-strokes.design` (saved before this feature): its strokes keep
   their colour and width.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D36 | adds, closes with `design/stroke-style` | C | `Tests/RealJobs/design/dashed-border/dashed-border.jobs.json`: `edit.select`, `stroke.add`, `stroke.width {"width": 2}`, `stroke.cap {"cap": "round"}`, `stroke.dash {"preset": "dashed"}`, export SVG | `input/one-rect.design` |

Trap: the SVG drops the dash (Design wrote only colour and width) or writes
it unscaled. Assertion: the rect has `stroke-dasharray="8 4"` and
`stroke-linecap="round"`. Mutation: `DesignModel.DesignSVG.json`
(attributes from the old two-field writer → `.strokeWritesDash`).

## Screens and states

`design-stroke-editor` (light and dark), `-dashed`, `-no-stroke`.

## Contract slice

```swift
// Sources/DesignModel/Contracts/StyleTypes.swift (DK-5)
public typealias DesignStroke = VectorStroke
// Sources/DesignModel/DesignNode.swift (DK-5): `stroke` decodes the old {color, width} shape too.
// Sources/DesignModel/DesignStroke+Kernel.swift (DK-1 stubs, DK-6 bodies)
extension DesignNode { public var vectorStroke: VectorStroke? { get } }   // the views read this, never DesignStroke's fields
extension DesignWorkspace: StrokeTarget {
    public var strokeHelp: String? { get }
    public var trimHelp: String? { get }                    // "Trim paths are for animation, in Flare and Halo."
    public var selectedStroke: VectorStroke? { get }
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DK-1 | – | The adapter and `DesignNode.vectorStroke` as stubs; `DesignStrokeTests` written, disabled | `Sources/DesignModel/DesignStroke+Kernel.swift`, `Tests/DesignModelTests/DesignStrokeTests.swift` | – | ~120, 2 |
| DK-2 | – | The inspector's Stroke section becomes `StrokeEditor` (no trim) on the stubs; the journey written, skipped | `Sources/DesignApp/DesignInspectorStyle.swift`, `UITests/DesignJourneyTests+Stroke.swift` | DK-1 | ~160, 2 |
| DK-3 | – | The canvas strokes `StrokeRules.paintedPath` with join and cap, read through `vectorStroke` | `Sources/DesignApp/DesignCanvasMarks.swift`, `Tests/AppSnapshotTests/DesignStrokePaintTests.swift` | DK-2 | ~140, 2 |
| DK-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignStrokeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignStrokeTests.swift` | DK-3 | ~160, 2 |
| DK-5 | – | `DesignStroke` becomes `VectorStroke` across the Model; old files decode | `Sources/DesignModel/Contracts/StyleTypes.swift`, `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/Live/LiveStyling.swift`, `Sources/DesignModel/Contracts/UseCases.swift`, `Sources/DesignModel/DesignActions+Edit.swift`, `Sources/DesignModel/Live/LiveFiling.swift`, `Sources/DesignModel/Fakes/DesignArrangeFakes.swift`, `Tests/DesignModelTests/DesignStrokeMigrationTests.swift`, `Tests/mutations/DesignModel.DesignNode.json` | DK-1 | ~260, 9 |
| DK-6 | – | Adapter bodies; the nine specs in the catalog and id list; turns on `DesignStrokeTests` | `Sources/DesignModel/DesignStroke+Kernel.swift`, `Tests/DesignModelTests/DesignStrokeTests.swift`, `Tests/mutations/DesignModel.DesignStroke+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt` | DK-5 | ~220, 5 |
| DK-7 | – | SVG writes `StrokeSVG.attributes`; RJ-D36's job folder | `Sources/DesignModel/Live/DesignSVG.swift`, `Tests/DesignModelTests/DesignSVGTests.swift`, `Tests/mutations/DesignModel.DesignSVG.json`, `Tests/RealJobs/design/dashed-border/dashed-border.jobs.json`, `Tests/RealJobs/design/dashed-border/input/one-rect.design` | DK-6 | ~140, 5 |
| DK-8 | – | The journey turned on, on live services | `UITests/DesignJourneyTests+Stroke.swift` | DK-4, DK-7 | ~50, 1 |
| DK-9 | – | `status: built`; `feature-done` | `docs/blueprints/design/features/stroke-style.wave.json` | DK-8 | ~10, 1 |

## Build waves

- Wave 1: DK-1. Independent in this wave: DK-1 alone.
- Wave 2: DK-2, DK-5. Independent in this wave: both.
- Wave 3: DK-3, DK-6. Independent in this wave: both.
- Wave 4: DK-4, DK-7. Independent in this wave: both.
- Wave 5: DK-8. Independent in this wave: DK-8 alone.
- Wave 6: DK-9 (`feature-done`, final). Independent in this wave: DK-9 alone.

Longest chain: DK-1 → DK-2 → DK-3 → DK-4 → DK-8 → DK-9 (6). Chain of 6: the stroke type switches before the adapter's bodies, the SVG writes what the commands set, the journey runs on all of it, and DK-9 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DK-1 | `DesignStrokeTests` compiles, disabled; `vectorStroke` maps today's colour and width | – | – (stub) |
| DK-2 | `DesignInspectorSnapshots`: the Stroke section is the editor on the stubs, trim hidden | the editor is missing | – (UI) |
| DK-3 | `DesignStrokePaintTests`: a dashed stroke paints gaps; a round cap rounds the ends | the canvas paints solid | – (UI) |
| DK-4 | `DesignStrokeSnapshots`; `RenderBudgetDesignStrokeTests.widthScrubInThreeBodies` | budget over | – (UI) |
| DK-5 | `DesignStrokeMigrationTests`: `old-strokes.design` decodes with its colours and widths as `VectorStroke`; a saved file round-trips join, cap and dash | an old file loses a stroke | `DesignModel.DesignNode`: old shape not read → `.oldStrokeDecodes`; a new stroke decoded as nil → `.newStrokeDecodes` |
| DK-6 | `DesignStrokeTests`: each stroke command on three selected nodes is one step; a locked node is skipped with its help; width clamps; `stroke.trim` is unavailable with the trim help | a step, a clamp or a refusal is wrong | `DesignModel.DesignStroke+Kernel`: one step per node → `.oneStepForSeveral`; locked not skipped → `.lockedSkipped` |
| DK-7 | `DesignSVGTests.dashedStroke`; RJ-D36 passes on Linux | the SVG drops the dash | `DesignModel.DesignSVG`: old writer kept → `.strokeWritesDash`; cap written as join → `.capAttribute` |
| DK-8 | `testDashedBorder` steps 1 to 4 on live | a step fails | – |
| DK-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample width scrub with the canvas live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignStrokeTests.widthScrubInThreeBodies` |
| One gesture, one step | a scrub, a chip, a preset each one step | `DesignStrokeTests.oneStepPerGesture` |
| No dead controls; keyboard parity | every row by Tab; disabled rows say why | `testDashedBorder` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DK-m merged-done with RJ-D36 green
in the Linux job; DK-u's feel gate and `Mac-Finish:`; DK-z's journey on live.
Then `Belt-Contact-Sheet:` with `design-stroke-*`.

## Not in this packet

Trim paths in Design, stroke alignment inside or outside, gradient strokes.
