# Feature packet: tone-controls

**Feature:** one set of tone and sharpen controls for the suite. SuiteImaging
(suite-imaging's target) gets a `Tone/` module: `ToneSettings` (White Balance temperature and tint,
Exposure, Brightness, Contrast, Highlights, Shadows, Whites, Blacks, Vibrance,
Saturation, and Sharpen amount, radius and threshold), the rules that turn
them into one CoreRender `ToneProgram` plus one unsharp pass, Auto from
CoreRaster's `AutoTone`, and the tone commands every app registers. SuiteUI
gets one `ToneRows` view: WHITE BALANCE, TONE (with Auto), PRESENCE and
SHARPEN sections of the suite's slider rows. The rows never edit a document:
they emit `ToneIntent`s, each one a tone command, and the app runs them
through its catalog.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/tone-controls`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 2). Labels `beta` and `p0` when filed.

**Covers:** feature map S1 (the shared half: tone rows and one adjustment
model) and the sharpen control S2's engine already has; real job RJ-X41
(new). Two adopts, each its own packet on its line: `photo/tone-controls`
and `library/tone-controls`, each waiting on this packet's TC-a. Halo stays
an S1 adopter with no packet yet. Brightness (finding #3527) is a TONE
slider here, beside Contrast (re-cut 2026-10-21 by the beta gaps packets:
one tone home, no second slider row).

**Depends on:** suite-imaging's contract slice **IM-a** (TC-1): the
`SuiteImaging` target, which links CoreRaster and CoreRender. The core pin
on dev, `2258b62` (#3549), already has `ToneProgram` (core #624), so TC-1 no
longer waits on photo #3144; Photo's live route is suite-imaging's IM-photo.
creative-core tone-pack #432 and
effects-engine #433 (closed; `AutoTone`, white balance, contrast,
highlights/shadows, vibrance and unsharp are on the pinned core).
gradient-fill (suiteui, planned): TC-1 waits on its GF-a for
`Tests/canonical-concepts.txt`, TC-2 for `SuiteGallery.swift`, TC-9 on its
no fake-document wait (TC-9's fake is its own file, below). editor-kernel (built): `History`,
`CommandSpec`. **creative-core, to file:** "Vibrance as a `ToneProgram` step"
(`AdjustTable` throws `unsupported(.color)` for it today, and
`RenderOp.notOnMetalYet` holds `.color`). Until it lands Vibrance ships
disabled with that reason (`ToneRules.waiting`); this packet doesn't wait on
it. Saturation needs nothing new: it is `hueSaturation(hue: 0, …)`, which the
program already runs.

**Rule 20.** One adjustment model: `ToneSettings`. Library's
`DevelopSettings` sliders (the ten on dev) are promoted into it with the
same JSON keys, so a catalog written today opens unchanged; Photo's
`AdjustmentSettings` gains a `tone` section of it. The settings → program
mapping lives once, in `ToneRules`, so Photo's live route, Library's loupe
and both apps' exports run the same list. TC-1 adds `Tone: ToneSettings
ToneSlider` to `Tests/canonical-concepts.txt`; the adopts' files are
`<X>Tone+Kernel.swift` adapters. **The module lives in SuiteImaging, not the
kernel** (re-cut 2026-10-20 with suite-imaging, from the canonical duplicates
audit). The mapping needs `ToneProgram.Operation` and `AutoTone`, and
SuiteKernel stays Foundation and FlareCore only (`KernelShapeTests`,
unchanged), so the module goes in the shared imaging target, whose
`ImagingProgram` appends these steps after the levels, curve and hue/saturation
ones. TC-1 edits no `Package.swift`: IM-1 makes the target and links it into
the app Models, SuiteUI and the CLI, so TC-1 is back on the fast lane.

**Render path.** No CPU route per slider step. A tone step is one
`ToneProgram` folded into the display write over a resident picture (suite-imaging's
`LiveToneSurface`, which Photo's canvas and Library's loupe both draw through). Sharpen reads
neighbours, so it is one `RenderBackend.unsharpMask` pass (Metal kernel
MB-12) over the resident base, applied before the tone program: a tone step
stays one write over the cached sharpened base, and only a sharpen step pays
the extra pass. Export runs the same steps on the CPU through
`ToneRules.adjustments` and `ToneRules.unsharp`, in the same order.

**C4:** new component part `suite-imaging/imaging-tone.json` (TC-1).
`ToneRows.swift` and its gallery page are new files in `Sources/SuiteUI/`,
covered by `suiteui-sources`.

**Clean-room.** Slider names, ranges and order from the HIG and the apps'
own blueprints; the maths is creative-core's. No task reads another
product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel);
suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| TC-a | SuiteImaging's `Tone/` module declares the settings, rules, intents and command specs as stubs, the gallery's `tone-rows` page is in the index, and the checks are written, disabled. | TC-1, TC-2 | SJ0 | suite-imaging:IM-a (TC-1); gradient-fill:GF-a; autosave-history:AH-a (TC-1, A/C first); placed-images:PL-a (TC-1, A/C first) |
| TC-u | On the gallery page every slider drags, types and resets, Auto and the section resets emit their intents, Vibrance shows its waiting reason, every control identified, within the render budget. | TC-3, TC-4 | TJ1 (`SuiteToneJourneyTests.testToneRowsSetAndReset`) | TC-a |
| TC-m | Settings clamp and round-trip with Library's keys, the rules give the program, the unsharp pass and Auto's values, and every tone command records exactly one undo step (a drag one). | TC-5, TC-6, TC-7 | KJ-tone | TC-a |
| TC-z | The gallery runs its intents through `ToneCommands` on a live target, the fake app takes tone so RJ-X41 runs on the CLI, and the feature is built. | TC-8, TC-9, TC-10 | TJ1, KJ-tone | TC-u, TC-m |

TC-u waits only on TC-a (rule 18); TC-m never waits on TC-u. KJ-tone is the
rules' and commands' Linux walk in `SuiteImagingTests`.

## Journey steps

1. Open the gallery index, click `tone-rows` (TC-2, SJ0): four sections,
   every slider at 0, Vibrance dimmed with its reason as help.
2. Drag Temperature to +30 (TC-3, `testToneRowsSetAndReset`): the page's log
   shows `tone.set` per sample, all under one drag token (one undo step once
   live, TC-8).
3. Type −40 in Highlights and 35 in Shadows; the TONE section shows its Reset.
4. Click Auto: the log shows one `tone.auto`.
5. Set Sharpen Amount to 80: Radius and Threshold enable (they are off at
   Amount 0, help "Sharpen is off at Amount 0.").
6. Click TONE's Reset: its six rows read 0 and the other sections keep their
   values. Every row works by keyboard (arrows step 1, Shift 10, Exposure
   0.01) and VoiceOver reads "Shadows, 35" (TC-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X41 | adds, closes with S1 | C | `Tests/RealJobs/fake/tone-controls/tone-controls.jobs.json`: `tone.set` temperature in 120 steps to 35 under one drag token, `tone.set` shadows 40, `edit.undo` once; the saved document | `input/one.fake-tone` (a neutral picture) |

Trap: the 120 steps land as 120 undo steps, or Vibrance is accepted while it
can't render, or a neutral slider writes a key old files don't have.
Assertion: after the undo, shadows is 0 and temperature is 35 (the drag was
one step); `tone.set` vibrance is unavailable with `ToneRules.waiting`'s
reason; the saved tone has exactly the keys `temperature` and nothing at 0.
Mutations: `SuiteImaging.ToneCommands.json` (the drag token not passed to
`setTone`), `SuiteImaging.ToneSettings.json` (a neutral value encoded).

## Screens and states

`suiteui-tone-rows` (light and dark, all neutral), `-edited` (WB, Tone and
Sharpen set, resets showing), `-vibrance-waiting` (the help shown),
`-sharpen-off` (Radius and Threshold off at Amount 0).

## Contract slice

```swift
// Sources/SuiteImaging/Tone/ToneSettings.swift (TC-1 values and stubs, TC-7 coding and clamping)
public enum ToneSlider: String, CaseIterable, Codable, Sendable {      // raw value: the JSON key and command param
    case temperature, tint, exposure, brightness, contrast, highlights, shadows, whites, blacks, vibrance, saturation
    case sharpenAmount, sharpenRadius, sharpenThreshold
    public var title: String { get }               // "Temperature", "Amount", ...
    public var group: ToneGroup { get }
    public var range: ClosedRange<Double> { get }  // exposure −5...5 stops; amount 0...300 %; radius 0.5...3 px;
                                                   // threshold 0...50 levels; the rest −100...100
    public var neutral: Double { get }             // 0, radius 1
    public var step: Double { get }                // exposure 0.01, radius 0.1, the rest 1
}
public enum ToneGroup: String, CaseIterable, Sendable { case whiteBalance, tone, presence, sharpen
    public var title: String { get }; public var sliders: [ToneSlider] { get } }
/// Edit instructions, never pixels; neutral renders the picture unchanged. Coded by hand: a neutral slider
/// writes no key, a missing key reads neutral, and the ten Develop keys are Library's own.
public struct ToneSettings: Hashable, Codable, Sendable {
    public static let neutral: ToneSettings
    public func value(_ s: ToneSlider) -> Double
    public func setting(_ s: ToneSlider, to v: Double) -> ToneSettings   // clamped to range; NaN keeps the old value
    public func reset(_ g: ToneGroup?) -> ToneSettings                  // nil: every group
    public func isNeutral(_ g: ToneGroup?) -> Bool
}
// Sources/SuiteImaging/Tone/ToneRules.swift (TC-1 stubs returning [] / nil / the input, TC-5 bodies)
public enum ToneRules {
    /// Sliders that can't render yet, with the reason the row and the command show.
    public static let waiting: [ToneSlider: String]   // [.vibrance: "Vibrance waits on creative-core: vibrance on the GPU."]
    public static func program(_ s: ToneSettings) -> [ToneProgram.Operation]   // live: one display write
    public static func adjustments(_ s: ToneSettings) -> [ToneAdjustment]      // export: the same steps on the CPU
    public static func unsharp(_ s: ToneSettings) -> (amount: Double, sigma: Double, threshold: Double)?  // nil at amount 0
    public static func auto(_ a: AutoTone, keeping s: ToneSettings) -> ToneSettings
}
// Sources/SuiteImaging/Tone/ToneCommands.swift (TC-1 specs with real ids, schemas and availability, runs throwing
// `NotBuilt`; TC-6 bodies)
public protocol ToneTarget: Sendable {
    var toneSettings: ToneSettings? { get }   // nil: nothing to adjust (no image, no photo)
    var toneHelp: String? { get }             // why the tone commands can't run now
    /// One undo step named `name`; steps under one `drag` token fold into one.
    mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws
    /// Auto's suggestion from the target's own histogram: one CPU read per click, never per slider step.
    func autoToneSuggestion() throws -> AutoTone
}
public enum ToneIntent: Hashable, Sendable {
    case set(ToneSlider, Double, drag: String?), reset(ToneGroup?), auto
    public var command: (id: String, params: JSONValue) { get }
}
public enum ToneCommands { public static func specs<T: ToneTarget>(_ target: T.Type) -> [CommandSpec<T>] }
// Sources/SuiteUI/ToneRows.swift (TC-2 placeholder, TC-3 view)
/// `hidden` drops sliders an app shows elsewhere (Photo keeps its own Exposure section).
public struct ToneRows: View {
    public init(settings: ToneSettings?, help: String?, hidden: Set<ToneSlider> = [],
                onIntent: @escaping (ToneIntent) -> Void) }
```

Commands (all `edit` but `tone.read`; ids go in each adopter's
`Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `tone.read` | – (query) | – → `{<slider>: value, ...}` (neutral omitted) | `toneHelp` |
| `tone.set` | the slider's title ("Temperature") | `{slider, value, drag?}` | `toneHelp`; a `waiting` slider (its reason); Radius or Threshold at Amount 0 |
| `tone.reset` | Reset <Group> / Reset Tone | `{group?}` | `toneHelp`; already neutral |
| `tone.auto` | Auto Tone | – | `toneHelp` |

## Pseudocode

- **program / adjustments.** In this order, each skipped at neutral:
  `whiteBalance(temperature, tint)`, `exposure(stops)`, Brightness as an
  sRGB `levels` gamma (`gamma = 2^(brightness / 100)`, black and white
  fixed, so +100 lifts the midtones about a stop and never clips), `contrast`,
  `highlightsShadows(highlights, shadows)`, Whites and Blacks as sRGB
  `levels` (Library's rule from `LiveDevelop`: at most a quarter of the range,
  so `levels` never throws), Saturation as `hueSaturation(hue: 0,
  saturation, lightness: 0)`, Vibrance only once `waiting` drops it. The
  two lists come from one private step list, so they can't drift.
- **unsharp.** Amount 0 → nil; else `(amount / 100, sigma: radius,
  threshold: level / 255)`, applied before the tone steps on both paths.
- **auto.** Temperature and tint from the suggestion; Blacks and Whites
  invert the levels rule on the suggestion's `inBlack` and `inWhite` (read in
  sRGB), clamped to ±100; Exposure = log2(0.18^(1/gamma) / 0.18), clamped;
  every other slider kept.
- **commands.** Each spec reads `toneSettings`, applies one rule and calls
  `setTone` once with its title; `drag` passes through, so the target's
  `History` folds a drag into one step (`FakeCanvasDocument.MoveRect`'s
  pattern).
- **The fake.** `FakeToneDocument` (SuiteImaging, TC-9) is a second fake app
  for the CLI, `fake-tone`: one picture's `ToneSettings` and a `History`,
  saved as JSON. It leaves `FakeCanvasDocument` alone, so SuiteKernel never
  sees a tone type and no other packet's fake-document task chains with
  this one.
- **View.** Each section is `InspectorSection` with `onReset` only while not
  neutral; each slider an `InspectorSliderRow` (bar look) identified
  `suite.tone.<slider>`; Auto is an `InspectorAction` row `suite.tone.auto`.
  A drag keeps its value local to the row until it ends and emits one intent
  per sample (the app's live copy shows it, rule 18).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| TC-1 | – | The SuiteImaging `Tone/` module as stubs: `ToneSlider`, `ToneGroup`, `ToneSettings`, `ToneRules`, `ToneTarget`, `ToneIntent`, the four specs with ids, schemas and availability, in SuiteImaging; the concept line; the C4 part; the three suites written, disabled by name | `Sources/SuiteImaging/Tone/ToneSettings.swift`, `Sources/SuiteImaging/Tone/ToneRules.swift`, `Sources/SuiteImaging/Tone/ToneCommands.swift`, `Tests/SuiteImagingTests/ToneSettingsTests.swift`, `Tests/SuiteImagingTests/ToneRulesTests.swift`, `Tests/SuiteImagingTests/ToneCommandsTests.swift`, `Tests/canonical-concepts.txt`, `docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json` | suite-imaging:IM-a, gradient-fill:GF-a | ~360, 8 |
| TC-2 | – | The placeholder `ToneRows`, the gallery's `tone-rows` page in `SuiteGallery.areas` on a local settings value, the journey written and skipped (`XCTSkip("waits on TC-4")`) | `Sources/SuiteUI/ToneRows.swift`, `Sources/SuiteUI/Gallery/GalleryToneRows.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `UITests/SuiteJourneyTests+Tone.swift` | TC-1, gradient-fill:GF-a | ~200, 4 |
| TC-3 | – | The view: four sections, slider rows, Auto, section resets, the waiting and off states with their help, identifiers `suite.tone.*` | `Sources/SuiteUI/ToneRows.swift`, `Tests/SuiteUITests/ToneRowsTests.swift` | TC-2 | ~320, 2 |
| TC-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteToneRowsSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetToneRowsTests.swift`, `UITests/SuiteJourneyTests+Tone.swift` | TC-3 | ~200, 3 |
| TC-5 | – | `ToneRules` bodies: one step list for `program` and `adjustments`, `unsharp`, `auto`, `waiting`; turns on `ToneRulesTests` | `Sources/SuiteImaging/Tone/ToneRules.swift`, `Tests/SuiteImagingTests/ToneRulesTests.swift`, `Tests/mutations/SuiteImaging.ToneRules.json` | TC-1 | ~300, 3 |
| TC-6 | – | `ToneCommands` bodies and `ToneIntent.command`; turns on `ToneCommandsTests` on a test target (one step per run, a drag one step, every why-not) | `Sources/SuiteImaging/Tone/ToneCommands.swift`, `Tests/SuiteImagingTests/ToneCommandsTests.swift`, `Tests/mutations/SuiteImaging.ToneCommands.json` | TC-5 | ~300, 3 |
| TC-7 | – | `ToneSettings` coding and clamping: neutral omitted, Library's ten keys, NaN refused; turns on `ToneSettingsTests` | `Sources/SuiteImaging/Tone/ToneSettings.swift`, `Tests/SuiteImagingTests/ToneSettingsTests.swift`, `Tests/mutations/SuiteImaging.ToneSettings.json` | TC-1 | ~220, 3 |
| TC-8 | – | The gallery page runs each intent through `ToneCommands` on a local target with a `History`, so the log and one undo step show; the live test | `Sources/SuiteUI/Gallery/GalleryToneRows.swift`, `Tests/SuiteUITests/ToneRowsLiveTests.swift` | TC-4, TC-6 | ~120, 2 |
| TC-9 | – | The CLI's `fake-tone` app: `FakeToneDocument` (one picture's `ToneSettings`, omitted when neutral, and a `History`) conforms to `ToneTarget` and lists the specs, registered beside the fake canvas app; RJ-X41's job folder | `Sources/SuiteImaging/Fakes/FakeToneDocument.swift`, `Sources/AfterGlowCLICore/Apps.swift`, `Tests/SuiteImagingTests/FakeToneTests.swift`, `Tests/mutations/SuiteImaging.FakeToneDocument.json`, `Tests/RealJobs/fake/tone-controls/tone-controls.jobs.json`, `Tests/RealJobs/fake/tone-controls/input/one.fake-tone` | TC-6, TC-7 | ~220, 6 |
| TC-10 | – | The C4 part names the commands and the rows; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-imaging/imaging-tone.json`, `docs/blueprints/suiteui/features/tone-controls.wave.json` | TC-8, TC-9 | ~20, 2 |

TC-1 declares every rule and spec, so TC-5, TC-6 and TC-7 each fill one
file. No `suiteui.md` edit: the C4 part and the adopts' blueprint lines carry
it. TC-1 edits no `Package.swift` (IM-1 did).

## Build waves

- Wave 1: TC-1. Independent in this wave: TC-1 alone.
- Wave 2: TC-2, TC-5, TC-7. Independent in this wave: all three.
- Wave 3: TC-3, TC-6. Independent in this wave: both.
- Wave 4: TC-4, TC-9. Independent in this wave: both.
- Wave 5: TC-8. Independent in this wave: TC-8 alone.
- Wave 6: TC-10 (`feature-done`, final). Independent in this wave: TC-10 alone.

Longest chain: TC-1 → TC-2 → TC-3 → TC-4 → TC-8 → TC-10 (6). Chain of 6: the page needs the module's types, the view fills the placeholder, the budget and journey time the view, the live page swaps the log under the journey, and TC-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| TC-1 | the three suites compile, disabled by name; `KernelShapeTests` unchanged and green (the kernel imports no engine); `ImagingBoundaryTests` green; `check-dup-logic` passes with the new concept line | the module imports an app Model or a Darwin framework | – (stubs) |
| TC-2 | SJ0: the index lists `tone-rows`; the page opens | the page is missing | – (UI) |
| TC-3 | `ToneRowsTests`: a drag emits `.set`s under one token; a typed value emits one `.set`; Auto emits `.auto`; a section's Reset emits `.reset(group)` and shows only off neutral; Vibrance is disabled with `waiting`'s reason; Radius is off at Amount 0 | an intent is wrong or doubled, or a disabled row acts | – (UI) |
| TC-4 | `SuiteToneRowsSnapshots`; `RenderBudgetToneRowsTests.sliderDragInThreeBodies`; `testToneRowsSetAndReset` steps 1 to 6 | budget over, or a step fails | – (UI) |
| TC-5 | `ToneRulesTests`: neutral gives an empty program and nil unsharp; temperature 30 gives one `whiteBalance` step; `program` and `adjustments` list the same steps in the same order; Whites 100 gives `inWhite` 0.75; Brightness 100 gives one `levels` step with gamma 2 and black 0, white 1; Amount 80, Radius 1.5, Threshold 4 give (0.8, 1.5, 4/255); `auto` of the identity suggestion keeps the settings; Vibrance is never in the program while waiting | a step, an order or a value is wrong | `SuiteImaging.ToneRules`: neutral check dropped (exposure 0 emits a step) → `.neutralIsEmpty`; whites sign flipped → `.whitesBrighten`; brightness gamma inverted → `.brightnessLifts`; threshold not divided by 255 → `.unsharpThreshold`; vibrance not skipped → `.vibranceWaits` |
| TC-6 | `ToneCommandsTests`: each run records one step named its title; 120 `tone.set` under one drag token undo in one; `tone.set` vibrance is unavailable with its reason; `tone.reset` on neutral is unavailable; `tone.auto` records one "Auto Tone"; `ToneIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteImaging.ToneCommands`: drag not passed to `setTone` → `.dragIsOneStep`; waiting check skipped → `.vibranceUnavailable`; `setTone` called twice in `tone.auto` → `.autoIsOneStep` |
| TC-7 | `ToneSettingsTests`: a neutral value writes no key; Library's catalog JSON fixture (ten keys) decodes to the same values; −250 clamps to −100; NaN keeps the old value; `reset(.tone)` leaves white balance | a key, a clamp or a reset is wrong | `SuiteImaging.ToneSettings`: neutral encoded → `.neutralWritesNoKey`; clamp skipped → `.clampsToRange`; reset clears every group → `.resetKeepsOtherGroups` |
| TC-8 | `ToneRowsLiveTests`: a slider drag on the page leaves one undo step; `testToneRowsSetAndReset` on live | the page stays on the local log | – (UI) |
| TC-9 | `FakeToneTests`: tone survives save and open; neutral tone writes `{}`; the fake canvas app's jobs are untouched; RJ-X41 passes on Linux | tone is lost, or a neutral key is written | `SuiteImaging.FakeToneDocument`: tone encoded when neutral → `.neutralWritesNothing`; `setTone` ignores the drag token → `.dragIsOneStep` |
| TC-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample slider drag on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetToneRowsTests.sliderDragInThreeBodies` |
| render: Auto click | ≤ 2 window bodies | `RenderBudgetToneRowsTests.autoInTwoBodies` |
| No CPU route per step | a tone step on an adopter's live route composites, uploads and reads back nothing (checked in each adopt) | `PhotoToneTests.stepIsOneWrite`, `LibraryLiveToneTests.stepIsOneWrite` |
| One gesture, one step | a slider drag, a typed value, Auto and a section reset are each one undo step | `ToneCommandsTests.dragIsOneStep`, `ToneRowsLiveTests` |
| No dead controls | every row registers in `suite.controls`; Vibrance and the off Sharpen rows say why | `testToneRowsSetAndReset` |
| Keyboard and VoiceOver parity | arrows step, Shift 10, Tab reaches each row; rows read "<Title>, <value>" | `testToneRowsSetAndReset` step 6 |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): TC-m merged-done on the Linux job with
`Mutate:` scores clean; TC-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; TC-z's journey on live and RJ-X41 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-tone-rows-*`.

## Adopted by

`photo/tone-controls` (the Adjust panel's WB, Tone, Presence and Sharpen
sections, on the image and on adjustment layers; RJ-P12, P13, P14) and
`library/tone-controls` (Develop's rows, Auto and Sharpen, and the loupe on
the GPU; RJ-L41). Each waits on TC-a and runs its UI on these stubs.

## Not in this packet

HSL, Black & White, channel mixer, colour balance and LUT rows (the core has
them; S1's later rows), masked or local adjustments, presets of tone
settings (S15), Halo's adoption (S1 lists it; no packet yet), Clarity and
Dehaze (no core op).
