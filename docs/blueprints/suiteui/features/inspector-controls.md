# Feature packet: inspector-controls

**Feature:** every inspector control ends each gesture exactly once and
works from the keyboard: the exact-number field and the color rows report
`onEnd`, a track owns its discrete step (Photo's Gamma), the section's
Reset gets a real hit area beside its header, slider rows and curve handles
read their values in UI tests, and the keyframe button, presets, chips and
both curve editors run on their contracts with goldens.
**Line:** `line:suiteui` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/inspector-controls`

**Covers:** #718 (`onEnd` on the exact field and color rows; closes with
IC-3), #591 and #88 (track-owned step and the log-mapped row; IC-4), #622
and #285 (Reset hit area, Reset over the header button; IC-6), #262
(readable values; IC-7), #343 (S13 `CurveEditor` goldens and probe mark;
IC-8). IC-1, IC-2, IC-5, IC-9 to IC-18 have no issue of their own
(IC-2 says "Part of #718", IC-8 "Part of #262").

**Not covered:** #745 was the same ask as #718 and is already closed (it
closed when #765 merged), so no task names it.

**Depends on:** the suite-harness feature issue (#778): `EditRun` and the
shared types (#773), `.suiteControl` and `suiteReduceMotion` (#775), the
`iconButtonHit` token (#774), the gallery stub `Gallery/GalleryInspector.swift`
(#776), the journey bundle (#333) and goldens (#331, #332). No
creative-core issue.

**This packet supersedes the "Touch only these files" list** of #343 (its
snapshot file is the existing `SuiteCurveEditorSnapshots.swift`, as its own
body already says) and adds contract, gallery and Fake-test files to every
covered issue (review of #765).

**App features it unblocks:** Design's one-undo-step edit runs (the
follow-up of closed #536, today on the #749 workaround: once IC-3 lands,
DesignApp passes `onEnd` and drops its gesture), Photo's Gamma leaving its
detent from the keyboard (follow-up of closed #584, after IC-4), Flare's
inspector F6a #186, F6b #348, F6c #349 and the easing popover F9 #378.

Blueprint sections: 4.2 (SJ11–SJ15, SJ24), 4.3 (SJ16 is tier 1, SJ20),
4.4 (SP1, SP6, SP7, SP9's chips), 5.2 (UC1–UC4, UC15, UC15b), 6.1 (the
house reference), 7.1, 7.3 (QB-S19), 7.4 (QB-S26, QB-S27), 8.3.

**File it receives from the harness:** `InspectorAction.swift` (identifier
applied by SH-5) and the stub `Gallery/GalleryInspector.swift`.

**Building blind.** Every file here is macOS-only. Keep each rule in its
pure half (`ScrubValue`, `NumericInput`, `HexColor`'s parsing, the curve
math), check every SwiftUI and AppKit API with `apple-docs` (say so in the
PR), and copy the shape of the file being edited. `ScrubField.swift` imports
AppKit (the color panel and key handling); keep new AppKit use there.

## Journey steps

SJ11–SJ15 in `UITests/SuiteJourneyTests+Inspector.swift` (IC-13), SJ16,
SJ20, SJ24 and the SP tests in `UITests/SuiteJourneyTests+InspectorCurves.swift`
(IC-14), on the `inspector` and `curves` pages, as section 4.2 and 4.3 write them. The log is the label of
`suite.gallery.log`; `ends n` counts `onEnd` calls.

1. **SJ11** `testBarSliderScrubTypeAndStep`: drag Rotation 40 pt, ⇧-drag 4,
   ⌥-drag 10; type 72 ↵; `abc` ↵ keeps 72; 9 then Escape keeps 72; → →, ⇧→,
   End, Home: 73, 74, 84, max, min; `ends` +1 per drag, commit and key; the
   disabled row's entry has its reason and a drag changes nothing.
2. **SJ12** `testExactFieldAndColorRowEnd`: X field drag 30 then ↑ (+30, +1,
   `ends` +1 each, #718); FILL hex `FF3B30` ↵ logs `color #FF3B30` and one
   end; `zz` ↵ keeps it; a system color panel pick logs one end when the
   panel closes.
3. **SJ13** `testSectionsPickersTogglesAndReset`: TRANSFORM collapses and
   expands; Reset appears only while the page's section differs; its hit
   frame ≥ 20 × 20 pt and overlaps no other control (#622, #285); log
   `reset transform`; Cap picker "Round"; checkbox toggles; the disabled
   action's entry has its reason.
4. **SJ14** `testKeyframeButtonStates`: stopwatch logs `key add`, diamond
   `key remove`; the log states "Not animated", "Animated", "Keyed at this
   frame"; the row's width is the same in all three.
5. **SJ15** `testPresetsAndChips`: "Ease Out" on (`isSelected`), → and Space
   move to the neighbour; the Onion chip on then off; with `-SuitePerfProbe`
   the `chip` series holds a `fade-start`/`fade-end` pair per click, 0.14 s
   apart with the page's Reduce Motion switch off and 0 with it on.
6. **SJ16** `testToneCurveAddMoveRemove`: add, drag up, ↑ nudges 0.01, Tab
   moves focus, drag out removes, Delete removes; `ends` +1 per gesture; the
   two end points cannot be deleted.
7. **SJ20** `testEasingCurveHandles`: drag handle 1, Tab, ↑, ⇧↑: one end
   each, 0.01 and 0.1; the preview dot absent under the page's switch (the
   probe's mark, #343).
8. **SJ24** `testInspectorRowsAlignAtEveryWidth`: `-SuiteGalleryWidth` 200,
   240, 280, 360: rows' edges equal (±0.5 pt), values' trailing edges equal,
   labels and values inside their rows (QB-S19).
9. **SP1** `testBarSliderScrubLatency` (`bar-slider`, `exact-field`), **SP6**
   `testSliderKeyLatency` (`slider-key`), **SP7** `testCurveDragLatency`
   (`curve-drag`), **SP9** `testChipPressLatency` (`press`): report-only,
   ≥ 60 samples each.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Bar slider / exact field | "Mixed" (nil value) shows no marker and a drag starts from the range's middle as today | text that isn't a number keeps the old value; NaN never lands | none |
| Color row | none | `zz` (not a color) keeps the old color | none |
| Section with Reset | an empty section shows its header only; no `onReset`, no Reset | none | none |
| Keyframe button | `.idle` reserves the diamond's slot (no width change) | none | none |
| Presets | no preset matches: none on | none | none |
| Tone curve | two end points only: they cannot be deleted | none | no histogram: no bars drawn |
| Easing curve | none | none | none |

## Contract slice

IC-1 lands six files verbatim from `docs/blueprints/suiteui/contracts/Contracts.swift`:

```swift
// Contracts/ValueScrubbing.swift (UC1): ScrubSpec, TrackStepping, ValueScrubbing  (uses ScrubKey from ScrubValue.swift)
public protocol TrackStepping: Sendable {
    func position(of value: Double) -> Double
    func value(at position: Double) -> Double
    func stepped(_ position: Double, by direction: Double) -> Double   // #591
}
public protocol ValueScrubbing: Sendable {
    func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double
    func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec, track: (any TrackStepping)?) -> Double
    func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double
    func fraction(_ value: Double, spec: ScrubSpec) -> Double
    func text(_ value: Double, spec: ScrubSpec) -> String
    func spoken(_ value: Double, spec: ScrubSpec) -> String
}
// Contracts/HexColorEditing.swift (UC2): RGB8; parse ("#RRGGBB", "RRGGBB", "#RGB"), committed, format ("#RRGGBB")
// Contracts/KeyframeFacing.swift (UC3): KeyPresence, KeyAction, KeyframeFace; face(for:)
// Contracts/PresetNavigating.swift (UC4): neighbor(of:_:count:columns:) -> Int?   (nil at an edge)
// Contracts/CurvePointEditing.swift (UC15): added, moved, removed, nudged, isOutOfWell
// Contracts/EasingHandleNudging.swift (UC15b): nudged(_:dx:dy:coarse:), describe(_:)
```

Public API this feature adds (additive):

```swift
ScrubField(_:value:in:step:unit:decimals:onChange:onEnd:)   // IC-2, onEnd defaults to {}
InspectorColorWellRow(..., onEnd:) / InspectorColorRow(..., onEnd:)   // IC-3
ScrubTrack(..., stepped: (@Sendable (Double, Double) -> Double)? = nil)   // IC-4, #591's shape
```

**Views with no contract**, on purpose (5.2 plus the review of #765):
`InspectorHeader`, `InspectorAction`, and **`InspectorSection`**: SJ13's
rules (collapse, Reset shown only while the host passes `onReset`, the
Reset hit area, no overlap) are the host's choice plus geometry, with no
decision a Model could share. They are proven by SJ13, IC-6's geometry test
and the goldens.

## Pseudocode

```
EditRun in every gesture (ScrubField, color rows, CurveEditor, ToneCurveEditor):
  on change: if run.change() { probe drag start }; onChange(v)
  on drag end / typed commit / key press / nudge: if run.end() { onEnd() }
  a key press is change() then end() in one call; a typed value that doesn't change the value still closes

ScrubField public init (IC-2): forward onEnd to the internal init that already fires it

Color rows (IC-3):
  hex field commit: c = HexColor.committed(text, old); if c != old { onChange(c) }; end the run once
  color panel: changes stream through onChange; the run ends once when the panel closes or the well loses
  the panel's target (apple-docs: NSColorPanel / ColorPicker end-of-interaction; if SwiftUI's ColorPicker
  exposes none, end on the panel's close notification and say so in the PR)

ScrubTrack.stepped (IC-4):
  pressed(key, value, mods, spec, track):
    home/end: range ends
    inc/dec:  delta = ±(shift ? 10 : option ? 0.1 : 1)
              track?.stepped present ? track.value(at: stepped(track.position(value), delta))
                                     : today's ScrubValue.pressed
  VoiceOver's adjustable action and the Slider representation call the same function

Section header (IC-6):
  HStack { header button (title, chevron; contentShape ends before Reset) ; Reset (glyph small,
          frame min iconButtonHit × iconButtonHit, contentShape rect) }   # no ZStack overlap

Readable values (IC-7, IC-8): accessibilityRepresentation { Slider(value, in: range) } on the bar row;
  .accessibilityValue(text) on each curve handle, checked to read in XCUITest via SJ11/SJ20's log AND .value
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: inspector-controls`,
`Fast-Check: pass`, `Head:`. IC-18 carries `feature-done`. Each component
task's snapshot test also calls `assertGolden` through `SnapshotHost` in the four appearances (QB-V5), so the baseline tasks at the end have recorded actuals to commit. Each component task registers its controls with `.suiteControl` (a test that each entry's
reason equals its `.help`), emits its probe series and moves its fades from
`accessibilityReduceMotion` to `suiteReduceMotion` (today in `ChipRow`,
`CurveEditor`, `ScrubField`, `InspectorRows`, `KeyframeButton`,
`InspectorAction`). No task edits `docs/c4/model.json`, `docs/design.md`,
`Tokens.swift` or `project.yml`, and none edits a blueprint or `waves.md`:
this packet edits no shared doc (`packets.md`, rule (a)), so it has no docs
task and IC-18 stays the final task.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| IC-1 | – | Six inspector contracts and their Fakes | `Sources/SuiteUI/Contracts/ValueScrubbing.swift`, `Sources/SuiteUI/Contracts/HexColorEditing.swift`, `Sources/SuiteUI/Contracts/KeyframeFacing.swift`, `Sources/SuiteUI/Contracts/PresetNavigating.swift`, `Sources/SuiteUI/Contracts/CurvePointEditing.swift`, `Sources/SuiteUI/Contracts/EasingHandleNudging.swift`, `Tests/SuiteUITests/InspectorFakeTests.swift` | – |
| IC-2 | #718 (part) | Public `ScrubField` init takes `onEnd`; runs through `EditRun`; `exact-field` series | `Sources/SuiteUI/ScrubField.swift`, `Tests/SuiteUITests/ScrubFieldEndTests.swift` | – |
| IC-3 | #718 (closes) | `onEnd` on `InspectorColorWellRow` and `InspectorColorRow`; `HexColor`'s parsing as a Foundation-only `HexColorEditing` conformance with `#RGB` | `Sources/SuiteUI/ColorWell.swift`, `Tests/SuiteUITests/HexColorTests.swift` | IC-1 |
| IC-4 | #591, #88 (closes both) | `ScrubTrack.stepped` decides arrow, VoiceOver and Slider steps; `ScrubTrack` conforms to `TrackStepping`; the log-mapped row snapshot | `Sources/SuiteUI/ScrubValue.swift`, `Sources/SuiteUI/ScrubField.swift`, `Tests/SuiteUITests/ScrubValueTests.swift`, `Tests/AppSnapshotTests/SuiteSliderSnapshots.swift` | IC-1, IC-2 |
| IC-5 | – | `SuiteValueScrubbing` over `ScrubValue` and `NumericInput`; the 60-row reference table (QB-S27) | `Sources/SuiteUI/ScrubValue.swift`, `Sources/SuiteUI/NumericInput.swift`, `Tests/SuiteUITests/ScrubReferenceTests.swift`, `Tests/SuiteUITests/NumericInputTests.swift` | IC-4 |
| IC-6 | #622, #285 (closes both) | Reset beside the header, hit ≥ `iconButtonHit`, no overlap; `InspectorRows` and `InspectorAction` on `suiteReduceMotion`; goldens of the section header and of the inspector title and info card | `Sources/SuiteUI/InspectorRows.swift`, `Sources/SuiteUI/InspectorAction.swift`, `Tests/SuiteUITests/InspectorSectionTests.swift`, `Tests/AppSnapshotTests/SuiteInspectorSnapshots.swift`, `Tests/AppSnapshotTests/SuiteHeaderSnapshots.swift` | – |
| IC-7 | #262 (closes) | Bar rows read their value (`accessibilityRepresentation` with a `Slider`); `bar-slider` and `slider-key` series | `Sources/SuiteUI/ScrubField.swift`, `Sources/SuiteUI/StudioScrubRow.swift`, `Tests/SuiteUITests/SliderBarTests.swift` | IC-4 |
| IC-8 | #343 (closes), #262 (part) | `CurveEditor`: `EasingHandleNudging` conformance, `EditRun`, readable handle values, the preview dot's Reduce Motion probe mark, `curve-drag` | `Sources/SuiteUI/CurveEditor.swift`, `Tests/SuiteUITests/CurveEditorTests.swift`, `Tests/AppSnapshotTests/SuiteCurveEditorSnapshots.swift` | IC-1 |
| IC-9 | – | `ToneCurveEditor` on `CurvePointEditing`, `EditRun`, `curve-drag` | `Sources/SuiteUI/ToneCurveEditor.swift`, `Tests/SuiteUITests/ToneCurveEditorTests.swift`, `Tests/AppSnapshotTests/SuiteToneCurveSnapshots.swift` | IC-1 |
| IC-10 | – | `KeyframeButton` on `KeyframeFacing`, `suiteReduceMotion`, registration | `Sources/SuiteUI/KeyframeButton.swift`, `Tests/SuiteUITests/KeyframeButtonTests.swift`, `Tests/AppSnapshotTests/SuiteKeyframeSnapshots.swift` | IC-1 |
| IC-11 | – | `PresetGrid` on `PresetNavigating` (`GridArrow` in place of `KeyEquivalent`); chips' fades and `press` series | `Sources/SuiteUI/PresetGrid.swift`, `Sources/SuiteUI/ChipRow.swift`, `Sources/SuiteUI/ChoiceChips.swift`, `Tests/SuiteUITests/PresetGridTests.swift`, `Tests/AppSnapshotTests/SuitePresetsSnapshots.swift` | IC-1 |
| IC-12 | – | The `inspector` and `curves` gallery pages, their log, `-SuiteGalleryWidth`, the Reduce Motion switch, the Fakes path | `Sources/SuiteUI/Gallery/GalleryInspector.swift` | IC-3, IC-5, IC-6, IC-8, IC-9, IC-10, IC-11 |
| IC-13 | – | SJ11 to SJ15 | `UITests/SuiteJourneyTests+Inspector.swift` | IC-7, IC-12 |
| IC-14 | – | SJ16, SJ20, SJ24, SP1, SP6, SP7, `testChipPressLatency` | `UITests/SuiteJourneyTests+InspectorCurves.swift` | IC-7, IC-12 |
| IC-15 | – | Baselines: bar slider, exact field, color row in four appearances | `Tests/AppSnapshotTests/Golden/inspector/` (12 PNGs) | IC-3, IC-4, IC-6, IC-7 (a CI run with their actuals) |
| IC-16 | – | Baselines: section header and Reset, keyframe button, presets in four appearances | `Tests/AppSnapshotTests/Golden/inspector/` (12 PNGs) | IC-6, IC-10, IC-11 (a CI run with their actuals) |
| IC-17 | – | Baselines: chips, easing curve, tone curve in four appearances | `Tests/AppSnapshotTests/Golden/inspector/` (12 PNGs) | IC-8, IC-9, IC-11 (a CI run with their actuals) |
| IC-18 | – | Baselines: inspector title and info card in four appearances; `feature-done` | `Tests/AppSnapshotTests/Golden/inspector/` (8 PNGs) | IC-6, IC-13, IC-14, IC-15, IC-16, IC-17 |

Sizes: IC-1 ~380 lines; IC-2 ~120; IC-3 ~220; IC-4 ~250; IC-5 ~330 (the
table is data); IC-6 ~200; IC-7 ~180; IC-8 ~260; IC-9 ~220; IC-10 ~150;
IC-11 ~250; IC-12 ~380; IC-13 ~350; IC-14 ~330. If IC-12 passes 400, the
`curves` page moves to IC-12b in the same file, chained (the longest
chain then grows by one).

Links: `ScrubField.swift` is edited by IC-2, IC-4 and IC-7 (IC-4 changes
the key and VoiceOver paths IC-2 rewires through `EditRun`, and IC-7's
`Slider` steps through IC-4's `stepped`), and `ScrubValue.swift` by IC-4
and IC-5 (`SuiteValueScrubbing.pressed` calls IC-4's track-aware
`ScrubValue.pressed`): those run as chains IC-2 → IC-4 → IC-5 and IC-2 →
IC-4 → IC-7. IC-3, IC-4 and IC-8 to IC-11 conform to IC-1's contracts.
IC-8 owns its own files and does not wait for IC-7. IC-8 says "see #262";
IC-7, in the later wave, closes it. IC-12's
pages draw every component and swap each conformance for IC-1's Fakes.
IC-13 and IC-14 drive IC-12's pages and read IC-7's slider value and
series; each owns its own journey file (`project.yml` compiles
`UITests/SuiteJourneyTests*.swift`), so they build side by side. Each
baseline task commits the actuals of the snapshot tests of the tasks it
names; the PNGs of IC-15 to IC-18 do not overlap. IC-18 waits for the other
baselines and both journey tasks, because its `feature-done` run is the done
check. `InspectorHeader.swift` and `SuiteProInspectorSnapshots.swift` are this
feature's in wave 2; no task changes them (IC-6 records the title and info
card goldens from `SuiteHeaderSnapshots.swift`).

## Build waves

- Wave 1: IC-1, IC-2, IC-6, IC-9, IC-10, IC-11. Independent in this wave: all six.
- Wave 2: IC-3, IC-4, IC-8, IC-16. Independent in this wave: all four.
- Wave 3: IC-5, IC-7, IC-17. Independent in this wave: all three.
- Wave 4: IC-12, IC-15. Independent in this wave: both.
- Wave 5: IC-13, IC-14. Independent in this wave: both.
- Wave 6: IC-18 (`feature-done`, final; no shared doc to edit).

Longest chain: IC-2 → IC-4 → IC-5 → IC-12 → IC-13 → IC-18 (6).
Chain of 6: IC-4 edits the key and VoiceOver paths of `ScrubField.swift`
that IC-2 rewires; `SuiteValueScrubbing` (IC-5) calls IC-4's track-aware
`ScrubValue.pressed` in `ScrubValue.swift`; `GalleryInspector.swift` (IC-12)
swaps `SuiteValueScrubbing` for its Fake; SJ11–SJ15 (IC-13) drive IC-12's
pages; IC-18's `feature-done` run must show those journeys green.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| IC-1 | `InspectorFakeTests`: each Fake gives `main.swift`'s literal results with its deliberate gap (no snapping, no `#RGB`, presets wrap, curve points unsorted and never refused, easing x unclamped) | a Fake loses its gap |
| IC-2 | `ScrubFieldEndTests`: the public init with `onEnd` builds; driving the field's internal rule through a drag of 3 changes, a typed commit and two key presses gives exactly 4 ends; a press at the range end that changes nothing still ends once | an end fires twice in one drag, or not at all for a key press |
| IC-3 | `HexColorTests`: `#ff3b30`, `FF3B30` and `#F30` parse; `zz`, `#12345` and `` do not and `committed` keeps the old color; `format` is upper case with `#`; the color rows' public inits take `onEnd`; a hex commit ends once | a shorthand fails, a bad text lands, or an end is missing |
| IC-4 | `ScrubValueTests`: with a track whose `stepped` jumps out of a ±4-step detent, one increment from 1 leaves 1 and one decrement back gives exactly 1; `stepped: nil` gives today's `ScrubValue.pressed` result for every key and modifier; `SuiteSliderSnapshots` adds a log-mapped row whose value 1 over 0.1…10 draws its thumb at the middle and its field reads `1` (#88) | the track is ignored, or a nil track changes any result |
| IC-5 | `ScrubReferenceTests` (QB-S27): 60 rows written from `docs/design.md`'s number rules, not from the code: (start, points, modifiers, step, range) → value and (value, key, modifiers) → value, through `SuiteValueScrubbing`; `NumericInputTests` keep passing | any row differs |
| IC-6 | `InspectorSectionTests`: laid out in an `NSHostingView` at 240 pt, the Reset button's frame is at least 20 × 20 pt and does not intersect the header button's frame; without `onReset` there is no Reset; `SuiteInspectorSnapshots` show the header with Reset | the hit is under 20 pt or the frames overlap |
| IC-7 | `SliderBarTests`: the bar row's accessibility representation is a slider whose value equals `ScrubValue`'s text; increment and decrement go through the same press rule as the keys | the value reads empty or steps differ from the keys |
| IC-8 | `CurveEditorTests`: handle x clamps to 0…1, ↑ and ⇧↑ nudge by 0.01 and 0.1, `describe` gives the handle's text; one end per drag and per nudge; under `suiteReduceMotion` the dot is not drawn and the probe records a `preview-stopped` mark; `SuiteCurveEditorSnapshots` extended (no new file) | a clamp, a nudge or the mark is wrong |
| IC-9 | `ToneCurveEditorTests`: a click adds a point in order, a drag past the well's margin removes it, the end points can't be removed, ↑ nudges 0.01, one end per gesture | points unsort, an end point goes, or ends double |
| IC-10 | `KeyframeButtonTests`: `face(for:)` gives the stopwatch, diamond, action and spoken text for each presence; the button's width is equal in all three; its entry's reason equals its `.help` | a face differs or the width moves |
| IC-11 | `PresetGridTests`: in 7 presets of 3 columns, → from 2 is nil (edge), ↓ from 4 is nil, ↓ from 1 is 4; chips record fade pairs with the switch off and on | the grid wraps, or a fade pair is missing |
| IC-12 | SJ0 opens `inspector` and `curves` with `violations()` empty; both build with `-SuiteGalleryFakes` | a control is unregistered or reasonless |
| IC-13 | SJ11–SJ15 pass on CI | any 4.2 assert |
| IC-14 | SJ16, SJ20, SJ24 pass; SP1, SP6, SP7 and the chip press test each hold ≥ 60 samples | an assert fails or a series is short |
| IC-15–18 | The next CI run's goldens pass against the committed baselines; no `inspector` known issue left | a baseline is missing or differs |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S1 bar slider and exact field drag | p95 ≤ 2 frames late (placeholder 3), report-only | SP1 |
| QB-S2 arrow key to value drawn | p95 ≤ 1 (placeholder 2) | SP6, series `slider-key` |
| QB-S6 curve handle and tone point drag | p95 ≤ 2 (placeholder 3) | SP7, series `curve-drag` |
| QB-S8 chip and preset press | p95 ≤ 1 (placeholder 2) | `testChipPressLatency`, series `press` |
| QB-S9 chip fades | 0.14 s ± 1 refresh; 0 under Reduce Motion | SJ15's mark pairs |
| QB-S19 rows align | ±0.5 pt at 200, 240, 280, 360 | SJ24 |
| QB-S26 curves stay curves | cubic elements, never a polyline over 8 segments | `CurveEditorTests`, `ToneCurveEditorTests` |
| QB-S27 number rules equal a reference | 60 rows exact | `ScrubReferenceTests` |
| QB-F3 one gesture, one end | `ends` +1 per gesture | SJ11, SJ12, SJ16, SJ20 and the unit tests above |
| QB-F4 keyboard parity | every pointer change also from keys | SJ11, SJ12, SJ14–SJ16 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by IC-18 is green:
  SJ11–SJ16, SJ20, SJ24, the perf series present, SJ0 and SJ25 on the
  inspector pages.
- **Audit zero new:** `suiteui` stays 0; the five apps' counts do not rise
  (every app's inspector draws these rows, section 7.2); Photo's `overlap`
  should fall by #285's one, which the `Audit lower` job records.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  listing `suiteui-inspector-*`, `suiteui-curves-*` and the app inspector
  shots that changed (Photo's tone and export sheet, Flare's easing).
