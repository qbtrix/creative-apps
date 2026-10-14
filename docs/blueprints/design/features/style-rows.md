# Feature packet: style-rows

**Feature:** the inspector's style rows for one or several layers, and the
canvas drawing them: layer opacity, stroke color and width, corner radius
on several layers, text family, size, weight and alignment; rows reading
"Mixed" that set every selected layer; text that doesn't jump on commit;
the locked hint in the value column; frame names above their frame.
(Blueprint F3.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/style-rows`

**Covers:** #752 (opacity as one layer opacity, Q9; stroke), #267 (stroke,
opacity, text size; Align shipped in #716), #268 (text jumps on commit),
#276 (locked hint in the gutter), #266 (frame names inside the frame),
#288 (part: the rows this feature adds). #752's Auto Layout bullet is not
v1 (blueprint Q2): the lead files one `p3` `gap` issue, "Design: Auto
Layout (direction, gap, padding) with the layout math", and ST-6's PR body
says #752 closes with that bullet moved there.

**Depends on:** the design-window feature issue (the several-layer shell,
the `DesignFrameLabels` slot, `setStyle` and `styleHelp` from design-seams)
and, through it, #778. Not blocked by SuiteUI: `InspectorSliderRow` already
takes `unit`, `decimals`, `mixed` and `onEnd` (`Sources/SuiteUI/InspectorRows.swift`),
and `InspectorColorWellRow`'s `onEnd` is #718 (inspector-controls IC-3,
open); until it lands Design's local end gesture (#749) stays, and the lead
drops it in a follow-up once IC-3 merges. The X, Y, W, H "Mixed" state on
`ScrubField` is design-window's `needs-ui` issue; meanwhile a plain "Mixed"
text. P2 needs #330 and #333 (suite-harness). No creative-core issue.

Blueprint sections: 4 (J10, J11, P2), 5.4 (`StyleEditing`), 6 (rules 1 to 4
and the Properties tab rows), 7.1 (QD-S6, QD-S7), 7.4 (QD-V3, QD-V7), 8.2 (F3).

**Shared files.** `DesignCorners.swift` is #753's and `DesignInspector.swift`
is design-window's until wave 0 merges; this feature takes both in wave 1
and no other wave-1 feature touches them. `DesignInspectorContent.swift`
(Model) gets the row values and helps; no view computes one.

## Journey steps

In `UITests/DesignJourneyTests+Style.swift`, class
`DesignStyleJourneyTests`, on `cards`, live services:

1. **J10** `testInspectorStyleRows`: select A; Corner radius 12 by typing
   ("Undo Change Corner Radius"); drag Opacity to 50% ("Undo Change
   Opacity"); Add Stroke (it starts at `DesignStroke.default`, width 1),
   then → three times: the width reads 4 (the blueprint's "four times"
   assumed a start at 0); one step "Undo Change Stroke" for the whole run; select Hidden
   from Layers: its rows are disabled with "Show Hidden to change it."
   (live-only, as blueprint 4 says).
2. **J11** `testTextFontAndSize`: select Title; size 32; weight Bold;
   alignment Center; each reads back; zoom to 50%; double-click Title,
   type, Return: the committed text's frame equals the editor's within
   1 pt ("Undo Edit Text").
3. **P2** `testScrubLatency` (`+PerfScrub`, class `DesignPerfScrubJourneyTests`)
   on `crowd`: a velocity drag on the Opacity bar and on the X scrub field;
   30 characters typed into the inline editor; ≥ 60 samples per series;
   report-only.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Properties, one layer | – | locked: rows disabled, the hint "Unlock A to change it." in the value column (#276); hidden: "Show Hidden to change it." | none |
| Properties, several | – | a row none of them takes (Corner radius on two ellipses) is disabled with "<name> has no corners to round."; Text rows with no text layer: "<name> isn't a text layer." | none |
| Rows that differ | – | – | – (they read "Mixed"; editing sets each layer) |
| Stroke section | no stroke: an "Add Stroke" `InspectorAction`; with one: color, width, and Remove | – | – |
| Canvas | – | – | – (radius, stroke and opacity draw as stored; frame names above the frame, never clipped) |

## Contract slice

`StyleEditing` (blueprint 5.4) filled by `Sources/DesignModel/Live/LiveStyling.swift`.
Rules beyond the fake's: locked or hidden-in-tree layers refuse with
`.locked(name)` / `.hidden(name)`; `setCornerRadius` skips kinds without
corners in a mixed selection and throws `.noCorners` when none take it;
`setTextStyle` skips non-text layers and throws `.notText` when none are
text; clamps are 5.4's. Model additions in `DesignInspectorContent.swift`:

```swift
/// The inspector's value for `property` over the selection: the shared value, or nil ("Mixed").
public func sharedValue<T: Equatable>(_ read: (DesignNode) -> T) -> T?   // on DesignWorkspace
public var opacityPercentText: String? { get }    // "50%"; nil when mixed
```

And in `DesignText.swift`: `textEditScale` follows the canvas zoom (no
floor at 100%), so the editor draws at the committed size (#268).

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
  value = model.sharedValue(\.opacity)            # nil → mixed: true
  InspectorSliderRow("Opacity", value: v ?? 1, in: 0...100, unit: "%", decimals: 0, mixed: v == nil,
                     onChange: { perform(.setStyle(.opacity($0 / 100))) }, onEnd: { perform(.endEditRun) })
  .disabled(model.styleHelp(.opacity) != nil).help(model.styleHelp(.opacity) ?? "")

artwork (DesignCanvasMarks): rect/frame → RoundedRectangle(cornerRadius:), stroke centered,
  .opacity(node.opacity) on the node's group so a frame fades its contents
frame labels (DesignFrameLabels): for each top-level frame, its name in caption type
  above its top-left in view points (one size at any zoom), in the unclipped overlay
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: style-rows`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. ST-8 also
carries `feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| ST-1 | #752 (Model part), #267 (Model part) | `LiveStyling`: every setter over ids with the refusals and clamps | `Live/LiveStyling.swift`, `DesignCorners.swift` (its help reused for several layers); tests `DesignStyleTests.swift` | – | ~330, 3 |
| ST-2 | #276 (Model part) | Shared values and "Mixed", opacity text, the hint's text per row | `DesignInspectorContent.swift`; tests `DesignInspectorSharedValueTests.swift` | – | ~180, 2 |
| ST-3 | #268 (Model part) | `textEditScale` follows the zoom; the editor's frame equals the committed frame | `DesignText.swift`; tests `DesignTextScaleModelTests.swift` | – | ~120, 2 |
| ST-4 | #752, #267, #276 (view part) | Style rows: Layer (Opacity), Corner radius, Stroke (add, color, width, remove), Text (family `Picker`, size, weight and alignment `ChoiceChips`); the hint in the value column; one `onEnd` per run | `DesignInspector.swift`, `DesignInspectorStyle.swift`; snapshots `DesignInspectorSnapshots.swift`, `DesignStyleSnapshots.swift` | ST-1, ST-2 | ~380, 4 |
| ST-5 | #268 (closes), #266 (closes) | Artwork draws radius, stroke and opacity; the editor at canvas scale; frame names in `DesignFrameLabels` | `DesignCanvasMarks.swift`, `DesignFrameLabels.swift`, `DesignTextEditor.swift`; snapshots `DesignTextSnapshots.swift`, `Tests/AppSnapshotTests/DesignArtworkPathTests.swift`, `Tests/AppSnapshotTests/DesignTextScaleTests.swift` | ST-3 | ~330, 6 |
| ST-6 | #752, #267, #276 (close all three) | J10, J11 | `UITests/DesignJourneyTests+Style.swift` | ST-4, ST-5 | ~250, 1 |
| ST-7 | – | QD-S6, QD-S7 model budgets | tests `DesignStyleBudgetTests.swift` | ST-1, ST-3 | ~120, 1 |
| ST-8 | – | P2 | `UITests/DesignJourneyTests+PerfScrub.swift` | ST-6, ST-7 | ~120, 1; `feature-done` |

ST-1, ST-2 and ST-3 run side by side; ST-4 and ST-5 touch disjoint files
and can too. If ST-4 measures over 400 lines it splits into ST-4a (Layer,
Corner radius, Stroke) and ST-4b (Text), both owning
`DesignInspectorStyle.swift` in that order.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| ST-1 | `DesignStyleTests` on `cards`, `.live`: opacity 0.5 on A and B sets both, one step "Change Opacity" for a run of five values; opacity 2 clamps to 1, -1 to 0; stroke width 4000 clamps to 1000, nil removes it; corner radius on A and E1 sets A and skips E1; on E1 and E2 throws `.noCorners("E2")`; radius 500 on A (100 × 80) clamps to 40; text size 0 clamps to 1, weight 950 to 900; text style on A throws `.notText("A")`; on Locked throws `.locked("Locked")`; on Hidden `.hidden("Hidden")`; setting the current value throws `.unchanged`; the contract law on `.live` | a clamp, skip or refusal differs, or a run is several steps |
| ST-2 | `DesignInspectorSharedValueTests`: A and B share H 80 and differ in X; `opacityPercentText` is "100%" for both, nil after one changes; the locked hint for A locked is "Unlock A to change it." on every row | "Mixed" shows for a shared value, or a shared value hides a difference |
| ST-3 | `DesignTextScaleModelTests`: at zoom 0.25, 0.5, 1, 2 `textEditScale` equals the zoom; the editor's frame for "Hello" at 0.5 equals the committed node frame scaled by 0.5 | the editor scale floors at 1 again |
| ST-4 | `DesignInspectorSnapshots` adds `design-inspector-style-light.png` and `-dark.png` (A with radius 12, opacity 50%, a 4 pt stroke), `design-inspector-locked-light.png` with the hint in the value column (#276; its x equals the X field's leading x, asserted on the hosted view); `DesignStyleSnapshots`: `design-inspector-several-mixed` (A and B: X, Y, W "Mixed", H 80) and `design-inspector-text` (Title: size 32, Bold, Center) | a row is missing, the hint sits in the gutter, or "Mixed" shows wrongly |
| ST-5 | `DesignArtworkPathTests` (QD-V3): a rounded rectangle's and an ellipse's built `Path` hold curve elements, never only lines; `DesignTextScaleTests` (QD-V7): the committed text's frame equals the editor's at 25%, 50%, 100% and 200% zoom within 1 pt; `DesignTextSnapshots` adds `design-text-committed-50`; a frame at the page's top edge keeps its name above it (`design-frame-labels`, #266) | a curve is flattened, the text jumps, or a label is clipped or inside its frame |
| ST-6 | J10 and J11 pass on the macOS run; J10 fails if the stroke run is more than one step or Hidden's rows are enabled; J11 fails if the frames differ by more than 1 pt | a value, undo name or reason differs |
| ST-7 | `DesignStyleBudgetTests.scrubStep` (QD-S7) and `.textDraftStep` (QD-S6) under the Linux debug gates on `crowd` | a step is over its gate |
| ST-8 | P2 records ≥ 60 samples per series and writes `perf-design-scrub.json` (report-only) | fewer than 60 samples |

## Quality tests

| quality row | budget (device / Linux debug gate; screen half) | test |
|---|---|---|
| QD-S6 one keystroke in the inline editor | `setTextDraft` ≤ 0.1 ms / ≤ 1 ms; p95 ≤ 2 frames late | `DesignStyleBudgetTests.textDraftStep`; P2 typing |
| QD-S7 inspector scrub step, coalesced | ≤ 0.5 ms / ≤ 5 ms; p95 ≤ 2 frames late (QB-L2) | `DesignStyleBudgetTests.scrubStep`; P2 |
| QD-V3 curves stay curves | curve elements only | `DesignArtworkPathTests` |
| QD-V7 text doesn't jump | ≤ 1 pt at four zooms | `DesignTextScaleTests` |
| QB-F3 one scrub, one step | a run is one step per row | J10, `DesignStyleTests` |
| QB-F4 keyboard parity | → steps the stroke width | J10 |
| 7.3 item 3 | the value column's leading x equal in every section, the hint in it | `testLayoutAtWidths` (design-window), `DesignInspectorSnapshots` |

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J10, J11 and P2 new; J3 (text and save) and the layout journey
  still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; every new row has its `design.inspector.<name>` id.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey and the audit counts.
