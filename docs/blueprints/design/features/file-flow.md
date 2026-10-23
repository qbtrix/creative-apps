# Feature packet: file-flow (Design)

**Feature:** Design gets File > Open Recent ▸ for the first time (its own files from the one suite list), Open In ▸ (off, with its reason, since no other app reads `.design`), and drops: a `.design` file opens in a new window, any other app's document goes to that app. A selection drags out to Flare, Halo or the Finder as the suite envelope, SVG and PNG, through the pasteboard coding Design's copy already uses.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7). Labels `beta` and `p1` when filed.

**Covers:** feature map `design/file-flow` (adopter of `suite/file-flow`);
#862 (Design: adopt the suite — `SuiteDocumentHost` and `.suiteApp`; this
packet's DF-1 and DF-2 do it, and DF-3 closes it); real job RJ-D42.

**Depends on:** `suite/file-flow` **SF-a** (cross-line: `DropPlan`,
`FileFlowTarget`, `SuiteFileCommands`, `.suiteFileDrop`,
`SuiteDocumentsBridge`); DF-3 needs **SF-5** and **SF-6**, DF-4 **SF-7**,
DF-7 **SF-8**. Same line: `design-export` (planned) owns `DesignCommands.swift` and `DesignWindow.swift`, so DF-a waits on it (and the held design-seams-2 S2-b now waits on DF-a); `gradient-fill`'s DG-m owns `DesignCommandCatalog.swift`, so DF-3 waits on it; `export-pack`'s DX-z owns `design.md`, so DF-8 waits on it. #836 (the `Cards.design` fixture) for the journey.

**Rule 20.** No Design recents list: the suite's, read through `SuiteDocumentsBridge`. The drag-out uses `PasteboardCoding`'s representations, which Design's copy already writes through `DesignPasteboardBridge`; no second encoder.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DF-a | Design conforms to `SuiteDocumentHost` and `FileFlowTarget` on stubs, its scene adopts `.suiteApp`, and its File menu and window use the suite's Open Recent, Open In and drop on the fakes. | DF-1, DF-2 | MDF | SF-a (cross-line); design-export; autosave-history:DA-a (DF-2, A/C first); placed-images:PD-u (DF-2, A/C first) |
| DF-u | The menu and the drop mark have snapshots and a render budget, and the journey is written. | DF-5, DF-6 | DFJ1 | DF-a |
| DF-m | Design accepts open and new hand-offs, lists its recents and refuses Open In with its reason, notes every open and save in the suite list, and drags a selection out with the pasteboard's representations. | DF-3, DF-4 | MDF | DF-a; SF-5, SF-6, SF-7 (cross-line); gradient-fill:DG-m; autosave-history:DA-m (DF-3, A/C first); transform:DT-m (DF-3, A/C first); eyedropper:DY-m (DF-3, A/C first); shape-tools:DS-m (DF-3, A/C first); stroke-style:DK-m (DF-3, A/C first); placed-images:PD-m (DF-3, A/C first) |
| DF-z | Drop, Open Recent and Open In run on live services, the journey passes, and the feature is built. | DF-7, DF-8 | DFJ1 | DF-u, DF-m; export-pack:DX-z; placed-images:PD-z (DF-8, A/C first) |

DF-u waits only on DF-a (rule 18); DF-m never waits on DF-u. DF-m is marked `"ui": true` because DF-4 changes `DesignWindow+Files.swift` and `DesignPasteboardBridge.swift` in DesignApp. MDF is the Model walk in `DesignFileFlowTests` (Linux).

## Journey steps

1. Launch Design with the `weekOfWork` fixture (DF-2,
   `DesignFileFlowJourneyTests.testOpenRecentAndDrop`): File > Open Recent ▸
   lists `Cards.design` and `Logo.design` only, newest first.
2. Pick `Logo.design`: it opens in a new window.
3. File > Open In ▸ is off: "No other app opens Design Document files."
4. Drop `Intro.halo` on the window: Halo opens it; Design is unchanged.
5. Save `Cards.design`: it moves to the top of Open Recent and of the home.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D42 | adds, closes with `design/file-flow` | C | `Tests/RealJobs/design/open-recent/open-recent.jobs.json`: `file.save` `Cards.design` then `Logo.design`, `file.recent`, `file.drop` with `Intro.halo` | `input/cards.design`, `input/logo.design`, `input/Intro.halo` |

Trap: Design has no Open Recent, or the list shows every app's files, or the `.halo` opens as a broken Design file. Assertion: `file.recent` is exactly `[Logo.design, Cards.design]`; the drop's result is one `handOff` to `halo` and the document is unchanged. Mutations: `DesignModel.DesignFileFlow+Kernel.json`, the app filter dropped → `.onlyDesignFiles`.

## Screens and states

`design-open-recent` (light and dark), `design-drop-mark`.

## Contract slice

```swift
// Sources/DesignModel/DesignFileFlow+Kernel.swift (DF-1 stubs returning the fake's values, DF-3 bodies)
extension DesignDocument: SuiteDocumentHost { ... }   // accept: open, new, place; refusal: why not
extension DesignDocument: FileFlowTarget { ... }     // appID "design"; places none (Design places images once S20 lands)
```

## Pseudocode

- **accept.** `.open` → a window for the file; `.new` → a new document; `.place` → refused "Design can't place files yet." until S20.
- **recentFiles.** The bridge's list for `.design`.
- **drag out.** `.suiteDraggable { selection as SuiteClipItem }` on the canvas.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DF-1 | – | The adapter as stubs (`SuiteDocumentHost`, `FileFlowTarget`); `DesignFileFlowTests` written, disabled | `Sources/DesignModel/DesignFileFlow+Kernel.swift`, `Tests/DesignModelTests/DesignFileFlowTests.swift` | SF-a | ~140, 2 |
| DF-2 | – | The scene adopts `.suiteApp(.design, host:)`; the File menu's Open Recent becomes `SuiteFileCommands` with Open In; the window takes `.suiteFileDrop` | `Sources/DesignApp/DesignApp.swift`, `Sources/DesignApp/DesignCommands.swift`, `Sources/DesignApp/DesignWindow.swift` | DF-1 | ~160, 3 |
| DF-3 | – | The adapter's bodies; `FileFlowCommands.specs` in the catalog; the ids; the host's accept and refusal; RJ-D42's job folder; turns on `DesignFileFlowTests` | `Sources/DesignModel/DesignFileFlow+Kernel.swift`, `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/DesignModelTests/DesignFileFlowTests.swift`, `Tests/mutations/DesignModel.DesignFileFlow+Kernel.json`, `Tests/RealJobs/design/open-recent/` | DF-1, SF-5, SF-6, gradient-fill:DG-m | ~300, 6 |
| DF-4 | – | The window notes opens and saves through the bridge; a canvas selection drags out with the pasteboard's representations | `Sources/DesignApp/DesignWindow+Files.swift`, `Sources/DesignApp/DesignPasteboardBridge.swift`, `Tests/AppSnapshotTests/DesignFileFlowLiveTests.swift` | DF-1, SF-7 | ~180, 3 |
| DF-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignFileDropTests.swift` | DF-2 | ~120, 2 |
| DF-6 | – | The journey written and skipped (`XCTSkip("waits on DF-7")`) | `UITests/DesignJourneyTests+FileFlow.swift` | DF-2 | ~100, 1 |
| DF-7 | – | Live: the journey turned on, on live services | `UITests/DesignJourneyTests+FileFlow.swift` | DF-6, DF-3, DF-4, SF-8 | ~40, 1 |
| DF-8 | – | design.md: Open Recent, Open In and drop; `status: built`; `feature-done` | `docs/blueprints/design.md`, `docs/blueprints/design/features/file-flow.wave.json` | DF-7, DF-5, export-pack:DX-z | ~30, 2 |

## Build waves

- Wave 1: DF-1. Independent in this wave: DF-1 alone.
- Wave 2: DF-2, DF-3, DF-4. Independent in this wave: all three.
- Wave 3: DF-5, DF-6. Independent in this wave: both.
- Wave 4: DF-7. Independent in this wave: DF-7 alone.
- Wave 5: DF-8 (`feature-done`, final). Independent in this wave: DF-8 alone.

Longest chain: DF-1 → DF-2 → DF-6 → DF-7 → DF-8 (5). Chain of 5: the menu needs the adapter, the journey drives the menu, DF-7 turns it on live, DF-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DF-1 | compiles; `DesignFileFlowTests` disabled by name | – | – (stub) |
| DF-2 | `DesignFileFlowSnapshots.menu` (DF-5's, first in the slice PR); the old Open Recent menu is gone | two Open Recent menus show | – (UI) |
| DF-3 | `DesignFileFlowTests`: `.halo` is handed off; `.design` opens; `file.recent` lists only Design's; Open In is off with its sentence; the id list matches the catalog; RJ-D42 passes on Linux | an action, a list or an id is wrong | `DesignModel.DesignFileFlow+Kernel`: the app filter dropped → `.onlyDesignFiles`; a place accepted → `.placeRefusedUntilS20` |
| DF-4 | `DesignFileFlowLiveTests` (macOS): an open and a save reach the bridge once each; a selection drag offers the suite envelope, SVG and PNG | an event is lost | – (macOS) |
| DF-5 | `DesignFileFlowSnapshots`; `RenderBudgetDesignFileDropTests.dragHoverInTwoBodies` | budget over | – (UI) |
| DF-6 | compiles, skipped | – | – |
| DF-7 | `DesignFileFlowJourneyTests.testOpenRecentAndDrop` on live | a step fails | – |
| DF-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over the window, 120 moves | ≤ 2 window bodies | `RenderBudgetDesignFileDropTests.dragHoverInTwoBodies` |
| One gesture, one step | a drop that hands off changes nothing here (no undo step) | `DesignFileFlowTests` |
| No dead controls | Open Recent and Open In say why when off | `DesignFileFlowSnapshots` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DF-m merged-done with RJ-D42 green in the Linux job; DF-u's and DF-m's feel gate and `Mac-Finish:`; DF-z's journey on live. Then `Belt-Contact-Sheet:` with `design-open-recent-*`.

## Not in this packet

Placing images and SVG in Design (S20), Quick Look, an Open Recent search.
