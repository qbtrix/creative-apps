# Feature packet: transform (Halo)

**Feature:** Halo's viewer gets rotate and scale handles. The selected
layer's box shows SuiteUI's `SelectionHandlesEditor`, turned with the layer;
a corner drag scales it (Shift keeps the ratio), the knob turns it (Shift
snaps 15°), and a drag inside moves it as today. Each gesture writes the
layer's `scaleX`, `scaleY`, `rotation` (and `x`, `y`) at the playhead, keyed
when the property is animated, as one step. Every edit is a SuiteKernel
transform command, so an agent can key a turn at a frame.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/transform`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/transform` (adopter of S7); real jobs RJ-H21
(rotate and scale a layer with handles in the viewer) and RJ-H34 (new: key a
turn and a scale at a frame by command).

**Depends on:** `suiteui/transform-tools` **TT-a** (cross-line); HT-5 needs
**TT-m**, HT-4 **TT-u**. Same line: autosave-history's **HA-m** before HT-6
(the catalog and id list). Built or earlier: foundation, viewer-playback,
layer-keys (the viewer drag and keying), core-loop.

**Rule 20.** No Halo transform maths: `HaloTransform+Kernel.swift` maps the
kernel's `TransformBox` onto the layer's rect and its sampled `scaleX`,
`scaleY` and `rotation`; the anchor point stays Halo's own rows. `flipHelp`
is "Flipping isn't in Halo yet."

**Render path.** None new: the frame renderer already draws `scaleX`,
`scaleY` and `rotation` through `HaloMatrix`; a drag previews through
`HaloLiveEdit` as the move drag does.

Blueprint sections: halo.md 5 (viewer), 6 (layer inspector).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HT-a | The adapter is declared as stubs and the selected layer shows its handles in the viewer. | HT-1, HT-2 | MJ-HT | – |
| HT-u | Handle drags preview live and commit once, and the snapshots and render budget hold. | HT-3, HT-4 | J-HT | HT-a |
| HT-m | A turn or scale writes the layer's tracks at the playhead, keyed when animated, as one step, and the transform commands run from the catalog. | HT-5, HT-6 | MJ-HT | HT-a, autosave-history:HA-m |
| HT-z | The journey turns and scales a layer on live services, and the feature is built. | HT-7, HT-8 | J-HT | HT-u, HT-m |

HT-u waits only on HT-a (rule 18); HT-m never waits on HT-u. MJ-HT is the
Model walk in `HaloTransformTests` (Linux).

## Journey steps

1. Select a shape layer in the viewer (HT-2, `HaloTransformJourneyTests.testRotateAndScaleInViewer`):
   its box shows eight handles and the knob.
2. Shift-drag a corner out: the layer scales in proportion; Scale X and Y read
   the same in the inspector.
3. Move the playhead to 1 s, Shift-drag the knob: 15° steps; with Rotation
   animated a key appears at 1 s.
4. Undo: the turn goes in one step.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H21 | closes (now `halo/transform`) | J | `testRotateAndScaleInViewer` steps 1 to 4 | `title.halo` |
| RJ-H34 | adds, closes with `halo/transform` | C | `Tests/RealJobs/halo/key-turn/key-turn.jobs.json`: `layer.select`, `inspector.toggle-animation {"property": "rotation"}`, `timeline.scrub {"frame": 12}`, `transform.rotate {"degrees": 30}`, `transform.scale {"sx": 2, "sy": 2, "anchor": "center"}`, save | `input/one-shape.halo` |

Trap: the turn overwrites the layer's base value instead of keying at frame
12, or the scale moves the layer off its centre. Assertion: the saved
rotation track has a key of 30 at frame 12 and the base at 0 kept; scale keys
2 at frame 12; the layer's centre is unchanged. Mutation:
`HaloModel.HaloTransform+Kernel.json` (written as the base value when animated
→ `.keysWhenAnimated`).

## Screens and states

`halo-viewer-handles` (light and dark, turned 30°), `-scaling`.

## Contract slice

```swift
// Sources/HaloModel/HaloTransform+Kernel.swift (HT-1 stubs, HT-5 bodies)
extension HaloProject: TransformTarget {
    public var transformSelection: TransformBox? { get }   // the selected layer at the playhead, composition pixels
    public var transformHelp: String? { get }              // "Select a layer to transform." / a null or text-only refusal
    public var flipHelp: String? { get }                   // "Flipping isn't in Halo yet."
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HT-1 | – | The adapter as stubs; `HaloTransformTests` written, disabled | `Sources/HaloModel/HaloTransform+Kernel.swift`, `Tests/HaloModelTests/HaloTransformTests.swift` | – | ~120, 2 |
| HT-2 | – | `HaloViewerHandles` over the selected layer in the viewer on the stubs; the journey written, skipped | `Sources/HaloApp/HaloViewerHandles.swift`, `Sources/HaloApp/HaloViewer.swift`, `UITests/HaloJourneyTests+Transform.swift` | HT-1 | ~160, 3 |
| HT-3 | – | Handle drags preview through `HaloLiveEdit` and commit once on release; Escape cancels | `Sources/HaloApp/HaloViewerHandles.swift`, `Tests/AppSnapshotTests/HaloViewerHandlesTests.swift` | HT-2 | ~180, 2 |
| HT-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloTransformSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloTransformTests.swift` | HT-3 | ~180, 2 |
| HT-5 | – | Adapter bodies: the box from the rect and sampled scale and rotation, writes keyed when animated; turns on `HaloTransformTests` | `Sources/HaloModel/HaloTransform+Kernel.swift`, `Tests/HaloModelTests/HaloTransformTests.swift`, `Tests/mutations/HaloModel.HaloTransform+Kernel.json` | HT-1 | ~240, 3 |
| HT-6 | – | The six specs in the catalog and id list; RJ-H34's job folder | `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloTransformCommandIDTests.swift`, `Tests/RealJobs/halo/key-turn/key-turn.jobs.json`, `Tests/RealJobs/halo/key-turn/input/one-shape.halo` | HT-5 | ~120, 5 |
| HT-7 | – | The journey turned on, on live services | `UITests/HaloJourneyTests+Transform.swift` | HT-4, HT-6 | ~50, 1 |
| HT-8 | – | `status: built`; `feature-done` | `docs/blueprints/halo/features/transform.wave.json` | HT-7 | ~10, 1 |

## Build waves

- Wave 1: HT-1. Independent in this wave: HT-1 alone.
- Wave 2: HT-2, HT-5. Independent in this wave: both.
- Wave 3: HT-3, HT-6. Independent in this wave: both.
- Wave 4: HT-4. Independent in this wave: HT-4 alone.
- Wave 5: HT-7. Independent in this wave: HT-7 alone.
- Wave 6: HT-8 (`feature-done`, final). Independent in this wave: HT-8 alone.

Longest chain: HT-1 → HT-2 → HT-3 → HT-4 → HT-7 → HT-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HT-1 | `HaloTransformTests` compiles, disabled | – | – (stub) |
| HT-2 | `HaloViewerSnapshots`: the handles show on the selected layer on the stubs | the handles are missing | – (UI) |
| HT-3 | `HaloViewerHandlesTests`: a corner drag previews through `HaloLiveEdit` and commits once on release; the knob turns the box | the drag commits per sample | – (UI) |
| HT-4 | `HaloTransformSnapshots`; `RenderBudgetHaloTransformTests.knobDragInThreeBodies` | budget over | – (UI) |
| HT-5 | `HaloTransformTests`: a turn at frame 12 on an animated rotation adds a key there; on a static one it sets the value; a scale about the centre keeps the centre; a 120-sample drag is one step | a key, a value or a step is wrong | `HaloModel.HaloTransform+Kernel`: base written when animated → `.keysWhenAnimated`; scale about the top-left → `.scaleAboutCentre` |
| HT-6 | the six specs listed; `transform.flip` is unavailable with `flipHelp`; RJ-H34 passes on Linux | an id is missing | – (registration) |
| HT-7 | `testRotateAndScaleInViewer` steps 1 to 4 on live | a step fails | – |
| HT-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample knob drag over a playing 1080p comp, paused | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetHaloTransformTests.knobDragInThreeBodies` |
| One gesture, one step | a drag is one step, keyed or not | `HaloTransformTests.dragIsOneStep` |
| No dead controls; keyboard parity | handles identified, Escape cancels a drag | `testRotateAndScaleInViewer` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HT-m merged-done with RJ-H34 green in the
Linux job; HT-u's feel gate and `Mac-Finish:`; HT-z's journey on live. Then
`Belt-Contact-Sheet:` with `halo-viewer-handles-*`.

## Not in this packet

Flips, a draggable anchor point in the viewer, several layers at once.
