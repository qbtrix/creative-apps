# Feature packet: stroke-style

**Feature:** one stroke for the suite: colour, width, join, cap, dashes and
trim paths, edited by one SuiteUI `StrokeEditor` that is built the way the
gradient editor is and sits under it in each app's paint section. SuiteKernel's
`Fill/` module (gradient-fill's) gets the stroke half of paint: FlareCore's
`Stroke` under the kernel name `VectorStroke`, `StrokeRules` (width limits,
the dash presets scaled by width, the painted path: trimmed, then dashed, on
FlareCore's path ops), the nine stroke commands every app registers, and
`StrokeSVG`'s attributes. The editor never edits a document: it emits
`StrokeIntent`s, each one a stroke command.
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/stroke-style`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"; trim paths are a high-weight Flare row). Labels `beta` and `p1` when filed.

**Covers:** feature map S17 (strokes, dashes and trim paths; gradient fills
are S24); real job RJ-X35 (new). The adopts are `design/stroke-style`,
`flare/stroke-style` and `halo/stroke-style`, each waiting on this packet's
SS-a.

**Depends on:**
- gradient-fill's **GF-a** before SS-1 (the `Fill/` module and `FillColor`)
  and its **GF-z** before SS-10 (both own `kernel-fill.json`); shape-tools'
  **SH-z** before SS-8 (the fake document).
- **creative-core path-geometry (#430)** built and a core bump in
  creative-apps: `Path.trimmed(start:end:offset:mode:tolerance:)`,
  `dashed(_:phase:tolerance:)` and `outlined(width:join:cap:miterLimit:…)`
  are on core `dev` (#735, #739, #741, #743, #751) but not at the pinned
  revision. SS-7 waits on the bump.
- **creative-core stroke-style (to file, `line:core`):** the model fields
  path-geometry left to S17. `Stroke.dash: [Double] = []`,
  `Stroke.dashPhase: Double = 0` and `Stroke.trim: StrokeTrim?` (`start`,
  `end` in 0...1, `offset` in turns, `mode: TrimMode`), decoded with those
  defaults so every old file opens; validation (a pattern of at most 64
  finite entries ≥ 0 with a positive sum; trim ends in 0...1); the render list
  strokes the trimmed, then dashed path; SVG writes `stroke-dasharray`,
  `stroke-dashoffset` and the trimmed geometry; Lottie writes `d` and a `tm`
  shape; Double tracks `trimStart.<i>`, `trimEnd.<i>`, `trimOffset.<i>`
  sampled like `strokeWidth.<i>` (animate-properties' "S17's trim fields key
  through the existing Double tracks"). SS-7 waits on it. Colour, width, join
  and cap are on the pinned core today, so SS-a, SS-u and SS-m don't wait.

**Rule 20.** One stroke model: FlareCore's `Stroke`, which Flare stores and
every exporter writes. Design's `DesignStroke` (`StyleTypes.swift`, colour and
width only) is the one app copy; `design/stroke-style` replaces it with
`VectorStroke` and reads old files. The kernel name is `VectorStroke`, never
`Stroke`: `Sources/SuiteKernel/Stroke/` is the brush module and SwiftUI owns
`StrokeStyle`. Dash and trim maths are FlareCore's path ops; `StrokeRules`
only chooses and orders them, so the canvas, the SVG and the raster outline
draw the same dashes.

**Render path.** None new. Design and Flare stroke `StrokeRules.paintedPath`
through SwiftUI and CoreGraphics as they stroke paths today; Halo fills
`Path.outlined` of the painted path through `HaloOutlines`' polygon branch,
the route its shapes already take; Photo has no vector strokes.

**C4:** `kernel-fill.json` gains `VectorStroke.swift`, `StrokeRules.swift`,
`StrokeCommands.swift` and `StrokeSVG.swift` (SS-10). `StrokeEditor.swift` is
a new file under `Sources/SuiteUI/`, covered by `suiteui-sources`.

**Clean-room.** Stroke semantics from SVG 1.1 (`stroke-dasharray`, joins and
caps) and the Lottie format's trim shape; no task reads another product's
code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets), 7.5 (feel);
suite.md 1.5 (commands).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SS-a | The kernel's stroke type, rules, target, intents, nine command specs and SVG writer are declared as stubs, the gallery's stroke-editor page is in the index, and the checks are written, disabled. | SS-1, SS-2 | SJ0 | gradient-fill:GF-a (SS-1) |
| SS-u | On the gallery page the editor sets colour, width, join and cap, shows the dash presets and trim rows (disabled with their reason until SS-d), and hides trim where an app has none, every control identified, within the render budget. | SS-3, SS-4 | KS1 | SS-a |
| SS-m | The rules clamp widths and scale the dash presets, the SVG writer writes colour, width, join and cap, and every stroke command but dash and trim records exactly one undo step (a scrub one). | SS-5, SS-6 | KJ-stroke | SS-a |
| SS-d | On the bumped core, dashes and trims paint the trimmed then dashed path, the two commands save fractions and scaled patterns in one step, and the fake app keeps them so RJ-X35 runs on the CLI. | SS-7, SS-8 | KJ-stroke | SS-m; creative-core path-geometry #430, stroke-style (to file) and the core bump (SS-7); shape-tools:SH-z (SS-8) |
| SS-z | The gallery runs its intents through StrokeCommands on a live target, the journey dashes and trims on live, and the feature is built. | SS-9, SS-10 | KS1 | SS-u, SS-d; gradient-fill:GF-z (SS-10) |

SS-u waits only on SS-a (rule 18); SS-m and SS-d never wait on SS-u. Until
SS-d merges, the editor's dash and trim rows show the commands' reason ("Dashes
and trim need creative-core's stroke fields.") and stay disabled; nothing
else waits on core. KJ-stroke is the rules' and commands' Linux walk in
`SuiteKernelTests`.

## Journey steps

1. Open the gallery index, click `stroke-editor` (SS-2, SJ0): a path with a
   2 pt black stroke and the editor: colour row, Width, Join, Cap, Dash, and
   Trim (Start, End, Offset).
2. Pick red, scrub Width to 6 (SS-3, `SuiteStrokeJourneyTests.testStrokeEditorDashAndTrim`):
   the preview follows; the log shows one `stroke.color` and a run of
   `stroke.width` under one drag token.
3. Pick Round join and Round cap: the corners and ends round.
4. Pick Dashed: the preview dashes at 4 × width on, 2 × width off; pick
   Custom and type 10 and 4: the pattern follows.
5. Scrub Trim End from 100% to 40%: the visible stroke shortens from its end;
   Offset turns it along the path. Remove Stroke clears it; Add Stroke brings
   a 1 pt black one back. Every row is reachable by Tab (SS-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X35 | adds, closes with S17 | C | `Tests/RealJobs/fake/dash-trim/dash-trim.jobs.json`: `rect.select`, `stroke.add`, `stroke.width {"width": 4}`, `stroke.dash {"preset": "dashed"}`, 60 `stroke.trim` under one drag token ending at `{"start": 0, "end": 0.5}`, then `edit.undo`; the saved rects before and after the undo | `input/one.fake` (one free rect) |

Trap: the dash pattern doesn't scale with the width (a 4 pt line gets
1 pt dashes), or the trim saves as a percentage (50) and draws nothing.
Assertion: the saved stroke reads `dash` `[16, 8]` and `trim.end` 0.5 before
the undo, and no `trim` after it (the 60 samples were one step). Mutations:
`SuiteKernel.StrokeRules.json` (pattern not scaled → `.dashScalesWithWidth`)
and `SuiteKernel.StrokeCommands.json` (percent kept → `.trimIsFraction`; drag
token dropped → `.trimDragIsOneStep`).

## Screens and states

`suiteui-stroke-editor` (light and dark), `-dashed`, `-custom-dash`,
`-trimmed` (end at 40%), `-no-stroke` (the Add Stroke button alone),
`-no-trim` (an app without trim: the trim rows hidden), `-waiting-core` (dash
and trim rows disabled with their reason, before SS-d).

## Contract slice

```swift
// Sources/SuiteKernel/Fill/VectorStroke.swift (SS-1, complete)
public typealias VectorStroke = FlareCore.Stroke     // colour, width, join, cap; dash, dashPhase, trim after the core bump
public typealias StrokeJoin = FlareCore.Stroke.Join
public typealias StrokeCap = FlareCore.Stroke.Cap
public enum DashPreset: String, Codable, CaseIterable, Sendable { case solid, dashed, dotted, custom }
// Sources/SuiteKernel/Fill/StrokeRules.swift (SS-1 stubs; SS-5 width, join, cap and presets; SS-7 dash and trim)
public enum StrokeRules {
    public static let widths = 0.0...1000.0, maxDashEntries = 64
    public static let waitingCore = "Dashes and trim need creative-core's stroke fields."
    public static func clampedWidth(_ width: Double) -> Double
    public static func pattern(_ preset: DashPreset, width: Double) -> [Double]   // dashed [4w, 2w], dotted [0, 2w]
    public static func preset(of stroke: VectorStroke) -> DashPreset             // .solid until SS-7
    public static func dash(of stroke: VectorStroke) -> (pattern: [Double], phase: Double)   // ([], 0) until SS-7
    public static func trim(of stroke: VectorStroke) -> (start: Double, end: Double, offset: Double)?   // nil until SS-7
    /// The path a stroke paints: trimmed, then dashed; `path` itself for a plain stroke.
    public static func paintedPath(_ path: Path, _ stroke: VectorStroke) throws -> Path
}
// Sources/SuiteKernel/Fill/StrokeCommands.swift (SS-1 specs with ids, schemas and availability, runs throwing
// `StrokeRules.notBuilt`; SS-6 bodies but dash and trim; SS-7 those two)
public protocol StrokeTarget: Sendable {
    var strokeHelp: String? { get }                 // why nothing can be stroked now; nil when it can
    var trimHelp: String? { get }                   // why trim can't run (Design: "Trim paths are for animation, in Flare and Halo.")
    var selectedStroke: VectorStroke? { get }       // the primary selected layer's stroke; nil when it has none
    /// Sets (nil removes) the stroke of every selected unlocked layer; one undo step named `name`;
    /// steps under one `drag` token fold into one.
    mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws
}
public enum StrokeIntent: Hashable, Sendable {
    case add, remove, color(FillColor, drag: String?), width(Double, drag: String?)
    case join(StrokeJoin), cap(StrokeCap), dash(DashPreset, pattern: [Double]?)
    case trim(start: Double, end: Double, offset: Double, drag: String?)
    public var command: (id: String, params: JSONValue) { get }
}
public enum StrokeCommands {
    public static func specs<T: StrokeTarget>(_ target: T.Type) -> [CommandSpec<T>]
}
// Sources/SuiteKernel/Fill/StrokeSVG.swift (SS-1 stub returning [], SS-5 colour to cap, SS-7 dash)
public enum StrokeSVG { public static func attributes(_ stroke: VectorStroke) -> [(name: String, value: String)] }
// Sources/SuiteUI/StrokeEditor.swift (SS-2 placeholder, SS-3 view)
/// `showsTrim: false` hides the trim rows (Design); `dashHelp` disables the dash and trim rows with it.
public struct StrokeEditor: View {
    public init(stroke: VectorStroke?, help: String?, dashHelp: String?, showsTrim: Bool = true,
                onIntent: @escaping @MainActor (StrokeIntent) -> Void)
}
```

Commands (all `edit` but `stroke.read`; ids go in each adopter's
`Tests/command-ids/<app>.txt`):

| id | title (undo step) | params | unavailable when |
|---|---|---|---|
| `stroke.read` | – (query) | – → `{r, g, b, a, width, join, cap, dash, dashPhase, trim?}` or `null` | `strokeHelp` |
| `stroke.add` | Add Stroke | – (1 pt black, miter, butt) | `strokeHelp`; already stroked ("The layer already has a stroke.") |
| `stroke.remove` | Remove Stroke | – | `strokeHelp`; no stroke |
| `stroke.color` | Stroke Color | `{r, g, b, a, drag?}` | `strokeHelp`; no stroke |
| `stroke.width` | Stroke Width | `{width, drag?}` (0...1000) | `strokeHelp`; no stroke |
| `stroke.join` | Stroke Join | `{join}` | `strokeHelp`; no stroke |
| `stroke.cap` | Stroke Cap | `{cap}` | `strokeHelp`; no stroke |
| `stroke.dash` | Stroke Dash | `{preset}` or `{pattern, phase?}` | `strokeHelp`; no stroke; `StrokeRules.waitingCore` until SS-7 |
| `stroke.trim` | Trim Path | `{start, end, offset?, drag?}` (fractions, offset in turns) | `strokeHelp`; `trimHelp`; no stroke; `waitingCore` until SS-7 |

An app adds the nine with `+ StrokeCommands.specs(<X>Workspace.self)` and its
`<X>Stroke+Kernel.swift` conformance.

## Pseudocode

- **pattern.** dashed `[4w, 2w]`, dotted `[0, 2w]` with the cap forced
  round by the command (a zero dash with a butt cap draws nothing), solid
  `[]`, each `w = max(width, 1)`. `preset(of:)` reads the pattern back to its
  preset when it matches, else `.custom`.
- **paintedPath.** No trim and no dash: `path`. Else
  `path.trimmed(start, end, offset, mode, tolerance: 0.25)` then
  `.dashed(pattern, phase, tolerance: 0.25)`. A trim with `start == end`
  paints nothing (an empty path, not an error).
- **commands.** Each spec reads `selectedStroke`, applies one rule, calls
  `setStroke` once with its title; `drag` passes through, so the target's
  `History` folds a scrub into one step. `stroke.dash` with a dotted preset
  also sets the cap to round in the same step.
- **View.** One `Form`-free stack in the paint section's style: the colour
  row (`InspectorColorWellRow`, with gradient-fill's and the eyedropper's
  row behaviour), Width (`StudioScrubRow` 0...1000 pt), Join and Cap
  (`ChoiceChips` with SF Symbols), Dash (`ChoiceChips` of the presets, and
  for Custom two `StudioScrubRow`s, Dash and Gap), Trim (Start, End 0...100 %,
  Offset −360...360 °). Each sample emits one intent, as `GradientEditor`
  does.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SS-1 | – | The contract: `VectorStroke`, `StrokeJoin`, `StrokeCap`, `DashPreset` (complete); `StrokeRules`, `StrokeTarget`, `StrokeIntent`, the nine specs with ids, schemas and availability and `StrokeSVG` as stubs; the three suites written, disabled by name | `Sources/SuiteKernel/Fill/VectorStroke.swift`, `Sources/SuiteKernel/Fill/StrokeRules.swift`, `Sources/SuiteKernel/Fill/StrokeCommands.swift`, `Sources/SuiteKernel/Fill/StrokeSVG.swift`, `Tests/SuiteKernelTests/StrokeRulesTests.swift`, `Tests/SuiteKernelTests/StrokeCommandsTests.swift`, `Tests/SuiteKernelTests/StrokeSVGTests.swift` | – | ~340, 7 |
| SS-2 | – | The placeholder `StrokeEditor`; the gallery's `stroke-editor` page in `GalleryInspector.pages` on a local stroke; the journey written and skipped (`XCTSkip("waits on SS-4")`) | `Sources/SuiteUI/StrokeEditor.swift`, `Sources/SuiteUI/Gallery/GalleryStrokeEditor.swift`, `Sources/SuiteUI/Gallery/GalleryInspector.swift`, `UITests/SuiteJourneyTests+Stroke.swift` | SS-1 | ~200, 4 |
| SS-3 | – | The editor: colour row, Width, Join, Cap, Dash presets and Custom rows, Trim rows (hidden with `showsTrim: false`), disabled rows with their reason, identifiers `suite.stroke.*` | `Sources/SuiteUI/StrokeEditor.swift`, `Tests/SuiteUITests/StrokeEditorTests.swift` | SS-2 | ~360, 2 |
| SS-4 | – | Snapshots, the render budget test, the journey's steps 1 to 3 turned on | `Tests/AppSnapshotTests/SuiteStrokeEditorSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetStrokeEditorTests.swift`, `UITests/SuiteJourneyTests+Stroke.swift` | SS-3 | ~220, 3 |
| SS-5 | – | `StrokeRules` width, join, cap and preset bodies and `StrokeSVG`'s colour-to-cap attributes, on the pinned core; turns on their tests | `Sources/SuiteKernel/Fill/StrokeRules.swift`, `Sources/SuiteKernel/Fill/StrokeSVG.swift`, `Tests/SuiteKernelTests/StrokeRulesTests.swift`, `Tests/SuiteKernelTests/StrokeSVGTests.swift`, `Tests/mutations/SuiteKernel.StrokeRules.json`, `Tests/mutations/SuiteKernel.StrokeSVG.json` | SS-1 | ~260, 6 |
| SS-6 | – | `StrokeCommands` bodies but dash and trim, and `StrokeIntent.command`; turns on `StrokeCommandsTests` on a test target | `Sources/SuiteKernel/Fill/StrokeCommands.swift`, `Tests/SuiteKernelTests/StrokeCommandsTests.swift`, `Tests/mutations/SuiteKernel.StrokeCommands.json` | SS-5 | ~320, 3 |
| SS-7 | – | After the core bump with path-geometry and stroke-style: dash and trim in the rules (`paintedPath`), the two commands and the SVG writer, with their tests | `Sources/SuiteKernel/Fill/StrokeRules.swift`, `Sources/SuiteKernel/Fill/StrokeCommands.swift`, `Sources/SuiteKernel/Fill/StrokeSVG.swift`, `Tests/SuiteKernelTests/StrokeDashTrimTests.swift`, `Tests/mutations/SuiteKernel.StrokeRules.json`, `Tests/mutations/SuiteKernel.StrokeCommands.json`, `Tests/mutations/SuiteKernel.StrokeSVG.json` | SS-6 | ~300, 7 |
| SS-8 | – | The fake app takes strokes: `FakeRect.stroke` (omitted when nil), `FakeCanvasDocument` conforms and lists the specs; RJ-X35's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeStrokeTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/dash-trim/dash-trim.jobs.json`, `Tests/RealJobs/fake/dash-trim/input/one.fake` | SS-7 | ~200, 5 |
| SS-9 | – | The gallery page runs each intent through `StrokeCommands` on a local target with a `History`; the journey's steps 4 and 5 on live; the live test | `Sources/SuiteUI/Gallery/GalleryStrokeEditor.swift`, `Tests/SuiteUITests/StrokeEditorLiveTests.swift`, `UITests/SuiteJourneyTests+Stroke.swift` | SS-4, SS-7 | ~160, 3 |
| SS-10 | – | `kernel-fill.json` names the stroke files, commands and the editor; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-fill.json`, `docs/blueprints/suiteui/features/stroke-style.wave.json` | SS-8, SS-9 | ~20, 2 |

SS-1 declares every rule and spec so SS-5, SS-6 and SS-7 fill bodies without
changing a signature.

## Build waves

- Wave 1: SS-1. Independent in this wave: SS-1 alone.
- Wave 2: SS-2, SS-5. Independent in this wave: both.
- Wave 3: SS-3, SS-6. Independent in this wave: both.
- Wave 4: SS-4, SS-7. Independent in this wave: both.
- Wave 5: SS-8, SS-9. Independent in this wave: both.
- Wave 6: SS-10 (`feature-done`, final). Independent in this wave: SS-10 alone.

Longest chain: SS-1 → SS-5 → SS-6 → SS-7 → SS-8 → SS-10 (6). Chain of 6: the rules come before the commands that call them, dash and trim fill the same three files once the core bump lands, the fake app's job needs dash and trim, and SS-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SS-1 | the three suites compile, disabled by name; `VectorStroke` is FlareCore's `Stroke`; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes over `Fill/` | the module imports past FlareCore, or a second stroke type appears | – (stubs) |
| SS-2 | SJ0: the index lists `stroke-editor`; the page opens | the page is missing | – (UI) |
| SS-3 | `StrokeEditorTests`: a width scrub emits `.width`s under one token; Round join emits one `.join(.round)`; Dashed emits one `.dash(.dashed, nil)`; with `dashHelp` set the dash and trim rows are disabled with it; `showsTrim: false` hides the trim rows | an intent is wrong or doubled, or a disabled row acts | – (UI) |
| SS-4 | `SuiteStrokeEditorSnapshots`; `RenderBudgetStrokeEditorTests.widthScrubInThreeBodies`; `testStrokeEditorDashAndTrim` steps 1 to 3 (4 and 5 skipped until SS-9) | budget over, or a step fails | – (UI) |
| SS-5 | `StrokeRulesTests`: widths clamp to 0...1000; `pattern(.dashed, width: 4)` is `[16, 8]`; dotted is `[0, 8]`; a solid stroke's painted path is the input; `StrokeSVGTests`: colour, width, round join and cap attributes | a pattern or attribute is wrong | `SuiteKernel.StrokeRules`: pattern not scaled → `.dashScalesWithWidth`; `min` for `max(width, 1)` → `.hairlineDashVisible`; `SuiteKernel.StrokeSVG`: join written for cap → `.capAttribute` |
| SS-6 | `StrokeCommandsTests`: each edit records one step named its title; 120 `stroke.width` under one token undo in one; `stroke.add` on a stroked layer is unavailable with its reason; `stroke.dash` and `stroke.trim` are unavailable with `waitingCore`; `StrokeIntent.command` round-trips each case | a run records zero or two steps, or a why-not is missing | `SuiteKernel.StrokeCommands`: drag not passed → `.widthDragIsOneStep`; add allowed twice → `.addNeedsNoStroke`; trimHelp not checked → `.trimHonoursHelp` |
| SS-7 | after the core bump: `StrokeDashTrimTests`: `stroke.dash` dashed on a 4 pt stroke saves `[16, 8]`; dotted also rounds the cap in the same step; `stroke.trim` 0...0.5 halves the painted length (`Path.length`); start equal to end paints nothing; SVG writes `stroke-dasharray="16 8"`; old strokes decode with no dash | a pattern, a trim or an old file is wrong | `SuiteKernel.StrokeRules`: dash before trim → `.trimThenDash`; `SuiteKernel.StrokeCommands`: percent kept → `.trimIsFraction`; dotted keeps a butt cap → `.dottedRoundsCap`; `SuiteKernel.StrokeSVG`: phase written as dasharray → `.dashOffset` |
| SS-8 | `FakeStrokeTests`: a stroke with dash and trim survives save and open; old jobs' JSON is unchanged; RJ-X35 passes on Linux | the stroke is lost or old JSON changes | `SuiteKernel.FakeCanvasDocument`: stroke dropped on save → `.strokeSaved`; trim drag recorded per sample → `.trimDragIsOneStep` |
| SS-9 | `StrokeEditorLiveTests`: a width scrub on the page leaves one undo step; `testStrokeEditorDashAndTrim` steps 1 to 5 on live | the page stays on the local log | – (UI) |
| SS-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-sample width scrub on the gallery page | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetStrokeEditorTests.widthScrubInThreeBodies` |
| render: 120-sample trim-end scrub | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetStrokeEditorTests.trimScrubInThreeBodies` |
| One gesture, one step | a width scrub, a trim scrub, a colour-panel session, a preset click each one undo step | `StrokeCommandsTests.widthDragIsOneStep`, `StrokeEditorLiveTests` |
| No dead controls | a row that can't act is disabled with its reason, never silent | `StrokeEditorTests.disabledRowsSayWhy` |
| Keyboard and VoiceOver | every row reachable by Tab, chips read their name ("Round join") | `testStrokeEditorDashAndTrim` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): SS-m and SS-d merged-done on the Linux job
with `Mutate:` scores clean and RJ-X35 green; SS-u's feel gate (`mouse`,
`taste`, `job` lenses) and its `Mac-Finish:` line; SS-z's journey on live.
Then `Belt-Contact-Sheet:` with `suiteui-stroke-editor-*`.

## Adopted by

`design/stroke-style` (Design's stroke rows become the editor; dashes, joins,
caps; `DesignStroke` replaced; RJ-D36), `flare/stroke-style` (the editor in
Flare's STROKE section; trim paths keyed for a draw-on; RJ-F02),
`halo/stroke-style` (strokes on shape layers, drawn by the frame renderer;
trim keyed; RJ-H30's stroke). Each waits on SS-a.

## Not in this packet

Gradient strokes, variable-width strokes, stroke alignment inside or outside
(SVG has none; centred only), arrowheads as stroke ends (S19's Arrow shape
covers the everyday case), multiple strokes per layer, a dash pattern editor
past two entries.
