# Feature packet: pen-paths (Flare)

**Feature:** Flare's Pen moves onto the shared kernel pen, and Direct Select
learns to drag anchors. The Pen's behaviour doesn't change: click corners,
drag smooth points, click the first anchor to close, Return to finish, the
same tolerances on screen, the same "Add Path" step, and every existing pen
test passes unchanged. Its rules leave `LiveShapes` for SuiteKernel's
`PenRules` through one adapter. Direct Select (A) keeps picking whole items
and, once one is picked, shows its anchors and handles through SuiteUI's
`PathEditOverlay`: drag an anchor and only it and its handles move (RJ-F27),
drag a handle, Option to break it, marquee anchors, Delete removes them. Each
edit is one step under the kernel path command's title ("Move Points",
"Move Handle", ...) through the existing `setPath` service, one drag token is
one step, and every param is document space (SuiteKernel `PathCommands`), so
the CLI and an agent edit points the same way.
**Line:** `line:flare` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/pen-paths`
**Beta:** captain, 2026-10-20 (the Pen shared from Flare). Labels `beta` and
`p1` when filed.

**Covers:** feature map `flare/pen-paths` (adopter of S25); real job RJ-F27
(drag one anchor and its handles; re-placed from `J` to `C`, since what moved
is in the saved file); the 5,000-anchor stress gate on Flare's stress
document.

**Depends on:** `suiteui/pen-paths` **PN-a** (cross-line: the `Paths/`
module, `PathEditTarget`, the specs, the overlay stubs, and the core bump PN-1
waits on). FP-5 needs its real `PenRules` (**PN-5**), FP-7 its real
`AnchorEdit` and `AnchorIndex` (**PN-5**, **PN-6**), FP-6 its real commands
(**PN-7**), FP-3 the real overlay (**PN-3**). FP-8 needs branch
`test/stress-perf-journeys` on `dev` (`FlareFixtures.stress`,
`FlareRealPerfJourneyTests`). Same line, the last owner of each shared file:
shape-tools **FS-a** (`FlareWorkspace.swift`) and **FS-m** (`LiveShapes.swift`
and its plan); stage-edit (`FlareDrag.swift`, `FlareSelection.swift`; no
slices); file-flow **FL-m** (the catalog and its id list) and **FL-z**
(`flare.md`).

**Hand-offs** (cross-line files; the lead checks each before the task):
`FlareWorkspace.swift` is also adopt-kernel-undo's AU-flare (FP-1),
`FlareSelection.swift` adopt-kernel-selection's AS-flare (FP-7), and the
catalog with `FlareCommandCatalogTests.swift` adopt-command-catalog's AC-flare
(FP-6): each starts after that slice's `Belt-Slice-Done:`.

**Rule 20.** Flare's pen rules are the copy that moves. FP-5 deletes
`LiveShapes.pen`, `outHandle`, `segment`, `mirror`, `near`, `distinct` and
`spans`, the fake's pen half in `FakeShapes.swift`, and
`FlarePenFinish.swift` (its `finishPath` and `finishPathHelp` keep their
signatures in `FlarePen+Kernel.swift`, now calling `PenRules`). `ShapeDraft`
keeps its public fields and init, which 21 tests construct: for a pen draft
`anchors`, `smoothAnchors` and `isClosed` become views of a stored
`pen: PenDraft`, and the init builds it. The two adapters are
`FlarePen+Kernel.swift` and `FlareAnchors+Kernel.swift`; no new Flare type.

**The oracle for "behaviour unchanged":** these suites pass with no edit:
`FlarePenCloseRadiusTests`, `FlarePenDegenerateTests`, `FlarePenFinishTests`,
`FlarePenStageScaleTests`, `FlarePenToleranceTests`, `LiveShapesTests`,
`ShapeFakesTests`, `FlareToolsTests`, `FlareToolSwitchTests`,
`LiveStageJourneyTests`, and `FlareStageSnapshots`' pen states. The draft's
element list stays byte-identical, including the trailing `move` that holds a
lone smooth first anchor's handle (FP-5's adapter writes it when the
contour has one anchor with an out handle).

**Render path.** Unchanged for the art: the stage and `StageRasterizer` draw
the stored `FlareShape.path`, and the SVG and Lottie writers export it. The
overlay draws marks only, over the stage, at the shape's layer transform for
the playhead.

Blueprint sections: flare.md 2 (stage gestures, Direct Select), 6.2 (shape
contracts), 8.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FP-a | The two adapters exist as stubs, `FlareWorkspace` conforms to `PathEditTarget` on them, and Direct Select shows the picked item's anchors through the overlay. | FP-1, FP-2 | MJ-FP | suiteui/pen-paths PN-a (cross-line); shape-tools:FS-a (FP-1) |
| FP-u | The anchor overlay's states have snapshots, an anchor drag stays in its render budget, and the journey is written. | FP-3, FP-4 | FJ-P1 | FP-a; PN-3 (FP-3, cross-line) |
| FP-m | The Pen runs on `PenRules` with every existing pen test unchanged, and the twelve path commands run on Flare's catalog. | FP-5, FP-6 | MJ-FP | FP-a; PN-5 (FP-5), PN-7 (FP-6), cross-line; shape-tools:FS-m (FP-5); file-flow:FL-m (FP-6) |
| FP-e | Direct Select drags an anchor and only its handles move, as one "Edit Path" step, and selecting and dragging 5,000 anchors on the stress document stays in budget. | FP-7, FP-8 | MJ-FP, FJ-P2 | FP-a; PN-5 and PN-6 (FP-7, cross-line); stage-edit (FP-7); branch test/stress-perf-journeys (FP-8) |
| FP-z | The journey passes on live services, and flare.md says Direct Select edits points. | FP-9, FP-10 | FJ-P1 | FP-u, FP-m, FP-e; file-flow:FL-z (FP-10) |

FP-u waits only on FP-a (rule 18); FP-m and FP-e never wait on FP-u, nor on
each other (their adapters are separate files).

## Journey steps

1. Choose the Pen (P) and draw a four-point path, one point dragged
   (`FlarePenJourneyTests.testPenThenDragAnchor`): it draws exactly as
   before; click the first anchor: "Path 1" in the layers panel.
2. Choose Direct Select (A), click the path: the item is picked and its four
   anchors show (FP-2).
3. Drag the smooth anchor 30 pt: it and its handles move, the other three
   don't (FP-7). Undo: one step, "Undo Move Points".
4. Option-drag its out handle: the in handle stays (a corner now).
5. Marquee two anchors, press Delete: the path keeps two anchors.
6. Stress (FP-8, `FlareRealPerfJourneyTests.testStressAnchors`): open the
   stress document, Direct Select, ⌘A picks every item, marquee all 5,000
   anchors, drag them for 3 s: step p95 ≤ 33 ms.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F27 | closes (now `S25`; re-placed `J` → `C`) | C | `Tests/RealJobs/flare/anchor-drag/anchor-drag.jobs.json`: `tool.direct-select`, select the shape, `path.anchor-select` anchor 2, `path.anchor-move` 30, 0; save | `input/four-points.flare` (one shape, a closed four-anchor path, anchor 2 smooth) |

Trap: Direct Select moves the whole shape, as it does today ("acts like
Select"). Assertion: in the saved file anchor 2 and both its handles moved by
(30, 0) and anchors 0, 1 and 3 are byte-equal to the input. Mutation:
`FlareModel.FlareAnchors+Kernel.json`, the move applied to every anchor of the
item → `FlareAnchorEditTests.onlyPickedAnchorsMove`.

## Screens and states

`flare-direct-anchors` (a picked path with its anchors), `flare-direct-anchor-
selected` (one anchor filled with handles), `flare-pen-drawing` (updated only
if the overlay changes the marks; the art is unchanged), light and dark.

## Contract slice

```swift
// Sources/FlareModel/FlarePen+Kernel.swift (FP-1 stubs forwarding to today's code, FP-5 bodies)
extension ShapeDraft {
    public var pen: PenDraft? { get set }                    // the stored source of truth for a pen draft
}
extension FlareWorkspace {
    public var penDraft: PenDraft? { get set }               // `draft` when it is a pen draft
    public mutating func addPath(_ path: VectorPath, name: String) throws -> String   // "Add Path" through LiveShapes.commit
    public var finishPathHelp: String? { get }               // moved from FlarePenFinish.swift, same text
    public mutating func finishPath()                        // moved, same behaviour
}
// Sources/FlareModel/FlareAnchors+Kernel.swift (FP-1 stubs, FP-7 bodies)
extension FlareWorkspace: PathEditTarget {
    public var pathInEdit: PathInEdit? { get }               // the one direct-selected shape item, toDocument = its layer at the playhead
    public var anchorSelection: Selection<AnchorRef> { get set }
    public var pathHelp: String? { get }                     // lockedHelp, "Select one shape with Direct Select to edit its points."
    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws  // services.shapes.setPath, titled `name`; one drag token folds into one step
    public mutating func runPath(_ intent: PathIntent)       // the intent's command through `catalog`
}
// Sources/FlareModel/FlareWorkspace.swift (FP-1): one stored field.
var anchorSelectionStore: Selection<AnchorRef>               // cleared when the item selection changes
```

## Pseudocode

- **Pen (FP-5).** `LiveShapes.draft(.pen, from:to:…)` becomes
  `PenRules.add(start, handleOut: drag == start ? nil : drag, to: previous?.pen,
  scale: stageScale)`, or `PenRules.closed` when `PenRules.closes`; the
  `ShapeDraft` it returns carries `pen` and a `FlareShape` whose path is
  `PenRules.path(pen)` (plus the lone-handle `move`), fill clear and default
  stroke as today. `commit` throws `PenRules.degenerate` where it threw
  `degeneratePath`. The fake's pen calls the same function.
- **Direct Select (FP-7).** On press with one item picked: `AnchorIndex.hit`
  (built once per gesture from `pathInEdit`) wins over the item hit; an
  anchor or handle hit starts an anchor drag, which previews by drawing the
  edited path in the overlay and commits once on mouse-up through
  `runPath(.move(…, drag:))` or `.handle`, so the undo stack gets one "Edit
  Path". An empty press starts an anchor marquee while an item is picked.
  The document offset maps through the inverse of `toDocument` (Flare's
  `layerMoves` rule, #554).
- **Stress (FP-8).** `FlareAnchorBudgetTests` builds a document laid out
  like `FlareFixtures.stress` (500 ten-point stars, in the test, so it needs
  no branch), picks every item, then times one `anchorSelection` select-all over 5,000
  anchors and one 5,000-anchor move preview.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FP-1 | – | The two adapters as stubs forwarding to today's code; `ShapeDraft.pen`; the anchor selection field; `FlarePenKernelTests` (with the drafts today's code gives for 200 seeded click and drag sequences recorded as its expected values) `FlareAnchorEditTests` and `FlarePathCommandTests` written, disabled | `Sources/FlareModel/FlarePen+Kernel.swift`, `Sources/FlareModel/FlareAnchors+Kernel.swift`, `Sources/FlareModel/FlareWorkspace.swift`, `Tests/mutations/FlareModel.FlareWorkspace.json`, `Tests/FlareModelTests/FlarePenKernelTests.swift`, `Tests/FlareModelTests/FlareAnchorEditTests.swift`, `Tests/FlareModelTests/FlarePathCommandTests.swift` | PN-a, shape-tools:FS-a | ~300, 7 |
| FP-2 | – | `PathEditOverlay` over the stage for Direct Select and the Pen, on the stubs, intents to `runPath` | `Sources/FlareApp/FlareWindow+Stage.swift` | FP-1 | ~120, 1 |
| FP-3 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareAnchorSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareAnchorTests.swift` | FP-2, PN-3 | ~180, 2 |
| FP-4 | – | The journey, written and skipped (`XCTSkip("waits on FP-9")`) | `UITests/FlareJourneyTests+Pen.swift` | FP-2 | ~100, 1 |
| FP-5 | – | The Pen on `PenRules`: `LiveShapes` and the fake call it; the pen helpers and `FlarePenFinish.swift` go; `ShapeDraft`'s pen fields become views; the plans repointed; the oracle suites pass unedited; turns on `FlarePenKernelTests` | `Sources/FlareModel/FlarePen+Kernel.swift`, `Sources/FlareModel/Live/LiveShapes.swift`, `Sources/FlareModel/Fakes/FakeShapes.swift`, `Sources/FlareModel/Contracts/ShapeContracts.swift`, `Sources/FlareModel/FlarePenFinish.swift`, `Tests/FlareModelTests/FlarePenKernelTests.swift`, `Tests/mutations/FlareModel.LiveShapes.json`, `Tests/mutations/FlareModel.FlarePenFinish.json`, `Tests/mutations/FlareModel.FlarePen+Kernel.json` | FP-1, PN-5, shape-tools:FS-m | ~340, 9 |
| FP-6 | – | The twelve specs in the catalog, the id list and the CLI golden; turns on `FlarePathCommandTests` | `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/mutations/FlareModel.FlareCommandCatalog.json`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json`, `Tests/FlareModelTests/FlarePathCommandTests.swift` | FP-1, PN-7, file-flow:FL-m | ~150, 5 |
| FP-7 | – | Direct Select anchor editing: the adapter bodies, the press routing in the stage gesture, the anchor marquee; RJ-F27's job folder; turns on `FlareAnchorEditTests`; `FlareAnchorBudgetTests` written, disabled | `Sources/FlareModel/FlareAnchors+Kernel.swift`, `Sources/FlareModel/FlareDrag.swift`, `Sources/FlareModel/FlareSelection.swift`, `Tests/FlareModelTests/FlareAnchorEditTests.swift`, `Tests/FlareModelTests/FlareAnchorBudgetTests.swift`, `Tests/mutations/FlareModel.FlareAnchors+Kernel.json`, `Tests/RealJobs/flare/anchor-drag/anchor-drag.jobs.json`, `Tests/RealJobs/flare/anchor-drag/input/four-points.flare` | FP-1, PN-5, PN-6, stage-edit | ~390, 8 |
| FP-8 | – | Turns on the 5,000-anchor budget (Linux, `.serialized`) and adds the real-app stress journey on anchors | `Tests/FlareModelTests/FlareAnchorBudgetTests.swift`, `UITests/FlareJourneyTests+RealPerfAnchors.swift` | FP-7, branch test/stress-perf-journeys | ~140, 2 |
| FP-9 | – | Live: the journey turned on, on live services | `UITests/FlareJourneyTests+Pen.swift` | FP-4, FP-5, FP-7 | ~40, 1 |
| FP-10 | – | flare.md: Direct Select edits points, the Pen is kernel-shared; `status: built`; `feature-done` | `docs/blueprints/flare.md`, `docs/blueprints/flare/features/pen-paths.wave.json` | FP-9, FP-6, FP-8, FP-3, file-flow:FL-z | ~30, 2 |

## Build waves

- Wave 1: FP-1. Independent in this wave: FP-1 alone.
- Wave 2: FP-2, FP-5, FP-6, FP-7. Independent in this wave: all four.
- Wave 3: FP-3, FP-4, FP-8. Independent in this wave: all three.
- Wave 4: FP-9. Independent in this wave: FP-9 alone.
- Wave 5: FP-10 (shared prose, `feature-done`, final). Independent in this wave: FP-10 alone.

Longest chain: FP-1 → FP-2 → FP-4 → FP-9 → FP-10 (5). Chain of 5: the
overlay needs the adapters, the journey drives the overlay, FP-9 turns it on
live, FP-10 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FP-1 | the suites compile, disabled; every oracle suite still passes (the stubs forward) | a stub changes behaviour | – (stub) |
| FP-2 | `FlareAnchorSnapshots.directPicked` (FP-3's, first in the slice PR): Direct Select on a path shows its anchors | the overlay is missing | – (UI) |
| FP-3 | `FlareAnchorSnapshots`; `RenderBudgetFlareAnchorTests.anchorDragInThreeBodies` | budget over | – (UI) |
| FP-4 | compiles, skipped | – | – |
| FP-5 | the oracle suites pass unedited; `FlarePenKernelTests`: for 200 seeded click and drag sequences the draft's `FlareShape` (points, path elements, closed) equals FP-1's recording of today's code; `finishPathHelp` reads its two reasons verbatim | one element or reason differs | `FlareModel.FlarePen+Kernel`: the lone-handle `move` dropped → `FlarePenKernelTests.loneSmoothFirstAnchorKeepsHandle`; `scale` not passed (tolerance in scene points) → `FlarePenStageScaleTests` (existing); `minimumFinishAnchors` 1 → `FlarePenFinishTests` (existing, its plan entry moved here) |
| FP-6 | `FlarePathCommandTests`: the twelve ids are in `catalog`; `path.draw` adds a "Path 1" layer in one step; `path.read` reads it back | an id is missing or a run takes two steps | `FlareModel.FlareCommandCatalog`: path specs left out → `.pathSpecsRegistered` |
| FP-7 | `FlareAnchorEditTests`: an anchor drag moves only it and its handles and is one "Edit Path" step; a handle drag on a smooth anchor turns its partner; Option breaks it; the marquee picks anchors only of the picked item; a locked layer refuses with its help; a layer scaled 2× maps a 30 pt drag to 15 in the path; RJ-F27 passes on Linux | the whole item moves, a handle is wrong, or a step count is wrong | `FlareModel.FlareAnchors+Kernel`: move applied to every anchor → `.onlyPickedAnchorsMove`; offset not mapped through the layer → `.scaledLayerDrag`; anchor hit after item hit → `.anchorWinsOverItem` |
| FP-8 | `FlareAnchorBudgetTests` (reported in release; gated ratio): select-all of 5,000 anchors ≤ 4 ms, one move preview ≤ 8 ms, 10,000 under 3 × 5,000; `FlareRealPerfJourneyTests.testStressAnchors` under the branch's 33 ms step p95 | a pass turns quadratic or the drag stutters | – (budget) |
| FP-9 | `FlarePenJourneyTests.testPenThenDragAnchor` steps 1 to 5 on live | a step fails | – |
| FP-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample anchor drag with the stage live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetFlareAnchorTests.anchorDragInThreeBodies` |
| Many anchors (VectorCraft) | 5,000 anchors on `FlareFixtures.stress`: select-all ≤ 4 ms, move preview ≤ 8 ms, linear; real app step p95 ≤ 33 ms | `FlareAnchorBudgetTests`, `FlareRealPerfJourneyTests.testStressAnchors` |
| Behaviour unchanged | every oracle suite passes with no edit | the FP-5 PR's `scripts/ci --changed` |
| One gesture, one step | an anchor drag, a handle drag, a pen path | `FlareAnchorEditTests`, `FlarePenFinishTests` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FP-m merged-done with the oracle suites
green and unedited; FP-e merged-done with RJ-F27 green in the Linux job and
`FlareAnchorBudgetTests` gated rows green; FP-u's feel gate and
`Mac-Finish:`; FP-z's journey on live. Then `Belt-Contact-Sheet:` with
`flare-direct-anchor*`.

## Not in this packet

Editing points of a shape with shape keys (refused: "This shape is animated;
edit its keys in the timeline."), booleans, a curvature pen, point snapping
to curves, Halo (it draws no paths).
