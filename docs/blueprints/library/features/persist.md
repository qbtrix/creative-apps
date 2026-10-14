# Feature packet: persist

**Feature:** the catalog survives a relaunch. Every change is saved to
`catalog.json` (JSON, `"version": 1`, with each photo's develop settings and
crop from the start), restored at launch, flushed on quit; a damaged file is
set aside as `catalog.json.bad` with a notice, a file from a newer Library is
left untouched, and photos whose files have gone show as missing.
**Line:** `line:library` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/persist`

**Covers:** #212 (closes with PE-6). Because the file carries `develop` and
`crop` from the start, the catalog-file parts of #423 and #425 are done here
(those issues close with develop and crop).

**Depends on:** the spine feature issue; #333 (J8 and J9 live in
`UITests/LibraryJourneyTests+Persist.swift`, which compiles only once #333
widens the Journey template). No creative-core issue for v1 (JSON, decision
D1; creative-core#157 only if the captain picks the SQLite catalog). S-L4
`InlineNotice` (#780) is a soft wait: the spine's notice slot draws the
damaged and newer notices as a placeholder until it lands. The perf task
PE-7 also waits on #330 and S-L8 (#782). J8 and J9 are live: PE-6 waits for
import's IM-6 to merge (a task order inside the wave).

Blueprint sections: 2.2 (`library-persistence`), 2.5, 4.1 (saved before
quit), 4.2 J8 and J9, 4.3 P7, 5.2 (`CatalogFileState`), 5.3 (`CatalogStoring`,
`CatalogCoding`), 5.7 (the J8, J9 rows), 6.3, 7.1 (QB-LIB-2), 7.4
(QB-LIB-V7), 10 (D1).

No task edits `docs/c4/model.json`, `docs/design.md` or
`docs/review-rubric.md`.

**The golden (review note).** `Package.swift` is protected and declares no
resources for `LibraryModelTests`, so a `Golden/catalog-v1.json` file in the
test folder would draw SwiftPM's unhandled-file warning and could not load
through `Bundle.module`. The golden is a Swift string literal instead, in
`Tests/LibraryModelTests/LibraryPersistGolden.swift` (`static let catalogV1 =
#"""…"""#`), replacing the blueprint's `Tests/LibraryModelTests/Golden/catalog-v1.json`.

## Journey steps

Both in `UITests/LibraryJourneyTests+Persist.swift`, all live (L). Every
relaunch waits for `library.catalog` = `saved` first and reuses the
journey's `-LibraryCatalogDir`.

**J8 · `testCatalogSurvivesRelaunch`**
1. Write 6 JPEGs, 2 of them in `day2/`; launch with `-LibraryImportFolder`
   and `-LibraryImportOnLaunch`. Rate the first 4 stars, pick the second,
   label the third Red.
2. Wait for `saved`; `terminate()`; relaunch with no import. Shot
   `relaunched`. Expect 6 cells, the first `4 stars`, the second `Picked`,
   the third `Red`, Favorites 1.
3. Delete `day2/`; relaunch. Shot `missing-files`. Expect those two cells
   `unreadable` with help "The file is missing." (cell values once #779 has
   merged; before it, the loupe value and its help); they can still be
   rated: press 1 on one and its value contains `1 star`.

**J9 · `testDamagedCatalogIsSetAside`**
1. Write `not json` as `catalog.json`; launch. Shot `catalog-damaged`. Expect
   the empty state and the notice "Library couldn't read its catalog and
   started a new one. The old file is catalog.json.bad." with **Show in
   Finder**; `catalog.json.bad` exists.
2. Write `{"version": 2}`; relaunch. Shot `catalog-newer`. Expect "This
   catalog was made by a newer Library. Update Library to open it."; import a
   folder and rate a photo: `catalog.json` still holds `{"version": 2}` byte
   for byte and `library.catalog` stays `dirty` (nothing is saved over it).

Develop and crop round trips are J5 step 7 and J6 step 7 (waves 3 and 4).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Launch | no `catalog.json`: the empty catalog, state `.ready` | damaged: notice with **Show in Finder**, file renamed `.bad`, empty catalog that saves normally; newer: notice, no action, nothing saved (`canSave` false); a failed write: `saveError` holds the reason ("The disk is full."), `library.catalog` stays `dirty` and the next change retries | `.loading` until the read finishes: the spine's browser keeps the content empty with no "No Photos" flash while `catalogState == .loading` (persist sets the state, never edits `LibraryBrowser.swift`) |
| Grid | – | a photo whose file is gone: `.missing`, cell `unreadable`, help "The file is missing."; still rateable | placeholders while thumbnails rebuild |

Snapshot (`LibraryRestoreSnapshots.swift`): `library-restored` (a restored
catalog with one missing photo), Light and Dark. The damaged and newer
notices are the spine's `library-notice-damaged` and `library-notice-newer`.

## Contract slice

From the spine: `CatalogCoding`, `CatalogStoring`, `CatalogFileState`, the
stored `catalogState`, `saveRevision`, `savedRevision`, `saveError`, the
readout `catalogValue`, and `LibraryMenu.persist`. This feature adds, in
`LibraryPersistence.swift`:

```swift
extension LibraryCatalog {
    /// Starts the launch read: state .loading.
    public mutating func beginRestore()
    /// The decoded photos replace the catalog (ids kept as stored); state .ready;
    /// saved. Called with nil when there is no file: keeps the current photos
    /// (a fixture's), state .ready.
    public mutating func restore(_ photos: [PhotoItem]?)
    /// .damagedCatalog -> .damaged (the area set the file aside first);
    /// .newerCatalog(v) -> .newer(version: v); anything else -> .damaged.
    public mutating func failRestore(_ error: LibraryError)
    /// What to write: nil when saved or when `catalogState.canSave` is false.
    public func saveRequest() -> (revision: Int, photos: [PhotoItem])?
    public mutating func didSave(revision: Int)          // savedRevision = max(savedRevision, revision)
    public mutating func failSave(_ error: LibraryError)  // saveError; stays dirty
    /// Marks these ids `.missing` (files gone at launch).
    public mutating func markMissing(_ ids: Set<String>)
}
```

`LiveCatalogCoding` replaces the spine's stub and sets `unavailable` to nil.
`CatalogStore` (`LibraryApp/Platform`) replaces the spine's stub. No contract
signature changes.

**The v1 file.** One object, keys sorted, two-space indent, a trailing
newline, so equal catalogs encode to equal bytes:

```json
{
  "photos" : [
    {
      "captureDate" : 1780308000,
      "color" : [0.5, 0.5, 0.5],
      "develop" : { "contrast" : 0, "crop" : { "angle" : 5, "aspect" : "1:1", "rect" : { "height" : 1, "width" : 0.6667, "x" : 0.1667, "y" : 0 } }, "exposure" : 1, "highlights" : 0, "shadows" : 0, "temperature" : 0, "tint" : 0 },
      "flag" : "Pick",
      "id" : "/Users/me/Pictures/IMG_0001.jpg",
      "label" : "Red",
      "name" : "IMG_0001",
      "path" : "/Users/me/Pictures/IMG_0001.jpg",
      "pixelSize" : { "height" : 4000, "width" : 6000 },
      "rating" : 3
    }
  ],
  "version" : 1
}
```

`captureDate` is seconds since 1970 (a number, so no date-format API is
needed on Linux). `develop` is omitted when neutral; `crop`, `label`, `path`
are omitted when nil; a missing `develop` decodes as neutral. Before using
`JSONEncoder.OutputFormatting.sortedKeys` and `.prettyPrinted` from
`FoundationEssentials`, check the current docs (CLAUDE.md, docs MCP).

## Pseudocode

```
LiveCatalogCoding.encode(photos):                                  # PE-2
  JSONEncoder(sortedKeys, prettyPrinted).encode(FileV1(version: 1, photos.map(Record.init)))
decode(data):
  guard let top = try? JSONSerialization-free probe: decode { version: Int } else throw damagedCatalog
  if version > 1: throw newerCatalog(version)
  if version != 1: throw damagedCatalog
  records = try? decode(FileV1) else throw damagedCatalog
  return records.map(PhotoItem.init)   # availability .available; develop neutral when absent

restore(photos?):                                                   # PE-1
  if let photos: items = photos (no renaming: ids are unique on disk; a duplicate id -> keep the first)
     recount(); rebuildOrder(); selection = []; mode = .grid
  catalogState = .ready; savedRevision = saveRevision
saveRequest(): guard catalogState.canSave, saveRevision != savedRevision else nil; return (saveRevision, items)

LibraryWindow+Persist (PE-5, macOS):
  on appear: model.beginRestore()
    Task.detached { data = try await store.read() }
      nil -> model.restore(nil)
      data -> do { photos = try coding.decode(data); model.restore(photos)
                   missing = paths not on disk (FileManager, off main); model.markMissing(missing) }
              catch damagedCatalog { _ = try await store.setAside(); model.failRestore(.damagedCatalog("")) }
              catch newerCatalog(v) { model.failRestore(.newerCatalog(version: v)) }
  onChange(of: model.saveRevision): debounce 500 ms, then save()
  save(): guard let (rev, photos) = model.saveRequest(); Task.detached { data = try coding.encode(photos);
           try await store.write(data) } -> model.didSave(revision: rev) | model.failSave(error)
  NSApplication.willTerminateNotification: encode and write synchronously on the main thread (the one
    allowed blocking write; ≤ 50 ms for 10,000 records by QB-LIB-2's encode budget)
  persist.showCatalogInFinder = catalogState == .damaged ? { NSWorkspace reveal catalog.json.bad } : nil
  window accessibility value library.catalog = model.catalogValue (the spine set it; it now changes)

CatalogStore(dir) (PE-4, macOS):  dir = -LibraryCatalogDir ?? Application Support/Library (created)
  read: file missing -> nil; write: Data.write(options: .atomic); setAside: remove old .bad, move -> .bad
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: persist`, `Fast-Check:
pass`, `Head:`. The last task to merge carries `feature-done` (PE-6, or PE-7
when it runs).

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| PE-1 | #212 (part) | Restore, fail, save requests, revisions, missing files on the catalog | `Sources/LibraryModel/LibraryPersistence.swift`, `Tests/LibraryModelTests/LibraryPersistTests.swift` | spine |
| PE-2 | #212 (part) | `LiveCatalogCoding` v1 with develop and crop; the golden; `unavailable = nil` | `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/LibraryModelTests/LibraryCatalogCodingTests.swift`, `Tests/LibraryModelTests/LibraryPersistGolden.swift` | spine |
| PE-3 | #212 (part) | The catalog budgets: decode and encode 10,000 | `Tests/LibraryModelTests/LibraryCatalogBudgetTests.swift` | PE-2 |
| PE-4 | #212 (part) | `CatalogStore`: folder, atomic write, set aside | `Sources/LibraryApp/Platform/CatalogStore.swift` | spine |
| PE-5 | #212 (part) | The persist area: load at launch, missing files, save after changes, flush on quit, Show in Finder; `library-restored` | `Sources/LibraryApp/LibraryWindow+Persist.swift`, `Tests/AppSnapshotTests/LibraryRestoreSnapshots.swift` | PE-1, PE-2, PE-4 |
| PE-6 | #212 (closes) | J8 and J9 | `UITests/LibraryJourneyTests+Persist.swift` | PE-5, #333, import IM-6 |
| PE-7 | – | P7 `testLaunchLargeCatalog` (perf, report-only) | `UITests/LibraryJourneyTests+PerfLaunch.swift` | PE-6, #330, #782 |

`LibraryCatalogCodingTests.swift` and `LibraryPersistGolden.swift` are new
test files (not in `waves.json`); no other feature names them. The
blueprint's `Tests/LibraryModelTests/Golden/catalog-v1.json` is not created.
PE-1, PE-2 and PE-4 start side by side.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| PE-1 | `LibraryPersistTests`: after `beginRestore`, `restore([3 photos])` gives 3 items, `.ready`, `catalogValue == "saved"`; `restore(nil)` on a fixture catalog keeps its photos; one rating makes `saveRequest()` non-nil with the new revision and `dirty`; `didSave` of an older revision after a newer change stays `dirty`; `failRestore(.newerCatalog(version: 2))` makes `saveRequest()` nil whatever changes; `failRestore(.damagedCatalog(""))` gives `.damaged` and saving works; `markMissing` makes `cellValue` start `unreadable` and the photo still rateable | a save is lost or written over a newer file, or a restore keeps stale state |
| PE-2 | `LibraryCatalogCodingTests`: encode → decode → encode is byte-equal for `shoot` with develop and a crop on one photo; the fixed three-photo catalog encodes byte-equal to `LibraryPersistGolden.catalogV1`, and that text with its `develop` objects removed decodes to neutral settings (QB-LIB-V7); `not json`, `[]`, `{}` and `{"version": 1}` without photos throw `damagedCatalog`; `{"version": 2}` throws `newerCatalog(version: 2)`; `LiveCatalogCoding.unavailable == nil` | bytes drift between runs, a field is lost, or a bad file decodes |
| PE-3 | `LibraryCatalogBudgetTests` (rows below) | a model half misses its debug gate |
| PE-4 | J9 on the macOS run (the `.bad` rename, the untouched newer file) | — (code covered by J8 and J9) |
| PE-5 | `LibraryRestoreSnapshots` `library-restored`, Light and Dark; J8 step 2 on the macOS run | the launch flashes "No Photos" before the restore, or a change is never saved |
| PE-6 | J8 and J9 pass | any expectation fails |
| PE-7 | P7 attaches 5 runs, each with its `launch-grid` mark | a run is missing its mark |

## Quality tests

| quality row | budget (CI gate, debug) | test |
|---|---|---|
| QB-LIB-2 model half | `LiveCatalogCoding.decode` of 10,000 ≤ 1 s (100 ms release); `encode` ≤ 500 ms (50 ms release) | `LibraryCatalogBudgetTests.decodeLargeWithinBudget`, `.encodeLargeWithinBudget` |
| QB-LIB-2, QB-L12 probe | `launch-grid` ≤ 1 s after launch on 10,000 records; no main-thread stall over 2 refreshes; report-only | P7 (PE-7) |
| QB-LIB-V7 | round trip byte-equal; golden byte-equal; missing develop decodes neutral | `LibraryCatalogCodingTests` |
| QB-F2 | catalog problems shown in place as a notice, never an alert at launch | J9 |
| QB-V5 | `library-restored`, Light and Dark | `LibraryRestoreSnapshots` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green, J8 and J9 included.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`;
  `relaunched`, `missing-files`, `catalog-damaged`, `catalog-newer` add
  nothing (the notice's action and close button are named).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue.
