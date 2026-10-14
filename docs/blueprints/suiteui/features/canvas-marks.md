# Feature packet: canvas-marks

**Feature:** what is drawn over every canvas and how the canvas moves:
selection handles with a hit size that holds at every zoom and rotate zones,
path, motion-path, ghost and guide marks, the point mark and the grid mark,
the ruler corner's unit, the zoom and pan rules behind a contract, and
`CanvasSurface` (Library's loupe, Halo's viewer) with a page and a journey
of its own.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/canvas-marks`

**Covers:** #273 (S12 selection handles and the vector marks; closes with
CM-6), #706 and #737 (one point mark asked twice; both close with CM-7),
#530 (grid mark; CM-8), #264 (ruler corner unit; CM-9). CM-1 to CM-3,
CM-5, CM-10 to CM-16 have no issue of their own (CM-4 and CM-5 say "Part
of #273").

**Depends on:** the suite-harness feature issue (#778): `ContractTypes.swift`
(#773), the `rotateZone` and point-mark tokens (#774), `.suiteControl` and
the probe (#775, #330), the stub `Gallery/GalleryCanvas.swift` (#776), the
journey bundle (#333) and goldens (#331, #332). No creative-core issue.

**This packet supersedes the "Touch only these files" list** of #273 (S12):
its marks are split over `CanvasMarks+Vector.swift` and
`CanvasMarks+Points.swift` and gain contract, gallery and Fake-test files
(review of #765).

**App features it unblocks:** Flare's stage (#12, F3c #375, F4b #390:
selection handles, path and motion-path marks, ghosts), Design adopting the
shared handles (a `line:design` task CM-4 files: Design's own
`DesignCanvasMarks` moves to `SelectionHandles`), Photo swapping its
`CloneSourceMark` and `StraightenMarks` placeholders (Clone, Heal and
Straighten shipped on them: closed #647, #422, #419; CM-7 and CM-8 each
file the `line:photo` swap), and Halo's viewer on `CanvasSurface`.

**Review of #765, folded in here:**

- **`CanvasSurface` had no page, journey or no-contract entry.** It is tier
  1 (Library's loupe, Halo's viewer). This packet adds the `surface` page,
  journey **SJ26** `testCanvasSurfaceCentersArtboard`, its goldens, and
  lists it under views with no contract (below). Its only proof before was
  `LibraryLoupeSnapshots` and `SuiteProInspectorSnapshots`.
- **⌘= must reach `CanvasViewport`, not Library's menu.** Library binds
  `.keyboardShortcut("+")` and `("-")` for Larger and Smaller Thumbnails
  (`Sources/LibraryApp/LibraryCommands.swift:42`, `:45`), and the menu bar
  takes key equivalents first. The HIG says the system localizes shortcut
  keys for the connected keyboard (apple-docs, Keyboards, checked
  2026-10-14), so whether ⌘= can match the ⌘+ item is exactly what SJ9 must
  prove: its first step presses ⌘= twice and asserts the zoom pill reads
  200 % and the log reads `zoom 2`; if the menu took the key, the pill stays
  at 100 % and the step fails. ⌘− is Library's and is never pressed; zoom
  out is ⌘0 (fit). The gallery has no zoom menu items of its own (Library's
  View menu holds thumbnail sizes), so no step uses a menu.
- **Library shortcuts checked:** `LibraryCommands.swift` binds only ⌘+ and
  ⌘−. No gallery step presses either.

Blueprint sections: 4.2 (SJ9, SJ10), 4.3 (SJ21), 4.4 (SP2, SP5), 5.2 (UC7,
UC8), 6.2 (selection handles, point mark, grid mark rows), 7.1 (QB-S3,
QB-S4), 7.4 (QB-S25), 8.3.

**Building blind.** All files are macOS-only. The geometry goes in
`HandleGeometry.swift` and `ZoomMath.swift`'s conformance (pure, unit-tested);
the marks only draw. `DesignCanvasMarks` (`Sources/DesignApp/DesignCanvasMarks.swift`)
is this repo's own code: read it for the look and the hit rules, but write
`SelectionHandles` in SuiteUI from the contract; no SuiteUI file imports or
edits DesignApp. Check `Canvas`, `Path`, `onContinuousHover`, `NSCursor`
with `apple-docs`.

## Journey steps

In `UITests/SuiteJourneyTests+Canvas.swift`, on the `canvas`, `canvas-pt`,
`marks` and `surface` pages:

1. **SJ9** `testCanvasZoomPanAndDrag`: ⌘= twice (pill 200 %, the ⌘= proof
   above); ⌘0 (100 %; the page's 400 × 300 document fits at 100 %); drag
   100 pt from the artboard's corner logs `drag (0,0)→(100,0) ends 1` in
   document pixels; Space-drag 100 pt scrolls and adds no drag; → scrolls a
   tenth of the viewport; `canvas-pt`'s ruler corner reads "pt" (#264).
2. **SJ10** `testSelectionHandlesAtEveryZoom`: at 25 %, 100 %, 400 %: drag
   bottom-right 50 pt (log `handle bottomRight` and the rect); ⇧-drag keeps
   the aspect (±1 px, log `keepAspect`); each handle's logged hit frame is at
   least 12 × 12 pt; a quarter turn in the rotate zone logs `rotate 90` (±1).
3. **SJ21** `testPointAndGridMarks`: the point mark's logged on-screen size is
   the same at zoom 1 and 4, over light and dark pixels; the grid logs
   `cells − 1` lines each way; a drag through the mark still logs (it takes
   no click).
4. **SJ26** `testCanvasSurfaceCentersArtboard`: at window widths 880 and
   1440, the `suite.canvas.artboard` element's frame is centered in the
   surface (±1 pt), inside it by `canvasInset`, with the document's aspect
   (±1 %); the `surface-empty` variant (0 × 0 document) draws a 1 × 1 pt
   artboard with no division.
5. **SP2** `testCanvasDragLatency` (`canvas-drag`), **SP5**
   `testHandleDragLatency` (`handle-drag`): 300 pt/s, ≥ 60 samples,
   report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| `canvas` | a 0 × 0 document fits at 100 % (each side counts as 1 pt) and draws no artboard | none | none |
| `marks` | no selection draws no handles; no path draws no anchors | a handle drag past the opposite edge flips no rect: width and height stop at 0 | none |
| Point and grid marks | `cells` ≤ 0 draws no grid | none | none |
| `surface` | `surface-empty`: the 1 × 1 pt artboard | none | none |

## Contract slice

CM-1 lands two files verbatim from `docs/blueprints/suiteui/contracts/Contracts.swift`:

```swift
// Contracts/CanvasNavigating.swift (UC7)
public protocol CanvasNavigating: Sendable {
    func clamped(_ zoom: Double) -> Double                 // 0.1...32; NaN -> 1
    func zoomedIn(from zoom: Double) -> Double             // the live zoom stops
    func zoomedOut(from zoom: Double) -> Double
    func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double   // never above 1, never ÷0
    func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint
    func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint
}
// Contracts/HandleGeometryProviding.swift (UC8): HandleKind (8 handles, 4 rotate zones)
public protocol HandleGeometryProviding: Sendable {
    func handles(around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> [HandleKind: PlaneRect]
    func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double, rotateZone: Double) -> HandleKind?
    func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect
    func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double
}
```

Public API this feature adds (additive):

```swift
SelectionHandles(rect: CGRect, zoom: Double, onResize:, onRotate:, onEnd:)       // CM-4
PathMarks(anchors:, segments:, zoom:) · guide marks                                // CM-5
MotionPathMarks(points:, zoom:) · GhostLayer(content:, opacity:)                   // CM-6
CanvasPointMark(point: CGPoint, zoom: Double)                                      // CM-7 (#706's name; #737's crosshair)
CanvasGrid(rect: CGRect, cells: Int, zoom: Double)                                 // CM-8
CanvasViewport(..., rulerUnit: String = "px")                                      // CM-9
```

**Views with no contract:** the marks' drawing, and **`CanvasSurface`**: it
centers and fits one rect, a rule with no decision a Model or second view
shares. SJ26, `CanvasSurfaceTests` and its goldens prove it (review of
#765, 5.2's list).

## Pseudocode

```
SuiteHandleGeometry : HandleGeometryProviding                    # CM-2
  handles: a hitSize square centred on each corner and edge midpoint (view points);
           rotate zone = a rotateZone square just outside each corner, diagonal from it
  hit(p): corners first, then edges, then rotate zones; where squares overlap (rect smaller than hitSize)
          the corner nearest p wins; nil otherwise
  resized(r, h, d, keep): move the dragged sides by d, the opposite side fixed; width and height ≥ 0;
          keep: scale = the larger |relative| change, applied to both sides about the fixed corner
  rotation(s, e, c, snap): atan2 difference in degrees, y down, clockwise positive, normalised to (-180, 180];
          snap rounds to 15

SuiteCanvasNavigating : CanvasNavigating                         # CM-3
  wraps ZoomMath (stops, clamp, fit) through PlaneExtent; fit: sides ≤ 0 count as 1; no room -> 0.1
  panStep: viewport × (shift ? 1 : 0.1) on the arrow's axis

SelectionHandles (CM-4): draw handles at selectionHandle size, hit at selectionHandleHit in view points at any
  zoom; drag: hit -> resized/rotation each change (probe "handle-drag"); EditRun ends once on mouse-up;
  rotate cursor over the zone (apple-docs: the system's rotate pointer if one exists, else the crosshair, said in the PR)

CanvasPointMark (CM-7): 12 pt ring and 6 pt cross; paper stroke pointMarkPaper under ink pointMarkInk;
  fixed on screen (sizes not scaled by zoom); .allowsHitTesting(false); .accessibilityHidden(true)
CanvasGrid (CM-8): guard cells > 0; cells-1 hairlines each way, overlayPaper 50 % over a 1 px ink shadow, clipped

CanvasSurface.fitted(artboard, in size, inset) (CM-10): pure; sides ≤ 0 -> 1; scale = min(avail.w / a.w, avail.h / a.h, 1)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: canvas-marks`,
`Fast-Check: pass`, `Head:`. CM-16 carries `feature-done`. Each component
task's snapshot test also calls `assertGolden` through `SnapshotHost` in the four appearances (QB-V5), so the baseline tasks at the end have recorded actuals to commit. Marks are not
controls (hidden from accessibility, no hit), so only `CanvasViewport` and
the page's switches register with `.suiteControl`. No task edits
`docs/c4/model.json`, `docs/design.md`, `Tokens.swift`, `project.yml` or
`ScrubValue.swift` (inspector-controls' file; `ViewerZoom.fitScale` is only
called).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| CM-1 | – | The two canvas contracts and their Fakes | `Sources/SuiteUI/Contracts/CanvasNavigating.swift`, `Sources/SuiteUI/Contracts/HandleGeometryProviding.swift`, `Tests/SuiteUITests/CanvasFakeTests.swift` | – |
| CM-2 | – | `SuiteHandleGeometry` (QB-S13) | `Sources/SuiteUI/HandleGeometry.swift`, `Tests/SuiteUITests/HandleGeometryTests.swift`, `Tests/SuiteUITests/HandleBudgetTests.swift` | CM-1 |
| CM-3 | – | `SuiteCanvasNavigating` over `ZoomMath` | `Sources/SuiteUI/ZoomMath.swift`, `Tests/SuiteUITests/ZoomMathTests.swift`, `Tests/SuiteUITests/CanvasPanTests.swift` | CM-1 |
| CM-4 | #273 (part) | `SelectionHandles`: draw, hit, resize, ⇧ aspect, rotate zones, `handle-drag`; files the `line:design` adoption task | `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/CanvasMarksTests.swift`, `Tests/AppSnapshotTests/SuiteMarksSnapshots.swift` | CM-2 |
| CM-5 | #273 (part) | `PathMarks` (smooth and corner anchors differ in shape) and the guide marks | `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/CanvasMarksTests.swift`, `Tests/AppSnapshotTests/SuiteMarksSnapshots.swift` | CM-4 |
| CM-6 | #273 (closes) | `MotionPathMarks` and `GhostLayer` | `Sources/SuiteUI/CanvasMarks+Vector.swift`, `Tests/SuiteUITests/CanvasMarksTests.swift`, `Tests/AppSnapshotTests/SuiteMarksSnapshots.swift` | CM-5 |
| CM-7 | #706, #737 (closes both) | `CanvasPointMark`; files the `line:photo` swap of `CloneSourceMark` | `Sources/SuiteUI/CanvasMarks+Points.swift`, `Tests/SuiteUITests/CanvasPointMarksTests.swift`, `Tests/AppSnapshotTests/SuitePointMarkSnapshots.swift` | – |
| CM-8 | #530 | `CanvasGrid`; files the `line:photo` swap of `StraightenMarks` | `Sources/SuiteUI/CanvasMarks+Points.swift`, `Tests/SuiteUITests/CanvasPointMarksTests.swift`, `Tests/AppSnapshotTests/SuitePointMarkSnapshots.swift` | CM-7 |
| CM-9 | #264 | The ruler corner's unit; `canvas-drag` series; the viewport's registration | `Sources/SuiteUI/CanvasViewport.swift`, `Sources/SuiteUI/Ruler.swift`, `Tests/SuiteUITests/RulerMarksTests.swift`, `Tests/AppSnapshotTests/CanvasViewportSnapshots.swift` | CM-3 |
| CM-10 | – | `CanvasSurface.fitted`, the `suite.canvas.artboard` identifier, its goldens | `Sources/SuiteUI/CanvasSurface.swift`, `Tests/SuiteUITests/CanvasSurfaceTests.swift`, `Tests/AppSnapshotTests/SuiteSurfaceSnapshots.swift` | – |
| CM-11 | – | The `canvas`, `canvas-pt`, `marks`, `surface` and `surface-empty` gallery pages (the last two declared in `GalleryCanvas.pages`, SH-6's per-area list), their log and the Fakes path | `Sources/SuiteUI/Gallery/GalleryCanvas.swift` | CM-6, CM-8, CM-9, CM-10 |
| CM-12 | – | SJ9 (with the ⌘= proof), SJ10, SJ26 | `UITests/SuiteJourneyTests+Canvas.swift` | CM-11 |
| CM-13 | – | SJ21, SP2, SP5 | `UITests/SuiteJourneyTests+Canvas.swift` | CM-12 |
| CM-14 | – | Baselines: viewport and rulers (px, pt), selection handles, path marks in four appearances | `Tests/AppSnapshotTests/Golden/canvas/` (12 PNGs) | CM-13's CI run |
| CM-15 | – | Baselines: motion path and ghosts, point mark, grid in four appearances | `Tests/AppSnapshotTests/Golden/canvas/` (12 PNGs) | CM-14 |
| CM-16 | – | Baselines: `CanvasSurface` in four appearances; `feature-done` | `Tests/AppSnapshotTests/Golden/canvas/` (4 PNGs) | CM-15 |

Sizes: CM-1 ~260 lines; CM-2 ~320; CM-3 ~180; CM-4 ~330; CM-5 ~280; CM-6
~250; CM-7 ~200; CM-8 ~160; CM-9 ~150; CM-10 ~170; CM-11 ~380 (if it passes 400, the `surface` pages move to CM-11b in the same file, chained); CM-12
~360; CM-13 ~250.

Chains: `CanvasMarks+Vector.swift`, `CanvasMarksTests.swift` and
`SuiteMarksSnapshots.swift` CM-4 → CM-5 → CM-6; `CanvasMarks+Points.swift`
and its tests CM-7 → CM-8; the journey file CM-12 → CM-13. CM-1, CM-7 and
CM-10 start at once. `CanvasMarks.swift` (`SelectionOutline`, `CropShade`)
and the `RulerLabel*Tests` are this feature's in wave 2 and must keep
passing unchanged.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| CM-1 | `CanvasFakeTests`: each Fake gives `main.swift`'s literal result with its gap (doubles and halves; corners only) | a Fake loses its gap |
| CM-2 | `HandleGeometryTests`: every handle's hit rect is 12 × 12 at zoom 0.25, 1 and 4 (view points); on a 4 × 4 pt rect the corner nearest the point wins; dragging bottomRight by (50, 0) with ⇧ from 200 × 100 gives 250 × 125 (±1; the larger relative change, 1.25, on both sides); a drag past the opposite side gives width 0, never negative; a quarter turn gives 90 and with snap 13° gives 15 | a hit size scales with zoom, an overlap picks an edge, or a rect goes negative |
| CM-3 | `ZoomMathTests`: `zoomedIn` from 1 is ZoomMath's next stop (1.5 then 2, as `ViewerZoom.stops` gives); NaN clamps to 1; a 0 × 0 document fits at 1; a viewport with no room gives 0.1; `CanvasPanTests`: → pans a tenth, ⇧→ a whole viewport | a stop, a fit or a pan step is wrong, or a zero divides |
| CM-4 | `CanvasMarksTests`: `SelectionHandles` draws 8 handles and hit rects come from `SuiteHandleGeometry`; one end per drag; `SuiteMarksSnapshots` handles at 25, 100 and 400 %, and its hairline check (in `Tests/AppSnapshotTests`, where `SnapshotHost` lives; `SuiteUITests` cannot reach it) that outline lines are 2 device px and handles sit on the pixel grid at scale 2 | a drag ends twice, or a handle is off the pixel grid |
| CM-5 | `CanvasMarksTests`: a smooth anchor and a corner anchor draw different shapes; guide marks span the viewport; snapshots added | anchors look the same |
| CM-6 | `CanvasMarksTests`: `MotionPathMarks` draws one dot per frame point; `GhostLayer` draws at its opacity; snapshots added | a point or the opacity is wrong |
| CM-7 | `CanvasPointMarksTests`: the mark's on-screen size is the same at zoom 1 and 4; it takes no hit and is hidden from accessibility; `SuitePointMarkSnapshots` over light and dark pixels at zoom 1 and 4 (#737's acceptance, #706's) | the size scales, or the mark takes a click |
| CM-8 | `CanvasPointMarksTests`: a 3-cell grid draws 2 lines each way, 0 cells draws none; snapshots over a light and a dark image in Light and Dark | the line count is off, or 0 cells draws |
| CM-9 | `RulerMarksTests`: the corner reads the given unit, "px" by default; `CanvasViewportSnapshots` adds the "pt" corner and the existing PNGs are unchanged | the default changes Design's or Photo's rulers |
| CM-10 | `CanvasSurfaceTests`: `fitted` centres a 400 × 300 artboard in 800 × 600 at scale 1, in 200 × 150 (less the inset) at the smaller scale, never above 1, and a 0 × 0 artboard as 1 × 1 with no division; `SuiteSurfaceSnapshots` records the surface and the empty variant; `LibraryLoupeSnapshots` unchanged | the rect is off-centre, scales up, or divides by zero |
| CM-11 | SJ0 opens the five canvas pages with `violations()` empty; each builds with `-SuiteGalleryFakes` | a control is unregistered or reasonless |
| CM-12 | SJ9, SJ10, SJ26 pass on CI | any assert, including the ⌘= step |
| CM-13 | SJ21 passes; SP2 and SP5 hold ≥ 60 samples each | an assert fails or a series is short |
| CM-14–16 | The next CI run's goldens pass against the baselines; no `canvas` known issue left | a baseline is missing or differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S3 canvas drag and Space-pan | p95 ≤ 2 frames late (placeholder 3), report-only | SP2, series `canvas-drag` |
| QB-S4 handle drag | p95 ≤ 2 (placeholder 3) | SP5, series `handle-drag` |
| QB-S13 `HandleGeometryProviding.hit` | ≤ 0.02 ms (debug ≤ 0.2 ms) | `HandleBudgetTests.hitWithinBudget` |
| QB-S25 hairlines 2 device px at 2× | the selection outline and ruler edge | `SuiteMarksSnapshots` through `SnapshotHost` |
| QB-S20 handle hits | ≥ 12 pt at every zoom (not elements) | SJ10's log, `HandleGeometryTests` |
| QB-S32 point-mark ink on paper | its contrast pair (landed by SH-2) | `TokensTests` (harness) |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by CM-16 is green:
  SJ9 (the ⌘= step included), SJ10, SJ21, SJ26, SP2 and SP5 present, SJ0
  and SJ25 on the canvas pages.
- **Audit zero new:** `suiteui` stays 0; Design's and Photo's counts do not
  rise (their `CanvasViewport` takes the `rulerUnit` default and
  registration), nor Library's and Halo's (`CanvasSurface`'s identifier).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-canvas-*`, `suiteui-marks-*`, `suiteui-surface-*` and the
  Library loupe and Halo viewer shots.
