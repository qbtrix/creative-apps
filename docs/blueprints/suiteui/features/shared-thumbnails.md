# Feature packet: shared-thumbnails

**Feature:** one place for previews. CoreAsset's disk `ThumbnailStore`
(creative-core, already at the pin and imported by no app today) lives at
`AfterGlow/Thumbnails/` under the suite's support root. SuiteShell's
`ThumbnailWriter` is the live `ThumbnailPublishing` over it, so the home's
cards finally show each document's picture (the slot says "Not connected
yet" today). Photo publishes a preview when it saves. Library's grid keeps
its in-memory LRU and gains the store as a disk tier, so a relaunch shows
the grid without decoding every photo again.
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/shared-thumbnails`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 12). Labels `beta` and `p1` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #12; feature map row `suiteui/shared-thumbnails`; real job RJ-X47
(new); SuiteShell's `ThumbnailsSlot` ("Not connected yet (recents-open-in)":
no packet owns that writer, so this one does).

**Depends on:** shared-codecs SC-a (ST-2 edits `Package.swift` and
`project.yml` after it); adopt-kernel-autosave AK-a (`SuiteLocations.appFolder`)
for ST-5, and its AK-photo before ST-7 (both edit `PhotoWindow+File.swift`).
creative-core: none (`ThumbnailStore` is at `2258b62`).

**Hand-offs** (cross-line):
- **ST-m:** `LiveThumbnails.swift` is library/spine's (building) and raw
  RW-3's. ST-6 adds a new adapter file and a two-line call in it; it starts
  after spine's feature-done.
- **ST-u:** `HomeGrid.swift` is suite/home's (built).
- **ST-z:** `PhotoWindow+File.swift` is photo/history-panel PH-m's and
  photo/file-flow PF-m's; `LibraryWindow.swift` is library/spine's.

**Rule 20.** One preview store (CoreAsset `ThumbnailStore`), one publishing
contract (SuiteModel `ThumbnailPublishing`), one writer (SuiteShell
`ThumbnailWriter`). Library's grid state (`LibraryThumbnails.swift`: which
cells to request, staleness, eviction) is view state, not a store, and stays.

**Deleted app-local files: none.** The duplicate here is a missing shared
store, not an extra copy: Library's LRU becomes the memory tier in front of
the shared disk store, and Photo's `LiveArchive` keeps the
`Thumbnails/thumbnail.png` that the OpenRaster format itself requires. So
`Tests/canonical-baseline.txt` does not change; the new Library file is an
adapter (`LiveThumbnailStoreAdapter.swift`), which `check-dup-logic` never
counts.

**C4:** `suite-shell/shell-documents.json` already lists
`ThumbnailWriter.swift`; ST-8 marks it built and names CoreAsset.

**Clean-room.** The home's card follows the HIG's collection rules; the
store's rules are CoreAsset's documented contract.

Blueprint sections: suite.md 2.3 and 2.6 (shell, store); library.md
(Grid); photo.md (Save).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| ST-a | SuiteShell and LibraryModel link CoreAsset, `ThumbnailPublishing` gains a read, `ThumbnailWriter` and Library's disk tier are declared as stubs, and their tests are written, disabled. | ST-1, ST-2 | MJ-ST | shared-codecs:SC-a (ST-2: `Package.swift`, `project.yml`, A/C first) |
| ST-u | The home's recent-document cards show each document's preview from the publishing contract on the fake, with a placeholder when there is none, within the render budget. | ST-3, ST-4 | HJ-ST | ST-a |
| ST-m | The writer stores and reads previews in `AfterGlow/Thumbnails/` within its byte budget, and Library's thumbnails read the disk store before decoding and write after, keyed so a changed file or develop setting never shows a stale picture. | ST-5, ST-6 | MJ-ST | ST-a; adopt-kernel-autosave:AK-a (ST-5); library spine (ST-6, cross-line hand-off) |
| ST-z | The thumbnails slot is live, Photo publishes a preview on save, Library builds its thumbnails over the shared store, the home shows real previews, and the feature is built. | ST-7, ST-8 | HJ-ST, MJ-ST | ST-u, ST-m; adopt-kernel-autosave:AK-photo (ST-7, `PhotoWindow+File.swift`) |

ST-u waits only on ST-a (rule 18) and runs on `FakeThumbnails`; ST-m never
waits on ST-u. `ThumbnailWriter` builds only on macOS: its plan runs on the
supervisor's Mac before `Belt-Slice-Done:` (suiteui waves, Q10).

## Journey steps

1. Launch the suite with a fixture store holding three recent documents
   (ST-4, `HomePreviewsJourneyTests.testHomeShowsDocumentPreviews`, skipped
   until ST-8): the home's Recent cards show the three fixture previews; a
   document with none shows its app's mark.
2. On live (ST-8): open `beach.png` in Photo, save as `Beach.ora`, quit
   Photo: the home's newest card shows the beach.
3. `MJ-ST` (Linux): `LibraryThumbnailDiskTests`: import 50 fixture photos,
   draw the grid (50 decodes), rebuild the services on the same folder, draw
   again: zero decodes; change one photo's exposure: one decode.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X47 | adds, closes with `suiteui/shared-thumbnails` | C | `Tests/RealJobs/library/relaunch-grid/relaunch-grid.jobs.json`: `file.load-samples`, `view.grid`, `thumbnails.stats`; a second run on the same `-SuiteSupportDir`: `view.grid`, `thumbnails.stats`; `photo.reset-develop` on one, `thumbnails.stats` | the samples |

Trap: the relaunch decodes every photo again (no disk tier), or a changed
develop setting shows the old picture from disk. Assertion: the second run's
stats read `decoded: 0, fromDisk: <visible count>`; after the reset,
`decoded: 1`. Mutations: `LibraryModel.LiveThumbnailStoreAdapter.json`
(develop token left out of the content key → `.staleAfterDevelop`; store
read skipped → `.relaunchDecodesNothing`). `thumbnails.stats` is a query ST-6
adds to Library's catalog (Library's id list gains it). Its check is written by ST-1 and stays disabled
(`waits_on: ST-1`).

## Screens and states

`home-recents-previews` (light and dark: three cards with previews, one
without), `home-recents-previews-live` (ST-8, after the Photo save).

## Contract slice

```swift
// Sources/SuiteModel/Contracts/ThumbnailPublishing.swift (ST-2). Linux-safe.
public protocol ThumbnailPublishing: Sendable {
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String   // unchanged
    /// The newest preview published for `ref`, or nil. Never decodes the document.
    func preview(for ref: SuiteDocumentRef) async -> Data?
}
// Sources/SuiteShell/ThumbnailWriter.swift (ST-2 stub, ST-5 body). macOS.
public final class ThumbnailWriter: ThumbnailPublishing {
    /// Over CoreAsset's ThumbnailStore at `<support>/Thumbnails`, `budgetBytes` 256 MB.
    public init(folder: String, budgetBytes: Int) throws
}
// Sources/LibraryModel/Live/LiveThumbnailStoreAdapter.swift (ST-2 stub, ST-6 body). Linux-safe.
/// Library's disk tier: CoreAsset's store keyed by photo id, content (file size, modification time,
/// develop token) and size class (the grid bucket).
public struct LiveThumbnailStoreAdapter: Sendable {
    public init(folder: String, budgetBytes: Int) throws
    public func read(id: String, content: String, bucket: Int) -> Data?
    public func write(_ png: Data, id: String, content: String, bucket: Int)
    public var stats: (decoded: Int, fromDisk: Int) { get }
}
```

## Pseudocode

- **Library.** In `LiveThumbnails.thumbnail(for:)`: memory LRU hit → done;
  else `adapter.read` → decode the stored PNG (cheap, bucket-sized) and put it
  in the LRU; else decode the file as today, then `adapter.write`. The content
  key changes when the file or its develop settings change, so a stale entry
  is never read (the store's LRU evicts it later).
- **Photo.** After a successful save, the `.ora`'s own 256 px thumbnail bytes
  are published for the document's `SuiteDocumentRef`, off the main actor.
- **Home.** Each Recent card asks `preview(for:)` once when it appears and
  caches the decoded image for the window's life; nil shows the app's mark.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| ST-1 | – | **Tests first.** `ThumbnailWriterTests` (macOS) and `LibraryThumbnailDiskTests` (Linux), both disabled (`waits on ST-5`, `waits on ST-6`); RJ-X47's job folder | `Tests/AppSnapshotTests/ThumbnailWriterTests.swift`, `Tests/LibraryModelTests/LibraryThumbnailDiskTests.swift`, `Tests/RealJobs/library/relaunch-grid/relaunch-grid.jobs.json` | – | ~220, 2 |
| ST-2 | – | CoreAsset linked into SuiteShell and LibraryModel (`Package.swift`, `project.yml`); `preview(for:)` on the contract and `FakeThumbnails` (a fixture PNG per ref); `ThumbnailWriter` and `LiveThumbnailStoreAdapter` as stubs. A supervisor merge | `Package.swift`, `project.yml`, `Sources/SuiteModel/Contracts/ThumbnailPublishing.swift`, `Sources/SuiteModel/Fakes/FakeThumbnails.swift`, `Sources/SuiteShell/ThumbnailWriter.swift`, `Sources/LibraryModel/Live/LiveThumbnailStoreAdapter.swift` | ST-1 | ~220, 7 |
| ST-3 | – | **The home's previews on the fake.** Each Recent card shows `preview(for:)`, the app's mark when nil, identifiers `home.recent.preview.<n>` | `Sources/AfterGlowApp/HomeGrid.swift`, `Tests/AppSnapshotTests/HomeGridPreviewTests.swift` | ST-2 | ~200, 2 |
| ST-4 | – | Snapshots, the render budget test, the journey written and skipped (`XCTSkip("waits on ST-8")`) | `Tests/AppSnapshotTests/HomePreviewSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHomePreviewTests.swift`, `UITests/AfterGlowJourneyTests+Previews.swift` | ST-3 | ~200, 3 |
| ST-5 | – | `ThumbnailWriter` body over `ThumbnailStore` at `appFolder`'s sibling `<support>/Thumbnails`; publish and preview; turns on `ThumbnailWriterTests` | `Sources/SuiteShell/ThumbnailWriter.swift`, `Tests/AppSnapshotTests/ThumbnailWriterTests.swift`, `Tests/mutations/SuiteShell.ThumbnailWriter.json` | ST-2 | ~260, 3 |
| ST-6 | – | Library's disk tier: the adapter's body, `LiveThumbnails` reads before decoding and writes after, the `thumbnails.stats` query in Library's catalog; turns on `LibraryThumbnailDiskTests` | `Sources/LibraryModel/Live/LiveThumbnailStoreAdapter.swift`, `Sources/LibraryModel/Live/LiveThumbnails.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/LibraryThumbnailDiskTests.swift`, `Tests/mutations/LibraryModel.LiveThumbnailStoreAdapter.json` | ST-2 | ~300, 7 |
| ST-7 | – | **Live.** `ThumbnailsSlot` builds `ThumbnailWriter` (`thumbnailsIsLive = true`); Photo publishes its `.ora` thumbnail after each save; Library's window builds `LiveThumbnails` over the adapter in `<support>/Library/Thumbnails` | `Sources/SuiteShell/Live/ThumbnailsSlot.swift`, `Sources/PhotoApp/PhotoWindow+File.swift`, `Sources/LibraryApp/LibraryWindow.swift`, `Tests/AppSnapshotTests/PhotoPublishesPreviewTests.swift` | ST-5, ST-6 | ~180, 4 |
| ST-8 | – | The journey turned on live; the C4 part names CoreAsset and the writer as built; `status: built`; `feature-done` | `UITests/AfterGlowJourneyTests+Previews.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-documents.json`, `docs/blueprints/suiteui/features/shared-thumbnails.wave.json` | ST-7, ST-4 | ~60, 3 |

## Build waves

- Wave 1: ST-1. Independent in this wave: ST-1 alone.
- Wave 2: ST-2. Independent in this wave: ST-2 alone.
- Wave 3: ST-3, ST-5, ST-6. Independent in this wave: all.
- Wave 4: ST-4, ST-7. Independent in this wave: both.
- Wave 5: ST-8. Independent in this wave: ST-8 alone.

Longest chain: ST-1 → ST-2 → ST-5 → ST-7 → ST-8 (5). Chain of 5: the tests before the stubs, the stubs before the writer's body, the body before the live wiring, and the live journey last.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| ST-1 | compiles, disabled by name | – | – (tests) |
| ST-2 | both platforms build; SuiteModel's fake tests green | the fake returns nothing for a fixture ref | – (stubs) |
| ST-3 | `HomeGridPreviewTests`: three fixture refs show three images; a nil shows the mark; a card asks once | a card is blank or asks on every body | – (UI) |
| ST-4 | `HomePreviewSnapshots`; `RenderBudgetHomePreviewTests.scrollRecentsInThreeBodies` | budget over | – (UI) |
| ST-5 | `ThumbnailWriterTests`: publish then preview returns the bytes; a second publish replaces; past the budget the oldest goes; `-SuiteSupportDir` reaches the folder | a preview is lost, stale or written outside the root | `SuiteShell.ThumbnailWriter`: key ignores the file key → `.perDocument`; folder on the real root under the flag → `.flagReachesStore` |
| ST-6 | `LibraryThumbnailDiskTests` (MJ-ST step 3); RJ-X47 on Linux | a relaunch decodes again, or a developed photo shows its old thumbnail | `LibraryModel.LiveThumbnailStoreAdapter`: develop token left out of the key → `.staleAfterDevelop`; read skipped → `.relaunchDecodesNothing` |
| ST-7 | `PhotoPublishesPreviewTests`: a save publishes once, off the main actor; a failed save publishes nothing | a preview is published for an unsaved or failed save | – (App wiring) |
| ST-8 | `HJ-ST` steps 1 and 2 on live; `scripts/waves render --dry-run` | the home shows no preview after a save | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: scroll the home's Recents through 40 cards | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHomePreviewTests.scrollRecentsInThreeBodies` |
| relaunch | a relaunched Library grid decodes no unchanged photo | `LibraryThumbnailDiskTests`, RJ-X47 |
| bounded disk | the store stays under 256 MB (Library's under its own 512 MB) | `ThumbnailWriterTests.budget` |
| off the main actor | publish and the disk read run off main | `PhotoPublishesPreviewTests.offMain` |
| no dead controls; VoiceOver | each card reads "<name>, <app>, edited <time>" with or without a preview | `testHomeShowsDocumentPreviews` |

## Done check

Per slice: ST-m green on the Linux job (`Mutate:` clean; the writer's plan on
the supervisor's Mac); ST-u through the feel gate with its `Mac-Finish:`
line; ST-z with the home journey green on live and RJ-X47 green on Linux.
Then `Belt-Contact-Sheet:` with `home-recents-previews-*`.
