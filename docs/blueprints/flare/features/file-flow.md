# Feature packet: file-flow (Flare)

**Feature:** Flare's File > Open Recent ▸ reads the one suite list (`FlareFiles`' own list goes, imported once), Open In ▸ offers Halo for a `.flare` (Halo's "Flare in Halo" reads it), and a drop on the stage follows the suite rule: a `.flare` opens, another app's document goes to that app, an SVG is refused with "Flare can't import SVG yet." until SVG import (E11) lands.
**Line:** `line:flare` · **Wave:** 6 (`waves.md`) · **Lead branch:** `lead/file-flow`
**Beta:** captain, 2026-10-20 (everyday gaps audit, rank 7). Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/file-flow` (adopter of `suite/file-flow`);
#861 (Flare: adopt the suite — `SuiteDocumentHost` and `.suiteApp`; this
packet's FL-1 and FL-2 do it, and FL-3 closes it); real job RJ-F42.

**Depends on:** `suite/file-flow` **SF-a** (cross-line: `DropPlan`,
`FileFlowTarget`, `SuiteFileCommands`, `.suiteFileDrop`,
`SuiteDocumentsBridge`); FL-3 needs **SF-5** and **SF-6**, FL-4 **SF-7**,
FL-7 **SF-8**. Same line: layers-files and mac-platform (built) own `FlareWindow+File.swift` and `FlareFiles.swift`; stage-edit (planned, wave 4) owns `FlareStage.swift`, so FL-2 waits on it. `gradient-fill`'s FG-m owns `FlareCommandCatalog.swift` and `Tests/command-ids/flare.txt`, so FL-3 waits on it; `export-pack`'s FV-z owns `flare.md`, so FL-8 waits on it. #837 (the `Bounce.flare` fixture) for the journey.

**Rule 20.** Flare's recents list in `FlareFiles` is deleted for the suite's; `file.open-recent` and `file.clear-recent` keep their ids as the shared specs.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| FL-a | Flare conforms to `SuiteDocumentHost` and `FileFlowTarget` on stubs, its scene adopts `.suiteApp`, and its File menu and window use the suite's Open Recent, Open In and drop on the fakes. | FL-1, FL-2 | MFL | SF-a (cross-line); layers-files, mac-platform, stage-edit; svg-place:PF-u (FL-2, A/C first) |
| FL-u | The menu and the drop mark have snapshots and a render budget, and the journey is written. | FL-5, FL-6 | FLJ1 | FL-a |
| FL-m | Flare accepts open and new hand-offs, imports its old recents once, lists the suite's, and notes every open and save there. | FL-3, FL-4 | MFL | FL-a; SF-5, SF-6, SF-7 (cross-line); gradient-fill:FG-m; shape-tools:FS-m (FL-3, A/C first); stroke-style:FK-m (FL-3, A/C first); svg-place:PF-m (FL-3, A/C first) |
| FL-z | Drop, Open Recent and Open In run on live services, the journey passes, and the feature is built. | FL-7, FL-8 | FLJ1 | FL-u, FL-m; export-pack:FV-z; svg-place:PF-z (FL-8, A/C first) |

FL-u waits only on FL-a (rule 18); FL-m never waits on FL-u. FL-m is marked `"ui": true` because FL-4 changes `FlareWindow+File.swift` in FlareApp. MFL is the Model walk in `FlareFileFlowTests` (Linux).

## Journey steps

1. Launch Flare with `weekOfWork` (FL-2,
   `FlareFileFlowJourneyTests.testOpenRecentAndOpenInHalo`): File > Open
   Recent ▸ lists `Bounce.flare`, `Title.flare`, `Logo.flare` only.
2. Drop `Bounce.flare` from Finder on the stage: it opens in a new window.
3. Drop `logo.svg`: the mark reads "Flare can't import SVG yet."; nothing changes.
4. File > Open In ▸ Halo: Halo makes a composition with the scene (SJ17's path).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F42 | adds, closes with `flare/file-flow` | C | `Tests/RealJobs/flare/open-recent/open-recent.jobs.json`: `file.save` `Bounce.flare`, `file.recent`, `file.drop` with `Title.flare` and `logo.svg` | `input/bounce.flare`, `input/title.flare`, `input/logo.svg` |

Trap: the old Flare-only list and the suite list disagree (two Open Recent truths), or an SVG drop half-imports. Assertion: `file.recent` lists `Bounce.flare` first and equals the suite list filtered to Flare; the drop's result is `open` for the `.flare` and `refuse` with "Flare can't import SVG yet." for the SVG. Mutations: `FlareModel.FlareFileFlow+Kernel.json`, SVG placed → `.svgRefusedUntilE11`.

## Screens and states

`flare-open-recent` (light and dark), `flare-drop-mark`.

## Contract slice

```swift
// Sources/FlareModel/FlareFileFlow+Kernel.swift (FL-1 stubs returning the fake's values, FL-3 bodies)
extension FlareWorkspace: SuiteDocumentHost { ... }   // accept: open, new, place; refusal: why not
extension FlareWorkspace: FileFlowTarget { ... }     // appID "flare"; places none until SVG import (E11)
```

## Pseudocode

- **accept.** `.open` → a window; `.new` → a new scene; `.place` → refused "Flare can't import SVG yet."
- **import once.** `FlareFiles`' saved list is noted into the suite list oldest first, then removed.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FL-1 | – | The adapter as stubs (`SuiteDocumentHost`, `FileFlowTarget`); `FlareFileFlowTests` written, disabled | `Sources/FlareModel/FlareFileFlow+Kernel.swift`, `Tests/FlareModelTests/FlareFileFlowTests.swift` | SF-a | ~140, 2 |
| FL-2 | – | The scene adopts `.suiteApp(.flare, host:)`; the File menu's Open Recent becomes `SuiteFileCommands` with Open In; the window takes `.suiteFileDrop` | `Sources/FlareApp/FlareApp.swift`, `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareStage.swift` | FL-1 | ~160, 3 |
| FL-3 | – | The adapter's bodies; `FileFlowCommands.specs` in the catalog; the ids; the host's accept; `FlareFiles`' recents removed and imported once; RJ-F42's job folder; turns on `FlareFileFlowTests` | `Sources/FlareModel/FlareFileFlow+Kernel.swift`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/FlareModelTests/FlareFileFlowTests.swift`, `Tests/mutations/FlareModel.FlareFileFlow+Kernel.json`, `Tests/RealJobs/flare/open-recent/`, `Sources/FlareModel/FlareFiles.swift` | FL-1, SF-5, SF-6, gradient-fill:FG-m | ~300, 7 |
| FL-4 | – | The window notes opens and saves through the bridge | `Sources/FlareApp/FlareWindow+File.swift`, `Tests/AppSnapshotTests/FlareFileFlowLiveTests.swift` | FL-1, SF-7 | ~180, 2 |
| FL-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/FlareFileFlowSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlareFileDropTests.swift` | FL-2 | ~120, 2 |
| FL-6 | – | The journey written and skipped (`XCTSkip("waits on FL-7")`) | `UITests/FlareJourneyTests+FileFlow.swift` | FL-2 | ~100, 1 |
| FL-7 | – | Live: the journey turned on, on live services | `UITests/FlareJourneyTests+FileFlow.swift` | FL-6, FL-3, FL-4, SF-8 | ~40, 1 |
| FL-8 | – | flare.md: Open Recent, Open In and drop; `status: built`; `feature-done` | `docs/blueprints/flare.md`, `docs/blueprints/flare/features/file-flow.wave.json` | FL-7, FL-5, export-pack:FV-z | ~30, 2 |

## Build waves

- Wave 1: FL-1. Independent in this wave: FL-1 alone.
- Wave 2: FL-2, FL-3, FL-4. Independent in this wave: all three.
- Wave 3: FL-5, FL-6. Independent in this wave: both.
- Wave 4: FL-7. Independent in this wave: FL-7 alone.
- Wave 5: FL-8 (`feature-done`, final). Independent in this wave: FL-8 alone.

Longest chain: FL-1 → FL-2 → FL-6 → FL-7 → FL-8 (5). Chain of 5: the menu needs the adapter, the journey drives the menu, FL-7 turns it on live, FL-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| FL-1 | compiles; `FlareFileFlowTests` disabled by name | – | – (stub) |
| FL-2 | `FlareFileFlowSnapshots.menu` (FL-5's, first in the slice PR); the old Open Recent menu is gone | two Open Recent menus show | – (UI) |
| FL-3 | `FlareFileFlowTests`: a `.flare` opens; an SVG is refused with its sentence; `.halo` hands off; old recents appear once; the id list matches the catalog; RJ-F42 passes on Linux | an action, a list or an id is wrong | `FlareModel.FlareFileFlow+Kernel`: SVG placed → `.svgRefusedUntilE11`; import run twice → `.importsOnce` |
| FL-4 | `FlareFileFlowLiveTests` (macOS): an open and a save reach the bridge once each; Open In Halo sends one hand-off | an event is lost | – (macOS) |
| FL-5 | `FlareFileFlowSnapshots`; `RenderBudgetFlareFileDropTests.dragHoverInTwoBodies` | budget over | – (UI) |
| FL-6 | compiles, skipped | – | – |
| FL-7 | `FlareFileFlowJourneyTests.testOpenRecentAndOpenInHalo` on live | a step fails | – |
| FL-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: a drag hovering over the window, 120 moves | ≤ 2 window bodies | `RenderBudgetFlareFileDropTests.dragHoverInTwoBodies` |
| One gesture, one step | a drop that opens or hands off changes no document (no undo step) | `FlareFileFlowTests` |
| No dead controls | Open Recent and Open In say why when off | `FlareFileFlowSnapshots` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): FL-m merged-done with RJ-F42 green in the Linux job; FL-u's and FL-m's feel gate and `Mac-Finish:`; FL-z's journey on live. Then `Belt-Contact-Sheet:` with `flare-open-recent-*`.

## Not in this packet

SVG import (E11), Lottie drop-in, dragging layers out to Halo.
