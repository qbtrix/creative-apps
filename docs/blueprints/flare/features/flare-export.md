# Feature packet: flare-export

**Feature:** export the open animation from the Export sheet as an SVG of one
frame, a Lottie JSON of the scene, or a PNG sequence of a frame range, into a
folder the person picks: the warnings the scan already names are shown
before Export, the run shows its progress and can be cancelled (no file is
left behind), nothing is ever overwritten, a failure says why with Try Again,
and a finished export offers Reveal in Finder. Flare's export state is the
SuiteKernel `ExportRun<ExportOptions>` and its sheet is SuiteUI's
`ExportSheet`; the SVG, Lottie and PNG writers are FlareCore's. An SVG or
Lottie export of a saved and reopened document is byte for byte the export
of the document before the save (the round-trip check).
**Line:** `line:flare` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/flare-export` · **Beta:** in the captain's cut (`2026-10-17-afterglow-beta-cut.md`, Flare row: "SVG frame, PNG sequence; Lottie if cheap"; Lottie is cheap, `LottieExporter` exists and `FakeExport` already writes it)

**Covers:** F15a #354 (the sheet), F15b #355 (failure, Cancel, never
overwrite), IN-7 #374 (export live; LM-13a and LM-13b, the live `Exporting`),
LA-1 (`StageRasterizer`, no issue of its own; blueprint 7.6 row "PNG export
equals the stage"). `docs/blueprints/suite.md` names #366 for Flare's SVG
export as the file Design's import will read; the SVG this packet writes is
that file.

**Depends on:** the `draw-key-save` feature (#1365, built: the window, the
router, `FlareWindow+Export.swift` as a stub, `-FlareExportTo` parsed into
`FlareLaunch.exportFolder`). Cross-line, in the `waits_cross_line` data (the
checker resolves `waits` keys inside one app only, so they are not in
`waits`; the lead checks each before its task starts): FX-2 waits on
editor-kernel's contract slice `EK-a` (the `SuiteKernel` target with the
`ExportRun` stub), FX-4 on `EK-run` (the real `ExportRun` body), FX-3 on
`EK-chrome` (SuiteUI's `ExportSheet`). Those three slices are not in the beta
cut's editor-kernel subset ("EK-a contract, EK-undo, EK-sel, EK-tree,
EK-stroke, EK-u"); this packet needs `EK-run` and `EK-chrome` too, about 300
and 590 lines. In the app, FX-5 waits on `inspector-timeline` (it owns
`UITests/FlareJourneyTests.swift`, whose J0 row still reads "Not built yet
(F15a).").

**Hand-offs** (files other packets own, cross-line, so not in `waits`):
- **adopt-kernel-export AX-flare** plans the same move (Flare's export state
  on `ExportRun<Options>`) and owns `FlareExport.swift`,
  `FlareWorkspaceState.swift`, `ExportScanTests.swift` and
  `Tests/mutations/FlareModel.FlareExport.json`. This packet does that move
  in FX-2 and FX-4 (rule 20: a task that needs export builds into the kernel
  module), so AX-flare becomes a check that nothing is left to delete, or is
  dropped; its Hand-offs line already says it starts after Flare's export
  packet. Issue to file on the adopt-kernel-export packet.
- **adopt-suiteui-chrome** owns `Sources/FlareApp/FlareWindow+Export.swift`
  too; it runs after this feature is built.

**Clean-room.** Behaviour only: the SVG and Lottie shapes come from the
public W3C and Lottie format docs through FlareCore; the sheet's rules come
from this blueprint and the apps' own tests.

**Never overwriting, without an app-local naming engine.** Library's
`LiveExporter.plan(…, existingNames:)` already numbers clashing names
(`IMG_0001 2.jpg`); rule 20 says a concept one app has is extracted into the
kernel first, never copied. The kernel has no naming module yet, so for the
beta the writer refuses a clash before it writes anything: "scene-1.svg is
already in Exports. Choose another folder." with Try Again. Zero naming
logic in Flare; when `SuiteKernel` gets the shared unique-name rule (issue to
file: extract Library's), one task adopts it and the refusal becomes the
` 2` suffix.

**The round-trip check, defined.** creative-core at the pinned `c608d4b` has
no SVG or Lottie importer, so the check is not import-and-compare. It is:
export the document (SVG at a frame, Lottie), save it with `saveData()`,
reopen those bytes in a fresh workspace, export again, and the bytes are
identical; exporting the same document twice is identical too. `SVGExporter`
builds its string in order and `LottieExporter` encodes with `.sortedKeys`,
so byte identity is a real oracle; on top, the SVG parses with `XMLParser`
(`FoundationXML` on Linux) with the scene's `width` and `height`, and the
Lottie decodes with `fr`, `w`, `h` and `op` equal to the scene's fps, width,
height and frame count. PNG is excluded (pixels depend on the rasterizer).

Blueprint sections: 1 (usage map, tier 2 "export"), 3.3 (Export sheet row;
FX-10 changes "Replace existing files?" to the refusal), 3.4 (File > Export…
⇧⌘E), 4 (J22, J23), 6.3 (`-FlareExportTo`, `FlareWindow` picks the
rasterizer, `FlareServices` has no rasterizer member), 7 rows "SVG export",
"Lottie export", "PNG sequence", "Export warnings", "Export failure, cancel,
replace", 7.3 (F15a, F15b), 7.6 (IN-7, LA-1), the "PNG export equals the
stage (QB-V4)" row.

**Where it starts from.** The Model has `ExportContracts.swift`
(`ExportFormat { svgFrame, lottie, pngSequence }`, `ExportOptions(format:
sceneID: frames: step: scale: transparentBackground:)`, `ExportFile`,
`ExportResult(files:, warnings:)`, `Exporting`, `FrameRasterizing`),
`ExportScan` (the four warning sentences and `withoutText`), `FakeExport`
(FlareCore's `SVGExporter`, `LottieExporter` and `PNGExportPlan` over
`FakeStage`'s draw lists, 20 ms per PNG frame so Cancel is reachable, a
cancel throws between frames), `FakeRasterizer` (one 1 × 1 PNG), and
`FlareExport.swift` with today's app-local run (`ExportState { idle,
running(progress:), finished(ExportResult), failed(String) }`,
`beginExport`, `exportProgressed(_ fraction:)`, `endExport`,
`dismissExport`, `export(_:rasterizer:)`), tested in `ExportScanTests`.
`FlareServices.fake()` holds `FakeExport()`; `.live` and `.built` hold
`NotBuilt("Not connected yet (IN-7).")`. The app has `FlareIntent.Export {
showSheet }`, the toolbar's Export… and File > Export… ⇧⌘E routed to
`FlareWindow+Export.swift`, where `performExport` does nothing and
`exportHelp` says "Not built yet (F15a).". No `StageRasterizer` exists
(LA-1). The kernel side is editor-kernel's: `ExportRun<Options>` (`idle`,
`editing(Options)`, `running(Options, done:, total:)`, `finished(Options,
[String])`, `failed(Options, String)`; `begin`, `start(total:)`,
`progressed(done:)`, `end`, `dismiss`; progress never goes back, cancel
returns to idle) and SuiteUI's `ExportSheet` (EK-30: rows from a
`FormatChoice` list, `StudioScrubRow`s, a progress bar, the finished or
failed line, over `ExportRun` readouts).

## Slices

A slice is the unit of done: its tasks have merged, its Linux walk is green
on the newest dev run, and its journeys pass on the Flare-scoped macOS run
(`ci.yml` with `app=flare`) that contains its last PR.

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FX-a | The export intents exist with titles and identifiers, `ExportState` is the kernel's `ExportRun<ExportOptions>`, and every Model signature the sheet calls is declared as a stub, with the Model tests and the round-trip test written and disabled, so the UI and the logic slices build at once. | FX-1, FX-2 | MJ-FX0 | editor-kernel:EK-a (FX-2, cross-line) |
| FX-u | Export… on the toolbar and in the File menu opens SuiteUI's `ExportSheet` with Flare's rows on the fakes, Export writes the files into `-FlareExportTo`'s folder or one the person picks, never over an existing file, with progress, Cancel, Reveal in Finder and Try Again, and `StageRasterizer` draws real pixels. | FX-3, FX-5, FX-7 | J22, J23 | FX-a (FX-3, FX-5); editor-kernel:EK-chrome (FX-3, cross-line); inspector-timeline (FX-5) |
| FX-run | The Model's export run is the kernel's: open, edit the options with their refusals, start with the plan's file count, progress that never goes back, finished with the written names, idle on cancel, failed with a sentence, Try Again back to editing. | FX-4, FX-11 | MJ-FX1 | FX-a; editor-kernel:EK-run (FX-4, cross-line) |
| FX-live | `LiveExportAdapter` runs FlareCore's exporters over the live stage with cancellation, `FakeExport` is that adapter over `FakeStage`, and the SVG and Lottie round trip is byte-identical on both. | FX-6, FX-8 | MJ-FX2 | FX-a (FX-8) |
| FX-z | `.built` exports through `LiveExportAdapter`, J22 and J23 pass live through `StageRasterizer`, the blueprint rows and the waves prose are current, and the feature is built. | FX-9, FX-10 | J22, J23 (live) | FX-u, FX-run, FX-live |

FX-a is the contract (rule 12). FX-u is the UI slice (`"ui": true`: the feel
gate, rule 15, and the Mac finish, rule 17): FX-3 makes Export… act on the
fakes, clickable end to end, and waits on no slice of this feature but FX-a;
FX-7, the rasterizer, waits on nothing. FX-run and FX-live are the logic
slices and never wait on FX-u. FX-z integrates: FX-9 swaps the fakes for the
live services and runs the journeys on `-FlareSample`. FX-run splits the run's
transitions (FX-4, `FlareExport+Kernel.swift`, the adapter onto the kernel)
from the readouts and setters (FX-11, `FlareExport.swift`), one file and one
test file each; FX-live splits the adapter (FX-6)
from the fake's delegation and the round-trip tests it turns on (FX-8),
which need FX-2's disabled tests.

## Journey steps

J22 and J23 each have their own file and class. FX-3 runs them on
`-FlareFixture <fixture>` (the fakes: real SVG and Lottie bytes, 1 × 1 PNGs,
20 ms per PNG frame); FX-9 switches J22 to `-FlareSample showcase` (live) and
adds the pixel-size check. Every launch passes `-FlareExportTo` on a fresh
temp folder the test makes and removes. Each step takes one shot,
`flare-export-<step>`.

**J22 · `FlareExportJourneys.testExportSVGLottieAndPNGSequence`**
(`UITests/FlareJourneyTests+Export.swift`; FX-3, live in FX-9) on
`showcase` (550 × 400, 24 fps, 48 frames, scene `scene-1`; a text layer, an
animated symbol instance and a machine):

| # | step (mouse) | expect |
|---|---|---|
| 1 | click the toolbar's Export… (`flare.export.showSheet`) | the sheet; the SVG frame chip (`flare.export.format.svgFrame`) selected; the warnings list reads "Text isn't exported yet (1 layer).", "Symbol animation exports as its first frame (1 instance).", "Interactions aren't exported (1 machine)."; Export (`flare.export.start`) enabled |
| 2 | click Export | the finished row "Exported scene-1.svg." with Reveal in Finder (`flare.export.reveal`) enabled; `scene-1.svg` exists, starts `<svg`, `XMLParser` parses it and the root's `width` is "550" and `height` "400" |
| 3 | click Done (`flare.export.dismiss`); click Export…; click the Lottie chip | the fourth warning "Background color isn't part of Lottie." joins the list |
| 4 | click Export | "Exported scene-1.json."; `scene-1.json` is JSON with `fr` 24, `w` 550, `h` 400, `op` 48 |
| 5 | Done; Export…; click the PNG sequence chip; click the To row (`flare.export.to`), type 12, Return; click the Step row (`flare.export.step`), type 2, Return | the From, To, Step, scale and transparent rows are shown; the file count reads "7 files" |
| 6 | click Export | the progress row with Cancel while it runs; then "Exported 7 files."; `frame_0000.png` … `frame_0012.png` (7 files) each start with the PNG header; live (FX-9): each IHDR width is 550 |

**J23 · `FlareExportErrorJourneys.testExportNeverOverwritesCancelAndFailure`**
(`UITests/FlareJourneyTests+ExportErrors.swift`; FX-3) on `bounce` with the
fakes (the 20 ms frame pause keeps Cancel reachable):

| # | step (mouse) | expect |
|---|---|---|
| 1 | Export…; Export (SVG); Done; Export…; Export again | the failed row "scene-1.svg is already in <folder>. Choose another folder." with Try Again (`flare.export.tryAgain`); the first file's bytes are unchanged |
| 2 | click Try Again | the sheet is editing again, SVG still chosen; click Cancel (`flare.export.cancel`, the editing sheet's close): the sheet is gone |
| 3 | relaunch with `-FlareExportTo` on a folder the test made read-only; Export…; Export | "Flare can't write to Locked." with Try Again; the folder stays empty |
| 4 | relaunch on a fresh folder; Export…; PNG sequence; scale 2x; Export; click Cancel within the run | the sheet is gone (the run returned to idle) and the folder holds no PNG |

**MJ-FX0 · `FlareIntentTests` and `FlareExportTests.shape`** (Linux, FX-1
and FX-2): every new intent case has an area, an identifier and a title; the
stubs return their fake values and `ExportState.idle` compiles as
`ExportRun<ExportOptions>`.

**MJ-FX1 · `FlareExportTests.walk` and `FlareExportOptionsTests`** (Linux, FX-4 and FX-11): on `.fake()` with
`showcase`: `openExport()` is true and the run is `.editing` of SVG frame,
scene-1, 0...47, step 1, 1x, opaque; `setExportFormat(.pngSequence)`,
`setExportFrames(0...12)`, `setExportStep(2)`: `exportFileCount` 7,
`exportProblem` nil; `startExport()` is true and the run is `.running(done:
0, total: 7)`; `exportProgressed(0.5)` then `(0.2)` reads `done` 3 both
times; `endExport(.success(names))` reads `.finished` with the 7 names and
`exportSummary` "Exported 7 files."; `dismissExport()` reads idle.

**MJ-FX2 · `LiveExportTests` and `FlareExportRoundTripTests`** (Linux, FX-6
and FX-8): the adapter over `LiveStage` exports `bounce` 0...48 step 2 as 25
PNGs through `FakeRasterizer`, a cancelled run throws `CancellationError`
with no files, SVG and Lottie bytes equal `FakeExport`'s for the same
document, and the round trip holds for `bounce`, `showcase` and `character`.

## Screens and states

| screen | state | snapshot PNG |
|---|---|---|
| Export sheet | `showcase`, SVG frame: the format chips, the Frame row, scale chips, Transparent background, the three warnings, Export enabled | `flare-export-svg-light.png`, `flare-export-svg-dark.png` (FX-5) |
| Export sheet | PNG sequence: From, To, Step, scale 1x/2x, Transparent, "7 files" | `flare-export-png-dark.png` (FX-5) |
| Export sheet | To set to 90: Export disabled with "Frames 0–90 aren't all in the scene." under the row | `flare-export-problem-dark.png` (FX-5) |
| Export sheet | running: the progress bar at 3 of 7 with Cancel; the options rows disabled | `flare-export-running-dark.png` (FX-5) |
| Export sheet | finished: "Exported 7 files.", Reveal in Finder, Done | `flare-export-finished-dark.png` (FX-5) |
| Export sheet | failed: "scene-1.svg is already in Exports. Choose another folder.", Try Again, Done | `flare-export-failed-dark.png` (FX-5) |
| Folder panel | no `-FlareExportTo`: the system open panel choosing a folder | journey shots only (system panel; journeys always pass the flag) |

The sheet is SuiteUI's `ExportSheet` as EK-30 ships it; Flare's rows go in
its options slot. Snapshots render the adapter's content view on the fakes.

## Contract slice

Model (Linux, tested). FX-1 and FX-2 declare; FX-4 fills the bodies without
changing a signature.

```swift
// Sources/FlareModel/FlareIntent.swift (FX-1)
public enum Export: Sendable, Equatable {
    case showSheet, setFormat(ExportFormat), setFrames(from: Int, to: Int), setStep(Int), setScale(Double),
         setTransparent(Bool), start, cancel, dismiss, tryAgain, reveal
}
// identifiers: flare.export.<name>; setFormat's name is "format.<rawValue>" (flare.export.format.lottie), so the
// three chips register apart in suite.controls; every other case's name is its case name.
// FlareIntent+Titles.swift: .export(.showSheet) stays "Export…"; the sheet's own controls take their row titles.

// Sources/FlareModel/FlareWorkspaceState.swift (FX-2)
import SuiteKernel
/// The export sheet's run on the kernel: idle, editing(options), running(options, done:, total:),
/// finished(options, written file names), failed(options, sentence). Replaces the app-local enum.
public typealias ExportState = ExportRun<ExportOptions>

// Sources/FlareModel/FlareExport.swift (FX-2 stubs, FX-11 bodies: the readouts, the setters, the sentences)
// Sources/FlareModel/FlareExport+Kernel.swift (FX-2 stubs, FX-4 bodies: the transitions over ExportRun)
/// What the app's writer refused; the Model turns each into the sheet's sentence.
public enum ExportWriteRefusal: Error, Equatable, Sendable {
    case alreadyThere(name: String, folder: String)   // "scene-1.svg is already in Exports. Choose another folder."
    case cantWrite(folder: String)                     // "Flare can't write to Locked."
}
extension FlareWorkspace {
    public func exportOptions(_ format: ExportFormat) -> ExportOptions?   // kept: selected scene, whole range, 1x, opaque
    public func exportWarnings(_ options: ExportOptions) -> [String]      // kept: services.export.warnings
    public var exportingOptions: ExportOptions? { get }   // the run's payload in every state but idle
    public var exportProblem: String? { get }    // nil when Export can start; "Frames 0–90 aren't all in the scene.",
                                                 // "The frame step must be 1 or more.", "Scale must be 1x or 2x.",
                                                 // "Open or create an animation first."
    public var exportFileCount: Int { get }      // 1 for SVG and Lottie; PNGExportPlan.plan(...).count; 0 with a problem
    public var exportSummary: String? { get }    // finished: "Exported scene-1.svg." or "Exported 7 files."; else nil
    @discardableResult public mutating func openExport() -> Bool          // idle → editing(exportOptions(.svgFrame)); false otherwise
    public mutating func setExportFormat(_ format: ExportFormat)           // editing only; keeps the other options
    public mutating func setExportFrames(_ frames: ClosedRange<Int>)       // editing only; stored as given, judged by exportProblem
    public mutating func setExportStep(_ step: Int)
    public mutating func setExportScale(_ scale: Double)
    public mutating func setExportTransparent(_ on: Bool)
    @discardableResult public mutating func startExport() -> Bool         // editing with no problem → running(done: 0, total: exportFileCount)
    public mutating func exportProgressed(_ fraction: Double)              // kept signature: done = floor(fraction × total); the kernel clamps, never back
    public mutating func endExport(_ outcome: Result<[String], any Error>) // finished(names); CancellationError → idle; else failed(exportMessage)
    public mutating func retryExport()                                     // failed → editing(same options)
    public mutating func dismissExport()                                   // editing, finished or failed → idle; running stays
    static func exportMessage(_ error: any Error) -> String   // kept; adds the two ExportWriteRefusal sentences
}
/// The sentence handed to the kernel's `end(.failure(_))`, so `failed(_, String)` carries it: `description` is the sentence.
/// How EK-22 turns the error into its string isn't in the kernel contract (issue to file); if it isn't the
/// description, `exportFailure: String?` maps the kernel's string back to the sentence.
struct ExportRefusal: Error, CustomStringConvertible, Sendable { let description: String }
// Dropped: beginExport(), export(_:rasterizer:) (the mutating async whole run; the window orchestrates, see Pseudocode).

// Sources/FlareModel/Live/LiveExportAdapter.swift (FX-6): Exporting over FlareCore's exporters and a stage.
public struct LiveExportAdapter: Exporting {
    public init(stage: any StageRendering, frameDelay: Duration = .zero)
    public func warnings(_ document: Document, options: ExportOptions) -> [String]          // ExportScan.warnings
    public func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                       progress: @Sendable (Double) -> Void) async throws -> ExportResult   // text removed first; cancel between frames
}
// Fakes/FakeExport.swift (FX-8): FakeExport keeps init(unavailable:frameDelay:) and forwards to
// LiveExportAdapter(stage: FakeStage(), frameDelay:); `unavailable` still throws NotBuilt and scans nothing.
```

App (macOS). `Sources/FlareApp/FlareExportSheetAdapter.swift` (FX-3): a
`ViewModifier` on the window that presents SuiteUI's `ExportSheet` while
`model.exportState != .idle` (a `Binding` whose get reads the Model and
whose set performs `.export(.dismiss)`, or `.export(.cancel)` while running;
the view reads and calls, never assigns), with Flare's `FormatChoice` list
("SVG frame", "Lottie", "PNG sequence"), its options slot (Frame or From, To
and Step `StudioScrubRow`s, scale `ChoiceChips` 1x and 2x, a Transparent
background toggle row, the warnings list, the file count), the run readouts
(`exportingOptions`, `exportState`, `exportProblem`, `exportSummary`) and
the actions Export, Cancel, Try Again, Reveal in Finder and Done, each a
`perform(.export(...))`. `Sources/FlareApp/StageRasterizer.swift` (FX-7):
`struct StageRasterizer: FrameRasterizing`, a CoreGraphics RGBA8 context of
the list's size times `scale`, the background filled unless `transparent`,
each item through `StagePath.cgPath` and `StagePath.cgColor`, encoded as PNG
through ImageIO. `FlareWindow+Export.swift` (FX-3): `performExport`,
`exportHelp` and the writer.

## Pseudocode

```
performExport:                                              # FX-3, FlareWindow+Export.swift
  .showSheet       -> model.openExport()
  .setFormat(f)    -> model.setExportFormat(f) ; .setFrames/.setStep/.setScale/.setTransparent likewise
  .start           -> guard model.startExport() ; let options = model.exportingOptions, document = model.document
                      exportTask = Task {
                        do {
                          let folder = try await exportFolder()          # -FlareExportTo, else FlareFileDialogs.chooseFolder()
                          let result = try await model.services.export.export(document, options, rasterizer) { f in
                              Task { @MainActor in model.exportProgressed(f) } }
                          try Task.checkCancellation()
                          let names = try await write(result.files, into: folder)   # off the main actor
                          model.endExport(.success(names)); exportedFolder = folder
                        } catch { model.endExport(.failure(error)) } }      # CancellationError -> idle, nothing written
  .cancel          -> exportTask?.cancel() while running ; model.dismissExport() while editing
  .dismiss         -> model.dismissExport()
  .tryAgain        -> model.retryExport()
  .reveal          -> NSWorkspace.shared.activateFileViewerSelecting([exportedFolder/first name])
exportHelp:
  .showSheet -> document == nil ? "Open or create an animation first." : nil
  .start     -> model.exportProblem ; .reveal -> finished ? nil : "Export first." ; the rest nil
rasterizer = model.services.isPreview ? FakeRasterizer() : StageRasterizer()     # FX-3 (so FX-3 depends on FX-7)

write(files, into folder):                                  # never overwrites, all or nothing
  if let taken = files.first(where: { exists(folder/name) }) { throw ExportWriteRefusal.alreadyThere(name, folder.lastPathComponent) }
  var written = [] ; for file in files { do { try file.data.write(to: folder/name, options: .atomic); written.append(name) }
                                         catch { written.forEach(remove) ; throw ExportWriteRefusal.cantWrite(folder.lastPathComponent) } }
  return written

FlareWorkspace, over run: ExportRun<ExportOptions> (FX-4 the transitions in +Kernel.swift, FX-11 the readouts):
  openExport        : guard document != nil, let o = exportOptions(.svgFrame) ; return run.begin(o)
  exportProblem     : no document -> "Open or create an animation first."
                      frames outside 0...durationFrames-1 -> "Frames a–b aren't all in the scene."
                      step < 1 -> "The frame step must be 1 or more." ; scale not 1 or 2 -> "Scale must be 1x or 2x."
  exportFileCount   : problem != nil -> 0 ; svgFrame, lottie -> 1 ; pngSequence -> PNGExportPlan.plan(...).count
  startExport       : guard exportProblem == nil ; run.start(total: exportFileCount)
  exportProgressed(f): guard case .running(_, done: _, total: let total) ; run.progressed(done: Int((f.clamped(0...1) * Double(total)).rounded(.down)))
  endExport(outcome): .success(names) -> run.end(.success(names)) ; .failure(CancellationError) -> run.end(.failure(CancellationError()))
                      .failure(e) -> run.end(.failure(ExportRefusal(exportMessage(e))))   # ExportRefusal: CustomStringConvertible, so failed(_, sentence)
  exportSummary     : .finished(_, [one]) -> "Exported \(one)." ; .finished(_, n) -> "Exported \(n.count) files."
  retryExport       : guard case .failed(let o, _) ; run = .idle ; run.begin(o)

LiveExportAdapter.export (FX-6):                            # FakeExport's switch, over `stage`
  clean = ExportScan.withoutText(document) ; scene = clean.scenes[sceneID] else throw CommandError.sceneNotFound
  .svgFrame   : transparent -> scene.background.a = 0 ; SVGExporter.export(scene, frame: frames.lowerBound, symbols) -> "<id>.svg"
  .lottie     : LottieExporter.export(scene, symbols) -> "<id>.json"
  .pngSequence: for frame in PNGExportPlan.plan(...) { checkCancellation ; stage.drawList(clean, sceneID, frame.frame, editing: nil)
                  -> rasterizer.png(list, scale, transparent) as frame.fileName ; progress(i+1 / count) ; sleep(frameDelay) }
  checkCancellation ; progress(1) for one-file formats ; ExportResult(files, ExportScan.warnings(document, options))
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: flare-export`, `Slice:
<slice>`, `Fast-Check: pass`, `Head:`, and for FX-1, FX-4, FX-6 and FX-11 the
`Mutate:` score. FX-10 also carries `feature-done`. Builders of FX-3, FX-5 and FX-7
read `docs/engineering/swiftui-rules.md`; FX-7 checks CoreGraphics and
ImageIO against the docs MCP and lists any `Unverified API:` line.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FX-1 | #354 (part) | The export intents: every `FlareIntent.Export` case with its name, identifier and title (`format.<rawValue>` for the chips); the representative-value list and both intent tests grow; a plan | `Sources/FlareModel/FlareIntent.swift`, `Sources/FlareModel/FlareIntent+Titles.swift`, `Tests/FlareModelTests/FlareIntentTests.swift`, `Tests/FlareModelTests/FlareIntentTitleTests.swift`, `Tests/mutations/FlareModel.FlareIntent.json` | – | ~120, 5 |
| FX-2 | #354 (part) | Checks first and the stubs: `ExportState = ExportRun<ExportOptions>`, `ExportWriteRefusal`, every signature above as a stub (the readouts return nil, 0 or false; the mutators change nothing); `FlareExportTests` (the transitions, "waits on FX-4"), `FlareExportOptionsTests` (the readouts and setters, "waits on FX-11") and `FlareExportRoundTripTests` ("waits on FX-8") written from MJ-FX1 and MJ-FX2, disabled; `ExportScanTests`' three run tests rewritten onto the new API and disabled "waits on FX-4" | `Sources/FlareModel/FlareWorkspaceState.swift`, `Sources/FlareModel/FlareExport.swift`, `Sources/FlareModel/FlareExport+Kernel.swift`, `Tests/FlareModelTests/FlareExportTests.swift`, `Tests/FlareModelTests/FlareExportOptionsTests.swift`, `Tests/FlareModelTests/FlareExportRoundTripTests.swift`, `Tests/FlareModelTests/ExportScanTests.swift` | editor-kernel EK-a (cross-line) | ~340, 7 |
| FX-3 | #354 (closes), #355 (part) | The sheet on the fakes, reachable from the toolbar's Export… and File > Export…: `FlareExportSheetAdapter` over SuiteUI's `ExportSheet` with Flare's rows and readouts; `performExport`, `exportHelp` and the writer (never overwrites, all or nothing, Cancel leaves nothing); `exportTask` and the modifier line in `FlareWindow`; `FlareFileDialogs.chooseFolder()`; the window picks `StageRasterizer` off the fakes and `FakeRasterizer` on them; J22 and J23 written and running on `-FlareFixture` | `Sources/FlareApp/FlareExportSheetAdapter.swift`, `Sources/FlareApp/FlareWindow+Export.swift`, `Sources/FlareApp/FlareWindow.swift`, `Sources/FlareApp/FlareFilePanels.swift`, `UITests/FlareJourneyTests+Export.swift`, `UITests/FlareJourneyTests+ExportErrors.swift` | FX-1, FX-2, FX-7, editor-kernel EK-chrome (cross-line) | ~390, 6 |
| FX-4 | #355 (part) | The run's transitions over `ExportRun` in `FlareExport+Kernel.swift`: `openExport`, `startExport`, `exportProgressed`, `endExport`, `retryExport`, `dismissExport`, `exportingOptions`; its plan; turns on `FlareExportTests` and the `ExportScanTests` run tests | `Sources/FlareModel/FlareExport+Kernel.swift`, `Tests/mutations/FlareModel.FlareExport+Kernel.json`, `Tests/FlareModelTests/FlareExportTests.swift`, `Tests/FlareModelTests/ExportScanTests.swift` | FX-2, editor-kernel EK-run (cross-line) | ~200, 4 |
| FX-11 | #355 (part) | The readouts and setters in `FlareExport.swift`: the five option setters, `exportProblem`, `exportFileCount`, `exportSummary`, `exportMessage` with the two refusal sentences; its plan; turns on `FlareExportOptionsTests` | `Sources/FlareModel/FlareExport.swift`, `Tests/mutations/FlareModel.FlareExport.json`, `Tests/FlareModelTests/FlareExportOptionsTests.swift` | FX-2 | ~180, 3 |
| FX-5 | #355 (closes) | The six sheet snapshots; the render budget test; J0's toolbar row reads "Open or create an animation first." for Export… | `Tests/AppSnapshotTests/FlareExportSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareExportTests.swift`, `UITests/FlareJourneyTests.swift` | FX-3, inspector-timeline (the feature; it owns `FlareJourneyTests.swift`) | ~220, 3 |
| FX-6 | #374 (part) | `LiveExportAdapter` (FlareCore's exporters over a `StageRendering`, text removed first, cancel between frames, the scan's warnings) with `LiveExportTests` and its plan; the flare-model C4 description names it | `Sources/FlareModel/Live/LiveExportAdapter.swift`, `Tests/FlareModelTests/LiveExportTests.swift`, `Tests/mutations/FlareModel.LiveExportAdapter.json`, `docs/c4/parts/creative-apps/flare-model/flare-model-sources.json` | – | ~260, 4 |
| FX-7 | #374 (part) | `StageRasterizer` on `StagePath` with `RasterizerTests` (2x is twice the pixel size; a transparent corner has alpha 0; `bounce` frame 0 at 1x matches the stage golden within QB-V2's tolerance); the flare-app C4 description names the rasterizer and the sheet adapter | `Sources/FlareApp/StageRasterizer.swift`, `Tests/AppSnapshotTests/RasterizerTests.swift`, `docs/c4/parts/creative-apps/flare-app/flare-app-sources.json` | – | ~200, 3 |
| FX-8 | #374 (part) | `FakeExport` forwards to `LiveExportAdapter(stage: FakeStage(), frameDelay:)` and keeps its init; turns on `FlareExportRoundTripTests` on both adapters (`FoundationXML` on Linux) | `Sources/FlareModel/Fakes/FakeExport.swift`, `Tests/FlareModelTests/FlareExportRoundTripTests.swift` | FX-2, FX-6 | ~160, 2 |
| FX-9 | #374 (closes) | Integrate: `.built` holds `LiveExportAdapter(stage: LiveStage())` and `FlareServicesBuiltTests` counts `export` among the built members; J22 on `-FlareSample showcase` with the IHDR width check, J23's steps 1 to 3 also on `-FlareSample bounce` | `Sources/FlareModel/FlareServicesBuilt.swift`, `Tests/FlareModelTests/FlareServicesBuiltTests.swift`, `UITests/FlareJourneyTests+Export.swift`, `UITests/FlareJourneyTests+ExportErrors.swift` | FX-3, FX-4, FX-6, FX-11 | ~90, 4 |
| FX-10 | – | Shared prose: flare.md's Export sheet row (3.3) and J23 row (4) read the refusal, not "Replace existing files?"; waves.in.md drops export from "Not in a packet yet" and adds the chain; `status: built`; this packet's status line; `feature-done` | `docs/blueprints/flare.md`, `docs/blueprints/flare/waves.in.md`, `docs/blueprints/flare/features/flare-export.wave.json`, `docs/blueprints/flare/features/flare-export.md` | FX-9 | ~60, 4; `feature-done` |

`FlareWindow.swift`, `FlareWindow+Export.swift`, `FlareFilePanels.swift`,
`FlareServicesBuilt.swift`, `FlareIntent.swift`, `FlareIntent+Titles.swift`,
their tests, `flare.md` and the two C4 parts are `draw-key-save`'s (built;
`depends`). `UITests/FlareJourneyTests.swift` is `inspector-timeline`'s
(wave 4), so FX-5 waits on that feature. `FlareExport.swift`,
`FlareWorkspaceState.swift`, `ExportScanTests.swift` and
`FlareModel.FlareExport.json` are also adopt-kernel-export's (cross-line, the
Hand-offs note). No task edits `FlareNewSheet.swift` (layers-files):
the sheet is presented from the Model's run, not from `FlarePresentation`.
No two tasks of one wave own a file; FX-2 shares `FlareExport.swift` with
FX-11 and `FlareExport+Kernel.swift` with FX-4 across a wait, as do FX-3 and FX-9 on the journey files. FX-3 sits at the
size cap with both journey files inside it; the lead may split them off
into a test-first task that merges skipped ("waits on FX-3"), which rule 13
allows (before or with).

## Build waves

- Wave 1: FX-1, FX-2, FX-6, FX-7. Independent in this wave: all four (FX-2
  starts when editor-kernel's EK-a has merged).
- Wave 2: FX-3, FX-4, FX-8, FX-11. Independent in this wave: all four (FX-3
  when EK-chrome has merged, FX-4 when EK-run has).
- Wave 3: FX-5. Independent in this wave: FX-5 (alone; it starts when
  inspector-timeline has merged).
- Wave 4: FX-9. Independent in this wave: FX-9 (alone).
- Wave 5: FX-10 (shared prose and status, final).

Longest chain: FX-2 → FX-3 → FX-5 → FX-9 → FX-10 (5). Chain of 5: FX-3
compiles against FX-2's stubs, FX-5 snapshots the sheet FX-3 adds, FX-9
swaps the fakes for live once every slice is in, and FX-10 is the one
shared-prose task (rule a).

## Acceptance test per task

Checks first (rule 13): the Model tests merge in FX-2 disabled by name and
turn on in FX-4 and FX-8; the journeys merge with FX-3, the first UI task,
and run on the fakes at once. Mutations (rule 14) go in the plan the task
owns and run with `scripts/mutate --plan FlareModel.<File>`.

| id | test | fails when | mutations |
|---|---|---|---|
| FX-1 | `FlareIntentTests` (the count and every case's area and identifier), `FlareIntentTitleTests` | a case has no identifier; two chips share one; "Export…" lost | `.setFormat`'s name drops the raw value (two chips read `flare.export.setFormat`) → `FlareIntentTests.identifiersAreUnique`; `.export(.start)`'s area reads `.file` → `FlareIntentTests.everyCaseKeepsItsArea` |
| FX-2 | `FlareExportTests.shape`; `FlareExportTests.walk`, `FlareExportOptionsTests`, `FlareExportRoundTripTests` and the `ExportScanTests` run tests (disabled) | a stub traps, `ExportState.idle` doesn't compile, or `FlareWorkspaceState.swift` still declares the old enum | – (declarations) |
| FX-3 | J22 steps 1 to 6 and J23 steps 1 to 4 on `-FlareFixture`; `FlareToolsTests` and J0 stay green | Export… is dead with a document open; a file is overwritten; Cancel leaves a PNG; a failure is silent | – (UI; the writer is proven by J23) |
| FX-4 | `FlareExportTests` (MJ-FX1), the `ExportScanTests` run tests, `scripts/mutate --plan FlareModel.FlareExport+Kernel` | see mutations | `startExport` ignores `exportProblem` → `FlareExportTests.startRefusesABadRange`; `dismissExport` while running goes idle → `.dismissKeepsARunningRun`; a `CancellationError` ends `.failed` → `.cancelReturnsToIdle`; `exportProgressed` maps the fraction with `ceil` → `.progressFloorsTheFraction`; `retryExport` from `.finished` reopens → `.retryOnlyFromFailed` |
| FX-11 | `FlareExportOptionsTests` (MJ-FX1), `scripts/mutate --plan FlareModel.FlareExport` | see mutations | `exportFileCount` for PNG ignores `step` → `FlareExportOptionsTests.pngCountFollowsStep`; `exportProblem` lets `upperBound == durationFrames` through (`<=` for `<`) → `.problemNamesFramesPastTheEnd`; `exportSummary` says "1 files" → `.summaryNamesTheOneFile`; `setExportFormat` resets the frames → `.formatKeepsTheOtherOptions` |
| FX-5 | `FlareExportSnapshots` (six PNGs); `RenderBudgetFlareExportTests.bodies`; J0's toolbar row | a snapshot missing; bodies over budget; J0 reads the old reason | – (UI) |
| FX-6 | `LiveExportTests` (MJ-FX2 half), `scripts/mutate --plan FlareModel.LiveExportAdapter` | see mutations | `Task.checkCancellation()` dropped between frames → `LiveExportTests.cancelLeavesNoFiles`; `withoutText` skipped → `.textNeverReachesTheExporters` (the exporters throw on text); SVG ignores `transparentBackground` → `.svgTransparentDropsTheBackground`; PNG names use the index, not `frame.fileName` → `.pngNamesFollowThePlan` |
| FX-7 | `RasterizerTests` (macOS) | 2x isn't twice the size; a transparent corner has alpha; frame 0 differs from the golden past QB-V2 | – (platform) |
| FX-8 | `FlareExportRoundTripTests` (byte identity after save and reopen, and twice in a row; the SVG parses with the scene's width and height; the Lottie's `fr`, `w`, `h`, `op`), `ExportScanTests` unchanged | a byte differs; `FakeExport(unavailable:)` no longer throws its reason | – (delegation; the adapter's plan covers the behaviour) |
| FX-9 | J22 on `-FlareSample showcase` (IHDR width 550), J23 steps 1 to 3 on `-FlareSample bounce`; `FlareServicesBuiltTests` counts `export` as built | the live export writes nothing or writes 1 × 1 PNGs | – (wiring) |
| FX-10 | `scripts/waves render --dry-run`; the blueprint rows read the refusal | status not `built`; a row still says Replace | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Never a silent drop | every warning the scan names is on the sheet before Export, in every format | J22 steps 1 and 3; `ExportScanTests` stay green |
| Never overwrite | a second export to the same folder refuses with the sentence and leaves the first file's bytes alone | J23 step 1 |
| Nothing left behind | Cancel or a failed write leaves no file of this run in the folder | J23 steps 3 and 4; `LiveExportTests.cancelLeavesNoFiles` |
| Round trip | SVG and Lottie bytes identical after save and reopen, and twice in a row | `FlareExportRoundTripTests` (FX-8) |
| QB-V4 PNG equals the stage | `StageRasterizer` of `bounce` frame 0 at 1x matches the stage golden within QB-V2's tolerance | `RasterizerTests` (FX-7) |
| QB-L8 export budget | SVG frame < 1 s, Lottie of 300 frames < 10 s, 48 PNG frames at 1080p < 10 s on the adapter with `frameDelay` zero | `ExportScanTests.svgFrameLottieAndPNGSequenceStayInsideQBL8` (kept, now through the adapter) |
| render: export sheet To row | 60 steps ≤ 60 window bodies (one per edit); the sheet opening and closing ≤ 2 bodies each; p95 ≤ 8.3 ms (reported, Mac finisher) | `RenderBudgetFlareExportTests.bodies`, `.timing` (FX-5) |
| render: progress | one body per frame that moves `done`; an equal fraction leaves the run identical, so nothing redraws | `FlareExportTests.progressIsOnePerFrame` (FX-4) |
| QB-F1 no dead controls | Export… disabled with its reason without a document; Export disabled with `exportProblem`; Reveal only when finished | J0 (FX-5), `flare-export-problem-dark.png` |
| QB-F2 errors in place | the failed row and Try Again in the sheet, never an alert | J23 steps 1 and 3 |
| Keyboard parity | ⇧⌘E opens, Return starts, Escape cancels a run or closes the sheet | J22 step 1 (the shortcut once), J23 step 2 |
| Mouse-only | every sheet control enters and leaves by click; hover and pressed states from SuiteUI | the `mouse` lens on FX-u's review |
| App audit | no Flare count over `UITests/audit-baseline.json` | the macOS run's `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17): its tasks merged, its Linux walk green on the
newest dev run containing its last PR, every mutation in its plans caught,
no open `finding`; then `Belt-Slice-Done: <slice>`. For FX-u also the feel
gate (`mouse` and `taste` lenses against `StudioScrubRow` and `ChoiceChips`)
and its `Mac-Finish:` line, with `RasterizerTests` and the time budgets on a
release build. J22 and J23 green on the Flare-scoped run that contains FX-9,
audit zero new, then `Belt-Contact-Sheet: <run link>` on the feature issue
once FX-z is done.
