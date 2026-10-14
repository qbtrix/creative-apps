# Feature packet: export-preview

**Feature:** export on preview data. Pick SVG frame, Lottie or a PNG
sequence, see every warning for what the export will leave out, export or
cancel, and get the files or the reason it failed, all on the fake services
and the `showcase` fixture.
**Line:** `line:flare` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/export-preview`

**Covers:** #324 (LM-0c3). It closes with the last task PR (EP-6); the
earlier PRs say "Part of #324".

**Depends on:** the mac-platform feature (wave 1), only because both edit
`docs/c4/model.json`; nothing else. #322 (LM-0c1) has merged. No creative-core
issue is needed: the fake writes its own minimal SVG and Lottie (below).

Why `p1`: the `showcase` fixture is what J27's "Text not shown (1)" pill
(F17b #392) and J22 run on, and the warnings scan is shared with the live
export (LM-13b #367), so "never a silent drop" is decided once, here.
Blueprint sections: 3.3 (Export sheet), 4 (J22, J23, fixtures), 6.2
(`Exporting`, `FrameRasterizing`), 7.1 (LM-0c3).

## Journey steps

J22 and J23 are the export journeys; their sheet is F15a (#354) and F15b
(#355), not built yet. This feature makes their Model half true, and
`Tests/FlareModelTests/ExportJourneyTests.swift` (EP-6) walks the same steps
through `FlareWorkspace` on `.fake`:

1. Load `showcase`. `exportHelp` is nil (with no document it says why).
2. Choose SVG frame 0: the warnings list shows "Text isn't exported yet (1
   layer).", "Symbol animation exports as its first frame (1 instance)." and
   "Interactions aren't exported (1 machine)."
3. Choose Lottie: the same three plus "Background color isn't part of
   Lottie."
4. Export a PNG sequence of `bounce`, frames 0–12, step 2: progress rises to
   1, the state is `.finished` with 7 PNG files.
5. Start a 2x export of 0–47 and cancel: the state returns to `.idle` and no
   files are kept.
6. A rasterizer that throws ends in `.failed` with its message; Try Again
   (a second `beginExport`) runs again.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Export sheet (section 3.3) | no document: `exportHelp` = "Open or create an animation to export." and export does nothing; a document with nothing to warn about: an empty warnings list | `exportState = .failed(message)` with the rasterizer's or the exporter's reason, plain text, never a debug dump | `exportState = .running(progress:)`, progress 0...1 and never falling; Cancel returns to `.idle` |
| Warnings list | empty for `bounce` | – | – (the scan is synchronous and cheap) |

## Contract slice

Unchanged contracts from `Sources/FlareModel/Contracts/ExportContracts.swift`:
`Exporting.warnings(_:options:)`, `Exporting.export(_:options:rasterizer:progress:)`
(async, throws `CancellationError` on cancel, writes nothing) and
`FrameRasterizing.png(_:scale:transparent:)`. `ExportState` is in
`FlareWorkspaceState.swift` and is not edited. New:

```swift
// Sources/FlareModel/ExportScan.swift: shared by FakeExport and LiveExport (LM-13b)
public enum ExportScan {
    public static func warnings(_ document: Document, options: ExportOptions) -> [String]
}
// Sources/FlareModel/Fakes/FakeRasterizer.swift
public struct FakeRasterizer: FrameRasterizing { public init() }
// Sources/FlareModel/Fakes/FakeExport.swift
public struct FakeExport: Exporting { public init() }
// Sources/FlareModel/FlareExport.swift (extension FlareWorkspace)
public var exportHelp: String? { get }
public func exportWarnings(_ options: ExportOptions) -> [String]
public mutating func beginExport()
public mutating func exportProgressed(_ fraction: Double)
public mutating func finishExport(_ result: Result<ExportResult, Error>)   // CancellationError -> .idle
public mutating func dismissExport()
// Sources/FlareModel/Fakes/Fixtures/ShowcaseFixture.swift
extension FlareFixtures { public static let showcase: Document }
```

## Pseudocode

```
ExportScan.warnings(doc, options):                 # EP-2; fixed order, one line per kind
  scene = doc.scene(options.sceneID) else []
  out = []
  t = layers(scene) with texts nonEmpty            -> "Text isn't exported yet (n layer|layers)."
  i = instances(scene) whose symbol is animated       -> "Symbol animation exports as its first frame (n instance|instances)."
      animated(symbol) = some layer has a track with 2+ keys, or holds an instance of an animated symbol
                         (recursive, each symbol visited once, so a cycle can't loop)
  m = doc.stateMachines.count                      -> "Interactions aren't exported (n machine|machines)."
  if options.format == .lottie && !options.transparentBackground
                                                   -> "Background color isn't part of Lottie."
  return out (each line only when its count > 0)

FakeRasterizer.png(list, scale, transparent):      # EP-3
  guard scale.isFinite, scale > 0 else throw
  return fixed 1x1 PNG bytes (signature + IHDR + IDAT + IEND), the same every call

FakeExport.export(doc, options, rasterizer, progress):   # EP-4
  frames = stride(options.frames.lowerBound ... upperBound, by: max(step, 1))
  switch format:
    svgFrame: [ "<scene>.svg": "<svg xmlns=... width=W height=H viewBox=...></svg>" ]
    lottie:   [ "<scene>.json": {"v":"5.7.0","fr":fps,"w":W,"h":H,"ip":0,"op":frames,"layers":[]} ]
    png:      for (n, f) in frames: try Task.checkCancellation()
                 files += ("frame_%04d.png" % f, rasterizer.png(FakeStage().drawList(doc, scene, f, nil), ...))
                 progress(Double(n + 1) / count)
  return ExportResult(files, warnings: ExportScan.warnings(doc, options))

workspace (EP-5):
  exportHelp = document == nil ? "Open or create an animation to export." : nil
  beginExport: guard exportHelp == nil; exportState = .running(0)
  exportProgressed(p): if case .running(let old) = state, p.isFinite: .running(min(max(p, old), 1))
  finishExport(.success(r)) -> .finished(r); (.failure(CancellationError)) -> .idle
  finishExport(.failure(e)) -> .failed(text), text = (e as? LocalizedError)?.errorDescription
                               ?? "The export didn't finish. Try again."   # never "\(e)", which prints case names
                               # LocalizedError is in FoundationEssentials (checked with swift 6.3.3 on Linux)
```

The app runs `services.export.export(...)` in a task and reports back through
these calls; the Model never awaits.

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: export-preview`,
`Fast-Check: pass`, `Head:`. EP-6 also carries `feature-done`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| EP-1 | #324 (part) | Fixture `showcase`: `bounce` plus a layer named "Title" holding one text item whose string is "Title", one instance of an animated "Spin" symbol and one machine; registered in `FlareFixtures.all` | `Sources/FlareModel/Fakes/Fixtures/ShowcaseFixture.swift`, `Sources/FlareModel/Fakes/FlareFixtures.swift`, `Tests/FlareModelTests/ShowcaseFixtureTests.swift`, `docs/c4/model.json` | – |
| EP-2 | #324 (part) | `ExportScan.warnings`, one test per warning | `Sources/FlareModel/ExportScan.swift`, `Tests/FlareModelTests/ExportScanTests.swift`, `docs/c4/model.json` | EP-1 |
| EP-3 | #324 (part) | `FakeRasterizer` | `Sources/FlareModel/Fakes/FakeRasterizer.swift`, `Tests/FlareModelTests/FakeRasterizerTests.swift`, `docs/c4/model.json` | EP-2 |
| EP-4 | #324 (part) | `FakeExport`: the three formats, progress, cancellation, warnings from the scan | `Sources/FlareModel/Fakes/FakeExport.swift`, `Tests/FlareModelTests/FakeExportTests.swift`, `docs/c4/model.json` | EP-3 |
| EP-5 | #324 (part) | Workspace export state and `exportHelp`; `FlareServices.fake` holds `FakeExport()` | `Sources/FlareModel/FlareExport.swift`, `Sources/FlareModel/FlareServices.swift`, `Tests/FlareModelTests/ExportWorkspaceTests.swift`, `docs/c4/model.json` | EP-4 |
| EP-6 | #324 (closes) | The model journey test for J22 and J23 | `Tests/FlareModelTests/ExportJourneyTests.swift` | EP-5 |

Each of EP-1 to EP-5 adds something the `flare-model-sources` C4
description doesn't mention yet (the `showcase` fixture, the warnings scan,
`FakeRasterizer`, `FakeExport`, the workspace's export methods), so each
edits its own sentence there in the same PR. That puts `docs/c4/model.json`
in each task and makes EP-1 to EP-5 one chain. `ServicesTests.swift` needs
no edit: it checks only members that are still `NotBuilt` (#405), so the
`.fake.export` check goes in `ExportWorkspaceTests`. The issue body lists one
test file (`ExportScanTests.swift`); the packet splits the tests one file per
task (CLAUDE.md: prefer a new file), and the PRs say so.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| EP-1 | `ShowcaseFixtureTests`: `showcase` passes `FlareFormat.validate`; it holds Background, Ball, Shadow, a layer named "Title" with one text item whose string is "Title", one instance of symbol "Spin" whose layer has two or more rotation keys, and one state machine; `FlareFormat.encode` then `decode` gives the same document; `FlareFixtures.all` has the name "showcase" | the fixture is missing a part J22 or J27 needs, or does not round-trip |
| EP-2 | `ExportScanTests`: one test each for text (1 layer, then 2 layers), an animated instance (and a still one, which gives no warning), a machine, the Lottie background (and none for SVG, and none with `transparentBackground`); `bounce` gives `[]`; `showcase` with Lottie gives the four lines in order | a case is dropped, worded differently from J22, or the order changes |
| EP-3 | `FakeRasterizerTests`: bytes start with `89 50 4E 47 0D 0A 1A 0A`; two calls give equal bytes; scale 0, -1 and NaN throw | not a PNG, not stable, or a bad scale passes |
| EP-4 | `FakeExportTests`: `bounce` 0–12 step 2 gives 7 files named `frame_0000.png` … `frame_0012.png`; progress values rise and end at 1; a progress callback that cancels its own task on the first call (`withUnsafeCurrentTask { $0?.cancel() }`) makes the export throw `CancellationError` with progress never reaching 1; SVG starts `<svg`; Lottie parses with `JSONSerialization` and has `fr` 24; `result.warnings == ExportScan.warnings` | a frame count, name or format is wrong, or cancel returns files |
| EP-5 | `ExportWorkspaceTests`: with no document `exportHelp` is the sentence and `beginExport` leaves `.idle`; `.running` never decreases and clamps to 1; success gives `.finished`, `CancellationError` gives `.idle`, a `CommandError` gives `.failed("The export didn't finish. Try again.")` and an error with a `LocalizedError` description gives that text; `FlareServices.fake().export` warns on `showcase` | a state is skipped, progress goes back, or the fake is not wired |
| EP-6 | `ExportJourneyTests.testExportSVGLottieAndPNGSequence` and `.testExportFailuresAndCancel` walk steps 1–6 above | any step's state or warnings differ from the journey |

## Quality tests

| quality row | budget | test |
|---|---|---|
| never a silent drop (7.1, LM-0c3) | every content kind v1 can't write has a named warning | `ExportScanTests` (one per case) |
| QB-L8 on the fake | 48 PNG frames of `bounce` in < 10 s debug (the CI gate; the fake rasterizer is constant time, so this guards the loop) | `FakeExportTests.pngSequenceWithinBudget` |
| QB-F2 | a failure says where and why, in plain text | `ExportWorkspaceTests.failureIsPlainText` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (EP-6) is green, `FlareJourneyTests` included.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json` in
  that run.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  no Flare screen changes in this feature, and the comment says so.
