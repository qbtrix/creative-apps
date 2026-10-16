# Feature packet: style-rows

**Feature:** the inspector's style rows for one or several layers, and the
canvas drawing them: text family, size, weight and alignment, drawn on the
canvas and in the inline editor; layer opacity, stroke color and width,
corner radius on several layers; rows reading "Mixed" that set every
selected layer; text that doesn't jump on commit; the locked hint in the
value column; top-level frame names above their frames. (Blueprint F3.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/style-rows`

**Covers:** #752 (opacity as one layer opacity, Q9; stroke), #267 (stroke,
opacity, text size; Align shipped in #716), #268 (text jumps on commit),
#276 (locked hint in the gutter), #266 (frame names inside the frame),
#288 (part: the rows this feature adds), #532 (corner radius: the Model
half is design-contracts D0-0, from PR #753; ST-6 closes #532 with the row
and J10's radius step). #752's Auto Layout bullet is not
v1 (blueprint Q2): the lead files one `p3` `gap` issue, "Design: Auto
Layout (direction, gap, padding) with the layout math", and ST-6's PR body
says #752 closes with that bullet moved there.

**Depends on:** the design-contracts feature issue (`setStyle`,
`styleHelp`, the `LiveStyling` stub, #753's corner radius, the fixtures):
SR-m's ST-1, ST-2 and ST-3 and SR-t's check ST-6b start when it closes.
The view tasks wait on design-window's contract slice DW-a: SR-t's on the
three slots it fills (`DesignInspectorText.swift`, `DesignTextArtwork.swift`,
`DesignFrameLabels.swift`), SR-a's on the several-layer shell in
`DesignInspector.swift`, SR-b's on `DesignCanvasMarks.swift`; each passes to
this feature when DW-a merges. ST-4 also waits on DW-b (the live box its
scrubs preview through). Text size waits on nothing else: not on SR-a, not
on DW-b. Not blocked by SuiteUI: `InspectorSliderRow` already
takes `unit`, `decimals`, `mixed` and `onEnd` (`Sources/SuiteUI/InspectorRows.swift`),
`ScrubField` takes a public `onEnd` on `dev`, and
`InspectorColorWellRow`'s `onEnd` is #718 (inspector-controls IC-3,
open); until it lands Design's local end gesture (#749) stays, and the lead
drops it in a follow-up once IC-3 merges. The X, Y, W, H "Mixed" state on
`ScrubField` is design-window's `needs-ui` issue; meanwhile a plain "Mixed"
text. P2 needs #330 and #333 (suite-harness). No creative-core issue.

Blueprint sections: 4 (J10, J11, P2), 5.4 (`StyleEditing`), 6 (rules 1 to 4
and the Properties tab rows), 7.1 (QD-S6, QD-S7), 7.4 (QD-V3, QD-V7), 8.2 (F3).

**Shared files.** `DesignCorners.swift` is design-contracts' (D0-0): ST-1
reads its help and doesn't edit it. `DesignInspector.swift`,
`DesignCanvasMarks.swift`, `DesignFrameLabels.swift`,
`DesignTextArtwork.swift` and `DesignInspectorText.swift` are
design-window's until DW-a merges, then this feature's; no other wave-1
feature touches them. `DesignInspectorContent.swift` (Model) gets the row
values and helps; no view computes one. SR-t shares no file with SR-a or
SR-b, so neither waits on the other. canvas-basics CB-b takes
`LiveStyling.swift`, `DesignText.swift`, `DesignTextEditor.swift`,
`DesignTextArtwork.swift` and `DesignTextFont.swift` after SR-m and SR-t.

## Slices

A slice is the unit of done: its tasks have merged and its journeys pass on
the Design-scoped macOS run (SR-m: on the Linux gate).

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SR-m | On the live services every style setter refuses, skips and clamps as blueprint 5.4 says, the inspector's shared values read "Mixed" only when layers differ, and the inline editor's scale follows the zoom. | ST-1, ST-2, ST-3 | MJ8 | design-contracts |
| SR-t | Text family, size, weight and alignment rows set a text layer, the canvas and the inline editor draw its text in that style (size 32 draws twice as tall as 16), committed text doesn't jump at any zoom, and top-level frame names sit above their frames. | ST-6b, ST-4b, ST-5t, ST-5f | J11 | SR-m (ST-4b, ST-5t); design-window DW-a (ST-4b, ST-5t, ST-5f) |
| SR-a | Layer opacity, corner radius and stroke rows set one or several layers in one step per scrub, read "Mixed" when the layers differ, show the locked hint in the value column, and keep each scrub step inside its budget. | ST-4, ST-6, ST-7 | J10 | SR-m (ST-4, ST-7); design-window DW-a (ST-4, ST-6) and DW-b (ST-4) |
| SR-b | The canvas draws radius, stroke and opacity as stored, and scrubs and typing keep up on 2,000 layers. | ST-5, ST-8 | P2 | design-window DW-a (ST-5, ST-8); SR-a, SR-t (ST-8) |

SR-m is the contract slice (rule 12): Model only, Linux, the setters,
shared values and edit scale both view slices call. SR-t is the front of
the queue: the captain's "text does not have font size adjustments"
(review 2026-10-16, R3 and R4) needs only SR-m and DW-a.

A scrub on a row (the Opacity bar, the X, Y, W and H fields, the stroke
width, the text Size field) previews through design-window's live box once
DW-b has merged and commits once at `onEnd`, so the editor body doesn't run
per sample; ST-4 checks it. Until DW-b, ST-4b's Size field commits on
Return and on `onEnd` only, never per sample.

## Journey steps

1. **J10** `testInspectorStyleRows` (ST-6), in `UITests/DesignJourneyTests+Style.swift`,
   class `DesignStyleJourneyTests`, on `cards`, live services: select A; Corner radius 12 by typing
   ("Undo Change Corner Radius"); drag Opacity to 50% ("Undo Change
   Opacity"); Add Stroke (it starts at `DesignStroke.default`, width 1),
   then → three times: the width reads 4 (the blueprint's "four times"
   assumed a start at 0); one step "Undo Change Stroke" for the whole run; select Hidden
   from Layers: its rows are disabled with "Show Hidden to change it."
   (live-only, as blueprint 4 says).
2. **J11** `testTextFontAndSize` (ST-6b writes it, ST-5t turns it on), in
   `UITests/DesignJourneyTests+Text.swift`, class `DesignTextJourneyTests`,
   on `cards`, live services, every step with the mouse on visible controls:
   click Title's row in Layers; click the Size field, type 32, Return:
   it reads 32 ("Undo Change Text Style"); click Bold in the weight chips;
   click Center in the alignment chips; pick a family from the Family
   menu; each reads back after selecting A and Title again; click A's row:
   the Text rows are disabled with "A isn't a text layer."; click the top
   bar's zoom-out until the status line reads 50%; double-click Title on
   the canvas, type, press Return: the committed text's frame equals the
   editor's within 1 pt ("Undo Edit Text"). The canvas half (size 32 draws
   about twice as tall as 16) is `DesignTextDrawTests` (ST-5t), a hosted
   render, since the artwork is one accessibility-hidden `Canvas`; J11
   attaches the canvas shot at size 32 for the contact sheet.
3. **P2** `testScrubLatency` (`+PerfScrub`, class `DesignPerfScrubJourneyTests`)
   on `crowd`: a velocity drag on the Opacity bar and on the X scrub field;
   30 characters typed into the inline editor; ≥ 60 samples per series;
   report-only.
4. **MJ8** `walkStyleRows` (ST-1), a Linux Model walk in `DesignStyleTests`
   on `cards`, `.live`: opacity, radius, stroke and text style set through
   `setStyle`, each one step, then undone in order.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Properties, one layer | – | locked: rows disabled, the hint "Unlock A to change it." in the value column (#276); hidden: "Show Hidden to change it." | none |
| Properties, several | – | a row none of them takes (Corner radius on two ellipses) is disabled with "<name> has no corners to round."; Text rows with no text layer: "<name> isn't a text layer." | none |
| Properties, text layer | – | – | – (the Text section after Fill: Family, Size, Weight, Alignment; `design-inspector-text`) |
| Rows that differ | – | – | – (they read "Mixed"; editing sets each layer) |
| Stroke section | no stroke: an "Add Stroke" `InspectorAction`; with one: color, width, and Remove | – | – |
| Canvas | – | – | – (text in its family, size, weight and alignment; radius, stroke and opacity as stored; a top-level frame's name above it, even past the page's top edge, never inside or clipped; nested frames show no name) |

## Contract slice

`StyleEditing` (blueprint 5.4) filled by `Sources/DesignModel/Live/LiveStyling.swift`.
Rules beyond the fake's: locked or hidden-in-tree layers refuse with
`.locked(name)` / `.hidden(name)`; `setCornerRadius` skips kinds without
corners in a mixed selection and throws `.noCorners(name)` ("E2 has no
corners to round.") when none take it; with one layer selected the row
keeps #753's `setCornerRadius` and its per-kind help ("An ellipse has no
corners to round."), as the "nothing that works today goes off" rule says;
`setTextStyle` skips non-text layers and throws `.notText` when none are
text; clamps are 5.4's. Model additions in `DesignInspectorContent.swift`:

```swift
/// The inspector's value for `property` over the selection: the shared value, or nil ("Mixed").
public func sharedValue<T: Equatable>(_ read: (DesignNode) -> T) -> T?   // on DesignWorkspace
public var opacityPercentText: String? { get }    // "50%"; nil when mixed
```

In `DesignText.swift`: `textEditScale` follows the canvas zoom (no
floor at 100%), so the editor draws at the committed size (#268).

In `DesignFrameLabel.swift` (ST-5f): names are drawn in the canvas overlay,
which isn't clipped, so the rule loses its artboard-top case:

```swift
/// The frames that show a name: visible top-level frames, back to front.
public static func labelled(on page: DesignPage) -> [DesignNode]
/// A name `labelHeight` tall sits with its bottom edge `gap` above the frame's top, at any zoom.
public static func bottom(frameTop: Double, gap: Double) -> Double
```

App (SR-t, macOS): `DesignTextFont` (`Sources/DesignApp/DesignTextFont.swift`)
maps a `DesignTextStyle` to the font and alignment both the artwork
(`DesignTextArtwork`) and the inline editor use, so they can't drift apart.

## Pseudocode

```
LiveStyling.setX(value, ids, page):
  nodes = find(ids); guard nonEmpty else .nothingSelected
  first locked-in-tree → .locked(name); first hidden-in-tree → .hidden(name)
  takers = nodes.filter(kind takes property)      # radius: rect, frame; text: text
  guard nonEmpty else .noCorners / .notText (name of the last selected)
  each taker: set clamped value; unchanged overall → .unchanged
  DesignEdit("Change <Property>", key: runKey(base, ids))

view row (DesignInspectorStyle):
  value = (live.workspace ?? model).sharedValue(\.opacity)   # nil → mixed: true
  InspectorSliderRow("Opacity", value: (v ?? 1) * 100, in: 0...100, unit: "%", decimals: 0, mixed: v == nil,
                     onChange: { live.preview(.opacity($0 / 100)) },   # the canvas and this row redraw
                     onEnd: { live.end(into: model) })                  # one setStyle, one step
  .disabled(model.styleHelp(.opacity) != nil).help(model.styleHelp(.opacity) ?? "")

text rows (DesignInspectorText, ST-4b):
  style = model.sharedValue(\.textStyle)              # nil → each row reads "Mixed"
  Family Picker, Size field (1...1000, Return / onEnd commits), Weight and Alignment ChoiceChips
  each → perform(.setStyle(.textStyle(changed)))      # one step "Change Text Style"
  .disabled(model.styleHelp(.textStyle) != nil).help(...)

text artwork (DesignTextArtwork, ST-5t): font = DesignTextFont(node.textStyle)
  draw node.text in the node's frame, scaled with the canvas, aligned as stored
inline editor (DesignTextEditor, ST-5t): the same DesignTextFont at size × textEditScale(zoom)

artwork (DesignCanvasMarks, ST-5): rect/frame → RoundedRectangle(cornerRadius:), stroke centered,
  .opacity(node.opacity) on the node's group so a frame fades its contents
frame labels (DesignFrameLabels, ST-5f): for DesignFrameLabel.labelled(page), the name in caption
  type with its bottom at bottom(frameTop: top × zoom, gap) in view points, in the unclipped overlay
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: style-rows`,
`Slice:`, `Fast-Check: pass`, `Head:`, the snapshot PNGs it changes, and
for a task with mutations its `Mutate:` score line. ST-8 also carries
`feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| ST-1 | #752 (Model part), #267 (Model part) | `LiveStyling`: every setter over ids with the refusals and clamps (reads design-contracts' `DesignCorners` help); walk MJ8 | `Live/LiveStyling.swift`; tests `DesignStyleTests.swift`; `Tests/mutations/DesignModel.LiveStyling.json` | – | ~340, 3 |
| ST-2 | #276 (Model part) | Shared values and "Mixed", opacity text, the hint's text per row | `DesignInspectorContent.swift`; tests `DesignInspectorSharedValueTests.swift`; `Tests/mutations/DesignModel.DesignInspectorContent.json` | – | ~190, 3 |
| ST-3 | #268 (Model part) | `textEditScale` follows the zoom; the editor's frame equals the committed frame | `DesignText.swift`; tests `DesignTextScaleModelTests.swift`, `DesignCompactSelectionTests.swift` (existing: its `textEditScale(zoom: 0.43) == 1` assert becomes 0.43); `Tests/mutations/DesignModel.DesignText.json` | – | ~140, 4 |
| ST-6b | – | J11 written from the packet, `XCTSkip("waits on ST-5t")` | `UITests/DesignJourneyTests+Text.swift` | – | ~130, 1 |
| ST-4b | #752, #267 (view part) | Text rows in DW-a's Text section slot: Family `Picker`, Size field, Weight and Alignment `ChoiceChips`; their ids | `DesignInspectorText.swift`; snapshots `DesignTextStyleSnapshots.swift` | ST-1, ST-2; design-window DW-a | ~200, 2 |
| ST-5t | #268 (closes) | The artwork draws text in its family, size, weight and alignment; the editor draws at canvas scale in the same font; turns J11 on | `DesignTextFont.swift`, `DesignTextArtwork.swift`, `DesignTextEditor.swift`; snapshots `DesignTextSnapshots.swift`; `Tests/AppSnapshotTests/DesignTextScaleTests.swift`, `Tests/AppSnapshotTests/DesignTextDrawTests.swift`; `UITests/DesignJourneyTests+Text.swift` | ST-3, ST-4b, ST-6b; design-window DW-a | ~360, 7 |
| ST-5f | #266 (closes) | Top-level frame names above their frames in the unclipped overlay, at one size at any zoom; nested frames unnamed | `DesignFrameLabels.swift`, `Sources/DesignModel/DesignFrameLabel.swift`; tests `DesignFrameLabelTests.swift` (existing); `Tests/mutations/DesignModel.DesignFrameLabel.json`; snapshots `DesignFrameLabelSnapshots.swift` | design-window DW-a | ~200, 5 |
| ST-4 | #752, #267, #276 (view part) | Style rows: Layer (Opacity), Corner radius, Stroke (add, color, width, remove); the hint in the value column; each scrub previews through the live box and commits once at `onEnd`; the rows' ids | `DesignInspector.swift`, `DesignInspectorStyle.swift`; snapshots `DesignInspectorSnapshots.swift`, `DesignStyleSnapshots.swift`; `Tests/AppSnapshotTests/DesignStyleScrubTests.swift` | ST-1, ST-2; design-window DW-a, DW-b | ~380, 5 |
| ST-5 | – | Artwork draws radius, stroke and opacity | `DesignCanvasMarks.swift`; `Tests/AppSnapshotTests/DesignArtworkPathTests.swift` | design-window DW-a | ~200, 2 |
| ST-6 | #752, #267, #276, #532 (close all four) | J10 | `UITests/DesignJourneyTests+Style.swift` | ST-4 | ~150, 1 |
| ST-7 | – | QD-S6, QD-S7 model budgets | tests `DesignStyleBudgetTests.swift` | ST-1 | ~120, 1 |
| ST-8 | – | P2 | `UITests/DesignJourneyTests+PerfScrub.swift` | ST-5, ST-5f, ST-5t, ST-6, ST-7 | ~120, 1; `feature-done` |

ST-1, ST-2, ST-3 and ST-6b run side by side once design-contracts closes.
The text rows live in their own file, `DesignInspectorText.swift`, a slot
DW-a's D0-5c puts after Fill, so ST-4b never shares
`DesignInspectorStyle.swift` with ST-4 and doesn't wait on it. Text drawing
lives in `DesignTextArtwork.swift`, a slot DW-a's D0-5b fills with
today's drawing, so ST-5t never shares `DesignCanvasMarks.swift` with ST-5.
J10 and J11 are in two journey files.

ST-4b needs ST-1 because its snapshots set text style on `.live`, where
`LiveStyling` is design-contracts' stub (D0-2b) that throws `.notBuilt`
until ST-1 fills it, and ST-2 for `sharedValue`; ST-4 likewise. ST-5t needs
ST-3's `textEditScale` for the editor and `DesignTextScaleTests`, ST-4b's
rows for the J11 it turns on, and ST-6b's journey file. ST-7's `scrubStep`
times `LiveStyling` (ST-1); `textDraftStep` times `setTextDraft`, which
exists today, so ST-7 does not wait for ST-3. ST-5f's Model change and its
overlay land together, so no PNG regresses in between: the first overlay
run moves Desktop's name above the page in today's canvas PNGs, which
ST-5f's PR lists. No task edits a shared doc (`docs/c4/model.json`,
`docs/design.md`, the blueprint or `waves.md`): the new files sit in the
`DesignModel`, `DesignApp` and test components already.

## Build waves

- Wave 1: ST-1, ST-2, ST-3, ST-6b. Independent in this wave: all four.
- Wave 2: ST-4b, ST-5f, ST-5, ST-7 (DW-a merged), and ST-4 once DW-b has merged. Independent in this wave: all five.
- Wave 3: ST-5t, ST-6. Independent in this wave: both.
- Wave 4: ST-8 (`feature-done`, final). Independent in this wave: ST-8 alone.

Longest chain: ST-1 → ST-4b → ST-5t → ST-8 (4), and ST-1 → ST-4 → ST-6 → ST-8 (4).
Chain of 4: ST-4b's live snapshots need `LiveStyling` (ST-1); ST-5t turns on
J11, which drives ST-4b's rows; ST-8 carries `feature-done`, whose run must
hold J10 and J11, and P2 drags ST-4's Opacity bar. A text size field that
works needs three tasks of this packet (ST-1, ST-4b, ST-5t) after DW-a.

## Acceptance test per task

Checks first (rule 13): SR-m's Model tests merge with their code; ST-6b
writes J11 before SR-t's view tasks, skipped until ST-5t. Mutations go in
the plan named in the task's owned files (`scripts/mutate --plan
DesignModel.<File>`).

| id | test | fails when | mutations |
|---|---|---|---|
| ST-1 | `DesignStyleTests` on `cards`, `.live`: opacity 0.5 on A and B sets both, one step "Change Opacity" for a run of five values; opacity 2 clamps to 1, -1 to 0; stroke width 4000 clamps to 1000, nil removes it; corner radius on A and E1 sets A and skips E1; on E1 and E2 throws `.noCorners("E2")`; radius 500 on A (100 × 80) clamps to 40; text size 0 clamps to 1, weight 950 to 900; text style on Title sets it and on Title and A sets Title only; text style on A throws `.notText("A")`; on Locked throws `.locked("Locked")`; on Hidden `.hidden("Hidden")`; setting the current value throws `.unchanged`; the contract law on `.live`; walk MJ8 | a clamp, skip or refusal differs, or a run is several steps | the size clamp's floor dropped (`max(1, …)` gone); the text-kind filter dropped, so A takes a text style; the locked check skipped; the run key built per call, so a run is five steps. The stub entries of today's plan are retired with the stub |
| ST-2 | `DesignInspectorSharedValueTests`: A and B share H 80 and differ in X; `opacityPercentText` is "100%" for both, nil after one changes; the locked hint for A locked is "Unlock A to change it." on every row | "Mixed" shows for a shared value, or a shared value hides a difference | `sharedValue` returns the first layer's value without comparing; `opacityPercentText` truncates instead of rounding (49.6% reads "49%") |
| ST-3 | `DesignTextScaleModelTests`: at zoom 0.25, 0.5, 1, 2 `textEditScale` equals the zoom; 0, -1, `.nan` and `.infinity` give 1; the editor's frame for "Hello" at 0.5 equals the committed node frame scaled by 0.5 | the editor scale floors at 1 again | the floor back (`max(zoom, 1)`); `.infinity` passes the finite check |
| ST-6b | J11 compiles and skips by name on the macOS run | the skip names another task, or the journey doesn't build | – (journey) |
| ST-4b | `DesignTextStyleSnapshots`: `design-inspector-text` (Title on `.live`: size 32, Bold, Center), light and dark; the Text rows are disabled with "A isn't a text layer." on A; with Title and A selected the rows set Title only; the hosted view's Size field commits once on Return | a Text row is missing or enabled on a rectangle, or Return records two steps | – (view code; J11 is its check) |
| ST-5t | `DesignTextDrawTests` (hosted render of Title on `.fake`): the ink is at least 1.8 times as tall at size 32 as at 16; Bold's ink is wider than Regular's; Center puts the ink's middle within 1 pt of the box's; `DesignTextScaleTests` (QD-V7): the committed text's frame equals the editor's at 25%, 50%, 100% and 200% zoom within 1 pt, and the editor's font size is the style's size × the zoom; `DesignTextSnapshots` adds `design-text-committed-50` and `design-text-sizes`; J11 passes on the macOS run | the artwork ignores a style field, the text jumps, or the editor and artwork use different fonts | – (view code; the Model half is ST-3's) |
| ST-5f | `DesignFrameLabelTests` (Linux): `labelled` on `cards` gives [Desktop]; a frame nested in Desktop gives no name; a hidden top-level frame gives none; `bottom(frameTop: 0, gap: 4)` is -4 (above the page's top edge). `DesignFrameLabelSnapshots`: `design-frame-labels` (a frame at the page's top edge keeps its name above it, #266, and a nested frame shows none) | a label is clipped, sits inside its frame, or a nested or hidden frame is named | `labelled` keeps nested frames (the top-level filter dropped); `labelled` keeps hidden frames; `bottom` adds the gap instead of taking it away. Today's `place` entries are retired with `place` |
| ST-4 | `DesignInspectorSnapshots` adds `design-inspector-style-light.png` and `-dark.png` (A with radius 12, opacity 50%, a 4 pt stroke), `design-inspector-locked-light.png` with the hint in the value column (#276; its x equals the X field's leading x, asserted on the hosted view); `DesignStyleSnapshots`: `design-inspector-several-mixed` (A and B: X, Y, W "Mixed", H 80). `DesignStyleScrubTests` (design-window D0-8b's `dragSamples`): a 120-sample drag on the Opacity bar and on the X field of A on `crowd` each run `DesignEditor`'s body 3 times or fewer and record one step | a row is missing, the hint sits in the gutter, "Mixed" shows wrongly, or the editor body runs per scrub sample | – (view code) |
| ST-5 | `DesignArtworkPathTests` (QD-V3): a rounded rectangle's and an ellipse's built `Path` hold curve elements, never only lines; a frame at 50% opacity fades its children; a 4 pt stroke draws centered on the edge | a curve is flattened, a child ignores its frame's opacity, or the stroke is offset | – (view code) |
| ST-6 | J10 passes on the macOS run; it fails if the stroke run is more than one step or Hidden's rows are enabled | a value, undo name or reason differs | – (journey) |
| ST-7 | `DesignStyleBudgetTests.scrubStep` (QD-S7) and `.textDraftStep` (QD-S6) under the Linux debug gates on `crowd` | a step is over its gate | – (tests only) |
| ST-8 | P2 records ≥ 60 samples per series and writes `perf-design-scrub.json` (report-only) | fewer than 60 samples | – (journey) |

## Quality tests

| quality row | budget (device / Linux debug gate; screen half) | test |
|---|---|---|
| QD-S6 one keystroke in the inline editor | `setTextDraft` ≤ 0.1 ms / ≤ 1 ms; p95 ≤ 2 frames late | `DesignStyleBudgetTests.textDraftStep`; P2 typing |
| QD-S7 inspector scrub step, coalesced | ≤ 0.5 ms / ≤ 5 ms; p95 ≤ 2 frames late (QB-L2) | `DesignStyleBudgetTests.scrubStep`; P2 |
| QD-V3 curves stay curves | curve elements only | `DesignArtworkPathTests` |
| QD-V7 text doesn't jump | ≤ 1 pt at four zooms | `DesignTextScaleTests` |
| text drawn as styled | size 32 ≥ 1.8 × size 16's ink height; artwork and editor share one font | `DesignTextDrawTests` (ST-5t) |
| QB-F3 one scrub, one step | a run is one step per row | J10, J11, `DesignStyleTests` |
| QB-F4 keyboard parity | → steps the stroke width | J10 |
| the editor body doesn't run per sample | ≤ 3 `DesignEditor` body runs over a 120-sample scrub on the Opacity bar or the X field | `DesignStyleScrubTests` (ST-4) |
| 7.3 item 3 | the value column's leading x equal in every section, the hint in it | `testLayoutAtWidths` (design-window), `DesignInspectorSnapshots` |

## Done check

Per slice (`lead.md` rule 6): SR-m is done when MJ8 and its Model tests
pass on the Linux gate with every mutation caught; SR-t when J11 passes on
the Design-scoped run after ST-5t; SR-a when J10 does after ST-6 and ST-7's
budgets are green; SR-b when P2 does after ST-8. The feature is done when
all four are:

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J10, J11 and P2 new; J3 (text and save) and the layout journey
  still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; every new row has its `design.inspector.<name>` id.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and the audit counts.

## Review notes folded in

- **Design app UX review (2026-10-16, R3 and R4).** Text size sat at the
  tail of an 8-link chain: ST-4b followed ST-4 in `DesignInspectorStyle.swift`,
  so it waited on SR-a and DW-b, and ST-5 never drew `textStyle`. The re-cut
  adds SR-m (the Model contract, so neither view slice waits on the other),
  splits SR-t out of SR-b with the text rows in their own file, the artwork
  and editor drawing from `textStyle`, the text-jump fix and frame names
  above their frames, and adds J11's canvas check (`DesignTextDrawTests`).
  J11 moved to its own journey file so SR-t shares nothing with SR-a.
