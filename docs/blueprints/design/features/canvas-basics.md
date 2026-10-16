# Feature packet: canvas-basics

**Feature:** the canvas behaves the way people expect from the first
minute: drawing, moving and resizing land on whole points; a text box fits
its text (a clicked box grows with it, a dragged box keeps its width and
wraps); layers past the page's edge stay visible, dimmed; and the page's
size is editable. Most-used first: whole points touch every draw and drag,
text fitting every text layer, the page only now and then.
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/canvas-basics`

**Covers:** the Design app UX review (2026-10-16, R6), items 5, 9 and 10 of
its top 12: fractional coordinates (`ui/design-inspector.png`: X 820.3,
W 601.7), text clipped to a fixed box, and layers past the page invisible
with a page size that can't change (`ui/design-new-file.png`,
`ui/design-shell-handles-dark.png`). No issue exists for them yet; the lead
files one `gap` issue per slice at stage 1 (labels `gap`, `line:design`,
`p1`), and each slice's last task closes its issue.

**Depends on:** the design-contracts feature issue (the schema, the live
stubs, the fixtures): CB-1, CB-4, CB-7 and CB-8 start when it closes.
- CB-a's Model tasks also wait on **design-seams** (D0-3c owns the gesture
  routes in `DesignCanvasEditing.swift`). select-several's S-5 waits on
  CB-a in turn, so the file passes design-seams → canvas-basics →
  select-several → snapping → design-seams-2.
- CB-b waits on **style-rows SR-m** (`DesignText.swift`,
  `Live/LiveStyling.swift`) and **SR-t** (`DesignTextFont.swift`,
  `DesignTextArtwork.swift`, `DesignTextEditor.swift`), and its App task
  on **all of design-window** (`DesignWindow.swift`).
- CB-c's App task waits on **all of design-window** (`DesignIntent.swift`,
  `DesignWindow.swift`, `DesignCanvas.swift`, and DW-a's
  `DesignInspectorPage.swift` slot) and on CB-b (`DesignWindow.swift`).
- design-window's DW-d waits on CB-a: its journey's Text click-drag step
  drives CB-3's route.

SuiteUI: `CanvasViewport` clips its content to the artboard, so CB-9
draws the layers past the edge in the canvas overlay, which isn't clipped;
no SuiteUI change is needed for that. Its `onPointer` reports nil past the
artboard, so hovering a layer past the edge shows no hover outline: DW-d's
`needs-ui` issue ("CanvasViewport: report the pointer past the artboard")
covers it, and nothing here waits on it. No creative-core issue.

Blueprint sections: 3 (the usage map, tier 1), 4 (J3), 5.1 (`DesignNode`,
`DesignTextStyle`), 6 (canvas and inspector rules), 7.1 (QD-S1 to QD-S3),
8.2 (wave 1).

**Clean-room.** Every rule below is a behaviour stated from the review's
screens and long-repeated user complaints about vector tools in general,
never from another product's code, files or documentation.

## Top complaints this feature answers

The blueprint has no "top user complaints" list yet (review, "Gap in the
inputs"). These are the ones this feature fixes, as behaviour:

1. Values like 820.3 after a drag: edges off the pixel grid, numbers that read as noise.
2. Text cut off when it outgrows its box, at a larger size or a longer line.
3. A box drawn for a paragraph that doesn't wrap.
4. A layer dragged past the page that vanishes, with only its handles left.
5. A page size fixed at creation.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run (CB-a's MJ9 also on the Linux gate).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| CB-a | Drawing, moving and resizing on the canvas land on whole points at any zoom, and a Text click-drag makes a text box as wide as the drag. | CB-1, CB-2, CB-3 | `testDrawMoveResizeOnWholePoints`, MJ9 | design-seams (CB-2, CB-3) |
| CB-b | A clicked text box grows and shrinks with its text, a dragged one keeps its width, wraps and grows down, and a size change refits the box, so no text is cut off. | CB-4, CB-5, CB-6 | `testTextBoxFitsItsText` | CB-a, style-rows SR-m (CB-5); style-rows SR-t, design-window (CB-6) |
| CB-c | Layers past the page's edge show dimmed instead of vanishing, and the page's width and height are editable in the inspector, one undo step each. | CB-7, CB-8, CB-9 | `testPageSizeAndPastThePage` | design-window, CB-b (CB-9) |

CB-b and CB-c are the UI slices (`"ui": true` in the `.wave.json`: the feel
gate, rule 15, and the Mac finish, rule 17); CB-a is Model only. Their view
tasks (CB-6, CB-9) call Model code their own slice adds
(`commitTextEdit(extent:)`, `setPageSize`), which design-contracts doesn't
declare, so they keep their waits; CB-9, the `feature-done` task, is the
integrate step that runs the journeys on `.live`.

CB-a is first and Model only (rule 12): CB-3's Text click-drag route is
what DW-d's preview and journey plug into.

## Journey steps

Every step uses the mouse on visible controls (lesson 152): tool box
buttons, the top bar's zoom buttons, Layers rows and inspector fields,
never a shortcut. Live services, `-DesignFixture cards`.

1. **CB-a** `testDrawMoveResizeOnWholePoints` (`+WholePoints`, class
   `DesignWholePointsJourneyTests`; CB-1 writes it, CB-2 turns it on):
   click the top bar's zoom-out three times; click Rectangle in the tool
   box; drag a box on Desktop: the inspector's X, Y, W and H each read a
   whole number ("Undo Add Rectangle"); drag the rectangle by an odd
   distance: X and Y whole ("Undo Move"); drag its bottom-right handle:
   W and H whole ("Undo Resize").
2. **MJ9** `walkWholePoints` (CB-2), a Linux Model walk in
   `DesignWholePointsTests` on `cards`: a draw from (100.3, 200.7) to
   (219.6, 280.2), a move by (13.4, -7.8) and a resize by (5.5, 0.4), each
   ending on whole points; Shift keeps the square whole.
3. **CB-b** `testTextBoxFitsItsText` (`+TextBox`, class
   `DesignTextBoxJourneyTests`; CB-4 writes it, CB-6 turns it on): click
   Text in the tool box; click Desktop's blank area; type "A longer line of
   text"; click the canvas's blank area to commit; click the new layer's
   row in Layers: W reads more than 120 and H at least 16; click Title's
   row; click the Size field, type 48, Return: H reads at least 48 and W
   grew; click Text, click-drag a box 150 pt wide, type two sentences,
   click the blank area: W reads 150 and H more than one line.
4. **CB-c** `testPageSizeAndPastThePage` (`+Page`, class
   `DesignPageJourneyTests`; CB-7 writes it, CB-9 turns it on): click the
   page's row in Pages: the inspector shows Width 1440 and Height 1024;
   click Width, type 800, Return: the status line reads "800 × 1024 pt" and
   the top bar's Undo reads "Undo Change Page Size"; Desktop's part past
   800 still shows, dimmed (the canvas shot is attached; the pixels are
   CB-9's snapshot); click Undo: Width reads 1440.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, page selected | no file: as today | a width or height under 1 or past 100,000 clamps; a non-number puts the field back | – (Width and Height `ScrubField` rows, ids `design.inspector.page-width` and `-height`; `design-inspector-page`) |
| Canvas, past the edge | nothing past the edge: as today | – | – (layers past the page draw at 40% opacity outside the page and in full inside it, with their selection marks; `design-canvas-past-edge`) |
| Canvas, text box | – | – | – (auto width: the box hugs the text; fixed width: the text wraps at the box's width; `design-text-fit`) |
| Inline editor | – | – | – (the field grows with its text in an auto-width box, wraps in a fixed one) |

## Contract slice

Model, Linux. Whole points (CB-2), new `Sources/DesignModel/DesignWholePoints.swift`:

```swift
extension DesignPoint {
    /// Both coordinates rounded to the nearest whole point (.5 rounds up); non-finite stays as is.
    public var wholePoints: DesignPoint { get }
}
extension DesignRect {
    /// The rectangle with each edge on a whole point, both sides at least 1.
    public var wholePoints: DesignRect { get }
}
```

Text boxes (CB-3, CB-5): `DesignTextStyle` (`Contracts/StyleTypes.swift`)
gains an optional `fixedWidth: Bool?`: nil or false, the box fits its text;
true, it keeps its width and wraps. It's left out of the file when unset,
so existing files open unchanged and keep their bytes. In `DesignText.swift`:

```swift
/// A text's measured size in points, as the app lays it out.
public struct DesignTextExtent: Sendable, Hashable { public var width, height: Double }
extension DesignWorkspace {
    /// Ends the edit as today; with `extent`, the box fits it in the same step: auto width takes
    /// both sides, fixed width only the height, each rounded up to a whole point, at least 1.
    public mutating func commitTextEdit(extent: DesignTextExtent?)
}
```

`LiveStyling.setTextStyle` (CB-5) refits an auto-width box by the size's
ratio (both sides), a fixed-width one by its height, rounded up, in the
"Change Text Style" step.

Page (CB-8), new `Sources/DesignModel/DesignPageSize.swift`:

```swift
extension DesignWorkspace {
    /// Sets the selected page's size as one step "Change Page Size". Clamps to 1...100,000;
    /// a non-finite value or the current size changes nothing and records nothing. Layers stay put.
    public mutating func setPageSize(width: Double, height: Double)
}
extension DesignPage {
    /// The union of the visible layers' frames; nil on an empty page.
    public var contentBounds: DesignRect? { get }
    /// Whether a layer's frame reaches past the page's edge.
    public func isPastEdge(_ node: DesignNode) -> Bool
}
```

App (macOS): `.setPageSize(width:height:)` in `DesignIntent`;
`DesignPastEdge` (`Sources/DesignApp/DesignPastEdge.swift`) in the canvas
overlay.

## Pseudocode

```
drag (CB-2), every route recomputed from the gesture's start as today:
  draw:    DesignRect(from: start.wholePoints, to: end.wholePoints, square: shift), sides ≥ 1
  move:    delta' = (original.origin + delta).wholePoints − original.origin   # the moved layer's
           translate the subtree by delta'                                     # top-left lands whole;
           several layers: the same with the selection box's top-left           # children keep offsets
  resize:  original.resized(handle, by: delta, keepAspect: shift, fromCenter: option).wholePoints
  nudge and typed values are untouched: a typed 10.5 stays 10.5
  no modifier turns it off: Option is resize-from-centre and duplicate-drag already

text route (CB-3):
  press with Text → .text route keeps the gesture's last point
  endDrag: moved → frame = DesignRect(from: start, to: last).wholePoints, width ≥ 8, height ≥ default,
                   textStyle.fixedWidth = true
           click → today's default box at the start, auto width

text fit (CB-5, CB-6):
  perform(intent) while a text edit is open, for every intent but .textDraft and .cancelText:
    extent = DesignTextFont.measure(draft, style, wrapWidth: fixedWidth ? frame.width : nil)
    model.commitTextEdit(extent: extent)     # then the intent, so a canvas press commits a fitted box
  editor: auto width → the field's width follows the measured draft; fixed → wraps at the frame
  setTextStyle: auto → frame.size × (new.size / old.size); fixed → height × ratio; ceil each

past the edge (CB-9):
  overlay: a Canvas laid out over page.contentBounds (a Canvas clips to its own frame) draws each
    painted layer with isPastEdge, at 40% opacity, clipped to outside the page (even-odd)
  page rows: Width, Height ScrubFields → perform(.setPageSize(w, h)) on Return or onEnd
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: canvas-basics`,
`Slice:`, `Fast-Check: pass`, `Head:`, the snapshot PNGs it changes, and
for a task with mutations its `Mutate:` score line. CB-9 also carries
`feature-done`. Paths drop `Sources/DesignModel/` and `Sources/DesignApp/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| CB-1 | – | CB-a's journey written first, `XCTSkip("waits on CB-2")` | `UITests/DesignJourneyTests+WholePoints.swift` | – | ~120, 1 |
| CB-2 | CB-a's gap issue (closes) | Draws, moves (one or several layers) and resizes land on whole points; walk MJ9; turns CB-1's journey on | `DesignWholePoints.swift`, `DesignDrawing.swift`, `DesignCanvasEditing.swift`; `Tests/DesignModelTests/DesignWholePointsTests.swift`; `Tests/mutations/DesignModel.DesignWholePoints.json`, `Tests/mutations/DesignModel.DesignDrawing.json`, `Tests/mutations/DesignModel.DesignCanvasEditing.json`; `UITests/DesignJourneyTests+WholePoints.swift` | CB-1; design-seams | ~280, 8 |
| CB-3 | – | A Text click-drag makes a fixed-width box as wide as the drag; a click keeps today's auto-width box; the optional `fixedWidth` flag | `Contracts/StyleTypes.swift`, `DesignDrawing.swift`, `DesignCanvasEditing.swift`; `Tests/DesignModelTests/DesignTextBoxDrawTests.swift`; `Tests/mutations/DesignModel.StyleTypes.json`, `Tests/mutations/DesignModel.DesignDrawing.json`, `Tests/mutations/DesignModel.DesignCanvasEditing.json` | CB-2 | ~220, 7 |
| CB-4 | – | CB-b's journey written first, `XCTSkip("waits on CB-6")` | `UITests/DesignJourneyTests+TextBox.swift` | – | ~130, 1 |
| CB-5 | – | `commitTextEdit(extent:)` fits the box in the commit's step; `setTextStyle` refits by the size's ratio | `DesignText.swift`, `Live/LiveStyling.swift`; `Tests/DesignModelTests/DesignTextFitTests.swift`; `Tests/mutations/DesignModel.DesignText.json`, `Tests/mutations/DesignModel.LiveStyling.json` | CB-3; style-rows SR-m | ~240, 5 |
| CB-6 | CB-b's gap issue (closes) | The window commits an open edit with its measured extent before any other intent; the editor grows or wraps; the artwork wraps fixed-width text; turns CB-4's journey on | `DesignWindow.swift`, `DesignTextFont.swift`, `DesignTextEditor.swift`, `DesignTextArtwork.swift`; snapshots `DesignTextFitSnapshots.swift`; `UITests/DesignJourneyTests+TextBox.swift` | CB-4, CB-5; style-rows SR-t; design-window | ~300, 6 |
| CB-7 | – | CB-c's journey written first, `XCTSkip("waits on CB-9")` | `UITests/DesignJourneyTests+Page.swift` | – | ~110, 1 |
| CB-8 | – | `setPageSize`, `contentBounds`, `isPastEdge` | `DesignPageSize.swift`; `Tests/DesignModelTests/DesignPageSizeTests.swift`; `Tests/mutations/DesignModel.DesignPageSize.json` | – | ~180, 3 |
| CB-9 | CB-c's gap issue (closes) | The page's Width and Height rows in DW-a's `DesignInspectorPage` slot and their intent; layers past the edge drawn dimmed in the overlay; turns CB-7's journey on | `DesignIntent.swift`, `DesignWindow.swift`, `DesignCanvas.swift`, `DesignInspectorPage.swift`, `DesignPastEdge.swift`; snapshots `DesignPageSnapshots.swift`; `UITests/DesignJourneyTests+Page.swift` | CB-6, CB-7, CB-8; design-window | ~330, 7; `feature-done` |

CB-1, CB-4, CB-7 and CB-8 start when design-contracts closes. CB-2 and
CB-3 share `DesignDrawing.swift` and `DesignCanvasEditing.swift`, so CB-3
follows CB-2. CB-5 reads CB-3's flag. CB-6 calls CB-5's
`commitTextEdit(extent:)`. CB-9 edits `DesignWindow.swift` after CB-6 (the
`perform` switch can't be split into its own file). Each journey task's
file passes to the task that turns it on. Existing Model tests that feed
fractional points to a drag and expect them back are updated in CB-2's PR,
which lists them. No task edits a shared doc (`docs/c4/model.json`,
`docs/design.md`, the blueprint or `waves.md`): every new file sits in the
`DesignModel`, `DesignApp` and test components already. The top complaints
above move into the blueprint at its next revision, not in a task here.

## Build waves

- Wave 1: CB-1, CB-4, CB-7, CB-8. Independent in this wave: all four.
- Wave 2: CB-2 (design-seams merged). Independent in this wave: CB-2 alone.
- Wave 3: CB-3. Independent in this wave: CB-3 alone.
- Wave 4: CB-5 (style-rows SR-m merged). Independent in this wave: CB-5 alone.
- Wave 5: CB-6 (style-rows SR-t and design-window merged). Independent in this wave: CB-6 alone.
- Wave 6: CB-9 (`feature-done`, final). Independent in this wave: CB-9 alone.

Longest chain: CB-1 → CB-2 → CB-3 → CB-5 → CB-6 → CB-9 (6).
Chain of 6: CB-2 turns on CB-1's journey; CB-3 edits CB-2's two files;
CB-5 fits by CB-3's flag; CB-6 calls CB-5's `commitTextEdit(extent:)`;
CB-9 edits CB-6's `DesignWindow.swift` and carries `feature-done`. CB-a,
the most-used slice, is done after its first three links.

## Acceptance test per task

Checks first (rule 13): each slice's journey merges in its first task,
skipped by name; the Model tests merge with their code. Mutations go in
the plan named in the task's owned files (`scripts/mutate --plan
DesignModel.<File>`).

| id | test | fails when | mutations |
|---|---|---|---|
| CB-1 | The journey compiles and skips by name on the macOS run | the skip names another task | – (journey) |
| CB-2 | `DesignWholePointsTests` on `cards`, `.live`: a rectangle drawn from (100.3, 200.7) to (219.6, 280.2) is (100, 201, 120, 79); Shift from (100.3, 200.7) to (160.2, 230.1) is a 60 × 60 square; A moved by (13.4, -7.8) lands at (113, 92) and a frame at (820.3, 450.6) moved by (40, 0) lands at (860, 451) with its children shifted by the same (39.7, 0.4); A and B moved together keep their gap and the box's top-left lands whole; A's bottom-right handle by (5.5, 0.4) gives W 106, H 80; Option (from the centre) keeps every edge whole; a nudge of a frame at 820.3 gives 821.3 (untouched); a 120-sample move and its last sample alone end equal; walk MJ9; the journey passes on the macOS run | a draw, move or resize ends off a whole point, a square isn't square, children drift from their parent, or a nudge rounds | `DesignDrawing`: the start's rounding dropped. `DesignCanvasEditing`: the move uses the raw delta; the resize rounds the width instead of the far edge, so the right edge leaves the grid. `DesignWholePoints`: `.rounded()` becomes `.rounded(.down)` |
| CB-3 | `DesignTextBoxDrawTests`: a Text click at (200, 300) gives today's 120 × 24 box with `fixedWidth` nil; a Text drag from (200, 300) to (500.4, 310) gives a 300 pt box, height 24, `fixedWidth` true, and opens its edit; a 3 pt drag gives the 8 pt minimum width; a file holding one of each round-trips, and a file without the key opens as auto width with the same bytes | a drag is ignored, a click is fixed width, or an old file changes | `DesignDrawing`: the drag's width replaced by the default; `fixedWidth` not set on a drag. `StyleTypes`: a missing key decodes as fixed width |
| CB-4 | The journey compiles and skips by name | the skip names another task | – (journey) |
| CB-5 | `DesignTextFitTests` on `.live`: a placed text committed with extent 150.2 × 19.1 is 151 × 20 in one "Add Text" step; a fixed-width 300 pt box committed with 280 × 41.5 keeps W 300 and gets H 42; a nil extent keeps the frame; Title (auto, 200 × 32) set from size 16 to 32 is 400 × 64 in one "Change Text Style" step; a fixed-width box keeps W and doubles H; cancel leaves the frame | the box doesn't fit, a fixed width changes, a fit records a second step, or a cancel resizes | `DesignText`: auto width keeps the old width; `.up` rounding becomes `.down`, so the box is a fraction short. `LiveStyling`: the ratio inverted (old / new); the fixed-width check dropped, so a fixed box's width scales |
| CB-6 | `DesignTextFitSnapshots`: `design-text-fit` (an auto box hugging "A longer line of text"; a 150 pt box wrapping two sentences), light and dark; a hosted check that a canvas press during an edit commits a fitted box before the press acts; the journey passes on the macOS run | the box clips its text, a wrapped box widens, or the press commits an unfitted box | – (view code; the Model half is CB-5's) |
| CB-7 | The journey compiles and skips by name | the skip names another task | – (journey) |
| CB-8 | `DesignPageSizeTests` on `cards`: 800 × 1024 is one step "Change Page Size" and `sizeText` reads "800 × 1024 pt"; Desktop keeps its frame; 0 clamps to 1 and 200,000 to 100,000; `.nan` or the current size records nothing; with no file nothing happens; `contentBounds` on `cards` is Desktop's frame, skips Hidden and counts Pair's children; `isPastEdge` is true for a rectangle at (-264, -594) and false for A; after 800 wide, Desktop is past the edge | a size escapes its clamp, a no-op records a step, or a hidden layer counts | the clamp's floor dropped; the unchanged check dropped (a step for no change); `contentBounds` keeps hidden layers |
| CB-9 | `DesignPageSnapshots`: `design-inspector-page` (Width and Height rows), `design-canvas-past-edge` (a rectangle at (-264, -594) drawn dimmed past the page and the 800-wide page cutting Desktop, its outside part dimmed); the journey passes on the macOS run | a row is missing or read-only, a layer past the edge vanishes or draws at full opacity | – (view code) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QD-S1 to QD-S3 drag steps | rounding keeps each step inside its gate on `crowd` | `DesignSelectBudgetTests` (select-several S-8), which runs after CB-a |
| QB-F3 one gesture, one step | a fitted commit, a refit and a page size change are one step each | `DesignTextFitTests`, `DesignPageSizeTests`, the journeys |
| the editor body doesn't run per sample | ≤ 3 `DesignEditor` body runs over a 120-sample drag, rounding included | `DesignWindowDragTests` (design-window D0-8b) |
| no dead controls | the page rows act or say why | J15 (design-window D0-7b) |
| audit | zero new `design` counts; the page rows carry their ids | the macOS run's audit |

## Done check

Per slice (`lead.md` rule 6): its journey green on a Design-scoped run that
contains its last merged PR (CB-a's MJ9 also on the Linux gate), no open
`finding` for the slice, and every mutation in its plans caught; then
`Belt-Slice-Done: <slice> <run url>` on the feature issue. The feature is
done when CB-a, CB-b and CB-c are, with zero new `design` audit counts and
the `Belt-Contact-Sheet:` comment listing the three journeys.
