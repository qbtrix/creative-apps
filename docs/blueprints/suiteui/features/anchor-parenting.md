# Feature packet: anchor-parenting

**Feature:** rotate and scale about a point you choose, and move a set of
layers as one by parenting them to a layer or a null. Halo already has both:
`anchorX` and `anchorY` keyed like any property, the local matrix
T(x, y) · R · S · T(−anchor) in `HaloKeyRules.localMatrix`, and parenting
through the kernel's `LayerFollow` (EK-13). This packet lifts Halo's matrix
and its keep-in-place rule into a kernel `Placement`, adds the commands and a
SuiteUI anchor mark and rows, moves Halo onto them (gaining a viewer anchor
drag, which it lacks), and brings Flare onto the same rule. In Flare today a
0 to 360 spin orbits the canvas's top-left corner (FlareCore `Transform` has no
anchor and drawn paths stay in scene space) and a set of imported layers can't
move as one (no parent field; Lottie import skips `parent`).
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/anchor-parenting`
**Beta:** captain, 2026-10-21 (beta gaps C6). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C6, evidence in `2026-10-21-gaps-flare.md` B1 and B4 and
`2026-10-21-gaps-halo.md` ("Drag the anchor point in the viewer"); feature map
row `suiteui/anchor-parenting` (new; S8's other parts, groups, clipping, lock
and solo, stay with the layer packets); real job RJ-X75 (new); RJ-F14 now
closes with it.

**Depends on:** editor-kernel, command-catalog, adopt-command-catalog (built).
**Core need (not filed):** FlareCore needs an anchor on `Transform` (matrix
T · R · S · T(−anchor), default 0 so old files draw the same), `Layer.parentID`
composed by `RenderList`, hit testing and the exporters, and Lottie `ks.a` and
`parent` read and written. Only the two Flare slices wait on that bump.
**Flare stopgap (in flight, not redone here):** branch
`fix/flare-stage-matches-export` makes the stage and PNG draw what the export
writes, and its anchor stopgap puts a new layer's origin at its shape's centre.
AN-flare-m starts after it merges and builds on it: the anchor field replaces
the moved origin as the rotation centre, and no slice here owns
`LiveShapes.swift` or `BoxGestureMath.swift`.

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **AN-halo:** `HaloKeyRules.swift` is edited by adopt-kernel-easing AE-halo
  and adopt-kernel-layers AL-halo first (both suiteui, in `waits`); the Halo
  catalog tail is halo/file-flow HF-m; `HaloWindow+Viewer.swift` is
  halo/transform HT-u's.
- **AN-flare-m, AN-flare-u:** `FlareLayers+Kernel.swift` follows
  adopt-kernel-layers AL-flare (in `waits`); `FlareInspectorGeometry.swift`
  is flare/stage-edit's (built); the Flare catalog tail is flare/pen-paths FP-m.

**Rule 20.** Transform and parenting are kernel concepts. Halo's
`localMatrix` composition and its keep-in-place maths become calls into
`Placement` (AN-8), and Flare gets no copy: its adapter maps FlareCore's
transform onto `Placement` and its layers onto `LayerFollow`. No file in
`Tests/canonical-baseline.txt` changes, so this packet is off the baseline
chain.

**AI-accessible first.** `transform.set-anchor` (`{x, y}` or `{at: center |
topLeft | ...}`, keeping the layer in place unless `{keepPlace: false}`),
`layer.set-parent` (`{id, parent}`, `null` to clear, keeping place), and
`layer.new-null`. Each has a control: the anchor mark on the canvas, the
nine-point picker and Parent menu in the inspector, Layer > New Null.

**C4:** AN-13 extends `kernel-transform.json` (`Transform/Placement.swift`,
`Transform/AnchorCommands.swift`) and `kernel-layers.json` (the parent
commands).

Blueprint sections: suite.md 2 (kernel transform and layer tree); halo.md
(transform, parenting); flare.md (transform).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AN-a | The kernel declares Placement with its anchor, set-anchor that keeps place, and the three anchor and parent command specs as stubs, with their tests written and disabled. | AN-1, AN-2 | MJ-AN | editor-kernel, command-catalog (built, `depends`) |
| AN-m | A layer turns and scales about its anchor, moving the anchor keeps the layer where it is on screen, and parenting or clearing a parent keeps the child in place through LayerFollow. | AN-3, AN-4 | MJ-AN | AN-a |
| AN-u | SuiteUI draws the anchor mark on the canvas and drags it as one command, and the inspector shows anchor rows with a nine-point picker and a Parent menu, reachable from the gallery on the fakes. | AN-5, AN-6 | SJ-AN | AN-a; shared files, after orientation-crop:OC-u (AN-5) |
| AN-halo | Halo's layers place through the kernel's Placement with its files and renders unchanged, the anchor can be dragged in the viewer and set from the nine-point picker without the layer moving, and Halo's parent command is the kernel's. | AN-7, AN-8 | MJ-AN-halo, HJ-AN | AN-a (AN-7); AN-m, AN-u, adopt-kernel-easing:AE-halo and adopt-kernel-layers:AL-halo (AN-8, `HaloKeyRules.swift`); shared files, after document-setup:DS-halo (AN-8) |
| AN-flare-m | A Flare layer carries an anchor and a parent from the bumped core, new shapes get their anchor at the shape's centre, set-anchor and set-parent keep layers in place, and Lottie writes and reads a and parent. | AN-9, AN-10 | MJ-AN-flare | AN-a (AN-9); AN-m and adopt-kernel-layers:AL-flare (AN-10); the creative-core bump and the Flare stopgap (cross-line); shared files, after document-setup:DS-flare (AN-10) |
| AN-flare-u | Flare's stage shows and drags the anchor, its inspector has the anchor rows and Parent menu, and Layer > New Null adds a null to parent to. | AN-11, AN-12 | FJ-AN | AN-u, AN-flare-m; shared files, after adopt-kernel-autosave:AK-z (AN-11) |
| AN-z | The kernel's C4 parts name Placement and the parent commands, RJ-X75 and RJ-F14 pass, and the feature is built. | AN-13, AN-14 | MJ-AN, HJ-AN, FJ-AN | AN-halo, AN-flare-u; shared files, after transform-tools:TT-z (AN-13) |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). AN-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

- `MJ-AN`: `PlacementTests` and `AnchorCommandsTests` on Linux.
- `SJ-AN` (`SuiteAnchorJourneyTests.testDragAnchorAndParentInGallery`, AN-6): on the gallery's Anchor page drag the mark to a corner (the box stays put), pick Center in the nine-point picker, parent the second box to the first, turn the first; the second follows.
- `MJ-AN-halo`: `HaloPlacementTests` on Linux.
- `HJ-AN` (`HaloAnchorJourneyTests.testDragAnchorKeepsPlace`, AN-8): select a shape layer, drag its anchor to the bottom edge, key rotation 0 to 30; the layer swings from its base.
- `MJ-AN-flare`: `FlareAnchorParentTests` on Linux.
- `FJ-AN` (`FlareInspectorJourneys.testAnchorAndParent`, AN-12): draw a rectangle, key rotation 0 to 360; scrub to mid-tween, the centre holds; Layer > New Null, parent the rectangle to it, move the null; the rectangle follows.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X75 | adds, closes with `suiteui/anchor-parenting` | C | `Tests/RealJobs/suite/spin-in-place/spin-in-place.jobs.json`: in Flare and in Halo, a 200×200 rectangle drawn by the shape command at (400, 300), `transform.set-anchor {at: center}`, rotation keyed 0 at frame 0 and 360 at frame 24; export PNG frames 0 and 12 | none (built by commands) |
| RJ-F14 | closes with `suiteui/anchor-parenting` (was S8) | C | `layer.set-parent` hand → arm, arm rotation keyed 0 to 45; the hand's world position at frame 0 equals its position before parenting | – |

RJ-X75. Trap: the spin orbits the canvas's top-left corner (Flare) or the
anchor command moves the layer. Assertion: the opaque pixels' centroid at
frame 12 is within 1 px of frame 0's in both apps' PNGs. Mutations:
`SuiteKernel.Placement` `.anchorSign`, `FlareModel.FlarePlacement+Kernel`
`.newShapeAnchorCentre`. Written by AN-7, disabled (`waits_on: AN-10`); its
Halo half passes after AN-8.

RJ-F14 keeps its row; its trap ("child jumps when parented") is caught by
`SuiteKernel.AnchorCommands` `.clearKeepsPlace` and Flare's `.lottieParent`.

## Screens and states

- `suite-gallery-anchor-{light,dark}.png` (AN-5): the mark at a corner, the nine-point picker, the Parent menu open.
- `halo-viewer-anchor-drag-{light,dark}.png` (AN-8).
- `flare-inspector-anchor-parent-{light,dark}.png` (AN-11).

## Contract slice

```swift
// Sources/SuiteKernel/Transform/Placement.swift (AN-1 stubs, AN-3 bodies). Foundation and FlareCore only.
/// A layer's place in its parent: position, scale, clockwise degrees, and the anchor in the layer's own space.
public struct Placement: Hashable, Sendable, Codable {
    public var x, y, scaleX, scaleY, rotation, anchorX, anchorY: Double
    public static let identity: Placement
    /// T(x, y) · R(rotation) · S(scaleX, scaleY) · T(−anchorX, −anchorY): Halo's rule, now everyone's.
    public var matrix: Matrix { get }
    /// The same layer with its anchor at `p` (layer space) and x, y moved so nothing moves on screen.
    public func movingAnchor(to p: Point) -> Placement
    /// One of the nine points of `box` (layer space), for the picker and `{at:}`.
    public static func anchorPoint(at a: BoxAnchor, in box: Rect) -> Point
}
// Sources/SuiteKernel/Transform/AnchorCommands.swift (AN-1 stubs, AN-4 bodies).
public protocol AnchorTarget: AnyObject {
    func placement(of id: String) -> Placement?
    func bounds(of id: String) -> Rect?                 // layer space
    func setPlacement(_ p: Placement, of id: String) throws   // keys when the property is keyed and auto-key is on
}
public protocol ParentTarget: AnyObject {
    associatedtype Payload: Sendable
    var layerTree: LayerTree<Payload> { get set }
    func local(_ node: LayerNode<Payload>) -> Matrix
    func keepPlace(_ node: inout LayerNode<Payload>, world: Matrix)
    func newNull(named: String) throws -> String
}
public enum AnchorCommands {
    public static let specs: [CommandSpec]              // transform.set-anchor, layer.set-parent, layer.new-null
    public static func run(_ id: String, _ params: JSONValue, anchor: AnchorTarget?, parent: (any ParentTarget)?) throws
}
```

## Pseudocode

- **Moving the anchor:** with `M = matrix`, the anchor's screen point before
  is `M · a_old` mapped through the same matrix as the layer; set `a_new`, then
  solve x, y so `M_new · p == M_old · p` for every layer point p, which is
  `(x, y) += R·S·(a_new − a_old)`. Keyed anchors and positions get a key at
  the current frame (auto-key) or move the base value (no keys).
- **Parenting:** `LayerFollow.setFollow(id, parent, local:, keepingPlace:)`
  already keeps the world matrix; `keepPlace` decomposes the new local matrix
  back into a `Placement` with the anchor unchanged.
- **Null:** an empty layer, 100×100 in layer space for its mark only, never
  drawn or exported as pixels (Lottie `ty: 3`).
- **Defaults:** a new Flare shape's anchor is its bounds' centre; Halo's
  existing default (`HaloLayerDefaults`) is the same rule, now read from
  `anchorPoint(at: .center, in:)`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AN-1 | – | **Contract as stubs.** `Placement` (x, y, scale, rotation, anchor; `matrix`; `movingAnchor(to:)`; `anchorPoint(at:in:)`), `AnchorTarget`, `ParentTarget` and `AnchorCommands`' three specs | `Sources/SuiteKernel/Transform/Placement.swift`, `Sources/SuiteKernel/Transform/AnchorCommands.swift` | – | ~170, 2 |
| AN-2 | – | `PlacementTests` and `AnchorCommandsTests` written, disabled (`waits on AN-3`, `waits on AN-4`) | `Tests/SuiteKernelTests/PlacementTests.swift`, `Tests/SuiteKernelTests/AnchorCommandsTests.swift` | AN-1 | ~180, 2 |
| AN-3 | – | `Placement` bodies, lifted from `HaloKeyRules.localMatrix` and its keep-in-place step; turns on `PlacementTests` | `Sources/SuiteKernel/Transform/Placement.swift`, `Tests/SuiteKernelTests/PlacementTests.swift`, `Tests/mutations/SuiteKernel.Placement.json` | AN-1, AN-2 | ~170, 3 |
| AN-4 | – | `AnchorCommands` run: set-anchor through `movingAnchor`, set-parent through `LayerFollow.setFollow(keepingPlace:)`, new-null as an empty layer at the canvas centre; turns on `AnchorCommandsTests` | `Sources/SuiteKernel/Transform/AnchorCommands.swift`, `Tests/SuiteKernelTests/AnchorCommandsTests.swift`, `Tests/mutations/SuiteKernel.AnchorCommands.json` | AN-1, AN-2 | ~180, 3 |
| AN-5 | – | **Reachable first:** the gallery's Anchor page on the fakes; `CanvasMarks+Anchor` (crosshair in a circle, hover and pressed states, a drag sends one `transform.set-anchor` at release, Shift snaps to the nine points); `AnchorRows` (X, Y, the nine-point picker on `BoxAnchor`, a Parent menu with None); `AnchorRowsTests` first | `Sources/SuiteUI/CanvasMarks+Anchor.swift`, `Sources/SuiteUI/AnchorRows.swift`, `Sources/SuiteUI/Gallery/GalleryAnchor.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/AnchorRowsTests.swift` | AN-1, AN-2 | ~280, 5 |
| AN-6 | – | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+Anchor.swift`, `Tests/AppSnapshotTests/RenderBudgetAnchorTests.swift` | AN-5 | ~110, 2 |
| AN-7 | – | **Halo, test first.** `HaloPlacementTests`, disabled: every fixture renders the same frames within 1 level; a viewer anchor drag keeps the layer in place and is one undo step; RJ-X75's job folder, disabled; the journey, skipped | `Tests/HaloModelTests/HaloPlacementTests.swift`, `UITests/HaloJourneyTests+Anchor.swift`, `Tests/RealJobs/suite/spin-in-place/spin-in-place.jobs.json` | AN-1, AN-2 | ~170, 3 |
| AN-8 | – | `HaloPlacement+Kernel.swift`; `HaloKeyRules.localMatrix` builds a `Placement`; the viewer draws `CanvasMarks+Anchor` and its drag sends `transform.set-anchor` (keyed when the anchor has keys); `AnchorRows` in the inspector; `inspector.set-parent` forwards to `layer.set-parent`; catalog specs; turns on the tests | `Sources/HaloModel/HaloPlacement+Kernel.swift`, `Sources/HaloModel/Live/HaloKeyRules.swift`, `Sources/HaloApp/HaloWindow+Viewer.swift`, `Sources/HaloApp/HaloInspector+Anchor.swift`, `Tests/HaloModelTests/HaloPlacementTests.swift`, `UITests/HaloJourneyTests+Anchor.swift`, `Tests/mutations/HaloModel.HaloPlacement+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | AN-7, AN-3, AN-4, AN-5, AN-6 | ~230, 10 |
| AN-9 | – | **Flare, test first.** `FlareAnchorParentTests`, disabled: a rectangle drawn with the tool and keyed 0 to 360° keeps its centre at frame 12 of 24; a hand parented to an arm follows the arm's turn with no jump; Lottie round-trips `a` and `parent`; old files draw the same | `Tests/FlareModelTests/FlareAnchorParentTests.swift` | AN-1, AN-2 | ~170, 1 |
| AN-10 | – | `FlarePlacement+Kernel.swift` maps FlareCore's transform and parent onto `Placement` and `LayerFollow`; `FlareLayers+Kernel` builds the tree's follow links from `parentID`; new shapes take `anchorPoint(at: .center)`; the three specs in Flare's catalog; turns on the tests | `Sources/FlareModel/FlarePlacement+Kernel.swift`, `Sources/FlareModel/FlareLayers+Kernel.swift`, `Tests/FlareModelTests/FlareAnchorParentTests.swift`, `Tests/mutations/FlareModel.FlarePlacement+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | AN-9, AN-3, AN-4 | ~230, 7 |
| AN-11 | – | The stage draws `CanvasMarks+Anchor` for the selected layer and its drag runs `transform.set-anchor` (keyed under auto-key); `AnchorRows` under Transform in the inspector; Layer > New Null | `Sources/FlareApp/FlareInspectorGeometry.swift`, `Sources/FlareApp/FlareStage+Anchor.swift`, `Sources/FlareApp/FlareCommands.swift`, `Tests/command-path-baseline/flare.txt` | AN-5, AN-6, AN-9, AN-10 | ~220, 4 |
| AN-12 | – | The journey and the render budget row | `UITests/FlareJourneyTests+Inspector.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareTests.swift` | AN-11 | ~120, 2 |
| AN-13 | – | The kernel's C4 parts: `kernel-transform.json` names `Placement.swift` and `AnchorCommands.swift`, `kernel-layers.json` the parent commands | `docs/c4/parts/creative-apps/suite-kernel/kernel-transform.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-layers.json` | AN-7, AN-8, AN-11, AN-12 | ~20, 2 |
| AN-14 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/anchor-parenting.wave.json` | AN-13 | ~10, 1 |

## Build waves

- Wave 1: AN-1. Independent in this wave: AN-1 alone.
- Wave 2: AN-2. Independent in this wave: AN-2 alone.
- Wave 3: AN-3, AN-4, AN-5, AN-7, AN-9. Independent in this wave: all.
- Wave 4: AN-6, AN-10. Independent in this wave: both.
- Wave 5: AN-8, AN-11. Independent in this wave: both.
- Wave 6: AN-12. Independent in this wave: AN-12 alone.
- Wave 7: AN-13. Independent in this wave: AN-13 alone.
- Wave 8: AN-14. Independent in this wave: AN-14 alone.

Longest chain: AN-1 → AN-2 → AN-5 → AN-6 → AN-11 → AN-12 → AN-13 → AN-14 (8). Chain of 8: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AN-1 | the kernel builds; `CommandShapeTests` with the three specs | a spec has no schema | – (stubs) |
| AN-2 | compile, disabled | – | – (tests only) |
| AN-3 | `PlacementTests`: a 100×100 box with its anchor at the centre, turned 90°, keeps its centre; `movingAnchor` to a corner leaves every corner where it was on screen, also when scaled 2x and turned 30°; `matrix` equals Halo's for 200 random placements | the turn is about the origin or moving the anchor shifts the layer | `SuiteKernel.Placement`: anchor translated by +anchor (sign) → `.anchorSign`; keep-place ignores scale → `.keepPlaceScaled`; rotate before scale order swapped → `.matrixOrder` |
| AN-4 | `AnchorCommandsTests` on the fake document: parenting a turned child to a scaled parent leaves its world corners unchanged; clearing the parent too; a cycle is refused with the sentence; `{at: center}` lands on the box centre | a child jumps when parented or a cycle is accepted | `SuiteKernel.AnchorCommands`: keepPlace skipped on clear → `.clearKeepsPlace`; cycle check skipped → `.refusesCycle` |
| AN-5 | `AnchorRowsTests`: the picker sends `{at:}` for each point, the Parent menu lists the other layers and None and never the layer or its descendants; the mark's hit radius is 6 pt at any zoom | a row is bare or the menu offers a cycle | – (SuiteUI view) |
| AN-6 | `SuiteAnchorJourneyTests.testDragAnchorAndParentInGallery`; `RenderBudgetAnchorTests.anchorDragInThreeBodies` | – | – |
| AN-7 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| AN-8 | `HaloPlacementTests`; `HaloViewerFidelityTests` unchanged; `HaloAnchorJourneyTests.testDragAnchorKeepsPlace` | a render changes or the drag moves the layer | `HaloModel.HaloPlacement+Kernel`: anchor keys ignored at frame f → `.anchorKeysSampled`; the drag keys position instead of anchor → `.dragSetsAnchor` |
| AN-9 | compiles, disabled | – | – (tests only) |
| AN-10 | `FlareAnchorParentTests`; Flare's export round-trip suites unchanged | the spin orbits a corner, the hand jumps, or Lottie drops `parent` | `FlareModel.FlarePlacement+Kernel`: anchor left at 0 for new shapes → `.newShapeAnchorCentre`; parent not written to Lottie → `.lottieParent` |
| AN-11 | `CommandPathTests`; Flare's Model tests unchanged | an anchor control is bare | – (app wiring) |
| AN-12 | `FlareInspectorJourneys.testAnchorAndParent`; `RenderBudgetFlareTests.anchorDragInThreeBodies` | – | – |
| AN-13 | `scripts/c4-assemble --check` | a path is missing | – |
| AN-14 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample anchor drag (gallery) | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetAnchorTests.anchorDragInThreeBodies` |
| render: Halo viewer anchor drag | ≤ 3 window bodies | `RenderBudgetHaloTests.anchorDragInThreeBodies` |
| render: Flare stage anchor drag | ≤ 3 window bodies | `RenderBudgetFlareTests.anchorDragInThreeBodies` |
| one gesture, one step | an anchor drag and a parent change are one undo step each | `AnchorCommandsTests.oneStep` |
| behaviour preserved | Halo renders and Flare's old files draw the same within 1 level | `HaloPlacementTests`, `FlareAnchorParentTests` |
| no dead controls; keyboard parity | the picker and Parent menu reach by Tab; every control has a command | `CommandPathTests`; `SJ-AN` |

## Done check

Per slice (rules 6, 15, 17, 21): AN-a and AN-m green on Linux with clean
`Mutate:` scores; AN-u, AN-halo and AN-flare-u through the feel gate
(`mouse`, `taste`, `job`: make a spinner turn in place and move a group of
layers by a null, mouse only) with their `Mac-Finish:` lines; AN-flare-m after
the core bump and the stopgap; AN-z with RJ-X75 and RJ-F14 green on Linux.
Then `Belt-Contact-Sheet:`.
