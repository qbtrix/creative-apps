# Feature packet: frame-rates

**Feature:** one list of frame rates for every timed app, 12, 23.976, 24, 25,
29.97, 30, 50, 59.94 and 60, as exact rationals (24000/1001, 30000/1001,
60000/1001), and one timecode rule: `HH:MM:SS:FF` at whole rates and
drop-frame `HH:MM:SS;FF` at 29.97 and 59.94, the broadcast convention. Halo
keeps `CompositionSettings.frameRates = [24, 25, 30, 60]` with an integer
`framesPerSecond` that `HaloFileValidation` checks, and Flare keeps its own
`[12, 24, 25, 30, 60]` in `FlareNewDocument`. A lower third made at 30 drifts
on a 29.97 editor timeline (RJ-H01, RJ-H41). Both lists are deleted and both
apps read the kernel's.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/frame-rates`
**Beta:** captain, 2026-10-21 (beta gaps C5). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C5, evidence in `2026-10-21-gaps-halo.md` B2; feature map row
`suiteui/frame-rates` (new); real job RJ-X74 (new).

**Depends on:** editor-kernel, command-catalog and timeline (built).
**Core need (not filed):** FlareCore's `Scene.fps` and `Timeline.time(ofFrame:fps:)`
take an `Int`. Flare's half needs a creative-core change that stores the rate
as a rational (numerator and denominator, old files decoding the integer) and
writes Lottie's `fr` as the decimal (29.97). Only FR-flare waits on that bump;
Halo's time math is its own and moves onto the kernel here.

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **FR-halo:** `HaloTimelineReadout.swift` and `HaloTimeline.swift` are
  halo/key-editing's and timeline-zoom work's; `CompositionSettings.swift` is
  shared with document-setup DS-halo, which waits on this slice. The Halo
  catalog tail is halo/file-flow HF-m.
- **FR-flare:** `FlareNewDocument.swift` and `FlareInspectorScene.swift` are
  shared with document-setup DS-flare, which waits on this slice; the Flare
  catalog tail is flare/pen-paths FP-m.

**Rule 20.** Time and rates are kernel `Keys` concepts. Halo's
`CompositionSettings.frameRates` and Flare's `NewDocumentSpec.frameRates`
are two copies of one list; FR-8 and FR-10 delete them, FR-z holds it with a test, and each app keeps only
an adapter. No file in `Tests/canonical-baseline.txt` changes (the lists are
lines in files that stay), so this packet is off the baseline chain.

**AI-accessible first.** `time.rates` lists the rates; `time.timecode`
converts a frame to timecode and back for a rate; Halo's
`composition.set-frame-rate` and Flare's `scene.set-frame-rate` take
`{num, den}` or a decimal from the list. Each has its inspector or sheet row.

**C4:** FR-2 extends the kernel part `kernel-keys.json` (`Keys/FrameRate.swift`, `Keys/Timecode.swift`).

Blueprint sections: suite.md 2 (kernel `Keys`); halo.md (compositions);
flare.md (scenes).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FR-a | The kernel declares FrameRate, the common list, Timecode and the two time.* specs as stubs, with their tests written and disabled. | FR-1, FR-2 | MJ-FR | editor-kernel, command-catalog (built, `depends`) |
| FR-m | Rates are exact rationals, a duration in seconds becomes whole frames by one rounding rule, and timecode is drop-frame at 29.97 and 59.94 and round-trips at every rate. | FR-3, FR-4 | MJ-FR | FR-a |
| FR-u | SuiteUI's timeline readout shows timecode at the document's rate and its rate menu offers the one list, reachable from the gallery's timeline page on the fakes. | FR-5, FR-6 | SJ-FR | FR-a; shared files, after timeline-select-all:TSA-a (FR-5) |
| FR-halo | A Halo composition can be 23.976, 29.97, 50 or 59.94 fps, its render times every frame by the exact rate, its readout shows drop-frame timecode, and every old file opens byte for byte. | FR-7, FR-8 | MJ-FR-halo, HJ-FR | FR-a (FR-7); FR-m and FR-u (FR-8); adopt-kernel-easing AE-halo and the Halo catalog chain (cross-line); shared files, after adopt-command-catalog:AC-z (FR-8), adopt-kernel-session:AD-halo (FR-8) |
| FR-flare | A Flare scene can be 23.976, 29.97, 50 or 59.94 fps on the stage, in the inspector and in the Lottie it writes, and every old file opens unchanged. | FR-9, FR-10 | MJ-FR-flare, FJ-FR | FR-a (FR-9); FR-m and FR-u (FR-10); the creative-core rate bump, adopt-kernel-easing AE-flare and the Flare catalog chain (cross-line); shared files, after adopt-command-catalog:AC-z (FR-10) |
| FR-z | A test holds that no app keeps its own rate list, RJ-X74 passes, and the feature is built. | FR-11, FR-12 | MJ-FR, HJ-FR, FJ-FR | FR-halo, FR-flare |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). FR-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

- `MJ-FR`: `FrameRateTests` and `TimecodeTests` on Linux.
- `SJ-FR` (`SuiteJourneyTests.testTimecodeAtNTSCRates`, FR-6): the gallery timeline at 29.97, scrub to frame 1800; the readout reads `00:01:00;02`.
- `MJ-FR-halo`: `HaloFrameRateTests` on Linux.
- `HJ-FR` (`HaloTimelineJourneyTests.testCompositionAt2997`, FR-8): New Composition at 29.97 fps, 10 s; the timeline ends at `00:00:10;00` and the render writes 300 frames.
- `MJ-FR-flare`: `FlareFrameRateTests` on Linux.
- `FJ-FR` (`FlareSceneInspectorJourneys.testSceneAt2398`, FR-10): set the scene to 23.976 in the inspector; playback holds 23.976 within 1% on the fps pill.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X74 | adds, closes with `suiteui/frame-rates` | C | `Tests/RealJobs/halo/ntsc-lower-third/ntsc-lower-third.jobs.json`: a 29.97 fps, 10 s composition with a text layer keyed from x 0 at frame 0 to x 600 at frame 299, by command; render a PNG sequence | none (built by commands) |

Trap: the composition silently runs at 30, so frame 299's timestamp is 9.967 s
instead of 9.977 s and the key lands a frame early on an editor timeline.
Assertion: the sequence has 300 files, the render's frame list times frame 299
at 299 × 1001 / 30000 s within 1 µs, and the readout at frame 1800 of a 2 min
copy is `00:01:00;02`. Mutations: `SuiteKernel.FrameRate` `.ntscExact`,
`HaloModel.HaloFrameRate+Kernel` `.renderUsesExactRate`. Written by FR-7,
disabled (`waits_on: FR-8`).

## Screens and states

- `suite-gallery-timeline-2997-{light,dark}.png` (FR-5): the rate menu open, the drop-frame readout.
- `halo-new-composition-rates-{light,dark}.png` (FR-8): the nine rates.
- `flare-scene-inspector-2398-{light,dark}.png` (FR-10).

## Contract slice

```swift
// Sources/SuiteKernel/Keys/FrameRate.swift (FR-1 stubs, FR-3 bodies).
public struct FrameRate: Hashable, Sendable, Codable, CustomStringConvertible {
    public let numerator: Int, denominator: Int                  // 30000/1001
    public init(numerator: Int, denominator: Int)                // reduced; denominator > 0
    public init(whole: Int)
    public static let common: [FrameRate]                        // 12, 23.976, 24, 25, 29.97, 30, 50, 59.94, 60
    public var isWhole: Bool { get }
    public var isDropFrame: Bool { get }                         // 29.97 and 59.94
    public var nominal: Int { get }                              // 30 for 29.97: timecode's frames per second
    public func seconds(ofFrame frame: Int) -> Double
    public func frame(atSeconds s: Double) -> Int                // nearest frame, ties up
    public func frames(forDuration s: Double) -> Int             // the same rounding: 10 s at 29.97 is 300
    public init(from decoder: Decoder) throws                   // {num, den}, or a legacy Int, or a decimal from `common`
}
// Sources/SuiteKernel/Keys/Timecode.swift (FR-1 stubs, FR-3 bodies).
public enum Timecode {
    public static func string(frame: Int, rate: FrameRate) -> String       // HH:MM:SS:FF, or HH:MM:SS;FF drop-frame
    public static func frame(_ text: String, rate: FrameRate) -> Int?      // nil for a label drop-frame skips
}
// Sources/SuiteKernel/Keys/TimeCommands.swift (FR-1): time.rates, time.timecode {frame | text, rate}.
public enum TimeCommands { public static let specs: [CommandSpec] }
```

## Pseudocode

- **Drop-frame (29.97, nominal 30):** skip labels `;00` and `;01` at the start
  of every minute except each tenth minute. 59.94 skips four (`;00` to `;03`).
  Frame to label: `d = frame / 17982` (frames per 10 min at 29.97), `m = frame
  % 17982`; `frame += 18 * d + 2 * max(0, (m - 2) / 1798)`; then format with
  nominal 30. 59.94 doubles every constant.
- **Rounding:** a duration in seconds becomes `round(s * num / den)` frames,
  half up; the document stores frames, so seconds are only an input.
- **Files:** Halo writes `"framesPerSecond": 30` as today for whole rates and
  adds `"frameRate": {"num": 30000, "den": 1001}` only for a fractional one,
  so every old file re-saves byte for byte. Flare's file follows the bumped
  core's field.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FR-1 | – | **Contract as stubs.** `FrameRate` (numerator, denominator, `common`, legacy `Int` and `Double` decode), `Timecode` (format, parse, drop-frame), `TimeCommands` specs | `Sources/SuiteKernel/Keys/FrameRate.swift`, `Sources/SuiteKernel/Keys/Timecode.swift`, `Sources/SuiteKernel/Keys/TimeCommands.swift` | – | ~170, 3 |
| FR-2 | – | `FrameRateTests` and `TimecodeTests` written, disabled (`waits on FR-3`); the kernel's C4 part names the two files | `Tests/SuiteKernelTests/FrameRateTests.swift`, `Tests/SuiteKernelTests/TimecodeTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json` | FR-1 | ~160, 3 |
| FR-3 | – | `FrameRate` and `Timecode` bodies; `TimeCommands` run; turns on both suites | `Sources/SuiteKernel/Keys/FrameRate.swift`, `Sources/SuiteKernel/Keys/Timecode.swift`, `Sources/SuiteKernel/Keys/TimeCommands.swift`, `Tests/SuiteKernelTests/FrameRateTests.swift`, `Tests/SuiteKernelTests/TimecodeTests.swift`, `Tests/mutations/SuiteKernel.Timecode.json`, `Tests/mutations/SuiteKernel.FrameRate.json` | FR-1, FR-2 | ~300, 7 |
| FR-4 | – | A golden list of 30 frame-to-timecode pairs per rate as a fixture, so a later edit can't drift | `Tests/SuiteKernelTests/Fixtures/timecode-golden.json` | FR-3 | ~60, 1 |
| FR-5 | – | **Reachable first:** the gallery timeline page gets a rate menu over `FrameRate.common`; `TimelineTime` formats through `Timecode` (frames, seconds or timecode, the unit menu it has); `FrameRateMenu` (one SwiftUI `Menu`, each item a `time.rates` entry) for the sheets and inspectors to share; `FrameRateMenuTests` first | `Sources/SuiteUI/FrameRateMenu.swift`, `Sources/SuiteUI/TimelineTime.swift`, `Sources/SuiteUI/Gallery/GalleryTimeline.swift`, `Tests/SuiteUITests/FrameRateMenuTests.swift` | FR-1, FR-2 | ~220, 4 |
| FR-6 | – | The journey and the render budget row | `UITests/SuiteJourneyTests+Timeline.swift`, `Tests/AppSnapshotTests/RenderBudgetSuiteTimelineRateTests.swift` | FR-5 | ~110, 2 |
| FR-7 | – | **Halo, test first.** `HaloFrameRateTests`, disabled: an old `fps: 30` file opens and re-saves byte for byte; a 29.97 composition renders frame 300 at 10.01 s; RJ-X74's job folder, disabled | `Tests/HaloModelTests/HaloFrameRateTests.swift`, `Tests/HaloModelTests/Fixtures/comp-30fps.halo`, `Tests/RealJobs/halo/ntsc-lower-third/ntsc-lower-third.jobs.json` | FR-1, FR-2 | ~150, 3 |
| FR-8 | – | `HaloFrameRate+Kernel.swift`; `CompositionSettings.frameRate: FrameRate` (`framesPerSecond` kept as a computed whole rate for old callers) and its `frameRates` list deleted; `HaloFileValidation` accepts the list and writes `frameRate` only when it isn't whole; render and playback time frames by the rational; the readout and the New Composition sheet's picker read `FrameRateMenu`; `composition.set-frame-rate` in the catalog; turns on the tests | `Sources/HaloModel/HaloFrameRate+Kernel.swift`, `Sources/HaloModel/CompositionSettings.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Sources/HaloModel/HaloPlayback.swift`, `Sources/HaloModel/HaloTimelineReadout.swift`, `Sources/HaloApp/NewCompositionSheet.swift`, `Tests/HaloModelTests/HaloFrameRateTests.swift`, `Tests/mutations/HaloModel.HaloFrameRate+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | FR-7, FR-3, FR-4, FR-5, FR-6 | ~250, 11 |
| FR-9 | – | **Flare, test first.** `FlareFrameRateTests`, disabled: an old `fps: 24` file opens unchanged; a 23.976 scene exports Lottie `fr: 23.976` with `op` frames matching its duration | `Tests/FlareModelTests/FlareFrameRateTests.swift` | FR-1, FR-2 | ~130, 1 |
| FR-10 | – | `FlareFrameRate+Kernel.swift` over the bumped core's rational rate; the scene inspector and New Animation pickers read `FrameRateMenu`; `NewDocumentSpec.fps` becomes a `FrameRate` and its `frameRates` list is deleted; playback ticks by the rational; `scene.set-frame-rate` in the catalog; turns on the tests | `Sources/FlareModel/FlareFrameRate+Kernel.swift`, `Sources/FlareModel/FlareNewDocument.swift`, `Sources/FlareApp/FlareInspectorScene.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Tests/FlareModelTests/FlareFrameRateTests.swift`, `Tests/mutations/FlareModel.FlareFrameRate+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | FR-9, FR-3, FR-4, FR-5, FR-6 | ~260, 9 |
| FR-11 | – | **One list, held.** `FrameRateHomeTests` fails on any frame-rate list literal under `Sources/*Model` or `Sources/*App` (the two app lists left with FR-8 and FR-10) | `Tests/SuiteKernelTests/FrameRateHomeTests.swift` | FR-7, FR-8, FR-9, FR-10 | ~70, 1 |
| FR-12 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/frame-rates.wave.json` | FR-11 | ~10, 1 |

## Build waves

- Wave 1: FR-1. Independent in this wave: FR-1 alone.
- Wave 2: FR-2. Independent in this wave: FR-2 alone.
- Wave 3: FR-3, FR-5, FR-7, FR-9. Independent in this wave: all.
- Wave 4: FR-4, FR-6. Independent in this wave: both.
- Wave 5: FR-8, FR-10. Independent in this wave: both.
- Wave 6: FR-11. Independent in this wave: FR-11 alone.
- Wave 7: FR-12. Independent in this wave: FR-12 alone.

Longest chain: FR-1 → FR-2 → FR-3 → FR-4 → FR-8 → FR-11 → FR-12 (7). Chain of 7: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FR-1 | the kernel builds; `CommandShapeTests` with `time.rates` and `time.timecode` | a spec has no schema | – (stubs) |
| FR-2 | compile, disabled | – | – (tests only) |
| FR-3 | `TimecodeTests`: frame 1800 at 29.97 DF reads `00:01:00;02`, frame 17982 reads `00:10:00;00`, and every frame 0...107892 parses back to itself; 25 fps frame 90000 reads `01:00:00:00`; `FrameRateTests`: 10 s at 29.97 is 300 frames, 1 s at 23.976 is 24, `Int 30` decodes to 30/1, `29.97` decodes to 30000/1001 | drop-frame skips the wrong labels, a round trip fails, or a decimal decodes to a float rate | `SuiteKernel.Timecode`: drop at every tenth minute too → `.tenthMinuteKeeps`; frames per drop 2 at 59.94 (should be 4) → `.dropCount5994`; `SuiteKernel.FrameRate`: floor for round → `.durationRounds`; `29.97` kept as 2997/100 → `.ntscExact` |
| FR-4 | `TimecodeTests.golden` reads it | a label changes | – |
| FR-5 | `FrameRateMenuTests`: nine items in order, 29.97 titled "29.97 fps", the checked item follows the bound rate; the readout at 29.97 reads `00:00:01;00` at frame 30 | a rate is missing or the readout uses a whole-number rate | – (SuiteUI view) |
| FR-6 | `SuiteJourneyTests.testTimecodeAtNTSCRates`; `RenderBudgetSuiteTimelineRateTests.scrubAt2997` | – | – |
| FR-7 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| FR-8 | `HaloFrameRateTests`; `HaloTimelineJourneyTests.testCompositionAt2997` | an old file changes bytes or 29.97 drifts a frame by 10 s | `HaloModel.HaloFrameRate+Kernel`: the rate rounded to 30 for render → `.renderUsesExactRate`; `frameRate` written for whole rates → `.oldFilesUnchanged` |
| FR-9 | compiles, disabled | – | – (tests only) |
| FR-10 | `FlareFrameRateTests`; `FlareSceneInspectorJourneys.testSceneAt2398` | the Lottie says 24 or an old file changes | `FlareModel.FlareFrameRate+Kernel`: fr written as 24 for 23.976 → `.lottieExactFr`; duration frames from floor → `.durationRounds` |
| FR-11 | `FrameRateHomeTests`: no `frameRates` literal under `Sources/*Model` | an app list survives | – (deletion) |
| FR-12 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: gallery timeline scrub at 29.97, 120 samples | ≤ 3 window bodies; readout update p95 ≤ 4 ms | `RenderBudgetSuiteTimelineRateTests.scrubAt2997` |
| render: Halo scrub at 29.97 | ≤ 3 window bodies (Halo's existing scrub row) | `RenderBudgetHaloTests` (existing) |
| behaviour preserved | old Halo and Flare files round-trip byte for byte | `HaloFrameRateTests`, `FlareFrameRateTests` |
| one list | no `frameRates` literal outside SuiteKernel | `FrameRateHomeTests` |
| kernel stays small | Foundation and FlareCore only | `KernelShapeTests` |

## Done check

Per slice (rules 6, 15, 17, 21): FR-a and FR-m green on Linux with clean
`Mutate:` scores; FR-u, FR-halo and FR-flare through the feel gate (`mouse`,
`taste`, `job`) with their `Mac-Finish:` lines; FR-flare only after the core
bump lands; FR-z with RJ-X74 green on Linux. Then `Belt-Contact-Sheet:`.
