# Feature packet: stroke-style (Halo)

**Feature:** Halo's shape layers take a stroke: colour, width, join, cap,
dashes and trim paths, through SuiteUI's `StrokeEditor` in the layer
inspector under the gradient editor. Trim Start, End and Offset are Halo
properties, so they key like position: a draw-on is two keys on Trim End.
The frame renderer draws the stroke as the outline of the painted path, the
route the shapes take.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/stroke-style`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/stroke-style` (adopter of S17); real job RJ-H30
(a star with a gradient fill and a stroke; now closes here).

**Depends on:** `suiteui/stroke-style` **SS-a** (cross-line); HK-5 and HK-6
need **SS-d** (dashes, trim and `Path.outlined` after the creative-core bump),
HK-4 **SS-u**. Same line: shape-tools' **HS-a** before HK-1 (`HaloLayer.swift`)
and **HS-m** before HK-5 and HK-6 (`HaloOutlines.swift`, the catalog);
gradient-fill's **HG-u** before HK-2 (`HaloLayerInspector.swift`) and **HG-m**
before HK-5 (`LiveFrameRendering.swift`). Built: foundation, layer-keys,
core-loop.

**Hand-offs:** `Contracts/HaloValues.swift` is adopt-kernel-easing's
(AE-halo): HK-5's three `HaloProperty` cases rebase onto it.

**Rule 20.** `HaloLayer.stroke` is the kernel's `VectorStroke`; the stroke's
outline is FlareCore's `Path.outlined` of `StrokeRules.paintedPath`. The
adapter is `HaloStroke+Kernel.swift`; trim values are `HaloProperty` tracks,
never a second keyframe store.

**Render path.** `LiveFrameRendering` draws a stroked layer's fill, then the
stroke's outline polygon (from `HaloOutlines`) in the stroke colour, with the
layer's opacity and blend. No new route.

Blueprint sections: halo.md 6 (layer inspector), 7 (render).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HK-a | Shape layers carry a stroke, the adapter is declared as stubs, and the shared stroke editor shows in the layer inspector. | HK-1, HK-2 | MJ-HK | shape-tools:HS-a, gradient-fill:HG-u |
| HK-u | The trim rows carry key diamonds, and the snapshots and render budget hold. | HK-3, HK-4 | J-HK | HK-a |
| HK-m | The renderer draws the trimmed, dashed stroke outline after the fill, trim keys at the playhead, and every stroke command is one step. | HK-5, HK-6 | MJ-HK | HK-a, shape-tools:HS-m, gradient-fill:HG-m |
| HK-z | The journey strokes a star and draws it on on live services, and the feature is built. | HK-7, HK-8 | J-HK | HK-u, HK-m |

HK-u waits only on HK-a (rule 18); HK-m never waits on HK-u. MJ-HK is the
Model walk in `HaloStrokeTests` (Linux).

## Journey steps

1. Select a star shape layer, click Add Stroke (HK-2,
   `HaloStrokeJourneyTests.testStrokeDrawOn`): a 1 pt black stroke; the editor
   shows Width, Join, Cap, Dash and Trim.
2. Width 8, Round join: the viewer's star outline thickens and rounds.
3. At 0 s key Trim End at 0%, at 1 s at 100% (HK-3): playing draws the outline
   on.
4. Render frames 0, 12 and 24 (HK-6): nothing, half, the whole outline.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H30 | closes (now `halo/stroke-style`) | C | `Tests/RealJobs/halo/star-stroke/star-stroke.jobs.json`: `shape.draw` star, `fill.type {"type": "linear"}`, `stroke.add`, `stroke.width {"width": 8}`, `render.frame {"frame": 0}` | `input/empty-1080p.halo` |

Trap: the stroke is drawn as a filled shape (the star's inside painted the
stroke colour) or skipped by Render… while the viewer shows it. Assertion: a
pixel on the star's edge is the stroke colour, the centre pixel is the
gradient's colour there. Mutation: `HaloModel.LiveFrameRendering.json`
(stroke filled instead of outlined → `.strokeIsOutline`).

## Screens and states

`halo-stroke-editor` (light and dark), `-trim-keyed` (key diamonds on the
trim rows).

## Contract slice

```swift
// Sources/HaloModel/HaloLayer.swift (HK-1): stored, omitted when nil.
public var stroke: VectorStroke?
// Sources/HaloModel/HaloStroke+Kernel.swift (HK-1 stubs, HK-6 bodies)
extension HaloProject: StrokeTarget {
    public var strokeHelp: String? { get }                  // "Strokes are for shape layers."
    public var trimHelp: String? { get }                    // nil: Halo trims
    public var selectedStroke: VectorStroke? { get }        // trim sampled at the playhead
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws
}
// Sources/HaloModel/Contracts/HaloValues.swift (HK-5): HaloProperty gains trimStart, trimEnd, trimOffset.
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HK-1 | – | `HaloLayer.stroke` (omitted when nil); the adapter as stubs; `HaloStrokeTests` written, disabled | `Sources/HaloModel/HaloLayer.swift`, `Sources/HaloModel/HaloStroke+Kernel.swift`, `Tests/HaloModelTests/HaloStrokeTests.swift` | – | ~140, 3 |
| HK-2 | – | `HaloStrokeInspector` (the shared editor) in the layer inspector for shape layers on the stubs; the journey written, skipped | `Sources/HaloApp/HaloStrokeInspector.swift`, `Sources/HaloApp/HaloLayerInspector.swift`, `UITests/HaloJourneyTests+Stroke.swift` | HK-1 | ~160, 3 |
| HK-3 | – | Key diamonds on the trim rows; their tests | `Sources/HaloApp/HaloStrokeInspector.swift`, `Tests/AppSnapshotTests/HaloStrokeInspectorTests.swift` | HK-2 | ~140, 2 |
| HK-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloStrokeSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloStrokeTests.swift` | HK-3 | ~160, 2 |
| HK-5 | – | The renderer draws the stroke's outline (trimmed at the frame, dashed) after the fill; the three trim properties | `Sources/HaloModel/Live/HaloOutlines.swift`, `Sources/HaloModel/Live/LiveFrameRendering.swift`, `Sources/HaloModel/Contracts/HaloValues.swift`, `Tests/HaloModelTests/HaloStrokeRenderTests.swift`, `Tests/mutations/HaloModel.LiveFrameRendering.json`, `Tests/mutations/HaloModel.HaloOutlines.json` | HK-1 | ~300, 6 |
| HK-6 | – | Adapter bodies (trim keyed when animated); the nine specs in the catalog and id list; turns on `HaloStrokeTests`; RJ-H30's job folder | `Sources/HaloModel/HaloStroke+Kernel.swift`, `Tests/HaloModelTests/HaloStrokeTests.swift`, `Tests/mutations/HaloModel.HaloStroke+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/RealJobs/halo/star-stroke/star-stroke.jobs.json`, `Tests/RealJobs/halo/star-stroke/input/empty-1080p.halo` | HK-5 | ~260, 7 |
| HK-7 | – | The journey turned on, on live services | `UITests/HaloJourneyTests+Stroke.swift` | HK-4, HK-6 | ~50, 1 |
| HK-8 | – | `status: built`; `feature-done` | `docs/blueprints/halo/features/stroke-style.wave.json` | HK-7 | ~10, 1 |

## Build waves

- Wave 1: HK-1. Independent in this wave: HK-1 alone.
- Wave 2: HK-2, HK-5. Independent in this wave: both.
- Wave 3: HK-3, HK-6. Independent in this wave: both.
- Wave 4: HK-4. Independent in this wave: HK-4 alone.
- Wave 5: HK-7. Independent in this wave: HK-7 alone.
- Wave 6: HK-8 (`feature-done`, final). Independent in this wave: HK-8 alone.

Longest chain: HK-1 → HK-2 → HK-3 → HK-4 → HK-7 → HK-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HK-1 | old projects decode with no stroke; `HaloStrokeTests` compiles, disabled | an old project fails | – (stub) |
| HK-2 | `HaloInspectorSnapshots`: the stroke editor shows for a shape layer on the stubs, not for text or nulls | the editor is missing or shown for text | – (UI) |
| HK-3 | `HaloStrokeInspectorTests`: the trim rows carry key diamonds; a diamond click emits one key toggle | a diamond is missing | – (UI) |
| HK-4 | `HaloStrokeSnapshots`; `RenderBudgetHaloStrokeTests.trimScrubInThreeBodies` | budget over | – (UI) |
| HK-5 | `HaloStrokeRenderTests`: an 8 pt stroke covers the outline band and not the centre; Trim End keyed 0 → 1 over 24 frames draws half the length at frame 12; dashes leave gaps | a band, a trim or a dash is wrong | `HaloModel.LiveFrameRendering`: stroke filled → `.strokeIsOutline`; `HaloModel.HaloOutlines`: trim sampled at frame 0 → `.trimAtFrame` |
| HK-6 | `HaloStrokeTests`: each stroke command is one step; trim on an animated Trim End keys at the playhead; the nine specs listed; RJ-H30 passes on Linux | a step or a key is wrong | `HaloModel.HaloStroke+Kernel`: trim written as the base when animated → `.trimKeysWhenAnimated`; a static trim ignores the value → `.staticTrimSets` |
| HK-7 | `testStrokeDrawOn` steps 1 to 4 on live | a step fails | – |
| HK-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample Trim End scrub with the viewer live | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetHaloStrokeTests.trimScrubInThreeBodies` |
| Frame budget | a stroked 1080p frame within the existing frame budget (`HaloFrameBudgetTests`) | `HaloStrokeRenderTests.withinFrameBudget` |
| One gesture, one step | a scrub, a chip, a preset each one step | `HaloStrokeTests.oneStepPerGesture` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HK-m merged-done with RJ-H30 green in the
Linux job; HK-u's feel gate and `Mac-Finish:`; HK-z's journey on live. Then
`Belt-Contact-Sheet:` with `halo-stroke-*`.

## Not in this packet

Strokes on solids and text, gradient strokes, keyed stroke colour (E14).
