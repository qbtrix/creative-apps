# Feature packet: stroke-style (Flare)

**Feature:** Flare's STROKE section becomes SuiteUI's `StrokeEditor`: colour,
width, join, cap, dashes and trim paths, under the gradient editor. Trim
Start, End and Offset key like stroke width (the `trimStart.<i>`,
`trimEnd.<i>` and `trimOffset.<i>` Double tracks creative-core's stroke-style
adds), so a logo draws itself on with two keys on Trim End; the stage, PNG,
SVG and Lottie draw it.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/stroke-style`
**Beta:** captain, 2026-10-20 (trim paths: map weight high). Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/stroke-style` (adopter of S17); real job RJ-F02
(draw a logo stroke on with trim paths, 0 → 100% over 1.5 s, export Lottie).

**Depends on:** `suiteui/stroke-style` **SS-a** (cross-line); FK-5 and FK-6
need **SS-d** and the creative-core bump with path-geometry and stroke-style
(the Lottie `tm` writer and the trim tracks live there), FK-4 **SS-u**. Same
line: gradient-fill's **FG-a** before FK-2 (`FlareInspectorFill.swift`) and
**FG-m** before FK-6 (the catalog and id list); shape-tools' **FS-m** before
FK-6. Built: live-stage, inspector-timeline (key diamonds), flare-export.

**Hand-offs:** `StagePath.swift` is also adopt-suiteui-chrome's (AC-colour):
FK-3's paint change rebases onto it.

**Rule 20.** FlareCore's `Stroke` is already the kernel's `VectorStroke`, so
Flare adds only the adapter `FlareStroke+Kernel.swift` (over the engine's
`shape.setStroke`) and keys trim through the keyframe commands it has.

**Render path.** The stage strokes `StrokeRules.paintedPath` of each shape at
the frame (trim sampled from its tracks) through `StagePath`; PNG through
`StageRasterizer` the same; SVG and Lottie are core's writers. No new route.

Blueprint sections: flare.md 6 (inspector: STROKE), 8 (export).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FK-a | The adapter is declared as stubs and STROKE is the shared editor with keyable trim rows. | FK-1, FK-2 | MJ-FK | gradient-fill:FG-a |
| FK-u | The stage and PNG stroke the painted path with joins, caps and dashes, and the snapshots and render budget hold. | FK-3, FK-4 | J-FK | FK-a |
| FK-m | Every stroke command is one step for the selection, trim keys at the playhead when animated, and the commands run from the catalog. | FK-5, FK-6 | MJ-FK | FK-a, gradient-fill:FG-m, shape-tools:FS-m |
| FK-z | The journey draws a logo on with trim keys on live services, and the feature is built. | FK-7, FK-8 | J-FK | FK-u, FK-m |

FK-u waits only on FK-a (rule 18); FK-m never waits on FK-u. MJ-FK is the
Model walk in `FlareStrokeTests` (Linux).

## Journey steps

1. Select the logo path, set Width 6 and Round cap in STROKE (FK-2,
   `FlareStrokeJourneyTests.testTrimDrawOn`).
2. At 0 s click Trim End's diamond with End 0%; at 1.5 s set End 100%: two keys.
3. Play: the stroke draws itself on over 1.5 s on the stage.
4. Export Lottie (FK-6): the file has a trim shape with two keys.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F02 | closes (now `flare/stroke-style`) | C | `Tests/RealJobs/flare/trim-draw-on/trim-draw-on.jobs.json`: `edit.select-all`, `stroke.width {"width": 6}`, `keyframe.set` on `trimEnd.0` at 0 (0) and 45 (1), export Lottie at 30 fps | `input/logo-path.flare` |

Trap: the trim keys land on the base value (no animation) or export as a
static dash. Assertion: the Lottie has a `tm` item whose `e` is animated with
keys at frames 0 and 45 (0 and 100) and the stroke width 6. Mutation:
`FlareModel.FlareStroke+Kernel.json` (trim written as the base when animated
→ `.trimKeysWhenAnimated`).

## Screens and states

`flare-stroke-editor` (light and dark), `-trim-keyed`, `-dashed` (the stage).

## Contract slice

```swift
// Sources/FlareModel/FlareStroke+Kernel.swift (FK-1 stubs, FK-5 bodies)
extension FlareWorkspace: StrokeTarget {
    public var strokeHelp: String? { get }               // "Select a shape layer." / a text-only selection
    public var trimHelp: String? { get }                 // nil: Flare trims
    public var selectedStroke: VectorStroke? { get }     // trim sampled at the playhead
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws   // through shape.setStroke
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FK-1 | – | The adapter as stubs; `FlareStrokeTests` written, disabled | `Sources/FlareModel/FlareStroke+Kernel.swift`, `Tests/FlareModelTests/FlareStrokeTests.swift` | – | ~110, 2 |
| FK-2 | – | STROKE becomes `StrokeEditor` with key diamonds on the trim rows, on the stubs; the journey written, skipped | `Sources/FlareApp/FlareInspectorFill.swift`, `UITests/FlareJourneyTests+Stroke.swift` | FK-1 | ~180, 2 |
| FK-3 | – | The stage and PNG stroke `StrokeRules.paintedPath` with join and cap | `Sources/FlareApp/StagePath.swift`, `Sources/FlareApp/StageRasterizer.swift`, `Tests/AppSnapshotTests/FlareStrokePaintTests.swift` | FK-2 | ~160, 3 |
| FK-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareStrokeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareStrokeTests.swift` | FK-3 | ~160, 2 |
| FK-5 | – | Adapter bodies (through `shape.setStroke`; trim keyed through the keyframe commands when animated); turns on `FlareStrokeTests` | `Sources/FlareModel/FlareStroke+Kernel.swift`, `Tests/FlareModelTests/FlareStrokeTests.swift`, `Tests/mutations/FlareModel.FlareStroke+Kernel.json` | FK-1 | ~240, 3 |
| FK-6 | – | The nine specs in the catalog and id list; RJ-F02's job folder | `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/FlareModelTests/FlareStrokeCommandIDTests.swift`, `Tests/RealJobs/flare/trim-draw-on/trim-draw-on.jobs.json`, `Tests/RealJobs/flare/trim-draw-on/input/logo-path.flare` | FK-5 | ~120, 5 |
| FK-7 | – | The journey turned on, on live services | `UITests/FlareJourneyTests+Stroke.swift` | FK-4, FK-6 | ~50, 1 |
| FK-8 | – | `status: built`; `feature-done` | `docs/blueprints/flare/features/stroke-style.wave.json` | FK-7 | ~10, 1 |

## Build waves

- Wave 1: FK-1. Independent in this wave: FK-1 alone.
- Wave 2: FK-2, FK-5. Independent in this wave: both.
- Wave 3: FK-3, FK-6. Independent in this wave: both.
- Wave 4: FK-4. Independent in this wave: FK-4 alone.
- Wave 5: FK-7. Independent in this wave: FK-7 alone.
- Wave 6: FK-8 (`feature-done`, final). Independent in this wave: FK-8 alone.

Longest chain: FK-1 → FK-2 → FK-3 → FK-4 → FK-7 → FK-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FK-1 | `FlareStrokeTests` compiles, disabled | – | – (stub) |
| FK-2 | `FlareInspectorSnapshots`: STROKE is the shared editor with trim rows and their key diamonds on the stubs | the editor or diamonds are missing | – (UI) |
| FK-3 | `FlareStrokePaintTests`: the stage strokes the painted path with join and cap; a dashed stroke leaves gaps | the stage strokes plainly | – (UI) |
| FK-4 | `FlareStrokeSnapshots`; `RenderBudgetFlareStrokeTests.trimScrubInThreeBodies` | budget over | – (UI) |
| FK-5 | `FlareStrokeTests`: each stroke command on two selected shapes is one step; trim on an animated Trim End keys at the playhead; width clamps | a step or a key is wrong | `FlareModel.FlareStroke+Kernel`: trim written as the base → `.trimKeysWhenAnimated`; one step per shape → `.oneStepForSeveral` |
| FK-6 | the nine specs listed; RJ-F02 passes on Linux | the Lottie has no animated trim | – (registration; the trap's mutation sits in FK-5's plan) |
| FK-7 | `testTrimDrawOn` steps 1 to 4 on live | a step fails | – |
| FK-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Trim End scrub with the stage live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetFlareStrokeTests.trimScrubInThreeBodies` |
| Playback | a trimmed, dashed 30-shape scene plays within the stage's frame budget | `FlareStrokeTests.playsWithinBudget` |
| One gesture, one step | a scrub, a chip, a preset each one step | `FlareStrokeTests.oneStepPerGesture` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FK-m merged-done with RJ-F02 green in the
Linux job; FK-u's feel gate and `Mac-Finish:`; FK-z's journey on live. Then
`Belt-Contact-Sheet:` with `flare-stroke-*`.

## Not in this packet

Keyed stroke colour (E14), gradient strokes, trim on text.
