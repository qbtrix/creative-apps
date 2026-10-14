# Feature packet: spine

**Feature:** the base every other Library feature builds on. The contracts,
their fakes and the live stubs land verbatim from the blueprint; the
catalog declares every stored property v1 needs, a cached display order and
undo; launch arguments and fixtures let journeys start on fakes or on real
files; and the app is split into one file per feature, with every v1 menu
item and single key wired to a per-area closure that starts out nil.
**Line:** `line:library` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/spine`

**Covers:** #235 (closes with SP-10). #156 was closed by the blueprint's
merge (#769) while its fix, PR #217, is still open: SP-9 lands the fix only if
#217 has not merged when SP-9 starts, and its PR says `Refs #156`.

**Depends on:** none. No creative-core issue (every type the contracts use is
on the creative-core revision `Package.resolved` pins, `main` cfad97f; the
blueprint's `check.sh` ran on `dev` 4cac701, whose CoreRaster and CoreColor
sources are the same). No SuiteUI change: the spine draws only existing
SuiteUI components, and until #333 merges its journeys go in
`UITests/LibraryJourneyTests.swift`, which it owns.

Blueprint sections: 2 (components, no shared wiring file, threads), 4.1
(launch arguments, fixtures, values), 5 (contracts, verbatim), 5.5 to 5.7
(`PhotoItem`, stored state, methods), 6.2 (menu bar, single keys), 6.3
(spine snapshots), 7 (`Budget.swift`), 8.3 (owned files).

**Shared docs.** No spine task edits `docs/c4/model.json`, `docs/design.md`
or `docs/review-rubric.md`: the supervisor folds the planned C4 descriptions
(`docs/blueprints/library/c4-planned.json`), the "Catalog apps (Library)"
look rules (blueprint 6.1) and the `QB-LIB` ids in later. Every new file sits
in `Sources/LibraryModel/` or `Sources/LibraryApp/`, which their target
components already own, so the C4 ownership check passes without an edit.

**Keep the shared tests compiling.** `Tests/AppSnapshotTests/AppSnapshotTests.swift`
(shared; no Library feature edits it) calls `LibraryBrowser(model:
LibraryCatalog())`, and the `Library*Snapshots.swift` files call
`LibraryCatalog()`, `load(_:)`, `LibrarySample.items()` and
`LibraryBrowser(model:)`. Every one of these stays callable with the same
arguments: `LibraryCatalog.init(services: LibraryServices = .fake())`, and
every new `LibraryBrowser` parameter has a default.

## Journey steps

J0 and J11 are the spine's; J10 and the four existing journeys are updated.
Until #333 merges they all live in `UITests/LibraryJourneyTests.swift`; once
it merges, J0 and J11 move to `UITests/LibraryJourneyTests+Shell.swift` and
the `LibraryFiles` helpers to `UITests/LibraryJourneyTests+Files.swift` (not
`UITests/Journey+Library.swift`, which the blueprint named: `UITests/Journey*.swift`
is SuiteUI's under the shared-file rule).

**J0 · `testLaunchShowsEmptyCatalog`**
1. (F, L) Launch with an empty `-LibraryCatalogDir` and no fixture. Shot
   `empty`. Expect `expectWindowShell()`, "No Photos" with **Import Folder…**
   as its one prominent button, every sidebar count 0.
2. (F, L) Open File. Shot `file-menu-empty`. Import Folder… and the empty
   state's button are enabled exactly when `library.controls` lists
   `library.import` as enabled; while disabled, the button's help is its
   reason ("Import isn't connected yet (import)." in wave 1). Export… is
   disabled.
3. (F, L) Open Edit. Undo and Redo are disabled.

**J10 · `testEveryMenuOpens`** (launched with `-LibraryFixture samples`):
every menu opens and each app menu holds exactly its app-owned items from
blueprint 6.2 (Library, File, Edit, View, Photo, Metadata), by title.

**J11 · `testEveryControlActsOrSaysWhy`** (launched with `-LibraryFixture
samples`): read `library.controls`; click each enabled control, then Escape
and Command-Z; each enabled control changed the shot or a value; each
disabled control has a non-empty reason.

**The four existing journeys** move to `-LibraryFixture samples`:
`testLoadSamplePhotos` launches with `-LibraryFixture empty` and chooses File
> Load Sample Photos (the empty state's button is now Import Folder…);
`testEveryMenuOpens` (J10), `testLoupeStepsAndReturnsToTheGrid` and
`testRateASelectedPhoto` launch on `samples` and no longer click a content
button. `testLaunchShowsWindowShell` is unchanged.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Content | "No Photos", **Import Folder…** (the one prominent button; disabled with its reason as help while `services.unavailable["importer"]` is set); Load Sample Photos stays in File | the notice slot at the top shows `catalogState.message` (damaged, newer) or `importNotice.message`, drawn as a plain placeholder row until S-L4 (#780) lands; its action comes from the persist or import area and is nil (no button) in wave 1 | `catalogState == .loading`: the grid area stays empty, no notice; nothing in wave 1 sets it |
| Status | – | – | the "Preview data" warning pill (a `ViewerStatusBar` trailing pill) whenever `services.isPreview` |
| Inspector | nothing selected: `InspectorHeader` with the collection's name and "N photos" (replaces today's `SurfaceCard`) | – | – |
| Develop tab | `DevelopInspector` stub: "Develop isn't connected yet (develop)." in an `EmptyStateView`; it hosts `CropInspector` (stub, empty) while `cropDraft` is set | – | – |
| Export sheet | `LibraryExportSheet` stub presented while `exportState != .idle`; nothing sets it in wave 1 | – | – |
| Menus | every v1 item from 6.2 present; an item whose closure is nil is disabled, and its help says why (`help(for:)`) | – | – |

## Contract slice

Lands verbatim from `docs/blueprints/library/contracts/` (blueprint 5.2 to
5.4), with three changes from the review:

1. **`FakeImporter` shows progress before it waits** (review note on J1 step
   6). It calls `progress(ImportProgress(done: 0, total: fresh.count))` before
   `FakeBehavior.perform`, and in `.slow` mode waits 2 s first and then 50 ms
   per file, so "Importing 1 of 24" stays on screen past S-L5's 100 ms delay.
   `.fail` still throws before any callback.
2. **A fixture that seeds only the fakes:** `shoot-unimported` gives
   `LibraryServices.fake(shoot photos)` with an empty catalog, so
   `FakeImporter`'s known-id filter leaves all 24 to import (J1 step 6 uses
   `-LibraryFixture shoot-unimported -LibraryFakeMode slow`).
3. **`CropGeometry.initial`'s comment** says what the code does: "centered,
   as large as fits on its aspect inside the same-aspect `straightenCrop`
   rect; conservative: a 1:1 at 5° on 6000 × 4000 is 3545 px, about 4% under
   the largest upright square (about 3690 px)". No signature changes.

`FakeUseCases.swift` is split in two files so each PR stays under 400 lines:
`Fakes/FakeUseCases.swift` (importer, thumbnails, culling, catalog coding)
and `Fakes/FakeRendering.swift` (loupe, develop, crop, exporter). The smoke
tests in `contracts/ContractSmokeTests.swift` land spread over the task tests
below, every one of them kept.

The catalog (blueprint 5.6), all in `LibraryCatalog.swift`, `public
internal(set)` (decision D6):

```swift
public internal(set) var services: LibraryServices            // excluded from ==
public internal(set) var history: CatalogHistory
public internal(set) var order: [String]                      // shown ids in sort order
public internal(set) var importState: ImportState             // .idle, .running(ImportProgress)
public internal(set) var importNotice: ImportNotice?
public internal(set) var thumbnails: [String: DisplayImage]
public internal(set) var thumbnailLongSide: Int
public internal(set) var pendingThumbnails: [String: ThumbnailRequest]
public internal(set) var autoAdvance: Bool                    // true
public internal(set) var loupeZoom: LoupeZoom                 // .fit, .actual, .scale(Double)
public internal(set) var loupeRender: RenderedPhoto?
public internal(set) var loupeRenderToken: Int
public internal(set) var loupeError: String?
public internal(set) var copiedSettings: DevelopSettings?
public internal(set) var cropDraft: CropSettings?
public internal(set) var exportState: ExportState             // .idle, .editing, .running, .finished
public internal(set) var catalogState: CatalogFileState      // .ready
public internal(set) var saveRevision: Int, savedRevision: Int
public internal(set) var saveError: String?
public internal(set) var showsTestValues: Bool                // -LibraryTestValues
public internal(set) var cullError: String?                   // a refused cull change (cull fills it)
public struct ThumbnailRequest: Hashable, Sendable { id: String; longSide: Int; token: Int }
```

`ThumbnailRequest` is declared here (thumbnails fills its use).
`cullError` is one property more than blueprint 5.6 lists: `-LibraryFakeMode
fail` makes `FakeCulling` refuse a change (5.1, "show a refused change"), and
without a stored home for the message cull would have to edit
`LibraryCatalog.swift` in wave 2. Existing
stored properties (`collections`, `selectedCollectionID`, `items`, `sort`,
`cellSize`, `selection`, `mode`, `focusedItemID`) become `public
internal(set)` too, and `editSelected` and `recount` become `internal`.

Methods and values the spine adds (blueprint 5.7):

| Method or value | File |
|---|---|
| `init(services: LibraryServices = .fake())`, hand-written `==` over every stored property but `services` | `LibraryCatalog.swift` |
| `rebuildOrder()`; `sortedItems` reads `order`; `select`, `open`, `showLoupe`, `stepLoupe`, `showGrid` use `order` | `LibraryOrder.swift` |
| `recordEdit(_ name: String, coalesceKey: String? = nil, ids: Set<String>, _ edit: (inout PhotoItem) -> Void)` (internal), `undo()`, `redo()`, `undoTitle`, `redoTitle`, `endCoalescing()` | `CatalogHistory.swift` |
| `PhotoItem.cullSummary`, `cellValue(for:)`, `cellHelp(for:)`, `loupeValue`, `histogramValue`, `catalogValue`, `notice: LibraryNoticeContent?`, `help(for member: String) -> String?` | `LibraryReadouts.swift` (new) |
| `LibraryKey` (`rating(Int)`, `pick`, `reject`, `unflag`, `crop`, `grid`, `confirm`, `first`, `last`), `LibraryKey(character:)`; `LibraryControlState` and `controlsJSON(_:)` | `LibraryKeys.swift` (new) |
| `LibraryLaunch(arguments:)`: `fixture`, `catalogDir`, `importFolder`, `importOnLaunch`, `exportTo`, `fakeMode`, `perfProbe`, `testValues`, `reduceMotion`, `windowSize` | `LibraryLaunch.swift` |
| `LibraryFixtures.photos(named:)`: `empty`, `samples`, `shoot`, `shoot-unimported`, `large` | `LibraryFixtures.swift` |

Every value is computed from stored state alone, so the features that fill
the state (thumbnails, loupe-viewport, develop, persist) never edit
`LibraryReadouts.swift`:

- `cellValue(for:)`: `unreadable` when `availability != .available`, else
  `ready W×H` when `thumbnails[id]` is set, else `loading`; then a space and
  `cullSummary` when it is not empty.
- `loupeValue`: nil outside the loupe; else `preview` or `full` from
  `loupeRender?.quality` (`loading` when nil), the render's `W×H`, the
  checksum when `showsTestValues`, the zoom (`fit`, `100%`, or the scale as a
  whole percent), then `cullSummary`.
- `histogramValue`: `mean 0.4213`: the mean of the three channels' bin means
  over 0...255, divided by 255, four decimals; `mean 0.0000` for an empty
  histogram (never NaN).
- `catalogValue`: `saved` when `saveRevision == savedRevision`, else `dirty`.
  Every catalog change bumps `saveRevision`: `recordEdit`, `load`, and the
  features' own changes (`appendImported`, `setDevelop`, …).
- `cellHelp(for:)`: "The file is missing." for `.missing`, the reason for
  `.unreadable(reason)`, else nil.
- `notice`: what the content's notice slot shows, first match wins:
  `catalogState.message` (error; action `.showCatalogInFinder` for
  `.damaged`), then `importNotice` (error or warning by `isError`; action
  `.showFailures` when it has failures), then `cullError` (error, no
  action). `LibraryNoticeContent` is `message`, `isError`, `action`,
  `source` (`.catalog`, `.import`, `.cull`). The spine's slot draws it;
  import (which owns `LibraryBrowser.swift` in wave 2) restyles it, and the
  close button calls the source's dismiss closure from `LibraryMenu`.
- `cullSummary`: "3 stars", "1 star", then ", Picked" or ", Rejected", then
  ", Red" (the label's title); empty for an unrated, unflagged, unlabelled
  photo. Stars are omitted at 0.

**`LibraryMenu`** (`LibraryMenus.swift`, SA-3). One sub-struct per area,
every member optional (nil disables the item, or ignores the key), so an
area fills its own sub-struct in its own `LibraryWindow+<Area>.swift` and
never edits the menu bar, the window or another area's file:

| Sub-struct (area file) | Members |
|---|---|
| `edit` (`+Edit`, spine) | `undo`, `redo`, `undoTitle`, `redoTitle`, `selectAll`, `deselect`, `loadSamples` |
| `file` (`+Import`, import) | `importFolder`, `importHelp`, `showImportFailures`, `dismissImportNotice` |
| `thumbnails` (`+Thumbnails`, thumbnails) | `visibleChanged([String])`, `cellSizeChanged(Int, scale: Int)` |
| `cull` (`+Cull`, cull) | `key(LibraryKey)`, `setRating(Int)`, `setFlag(PhotoFlag)`, `setLabel(PhotoLabel?)`, `toggleAutoAdvance`, `autoAdvance: Bool`, `dismissCullError` |
| `persist` (`+Persist`, persist) | `showCatalogInFinder` |
| `view` (`+Loupe`, loupe-viewport) | `grid`, `loupe`, `zoomIn`, `zoomOut`, `zoomToFit`, `actualSize`, `setSort`, `sort`, `first`, `last`, `zoomInTitle`, `zoomOutTitle` |
| `photo` (`+Develop`, develop; `+Crop`, crop) | `copySettings`, `pasteSettings`, `resetDevelop` (develop); `toggleCrop`, `cropTitle`, `applyCrop`, `resetCrop` (crop) |
| `export` (`+Export`, export) | `export`, `exportHelp` |

The `photo` sub-struct is built by two areas: `LibraryWindow` merges the
develop half and the crop half, so develop (wave 3) and crop (wave 4) each
fill only their own half. The spine's `+Loupe` stub keeps today's View
items working (Grid, Loupe, Sort By, Larger and Smaller Thumbnails as Zoom
In and Zoom Out in the grid); loupe-viewport replaces it in wave 2. The
spine's `+Cull` stub routes `setRating`, `setFlag` and `setLabel` to the
existing catalog methods so the #750 inspector and `testRateASelectedPhoto`
keep working; cull replaces it in wave 2.

## Pseudocode

```
LibraryCatalog.init(services = .fake()):  every stored property at its default; rebuildOrder()

rebuildOrder():                                            # SP-8
  order = shownItems.sorted(by: sort).map(\.id)            # O(n log n), once per change
  call sites: load, setSort, selectCollection, recount after editSelected/recordEdit
  (only when sort == .rating or the collection is Favorites, i.e. the change can reorder or hide)

recordEdit(name, coalesceKey, ids, edit):                  # SP-11
  before = items for ids;  apply edit;  after = items for ids
  if before == after: return                               # no step for a no-op
  saveRevision += 1
  if coalesceKey != nil && history.top.coalesceKey == coalesceKey && history.open:
     history.top.after = after                             # one step per drag
  else history.push(Step(name, before, after, coalesceKey)); history.redo = []
  recount(); rebuildOrder() when needed; select(selection)
undo(): pop step, put `before` back by id, push on redo; never moves the loupe (#426)
redo(): the reverse
undoTitle = history.top.map { "Undo " + $0.name }

uniquingIDs(photos):                                       # SP-10, #235
  pass 1: taken = the set of every photo's own id, first occurrence wins
  pass 2: each later duplicate gets the lowest "<id>#n" (n ≥ 2) not in taken; insert it

selectCollection(id):                                      # SP-9, #156 (unless #217 merged)
  ...; rebuildOrder(); if mode == .loupe && !order.contains(focusedItemID): mode = .grid; focusedItemID = nil

LibraryKey(character c):                                   # SP-13
  "0"..."5" -> rating(n); p -> pick; x -> reject; u -> unflag; r -> crop; g -> grid
  Return, Home, End come as KeyEquivalent, mapped by LibraryKey(special:)

LibraryWindow.onKeyPress (macOS, SA-4):
  guard grid or loupe has focus, no text field focused
  switch LibraryKey(press):
    rating/pick/reject/unflag -> menus.cull.key?(key)      # cull fills in wave 2
    first/last                -> menus.view.first?() / last?()    # loupe-viewport, wave 2
    crop                      -> menus.photo.toggleCrop?() # crop, wave 4
    confirm                   -> menus.photo.applyCrop?() ?? (grid: .ignored, so ThumbnailGrid opens the anchor)
    grid                      -> menus.view.grid?()
  nil closure -> .ignored

LibraryLaunch(arguments):                                  # SP-12
  scan pairs; unknown flags ignored; -LibraryFakeMode accepts ok|fail|slow else .ok;
  -LibraryWindowSize "WxH" with both ≥ 1 else nil
services(for launch, platform): fixture != nil ? .fake(LibraryFixtures.photos(fixture), mode)
                                              : .live(decoder:, writer:, store:)
initial photos: fixture == "shoot-unimported" ? [] : LibraryFixtures.photos(fixture)
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: spine`, `Fast-Check: pass`,
`Head:`. SJ-2 also carries `feature-done`. Model tasks (SP) build and test on
Linux; app tasks (SA, SJ) build only in the macOS job on `dev`, so they copy
the shape of a view that already builds and keep each change small.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| SP-1 | – | Shared values and the notice and file-state texts, verbatim | `Sources/LibraryModel/Contracts/LibraryValues.swift`, `Sources/LibraryModel/Contracts/StateValues.swift`, `Tests/LibraryModelTests/LibraryValuesTests.swift` | – |
| SP-2 | – | Develop values; `PhotoItem` grows `path`, `pixelSize`, `develop`, `availability` with defaults | `Sources/LibraryModel/Contracts/DevelopValues.swift`, `Sources/LibraryModel/PhotoItem.swift`, `Tests/LibraryModelTests/LibraryPhotoItemTests.swift` | SP-1 |
| SP-3 | – | The protocols (with the `initial` comment fix) and `SampleImage` | `Sources/LibraryModel/Contracts/LibraryContracts.swift`, `Sources/LibraryModel/SampleImage.swift`, `Tests/LibraryModelTests/LibraryContractsTests.swift` | SP-2 |
| SP-4 | – | Fakes: support, platform, importer (progress first), thumbnails, culling, coding | `Sources/LibraryModel/Fakes/FakeSupport.swift`, `Sources/LibraryModel/Fakes/FakePlatform.swift`, `Sources/LibraryModel/Fakes/FakeUseCases.swift`, `Tests/LibraryModelTests/LibraryFakesTests.swift` | SP-3 |
| SP-5 | – | Fakes: loupe, develop, crop, exporter | `Sources/LibraryModel/Fakes/FakeRendering.swift`, `Tests/LibraryModelTests/LibraryFakeRenderingTests.swift` | SP-3 |
| SP-6 | – | The eight live stubs and `LibraryServices` (`.fake`, `.live`) | `Sources/LibraryModel/Live/` (8 files), `Sources/LibraryModel/LibraryServices.swift`, `Tests/LibraryModelTests/LibraryServicesTests.swift` | SP-4, SP-5 |
| SP-7 | – | Every stored property, the state enums, `init(services:)`, the hand-written `==` | `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/LibraryModelTests/LibraryCatalogTests.swift` | SP-6 |
| SP-8 | – | The cached `order` and `Budget.swift` | `Sources/LibraryModel/LibraryOrder.swift`, `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/LibraryModelTests/LibraryOrderTests.swift`, `Tests/LibraryModelTests/Budget.swift` | SP-7 |
| SP-9 | #156 (refs; skip if #217 merged) | Leave the loupe when the new collection hides its photo | `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/LibraryModelTests/LibraryCollectionSwitchTests.swift` | SP-8 |
| SP-10 | #235 (closes) | `uniquingIDs` in two passes | `Sources/LibraryModel/LibraryCatalog.swift`, `Tests/LibraryModelTests/LibraryPhotoIDTests.swift` | SP-9 |
| SP-11 | – | `CatalogHistory`: named steps, coalescing, undo and redo | `Sources/LibraryModel/CatalogHistory.swift`, `Tests/LibraryModelTests/LibraryHistoryTests.swift` | SP-8 |
| SP-12 | – | Launch arguments and fixtures (`shoot`, `shoot-unimported`, `large`); samples get `pixelSize` 4032 × 3024 | `Sources/LibraryModel/LibraryLaunch.swift`, `Sources/LibraryModel/LibraryFixtures.swift`, `Sources/LibraryModel/LibrarySample.swift`, `Tests/LibraryModelTests/LibraryLaunchTests.swift` | SP-6 |
| SP-13 | – | Readouts (`cullSummary`, `cellValue`, `loupeValue`, `histogramValue`, `catalogValue`, `help(for:)`), keys and the controls JSON | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/LibraryKeys.swift`, `Tests/LibraryModelTests/LibraryReadoutsTests.swift`, `Tests/LibraryModelTests/LibraryKeysTests.swift` | SP-7 |
| SA-1 | – | The pure split: scene, window, browser, grid, image helper, inspector in their own files; no behavior change | `Sources/LibraryApp/LibraryApp.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryBrowser.swift`, `Sources/LibraryApp/LibraryGrid.swift`, `Sources/LibraryApp/DisplayImage+Image.swift`, `Sources/LibraryApp/LibraryInspector.swift` | – |
| SA-2 | – | One `Window` scene (D2); services from the launch arguments; the three platform stubs | `Sources/LibraryApp/LibraryApp.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/Platform/ImageIODecoder.swift`, `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Sources/LibraryApp/Platform/CatalogStore.swift` | SA-1, SP-12 |
| SA-3 | – | `LibraryMenu` with one sub-struct per area, and every v1 menu item (6.2) with its help | `Sources/LibraryApp/LibraryMenus.swift`, `Sources/LibraryApp/LibraryCommands.swift` | SA-2 |
| SA-4 | – | The nine area files (`LibraryWindow+Edit` … `+Export`), each a stub returning its sub-struct; Edit wires undo, redo and samples, Loupe keeps today's View items; the window's `onKeyPress` routes every single key | `Sources/LibraryApp/LibraryWindow.swift`, `Sources/LibraryApp/LibraryWindow+Edit.swift`, `+Import`, `+Thumbnails`, `+Cull`, `+Persist`, `+Loupe`, `+Develop`, `+Crop`, `+Export` (`.swift` each) | SA-3, SP-11, SP-13 |
| SA-5 | – | Content: Import Folder… empty state, the notice slot, the Preview data pill, the export sheet's presentation | `Sources/LibraryApp/LibraryBrowser.swift`, `Sources/LibraryApp/LibraryStatusBar.swift`, `Sources/LibraryApp/LibraryExportSheet.swift`, `Sources/LibraryApp/LibraryWindow.swift` | SA-4 |
| SA-6 | – | Inspector tabs and header; Develop and Crop stubs; the crop overlay stub in the loupe; the loupe photo's value | `Sources/LibraryApp/LibraryInspector.swift`, `Sources/LibraryApp/DevelopInspector.swift`, `Sources/LibraryApp/CropInspector.swift`, `Sources/LibraryApp/LibraryCropOverlay.swift`, `Sources/LibraryApp/LibraryLoupe.swift` | SA-4 |
| SA-7 | – | `library.controls` on the window, identifiers on the spine's controls, and the spine's snapshots | `Sources/LibraryApp/LibraryControls.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Tests/AppSnapshotTests/LibraryShellSnapshots.swift` | SA-5, SA-6 |
| SJ-1 | – | The four journeys on `-LibraryFixture samples`; J0; J10's app-owned items | `UITests/LibraryJourneyTests.swift` | SA-7 |
| SJ-2 | – (`feature-done`) | J11 and the `LibraryFiles` helpers (in `LibraryJourneyTests.swift`, or `+Shell.swift` and `+Files.swift` once #333 has merged) | `UITests/LibraryJourneyTests.swift`, `UITests/LibraryJourneyTests+Shell.swift`, `UITests/LibraryJourneyTests+Files.swift` | SJ-1 |

Order. SP-1 to SP-6 are a chain (each compiles on the one before). SP-7,
SP-8, SP-9 and SP-10 stack on `LibraryCatalog.swift`. SP-11, SP-12 and SP-13
can run beside them once their base is in. SA-1 needs nothing and can go
first; the app chain SA-2 to SA-7 stacks on `LibraryWindow.swift`. Sizes:
SP-6 is about 270 lines of stubs and wiring plus its tests (10 files);
SA-4 is 10 files of about 20 lines each plus the key routing. If a task nears
400 lines, the lead splits it by file before opening the PR.

Existing test files the spine owns (`LibraryCellSizeFuzzTests`,
`LibraryCollectionEmptinessTests`, `LibraryEmptyCollectionTests`,
`LibraryGridEdgeTests`, `LibraryGridTests`, `LibraryPhotoIDFuzzTests`) must
pass unchanged after SP-7 and SP-8; that is part of their acceptance. The
loupe and metadata tests (`LibraryLoupeTests`, `LibraryMetadataTests`) and
the four existing `Library*Snapshots.swift` files belong to wave-2 features
and must also pass and compile unchanged.

**#217.** If PR #217 merges before SP-9, SP-9 is dropped and SP-7 to SP-10
rebase onto it. If SP-9 merges first, #217 conflicts and its author rebases
or closes it as superseded; the lead comments once on #217 saying so.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SP-1 | `LibraryValuesTests`: `PixelSize(6000, 4000).fitting(longSide: 1024)` is 1024 × 683 and never enlarges; `ThumbnailBucket.longSide(forCell: 320, scale: 2)` is 1024 and `(80, 1)` is 128; `DisplayImage` refuses a byte count that isn't w·h·4; `PhotoFileKind.kind(forFileName: "a.HEIF")` is `.heic` and `".jpg"` is nil; every `LibraryError.message`, `ImportNotice.message` (26 added and 1 failure, 0 added, only failures), `ExportSummary.message` and `CatalogFileState.message`/`canSave` equals the blueprint's text | a text or a size rule differs from the contract |
| SP-2 | `LibraryPhotoItemTests`: an existing `PhotoItem(name:captureDate:color:)` call compiles and has `path == nil`, `pixelSize` 4032 × 3024, neutral `develop`, `.available`; `DevelopSettings.setting(.exposure, to: .nan)` is 0 and `to: 9` is 5; `pastingAdjustments` keeps the crop; `CropAspect.threeTwo.ratio(for: 4000 × 6000)` is 2/3 | a default breaks an existing caller, or a clamp or ratio rule differs |
| SP-3 | `LibraryContractsTests`: `CullChange.flag(.reject).undoName` is "Reject" and the other four names match; `ExportOptions(longEdge: 99999, quality: 120)` clamps to 16384 and 100; `SampleImage.image(for:longSide: 64)` is 64 × 48 and its first pixel equals the photo's color, its last half of it (±1) | a name, clamp or sample picture differs |
| SP-4 | `LibraryFakesTests`: in `.slow` mode the importer's first `progress` call arrives before 100 ms and reads "Importing 1 of 24", and `added` is called 24 times; in `.fail` it throws `unreadableFolder` with no callback; `FakeDecoder.scan` lists the fixture; `FakeJPEGWriter` refuses a second write to one name; `FakeCatalogStore.setAside` returns `catalog.json.bad`; `FakeCulling` refuses a rating of 6 and advances on the last photo to itself | progress waits for the 2 s, a fake ignores its mode, or a rule differs |
| SP-5 | `LibraryFakeRenderingTests`: `FakeLoupe` with exposure +0.01 lifts every channel byte by 1 and its histogram sums to the pixel count; in `.fail` it throws `renderFailed("the preview failed on purpose")`; `FakeCrop.initial(.square, 0, 6000 × 4000)` has rect width 4000/6000; `FakeExporter.plan` names `IMG_0001 2.jpg` when `IMG_0001.jpg` exists | a fake stops showing a change a journey's (F) step asserts |
| SP-6 | `LibraryServicesTests`: every member of `.fake(shoot)` answers once (the blueprint's `everyFakeAnswers`); `.live(...)` lists a reason for all eight `Live…` types and `help`-style texts are non-empty; `LiveThumbnails` and `LiveLoupeImaging` draw a sample (no `path`) and throw their reason for a photo with a `path`; `LiveCulling` applies a rating (the #750 inspector keeps working) | a stub throws for a sample, a reason is missing, or a fake isn't called |
| SP-7 | `LibraryCatalogTests`: two catalogs that differ only in `services` (`.fake()` vs `.fake(mode: .fail)`) are `==`; two that differ in any one other stored property (each tried) are not; `LibraryCatalog()` builds with fake services and `autoAdvance == true`, `catalogState == .ready` | `==` compares services or skips a property |
| SP-8 | `LibraryOrderTests`: `order` equals the old `sortedItems` ids after load, each sort, each collection, and a rating change under `.rating`; `orderRebuildWithinBudget`: rebuilding `order` for `large` (10,000) has median ≤ 50 ms in debug (5 ms release target, QB-LIB-3 model half), printed as a `LIBRARY-BUDGET` line; every existing grid, cell-size and emptiness test passes unchanged | the cache goes stale after a change, or the rebuild misses its budget |
| SP-9 | `LibraryCollectionSwitchTests`: the issue's repro (open B, choose Favorites) gives grid, no focused photo, empty selection; a still-shown photo keeps the loupe | the loupe stays on a hidden photo |
| SP-10 | `LibraryPhotoIDTests`: loading `["a#2", "a", "a"]` keeps `a#2` and renames the second `a` to `a#3`; every existing id test passes | a photo's own id is taken by an earlier duplicate |
| SP-11 | `LibraryHistoryTests`: a recorded rating edit gives `undoTitle == "Undo Set Rating"`, undo restores the photo exactly and leaves the loupe where it was, redo reapplies; three edits with one `coalesceKey` are one step until `endCoalescing()`; a no-op edit records nothing; a new edit clears redo | a gesture becomes two steps, undo moves the loupe, or a no-op is recorded |
| SP-12 | `LibraryLaunchTests`: the blueprint's argument table parses (every flag, `-LibraryFakeMode bogus` is `.ok`, `-LibraryWindowSize 0x5` is nil); `shoot` has 24 photos, 8 portrait 4000 × 6000, `IMG_0024` first by capture date and `IMG_0001` first by name; `shoot-unimported` gives 24 fake photos and an empty catalog; `large` has 10,000 unique ids; samples have `pixelSize` 4032 × 3024 | a fixture's shape or order differs, or a flag is dropped |
| SP-13 | `LibraryReadoutsTests`: a 3-star picked red photo's `cullSummary` is "3 stars, Picked, Red"; `cellValue` reads `loading`, then `ready 256×171 …` after a thumbnail is set, `unreadable` for a missing file; `loupeValue` under `showsTestValues` includes the 16-digit checksum and `100%` at `.actual`; `histogramValue` of `.empty` is `mean 0.0000`; `catalogValue` flips to `dirty` when `saveRevision` moves; `cellHelp` of a missing photo is "The file is missing."; `notice` prefers a damaged catalog over an import notice over `cullError`. `LibraryKeysTests`: "3" is `rating(3)`, "P" and "p" are `pick`, "7" is nil; `controlsJSON` of one enabled and one disabled control round-trips through `JSONDecoder` with the reason | a value's text differs from blueprint 4.1, or a key maps to the wrong area |
| SA-1 | The next macOS run: `library-grid-*`, `library-loupe-*`, `library-empty-*`, `library-metadata-*` PNGs unchanged; the existing journeys pass | the split changes a pixel or breaks a call site |
| SA-2 | macOS: `testLaunchShowsWindowShell` passes; File > New Window is gone (one `Window` scene); with `-LibraryFixture samples` the grid shows 60 photos at launch | a second window can open, or the fixture isn't loaded |
| SA-3 | J10 (SJ-1) lists every 6.2 item; on Linux, `LibraryKeysTests` already covers the key table the help tags name | an item is missing or a nil closure leaves an item enabled |
| SA-4 | J0 step 3 (Undo and Redo disabled on launch); `testRateASelectedPhoto` still rates (the stub culling area keeps the inspector working) | a stub breaks today's behavior, or a key reaches the wrong area |
| SA-5 | `LibraryShellSnapshots` (SA-7) `library-empty-import`, `library-notice-damaged`, `library-notice-newer`, `library-preview-data` | the empty state still offers Load Sample Photos, or a notice or the pill is missing |
| SA-6 | `LibraryShellSnapshots` `library-inspector-none`; `testLoupeStepsAndReturnsToTheGrid` reads `library.loupe.photo`'s value ending in the photo's `cullSummary` | the inspector still shows a `SurfaceCard`, or the loupe has no value |
| SA-7 | `LibraryShellSnapshots` (Light and Dark, five states); J11 (SJ-2) reads `library.controls` | a snapshot is missing or the JSON doesn't decode |
| SJ-1 | J0, J10 and the four switched journeys pass on the macOS run | a journey still clicks "Load Sample Photos" in the content |
| SJ-2 | J11 passes; a helper smoke step writes `writeShoot` into a temp folder and finds 24 `.jpg` files starting `FF D8` | an enabled control does nothing, a disabled one has no reason, or the helpers write nothing |

## Quality tests

| quality row | budget (CI gate) | test |
|---|---|---|
| QB-LIB-3 model half (order) | rebuild `order` for 10,000 ≤ 5 ms release, ≤ 50 ms debug | `LibraryOrderTests.orderRebuildWithinBudget` over `Budget.swift` |
| QB-F3 one gesture, one step | every recorded edit is one named step; undo restores exactly | `LibraryHistoryTests` |
| QB-F1 no dead controls | every enabled control acts, every disabled one says why | J11 `testEveryControlActsOrSaysWhy` |
| QB-V5 visible states | five spine states, Light and Dark (four appearances once #332 lands) | `LibraryShellSnapshots` |

`Budget.swift` (blueprint 7): `Budget.measure(_ name:, runs: 20, _ body:)`
returns median and p95, prints one `LIBRARY-BUDGET <area> <row> median=… p95=…`
line and appends it to `.build/snapshots/library-budget-<area>.txt`. Every
later feature's budget file uses it.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by SJ-2 is green: J0,
  J10, J11, the four switched journeys, and every other app's journeys.
- **Audit zero new:** no `library` count over `UITests/audit-baseline.json`
  (contrast 2, identifier 16, offscreen 16, unnamed 1), and the spine's new
  screens (`empty`, `file-menu-empty`, the inspector header) add nothing to
  any count in the contact sheet's audit table.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  one line per journey and the audit counts.
