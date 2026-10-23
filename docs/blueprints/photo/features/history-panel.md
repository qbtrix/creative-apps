# Feature packet: history-panel (Photo)

**Feature:** Photo's History tab: SuiteUI's `HistoryPanel` in the inspector,
listing the image's steps from its kernel `History`, the current one marked;
a click jumps back or forward (one `history.jump`, no new step). Photo's
autosave moves onto the shared service: the window uses SuiteUI's
`.autosaveRecovery` with Photo's hooks and its recovery files go through
SuiteModel's `RecoveryFolder`, so `PhotoAutosave` is deleted. This fills PV-4's
stubs (`HistoryIntent {}`, `PhotoHistoryTab`).
**Line:** `line:photo` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/history-panel`
**Beta:** captain, 2026-10-20. Labels `beta` and `p1` when filed.

**Covers:** feature map `photo/history-panel` (adopter of S12); real job
RJ-P28 (jump back 10 steps by clicking the History panel); RJ-X24's Photo leg
(kill -9, relaunch, restore).

**Depends on:** `suiteui/autosave-history` **AH-a** (cross-line: the listing,
`HistoryJumping`, the specs, `HistoryPanel`, the modifier, `RecoveryFolder`
as stubs); PH-5 needs **AH-m** (the real jump), PH-6 **AH-z** (the real
modifier and folder). Same line: transform's **PT-m** before PH-5 (both own
`PhotoCommandCatalog.swift` and `photo.txt`). Built: photo-documents
(autosave today), photo-seams. Photo's history is on the kernel already
(adopt-kernel-undo AU-photo).

**Hand-offs:** `Tests/canonical-baseline.txt` is autosave-history's (AH-1):
PH-6 drops `Sources/PhotoApp/PhotoAutosave.swift` from it with
`scripts/check-dup-logic --update-baseline` after AH-a merges.

**Rule 20.** No Photo history list: the tab reads `History.listing`. No Photo
autosave timing: `PhotoAutosave.swift` (the copy AH-1 grandfathered) is
deleted, and `LiveRecovery` stores through `RecoveryFolder` with the `.ora`
bytes `LiveArchive` already writes. The only new Model file is the adapter
`PhotoHistory+Kernel.swift`.

**Render path.** None.

Blueprint sections: photo.md 4 (Window menu), 7 (the inspector), 9 (files and
recovery).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PH-a | The adapters are declared as stubs and the History tab lists the steps on them, reachable from Window > History. | PH-1, PH-2 | MJ-PH | suiteui/autosave-history AH-a (cross-line) |
| PH-u | The tab follows undo, redo and jumps, and its snapshots and render budget hold. | PH-3, PH-4 | PJ-H1 | PH-a |
| PH-m | A jump lands on its step without recording one, and autosave writes, offers and restores through the shared schedule and folder with Photo's copy deleted. | PH-5, PH-6 | MJ-PH | PH-a; transform:PT-m (PH-5); AH-m, AH-z (cross-line) |
| PH-z | The journeys jump back ten steps and restore after a quit on live services, and the feature is built. | PH-7, PH-8 | PJ-H1 | PH-u, PH-m |

PH-u waits only on PH-a (rule 18); PH-m never waits on PH-u. PH-m is `"ui": true` because PH-6 edits the window's file hooks. MJ-PH is the
Model walk in `PhotoHistoryJumpTests` (Linux).

## Journey steps

1. Open `portrait.jpg`, make 12 edits (brush, curves, crop), then open the
   inspector's History tab (PH-2, `PhotoHistoryJourneyTests.testJumpBackTenSteps`):
   "Open" and 12 steps, the last current.
2. Click the second step: the canvas shows the image after two steps; ten rows
   dim.
3. Paint one stroke: the ten dimmed rows go, a "Brush" row is current.
4. Quit with unsaved work and relaunch (PH-6, `testRestoreAfterQuit`): the
   alert offers "Restore the autosaved changes to “portrait.jpg”?"; Restore
   shows the 3-step image.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-P28 | closes (now `photo/history-panel`) | J | `testJumpBackTenSteps`: 12 edits, a click on the second step, one more edit | `portrait.jpg` |

Trap: the click replays every step forward from "Open" (slow on 12 MP) or
records a "Jump" step of its own. Assertion: after the click Undo reads the
second step's name and Redo the third's; the step count is unchanged until
the next edit. Mutation: `PhotoModel.PhotoHistory+Kernel.json` (jump through
`undo` once per step without ending the run → `.jumpEndsRun`).

## Screens and states

`photo-history-tab` (12 steps, the current marked, light and dark),
`-jumped` (later rows dimmed), `photo-recovery-offer` (the alert).

## Contract slice

```swift
// Sources/PhotoModel/PhotoHistory+Kernel.swift (PH-1 stubs, PH-5 bodies)
extension PhotoWorkspace: HistoryJumping {
    public var historyListing: HistoryListing { get }       // base: "Open" or "New Image", from PhotoHistory
    public mutating func jumpHistory(to index: Int) throws  // through PhotoHistory's kernel jump, applying each PhotoEdit
}
// Sources/PhotoModel/PhotoRecovery+Kernel.swift (PH-1 stubs, PH-6 bodies)
extension PhotoWorkspace {
    public func recoveryBytes() throws -> Data              // the .ora container of `recoveryEntry`
    public static func recovered(from data: Data, name: String?) async throws -> PhotoWorkspace
}
```

## Pseudocode

- **jump.** `endAdjust()` first (a slider drag in progress ends), then
  `History.jump(to:)` applying each step's `PhotoEdit` in order; pixel tiles
  swap, stack edits restore, so a jump of ten costs ten swaps, never a replay
  from "Open".
- **Autosave.** The window's `.autosaveRecovery` hooks: `isDirty` is
  `model.isDirty`, `encoder` copies `model` on main and returns
  `{ try copy.recoveryBytes() }`, `restore` decodes off main and installs;
  the folder is `RecoveryFolder(store: Photo's support store, ext: "ora")`,
  nil under `-ApplePersistenceIgnoreState`; the delay stays
  `PhotoWorkspace.autosaveDelay`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PH-1 | – | The two adapters' signatures as stubs; `PhotoHistoryJumpTests` written, disabled | `Sources/PhotoModel/PhotoHistory+Kernel.swift`, `Sources/PhotoModel/PhotoRecovery+Kernel.swift`, `Tests/PhotoModelTests/PhotoHistoryJumpTests.swift` | – | ~120, 3 |
| PH-2 | – | The History tab on the stubs: `HistoryPanel` in `PhotoHistoryTab`, `HistoryIntent.jump`, the tab shown in the panel, Window > History; the journeys written, skipped | `Sources/PhotoApp/PhotoHistoryTab.swift`, `Sources/PhotoApp/PhotoWindow+History.swift`, `Sources/PhotoApp/PhotoPanel.swift`, `Sources/PhotoApp/PhotoCommands+View.swift`, `UITests/PhotoJourneyTests+History.swift` | PH-1 | ~200, 5 |
| PH-3 | – | The tab follows the listing after undo, redo and a jump; its tests | `Sources/PhotoApp/PhotoHistoryTab.swift`, `Tests/AppSnapshotTests/PhotoHistoryTabTests.swift` | PH-2 | ~140, 2 |
| PH-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/PhotoHistorySnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetPhotoHistoryTests.swift` | PH-3 | ~180, 2 |
| PH-5 | – | The jump body; the two history specs in the catalog and id list; turns on `PhotoHistoryJumpTests` | `Sources/PhotoModel/PhotoHistory+Kernel.swift`, `Tests/PhotoModelTests/PhotoHistoryJumpTests.swift`, `Tests/mutations/PhotoModel.PhotoHistory+Kernel.json`, `Sources/PhotoModel/PhotoCommandCatalog.swift`, `Tests/command-ids/photo.txt` | PH-1 | ~200, 5 |
| PH-6 | – | Autosave on the shared modifier and `RecoveryFolder`: the recovery bytes, `LiveRecovery` through the folder, `PhotoAutosave.swift` deleted and its baseline line dropped | `Sources/PhotoModel/PhotoRecovery+Kernel.swift`, `Sources/PhotoModel/Live/LiveRecovery.swift`, `Sources/PhotoApp/PhotoWindow+File.swift`, `Sources/PhotoApp/PhotoAutosave.swift`, `Tests/PhotoModelTests/PhotoRecoveryFolderTests.swift`, `Tests/mutations/PhotoModel.LiveRecovery.json`, `Tests/canonical-baseline.txt` | PH-1 | ~300, 7 |
| PH-7 | – | The journeys turned on, on live services | `UITests/PhotoJourneyTests+History.swift` | PH-4, PH-5, PH-6 | ~60, 1 |
| PH-8 | – | `status: built`; `feature-done` | `docs/blueprints/photo/features/history-panel.wave.json` | PH-7 | ~10, 1 |

## Build waves

- Wave 1: PH-1. Independent in this wave: PH-1 alone.
- Wave 2: PH-2, PH-5, PH-6. Independent in this wave: all 3.
- Wave 3: PH-3. Independent in this wave: PH-3 alone.
- Wave 4: PH-4. Independent in this wave: PH-4 alone.
- Wave 5: PH-7. Independent in this wave: PH-7 alone.
- Wave 6: PH-8 (`feature-done`, final). Independent in this wave: PH-8 alone.

Longest chain: PH-1 → PH-2 → PH-3 → PH-4 → PH-7 → PH-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PH-1 | `PhotoHistoryJumpTests` compiles, disabled | – | – (stub) |
| PH-2 | `PhotoInspectorSnapshots`: the History tab shows on the stubs; Window > History opens it | the tab is missing | – (UI) |
| PH-3 | `PhotoHistoryTabTests`: a click emits one `.jump(index)`; the tab follows the model's listing after an undo | a jump is doubled | – (UI) |
| PH-4 | `PhotoHistorySnapshots`; `RenderBudgetPhotoHistoryTests.arrowWalkInThreeBodies` | budget over | – (UI) |
| PH-5 | `PhotoHistoryJumpTests`: 12 steps, jump to 2: Undo and Redo name steps 2 and 3, the pixels equal the state after step 2; a jump records nothing and ends an open slider run; `history.jump` out of range throws | a pixel, a name or a step count is wrong | `PhotoModel.PhotoHistory+Kernel`: run not ended → `.jumpEndsRun`; step recorded → `.jumpRecordsNothing`; base named "" → `.baseIsOpen` |
| PH-6 | `PhotoRecoveryFolderTests`: an edit writes one `.ora` through `RecoveryFolder` after the delay; a save removes it; a relaunch offers it and Restore gives the same layers; `PhotoAutosave.swift` is gone and `check-dup-logic` passes | a write is doubled, a saved file stays or a restore differs | `PhotoModel.LiveRecovery`: discard skipped on save → `.saveRemovesRecovery`; oldest offered → `.newestOffered` |
| PH-7 | `testJumpBackTenSteps` and `testRestoreAfterQuit` on live | a step fails | – |
| PH-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: arrow-key walk down 30 steps of the tab on a 12 MP image | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetPhotoHistoryTests.arrowWalkInThreeBodies` |
| One gesture, one step | a jump adds no step | `PhotoHistoryJumpTests.jumpRecordsNothing` |
| render: 120-sample brush stroke while the autosave tick runs (PH-6 touches the window) | ≤ 3 window bodies; p95 ≤ 16 ms | `RenderBudgetPhotoHistoryTests.paintWhileAutosaving` |
| Autosave stays off the main actor | the `.ora` encode runs detached | `PhotoRecoveryFolderTests.encodesOffMain` |
| No dead controls; keyboard parity | every row identified, arrows and Return jump | `testJumpBackTenSteps` |
| Audit | zero new over Photo's baseline | `audit-photo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PH-m merged-done on the Linux job; PH-u's
feel gate and `Mac-Finish:`; PH-z's journeys on live and RJ-P28 green in the
scoped run. Then `Belt-Contact-Sheet:` with `photo-history-*`.

## Not in this packet

History snapshots, the history brush, history kept across a relaunch.
