# Feature packet: gradient-fill (Flare)

**Feature:** Flare's gradient fills become editable. Flare already stores,
draws and exports FlareCore's linear and radial `Fill`; what it lacks is the
editing. The inspector's FILL section shows SuiteUI's `GradientEditor` for a
gradient (its stops as the swatch #2315 asks for) and the Solid / Linear /
Radial switch for any fill, and every edit is one of SuiteKernel's fill
commands, so the CLI and an agent can change a gradient too.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/gradient-fill`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/gradient-fill` (adopter of S24); #2315 (the
gradient row shows only the word "Gradient" and a copied refusal string);
real job RJ-F31 (new).

**Depends on:** `suiteui/gradient-fill` **GF-a** (cross-line: the `Fill/`
module, `GradientFillTarget`, the specs, the editor stubs); FG-5 needs its
**GF-6** (real commands), FG-3 its **GF-3** (the real view). Same line:
inspector-timeline (built; it owns `FlarePaint.swift` and
`FlareInspectorFill.swift`) and flare-export (built; it last edited `flare.md`).

**Hand-offs:** `FlareCommandCatalog.swift`, its plan and
`Tests/command-ids/flare.txt` are adopt-command-catalog's (#2999): FG-5
starts after AC-flare's `Belt-Slice-Done:`.

**Rule 20.** Flare's stored `Fill` is the kernel's `Fill` (a typealias), so
there is no adapter type, only the conformance in `FlareFill+Kernel.swift`.
`FlarePaint.gradientRefusal` and the view's copy of it are deleted.

**Render path.** Unchanged: `FlareStage` and `StageRasterizer` already draw
the stored fill, and the SVG and Lottie writers already export it. An edit
that changes the angle rewrites the stored start and end points (from
`GradientRules.rotated` on the shape's bounds), so the stage and the export
read the same points. A gradient imported with points off the box centre
keeps them until its angle or type is edited; stop and colour edits keep them.

Blueprint sections: flare.md 6 (inspector rows; gradients leave the Later
list), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FG-a | `FlareWorkspace` conforms to `GradientFillTarget` as stubs, the paint readout carries the gradient, and the FILL section shows the switch and the editor on them. | FG-1, FG-2 | MJ-FG | suiteui/gradient-fill GF-a (cross-line) |
| FG-u | The FILL section's states have snapshots, a stop drag stays in its render budget, and the journey is written. | FG-3, FG-4, FG-9 | FJ-G1 | FG-a; GF-3 (FG-3, cross-line) |
| FG-m | Every fill command runs on the selected shapes as one undo step through the command engine, and the paint readout reads Mixed for differing gradients. | FG-5, FG-6 | MJ-FG | FG-a; key-select-all:KS-a (the catalog); GF-6 and AC-flare (FG-5, cross-line) |
| FG-z | The FILL section runs on live services, the journey passes on live, and #2315 closes. | FG-7, FG-8 | FJ-G1 | FG-u, FG-m |

FG-u waits only on FG-a (rule 18); FG-m never waits on FG-u. MJ-FG is the
Model walk in `FlareGradientTests` (Linux).

## Journey steps

1. Open the sample with the gradient circle; select it (FG-2,
   `FlareGradientJourneyTests.testEditImportedGradient`): FILL shows the stop
   bar in the gradient's colours, not the word "Gradient".
2. Select the middle stop and pick red: the stage's circle shows red there.
3. Type 90 in the angle row: the gradient runs top to bottom.
4. Undo twice: the angle, then the colour, come back (one step each).
5. Select a solid rectangle, pick Radial: it takes a two-stop radial fill.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F31 | adds, closes with `flare/gradient-fill` | C | `Tests/RealJobs/flare/gradient-edit/gradient-edit.jobs.json`: select the shape, `fill.stop-color` index 1 red, `fill.angle` 90, export SVG and save | `input/gradient-circle.flare` (one shape, a three-stop linear fill from an import, left to right) |

Trap: the stage shows the change but the saved `Fill` keeps its old
endpoints, so the export still runs left to right. Assertion: the SVG's
`linearGradient` has `x1` equal to `x2` and `y1` below `y2`, its middle stop
`#ff0000`, and the saved file's stops match. Mutation:
`FlareModel.FlareFill+Kernel.json`, the angle edit writing stops only →
`FlareGradientTests.angleRewritesPoints`.

## Screens and states

`flare-fill-gradient` (updated: the editor instead of the word),
`flare-fill-radial`, `flare-fill-solid-switch` (light and dark).

## Contract slice

```swift
// Sources/FlareModel/FlareFill+Kernel.swift (FG-1 stubs, FG-5 bodies)
extension FlareWorkspace: GradientFillTarget {
    public var fillSelection: FillSelection? { get }   // the first edited shape's Fill in its bounds
    public var fillHelp: String? { get }               // FlarePaint's "no shape" reason
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws
    public mutating func runFill(_ intent: GradientIntent)  // the intent's command through `catalog`
}
// Sources/FlareModel/FlarePaint.swift (FG-1): PaintReadout gains the gradient itself.
public var gradient: FillSelection?   // nil for solid or Mixed; replaces `fillIsGradient`'s refusal
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FG-1 | – | The conformance and `runFill` as stubs; `PaintReadout.gradient`; `FlareGradientTests` written, disabled | `Sources/FlareModel/FlareFill+Kernel.swift`, `Sources/FlareModel/FlarePaint.swift`, `Tests/FlareModelTests/FlareGradientTests.swift` | GF-a | ~140, 3 |
| FG-2 | – | FILL shows the switch and `GradientEditor` on the stubs, intents to `runFill`; the copied refusal string goes | `Sources/FlareApp/FlareInspectorFill.swift` | FG-1 | ~120, 1 |
| FG-3 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareGradientSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareGradientTests.swift` | FG-2, GF-3 | ~160, 2 |
| FG-4 | – | The journey, written and skipped (`XCTSkip("waits on FG-7")`) | `UITests/FlareJourneyTests+Gradient.swift` | FG-2 | ~100, 1 |
| FG-5 | – | Conformance bodies (`setFill` through `services.properties`, one step, the drag token as the fold key; angle and type rewrite points); the eight specs in the catalog and the id list; RJ-F31's job folder; turns on `FlareGradientTests` | `Sources/FlareModel/FlareFill+Kernel.swift`, `Tests/FlareModelTests/FlareGradientTests.swift`, `Tests/mutations/FlareModel.FlareFill+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/RealJobs/flare/gradient-edit/gradient-edit.jobs.json`, `Tests/RealJobs/flare/gradient-edit/input/gradient-circle.flare` | FG-1, GF-6, AC-flare | ~300, 7 |
| FG-6 | – | `PaintReadout` reads Mixed for differing gradients; the solid setter turns a gradient solid instead of refusing; `gradientRefusal` deleted | `Sources/FlareModel/FlarePaint.swift`, `Tests/FlareModelTests/FlarePaintGradientTests.swift`, `Tests/mutations/FlareModel.FlarePaint.json` | FG-1 | ~140, 3 |
| FG-7 | – | Live: the journey turned on, on live services | `UITests/FlareJourneyTests+Gradient.swift` | FG-4, FG-5 | ~40, 1 |
| FG-8 | – | flare.md: gradient editing leaves the Later list; `status: built`; `feature-done`; `Fixes #2315` | `docs/blueprints/flare.md`, `docs/blueprints/flare/features/gradient-fill.wave.json` | FG-7, FG-6, FG-3 | ~30, 2 |
| FG-9 | – | The FILL and STROKE colour rows switch to `InspectorColorWellRow(_:color:opacity:)` and the paint setters carry the opacity, so a picked alpha reaches the shape and a typed hex keeps it; it also stores the kernel's `FillMemory` beside the fill and saves it, so linear → radial → linear keeps the angle (gap audit C3) | `Sources/FlareApp/FlareInspectorFill.swift`, `Sources/FlareModel/FlarePaint.swift`, `Tests/FlareModelTests/FlarePaintAlphaTests.swift`, `Tests/mutations/FlareModel.FlarePaint.json` | FG-2, suiteui gradient-fill C3 (the opacity colour row and the kernel's opt-in no fill, cross-line) | ~160, 4 |

## Build waves

- Wave 1: FG-1. Independent in this wave: FG-1 alone.
- Wave 2: FG-2, FG-5, FG-6. Independent in this wave: all three.
- Wave 3: FG-3, FG-4. Independent in this wave: both.
- Wave 4: FG-7. Independent in this wave: FG-7 alone.
- Wave 5: FG-8 (shared prose, `feature-done`, final). Independent in this wave: FG-8 alone.
- With its slice (gap audit C3, added 2026-10-21): FG-9, after FG-2 and the suiteui C3 pull request.

Longest chain: FG-1 → FG-2 → FG-4 → FG-7 → FG-8 (5). Chain of 5: the
section needs the readout, the journey drives the section, FG-7 turns it on
live, FG-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FG-1 | the suite compiles, disabled; old files decode | a file fails to open | – (stub) |
| FG-2 | `FlareGradientSnapshots.fillGradient` (FG-3's, first in the slice PR): FILL on a gradient shows its stops, no "Gradient" word | the word is back | – (UI) |
| FG-3 | `FlareGradientSnapshots`; `RenderBudgetFlareGradientTests.stopDragInThreeBodies` | budget over | – (UI) |
| FG-4 | compiles, skipped | – | – |
| FG-5 | `FlareGradientTests`: `fill.angle` 90 rewrites start and end to the bounds' top and bottom middle; a stop colour keeps the points; two shapes take one undo step; a 120-move drag is one step; RJ-F31 passes on Linux | points, steps or the export are wrong | `FlareModel.FlareFill+Kernel`: angle edit writes stops only → `.angleRewritesPoints`; one step per shape → `.oneStepForSeveral`; drag token dropped → `.dragIsOneStep` |
| FG-6 | `FlarePaintGradientTests`: two different gradients read Mixed; the same gradient reads it; `setFill(hex:)` on a gradient makes it solid | a readout or the setter is wrong | `FlareModel.FlarePaint`: gradients compared by type only → `.differingGradientsAreMixed`; refusal kept → `.solidReplacesGradient` |
| FG-7 | `FlareGradientJourneyTests.testEditImportedGradient` steps 1 to 5 | a step fails | – |
| FG-8 | `scripts/waves render --dry-run` | status not built | – |
| FG-9 | `FlarePaintAlphaTests`: a fill set at 50% stores alpha 0.5, a hex set after it keeps 0.5, a stroke colour keeps its alpha; a linear fill at 45° switched to radial and back reads 45° after a save and open | the alpha resets to 1 | `FlareModel.FlarePaint`: alpha forced to 1 → `.fillKeepsAlpha`; hex setter drops alpha → `.hexKeepsAlpha` |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample stop drag with the stage live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetFlareGradientTests.stopDragInThreeBodies` |
| One gesture, one step | a stop drag, an angle scrub, a type switch | `FlareGradientTests.dragIsOneStep` |
| No dead controls; first-use clarity | the gradient row shows its colours, never only a word | `FlareGradientSnapshots` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FG-m merged-done with RJ-F31 green in the
Linux job; FG-u's feel gate and `Mac-Finish:`; FG-z's journey on live. Then
`Belt-Contact-Sheet:` with `flare-fill-*`.

## Not in this packet

Gradient strokes, on-stage gradient handles, keyframed gradient stops,
diamond and angular types.
