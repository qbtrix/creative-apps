# Feature packet: import

**Feature:** File > Import Folder… reads a folder of JPEG, PNG and HEIC files
(subfolders included) into the catalog: capture dates from Exif, each
photo's id is its path, files already in the catalog are skipped, the grid
fills while the import runs, a progress row shows within 100 ms, and a
notice at the top of the content says what came in and what failed.
**Line:** `line:library` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/import`

**Covers:** #210 (closes with IM-8). Its "Files likely involved" list is
superseded by the owned files below; its `LibraryCommands.swift` edit is
already done by the spine's File menu item.

**Depends on:** the spine feature issue (see `waves.md`). No creative-core
issue (decoding is ImageIO, in `LibraryApp/Platform`). SuiteUI: S-L4
`InlineNotice` (#780) and S-L5 `ProgressRow` (#781) are soft waits: until
they merge the notice and progress row are plain SwiftUI placeholders in
`LibraryBrowser.swift`, and a fix PR swaps them in once they land (in this
feature if it is still running, else a `gap` issue). Import owns
`UITests/LibraryJourneyTests.swift` in wave 2, so J1 needs no #333. The perf
task IM-9 waits on #330, S-L8 (#782) and #333 (`waves.md`, Perf tasks).

Blueprint sections: 2.2 (`library-import`), 2.5 (threads), 4.1 and 4.2 J1,
4.3 P6, 5.2 (`ImportCandidate`, `FolderScan`, `ImportProgress`,
`ImportResult`, `ImportNotice`), 5.3 (`PhotoDecoding`, `PhotoImporting`), 5.7
(the J1 row), 6.1 (Progress, Notices), 6.3, 7.1 (QB-L9, QB-LIB-1), 7.4
(QB-LIB-V6).

No task edits `docs/c4/model.json`, `docs/design.md` or
`docs/review-rubric.md` (the supervisor folds them in).

## Journey steps

**J1 · `testImportAFolder`** in `UITests/LibraryJourneyTests.swift` (in
`UITests/LibraryJourneyTests+Import.swift` if #333 has merged when IM-8
starts). Steps 1–5 are live (L), step 6 runs on fakes (F).

1. Write 24 JPEGs (4 of them in `day2/`), 1 PNG, 1 HEIC,
   `LibraryFiles.broken` and a `notes.txt` into a temp folder; launch with
   `-LibraryImportFolder` on it and an empty `-LibraryCatalogDir`.
2. Click **Import Folder…**. Shot `importing`. Expect cells with the value
   `loading` before the import ends (batches arrive through `added`).
3. Wait for the progress row to go. Shot `imported`. Expect 26 cells, All
   Photos 26, the first cell the earliest written, and the notice "Imported
   26 photos. 1 file couldn't be imported." whose **Show** lists
   `broken.jpg: not an image file`; `notes.txt` is not mentioned.
4. Delete `broken.jpg`; import the same folder again. Shot `import-again`.
   Expect "No new photos in <folder>." and still 26 cells.
5. Relaunch with `-LibraryImportFolder` on `LibraryFiles.unreadableFolder()`
   and import. Shot `import-denied`. Expect "Library can't read <folder>.
   Check that you have access to it." as an error notice.
6. (F) Relaunch with `-LibraryFixture shoot-unimported -LibraryFakeMode slow`
   (the spine's fixture: the fakes hold `shoot`, the catalog is empty); File
   > Import Folder…. Shot `import-progress`. Expect `library.import.progress`
   reading "Importing 1 of 24" within 2 s (the spine's `FakeImporter`
   reports progress before its 2 s wait, review note on J1 step 6).

`<folder>` is the folder's last path component everywhere (the notice and
`LibraryError.unreadableFolder`). IM-8 also deletes the skipped
`testImportRateAndRelaunch` (J8 replaces it, in persist).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Content | the spine's "No Photos" with **Import Folder…**, now enabled (`LiveImporter.unavailable` is nil after IM-2) | notice (error state): "Library can't read <folder>. Check that you have access to it." or "No photos found in <folder>."; notice (warning state) when some files failed: "Imported 26 photos. 1 file couldn't be imported." with **Show** listing each `name: reason`; "1 file couldn't be imported." alone when nothing came in | progress row "Importing 3 of 27" (`library.import.progress`), shown 100 ms after the command, with a determinate bar; cells of new photos appear as batches arrive, valued `loading` until thumbnails draws them |
| Notice | – | dismissible (close button → `dismissImportNotice()`); a new import replaces it | – |
| File menu | Import Folder… disabled with "An import is already running." while one runs | – | – |

Snapshots (`LibraryImportSnapshots.swift`): `library-importing`,
`library-imported`, `library-import-failures`, `library-import-nothing-new`,
`library-import-denied`, Light and Dark.

## Contract slice

From the spine (verbatim contracts): `PhotoDecoding.scan(folder:)`,
`PhotoImporting.importFolder(_:known:progress:added:)`, `ImportProgress`,
`ImportResult`, `ImportNotice`, `ImportState`, `LibraryError`. This feature
adds the catalog methods (blueprint 5.7) in `LibraryImport.swift`:

```swift
extension LibraryCatalog {
    /// The known ids to skip, and state .running(0 of 0); nil while an import runs.
    public mutating func beginImport(_ folder: String) -> Set<String>?
    public mutating func showImportProgress(_ progress: ImportProgress)
    /// A batch from `added`: photos whose id is already in the catalog are ignored.
    public mutating func appendImported(_ photos: [PhotoItem])
    /// Appends what `appendImported` missed, sets `importNotice`, state .idle.
    public mutating func finishImport(_ result: ImportResult)
    public mutating func failImport(_ error: LibraryError)
    public mutating func dismissImportNotice()
    /// "An import is already running." while one runs, else the importer's unavailable reason.
    public var importHelp: String? { get }
}
```

`LiveImporter(decoder:)` replaces the spine's stub in `Live/LiveImporter.swift`
and sets `unavailable` to nil. `ImageIODecoder` replaces the spine's
`Platform/ImageIODecoder.swift` stub and conforms to `PhotoDecoding` in full
(`decode` is used by thumbnails, loupe and export later; it lands here). No
contract signature changes.

## Pseudocode

```
beginImport(folder):                                        # IM-1
  guard importState == .idle else return nil
  importState = .running(ImportProgress(done: 0, total: 0)); importNotice = nil
  pendingFolder = lastPathComponent(folder)                 # kept in importState's notice
  return Set(items.map(\.id))
appendImported(batch):  new = batch.filter { id not in items }; items += new;
  recount(); rebuildOrder(); saveRevision += 1              # never an undo step (D4)
finishImport(result):  appendImported(result.added)
  importNotice = ImportNotice(folder, added: result.added.count, alreadyKnown, failures)
  importState = .idle
failImport(error):     importNotice = ImportNotice(folder, error: error); importState = .idle

LiveImporter.importFolder(folder, known, progress, added):  # IM-2
  scan = try await decoder.scan(folder)                     # throws unreadableFolder
  if scan.candidates.isEmpty && scan.failures.isEmpty: throw noPhotos(name)
  fresh = scan.candidates.filter { !known.contains($0.path) }
          .sorted { ($0.captureDate, $0.path) < ($1.captureDate, $1.path) }
  progress(0 of fresh.count)
  batch = []; lastFlush = now; lastProgress = now
  for (i, c) in fresh:
    batch.append(PhotoItem(id: c.path, path: c.path, name: fileStem(c.path), captureDate: c.captureDate,
                           pixelSize: c.pixelSize, color: neutral grey))
    if now - lastProgress ≥ 1/30 s: progress(i+1 of total)
    if batch.count == 50 || now - lastFlush ≥ 250 ms: added(batch); batch = []
    if Task.isCancelled: break
  if !batch.isEmpty: added(batch)
  return ImportResult(added: all, alreadyKnown: scan.candidates.count - fresh.count, failures: scan.failures)
  (the clock is a parameter, so tests drive time without sleeping)

ImageIODecoder.scan(folder):                                # IM-4 (macOS)
  enumerator(at: folder, skipsHiddenFiles, skipsPackageDescendants) else throw unreadableFolder
  for each regular file with PhotoFileKind(forFileName:):
    CGImageSourceCreateWithURL; properties at index 0
    else failures += (path, "not an image file")
    size = pixel width/height, swapped for orientations 5...8
    date = Exif DateTimeOriginal (+ OffsetTimeOriginal when present) ?? file creation date
ImageIODecoder.decode(path, maxLongSide):
  missing -> missingFile; no source -> notAnImage
  CGImageSourceCreateThumbnailAtIndex(createAlways, withTransform, maxPixelSize = maxLongSide ?? long side)
  draw into an sRGB RGBA8 premultiplied CGContext; un-premultiply to straight alpha -> DisplayImage

LibraryWindow+Import (IM-6, macOS):
  import(): folder = launch.importFolder ?? NSOpenPanel (directories only)
    guard let known = model.beginImport(folder) else return
    Task.detached { result = try await services.importer.importFolder(folder, known,
         progress: { p in Task { @MainActor in model.showImportProgress(p) } },
         added:    { b in Task { @MainActor in model.appendImported(b) } }) }
      success -> MainActor model.finishImport(result); failure -> model.failImport(error as? LibraryError ?? .invalid(…))
  on appear: if launch.importOnLaunch, import()
  menu sub-struct: importFolder = model.importHelp == nil ? import : nil
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: import`, `Fast-Check: pass`,
`Head:`. The last task to merge carries `feature-done` (IM-8, or IM-9 when it
runs).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| IM-1 | #210 (part) | The import state machine on the catalog: begin, progress, batches, finish, fail, dismiss, help | `Sources/LibraryModel/LibraryImport.swift`, `Tests/LibraryModelTests/LibraryImportTests.swift` | spine |
| IM-2 | #210 (part) | `LiveImporter`: skip known, capture-date order, path ids, batches, throttled progress, cancel; `unavailable = nil` | `Sources/LibraryModel/Live/LiveImporter.swift`, `Tests/LibraryModelTests/LibraryLiveImporterTests.swift` | spine |
| IM-3 | #210 (part) | The import model budgets | `Tests/LibraryModelTests/LibraryImportBudgetTests.swift` | IM-1, IM-2 |
| IM-4 | #210 (part) | `ImageIODecoder`: scan with metadata and orientation, decode to sRGB RGBA8 | `Sources/LibraryApp/Platform/ImageIODecoder.swift` | spine |
| IM-5 | #210 (part) | QB-LIB-V6 decode fidelity on macOS | `Tests/AppSnapshotTests/LibraryDecodeTests.swift` | IM-4 |
| IM-6 | #210 (part) | The import area: File > Import Folder…, open panel or `-LibraryImportFolder`, the task off the main actor, import on launch | `Sources/LibraryApp/LibraryWindow+Import.swift` | IM-1, IM-2, IM-4 |
| IM-7 | #210 (part) | The progress row and the notice (placeholders until #780 and #781) and their snapshots | `Sources/LibraryApp/LibraryBrowser.swift`, `Tests/AppSnapshotTests/LibraryImportSnapshots.swift` | IM-1 |
| IM-8 | #210 (closes) | J1; delete the skipped `testImportRateAndRelaunch` | `UITests/LibraryJourneyTests.swift`, `UITests/LibraryJourneyTests+Import.swift`, `UITests/LibraryJourneyTests+Files.swift` | IM-6, IM-7 |
| IM-9 | – | P6 `testImportProgressAndThroughput` (perf, report-only) | `UITests/LibraryJourneyTests+PerfImport.swift` | IM-8, #330, #782, #333 |

`LibraryLiveImporterTests.swift` is a new test file (not in `waves.json`); no
other feature names it. IM-8 owns `LibraryJourneyTests+Files.swift` in wave 2
only to move the spine's `LibraryFiles` helpers there if #333 merges during
wave 2 (the other wave-2 features read the helpers, never edit them). IM-1,
IM-2 and IM-4 can start side by side; IM-7 needs only IM-1.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| IM-1 | `LibraryImportTests`: `beginImport` returns every id and a second call returns nil until `finishImport`; `appendImported` of a batch holding an existing id adds only the new ones and updates All Photos and `order`; `finishImport` of 26 added and 1 failure sets the notice's `message` to "Imported 26 photos. 1 file couldn't be imported." and state `.idle`; `failImport(.unreadableFolder("Shots"))` gives the error notice and `isError`; an import adds no undo step (`undoTitle` unchanged); `importHelp` is "An import is already running." while running | a duplicate gets in, the state doesn't return to idle, the text differs, or import becomes undoable |
| IM-2 | `LibraryLiveImporterTests` over a test decoder that scans 120 candidates (3 known, 2 failures) on a test clock: the result has 117 photos in capture-date order with `id == path` and the file stem as name; `added` batches are ≤ 50 and their concatenation equals the result; `progress` is called ≤ 30 times a simulated second and ends at total; an empty folder throws `noPhotos`; a scan error passes `unreadableFolder` through; `LiveImporter.unavailable == nil` | a known path is re-imported, the order or ids differ, batches are too big, or progress floods |
| IM-3 | `LibraryImportBudgetTests` (rows below) | a model half misses its debug gate |
| IM-4 | IM-5's tests; J1 steps 1–5 on the macOS run | — (code covered by IM-5 and J1) |
| IM-5 | `LibraryDecodeTests` (macOS): a generated JPEG with Exif orientation 6 and a red marker top-left before rotation scans as portrait and decodes with the marker top-left of the upright image; a Display P3 PNG of P3 (1, 0, 0) decodes to sRGB within 2/255 of the clipped expected value; a `.jpg` of the bytes `not an image` is a scan failure with reason "not an image file"; `decode(maxLongSide: 512)` of a 4000 × 3000 file is 512 × 384; a hidden file and a file inside a package are not listed | orientation or color is wrong, a broken file throws instead of failing, or the size isn't fitted |
| IM-6 | J1 steps 2–5 on the macOS run | the import blocks the main thread, a second import starts, or import on launch doesn't run |
| IM-7 | `LibraryImportSnapshots`: the five states above, Light and Dark; the progress row carries `library.import.progress` with the text as its value | a state is missing or the row has no identifier |
| IM-8 | J1 passes; `testImportRateAndRelaunch` is gone | any J1 expectation fails |
| IM-9 | P6 attaches `perf-testImportProgressAndThroughput.json` with 5 runs, each with a `progress` and a `thumb-ready` mark | a run is missing its marks |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-L9 model half | `beginImport` on a 10,000-photo catalog ≤ 10 ms (1 ms release) | `LibraryImportBudgetTests.beginImportWithinBudget` |
| QB-LIB-1 model half | `finishImport` of 200 into 10,000 ≤ 50 ms (5 ms release); planning 10,000 candidates against 10,000 known ≤ 200 ms (20 ms release) | `LibraryImportBudgetTests.finishImportWithinBudget`, `.planAgainstKnownWithinBudget` |
| QB-LIB-1, QB-L9 probe | `progress` ≤ 100 ms after the command; first 20 cells `thumb-ready` ≤ 2 s; all 200 records ≤ 10 s; report-only | P6 (IM-9) |
| QB-LIB-V6 | orientation and color within 2/255 | `LibraryDecodeTests` (IM-5) |
| QB-F2 | progress and errors shown in place (the content's row and notice, never an alert) | J1 steps 3–6 |
| QB-F5 | the progress row's appear animation has duration 0 under `-LibraryReduceMotion` | J1 step 6 relaunched with `-LibraryReduceMotion` reads the probe (once #330 lands; a step in IM-9) |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green, J1 included, and the spine's journeys still pass.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`;
  the shots `importing`, `imported`, `import-again`, `import-denied`,
  `import-progress` add nothing to any count (the notice's close button and
  action are named and identified).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  with J1's six shots and, if IM-9 ran, P6's numbers.
