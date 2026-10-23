# Feature packet: file-flow (Library)

**Feature:** A drop of photos or a folder on Library imports them (the existing import, one step) and selects them; another app's document goes to that app. A thumbnail drags out to Photo, Design or the Finder as the file and a PNG. File > Open In ▸ Photo opens the loupe's photo in Photo. Library has no Open Recent (it is one catalog); its File menu adds only Open In.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7). Labels `beta` and `p1` when filed.

**Covers:** feature map `library/file-flow` (adopter of `suite/file-flow`);
#864 (Library: adopt the suite — `SuiteDocumentHost` and `.suiteApp`; this
packet's LF-1 and LF-2 do it, and LF-3 closes it); real job RJ-L42.

**Depends on:** `suite/file-flow` **SF-a** (cross-line: `DropPlan`,
`FileFlowTarget`, `SuiteFileCommands`, `.suiteFileDrop`,
`SuiteDocumentsBridge`); LF-3 needs **SF-5** and **SF-6**, LF-4 **SF-7**,
LF-7 **SF-8**. Same line: spine (building), import and thumbnails (built) own the app files, so LF-a waits on them; the held p3 features filters-collections (FC-a, FC-c) and metadata-more (MD-e) now wait on LF-a for `LibraryCommands.swift` and `LibraryGrid.swift`. `tone-controls`'s LT-m owns `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`, so LF-3 waits on it. `LibraryFileFlow+Kernel.swift` is listed in `library/c4-planned.json` (library-import) with this packet.

**Rule 20.** The drop's import is Library's existing import; the drag-out uses `PasteboardCoding`'s representations. Library's recents are the suite list's (it notes catalog opens there for the home), with no menu of its own.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LF-a | Library conforms to `SuiteDocumentHost` and `FileFlowTarget` on stubs, its scene adopts `.suiteApp`, and its File menu and window use the suite's Open Recent, Open In and drop on the fakes. | LF-1, LF-2 | MLF | SF-a (cross-line); spine, import, thumbnails |
| LF-u | The menu and the drop mark have snapshots and a render budget, and the journey is written. | LF-5, LF-6 | LFJ1 | LF-a |
| LF-m | Library imports dropped photos and folders as one step, accepts import and open hand-offs, notes its catalog opens in the suite list, and drags thumbnails out as the file and a PNG. | LF-3, LF-4 | MLF | LF-a; SF-5, SF-6, SF-7 (cross-line); tone-controls:LT-m; cull-finish:DR-m (LF-3, A/C first) |
| LF-z | Drop, Open Recent and Open In run on live services, the journey passes, and the feature is built. | LF-7, LF-8 | LFJ1 | LF-u, LF-m |

LF-u waits only on LF-a (rule 18); LF-m never waits on LF-u. LF-m is marked `"ui": true` because LF-4 changes `LibraryWindow+Import.swift` in LibraryApp. MLF is the Model walk in `LibraryFileFlowTests` (Linux).

## Journey steps

1. Launch Library with the sample catalog (LF-2,
   `LibraryFileFlowJourneyTests.testDropToImportAndDragOut`).
2. Drop a folder of three JPEGs on the grid: the mark reads "Import 3
   photos"; on release they import and are selected; Undo removes them in
   one step.
3. Drop `Intro.halo`: Halo opens it.
4. Drag a thumbnail onto Photo (SJ14's half): Photo places it as a layer.
5. File > Open In ▸ Photo with the loupe open: Photo opens that photo.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L42 | adds, closes with `library/file-flow` | C | `Tests/RealJobs/library/drop-import/drop-import.jobs.json`: `file.drop` with `shoot/` (three JPEGs) and `Intro.halo`, `edit.undo` | `input/shoot/` (three JPEGs), `input/Intro.halo` |

Trap: the folder drop imports nothing (folders not expanded), or each file is its own undo step, or the `.halo` is imported as a broken photo. Assertion: after the drop the catalog has 3 more photos, selected; one undo removes all three; the `.halo` is one `handOff` to `halo`. Mutations: `LibraryModel.LibraryFileFlow+Kernel.json`, one step per file → `.oneImportStep`; other apps' documents imported → `.othersHandOff`.

## Screens and states

`library-open-recent` (light and dark), `library-drop-mark`.

## Contract slice

```swift
// Sources/LibraryModel/LibraryFileFlow+Kernel.swift (LF-1 stubs returning the fake's values, LF-3 bodies)
extension LibraryCatalog: SuiteDocumentHost { ... }   // accept: open, new, place; refusal: why not
extension LibraryCatalog: FileFlowTarget { ... }     // appID "library"; places jpg, jpeg, png, heic, tiff, and raw types
```

## Pseudocode

- **accept.** `.place` → the existing import of those files, one step, then select them; `.open` of an image → the same import.
- **drag out.** `.suiteDraggable { the thumbnail's file URL and its PNG }` on each grid cell.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LF-1 | – | The adapter as stubs (`SuiteDocumentHost`, `FileFlowTarget`); `LibraryFileFlowTests` written, disabled | `Sources/LibraryModel/LibraryFileFlow+Kernel.swift`, `Tests/LibraryModelTests/LibraryFileFlowTests.swift` | SF-a | ~140, 2 |
| LF-2 | – | The scene adopts `.suiteApp(.library, host:)`; the File menu's Open Recent becomes `SuiteFileCommands` with Open In; the window takes `.suiteFileDrop` | `Sources/LibraryApp/LibraryApp.swift`, `Sources/LibraryApp/LibraryCommands.swift`, `Sources/LibraryApp/LibraryGrid.swift` | LF-1 | ~160, 3 |
| LF-3 | – | The adapter's bodies; `FileFlowCommands.specs` in the catalog; the ids; the host's accept (place is import); RJ-L42's job folder; turns on `LibraryFileFlowTests` | `Sources/LibraryModel/LibraryFileFlow+Kernel.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/LibraryFileFlowTests.swift`, `Tests/mutations/LibraryModel.LibraryFileFlow+Kernel.json`, `Tests/RealJobs/library/drop-import/` | LF-1, SF-5, SF-6, tone-controls:LT-m | ~300, 6 |
| LF-4 | – | Library notes catalog opens through the bridge; thumbnails drag out with the file URL and a PNG | `Sources/LibraryApp/LibraryWindow+Import.swift`, `Tests/AppSnapshotTests/LibraryFileFlowLiveTests.swift` | LF-1, SF-7 | ~180, 2 |
| LF-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/LibraryFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetLibraryFileDropTests.swift` | LF-2 | ~120, 2 |
| LF-6 | – | The journey written and skipped (`XCTSkip("waits on LF-7")`) | `UITests/LibraryJourneyTests+FileFlow.swift` | LF-2 | ~100, 1 |
| LF-7 | – | Live: the journey turned on, on live services | `UITests/LibraryJourneyTests+FileFlow.swift` | LF-6, LF-3, LF-4, SF-8 | ~40, 1 |
| LF-8 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/file-flow.wave.json` | LF-7, LF-5 | ~30, 1 |

## Build waves

- Wave 1: LF-1. Independent in this wave: LF-1 alone.
- Wave 2: LF-2, LF-3, LF-4. Independent in this wave: all three.
- Wave 3: LF-5, LF-6. Independent in this wave: both.
- Wave 4: LF-7. Independent in this wave: LF-7 alone.
- Wave 5: LF-8 (`feature-done`, final). Independent in this wave: LF-8 alone.

Longest chain: LF-1 → LF-2 → LF-6 → LF-7 → LF-8 (5). Chain of 5: the menu needs the adapter, the journey drives the menu, LF-7 turns it on live, LF-8 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LF-1 | compiles; `LibraryFileFlowTests` disabled by name | – | – (stub) |
| LF-2 | `LibraryFileFlowSnapshots.menu` (LF-5's, first in the slice PR); the old Open Recent menu is gone | two Open Recent menus show | – (UI) |
| LF-3 | `LibraryFileFlowTests`: a folder of three JPEGs imports three in one step and selects them; `.halo` hands off; the id list matches the catalog; RJ-L42 passes on Linux | an action, a list or an id is wrong | `LibraryModel.LibraryFileFlow+Kernel`: one step per file → `.oneImportStep`; other apps' documents imported → `.othersHandOff` |
| LF-4 | `LibraryFileFlowLiveTests` (macOS): an open and a save reach the bridge once each; a thumbnail drag offers the file URL and a PNG | an event is lost | – (macOS) |
| LF-5 | `LibraryFileFlowSnapshots`; `RenderBudgetLibraryFileDropTests.dragHoverInTwoBodies` | budget over | – (UI) |
| LF-6 | compiles, skipped | – | – |
| LF-7 | `LibraryFileFlowJourneyTests.testDropToImportAndDragOut` on live | a step fails | – |
| LF-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over the window, 120 moves | ≤ 2 window bodies | `RenderBudgetLibraryFileDropTests.dragHoverInTwoBodies` |
| One gesture, one step | a drop of any number of photos is one import step | `LibraryFileFlowTests` |
| No dead controls | Open Recent and Open In say why when off | `LibraryFileFlowSnapshots` |
| Audit | zero new over Library's baseline | `audit-library-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): LF-m merged-done with RJ-L42 green in the Linux job; LF-u's and LF-m's feel gate and `Mac-Finish:`; LF-z's journey on live. Then `Belt-Contact-Sheet:` with `library-open-recent-*`.

## Not in this packet

An Open Recent of catalogs (one catalog per Library), dragging between Library and its own collections (filters-collections), watched folders (A7).
