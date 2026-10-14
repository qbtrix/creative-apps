# Feature packet: photo-documents

**Feature:** PV-1. Save and reopen with layers kept (an OpenRaster `.ora`
file), the "Keep layers?" choice for a flat file with layers, Open Recent,
the unsaved state (top bar and the window's edited dot), the unsaved-changes
prompt on close and quit, autosave to a recovery file and the restore offer
after a crash.
**Line:** `line:photo` · **Wave:** 1 (`waves.md`) · **Tier:** p1 · **Lead
branch:** `lead/photo-documents`

**Covers:** no open issue (blueprint 8.1: PV-1 has none). Tier-1 rows 1 and
2 of the usage map.

**Depends on:** photo-seams (contracts, `LiveDocuments.swift` stub,
`PhotoWindow+File.swift`, `PhotoCommands+File.swift`, `PhotoTopBar.swift`,
`fileServices(_:)`) and photo-journey-kit (`writeTestPhoto`, a second
journey file). No creative-core issue: the zip container is pure Swift in
PhotoModel and PNGs go through the app's `PhotoImageCodec`.

Blueprint sections: 4.2 PJ-1 to PJ-4, 5.1 (documents and recovery
contracts), 5.3 (PV-1 methods), 6.1 rules 6–8, 6.2 (Keep layers?, Restore,
Unsaved changes, Open failure), 7.1 PB-18 to PB-20, 7.3 PF-1, PF-2, 8.3.

## Review notes folded in (review of #768)

1. **Where recovery I/O lives, and how `-PhotoRecoveryDir` reaches it.** The
   file I/O is Model code, `M/Live/LiveRecovery.swift`: one
   `<window>.ora` per window in a folder, written atomically through
   `FileManager` (FoundationEssentials has it), so Linux tests it in a
   temporary folder. `LiveDocuments.recovery(directory:)` makes it. The
   window gets it through `PhotoWindow.fileServices(_:)` (photo-seams,
   review note 4), which this feature fills in `PhotoWindow+File.swift`:
   `-PhotoRecoveryDir <folder>` when given, else
   `~/Library/Application Support/Photo/Recovery`. `A/PhotoAutosave.swift`
   holds only the timer and the off-main calls.
2. **Flare's shape, reused.** `A/PhotoAutosave.swift` copies the shape of
   `Sources/FlareApp/FlareAutosave.swift` (#759–#764): `noteEdit(at:)`,
   `tick(model:now:)`, `didSave()`, `willQuit(model:)`, `launch()` returning
   a `RecoveryOffer`, `restore(_:into:)`, `discard()`, times passed in as
   arguments. The offer's text is Model code (`PhotoRecovery.swift`) so Linux
   tests it.
3. **The damaged recovery file matches Flare.** Flare removes a recovery
   file that doesn't decode and shows no offer. Photo does the same, so
   PJ-3's error state changes from the blueprint's "couldn't be restored"
   offer to: no offer, the file removed, the empty canvas. One rule for the
   suite; a damaged recovery file holds nothing the person can use.
4. **The failed save has a journey.** Blueprint 6.1 rule 6's "Not saved"
   state had none; PJ-1b `testFailedSaveSaysNotSaved` below adds it.
5. **Save routing doesn't list formats.** `fileKind` comes from
   `ImageFormat(fileName:)`: a name it maps is `.image(format)`, any other
   opened file `.readOnly`. So when PV-8 (wave 3) adds TIFF and HEIC cases to
   `ImageFormat` in `PhotoImageFile.swift` (its file), a HEIC becomes
   writable without an edit to `PhotoDocumentFile.swift` or
   `PhotoWindow+File.swift` (the review's third unowned need).

**Decisions (this packet):**

- **Reading.** Photo reads only documents that carry `photo/document.json`
  (the layer list, kinds, masks, whole-image adjustments, format version).
  `stack.xml` is written for other OpenRaster readers but not parsed back:
  FoundationEssentials has no XML parser, and a hand-written one is not v2.
  An `.ora` without `photo/document.json` opens as
  `ArchiveError.damaged("photo/document.json is missing")`.
- **Save status before SuiteUI.** The top bar shows the status as a plain
  `Text` with the dot (`circle.fill`) until editor-chrome's EC-4
  (`EditorSaveStatus`, #339) lands; swapping it is a `line:photo` follow-up
  the lead files when EC-4 merges. No SuiteUI edit here.

## Journey steps

PJ-1 to PJ-4 run as blueprint 4.2 writes them, with these changes: PJ-3's
error state per note 3, and one new journey.

1. **PJ-1 `testSaveLayeredDocumentAndReopen`** (`+Documents`): open
   `beach.png` with `-PhotoSaveTo <tmp>`; "Saved"; New Layer, brush, opacity
   50, Multiply; "Edited" and the window's edited state; File > Save asks
   **Keep layers?** (Save as Photo Document default, Flatten into PNG,
   Cancel); Save as Photo Document gives the title `beach.ora`, "Saved", a
   zip whose first entry is `mimetype` = `image/openraster`; Command-W closes
   with no prompt; Open Recent > `beach.ora` gives 2 layers, the top "Layer
   1", opacity 50, Multiply, the canvas equal to step 3's; Command-Z leaves
   Edit reading "Redo" only.
2. **PJ-1b `testFailedSaveSaysNotSaved`** (`+Documents`, new): open
   `beach.png` with `-PhotoSaveTo <tmp>/locked` (the test makes the folder
   and sets it to `0o500`); brush; File > Save, Save as Photo Document.
   Assert the alert "The image couldn't be saved: <reason>." with OK, then
   `photo.bar.saved` reads "Not saved" and the window stays edited. Restore
   the folder's permissions in `tearDown`.
3. **PJ-2 `testUnsavedPromptAndOpenRecent`** (`+Documents`): as written
   (Cancel keeps the window; Don't Save closes; Open Recent lists
   `beach.png` first and reopens it without the stroke; Clear Menu leaves
   only Clear Menu, disabled).
4. **PJ-3 `testRestoreAfterCrash`** (`+Recovery`): as written (autosave 5 s
   after the last edit under `-PhotoRecoveryDir`; "Edited, autosaved";
   `app.terminate()`; relaunch; "Restore beach.png from <time>?" with
   `photo.recovery.restore` and `photo.recovery.discard`; Restore gives 2
   layers, "Edited"; Command-Q, Don't Save, relaunch: no offer). Added step:
   the test writes `not a zip` as a recovery file into the folder and
   relaunches: no offer, and the file is gone.
5. **PJ-4 `testOpenBadDocuments`** (`+Documents`): as written (four files,
   four `ArchiveError.message` alerts, the empty state stays).
6. **PJ-P3 `testOpenLargeDocument`** (`+PerfDocuments`): save `large` (from
   `-PhotoFixture large` with `.live` documents: see D-8) as a document,
   reopen it; report the "Opening…" mark and main-thread stalls
   (report-only until SuiteUI's FrameProbe #330, in suite-harness).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Top bar save status | no image: no status | "Not saved" in the error color after a failed save (PJ-1b) | "Saving…" note on the canvas after 100 ms |
| Keep layers? | – (only when saving a flat file with more than one layer, a mask or an adjustment layer) | – | – |
| Unsaved changes alert | not shown for a clean or empty window | – | – |
| Open Recent | only "Clear Menu", disabled | a recent file that is gone: today's open error alert, the list unchanged | – |
| Open failure | the window keeps what it had (empty or the open document) | the four `ArchiveError.message` texts (PJ-4) | "Opening…" after 100 ms |
| Restore offer | no recovery file: no offer | a damaged recovery file: removed, no offer (note 3) | the folder is read off the main thread before the offer shows |

## Contract slice

From blueprint 5.1 (`DocumentArchiving`, `RecoveryStoring`, `PhotoFileKind`,
`SaveAction`, `ArchiveError`, `PhotoPackage`, `PhotoDocumentSnapshot`,
`RecoveryEntry`, landed by photo-seams) and 5.3's PV-1 methods. Added here:

```swift
// M/PhotoDocumentFile.swift
public enum PhotoSaveStatus: Hashable, Sendable {
    case saved, edited, editedAutosaved, notSaved
    public var title: String   // "Saved", "Edited", "Edited, autosaved", "Not saved"
}
extension PhotoWorkspace {
    public func saveStatus(autosaved: Bool, saveFailed: Bool) -> PhotoSaveStatus?   // nil with no image
    /// What the image needs to keep: more than one layer, a mask or an adjustment layer.
    public var needsDocument: Bool
    /// The kind of an opened file: .document for "ora", .image(f) for a name ImageFormat maps, else .readOnly.
    public static func fileKind(forName name: String) -> PhotoFileKind
}

// M/PhotoRecovery.swift
public struct RecoveryOffer: Sendable, Equatable {
    public let entry: RecoveryEntry
    public let message: String   // "Restore beach.png from <time>?" / "Restore the unsaved image from <time>?"
    public init(entry: RecoveryEntry, time: (Double) -> String)
}
extension PhotoWorkspace {
    public func autosaveDue(lastEdit: Double, lastAutosave: Double?, now: Double,
                            delay: Double = PhotoWorkspace.autosaveDelay) -> Bool
}

// M/Live/LiveDocuments.swift (stub from photo-seams, filled here)
enum LiveDocuments {
    static func archive() -> any DocumentArchiving          // LiveArchive
    static func recovery() -> any RecoveryStoring           // LiveRecovery at the default folder
    static func recovery(directory: URL) -> any RecoveryStoring
}

// A/PhotoAutosave.swift (shape of FlareAutosave)
@MainActor final class PhotoAutosave {
    init(window: String, delay: Double)
    func noteEdit(at time: Double)
    func tick(model: PhotoWorkspace, now: Double, codec: any PhotoImageCodec) async
    var autosaved: Bool { get }
    func didSave(model: PhotoWorkspace)
    func willQuit(model: PhotoWorkspace, codec: any PhotoImageCodec) async
    func launch(model: PhotoWorkspace) async -> RecoveryOffer?
    func restore(_ offer: RecoveryOffer, into model: inout PhotoWorkspace, codec: any PhotoImageCodec) throws
    func discard(model: PhotoWorkspace)
}
```

## Pseudocode

```
container(package):                                  # D-1, M/Live/PhotoZip.swift
  entries = ["mimetype"] + package.files.keys.sorted() minus "mimetype"
  for each: local header (stored, method 0, CRC-32, sizes), name, bytes
  central directory, end record; no zip64 (a file over 4 GB throws .tooLarge)
package(fromContainer: data):
  no end record or first entry isn't "mimetype" = "image/openraster" -> .notADocument
  method != 0 -> .damaged("<name> is compressed"); CRC mismatch -> .damaged("<name> is corrupt")

encode(snapshot, codec):                             # D-2, M/Live/LiveArchive.swift
  files["mimetype"] = "image/openraster"
  for pixel layer i (bottom-up in stack.xml): files["data/layer-<i>.png"] = codec.encode(png)
  for each mask: files["photo/masks/layer-<i>.png"]; files["mergedimage.png"], thumbnail (longest side 256)
  files["stack.xml"] = OpenRaster stack: <image w h><stack><layer src name opacity visibility x y
                        composite-op="svg:multiply"...> (top first, pixel layers only)
  files["photo/document.json"] = { format: 1, canvas, layers:[{id,name,kind,adjustment?,visible,opacity,
                                   blend,offset,src?,mask?,maskEnabled}], adjustments, selected }
decode(package, codec):
  json missing -> .damaged("photo/document.json is missing"); format > formatVersion -> .newerVersion(v)
  any src missing -> .damaged("<src> is missing"); canvas or a layer over PhotoWorkspace's pixel limit -> .tooLarge

saveAction:                                          # D-3
  fileKind == .document -> .writeDocument
  .image(f): needsDocument ? .askKeepLayers(f) : .writeImage(f)
  nil or .readOnly -> .saveAs
openDocument(package, name, codec): snapshot = decode; start(...) with every layer, mask, kind, adjustments;
  fileKind = .document; savedStepID = currentStepID; history empty ("Open")
didSave(as name, kind): documentName = name; fileKind = kind; savedStepID = currentStepID

autosaveDue(lastEdit, lastAutosave, now, delay):     # D-4a
  guard isDirty, all finite else false
  return now - lastEdit >= delay && (lastAutosave ?? -inf) < lastEdit
recoveryEntry(now, codec): isDirty ? RecoveryEntry(documentName, now, documentPackage(codec)) : nil
restore(entry, codec): openDocument(entry.package, name: entry.documentName ?? "Untitled");
  fileKind = nil; savedStepID = nil-equivalent (dirty: a step that never matches)

LiveRecovery(directory):                             # D-4b
  write: container(entry.package) -> <dir>/<window>.ora atomically, savedAt as the file date
  leftBehind: every *.ora in dir, newest first; one that fails package(fromContainer:) is removed and skipped
  discard(window), discardAll
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: photo-documents`,
`Fast-Check: pass`, `Head:`. The last one carries `feature-done`. Paths as
in photo-seams (`M/`, `A/`, `MT/`, `ST/`, `UT/` = `UITests/`).

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| D-1 | – | The stored-entry zip writer and reader with CRC-32 | `M/Live/PhotoZip.swift`, `MT/PhotoContainerTests.swift` | – | ~300, 2 |
| D-2 | – | `LiveArchive`: encode and decode the document; `LiveDocuments.archive()` returns it | `M/Live/LiveArchive.swift`, `M/Live/LiveDocuments.swift`, `MT/PhotoDocumentRoundTripTests.swift` | D-1 | ~390, 3 |
| D-3 | – | Workspace side: `snapshot`, `documentPackage`, `openDocument`, `didSave`, `saveAction`, `fileKind(forName:)`, `needsDocument`, `saveStatus` | `M/PhotoDocumentFile.swift`, `MT/PhotoDocumentFileTests.swift` | D-2 | ~330, 2 |
| D-4a | – | `autosaveDue`, `recoveryEntry`, `restore`, `RecoveryOffer` text | `M/PhotoRecovery.swift`, `MT/PhotoRecoveryTests.swift` | D-3 | ~220, 2 |
| D-4b | – | `LiveRecovery` (folder I/O, atomic, damaged files dropped); `LiveDocuments.recovery(directory:)` | `M/Live/LiveRecovery.swift`, `M/Live/LiveDocuments.swift`, `MT/LiveRecoveryTests.swift` | D-4a | ~250, 3 |
| D-5 | – | Budgets PB-18, PB-19, PB-20 on `large` | `MT/PhotoDocumentsBudgetTests.swift` | D-4b | ~150, 1 |
| D-6 | – | `PhotoPackageIO`: read and write a document's bytes off the main actor; PF-1 through ImageIO | `A/PhotoPackageIO.swift`, `ST/PhotoPackageIOTests.swift` | D-3 | ~220, 2 |
| D-7 | – | Save routing, Keep layers?, open `.ora`, open errors, "Not saved", `fileServices` with the recovery folder; Open Recent noted after each open and save | `A/PhotoWindow+File.swift`, `A/PhotoCommands+File.swift` | D-6, D-4b | ~340, 2 |
| D-8 | – | Save status in the top bar (plain until EC-4), the window's edited dot, the "Saving…" and "Opening…" notes; snapshots | `A/PhotoTopBar.swift`, `ST/PhotoDocumentsSnapshots.swift` | D-7 | ~200, 2 |
| D-9 | – | `PhotoAutosave` (Flare's shape) and its wiring: tick every second, restore offer at launch, discard on a clean close | `A/PhotoAutosave.swift`, `A/PhotoWindow+File.swift`, `ST/PhotoAutosaveTests.swift` | D-8 | ~360, 3 |
| D-10 | – | App delegate adaptor: Open Recent and Finder opens with no window, the unsaved prompt on close and on Quit | `A/PhotoApp.swift`, `A/PhotoWindow+File.swift`, `ST/PhotoUnsavedPromptTests.swift` | D-9 | ~260, 3 |
| D-11 | – | Journeys PJ-1, PJ-1b, PJ-2, PJ-4 | `UT/PhotoJourneyTests+Documents.swift` | D-10, photo-journey-kit | ~330, 1 |
| D-12 | – | Journeys PJ-3 and PJ-P3 | `UT/PhotoJourneyTests+Recovery.swift`, `UT/PhotoJourneyTests+PerfDocuments.swift` | D-10, photo-journey-kit | ~220, 2 |

Chains: D-1 → D-2 → D-3 → D-4a → D-4b → D-5 (Model types in turn; D-2 and
D-4b share `LiveDocuments.swift`); D-6 after D-3, parallel to D-4a; D-7 →
D-8 → D-9 → D-10 share the window and file code. D-11 and D-12 run side by
side after D-10. D-12 carries `feature-done` (or whichever merges last).

**PJ-P3's large document.** `-PhotoFixture large` runs on `.fake`, whose
archive writes no real file. D-12 instead makes the large photo with
`writeTestPhoto(to:width:height:)` at 4000 × 3000, adds two layers in the UI
and saves as a document; the perf numbers come from reopening that file.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| D-1 | `PhotoContainerTests`: a package with `mimetype` and two entries round-trips byte for byte; the first local header's name is `mimetype` at offset 30 and its data `image/openraster` (the OpenRaster rule); CRC-32 of "123456789" is `0xCBF43926`; a flipped data byte gives `.damaged("data/layer-1.png is corrupt")`; `not a zip` gives `.notADocument`; a method-8 entry gives `.damaged` | an entry is reordered or compressed, the CRC is wrong, or bad bytes open |
| D-2 | `PhotoDocumentRoundTripTests` with an in-memory lossless codec: PF-1 (every layer's 8-bit bytes, masks, kinds, blend, opacity, offsets, visibility, the global adjustments, the selected layer survive exactly); format 2 gives `.newerVersion(2)`; a missing `data/layer-2.png` gives that exact damaged text; a 20 MP layer gives `.tooLarge`; no `photo/document.json` gives its damaged text | a field is lost, or a bad package opens or throws another error |
| D-3 | `PhotoDocumentFileTests`: `fileKind(forName:)` maps `a.ora`, `a.PNG`, `a.jpeg`, `a.heic` to document, PNG, JPEG, readOnly; `saveAction` is `.askKeepLayers(.png)` after New Layer on an opened PNG and `.writeImage(.png)` with one layer; `didSave` makes `isDirty` false and an undo makes it true; `openDocument` leaves nothing to undo; `compositeSurvives` (PF-2): the composite after reopening is within 1/255 of the one before | Save routes wrong, a just-opened document reads dirty, or the picture drifts past 1/255 |
| D-4a | `PhotoRecoveryTests`: due at exactly `delay` after the last edit and not before; not due when clean, after an autosave of that edit, or with NaN; `recoveryEntry` is nil when clean; `restore` lands 2 layers, dirty, `fileKind == nil`; `RecoveryOffer` text with a fixed `time` is "Restore beach.png from 9:41 AM?" and "Restore the unsaved image from 9:41 AM?" untitled | due early or twice, a clean image autosaves, a restore reads clean |
| D-4b | `LiveRecoveryTests` in a temp folder: write then `leftBehind` gives the entry; a second write for the same window replaces it; two windows give two entries newest first; `discard(window:)` removes one, `discardAll` all; a `not a zip` file is removed and skipped; the write is atomic (no partial file after a throwing write) | an entry is lost, a damaged file is offered or left, or a partial file appears |
| D-5 | `PhotoDocumentsBudgetTests`: PB-18 save and PB-19 open of a 3-layer 12 MP document ≤ 2 s release, PB-20 autosave ≤ 2 s release and its main-actor snapshot copy ≤ 16 ms debug (gated in CI) | the debug snapshot copy is over 16 ms, or a release gate is missed locally |
| D-6 | `PhotoPackageIOTests` (macOS): PF-1 through `ImageIOCodec`; the write runs with `Thread.isMainThread == false` inside it; a write into a read-only folder throws and leaves no file | a field changes through ImageIO, the write runs on main, or a failed write leaves a file |
| D-7 | V5 and V6 green (a one-layer PNG still saves in place with no question); PJ-1 and PJ-4 pass once D-11 lands; the app-state rule passes | a flat one-layer save asks, or a view assigns state |
| D-8 | `PhotoDocumentsSnapshots`: `photo-unsaved-light.png`, `-dark.png` (the dot and "Edited") and `photo-keep-layers-light.png`, `-dark.png`; every element has a `photo.bar.saved` or `photo.file.*` identifier | a status has no identifier, or the dialog doesn't fit 1024 × 768 |
| D-9 | `PhotoAutosaveTests` (temp folder, times passed in): a due model writes once per edit; a clean model writes nothing; `didSave` removes the file; a write landing after a save is removed; `launch` reads off main and gives the offer; a damaged file gives nil and is gone; Restore and Discard remove the file | Flare's MP-5 and MP-6 cases fail for Photo |
| D-10 | `PhotoUnsavedPromptTests`: the alert's text and buttons (Save, Don't Save, Cancel) for "beach.png"; a clean window closes without it; Quit with two dirty windows asks for each; PJ-2 passes once D-11 lands | a clean window prompts, or Quit skips a dirty window |
| D-11 | PJ-1, PJ-1b, PJ-2, PJ-4 pass on the macOS run; each step `shot`s | any step's assertion fails |
| D-12 | PJ-3 passes, including the damaged-file step; PJ-P3 records at least one "Opening…" sample (report-only) | the offer is missing, a damaged file is offered, or PJ-P3 records nothing |

## Quality tests

| quality row | budget | test |
|---|---|---|
| PB-18 save, 3-layer 12 MP | ≤ 2 s release, report debug; "Saving…" within 100 ms (report until #330) | `PhotoDocumentsBudgetTests.saveDocument` |
| PB-19 open the same | ≤ 2 s release, report debug | `PhotoDocumentsBudgetTests.openDocument`, PJ-P3 |
| PB-20 autosave | ≤ 2 s off main release; snapshot copy on main ≤ 1.6 ms release, ≤ 16 ms debug (gated) | `PhotoDocumentsBudgetTests.autosaveSnapshotCopy` |
| PF-1 | exact round trip in 8 bits | `PhotoDocumentRoundTripTests`, `PhotoPackageIOTests` |
| PF-2 | composite within 1/255 after reopening | `PhotoDocumentFileTests.compositeSurvives` |
| QB-L12 | reads, decodes and writes never on the main thread | `PhotoPackageIOTests.writesOffMain`, `PhotoAutosaveTests.readsOffMain` |
| QB-F2 live feedback | the save status changes in the same call that edits or saves | `PhotoDocumentFileTests.statusFollowsEdits` |
| QB-F3 | Open is the first history step; a reopened document has nothing to undo | `PhotoDocumentFileTests.openHasNoUndo`, PJ-1 step 5 |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the
  `feature-done` PR is green: PJ-1, PJ-1b, PJ-2, PJ-3, PJ-4, V1–V12.
- **Audit zero new:** no Photo count over `UITests/audit-baseline.json`; the
  Keep layers?, Restore and Unsaved alerts are audited as their own layers
  and fit 1024 × 768 (`offscreen` 0).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
