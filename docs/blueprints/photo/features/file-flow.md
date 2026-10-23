# Feature packet: file-flow (Photo)

**Feature:** Photo's File > Open Recent ▸ reads the one suite list (its own list and `PhotoRecentMenu` go, their entries imported once), Open In ▸ offers Library for an image, and the drop on the canvas follows the suite rule: an image on an open document becomes a layer (one "Place" step), on an empty window it opens, and another app's document goes to that app. The drop that `PhotoEditor` has today becomes `.suiteFileDrop`.
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7). Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/file-flow` (adopter of `suite/file-flow`);
#863 (Photo: adopt the suite — `SuiteDocumentHost` and `.suiteApp`; this
packet's PF-1 and PF-2 do it, and PF-3 closes it); real job RJ-P42.

**Depends on:** `suite/file-flow` **SF-a** (cross-line: `DropPlan`,
`FileFlowTarget`, `SuiteFileCommands`, `.suiteFileDrop`,
`SuiteDocumentsBridge`); PF-3 needs **SF-5** and **SF-6**, PF-4 **SF-7**,
PF-7 **SF-8**. Same line (built, as slice waits): photo-seams, photo-documents, photo-render-adopt and shell-parity own the three app files. `tone-controls`'s PT-m owns `PhotoCommandCatalog.swift` and `Tests/command-ids/photo.txt`, so PF-3 waits on it; `export-pack`'s PX-z owns `photo.md`, so PF-8 waits on it.

**Rule 20.** Photo's recents list is deleted for the suite's (`PhotoRecentMenu.swift` goes; `file.open-recent` and `file.clear-recent` keep their ids as the shared specs). The place is Photo's existing paste-as-layer path, not a new one.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PF-a | Photo conforms to `SuiteDocumentHost` and `FileFlowTarget` on stubs, its scene adopts `.suiteApp`, and its File menu and window use the suite's Open Recent, Open In and drop on the fakes. | PF-1, PF-2 | MPF | SF-a (cross-line); photo-seams, photo-documents, photo-render-adopt, shell-parity; place-image:PP-u (PF-2, A/C first) |
| PF-u | The menu and the drop mark have snapshots and a render budget, and the journey is written. | PF-5, PF-6 | PFJ1 | PF-a |
| PF-m | Photo accepts open, new and place hand-offs, imports its old recents once, lists the suite's, and notes every open and save there. | PF-3, PF-4 | MPF | PF-a; SF-5, SF-6, SF-7 (cross-line); tone-controls:PT-m; transform:PT-m (PF-3, A/C first); history-panel:PH-m (PF-3, A/C first); eyedropper:PE-m (PF-3, A/C first); place-image:PP-m (PF-3, A/C first) |
| PF-z | Drop, Open Recent and Open In run on live services, the journey passes, and the feature is built. | PF-7, PF-8 | PFJ1 | PF-u, PF-m; export-pack:PX-z; place-image:PP-z (PF-8, A/C first) |

PF-u waits only on PF-a (rule 18); PF-m never waits on PF-u. PF-m is marked `"ui": true` because PF-4 changes `PhotoWindow+File.swift` in PhotoApp. MPF is the Model walk in `PhotoFileFlowTests` (Linux).

## Journey steps

1. Launch Photo with `weekOfWork` and open `Sunset.png` (PF-2,
   `PhotoFileFlowJourneyTests.testDropImageAsLayer`): File > Open Recent ▸
   lists Photo's files from the suite list.
2. Drop `Logo.png` from Finder on the canvas: the mark reads "Place in
   Sunset"; on release a layer "Logo" sits centred; Undo removes it in one step.
3. Drop `Intro.halo`: Halo opens it.
4. File > Open In ▸ Library: Library imports `Sunset.png`.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P42 | adds, closes with `photo/file-flow` | C | `Tests/RealJobs/photo/drop-layer/drop-layer.jobs.json`: open `sunset.png`, `file.drop` with `logo.png`, `edit.undo`, `file.drop` again, save | `input/sunset.png`, `input/logo.png` (transparent) |

Trap: the drop replaces the document or opens a second window instead of adding a layer, or one drop makes two undo steps. Assertion: after the first drop the document has 2 layers, the new one named "logo" and centred; after one undo it has 1; the saved file has 2. Mutations: `PhotoModel.PhotoFileFlow+Kernel.json`, place opened as a document → `.placesAsLayer`; two steps per drop → `.oneStep`.

## Screens and states

`photo-open-recent` (light and dark), `photo-drop-mark`.

## Contract slice

```swift
// Sources/PhotoModel/PhotoFileFlow+Kernel.swift (PF-1 stubs returning the fake's values, PF-3 bodies)
extension PhotoWorkspace: SuiteDocumentHost { ... }   // accept: open, new, place; refusal: why not
extension PhotoWorkspace: FileFlowTarget { ... }     // appID "photo"; places png, jpg, jpeg, heic, tiff, psd
```

## Pseudocode

- **accept.** `.open` → a window; `.place` → the paste-as-layer path, centred, one "Place" step.
- **import once.** On first launch with the suite list, `PhotoRecentMenu`'s saved paths are noted into it (oldest first, so order holds), then the old key is removed.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PF-1 | – | The adapter as stubs (`SuiteDocumentHost`, `FileFlowTarget`); `PhotoFileFlowTests` written, disabled | `Sources/PhotoModel/PhotoFileFlow+Kernel.swift`, `Tests/PhotoModelTests/PhotoFileFlowTests.swift` | SF-a | ~140, 2 |
| PF-2 | – | The scene adopts `.suiteApp(.photo, host:)`; the File menu's Open Recent becomes `SuiteFileCommands` with Open In; the window takes `.suiteFileDrop` | `Sources/PhotoApp/PhotoApp.swift`, `Sources/PhotoApp/PhotoCommands+File.swift`, `Sources/PhotoApp/PhotoEditor.swift` | PF-1 | ~160, 3 |
| PF-3 | – | The adapter's bodies; `FileFlowCommands.specs` in the catalog; the ids; the host's accept; `PhotoRecentMenu.swift` deleted and its saved list imported once; RJ-P42's job folder; turns on `PhotoFileFlowTests` | `Sources/PhotoModel/PhotoFileFlow+Kernel.swift`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt`, `Tests/PhotoModelTests/PhotoFileFlowTests.swift`, `Tests/mutations/PhotoModel.PhotoFileFlow+Kernel.json`, `Tests/RealJobs/photo/drop-layer/`, `Sources/PhotoModel/PhotoRecentMenu.swift` | PF-1, SF-5, SF-6, tone-controls:PT-m | ~300, 7 |
| PF-4 | – | The window notes opens and saves through the bridge | `Sources/PhotoApp/PhotoWindow+File.swift`, `Tests/AppSnapshotTests/PhotoFileFlowLiveTests.swift` | PF-1, SF-7 | ~180, 2 |
| PF-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoFileDropTests.swift` | PF-2 | ~120, 2 |
| PF-6 | – | The journey written and skipped (`XCTSkip("waits on PF-7")`) | `UITests/PhotoJourneyTests+FileFlow.swift` | PF-2 | ~100, 1 |
| PF-7 | – | Live: the journey turned on, on live services | `UITests/PhotoJourneyTests+FileFlow.swift` | PF-6, PF-3, PF-4, SF-8 | ~40, 1 |
| PF-8 | – | photo.md: Open Recent, Open In and drop; `status: built`; `feature-done` | `docs/blueprints/photo.md`, `docs/blueprints/photo/features/file-flow.wave.json` | PF-7, PF-5, export-pack:PX-z | ~30, 2 |

## Build waves

- Wave 1: PF-1. Independent in this wave: PF-1 alone.
- Wave 2: PF-2, PF-3, PF-4. Independent in this wave: all three.
- Wave 3: PF-5, PF-6. Independent in this wave: both.
- Wave 4: PF-7. Independent in this wave: PF-7 alone.
- Wave 5: PF-8 (`feature-done`, final). Independent in this wave: PF-8 alone.

Longest chain: PF-1 → PF-2 → PF-6 → PF-7 → PF-8 (5). Chain of 5: the menu needs the adapter, the journey drives the menu, PF-7 turns it on live, PF-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PF-1 | compiles; `PhotoFileFlowTests` disabled by name | – | – (stub) |
| PF-2 | `PhotoFileFlowSnapshots.menu` (PF-5's, first in the slice PR); the old Open Recent menu is gone | two Open Recent menus show | – (UI) |
| PF-3 | `PhotoFileFlowTests`: a PNG on an open image places one layer in one step; with no image it opens; `.halo` hands off; old saved recents appear once in the suite list; the id list matches the catalog; RJ-P42 passes on Linux | an action, a list or an id is wrong | `PhotoModel.PhotoFileFlow+Kernel`: place opened as a document → `.placesAsLayer`; import run twice → `.importsOnce` |
| PF-4 | `PhotoFileFlowLiveTests` (macOS): an open and a save reach the bridge once each; the old list's key is gone after the import | an event is lost | – (macOS) |
| PF-5 | `PhotoFileFlowSnapshots`; `RenderBudgetPhotoFileDropTests.dragHoverInTwoBodies` | budget over | – (UI) |
| PF-6 | compiles, skipped | – | – |
| PF-7 | `PhotoFileFlowJourneyTests.testDropImageAsLayer` on live | a step fails | – |
| PF-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over the window, 120 moves | ≤ 2 window bodies | `RenderBudgetPhotoFileDropTests.dragHoverInTwoBodies` |
| One gesture, one step | a drop of any number of images is one "Place" step | `PhotoFileFlowTests` |
| No dead controls | Open Recent and Open In say why when off | `PhotoFileFlowSnapshots` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PF-m merged-done with RJ-P42 green in the Linux job; PF-u's and PF-m's feel gate and `Mac-Finish:`; PF-z's journey on live. Then `Belt-Contact-Sheet:` with `photo-open-recent-*`.

## Not in this packet

Dropping layers with masks into other apps, a drop onto a specific layer position.
