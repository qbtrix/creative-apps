# Feature packet: eyedropper

**Feature:** one eyedropper for the suite. Every SuiteUI colour row gets an
eyedropper button that picks a colour anywhere on screen through the system's
`NSColorSampler` (rung 4: the platform already samples the screen, including
the canvas), and an app's eyedropper tool shows SuiteUI's `SampleLoupe` at the
pointer. SuiteKernel gets a `Sample/` module: `SampleSize` (moved from
PhotoModel), `SampleRules.mean`, the one N×N average every sampler uses over
any pixel reader, and `color.sample`, a query command that reads the colour a
person sees at a document point, so an agent can pick a colour and set it with
the fill or stroke commands.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/eyedropper`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"). Labels `beta` and `p1` when filed.

**Covers:** feature map S13 (eyedropper; the re-cut of Photo's PV-9); real
job RJ-X33 (new). The adopts are `photo/eyedropper` and `design/eyedropper`,
each waiting on this packet's EY-a.

**Depends on:** gradient-fill's **GF-a** before EY-1 (the kernel's
`FillColor` is declared there) and its **GF-z** through transform-tools'
**TT-z** before EY-8 (the fake's `FakeRect.fill` and `FakeCanvasDocument.swift`).
canvas-host (built) for the gallery page. No creative-core issue: Photo's
pixels come from its own composite.

**Rule 20.** One mean: Photo's `ColorSampling` contract keeps its signature
but its live body calls `SampleRules.mean` with a reader over its
`PixelBuffer` (the Photo adopt), and `SampleSize` moves here (Photo keeps a
typealias). The kernel never imports CoreRaster: the reader is a closure.
The screen pick needs no model at all: `NSColorSampler` returns the colour and
the row reports it like any other pick (one gesture, one step).

**Render path.** None: the loupe is a canvas mark; sampling reads what the app
already drew.

**C4:** new component part `suite-kernel/kernel-sample.json` (EY-1).
`Eyedropper.swift` is a new file under `Sources/SuiteUI/`, covered by
`suiteui-sources`.

**Clean-room.** The pick follows the HIG's colour-picker guidance and Apple's
`NSColorSampler` documentation; no task reads another product's code.

Blueprint sections: suiteui.md 2.2 (components, the colour row), 2.4 (canvas
marks), 7.1 (budgets); suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EY-a | The kernel's sample size, mean, target and color.sample spec are declared as stubs, the colour rows take the eyedropper parameter, the gallery's eyedropper page is in the index, and the checks are written, disabled. | EY-1, EY-2 | SJ0 | gradient-fill:GF-a (EY-1, FillColor); canvas-host (built) |
| EY-u | On the gallery page every colour row's eyedropper picks a colour from the screen as one gesture, the loupe follows the pointer with the colour under it, and the size chips change the square, within the render budget. | EY-3, EY-4 | EJ1 | EY-a |
| EY-m | The mean averages the visible pixels of the square weighted by alpha, and color.sample reads the colour at a document point or null. | EY-5, EY-6 | KJ-sample | EY-a |
| EY-z | The gallery samples through color.sample on a live target, the fake app samples its topmost rect so RJ-X33 runs on the CLI, and the feature is built. | EY-7, EY-8, EY-9 | EJ1, KJ-sample | EY-u, EY-m; transform-tools:TT-z (EY-8) |

EY-u waits only on EY-a (rule 18); EY-m never waits on EY-u. KJ-sample is the
mean's and the command's Linux walk in `SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `eyedropper` (EY-2, SJ0): a colour row
   (blue) with its eyedropper button, and a small canvas with a red, a green
   and a half-transparent black swatch.
2. Click the eyedropper button (EY-3, `SuiteEyedropperJourneyTests.testEyedropperPicksFromCanvas`):
   the system sampler opens; click the red swatch: the row reads `#FF0000`;
   the page's log shows one change and one end (one undo step once live).
3. Press Escape in the sampler: nothing changes and nothing is logged.
4. Turn on the page's eyedropper tool and move over the green swatch: the
   loupe follows the pointer showing green and `#00FF00`; a click sets the
   row; the log shows `color.sample {"x":…, "y":…, "size": 1}`.
5. Pick 5 × 5 in the size chips and click the swatch edge: the row shows the
   mean of the covered pixels. The button reads "Pick a colour from the
   screen" to VoiceOver (EY-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X33 | adds, closes with S13 | C | `Tests/RealJobs/fake/sample-color/sample-color.jobs.json`: `color.sample` inside a red rect, inside a rect with a two-stop linear gradient at its middle, and on empty space | `input/two-fills.fake` (a red rect over a blue-to-white one) |

Trap: the sample reads the selected rect instead of the one under the point,
or the rect beneath an overlapping one. Assertion: the point in the overlap
reads red (the topmost), the gradient's middle reads the 50% mix
(`#8080FF` within 1 per channel), and empty space reads `null`. Mutations:
`SuiteKernel.FakeCanvasDocument.json` (the bottom rect wins → `.sampleTopmost`)
and `SuiteKernel.SampleRules.json` (transparent pixels counted →
`.meanSkipsTransparent`).

## Screens and states

`suiteui-eyedropper-row` (the colour row with its button, light and dark),
`-loupe` (the ring over green, its hex), `-loupe-empty` (outside the image:
the ring hollow, "No colour here"), `-sizes` (the size chips).

## Contract slice

```swift
// Sources/SuiteKernel/Sample/SampleRules.swift (EY-1 stubs returning nil, EY-5 bodies)
public enum SampleSize: Int, Hashable, Sendable, CaseIterable, Codable {
    case point = 1, threeByThree = 3, fiveByFive = 5
    public var title: String { get }                          // "Point", "3 × 3", "5 × 5"
}
/// One pixel as a reader hands it to the sampler: 8-bit sRGB, straight alpha.
public struct SampleRGBA: Hashable, Sendable { public var r, g, b, a: UInt8 }
public enum SampleRules {
    /// The mean of the size × size square centred on (x, y) over the pixels `read` returns (nil outside the
    /// image) that aren't fully transparent, each weighted by its alpha; nil when there are none.
    public static func mean(x: Int, y: Int, size: SampleSize, read: (Int, Int) -> SampleRGBA?) -> FillColor?
    public static func hex(_ color: FillColor) -> String     // "#RRGGBB", rounded per channel
}
// Sources/SuiteKernel/Sample/SampleCommands.swift (EY-1 spec with id, schema and availability, run throwing
// `SampleRules.notBuilt`; EY-6 body)
public protocol SampleTarget: Sendable {
    var sampleHelp: String? { get }                          // why nothing can be sampled now; nil when it can
    /// The colour a person sees at `point` (document space): the composite for pixel apps, the topmost
    /// visible painted layer for vector apps; nil on empty canvas or outside the document.
    func sampledColor(at point: Point, size: SampleSize) -> FillColor?
}
public enum SampleCommands {
    public static func specs<T: SampleTarget>(_ target: T.Type) -> [CommandSpec<T>]   // color.sample
}
// Sources/SuiteUI/Eyedropper.swift (EY-2 placeholders, EY-3 views)
/// The eyedropper button of a colour row: the system screen sampler; Escape picks nothing.
public struct EyedropperButton: View {
    public init(help: String? = nil, onPick: @escaping @MainActor (HexColor) -> Void)
}
/// An eyedropper tool's ring at the pointer: the colour under it and its hex, hollow when there is none.
public struct SampleLoupe: View { public init(color: HexColor?, at point: CGPoint) }
/// The sample-size chips an eyedropper tool's options show.
public struct SampleSizeChips: View { public init(size: SampleSize, onChange: @escaping @MainActor (SampleSize) -> Void) }
// Sources/SuiteUI/ColorWell.swift (EY-2 adds the parameter, the button hidden; EY-3 shows it)
// InspectorColorRow and InspectorColorWellRow gain `sampleable: Bool = true`: the row shows an
// EyedropperButton whose pick goes through the row's onChange then onEnd, one gesture.
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | title | kind | params | unavailable when |
|---|---|---|---|---|
| `color.sample` | – | query | `{x, y, size?}` → `{color: {hex, r, g, b, a} \| null}` | `sampleHelp` |

Applying a sampled colour is the commands that already set it (`fill.type` /
`fill.gradient`, `stroke.color`, an app's paint colour), so a pick through the
UI and a pick by an agent record the same one step.

## Pseudocode

- **mean.** For each (x + dx, y + dy) with dx, dy in `-(n/2)...(n/2)`: skip a
  nil or alpha-0 pixel; sum `c · a` per channel and `a`; the result is
  `sum / sumA` per channel and `sumA / count` for alpha, all over 255. Nil
  when every pixel was skipped.
- **command.** Read `sampledColor(at:size:)`; write `hex` and the 0...255
  channels, or `null`.
- **Button.** `NSColorSampler().show { color in … }` on the main actor;
  convert through sRGB (`usingColorSpace(.sRGB)`), round to `HexColor`; nil
  (Escape) calls nothing. A second click while open does nothing.
- **Loupe.** A 44 pt ring of the colour with a 1 pt contrast outline
  (`SuiteColor.overlayPaper` over `.overlayInk`), the hex in a pill under it,
  offset so it never covers the pixel being read; fixed size on screen.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EY-1 | – | The contract as stubs: `SampleSize`, `SampleRGBA`, `SampleRules`, `SampleTarget`, the `color.sample` spec with its schema and availability; the new C4 part; the two suites written, disabled by name | `Sources/SuiteKernel/Sample/SampleRules.swift`, `Sources/SuiteKernel/Sample/SampleCommands.swift`, `Tests/SuiteKernelTests/SampleRulesTests.swift`, `Tests/SuiteKernelTests/SampleCommandsTests.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-sample.json` | – | ~220, 5 |
| EY-2 | – | The placeholder `EyedropperButton`, `SampleLoupe` and `SampleSizeChips`; the colour rows' `sampleable:` parameter, the button hidden; the gallery's `eyedropper` page in `GalleryCanvasHost.pages`; the journey written and skipped (`XCTSkip("waits on EY-4")`) | `Sources/SuiteUI/Eyedropper.swift`, `Sources/SuiteUI/ColorWell.swift`, `Sources/SuiteUI/Gallery/GalleryEyedropper.swift`, `Sources/SuiteUI/Gallery/GalleryCanvasHost.swift`, `UITests/SuiteJourneyTests+Eyedropper.swift` | EY-1 | ~200, 5 |
| EY-3 | – | The views: the `NSColorSampler` button on every colour row (one change and one end per pick), the loupe, the size chips; identifiers `suite.color.eyedropper`, `suite.sample.*` | `Sources/SuiteUI/Eyedropper.swift`, `Sources/SuiteUI/ColorWell.swift`, `Tests/SuiteUITests/EyedropperTests.swift` | EY-2 | ~260, 3 |
| EY-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteEyedropperSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetEyedropperTests.swift`, `UITests/SuiteJourneyTests+Eyedropper.swift` | EY-3 | ~200, 3 |
| EY-5 | – | `SampleRules` bodies; turns on `SampleRulesTests` | `Sources/SuiteKernel/Sample/SampleRules.swift`, `Tests/SuiteKernelTests/SampleRulesTests.swift`, `Tests/mutations/SuiteKernel.SampleRules.json` | EY-1 | ~160, 3 |
| EY-6 | – | The `color.sample` body; turns on `SampleCommandsTests` on a test target | `Sources/SuiteKernel/Sample/SampleCommands.swift`, `Tests/SuiteKernelTests/SampleCommandsTests.swift`, `Tests/mutations/SuiteKernel.SampleCommands.json` | EY-5 | ~140, 3 |
| EY-7 | – | The gallery page's tool samples its canvas through `color.sample` on a local target and sets the row as one step; the live test | `Sources/SuiteUI/Gallery/GalleryEyedropper.swift`, `Tests/SuiteUITests/EyedropperLiveTests.swift` | EY-4, EY-6 | ~140, 2 |
| EY-8 | – | The fake app samples: `FakeCanvasDocument` conforms to `SampleTarget` (the topmost rect under the point, its fill at the point) and lists the spec; RJ-X33's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeSampleTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/sample-color/sample-color.jobs.json`, `Tests/RealJobs/fake/sample-color/input/two-fills.fake` | EY-6 | ~160, 5 |
| EY-9 | – | The C4 part names the command, the button and the loupe; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-sample.json`, `docs/blueprints/suiteui/features/eyedropper.wave.json` | EY-7, EY-8 | ~20, 2 |

EY-1 declares the mean and the spec so EY-5 and EY-6 each fill one file.

## Build waves

- Wave 1: EY-1. Independent in this wave: EY-1 alone.
- Wave 2: EY-2, EY-5. Independent in this wave: both.
- Wave 3: EY-3, EY-6. Independent in this wave: both.
- Wave 4: EY-4, EY-8. Independent in this wave: both.
- Wave 5: EY-7. Independent in this wave: EY-7 alone.
- Wave 6: EY-9 (`feature-done`, final). Independent in this wave: EY-9 alone.

Longest chain: EY-1 → EY-2 → EY-3 → EY-4 → EY-7 → EY-9 (6). Chain of 6: the page needs the module's types, the views fill the placeholders, the budget and journey time the views, the live page samples through the command under the journey, and EY-9 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| EY-1 | the two suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes over `Sample/` | the module imports CoreRaster | – (stubs) |
| EY-2 | SJ0: the index lists `eyedropper`; the page opens; every existing colour row still builds with the button hidden | the page is missing or a row breaks | – (UI) |
| EY-3 | `EyedropperTests`: a pick calls the row's onChange then onEnd once each; a nil pick calls neither; the loupe's hex reads `#00FF00` for green and "No colour here" for nil | a pick is doubled or a cancel changes the row | – (UI) |
| EY-4 | `SuiteEyedropperSnapshots`; `RenderBudgetEyedropperTests.loupeTrackInThreeBodies`; `testEyedropperPicksFromCanvas` steps 1 to 5 | budget over, or a step fails | – (UI) |
| EY-5 | `SampleRulesTests`: a point on red reads `#FF0000`; 3 × 3 over half red, half blue reads their mean; transparent pixels are skipped; a square off the image's edge averages what is inside; all transparent is nil | a mean is wrong or counts transparent pixels | `SuiteKernel.SampleRules`: alpha weight dropped → `.meanWeightsAlpha`; transparent counted → `.meanSkipsTransparent`; `n/2` for `-(n/2)` → `.squareIsCentred` |
| EY-6 | `SampleCommandsTests`: `color.sample` on a test target returns its colour as hex and channels, `null` on empty space, and is unavailable with `sampleHelp` | the result shape or the why-not is wrong | `SuiteKernel.SampleCommands`: help not checked → `.honoursSampleHelp`; size ignored → `.passesSize` |
| EY-7 | `EyedropperLiveTests`: the page's tool samples its canvas through `color.sample` on a local target and the row takes it as one step; `testEyedropperPicksFromCanvas` on live | the page stays on the local log | – (UI) |
| EY-8 | `FakeSampleTests`: the topmost rect under a point wins; a gradient rect reads its colour at the point; empty space is nil; RJ-X33 passes on Linux | a lower rect wins or the gradient reads its first stop | `SuiteKernel.FakeCanvasDocument`: bottom rect first → `.sampleTopmost`; solid colour used for a gradient → `.sampleGradientAtPoint` |
| EY-9 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample loupe track over the gallery canvas | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetEyedropperTests.loupeTrackInThreeBodies` |
| One gesture, one step | a screen pick is one change and one end | `EyedropperTests.pickIsOneGesture` |
| No dead controls; keyboard and VoiceOver | the button identified `suite.color.eyedropper`, reachable by Tab, Space opens the sampler, Escape cancels | `testEyedropperPicksFromCanvas` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): EY-m merged-done on the Linux job with
`Mutate:` scores clean; EY-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; EY-z's journey on live and RJ-X33 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-eyedropper-*`.

## Adopted by

`photo/eyedropper` (the Eyedropper tool, sample size, the brush colour;
RJ-P22), `design/eyedropper` (an Eyedropper tool that sets the selection's
fill or stroke; RJ-D34). Each waits on EY-a. Every other app's colour rows get
the button from SuiteUI with no adopt (Flare's and Halo's fill rows,
gradient stops).

## Not in this packet

Sampling one layer instead of the composite, a colour history or swatch
panel, sampling across apps by drag, a "sample all layers" toggle.
