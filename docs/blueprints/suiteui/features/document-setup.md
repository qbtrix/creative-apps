# Feature packet: document-setup

**Feature:** start a document the way the job needs and change it later. One
SuiteUI sheet asks for width and height in px, pt, in, cm or mm, resolution,
orientation, background (white, transparent or a colour), offers the app's
presets (the suite-home `NewDocumentPreset` list) and "Clipboard" when an image
is on the pasteboard, and, for Halo and Flare, frame rate and duration. The
same sheet in settings mode edits an existing document: size with an anchor,
rate, duration, background. Photo's File > New always makes 1920×1080 white
(`PhotoWindow.swift`), Halo can't change a composition after it exists
(`HaloCommand` has new, duplicate, rename, delete, select; `CompositionSettings`
has no colour), and Halo's and Flare's own New sheets validate the same values
twice. Photo keeps Canvas Size and Image Size and Design keeps its page size
fields for later edits; they gain the shared New sheet only.
**Line:** `line:suiteui` · **Wave:** XK4 (`waves.md`, the beta gaps on the kernel track) · **Lead branch:** `lead/document-setup`
**Beta:** captain, 2026-10-21 (beta gaps C4). Labels `beta` and `p1` when filed.

**Covers:** `paw-workspace/docs/design/drafts/2026-10-21-beta-gaps-combined.md`
C4, evidence in `2026-10-21-gaps-photo.md` row 6 and `2026-10-21-gaps-halo.md`
B1 and the preset row; feature map row `suiteui/document-setup` (new); real
jobs RJ-P71 and RJ-H70 (new).

**Depends on:** editor-kernel, command-catalog, adopt-command-catalog (built).
**Waits:** frame-rates FR-a for `FrameRate` (DS-a), and FR-halo and FR-flare,
which edit the same Halo and Flare files first; clipboard-interop CB-s for the
clipboard size in Photo.

**Hand-offs** (cross-line; the lead checks each before the slice starts): the
Photo, Design, Halo and Flare catalog tails (photo/file-flow PF-m,
design/pen-paths DP-m, halo/file-flow HF-m, flare/pen-paths FP-m);
`PhotoWindow.swift` is shared with photo/file-flow; `HaloWindow+File.swift`
with halo/file-flow.

**Rule 20.** Document setup is one concept with two app copies:
`CompositionSettings`' validation with `NewCompositionSheet`, and
`NewDocumentSpec`'s with `FlareNewAnimationSheet`. Both validations become
`DocumentSetup.problems` through adapters (`HaloDocumentSetup+Kernel.swift`,
`FlareDocumentSetup+Kernel.swift`), and both sheets are deleted in DS-z with
`scripts/check-dup-views --update-baseline`: `Tests/canonical-ui-baseline.txt`
shrinks by its 6 lines for the two sheets. No file in
`Tests/canonical-baseline.txt` changes.

**AI-accessible first.** Each app's existing `file.new` (Halo:
`composition.new`) takes the `DocumentSetup` parameters, and two kernel specs
are new: `document.read-settings` and `document.set-settings` (with an
`anchor` for a size change). File > Document Settings… (Halo: Composition >
Composition Settings…) is their menu item.

**C4:** DS-1 adds `docs/c4/parts/creative-apps/suite-kernel/kernel-document.json`
(`Sources/SuiteKernel/Document/`).

Blueprint sections: suite.md 2 and 4 (kernel; home presets); photo.md (File >
New); halo.md (compositions); flare.md (new animation); design.md (new
document).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DS-a | The kernel declares DocumentSetup with units, resolution, background, rate and length, its per-field problems and the two document.* specs as stubs, with their tests written and disabled. | DS-1, DS-2 | MJ-DS | frame-rates:FR-a (the rate type) |
| DS-m | Sizes convert between units at the document's resolution to whole pixels, each field gets its own problem sentence against the app's limits, orientation swaps width and height, and a settings change plans the canvas offset for its anchor. | DS-3, DS-4 | MJ-DS | DS-a |
| DS-u | SuiteUI has one New Document sheet with presets, units, resolution, orientation, background, clipboard size and, for timed apps, rate and duration, and the same sheet edits settings later, reachable from the gallery on the fakes. | DS-5, DS-6 | SJ-DS | DS-a; frame-rates:FR-u (`FrameRateMenu`); shared files, after area-selection:AR-u (DS-5) |
| DS-photo | Photo's File > New opens the shared sheet with its presets and the clipboard size, and makes the image at that size, resolution and background. | DS-7, DS-8 | PJ-DS | DS-u, DS-m, clipboard-interop:CB-s (DS-8); photo/file-flow PF-m (cross-line); shared files, after adopt-suiteui-chrome:AC-zoom (DS-8), clipboard-interop:CB-photo (DS-8) |
| DS-design | Design's File > New opens the shared sheet with its frame presets and makes the first page at that size and background. | DS-9, DS-10 | DJ-DS | DS-u, DS-m (DS-10); design/pen-paths DP-m (cross-line); shared files, after clipboard-interop:CB-design (DS-10) |
| DS-halo | Halo makes compositions from the shared sheet and changes size, rate, duration and background colour later from Composition Settings, each change one undo step that keeps keys at their times. | DS-11, DS-12 | MJ-DS-halo, HJ-DS | DS-a (DS-11); DS-u, DS-m, frame-rates:FR-halo (DS-12); halo/file-flow HF-m (cross-line); shared files, after adopt-kernel-unsaved-prompt:UP-halo (DS-12), clipboard-interop:CB-halo (DS-12) |
| DS-flare | Flare makes animations from the shared sheet and edits size, rate, duration and background later from File > Document Settings, the same values its scene inspector shows. | DS-13, DS-14 | FJ-DS | DS-u, DS-m, frame-rates:FR-flare (DS-14); flare/pen-paths FP-m (cross-line); shared files, after clipboard-interop:CB-flare (DS-14) |
| DS-z | Halo's and Flare's own New sheets are deleted with the UI baseline shrunk, RJ-P71 and RJ-H70 pass, and the feature is built. | DS-15, DS-16 | MJ-DS, PJ-DS, HJ-DS, FJ-DS | DS-photo, DS-design, DS-halo, DS-flare |

**Slice size.** Each slice is one PR of 150 to 400 lines with its test commit first (lead.md rule 22). DS-z is smaller than that; the lead folds it into whichever adopt slice merges last, as rule 22 says for a same-feature change under 50 lines.

## Journey steps

- `MJ-DS`: `DocumentSetupTests` on Linux.
- `SJ-DS` (`SuiteDocumentSetupJourneyTests.testNewSheetPresetsAndUnits`, DS-6): open the gallery's New Document page, pick a preset, switch to inches, type 4 by 6 at 300, pick Transparent, press the orientation swap; the pixel readout says 1800 × 1200.
- `PJ-DS` (`PhotoDocumentsJourneyTests.testNewImageFromSheet`, DS-8): File > New, 4 × 6 in at 300 ppi, Transparent, Create; the canvas is 1200 × 1800 over the checkerboard.
- `DJ-DS` (`DesignPageJourneyTests.testNewDocumentFromPreset`, DS-10): File > New, Story 1080 × 1920; the page has that size.
- `MJ-DS-halo`: `HaloCompositionSettingsTests` on Linux.
- `HJ-DS` (`HaloSettingsJourneyTests.testCompositionSettingsLater`, DS-12): a 10 s composition; Composition > Composition Settings…, 15 s and navy, OK; the timeline is 15 s and the viewer navy; Undo once restores both.
- `FJ-DS` (`FlareNewSheetJourneys.testDocumentSettingsLater`, DS-14): File > Document Settings…, 1080 × 1080; the stage is square.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P71 | adds, closes with `suiteui/document-setup` | C | `Tests/RealJobs/photo/new-print-size/new-print-size.jobs.json`: `file.new {width: 4, height: 6, unit: in, resolution: 300, background: transparent}`, draw a 100 px red square by command, export PNG | none |
| RJ-H70 | adds, closes with `suiteui/document-setup` | C | `Tests/RealJobs/halo/longer-navy-comp/longer-navy-comp.jobs.json`: a 10 s 1920×1080 comp with a text layer keyed at 1 s and 9 s; `document.set-settings {duration: 15, background: "#1B2A4A"}`; render frame 400 | none |

RJ-P71. Trap: the image comes out 1920×1080 white, or 4×6 px. Assertion: the
PNG is 1200×1800, its corner pixel's alpha is 0, and its pHYs chunk says 300
ppi. Mutations: `SuiteKernel.DocumentSetup` `.pixelsRound`,
`PhotoModel.PhotoNewImage+Kernel` `.transparentBackground`. Written by DS-7,
disabled (`waits_on: DS-8`).

RJ-H70. Trap: there is no way to change the comp without rebuilding it, or the
keys stretch to the new length. Assertion: frame 400 (13.3 s at 30) renders
with a navy corner pixel within 2 levels, and the keys are still at frames 30
and 270. Mutation: `HaloModel.HaloDocumentSetup+Kernel` `.keysKeepTimes`.
Written by DS-11, disabled (`waits_on: DS-12`).

## Screens and states

- `suite-new-document-{light,dark}.png` and `suite-document-settings-{light,dark}.png` (DS-5).
- `photo-new-image-sheet-{light,dark}.png` (DS-8).
- `halo-composition-settings-{light,dark}.png` (DS-12).
- `flare-document-settings-{light,dark}.png` (DS-14).

## Contract slice

```swift
// Sources/SuiteKernel/Document/DocumentSetup.swift (DS-1 stubs, DS-3 bodies). Foundation and FlareCore only.
public enum LengthUnit: String, Hashable, Sendable, Codable, CaseIterable { case px, pt, inch = "in", cm, mm }
public enum DocumentBackground: Hashable, Sendable, Codable { case white, transparent, color(hex: String) }
public struct DocumentLimits: Hashable, Sendable { public var maxSide: Int; public var rates: [FrameRate]?; public var maxSeconds: Double? }
public enum SetupField: String, Hashable, Sendable { case width, height, resolution, frameRate, duration, background }
public struct SetupProblem: Hashable, Sendable { public var field: SetupField; public var text: String }
public struct DocumentSetup: Hashable, Sendable, Codable {
    public var width, height: Double; public var unit: LengthUnit; public var resolution: Double   // ppi, 72 default
    public var background: DocumentBackground
    public var frameRate: FrameRate?; public var durationSeconds: Double?                          // timed apps only
    public var pixelSize: (width: Int, height: Int) { get }                                         // rounded, at `resolution`
    public func converted(to unit: LengthUnit) -> DocumentSetup                                     // same pixels
    public func swapped() -> DocumentSetup
    public func problems(_ limits: DocumentLimits) -> [SetupProblem]
}
// Sources/SuiteKernel/Document/DocumentSetupCommands.swift (DS-1 stubs, DS-4 bodies).
public protocol DocumentSetupTarget: AnyObject {
    var documentSetup: DocumentSetup { get }; var documentLimits: DocumentLimits { get }
    func apply(_ setup: DocumentSetup, anchor: BoxAnchor) throws      // one undo step
}
public enum DocumentSetupCommands {
    public static let setupSchema: ParamSchema                        // what file.new and composition.new take
    public static let specs: [CommandSpec]                            // document.read-settings, document.set-settings {…, anchor}
}
```

## Pseudocode

- **Units:** px is pixels; pt is 1/72 in; in; cm = in / 2.54; mm = cm / 10.
  Pixels = round(value × resolution / perInch); px ignores resolution. A unit
  change converts the displayed numbers and keeps the pixels.
- **Clipboard preset:** the app passes the pasteboard image's pixel size when
  there is one (through clipboard-interop's bridge); the sheet lists it first.
- **Settings:** a size change places old content by `anchoredOrigin`; a
  duration change keeps every key's time in seconds and trims nothing (keys
  past the end stay, dimmed); a rate change keeps seconds, so a key at 1 s
  stays at 1 s.
- **Files:** Halo writes `background` only when it isn't white, so old files
  re-save byte for byte.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DS-1 | – | **Contract as stubs.** `DocumentSetup`, `LengthUnit`, `DocumentBackground`, `DocumentLimits`, `SetupProblem`, `DocumentSetupTarget` and `DocumentSetupCommands`; the C4 part | `Sources/SuiteKernel/Document/DocumentSetup.swift`, `Sources/SuiteKernel/Document/DocumentSetupCommands.swift`, `docs/c4/parts/creative-apps/suite-kernel/kernel-document.json` | – | ~200, 3 |
| DS-2 | – | `DocumentSetupTests` written, disabled (`waits on DS-3`, `waits on DS-4`) | `Tests/SuiteKernelTests/DocumentSetupTests.swift` | DS-1 | ~160, 1 |
| DS-3 | – | `DocumentSetup` bodies: unit conversion, pixel size, problems per field, swap, background hex; turns on the value half of `DocumentSetupTests` | `Sources/SuiteKernel/Document/DocumentSetup.swift`, `Tests/SuiteKernelTests/DocumentSetupTests.swift`, `Tests/mutations/SuiteKernel.DocumentSetup.json` | DS-1, DS-2 | ~200, 3 |
| DS-4 | – | `DocumentSetupCommands` run: read and set with an anchor through `TransformRules.anchoredOrigin`, one undo step; turns on the rest | `Sources/SuiteKernel/Document/DocumentSetupCommands.swift`, `Tests/mutations/SuiteKernel.DocumentSetupCommands.json` | DS-1, DS-2 | ~140, 2 |
| DS-5 | – | **Reachable first:** the gallery's New Document page on the fakes; `NewDocumentSheet` (`.new(presets:clipboard:)` and `.settings`), each field showing its `SetupProblem` beside it, Create off until there are none, every control naming its `document.*` or `file.new` parameter; `NewDocumentSheetTests` first | `Sources/SuiteUI/NewDocumentSheet.swift`, `Sources/SuiteUI/Gallery/GalleryNewDocument.swift`, `Sources/SuiteUI/SuiteGallery.swift`, `Tests/SuiteUITests/NewDocumentSheetTests.swift` | DS-1, DS-2 | ~290, 4 |
| DS-6 | – | The gallery journey and the render budget row | `UITests/SuiteJourneyTests+DocumentSetup.swift`, `Tests/AppSnapshotTests/RenderBudgetNewDocumentTests.swift` | DS-5 | ~110, 2 |
| DS-7 | – | **Photo, test first.** `PhotoNewImageTests`, disabled: `file.new` with `{width: 4, height: 6, unit: in, resolution: 300, background: transparent}` makes 1200×1800 with alpha 0 and stores 300 ppi; RJ-P71's job folder, disabled; the journey, skipped | `Tests/PhotoModelTests/PhotoNewImageTests.swift`, `UITests/PhotoJourneyTests+Documents.swift`, `Tests/RealJobs/photo/new-print-size/new-print-size.jobs.json` | – | ~150, 3 |
| DS-8 | – | `PhotoNewImage+Kernel.swift`; `PhotoWindow` presents `NewDocumentSheet`; `file.new` takes the setup; the resolution is saved in the document; turns on the tests | `Sources/PhotoModel/PhotoNewImage+Kernel.swift`, `Sources/PhotoApp/PhotoWindow.swift`, `Tests/PhotoModelTests/PhotoNewImageTests.swift`, `UITests/PhotoJourneyTests+Documents.swift`, `Tests/mutations/PhotoModel.PhotoNewImage+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/AfterGlowCLITests/Golden/apps/photo.list-commands.json` | DS-7, DS-5, DS-6, DS-3, DS-4 | ~230, 8 |
| DS-9 | – | **Design, test first.** `DesignNewDocumentTests`, disabled: a 1080×1920 preset makes one page of that size; transparent leaves the frame unfilled; the journey, skipped | `Tests/DesignModelTests/DesignNewDocumentTests.swift`, `UITests/DesignJourneyTests+Page.swift` | – | ~130, 2 |
| DS-10 | – | `DesignNewDocument+Kernel.swift`; File > New presents the sheet; `file.new` takes the setup; turns on the tests | `Sources/DesignModel/DesignNewDocument+Kernel.swift`, `Sources/DesignApp/DesignCommands.swift`, `Tests/DesignModelTests/DesignNewDocumentTests.swift`, `UITests/DesignJourneyTests+Page.swift`, `Tests/mutations/DesignModel.DesignNewDocument+Kernel.json`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/AfterGlowCLITests/Golden/apps/design.list-commands.json` | DS-9, DS-5, DS-6, DS-3, DS-4 | ~200, 8 |
| DS-11 | – | **Halo, test first.** `HaloCompositionSettingsTests`, disabled: a 10 s comp set to 15 s keeps every key's time; size anchored centre keeps layers centred; a navy background renders and saves (old files open white, byte for byte); RJ-H70's job folder, disabled; the journey, skipped | `Tests/HaloModelTests/HaloCompositionSettingsTests.swift`, `UITests/HaloJourneyTests+Settings.swift`, `Tests/RealJobs/halo/longer-navy-comp/longer-navy-comp.jobs.json` | DS-1, DS-2 | ~160, 3 |
| DS-12 | – | `HaloDocumentSetup+Kernel.swift`; `CompositionSettings` gains `background` and its validation calls `DocumentSetup.problems`; New Composition and Composition > Composition Settings… present the shared sheet; `composition.new` takes the setup and `document.set-settings` is in the catalog; turns on the tests | `Sources/HaloModel/HaloDocumentSetup+Kernel.swift`, `Sources/HaloModel/CompositionSettings.swift`, `Sources/HaloApp/HaloWindow+File.swift`, `Tests/HaloModelTests/HaloCompositionSettingsTests.swift`, `UITests/HaloJourneyTests+Settings.swift`, `Tests/mutations/HaloModel.HaloDocumentSetup+Kernel.json`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/AfterGlowCLITests/Golden/apps/halo.list-commands.json` | DS-11, DS-5, DS-6, DS-3, DS-4 | ~240, 9 |
| DS-13 | – | **Flare, test first.** `FlareDocumentSetupTests`, disabled: a Vertical preset makes 1080×1920 at 30; Document Settings to 15 s keeps keys; the journey, skipped | `Tests/FlareModelTests/FlareDocumentSetupTests.swift`, `UITests/FlareJourneyTests+NewSheet.swift` | – | ~130, 2 |
| DS-14 | – | `FlareDocumentSetup+Kernel.swift` over `SceneContracts.setCanvas`; `NewDocumentSpec.problem` calls `DocumentSetup.problems`; File > New and File > Document Settings… present the shared sheet; turns on the tests | `Sources/FlareModel/FlareDocumentSetup+Kernel.swift`, `Sources/FlareModel/FlareNewDocument.swift`, `Sources/FlareApp/FlareCommands.swift`, `Tests/FlareModelTests/FlareDocumentSetupTests.swift`, `UITests/FlareJourneyTests+NewSheet.swift`, `Tests/mutations/FlareModel.FlareDocumentSetup+Kernel.json`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/AfterGlowCLITests/Golden/apps/flare.list-commands.json` | DS-13, DS-5, DS-6, DS-3, DS-4 | ~220, 9 |
| DS-15 | – | **Delete the sheets.** Removes `NewCompositionSheet.swift` and `FlareNewSheet.swift`; `scripts/check-dup-views --update-baseline` drops their 6 lines | `Sources/HaloApp/NewCompositionSheet.swift`, `Sources/FlareApp/FlareNewSheet.swift`, `Tests/canonical-ui-baseline.txt` | DS-11, DS-12, DS-13, DS-14 | ~200, 3 |
| DS-16 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/document-setup.wave.json` | DS-15, DS-7, DS-8, DS-9, DS-10 | ~10, 1 |

## Build waves

- Wave 1: DS-1, DS-7, DS-9, DS-13. Independent in this wave: all.
- Wave 2: DS-2. Independent in this wave: DS-2 alone.
- Wave 3: DS-3, DS-4, DS-5, DS-11. Independent in this wave: all.
- Wave 4: DS-6. Independent in this wave: DS-6 alone.
- Wave 5: DS-8, DS-10, DS-12, DS-14. Independent in this wave: all.
- Wave 6: DS-15. Independent in this wave: DS-15 alone.
- Wave 7: DS-16. Independent in this wave: DS-16 alone.

Longest chain: DS-1 → DS-2 → DS-5 → DS-6 → DS-12 → DS-15 → DS-16 (7). Chain of 7: each link is a slice waiting on the slice whose types or files it needs (the stubs before the bodies, the bodies before an app's adapter, the adapter before its screen, the delete and the status last); only the named tasks wait, so the other slices run beside it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DS-1 | the kernel builds; `CommandShapeTests` with the two specs | a spec has no schema | – (stubs) |
| DS-2 | compiles, disabled | – | – (tests only) |
| DS-3 | `DocumentSetupTests`: 4×6 in at 300 ppi is 1200×1800 px; 10 cm at 300 ppi is 1181 px; 0 width gives "Width must be 1 to 16384 px." on the width field; swap of 1080×1920 is 1920×1080; `#00000000` reads transparent | a unit converts wrong or a problem lands on the wrong field | `SuiteKernel.DocumentSetup`: cm treated as 1/10 in → `.cmPerInch`; floor for round → `.pixelsRound`; height checked against the width limit → `.heightLimit` |
| DS-4 | `DocumentSetupTests.settings`: growing 1920×1080 to 1920×1200 anchored bottom moves content down 120; a rate change keeps the duration in seconds; set is one undo step | the anchor is ignored or a set takes two steps | `SuiteKernel.DocumentSetupCommands`: anchor offset sign flipped → `.anchorOffset`; duration kept in frames across a rate change → `.durationKeepsSeconds` |
| DS-5 | `NewDocumentSheetTests`: a preset fills every field; changing the unit keeps the pixel size; the clipboard preset shows only with a size; settings mode shows the anchor grid and hides presets; rate and duration only for timed apps | a field loses its value on a unit change or Create runs with a problem | – (SuiteUI view) |
| DS-6 | `SuiteDocumentSetupJourneyTests.testNewSheetPresetsAndUnits`; `RenderBudgetNewDocumentTests.typeWidthInOneBody` | – | – |
| DS-7 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| DS-8 | `PhotoNewImageTests`; `PhotoDocumentsJourneyTests.testNewImageFromSheet` | the image is 1920×1080 white whatever was asked | `PhotoModel.PhotoNewImage+Kernel`: background ignored → `.transparentBackground`; resolution not saved → `.resolutionSaved` |
| DS-9 | compile, disabled | – | – (tests only) |
| DS-10 | `DesignNewDocumentTests`; `DesignPageJourneyTests.testNewDocumentFromPreset` | the page ignores the preset | `DesignModel.DesignNewDocument+Kernel`: width and height swapped → `.pageSize`; transparent filled white → `.transparentFrame` |
| DS-11 | compile, disabled; `scripts/jobs check` | – | – (tests only) |
| DS-12 | `HaloCompositionSettingsTests`; `HaloSettingsJourneyTests.testCompositionSettingsLater` | keys move when the duration changes or the background isn't saved | `HaloModel.HaloDocumentSetup+Kernel`: keys rescaled to the new duration → `.keysKeepTimes`; background written for white → `.oldFilesUnchanged` |
| DS-13 | compile, disabled | – | – (tests only) |
| DS-14 | `FlareDocumentSetupTests`; `FlareNewSheetJourneys.testDocumentSettingsLater` | settings change the canvas but not the scene's duration | `FlareModel.FlareDocumentSetup+Kernel`: background dropped on settings → `.settingsKeepBackground`; duration set in frames at the old rate → `.durationKeepsSeconds` |
| DS-15 | both apps build; `scripts/check-dup-views` (baseline shrank by 6); `HJ-DS`, `FJ-DS` | a deleted sheet is still presented | – (deletion) |
| DS-16 | `scripts/waves check`; `scripts/jobs check` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: typing a width in the sheet, 20 keystrokes | ≤ 1 window body each; the readout and problems update in place | `RenderBudgetNewDocumentTests.typeWidthInOneBody` |
| render: Halo settings change on a 20-layer comp | ≤ 3 window bodies | `RenderBudgetHaloTests.compositionSettings` |
| one gesture, one step | a settings change is one undo step | `DocumentSetupTests.settings`, `HaloCompositionSettingsTests` |
| no dead controls; keyboard parity | Return creates, Escape cancels, Tab reaches every field | `SJ-DS`; `CommandPathTests` |
| behaviour preserved | old Halo and Flare files open unchanged | the adapters' tests |
| render: Halo's and Flare's New sheets once their own are gone (DS-z) | ≤ 1 window body per keystroke | `RenderBudgetNewDocumentTests.typeWidthInOneBody` (DS-6's row) |

## Done check

Per slice (rules 6, 15, 17, 21): DS-a and DS-m green on Linux with clean
`Mutate:` scores; DS-u and every adopt slice through the feel gate (`mouse`,
`taste`, `job`: make a print-size image and lengthen a composition, mouse
only) with their `Mac-Finish:` lines; DS-z with the UI baseline shrunk and
RJ-P71 and RJ-H70 green on Linux. Then `Belt-Contact-Sheet:`.
