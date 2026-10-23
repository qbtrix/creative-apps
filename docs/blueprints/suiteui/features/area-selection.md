# Feature packet: area-selection

**Feature:** a selection that is an area, not only a rectangle. SuiteKernel
holds the recipe: the shapes (rectangle, ellipse, freehand lasso, polygon
lasso, magic wand), how each joins the last (replace, add with Shift,
subtract with Option, intersect with both), and the steps after it (invert,
feather, expand, contract), plus Reselect. SuiteImaging turns a recipe into a
CoreRaster `Mask` (core already has `Mask.ellipse`, `polygon`, `add`,
`subtract`, `intersect`, `invert`, `feathered`, `contours`, `floodMask` and
`colorRangeMask` at the pin). SuiteUI draws the marching ants and the tool
options. The same packet gives object editors the group-aware click: a click
on a grouped layer picks the group, a double-click or Return enters it, Escape
steps out one level, and ⌘-click picks the deepest layer. Photo adopts the
area selection (its `LiveSelection` is `NotBuiltSelection` today, PV-5) and
Design adopts the group click (`DesignNode.hit(at:)` returns the innermost
child, so a click never picks a group and a drag pulls one child out).
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/area-selection`
**Beta:** captain, 2026-10-21 (beta gaps C1). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C1, with the evidence in `2026-10-21-gaps-photo.md` rows 1 and 2 and
`2026-10-21-gaps-design.md` row 1; feature map row S5; real jobs RJ-X70 and
RJ-X71 (new).

**Depends on:** editor-kernel, command-catalog and adopt-command-catalog
(built). **Waits:** suite-imaging IM-a for the SuiteImaging target (AR-r) and
IM-z for the baseline chain (AR-z). No creative-core issue: every raster
operation is on the `2258b625` pin.

**Hand-offs** (files other packets own; cross-line, so not in `waits`; the
lead checks each before the slice starts):
- **AR-photo-m:** `PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`
  and the CLI golden chain through Photo's beta packets; its tail is
  photo/file-flow PF-m. `PhotoSelectionMask.swift` is PV-5's file (photo
  seams); it is free once PV-5 is closed or folded here.
- **AR-photo-u:** `PhotoModel/PhotoToolbarItems.swift` and `PhotoToolOptions.swift` are
  shared with photo/gradient-fill and adopt-kernel-brush AB-photo; start after
  both, or tell their owners.
- **AR-design:** `DesignCanvasEditing.swift` passes design-seams-2 and
  design/transform; the Design catalog chain's tail is design/pen-paths DP-m.

**Rule 20.** Selection is a kernel concept. Photo's `SelectionShape`,
`SelectionCombine`, `SelectionShapeKind` and `SelectionOptions`
(`Contracts/SelectionContracts.swift`) are an app copy of the recipe; they
become the kernel's through `PhotoArea+Kernel.swift` and are deleted. Halo and
Flare draw mask shapes through the masks packets (S4), which read
`AreaShape`; they have no groups to enter (Halo's nulls are follow links,
symbols are out of the beta), so they get no adopt slice here.

**Deleted app-local files:** `Sources/PhotoModel/Contracts/SelectionContracts.swift`
(its `LayerMasking` protocol moves to `Contracts/LayerMaskContracts.swift`),
`Sources/PhotoModel/Live/LiveSelection.swift` and
`Sources/PhotoApp/SelectionOverlay.swift`, in AR-z with
`scripts/check-dup-logic --update-baseline`: `Tests/canonical-baseline.txt`
shrinks by 3 lines.

**AI-accessible first.** Every action is a catalog command: `select.rect`,
`select.ellipse`, `select.lasso`, `select.polygon`, `select.wand`,
`select.invert`, `select.feather`, `select.expand`, `select.contract`,
`select.reselect`, and for objects `select.pick`, `select.enter-group`,
`select.exit-group`. Each has a menu item (Select menu in Photo; Edit > Enter
Group and Exit Group in Design), so nothing is shortcut-only.

**C4:** AR-6 adds `docs/c4/parts/creative-apps/suite-imaging/imaging-select.json`
(`Sources/SuiteImaging/Select/`); AR-z edits the kernel's
`kernel-selection.json` to name the recipe and the group rule.

**Clean-room.** Behaviour comes from the apps' own tests and core's documented
mask operations.

Blueprint sections: suite.md 2 (the kernel tier); photo.md 3 (selections);
design.md (select and groups).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AR-a | The kernel declares the area recipe, the group pick rule and their thirteen select.* command specs as stubs, with their tests written and disabled. | AR-1, AR-2 | MJ-AR | editor-kernel, command-catalog (built, `depends`) |
| AR-m | Shapes join the area by Shift, Option or both, a lasso closes and drops points closer than a pixel, the steps keep their order, and a click picks the outermost group in the entered scope. | AR-3, AR-4 | MJ-AR | AR-a |
| AR-r | A recipe becomes a CoreRaster mask in SuiteImaging: shapes joined in order, the wand by tolerance and contiguity over one layer or all, then invert, feather, expand and contract. | AR-5, AR-6 | MJ-AR-raster | suite-imaging:IM-a (the target); AR-a |
| AR-u | SuiteUI draws marching ants from a mask outline and a lasso in progress, and shows the area tool options (shape, mode, feather, wand tolerance, contiguous, all layers) as command-backed controls, reachable from the gallery on the fakes. | AR-7, AR-8 | SJ-AR | AR-a; shared files, after pen-paths:PN-a (AR-7) |
| AR-photo-m | Photo's selection runs on the kernel recipe and SuiteImaging's mask behind its existing API, every select.* command works by CLI, and delete, fill and paint keep weighting by coverage. | AR-9, AR-10 | MJ-AR-photo | AR-a (AR-9); AR-m and AR-r (AR-10); photo/file-flow PF-m (catalog chain, cross-line) |
| AR-photo-u | Photo's toolbar has Ellipse, Lasso, Polygon Lasso and Magic Wand beside the Marquee, the Select menu lists every area command, and the ants come from SuiteUI instead of Photo's overlay. | AR-11, AR-12 | PJ-AR | AR-u, AR-photo-m; shared files, after adopt-suiteui-chrome:AC-colour (AR-11) |
| AR-design | In Design a click on a grouped layer picks the group and drags it whole, a double-click or Return enters it, Escape steps out one level, and ⌘-click picks the deepest layer, all as commands. | AR-13, AR-14 | DJ-AR | AR-a (AR-13); AR-m (AR-14); design/pen-paths DP-m (catalog chain, cross-line); shared files, after adopt-kernel-transform:AT-design (AR-14) |
| AR-z | Photo's selection contract copy, its NotBuilt live service and its own overlay are deleted with the baseline shrunk by three lines, the kernel's C4 part names the recipe, RJ-X70 and RJ-X71 pass, and the feature is built. | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z (AR-15, `canonical-baseline.txt`) |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). AR-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

Linux walks, then the apps' journeys on the scoped run after each slice's last PR:
- `MJ-AR`: `AreaShapeTests` and `GroupPickTests` on the Linux job.
- `MJ-AR-raster`: `AreaMaskTests` on the Linux job (SuiteImaging builds on Linux without Metal).
- `SJ-AR` (`SuiteAreaSelectJourneyTests.testAntsAndOptionsInGallery`, AR-8): open the gallery's Area Select page, drag a lasso, pick Subtract, set Feather to 4, click the wand; the ants follow and every option shows its state.
- `MJ-AR-photo`: `PhotoAreaSelectionTests` on the Linux job.
- `PJ-AR` (`PhotoSelectionJourneyTests.testShapesWandInvertFeather`, AR-12): open the fixture photo; Ellipse tool, drag a face-sized ellipse; Lasso with Option held, cut a notch; Select > Invert; Select > Feather… 8; Edit > Fill Selection; the canvas shows the filled surround with a soft edge.
- `DJ-AR` (`DesignSelectJourneyTests.testClickGroupThenEnter`, AR-14): a card group of a rectangle and a text; click the text, the card is picked; drag, the card moves whole; double-click, the text is picked; Escape, the card again.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X70 | adds, closes with `S5` | C | `Tests/RealJobs/photo/select-shapes/select-shapes.jobs.json`: on `portrait.png`, `select.ellipse` around the face, `select.lasso` with `mode: subtract` over the chin, `select.invert`, `select.feather` 8, `edit.fill-selection` white, `file.export` PNG | `input/portrait.png` |
| RJ-X71 | adds, closes with `S5` | C | `Tests/RealJobs/design/group-click/group-click.jobs.json`: `select.pick` at the card's text, `transform.set` x +40, `select.enter-group`, `select.pick` at the text, `transform.set` x +10, save | a two-layer card group made by commands |

RJ-X70. Trap: Option adds instead of subtracting, the feather is ignored, or
Invert selects the whole canvas. Assertion: the face centre is unchanged, the
chin notch and the surround are white, and the edge ramp from 10% to 90% white
is at least 6 px wide. Mutations: `SuiteKernel.AreaShape` `.optionSubtracts`,
`SuiteImaging.AreaMask` `.featherAfterCombine`. Disabled
(`waits_on: AR-10`).

RJ-X71. Trap: the pick lands on the text, so the first move pulls the text
out of its card. Assertion: after the first move both layers moved 40; after
the second only the text moved 10 more. Mutation:
`SuiteKernel.GroupPick` `.outermostGroup`. Written by AR-13, disabled
(`waits_on: AR-14`).

## Screens and states

- `suite-gallery-area-select-{light,dark}.png` (AR-7): the options bar in each mode and the ants on a lasso.
- `photo-select-ellipse-feather-{light,dark}.png` (AR-11): the ants on a feathered, inverted ellipse.
- `photo-select-wand-{light,dark}.png` (AR-11): wand options with Contiguous off.
- `design-group-entered-{light,dark}.png` (AR-14): a picked child inside an entered group, the group's box dimmed.

## Contract slice

```swift
// Sources/SuiteKernel/Selection/AreaShape.swift (AR-1 stubs, AR-3 bodies). Foundation and FlareCore only.
public enum AreaShape: Hashable, Sendable, Codable {
    case rect(Rect), ellipse(Rect)
    case lasso([Point])                 // freehand; closed and simplified by `normalized`
    case polygon([Point])               // clicked corners; closed
    case wand(seed: Point, tolerance: Double, contiguous: Bool, allLayers: Bool)  // tolerance 0...255
}
public enum AreaCombine: String, Hashable, Sendable, Codable, CaseIterable {
    case replace, add, subtract, intersect
    public init(_ modifiers: EditModifiers)          // Shift add, Option subtract, both intersect
}
public struct AreaRecipe: Hashable, Sendable, Codable {
    public enum Step: Hashable, Sendable, Codable { case shape(AreaShape, AreaCombine), invert, feather(Double), expand(Double) }
    public private(set) var steps: [Step]            // expand(-r) is Contract
    public static let empty: AreaRecipe
    public mutating func apply(_ step: Step)          // a replace shape clears the earlier steps
    public func normalized() -> AreaRecipe            // lassos closed and simplified (points under 1 px apart dropped)
}
// Sources/SuiteKernel/Selection/AreaSelectCommands.swift (AR-1). The ten specs and the target the adopters conform to.
public protocol AreaSelectTarget: AnyObject {
    var areaRecipe: AreaRecipe { get }
    var lastAreaRecipe: AreaRecipe? { get }           // for Reselect
    func setAreaRecipe(_ recipe: AreaRecipe) throws   // one undo step
}
public enum AreaSelectCommands {
    public static let specs: [CommandSpec]            // select.rect, .ellipse, .lasso, .polygon, .wand, .invert, .feather, .expand, .contract, .reselect
    public static func run(_ id: String, _ params: JSONValue, on target: AreaSelectTarget) throws
}
// Sources/SuiteKernel/Selection/GroupPick.swift (AR-1 stubs, AR-4 bodies).
public struct GroupScope: Hashable, Sendable { public var path: [String] }   // [] is the root
public enum GroupPick {
    /// The id a click picks: the ancestor of `hit` that is a direct child of the scope's innermost group,
    /// or `hit` itself when `deep` (⌘) or when it already is one. nil when the hit is outside the scope.
    public static func target<P>(hit: String, scope: GroupScope, deep: Bool, in tree: LayerTree<P>) -> String?
    public static func entering(_ id: String, scope: GroupScope, in tree: LayerTree<some Sendable>) -> GroupScope?
    public static func exiting(_ scope: GroupScope) -> GroupScope        // one level up
    public static let specs: [CommandSpec]            // select.pick {x, y, deep}, select.enter-group, select.exit-group
}
// Sources/SuiteImaging/Select/AreaMask.swift (AR-5 stub, AR-6 body). Linux-safe.
public enum AreaMask {
    public struct Sources { public var layer: PixelBuffer; public var composite: PixelBuffer }   // the wand's two choices
    public static func mask(_ recipe: AreaRecipe, width: Int, height: Int, sources: Sources?) throws -> Mask
    public static func outline(_ mask: Mask) throws -> [[Point]]    // contours at 0.5, for the ants
}
```

## Pseudocode

- **Recipe to mask:** start empty; for each step in order: a shape renders to
  its own mask (rect and ellipse from core's statics, lasso and polygon by
  `Mask.polygon`, wand by `floodMask(from:tolerance:contiguous:)` on the layer
  or the composite) and joins by `add`, `subtract` or `intersect` (replace
  starts over); `invert` flips; `feather(r)` runs `feathered(radius:)`;
  `expand(r)` takes the max (min for r < 0) of coverage over a disk of radius
  |r|. Feather and expand apply where they sit in the list, so feather then
  subtract keeps the hard cut (Photoshop order).
- **Wand tolerance:** 0...255 per channel, the same unit as core's
  `FillTolerance`; "All Layers" samples the composite.
- **Group pick:** walk from the hit up through its parents; return the first
  whose parent is the scope's innermost group (the root when the scope is
  empty). Enter needs the picked id to be a group with children; exit pops one
  level. A new selection made outside the scope resets the scope to the root.
- **Undo:** each `select.*` is one step; a lasso drag is one step at release.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AR-1 | – | **Contract as stubs.** `AreaShape` (rect, ellipse, lasso, polygon, wand), `AreaCombine` (from `EditModifiers`), `AreaRecipe` (ordered steps, invert, feather, expand), `AreaSelectTarget` and `AreaSelectCommands`' ten `select.*` specs; `GroupPick` and its three specs. Stubs return the fake's value | `Sources/SuiteKernel/Selection/AreaShape.swift`, `Sources/SuiteKernel/Selection/AreaSelectCommands.swift`, `Sources/SuiteKernel/Selection/GroupPick.swift` | – | ~220, 3 |
| AR-2 | – | `AreaShapeTests` and `GroupPickTests` written from this packet, disabled by name (`waits on AR-3`, `waits on AR-4`) | `Tests/SuiteKernelTests/AreaShapeTests.swift`, `Tests/SuiteKernelTests/GroupPickTests.swift` | AR-1 | ~160, 2 |
| AR-3 | – | `AreaShape`, `AreaCombine` and `AreaRecipe` bodies: modifiers to combine, lasso close and simplify, polygon close, Reselect keeps the last recipe; turns on `AreaShapeTests` | `Sources/SuiteKernel/Selection/AreaShape.swift`, `Tests/SuiteKernelTests/AreaShapeTests.swift`, `Tests/mutations/SuiteKernel.AreaShape.json` | AR-1, AR-2 | ~200, 3 |
| AR-4 | – | `GroupPick` bodies: the hit lifted to the outermost group under the entered scope, ⌘ picks the deepest, enter and exit one level, a locked group passes the click to nothing; turns on `GroupPickTests` | `Sources/SuiteKernel/Selection/GroupPick.swift`, `Tests/SuiteKernelTests/GroupPickTests.swift`, `Tests/mutations/SuiteKernel.GroupPick.json` | AR-1, AR-2 | ~170, 3 |
| AR-5 | – | `AreaMask` declared (stub returning an empty mask) and `AreaMaskTests` written, disabled (`waits on AR-6`) | `Sources/SuiteImaging/Select/AreaMask.swift`, `Tests/SuiteImagingTests/AreaMaskTests.swift` | AR-1, AR-2 | ~150, 2 |
| AR-6 | – | `AreaMask` body over core's `Mask` and `floodMask`/`colorRangeMask`; expand and contract as a disk max/min of the coverage; the outline for the ants from `contours`; turns on `AreaMaskTests`; the C4 part | `Sources/SuiteImaging/Select/AreaMask.swift`, `Tests/SuiteImagingTests/AreaMaskTests.swift`, `Tests/mutations/SuiteImaging.AreaMask.json`, `docs/c4/parts/creative-apps/suite-imaging/imaging-select.json` | AR-5 | ~240, 4 |
| AR-7 | – | **Reachable first:** the gallery's Area Select page on the fakes; `CanvasMarks+Area` (ants animated at 4 steps a second, paused under Reduce Motion; the rubber-band lasso and polygon); `AreaToolOptions` on `ChoiceChips` and `StudioScrubRow`, each control naming its command; `AreaToolOptionsTests` first | `Sources/SuiteUI/CanvasMarks+Area.swift`, `Sources/SuiteUI/AreaToolOptions.swift`, `Sources/SuiteUI/Gallery/GalleryAreaSelect.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/AreaToolOptionsTests.swift` | AR-1, AR-2 | ~270, 5 |
| AR-8 | – | Render budget and the gallery journey: a 120-sample lasso drag and a wand click on the gallery canvas | `Tests/AppSnapshotTests/RenderBudgetAreaSelectTests.swift`, `UITests/SuiteJourneyTests+AreaSelect.swift` | AR-7 | ~130, 2 |
| AR-9 | – | **Photo, test first.** `PhotoAreaSelectionTests`, disabled (`waits on AR-10`); RJ-X70's job folder, disabled until its commands exist | `Tests/PhotoModelTests/PhotoAreaSelectionTests.swift`, `Tests/RealJobs/photo/select-shapes/select-shapes.jobs.json`, `Tests/RealJobs/photo/select-shapes/input/portrait.png` | AR-1, AR-2 | ~150, 3 |
| AR-10 | – | **Photo adapter.** `PhotoArea+Kernel.swift` conforms Photo to `AreaSelectTarget` and keeps the last recipe for Reselect; `PhotoSelectionMask` routes the drag's shape and modifiers into the recipe; the ten specs in Photo's catalog, the id list and the CLI golden; turns on `PhotoAreaSelectionTests` | `Sources/PhotoModel/PhotoArea+Kernel.swift`, `Sources/PhotoModel/PhotoSelectionMask.swift`, `Tests/PhotoModelTests/PhotoAreaSelectionTests.swift`, `Tests/mutations/PhotoModel.PhotoArea+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | AR-9, AR-3, AR-4, AR-5, AR-6 | ~250, 7 |
| AR-11 | – | Photo's tools and Select menu on the shared options and marks: four tools, Select > Invert, Feather…, Expand…, Contract…, Reselect; `SelectionOverlay` no longer drawn | `Sources/PhotoModel/PhotoToolbarItems.swift`, `Sources/PhotoApp/PhotoToolOptions.swift`, `Sources/PhotoApp/PhotoWindow+Select.swift`, `Sources/PhotoApp/PhotoCommands.swift`, `Tests/command-path-baseline/photo.txt` | AR-7, AR-8, AR-9, AR-10 | ~300, 5 |
| AR-12 | – | Journey and render budget: ellipse, Option-lasso, wand, invert, feather on the fixture photo | `UITests/PhotoJourneyTests+Selection.swift`, `Tests/AppSnapshotTests/PhotoRenderBudgetTests.swift` | AR-11 | ~140, 2 |
| AR-13 | – | **Design, test first.** `DesignGroupPickTests` (Model), disabled (`waits on AR-14`), the journey, skipped (`waits on AR-14`), and RJ-X71's job folder, disabled | `Tests/DesignModelTests/DesignGroupPickTests.swift`, `UITests/DesignJourneyTests+Select.swift`, `Tests/RealJobs/design/group-click/group-click.jobs.json` | AR-1, AR-2 | ~170, 3 |
| AR-14 | – | `DesignGroupPick+Kernel.swift`; the Move press lifts its hit through `GroupPick`; double-click and Return enter, Escape exits; `select.pick`, `select.enter-group`, `select.exit-group` in Design's catalog with Edit > Enter Group and Exit Group items; turns both on | `Sources/DesignModel/DesignGroupPick+Kernel.swift`, `Sources/DesignModel/DesignCanvasEditing.swift`, `Sources/DesignApp/DesignEditMenu.swift`, `Tests/DesignModelTests/DesignGroupPickTests.swift`, `UITests/DesignJourneyTests+Select.swift`, `Tests/mutations/DesignModel.DesignGroupPick+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json` | AR-13, AR-3, AR-4 | ~230, 9 |
| AR-15 | – | **Photo delete.** Removes `SelectionContracts.swift` (its `LayerMasking` moves to `LayerMaskContracts.swift`), `LiveSelection.swift` and `SelectionOverlay.swift`; repoints any plan `find`; `scripts/check-dup-logic --update-baseline` drops their 3 lines | `Sources/PhotoModel/Contracts/SelectionContracts.swift`, `Sources/PhotoModel/Contracts/LayerMaskContracts.swift`, `Sources/PhotoModel/Live/LiveSelection.swift`, `Sources/PhotoApp/SelectionOverlay.swift`, `Sources/PhotoModel/PhotoServices.swift`, `Tests/canonical-baseline.txt` | AR-9, AR-10, AR-11, AR-12 | ~200, 6 |
| AR-16 | – | The kernel's C4 part names `AreaShape`, `AreaRecipe` and `GroupPick`; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-selection.json`, `docs/blueprints/suiteui/features/area-selection.wave.json` | AR-15, AR-13, AR-14 | ~30, 2 |

## Build waves

- Wave 1: AR-1. Independent in this wave: AR-1 alone.
- Wave 2: AR-2. Independent in this wave: AR-2 alone.
- Wave 3: AR-3, AR-4, AR-5, AR-7, AR-9, AR-13. Independent in this wave: all.
- Wave 4: AR-6, AR-8, AR-14. Independent in this wave: all.
- Wave 5: AR-10. Independent in this wave: AR-10 alone.
- Wave 6: AR-11. Independent in this wave: AR-11 alone.
- Wave 7: AR-12. Independent in this wave: AR-12 alone.
- Wave 8: AR-15. Independent in this wave: AR-15 alone.
- Wave 9: AR-16. Independent in this wave: AR-16 alone.

Longest chain: AR-1 → AR-2 → AR-5 → AR-6 → AR-10 → AR-11 → AR-12 → AR-15 → AR-16 (9). Chain of 9: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AR-1 | the kernel builds on Linux; `KernelShapeTests` and `CommandShapeTests` pass with the new specs | a spec has no schema or the kernel imports more than Foundation and FlareCore | – (stubs) |
| AR-2 | both suites compile, disabled | a signature the adopters call is missing | – (tests only) |
| AR-3 | `AreaShapeTests`: Option-drag subtracts, Shift-Option intersects; a lasso of 3 points closes; 1,000 points 0.2 px apart simplify to under 50; invert twice is the same recipe | a modifier maps to the wrong mode or a lasso stays open | `SuiteKernel.AreaShape`: Option mapped to add → `.optionSubtracts`; the closing point dropped → `.lassoCloses`; simplify with `<=` for `<` → `.simplifyKeepsCorners` |
| AR-4 | `GroupPickTests` on a three-level `LayerTree` fixture: a click on a leaf picks its top group; after enter it picks the child group; ⌘ picks the leaf; Esc steps out one level, not to the root | the click picks the innermost layer or Esc leaves every group | `SuiteKernel.GroupPick`: the deepest hit returned at the root scope → `.outermostGroup`; exit to the root instead of one level → `.exitOneLevel` |
| AR-5 | compiles, disabled | – | – (stub and tests) |
| AR-6 | `AreaMaskTests` on a 64×64 fixture: ellipse minus lasso leaves the expected coverage within 1/255; the wand at tolerance 10 stops at a 20-level edge; contiguous off picks both islands; feather 4 makes a ramp at least 6 px wide; expand 2 then contract 2 restores a square | a step runs out of order or the wand leaks across an edge | `SuiteImaging.AreaMask`: feather before the combine → `.featherAfterCombine`; contiguous ignored → `.wandContiguous`; expand radius off by one with `<` → `.expandRadius` |
| AR-7 | `AreaToolOptionsTests`: every control carries a command id from `AreaSelectCommands`; the mode chip follows held modifiers; the ants path equals the outline it was given | a control is bare (no command) or the ants ignore Reduce Motion | – (SuiteUI view; no Model plan) |
| AR-8 | `RenderBudgetAreaSelectTests.lassoDragInThreeBodies`; `SuiteAreaSelectJourneyTests.testAntsAndOptionsInGallery` | a lasso drag re-renders the window per sample | – |
| AR-9 | compiles, disabled; `scripts/jobs check` | – | – (tests only) |
| AR-10 | `PhotoAreaSelectionTests`: `select.ellipse` then `select.lasso` with `mode: subtract` leaves the hole; Fill Selection weights by the feathered coverage; Reselect after Deselect restores the area; every `.ora` fixture opens unchanged | an area command is missing from the CLI or paint ignores the feather | `PhotoModel.PhotoArea+Kernel`: Reselect keeps nothing → `.reselectRestores`; the recipe applied to the composite, not the canvas size → `.maskMatchesCanvas` |
| AR-11 | `CommandPathTests` (no new bare control); Photo's Model tests unchanged | a new menu item or tool has no command spec | – (app wiring) |
| AR-12 | `PhotoSelectionJourneyTests.testShapesWandInvertFeather`; `PhotoRenderBudgetTests.lassoDragInThreeBodies` | a tool doesn't reach its command or the ants freeze | – |
| AR-13 | compiles, disabled | – | – (tests only) |
| AR-14 | `DesignGroupPickTests`: a press on a grouped card's text picks the card; a drag moves the card with its children; after enter the text is picked; Esc then picks the card again; `DesignSelectJourneyTests.testClickGroupThenEnter` | a drag pulls one child out of its group | `DesignModel.DesignGroupPick+Kernel`: the scope not reset on a new selection → `.scopeResetsOnDeselect`; ⌘ ignored → `.commandPicksDeepest` |
| AR-15 | Photo's Model tests; `scripts/check-dup-logic` (baseline shrank by 3, nothing new); `scripts/mutate --validate` | a deleted type is still referenced or its baseline line stays | – (deletion) |
| AR-16 | `scripts/c4-assemble --check`; `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample lasso drag (gallery) | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetAreaSelectTests.lassoDragInThreeBodies` |
| render: 120-sample lasso drag on an 8K photo | ≤ 3 window bodies; mask build at release p95 ≤ 30 ms | `PhotoRenderBudgetTests.lassoDragInThreeBodies` |
| render: Design press-drag on a group | ≤ 3 window bodies | `RenderBudgetDesignTests` (existing drag row, unchanged) |
| one gesture, one step | a lasso, a wand click, a feather each one undo step | `PhotoAreaSelectionTests.oneStepEach` |
| no dead controls; keyboard parity | every tool and option has a command and a menu item; Return enters, Escape exits | `CommandPathTests`; `DJ-AR` |
| Reduce Motion | ants stand still | `AreaToolOptionsTests.antsStillUnderReduceMotion` |
| kernel stays small | SuiteKernel imports only Foundation and FlareCore | `KernelShapeTests` (unchanged) |
| render: Photo's lasso drag once its overlay is gone (AR-z) | ≤ 3 window bodies | `PhotoRenderBudgetTests.lassoDragInThreeBodies` (AR-12's row) |

## Done check

Per slice (rules 6, 15, 17, 21): AR-a, AR-m and AR-r green on the Linux job
with clean `Mutate:` scores; AR-u, AR-photo-u and AR-design through the feel
gate (`mouse`, `taste` and `job` lenses: a first-time user makes an ellipse,
cuts a notch, feathers and fills with the mouse alone; enters and leaves a
group) with their `Mac-Finish:` lines; AR-z with the baseline shrunk and
RJ-X70 and RJ-X71 green on Linux. Then `Belt-Contact-Sheet:` with the four
snapshots above.
