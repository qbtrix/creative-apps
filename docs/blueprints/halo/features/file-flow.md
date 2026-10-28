# Feature packet: file-flow (Halo)

**Feature:** Halo's File > Open Recent ▸ reads the one suite list (`HaloFiles`' `recent` list goes; `HaloRecentFile` stays as the type the old defaults decode into for `takeOldRecents(_ stored: inout [HaloRecentFile]?)`, imported once), and a drop on the viewer follows the suite rule: a `.halo` opens in this window, a `.flare` hands off to Flare (flare-in-halo FH-1 later makes it a scene), other apps' documents go to their app, and an image dropped on the canvas is placed by placed-images' PH-3 (`placeDropTarget`); off the canvas it hands off to Photo.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7). Labels `beta` and `p1` when filed.

**Covers:** feature map `halo/file-flow` (adopter of `suite/file-flow`);
#865 (Halo: adopt the suite; A-HA-1 already built the host, `HaloDocumentHost`,
and the scene's `.suiteEditor(.halo, host: HaloShell.host, live: HaloLive.channel)`;
HF-3 extends `HaloDocumentHost.command(for:)` and closes it); real job RJ-H42.

**Depends on:** `suite/file-flow` **SF-a** (cross-line: `DropPlan`,
`FileFlowTarget`, `SuiteFileCommands`, `.suiteFileDrop`,
`SuiteDocumentsBridge`); HF-3 needs **SF-5** and **SF-6**, HF-4 **SF-7**,
HF-7 **SF-8**. Same line: foundation (built) owns `HaloApp.swift`. `gradient-fill`'s HG-m owns `HaloCommandCatalog.swift` and `Tests/command-ids/halo.txt`, so HF-3 waits on it; `export-pack`'s HX-z owns `halo.md`, so HF-8 waits on it. `HaloFileFlow+Kernel.swift` is listed in `halo/c4-planned.json` (halo-files) with this packet.

**Rule 20.** Halo's recents list in `HaloFiles` is deleted for the suite's; a `.flare` drop keeps the existing hand-off to Flare, not a new path (`.flare` lists only Flare as a reader and `HaloDocumentHost` refuses `.importAnimation` until flare-in-halo FH-1).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HF-a | Halo conforms to `FileFlowTarget` on stubs (the host stays `HaloDocumentHost`), its scene is `.suiteEditor`, and its File menu and window use the suite's Open Recent, Open In and drop on the fakes. | HF-1, HF-2 | MHF | SF-a (cross-line); foundation; transform:HT-a (HF-2, A/C first); shape-tools:HS-a (HF-2, A/C first); placed-images:PH-u (HF-2, A/C first) |
| HF-u | The menu and the drop mark have snapshots and a render budget, and the journey is written. | HF-5, HF-6 | HFJ1 | HF-a |
| HF-m | Halo accepts open and new hand-offs, imports its old recents once, lists the suite's, and notes every open and save there. | HF-3, HF-4 | MHF | HF-a; SF-5, SF-6, SF-7 (cross-line); gradient-fill:HG-m; autosave-history:HA-m (HF-3, A/C first); transform:HT-m (HF-3, A/C first); shape-tools:HS-m (HF-3, A/C first); stroke-style:HK-m (HF-3, A/C first); placed-images:PH-m (HF-3, A/C first) |
| HF-z | Drop, Open Recent and Open In run on live services, the journey passes, and the feature is built. | HF-7, HF-8 | HFJ1 | HF-u, HF-m; export-pack:HX-z; placed-images:PH-z (HF-8, A/C first) |

HF-u waits only on HF-a (rule 18); HF-m never waits on HF-u. HF-m is marked `"ui": true` because HF-4 changes `HaloWindow+File.swift` in HaloApp. MHF is the Model walk in `HaloFileFlowTests` (Linux).

## Journey steps

1. Launch Halo with `weekOfWork` (HF-2,
   `HaloFileFlowJourneyTests.testOpenRecentAndDrop`): File > Open Recent ▸
   lists `Intro.halo` only.
2. Drop `Promo.halo` from Finder on the viewer: it opens in this window,
   asking about unsaved changes first; no window is added.
3. Drop `Sunset.png` on the canvas: PH-3 places it; no Halo window opens.
4. Drop `Bounce.flare`: the mark reads "Open in Flare" and the file goes to
   Flare (rule 20; flare-in-halo FH-1 makes it a scene); no Halo window opens.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H42 | adds, closes with `halo/file-flow` | C | `Tests/RealJobs/halo/open-recent/open-recent.jobs.json`: `file.save` `Intro.halo`, `file.recent`, `file.drop` with `Promo.halo` and `sunset.png` | `input/intro.halo`, `input/promo.halo`, `input/sunset.png` |

Trap: Halo keeps its own list (two Open Recent truths), or an image drop is silently ignored. Assertion: `file.recent` equals the suite list filtered to Halo, `Intro.halo` first; the drop's result is `open` for `Promo.halo` and `handOff` to `photo` for the PNG off the canvas (Photo reads it; `placesExtensions` stays empty because `HaloDocumentHost` refuses `.place`, and the canvas places through PH-3 instead). Mutations: `HaloModel.HaloFileFlow+Kernel.json`, a PNG in `placesExtensions` → `.imagesRefusedUntilS20` (the label predates PH-3; the follow-up renames it).

## Screens and states

`halo-open-recent` (light and dark), `halo-drop-mark` (light and dark).

## Contract slice

```swift
// Sources/HaloModel/HaloFileFlow+Kernel.swift (HF-1 stubs returning the fake's values, HF-3 bodies)
// SuiteDocumentHost stays HaloDocumentHost (A-HA-1); HF-3 extends HaloDocumentHost.command(for:)
extension HaloProject: FileFlowTarget { ... }     // appID "halo"; placesExtensions empty (the canvas places through PH-3)
```

## Pseudocode

- **accept.** `.open` → `.openRecent(path)` in this window (unsaved changes asked first); `.importAnimation` is refused until flare-in-halo FH-1.
- **import once.** The window reads the `HaloRecentFiles` default, calls `HaloProject.takeOldRecents(&stored)`, notes each ref `.opened` through HaloShell.bridge, then removes the default.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HF-1 | – | The adapter as stubs (`SuiteDocumentHost`, `FileFlowTarget`); `HaloFileFlowTests` written, disabled | `Sources/HaloModel/HaloFileFlow+Kernel.swift`, `Tests/HaloModelTests/HaloFileFlowTests.swift` | SF-a | ~140, 2 |
| HF-2 | – | Landed with HF-a: the scene is `.suiteEditor(.halo, host: HaloShell.host, live: HaloLive.channel)`; the File menu's Open Recent becomes `SuiteFileCommands` with Open In; the window takes `.suiteFileDrop` | `Sources/HaloApp/HaloApp.swift`, `Sources/HaloApp/HaloFileMenu.swift`, `Sources/HaloApp/HaloViewer.swift` | HF-1 | ~160, 3 |
| HF-3 | – | The adapter's bodies; `FileFlowCommands.specs` in the catalog after retiring `HaloCommand.openRecent`'s `file.open-recent` spec (param `path`; the suite's takes `fileID`); `file.recent`, `file.clear-recent`, `file.open-in` and `file.drop` added to halo.txt; no menu reads `HaloFiles`' own `recent` list after HF-4; removing it (the pending open moves into `file.opening`, and `HaloProject.swift`, `Availability/HaloAvailability+Files.swift` and `HaloRecovery+Kernel.swift` join the owned files) and the unused `imageRefusal` go in one fix PR after HF-4 lands; the host's accept; RJ-H42's job folder; turns on `HaloFileFlowTests` | `Sources/HaloModel/HaloFileFlow+Kernel.swift`, `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloFileFlowTests.swift`, `Tests/mutations/HaloModel.HaloFileFlow+Kernel.json`, `Tests/RealJobs/halo/open-recent/`, `Sources/HaloModel/HaloFiles.swift` | HF-1, SF-5, SF-6, gradient-fill:HG-m | ~300, 7 |
| HF-4 | – | The window notes opens and saves through the bridge and imports the `HaloRecentFiles` default once (`takeOldRecents`) | `Sources/HaloApp/HaloWindow+File.swift`, `Tests/AppSnapshotTests/HaloFileFlowLiveTests.swift` | HF-1, SF-7 | ~180, 2 |
| HF-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloFileDropTests.swift` | HF-2 | ~120, 2 |
| HF-6 | – | The journey written and skipped (`XCTSkip("waits on HF-7")`) | `UITests/HaloJourneyTests+FileFlow.swift` | HF-2 | ~100, 1 |
| HF-7 | – | Live: the journey turned on, on live services | `UITests/HaloJourneyTests+FileFlow.swift` | HF-6, HF-3, HF-4, SF-8 | ~40, 1 |
| HF-8 | – | halo.md: Open Recent, Open In and drop; `status: built`; `feature-done` | `docs/blueprints/halo.md`, `docs/blueprints/halo/features/file-flow.wave.json` | HF-7, HF-5, export-pack:HX-z | ~30, 2 |

## Build waves

- Wave 1: HF-1. Independent in this wave: HF-1 alone.
- Wave 2: HF-2, HF-3, HF-4. Independent in this wave: all three.
- Wave 3: HF-5, HF-6. Independent in this wave: both.
- Wave 4: HF-7. Independent in this wave: HF-7 alone.
- Wave 5: HF-8 (`feature-done`, final). Independent in this wave: HF-8 alone.

Longest chain: HF-1 → HF-2 → HF-6 → HF-7 → HF-8 (5). Chain of 5: the menu needs the adapter, the journey drives the menu, HF-7 turns it on live, HF-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HF-1 | compiles; `HaloFileFlowTests` disabled by name | – | – (stub) |
| HF-2 | `HaloFileFlowSnapshots.menu` (HF-5's, first in the slice PR); the old Open Recent menu is gone | two Open Recent menus show | – (UI) |
| HF-3 | `HaloFileFlowTests`: a `.halo` opens; a PNG hands off to Photo; old recents appear once; the id list matches the catalog; RJ-H42 passes on Linux | an action, a list or an id is wrong | `HaloModel.HaloFileFlow+Kernel`: images placed → `.imagesRefusedUntilS20`; import run twice → `.importsOnce` |
| HF-4 | `HaloFileFlowLiveTests` (macOS): an open and a save reach the bridge once each; Clear Menu empties Halo's recents | an event is lost | – (macOS) |
| HF-5 | `HaloFileFlowSnapshots`; `RenderBudgetHaloFileDropTests.dragHoverInTwoBodies` | budget over | – (UI) |
| HF-6 | compiles, skipped | – | – |
| HF-7 | `HaloFileFlowJourneyTests.testOpenRecentAndDrop` on live | a step fails | – |
| HF-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over the window, 120 moves | ≤ 2 window bodies | `RenderBudgetHaloFileDropTests.dragHoverInTwoBodies` |
| One gesture, one step | a drop that opens or hands off changes no document (no undo step) | `HaloFileFlowTests` |
| No dead controls | Open Recent and Open In say why when off | `HaloFileFlowSnapshots` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HF-m merged-done with RJ-H42 green in the Linux job; HF-u's and HF-m's feel gate and `Mac-Finish:`; HF-z's journey on live. Then `Belt-Contact-Sheet:` with `halo-open-recent-*`.

## Not in this packet

Image and SVG layers (S20, E11), footage drops (shell-media decode adoption).
