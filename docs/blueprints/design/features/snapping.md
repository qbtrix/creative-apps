# Feature packet: snapping

**Feature:** a drag lines up with what is already on the canvas: moving,
resizing and drawing, with one layer or several, snap edges and centres to
the other layers, the frame and the page; smart guides show what lined up,
with distance labels to the nearest neighbours and a hint when a gap equals
another; holding ⌘ turns snapping off for as long as it's held, and View >
Snap to Layers turns it off until turned back on, across relaunches.
Most-used first: whole points touch every drag (canvas-basics, reused),
edge and centre snapping nearly every move, guides and distances every
snapped drag, equal spacing when laying out rows, ⌘ and the menu toggle now
and then.
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/snapping`

**Covers:** the captain's call of 2026-10-16, "snapping in v1", after
using the app: "the canvas feels basic, needs better tool feedback". It
reverses the blueprint's "first item after v1" (`design.md` §1) and answers
the Design app UX review (2026-10-16), item 11 of its top 12 and R7. No
issue exists yet; the lead files one `gap` issue per slice at stage 1
(labels `gap`, `line:design`, `p1`), and each slice's last task closes its
issue. The lead also files one `needs-ui` issue (labels `needs-ui`,
`line:suiteui`): "SuiteUI: smart-guide marks, a line between two boxes with
a distance label", linking canvas-marks CM-5, whose guide marks span the
viewport and carry no label. SN-7 draws plain marks in the meantime
(`docs/engineering/swiftui-rules.md`, rule 11); nothing here waits on it.

**Depends on:** the design-contracts feature issue (the schema, the
workspace, the fixtures): SN-1 and SN-6 start when it closes. Within the
feature, SN-e (the engine) and SN-c (the screen) wait only on SN-a, the
contract, so the screen is built on the contract's stubs beside the engine
and the routes (`lead.md` rule 18).
- **Snap to pixel is canvas-basics CB-a**, not a task here. CB-2 makes
  every draw, move and resize land on whole points through
  `DesignPoint.wholePoints` and `DesignRect.wholePoints`; this feature snaps
  first and lets CB-2's rounding run after, unchanged.
- SN-b edits `DesignCanvasEditing.swift` and calls the engine, so it waits
  on SN-a and SN-e, and on its file's owners before it: **design-seams** (D0-3c, the several-layer and Option-drag routes),
  **canvas-basics CB-a** (CB-2, CB-3: whole points and the Text click-drag
  route) and **select-several SS-b** (S-5, the mid-gesture guard). The file
  passes design-seams → canvas-basics → select-several → snapping →
  design-seams-2, whose D2-3b now waits on SN-b.
- SN-c's App tasks wait on SN-a and on **design-window**: SN-7 on DW-d
  (`DesignCanvasFeedback.swift` after D0-9d; DW-b's live drag box and
  D0-8b's `bodyRuns` counter and `dragSamples` helper come before it), SN-8
  on DW-a (`DesignIntent.swift` from D0-5a, `DesignCommands.swift` from
  D0-6). SN-8 also waits on **canvas-basics CB-c** (CB-9 edits
  `DesignIntent.swift`) and **files-history FH-b** (FH-3 edits
  `DesignCommands.swift`). design-seams-2's D2-4b now waits on SN-c for
  both files. SN-f edits only the journey and render budget files SN-c
  owns, so it waits on SN-c, SN-b and SN-e.
- `design.canvas.guides` joins design-window D0-5a's up-front id list
  (`DesignControlID`), as DW-d's and canvas-basics' ids did.

No creative-core issue.

Blueprint sections: 1 (the v1 line), 3 (the usage map), 5.5 (the gesture
routes), 6 (canvas rules, the View menu), 7.1 (speed budgets; QD-S13 and
QD-S14 below are new rows), 8.2.

**Clean-room.** Every rule below is a behaviour stated from the review's
screens and long-repeated user complaints about vector tools in general,
never from another product's code, files or documentation.

## Top complaints this feature answers

The blueprint has no "top user complaints" list yet (review, "Gap in the
inputs"). These are the ones this feature fixes, as behaviour:

1. Lining two boxes up by eye, then reading X and Y to check, at 23 % zoom.
2. No sign of what a drag lined up with, or how far it is from its neighbours.
3. Rows of cards with uneven gaps, measured one by one.
4. A drag that snaps when the user wants it free, with no quick way out.
5. A snapping preference that resets every launch.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run (SN-a's MJ12, SN-e's MJ10 and SN-b's MJ11 on the
Linux gate).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SN-a | The guide types, the ⌘ and setting modifier, the layers a drag can line up with and the engine's shape are declared, with stubs for everything the screen calls (a fixed guide set while a drag runs, none otherwise), so the screen and the snap logic build in parallel. | SN-1, SN-9 | MJ12 | – (design-contracts, the feature) |
| SN-b | Moving, resizing and drawing on the canvas, with one layer or several and with an Option-drag copy, snap to those lines and gaps before whole points, build the engine once per drag, and snap to nothing while ⌘ is held. | SN-4, SN-5 | MJ11 | SN-a, SN-e, design-seams, canvas-basics CB-a, select-several SS-b (SN-4) |
| SN-c | The canvas draws the smart guides, distance labels and spacing hints while a drag snaps (the stubbed guides first, the live ones once the routes land), and View > Snap to Layers turns snapping off and on, remembered across relaunches. | SN-6, SN-7, SN-8 | `testSnapAndSmartGuides` | SN-a (SN-7, SN-8); design-window DW-d (SN-7); design-window DW-a, canvas-basics CB-c, files-history FH-b (SN-8) |
| SN-e | Given the layers a drag can line up with, the snap engine finds the offset that puts an edge or centre on another layer's, the frame's or the page's, or makes a gap equal its neighbour's, and names the guides, distances and spacing hints that result. | SN-2, SN-3 | MJ10 | SN-a |
| SN-f | Moving, resizing and drawing on the real canvas show the live smart guides, and the journey's snapped drags, guide reads and budgets pass on the live services. | SN-10, SN-11 | `testSnapAndSmartGuides` | SN-b, SN-e, SN-c |

SN-a is the contract and comes first (rule 12), and it declares every Model
signature the screen calls as a stub (rule 18, contract widening): the
guide types, the snapping-off flag (`.noSnap`, its init, the defaults key)
and `snapGuides`, which returns a fixed guide set while a drag runs and
nothing otherwise. SN-1 declares the types, the modifier, the candidates
and the engine files' signatures; SN-9 adds the stubs the screen draws
from. A slice needs two tasks, so the stubs are their own small task. It
is pure Model code with no wait past design-contracts, so it can be done on
Linux. Then two tracks run in parallel. SN-c, the screen, is `"ui": true`
(the feel gate and a Mac finisher pass, `lead.md` rules 15 and 17): it
waits only on SN-a and draws the stubbed guides, with View > Snap to Layers
as its visible control. SN-e builds the engine and SN-b the routes, and
never wait on the screen. SN-f is the integrate step: it waits on SN-b, SN-e
and SN-c, turns on the journey's live steps and runs the render budget on
the live guides, and its last task carries `feature-done`. It sits in its
own slice because a slice that waits on SN-b would stop SN-c counting as
the screen's slice (`scripts/waves check`).

## Journey steps

Every step of the XCUITest uses the mouse on visible controls (lesson 152):
Layers rows, the tool box, the top bar's Undo and the View menu, never a
shortcut. XCUITest can't see guides drawn in a canvas or look during a
drag, so the canvas publishes the guide set as an accessibility value:
`design.canvas.guides` reads the summary of the drag under way, and after
mouse-up the last drag's, until the next press (`"x 300, y 140, gap x 100,
spacing x 100"`, or `"none"`). Holding ⌘ is a key, so it's proven in MJ11
and SN-8's hosted check, not here. `-DesignFixture cards`, at the window's
fitted zoom (under 100 %). The steps that click View and read the menu's
checkmark run on the stubs; the steps that drag and read X, W, H or the
guides value need the live routes, so they sit behind
`DesignSnapJourneyTests.snapIsLive`, false until SN-10 sets it.

1. **SN-c** `testSnapAndSmartGuides` (`+Snap`, class
   `DesignSnapJourneyTests`; SN-6 writes it, SN-7 turns on the stub steps,
   SN-10 the live ones). Screen
   positions come from the `design.canvas.selection` element's frame, so
   each drag stops 2 screen points short of its target, inside the
   window's snap reach of 8 screen points:
   1. *A clean start:* click View; if Snap to Layers is unchecked, click
      it; otherwise click View again to close the menu. Click the rows of
      B, C and Pair in Layers in turn and note each selection frame.
   2. *Move:* click A's row and note its frame; drag A until its right
      edge is 2 pt short of B's left edge: X reads 200, the top bar's Undo
      reads "Undo Move", and the guides value holds "x 300". Click Undo.
   3. *Resize:* drag A's bottom-right handle until its right edge is 2 pt
      short of B's left edge: W reads 200 ("Undo Resize"), the guides value
      holds "x 300". Click Undo.
   4. *Several:* drag a marquee on Desktop's blank area from 10 pt above
      and left of A to 10 pt below and right of B (select-several's J5
      rule); drag A until the box's bottom is 2 pt short of Pair's bottom:
      "Undo Move", and the guides value holds "y 500". Click Undo.
   5. *Equal spacing:* click C's row; drag C left until its left edge is 2
      pt short of where its gap to B equals A's gap to B: X reads 600, the
      guides value holds "spacing x 100". Click Undo.
   6. *Draw:* click Rectangle in the tool box; drag from 2 pt right of B's
      top-right corner to 2 pt left of C's bottom-left corner: X 500, Y 140,
      W 200, H 80 ("Undo Add Rectangle"). Click Undo.
   7. *Off:* click View > Snap to Layers; repeat step 2's drag: X reads
      less than 200 and the guides value is "none". Click Undo.
   8. *Remembered:* relaunch with the same arguments; click View: Snap to
      Layers is unchecked (the menu item's `value`, listed `Unverified API`
      for the finisher); click View to close; repeat step 2's drag: X reads
      less than 200. Click Undo.
   9. *On again:* click View > Snap to Layers; repeat step 2's drag: X reads
      200. Click Undo. The journey leaves the setting on.
2. **MJ12** `walkSnapContract`, a Linux Model walk in
   `DesignSnapCandidateTests` on `cards` (SN-1 writes it, SN-9 extends it;
   green from SN-9): A's candidates; the modifiers map ⌘ or the setting off
   to `.noSnap`; `summary` of the empty set and of a full one;
   `snapGuides` is nil with no drag and `DesignSnapGuides.fake` while one
   runs; the engines' stubs find no line, no gap and no offset.
3. **MJ10** `walkEngine`, a Linux Model walk in `DesignSnapEngineTests` on
   `cards` (SN-1 writes it disabled, SN-3 turns it on): A's box at (297.4, 100.4) gets offset (2.6, -0.4) from the lines; C's box
   at x 603 gets -3 from the spacing; distances and spacing hints for each.
4. **MJ11** `walkSnapping`, a Linux Model walk in `DesignSnapWalkTests` on
   `cards` (SN-4 writes it disabled, SN-5 turns it on): a move, a several
   move, an Option-drag copy, a resize, a Shift and an Option resize, a
   rectangle draw and a Text click-drag, each snapped, then each again with
   `.noSnap`, ending on whole points with one undo step per gesture.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Canvas, a drag that snaps | nothing within reach: no guides; the layer follows the pointer on whole points | – | – (a 1 pt accent line for each edge or centre that lined up, spanning the moving box and the layers on it, with a small cross at each end; the distance to the nearest neighbour on each side as a caption pill on a thin line across the gap; at an equal gap, each equal gap carries the same pill; one size at any zoom; `design-canvas-snap-guides`, `design-canvas-snap-spacing`) |
| Canvas, ⌘ held or Snap to Layers off | – | – | – (no guides, no labels; whole points still apply) |
| Canvas, after mouse-up | – | – | – (the guides go; `design.canvas.guides` keeps the last drag's summary until the next press) |
| View menu | – | – | – (Snap to Layers, a checkmark item after Fit Page, on by default, no key equivalent; enabled with no file open, since it's a preference) |

## Contract slice

Model, Linux. New `Sources/DesignModel/DesignSnapping.swift` (SN-1):

```swift
/// A line the moving box sits on after a snapped step, in document points.
public struct DesignSnapLine: Sendable, Hashable {
    public enum Axis: Sendable, Hashable { case x, y }   // x: a vertical line at `at`
    public var axis: Axis
    public var at: Double
    /// The span drawn on the other axis: the moving box and every candidate on the line.
    public var from: Double, to: Double
}
/// A labelled gap: from the moving box to a neighbour, or one of a pair of equal gaps.
public struct DesignSnapGap: Sendable, Hashable {
    public var axis: DesignSnapLine.Axis                // x: a horizontal gap
    public var from: Double, to: Double                 // its ends on `axis`
    public var across: Double                           // where the label sits on the other axis
    public var isSpacing: Bool                          // an equal-spacing hint
    public var length: Int { get }                      // whole points
}
public struct DesignSnapGuides: Sendable, Hashable {
    public var lines: [DesignSnapLine]
    public var gaps: [DesignSnapGap]
    /// "x 300, y 140, gap x 100, spacing x 100": lines (x, then y, by position), then gaps,
    /// then spacing hints; "none" when empty. The guide mark's accessibility value.
    public var summary: String { get }
    public init(lines: [DesignSnapLine] = [], gaps: [DesignSnapGap] = [])
    public static let empty: DesignSnapGuides
    /// A fixed set for the screen to draw before the routes exist (SN-9): one line at x 300,
    /// a gap of 100 on x and a spacing hint of 100; its `summary` is "x 300, gap x 100, spacing x 100".
    public static let fake: DesignSnapGuides
}
extension DesignWorkspace {
    /// The guides of the drag under way: nil when no gesture runs, empty when one runs and
    /// nothing lined up. A stub until SN-4: nil with no gesture, `.fake` while one runs
    /// (SN-1 returns nil, SN-9 adds the fake); SN-4 reads the gesture and never changes the signature.
    public var snapGuides: DesignSnapGuides? { get }
}
extension DesignModifiers {
    /// Layer snapping off for this step: ⌘ held, or View > Snap to Layers off. Whole points still apply.
    public static let noSnap = DesignModifiers(rawValue: 4)
    /// The modifiers of one pointer step: `.noSnap` when `command` or when `snapToLayers` is false.
    public init(shift: Bool, option: Bool, command: Bool, snapToLayers: Bool)
}
public enum DesignSnapSettings {
    /// The defaults key View > Snap to Layers writes; a missing value reads as on.
    public static let defaultsKey = "design.snapToLayers"
}
/// A box a drag can line up with: a layer, or the page (id nil).
struct DesignSnapCandidate: Sendable, Equatable { var id: String?; var frame: DesignRect }
extension DesignWorkspace {
    /// The siblings of the moving layers (several: of each), their parent frames and the page
    /// (a draw: the children of the frame it draws into, that frame and the page). Skips hidden
    /// layers, the moving layers and everything inside them; locked layers count.
    func snapCandidates(moving: [String], drawingInto parent: String?) -> [DesignSnapCandidate]
}
```

The engine, built once per gesture from the candidates, each in its own
file so SN-2 and SN-3 share nothing (SN-1 adds both with these signatures
and stub bodies that return nothing: no line, no gap, no offset):

```swift
// DesignSnapLines.swift (SN-2): each candidate's min, centre and max on both axes, bucketed by position.
struct DesignSnapLines: Sendable {
    init(_ candidates: [DesignSnapCandidate])
    /// The smallest offset within `tolerance` that puts one of `values` on a line; nil if none.
    func offset(_ axis: DesignSnapLine.Axis, for values: [Double], tolerance: Double) -> Double?
    /// The lines `box`'s min, centre and max sit on exactly, each spanning the box and its candidates.
    func lines(on box: DesignRect) -> [DesignSnapLine]
}
// DesignSnapGaps.swift (SN-3): the candidates in a coarse grid, for neighbours and equal gaps.
struct DesignSnapGaps: Sendable {
    init(_ candidates: [DesignSnapCandidate])
    /// The smallest offset within `tolerance` that makes `box`'s gap to its neighbour on one side equal
    /// that neighbour's gap to the next one beyond it, or centres `box` between its two neighbours.
    func spacingOffset(_ axis: DesignSnapLine.Axis, for box: DesignRect, tolerance: Double) -> Double?
    /// The gap to the nearest neighbour on each side, and the spacing hints where `box` sits at an equal gap.
    func gaps(around box: DesignRect) -> [DesignSnapGap]
}
```

App (macOS): `DesignSnapGuides` (`Sources/DesignApp/DesignSnapGuides.swift`)
in DW-d's `DesignCanvasFeedback` overlay; `DesignModifiers.current` reads ⌘
and the setting; a Snap to Layers toggle in `DesignViewMenu`.

## Pseudocode

```
candidates (SN-1), once per gesture:
  parents = the parent of each moving id (a draw: the frame it draws into; nil: the page's top level)
  for each parent: its visible children not moving, the parent itself (if a frame); then the page rect
  skip: hidden in tree, the moving ids and their subtrees. Locked: kept (lining up never moves it)

lines (SN-2), built once:
  for each candidate: x lines minX, midX, maxX; y lines minY, midY, maxY; each into a bucket
    keyed by Int(floor(v / 64)), kept with the candidate's span on the other axis
  offset(axis, values, tol): for each value v, read buckets floor((v - tol)/64) ... floor((v + tol)/64);
    best = the line with the smallest |line - v| <= tol (inclusive); equal |d|, opposite signs: the negative
  lines(on: box): the lines exactly equal (|d| < 0.001) to box's min, centre or max on each axis,
    one DesignSnapLine per position, spanning box and every candidate on it

gaps (SN-3), built once:
  grid of 256 pt cells; each candidate goes in every cell its frame covers
  neighbour(box, side): walk cells outward from box on that side, at most 8 cells (2,048 pt);
    nearest candidate that overlaps box on the other axis, doesn't contain box, and box doesn't touch
  gaps(around: box): one gap per side to its neighbour; spacing hints where box's gap on a side equals
    (to 0.5 pt) the neighbour's gap to its own neighbour beyond, or box's two gaps on an axis are equal
  spacingOffset(axis, box, tol): the smallest offset within tol giving either equal gap

routes (SN-4 moves, SN-5 resize and draw), in DesignCanvasEditing:
  at the press (beginGesture), for move, several move, Option-drag copy, resize, several resize,
  draw and text:
    gesture.snap = (DesignSnapLines(c), DesignSnapGaps(c)) with c = snapCandidates(...)
    gesture.snapBuilds += 1                         # stays 1 for the whole gesture
  every step, from the gesture's start as today, then CB-2's whole points as today:
    .noSnap: snap nothing, gesture.guides = empty
    tol = handleTolerance                           # the window keeps it SuiteSpacing.s / zoom
    move routes:  box = the moving box at start + delta (several: the selection's bounds)
                  per axis: d = the smaller of lines.offset(box min, mid, max) and gaps.spacingOffset
                  delta += d
    resize:       box = today's resized frame; values = the handle's edges only (a corner one x, one y)
                  per axis: d = lines.offset(the dragged edge); the dragged edge moves by d
                  Shift: only the nearer axis's d, the other side follows the aspect
                  Option: the opposite edge mirrors, so the box stays centred
    draw, text:   once the pointer has moved, start and end each += lines.offset per axis;
                  Shift: the end's nearer axis, then the square. The route gets a copy of the
                  gesture whose start is the snapped one, so DesignDrawing.swift doesn't change
    after whole points: gesture.guides = lines.lines(on: final box) + gaps.gaps(around: final box)
  snapGuides = gesture?.guides                      # nil once endDrag clears the gesture

  a click that never moves snaps nothing: a Move click selects, and a drawing tool's click
    places its default box at the raw point on whole points, where DW-d's preview showed it
  nudges and typed values never snap
  snap first, whole points second: a candidate at a fraction (an old file's 820.3) can't be met,
    the rounding wins, and no guide is reported for it

overlay (SN-7), in DesignCanvasFeedback, no model write; on the stubs it draws .fake, later the live set:
  g = (live.workspace ?? model).snapGuides
  draw g's lines (1 pt accent, end crosses) and gaps (thin line plus caption pill), one size at any zoom
  @State last: String?                              # the a11y value after mouse-up
  onChange(of: g) { old, new in
      if new == nil, let old { last = old.summary } else if new != nil, last != nil { last = nil } }
  design.canvas.guides: value g?.summary ?? last ?? "none"   # at most two writes per gesture

menu and modifiers (SN-8):
  View: Toggle("Snap to Layers", isOn: @AppStorage(DesignSnapSettings.defaultsKey) = true), after Fit Page
  DesignModifiers.current = DesignModifiers(shift:, option:, command: flags ∋ .command,
      snapToLayers: UserDefaults.standard.object(forKey: key) as? Bool ?? true)
```

Modifier check. Shift already toggles a layer on a Move press, squares a
draw and keeps a resize's aspect; Option resizes from the centre, makes a
drag a copy (copy-group, design-seams D0-3c) and shows DW-d's copy pointer.
⌘ has no meaning on a canvas drag today: `CanvasViewport` uses it only for
the zoom keys ⌘=, ⌘− and ⌘0, it ignores ⌘-arrows for panning,
`DesignModifiers.current` doesn't read it, and no packet gives ⌘-drag or
⌘-click a meaning. So ⌘ is free, and with Shift or Option it keeps their
meanings. Whole points stay on under ⌘, as canvas-basics says.

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: snapping`,
`Slice:`, `Fast-Check: pass`, `Head:`, the snapshot PNGs it changes, and
for a task with mutations its `Mutate:` score line. SN-11 also carries
`feature-done`. Paths drop `Sources/DesignModel/` and `Sources/DesignApp/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SN-1 | – | The contract: the guide types, `summary`, `.noSnap` and its init, the defaults key, `snapGuides` (nil), `snapCandidates`; `DesignSnapLines` and `DesignSnapGaps` with their signatures and stub bodies; MJ10 written first, disabled; MJ12 written | `DesignSnapping.swift`, `DesignSnapLines.swift`, `DesignSnapGaps.swift`; `Tests/DesignModelTests/DesignSnapCandidateTests.swift`, `Tests/DesignModelTests/DesignSnapEngineTests.swift`; `Tests/mutations/DesignModel.DesignSnapping.json` | – | ~300, 6 |
| SN-2 | – | Edges and centres: the bucketed lines, `offset` and `lines(on:)` | `DesignSnapLines.swift`; `Tests/DesignModelTests/DesignSnapLineTests.swift`; `Tests/mutations/DesignModel.DesignSnapLines.json` | SN-1 | ~250, 3 |
| SN-3 | SN-e's gap issue (closes) | Distances and equal spacing: the grid, `gaps(around:)` and `spacingOffset`; turns on MJ10 | `DesignSnapGaps.swift`; `Tests/DesignModelTests/DesignSnapGapTests.swift`, `Tests/DesignModelTests/DesignSnapEngineTests.swift`; `Tests/mutations/DesignModel.DesignSnapGaps.json` | SN-1, SN-2 | ~300, 4 |
| SN-4 | – | The gesture builds the engine once at the press; a move, a several move and an Option-drag copy snap before whole points; `.noSnap` snaps nothing; `snapGuides` reads the gesture, replacing SN-9's fake; MJ11 written first, disabled | `DesignCanvasEditing.swift`, `DesignSnapping.swift`; `Tests/DesignModelTests/DesignSnapMoveTests.swift`, `Tests/DesignModelTests/DesignSnapWalkTests.swift`, `Tests/DesignModelTests/DesignSnapBudgetTests.swift`; `Tests/mutations/DesignModel.DesignCanvasEditing.json`, `Tests/mutations/DesignModel.DesignSnapping.json` | SN-2, SN-3, SN-9; design-seams; canvas-basics CB-a; select-several SS-b | ~350, 7 |
| SN-5 | SN-b's gap issue (closes) | A resize (one or several, Shift, Option) snaps its dragged edges; a draw and a Text click-drag snap their start and end; turns on MJ11 | `DesignCanvasEditing.swift`; `Tests/DesignModelTests/DesignSnapResizeDrawTests.swift`, `Tests/DesignModelTests/DesignSnapWalkTests.swift`, `Tests/DesignModelTests/DesignSnapBudgetTests.swift`; `Tests/mutations/DesignModel.DesignCanvasEditing.json` | SN-4 | ~320, 5 |
| SN-6 | – | SN-c's journey written first, `XCTSkip("waits on SN-7")`, its drag and guide steps behind `snapIsLive` | `UITests/DesignJourneyTests+Snap.swift` | – | ~170, 1 |
| SN-7 | SN-c's gap issue (closes) | The guide overlay in DW-d's slot, drawing `snapGuides` (the fake's set until the routes land): lines, distance labels and spacing hints, the `design.canvas.guides` value; snapshots from fixed guide sets; the render budget test on the fake guides; turns on SN-6's journey except the `snapIsLive` steps | `DesignSnapGuides.swift`, `DesignCanvasFeedback.swift`; `Tests/AppSnapshotTests/DesignSnapGuideSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignSnapTests.swift`; `UITests/DesignJourneyTests+Snap.swift` | SN-6, SN-8, SN-9; design-window DW-d | ~300, 5 |
| SN-8 | – | View > Snap to Layers, stored under `DesignSnapSettings.defaultsKey`; `DesignModifiers.current` adds `.noSnap` for ⌘ or the setting off | `DesignIntent.swift`, `DesignCommands.swift`; `Tests/AppSnapshotTests/DesignSnapSettingTests.swift` | SN-1; design-window DW-a; canvas-basics CB-c; files-history FH-b | ~160, 3 |
| SN-9 | SN-a's gap issue (closes) | The stubs the screen calls: `DesignSnapGuides.init`, `.empty` and `.fake`, `snapGuides` returning `.fake` while a drag runs and nil otherwise; MJ12 extended and green | `DesignSnapping.swift`; `Tests/DesignModelTests/DesignSnapCandidateTests.swift`; `Tests/mutations/DesignModel.DesignSnapping.json` | SN-1 | ~120, 3 |
| SN-10 | – | The integrate step: sets `snapIsLive`, so the journey's snapped drags and guide reads run on the live routes (steps 2 to 9); fixes whatever the live guides show the overlay got wrong | `UITests/DesignJourneyTests+Snap.swift` | SN-5, SN-7 | ~60, 1 |
| SN-11 | SN-f's gap issue (closes) | The render budget on the live guides: a 120-sample move, resize and draw read the live copy's summary; `feature-done` | `Tests/AppSnapshotTests/RenderBudgetDesignSnapTests.swift` | SN-10 | ~120, 1; `feature-done` |

SN-2 and SN-3 each fill the stub file SN-1 adds, so they share no file.
SN-3 waits on SN-2 only because MJ10, which it turns on, walks the lines
too. SN-9 edits the `DesignSnapping.swift` SN-1 adds and runs beside SN-2.
SN-4 calls both engines and edits `DesignSnapping.swift` after SN-9
(`snapGuides` reads the gesture instead of returning the fake). SN-5 edits
SN-4's `DesignCanvasEditing.swift`, walk and budget file. SN-7 draws
`snapGuides` and needs none of SN-2 to SN-5: it runs on SN-9's fake, and it
turns on the journey's menu steps with SN-8's toggle. SN-10 and SN-11 are
the integrate step and wait on SN-5 and SN-7 (SN-3 comes with SN-5): the
journey's drags and the render budget need the routes and the screen both.
SN-8 needs only SN-1's `.noSnap` and its init. Each journey or walk file
passes to the task that turns it on. Existing Model tests that drag a layer near another
and expect the raw position back are updated in SN-4's or SN-5's PR, which
lists them. No task edits a shared doc (`docs/c4/model.json`,
`docs/design.md`, the blueprint or `waves.md`): every new file sits in the
`DesignModel`, `DesignApp` and test components already. The QD rows and
the complaints above move into the blueprint at its next revision.

## Build waves

- Wave 1: SN-1, SN-6. Independent in this wave: both.
- Wave 2: SN-2, SN-9, SN-8 (design-window DW-a, canvas-basics CB-c and files-history FH-b merged). Independent in this wave: all three.
- Wave 3: SN-3, SN-7 (design-window DW-d merged). Independent in this wave: both.
- Wave 4: SN-4 (design-seams, canvas-basics CB-a and select-several SS-b merged). Independent in this wave: SN-4 alone.
- Wave 5: SN-5. Independent in this wave: SN-5 alone.
- Wave 6: SN-10. Independent in this wave: SN-10 alone.
- Wave 7: SN-11 (`feature-done`, final). Independent in this wave: SN-11 alone.

Longest chain: SN-1 → SN-2 → SN-3 → SN-4 → SN-5 → SN-10 → SN-11 (7).
Chain of 7: SN-2 fills SN-1's line stub; SN-3's MJ10 walks SN-2's lines;
SN-4's routes call both engines; SN-5 edits SN-4's `DesignCanvasEditing.swift`;
SN-10 turns on the live journey steps once the routes and the screen have
merged; SN-11 times the live guides and carries `feature-done`.
SN-a, the contract, is done after its first two links (SN-1, SN-9), and the
screen (SN-6, SN-8, SN-7) is done by wave 3, before the engine and the
routes, on the stubs.

## Acceptance test per task

Checks first (rule 13): SN-e's walk MJ10 merges in SN-1, SN-b's MJ11 in
SN-4, SN-c's journey in SN-6, each disabled by name (SN-a's MJ12 merges
green); the Model tests merge
with their code. Numbers are on `cards` with the workspace's default
`handleTolerance` of 6 pt: A (100, 100, 100 × 80), B (300, 140, 200 × 80),
C (700, 100, 100 × 120), Title (100, 40, 200 × 32), Pair (900, 400,
300 × 100), Locked (400, 600, 100 × 100), Hidden (600, 600), all in Desktop
(0, 0, 1440 × 1024). Mutations go in the plan named in the task's owned
files (`scripts/mutate --plan DesignModel.<File>`).

| id | test | fails when | mutations |
|---|---|---|---|
| SN-1 | `DesignSnapCandidateTests`: A's candidates are B, C, Title, Pair, Locked, Desktop and the page, never A or Hidden; Pair's leave out E1 and E2; A and B moving together leave out both; a draw into Desktop gets Desktop's visible children, Desktop and the page; `DesignModifiers(shift: false, option: false, command: true, snapToLayers: true)` holds `.noSnap`, so does `snapToLayers: false`, and neither alone with `command: false, snapToLayers: true`; `summary` of an empty set is "none" and of one line at x 300, a gap of 100 on x and a spacing hint of 100 is "x 300, gap x 100, spacing x 100"; `snapGuides` is nil; the engines' stubs return no line, no gap and no offset; MJ12 written; MJ10 compiles, disabled "waits on SN-3" | a hidden or moving layer is a candidate, a locked one is dropped, or ⌘ or the setting fails to turn snapping off | `snapCandidates`: the hidden check dropped; the moving subtree kept (only the moving ids skipped). `init(shift:option:command:snapToLayers:)`: `||` becomes `&&` |
| SN-2 | `DesignSnapLineTests` on A's candidates: values 297.4, 347.4, 397.4 on x give +2.6 (300, and 400 for the right edge); 294 gives +6 (exactly the tolerance); 293.9 gives nil; on y 100.4, 140.4, 180.4 give -0.4; a value equally far from two lines, 3 below and 3 above, gives -3; `lines(on:)` A at (300, 100) gives x 300 spanning Title and B, x 400, y 100, y 140 and y 180; a box at a fraction gives no line; a line at 129 catches a value at 127, across the 128 bucket edge | a value past the tolerance snaps, the nearest line loses, or a guide is reported off its line | `offset`: `<= tolerance` becomes `< tolerance`; the bucket range reads only floor(v / 64), so a line across a bucket edge is missed. `lines(on:)`: the centre left out |
| SN-3 | `DesignSnapGapTests`: A's box at its own place has gaps x 100 to B and y 28 to Title and none left or below; C's box at x 603 gets spacing offset -3 on x (B's gap to A is 100), and at 600 the gaps hold "spacing x 100" twice (A to B, B to C); B's box at x 348.6 gets +1.4 (centred, 150 each side); a neighbour that contains the box (Desktop) or overlaps it gives no gap; a neighbour past 2,048 pt gives none; MJ10 passes | a gap is measured to the parent, an overlapping layer or the wrong side, or an equal gap is missed | `neighbour`: the overlap check on the other axis dropped, so Pair counts as A's right neighbour; the equal-gap compare uses the box's own gap twice. `spacingOffset`: the centred case dropped |
| SN-4 | `DesignSnapMoveTests` on `cards`, `.live`: A moved by (197.4, 0.4) lands at (300, 100) with "Undo Move" and `snapGuides` holding x 300 mid-drag; the same with `.noSnap` lands at (297, 100) with no guides; A by (0.4, 0.4) stays at (100, 100) with gaps x 100 and y 28; A and B moved by (0, 277.6) land at y 380 and 420, keeping their gap, guide y 500; an Option-drag of A and B by the same lands the copies there in one "Duplicate" step, the originals unmoved; C by (-97, 0.4) lands at (600, 100) with "spacing x 100"; a 120-sample move keeps `gesture.snapBuilds` at 1 and ends equal to its last sample alone; after `endDrag` `snapGuides` is nil. `DesignSnapBudgetTests`: QD-S13 and QD-S14 (move) on `crowd` and on a flat page of 2,000 rectangles | a move ignores a line or snaps under `.noSnap`, several layers drift apart, the engine is rebuilt per sample, or a step leaves its gate | `DesignCanvasEditing`: the index built in each step instead of at the press; the `.noSnap` check dropped; the several move snaps A's frame instead of the selection's bounds. `DesignSnapping`: `snapGuides` keeps the last guides after `endDrag` |
| SN-5 | `DesignSnapResizeDrawTests` on `cards`, `.live`: A's bottom-right handle by (97.6, 0.4) gives W 200, H 80 ("Undo Resize"), and with `.noSnap` W 198; with Shift W 200, H 160; with Option X 0, W 300, Y 100, H 80; with A and B selected, the box's bottom-right handle by (197.6, 0) puts the box's right edge on C's left edge, 700; a Rectangle drag from (497.5, 137.6) to (697.2, 222.3) gives (500, 140, 200, 80), and with `.noSnap` (498, 138, 199, 84); a Text drag from (497.5, 137.6) to (697.2, 160) gives a 200 pt fixed-width box at x 500; a click with Rectangle at (497.5, 137.6) places its default box at (498, 138), unsnapped, where DW-d's preview showed it; MJ11 passes; QD-S14 (resize, draw) | a resize snaps the edge it didn't drag, Shift or Option lose their meaning, a draw's start or end ignores a line, or a step leaves its gate | `DesignCanvasEditing`: the resize snaps every edge of the box, not the handle's; with Shift both axes snap, breaking the aspect; the draw snaps its end but not its start |
| SN-6 | The journey compiles and skips by name on the macOS run | the skip names another task | – (journey) |
| SN-7 | `DesignSnapGuideSnapshots`: `design-canvas-snap-guides` (a fixed set: a line at x 300 with its end crosses, a gap x 100 and a gap y 28), `design-canvas-snap-spacing` (a fixed spacing set: two "100" pills), light and dark, at 50 % and 200 % zoom (one size); `RenderBudgetDesignSnapTests.snappedDrag` (the hosted window, D0-8b's `dragSamples`, `crowd`, Snap to Layers on, the stub's `.fake` guides): a 120-sample move runs `DesignEditor`'s body 3 times or fewer, and after 60 samples `design.canvas.guides` reads the fake's summary while the model's layer is unmoved; after mouse-up the value keeps the last summary and a new press clears it; the journey's stub steps pass on the macOS run (View checkmark, relaunch, the toggle) | the guides are missing, scale with zoom, read the model mid-drag, or a sample runs the editor body | – (view code; the Model half is SN-1 to SN-5's) |
| SN-8 | `DesignSnapSettingTests` (macOS, a private `UserDefaults` suite): with no stored value Snap to Layers reads on and `.current`'s mapping has no `.noSnap`; stored false, the mapping has it; toggling the menu item writes the key; the View menu lists Snap to Layers after Fit Page, enabled with no file open | the setting doesn't persist, reads off when missing, or ⌘ and the setting aren't both honoured | – (the mapping's mutations are SN-1's) |
| SN-9 | `DesignSnapCandidateTests` (MJ12): `snapGuides` is nil with no drag and `DesignSnapGuides.fake` while a drag runs, with `summary` "x 300, gap x 100, spacing x 100"; `.empty.summary` is "none"; the init defaults to no lines and no gaps | the screen gets nothing to draw before the routes exist, or a stale fake outlives the drag | `snapGuides`: the no-gesture nil check dropped, so the fake shows with no drag; the stub returns `.empty` instead of `.fake` |
| SN-10 | The journey passes on the macOS run with `snapIsLive` set: steps 2 to 9, each drag's Undo title and X, W, H or guides value as listed | a step still passes only on the stubs (step 7's "none" under the fake) or a live drag shows no guides | – (journey) |
| SN-11 | `RenderBudgetDesignSnapTests.snappedDrag` on `crowd` with live guides: a 120-sample move, resize and draw each run `DesignEditor`'s body 3 times or fewer, and after 60 samples of each `design.canvas.guides` reads the live copy's summary while the model's layer is unmoved | a snapped step runs the editor body, or the overlay reads the model mid-drag | – (view code) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-S13 snap engine at the press | lines and grid built from 1,999 siblings (a flat page of 2,000 rectangles) ≤ 2 ms device / ≤ 20 ms Linux debug; on `crowd` (a frame among 40) well under | `DesignSnapBudgetTests.engineBuild` (SN-4) |
| QD-S14 one snapped step | lines, spacing, whole points and guides for one move, resize or draw step on the flat page ≤ 0.2 ms / ≤ 2 ms; QD-S1 to QD-S3 stay inside their gates with snapping on | `DesignSnapBudgetTests.snapStep` (SN-4 move, SN-5 resize and draw); `DesignSelectBudgetTests` (select-several S-8) |
| never per sample over all layers | a 120-sample drag builds the engine once (`snapBuilds == 1`) | `DesignSnapMoveTests` (SN-4) |
| render: snapped drag | 120-sample move, resize and draw on `crowd` with Snap to Layers on: ≤ 3 `DesignEditor` body runs each (the window body, `lead.md` rule 15a; `swiftui-rules.md` rules 1 and 6); guide overlay frame p95 ≤ 8 ms, reported, checked by the Mac finisher | `RenderBudgetDesignSnapTests.snappedDrag` (SN-7 on the stub's fake guides, SN-11 on the live ones) |
| QB-F3 one gesture, one step | a snapped move, resize, draw and Option-drag copy are one step each | MJ11, the journey |
| no dead controls | Snap to Layers acts in every state; the guide mark is a value, not a control | J15 (design-window D0-7b) |
| audit | zero new `design` counts; `design.canvas.guides` carries its id | the macOS run's audit |

## Done check

Per slice (`lead.md` rule 6): its journeys green on a Design-scoped run that
contains its last merged PR (MJ10 and MJ11 on the Linux gate too), no open
`finding` for the slice, and every mutation in its plans caught; for SN-c
also the feel gate (rule 15: the render budget row, the `mouse` and `taste`
lenses) and its `Mac-Finish:` line (rule 17); then `Belt-Slice-Done:
<slice> <run url>` on the feature issue. The feature is done when SN-a,
SN-e, SN-b, SN-c and SN-f are, with zero new `design` audit counts and the
`Belt-Contact-Sheet:` comment listing the journey and the three walks.
