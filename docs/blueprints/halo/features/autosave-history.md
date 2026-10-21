# Feature packet: autosave-history (Halo)

**Feature:** Halo stops losing work. A Halo window autosaves a recovery copy a
delay after each edit through SuiteUI's `.autosaveRecovery` and SuiteModel's
`RecoveryFolder`, offers it back after a crash, and shows a History panel
(Edit > Show History, or the History button by the transport) listing the
project's steps from its kernel `History` (#3139); a click jumps to any step,
key edits and scrubs included. Halo adds only its hooks.
**Line:** `line:halo` · **Wave:** W4 (`waves.md`) · **Lead branch:** `lead/autosave-history`
**Beta:** captain, 2026-10-20. Labels `beta` and `p0` when filed.

**Covers:** feature map `halo/autosave-history` (adopter of S12); real jobs
RJ-H23 (force-quit after 30 minutes of work, relaunch) and RJ-H33 (new: jump
back through key edits, save, reopen).

**Depends on:** `suiteui/autosave-history` **AH-a** (cross-line); HA-5 needs
**AH-m**, HA-7 **AH-z**. Same line: gradient-fill's **HG-m** before HA-6 (both
own `HaloCommandCatalog.swift` and `Tests/command-ids/halo.txt`). Built:
foundation, history-files (save, the kernel session), viewer-playback.

**Hand-offs:** `HaloEditMenu.swift` is adopt-command-catalog's (AC-halo): HA-2's
menu item lands after AC-halo's `Belt-Slice-Done:`.

**Rule 20.** The panel reads `History.listing`; the recovery bytes are
`HaloFiles`' own encoding; the only new Model file is the adapter
`HaloRecovery+Kernel.swift`.

**Render path.** None.

Blueprint sections: halo.md 9 (files), 10 (menus).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| HA-a | The adapter is declared as stubs and the History panel and autosave hooks are on the window, reachable from Edit > Show History. | HA-1, HA-2 | MJ-HA | – |
| HA-u | The transport's History button toggles the panel, the panel follows undo and jumps, and the snapshots and render budget hold. | HA-3, HA-4 | J-HA | HA-a |
| HA-m | A jump lands on its step without recording one, recovery bytes reopen as a dirty never-saved project, and the history commands run from the catalog. | HA-5, HA-6 | MJ-HA | HA-a, gradient-fill:HG-m |
| HA-z | The journey jumps and recovers after a force-quit on live services, and the feature is built. | HA-7, HA-8 | J-HA | HA-u, HA-m |

HA-u waits only on HA-a (rule 18); HA-m never waits on HA-u. MJ-HA is the
Model walk in `HaloRecoveryTests` (Linux).

## Journey steps

1. Open `title.halo`, make 10 key edits, click the History button (HA-2,
   `HaloHistoryJourneyTests.testJumpAndRecover`): "Open" and 10 steps.
2. Click step 4: the timeline and viewer show the project after four edits.
3. Force-quit with the edits unsaved, relaunch (HA-7): the offer names
   `title.halo`; Restore shows the 4-step project, marked edited.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-H23 | closes (now `halo/autosave-history`) | J | `testJumpAndRecover` step 3 | `title.halo` |
| RJ-H33 | adds, closes with `halo/autosave-history` | C | `Tests/RealJobs/halo/history-jump/history-jump.jobs.json`: `layer.select`, 10 `inspector.set-property {"property": "x", …}` at frames 0…9, `history.jump {"index": 4}`, save, reopen | `input/one-solid.halo` |

Trap: the jump replays forward from the save and drops the keys' easing, or
records a step. Assertion: the reopened layer has 4 keys on `x` with their
values and easings. Mutation: `HaloModel.HaloRecovery+Kernel.json` (jump
lands on `index + 1` → `.jumpLandsOnIndex`).

## Screens and states

`halo-history-panel` (light and dark), `-jumped`, `halo-recovery-offer`.

## Contract slice

```swift
// Sources/HaloModel/HaloRecovery+Kernel.swift (HA-1 stubs, HA-5 bodies)
extension HaloProject: HistoryJumping {
    public var historyListing: HistoryListing { get }       // base "Open" or "New Project"
    public mutating func jumpHistory(to index: Int) throws  // HaloHistory's kernel jump
}
extension HaloProject {
    public func recoveryBytes() throws -> Data              // the project as HaloFiles writes it
    public static func recovered(from data: Data, name: String?) throws -> HaloProject   // dirty, never saved
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HA-1 | – | The adapter's signatures as stubs; `HaloRecoveryTests` written, disabled | `Sources/HaloModel/HaloRecovery+Kernel.swift`, `Tests/HaloModelTests/HaloRecoveryTests.swift` | – | ~120, 2 |
| HA-2 | – | The History panel and autosave hooks on the stubs: `HaloHistoryArea`, one line in the window, Edit > Show History; the journey written, skipped | `Sources/HaloApp/HaloHistoryArea.swift`, `Sources/HaloApp/HaloWindow.swift`, `Sources/HaloApp/HaloEditMenu.swift`, `UITests/HaloJourneyTests+History.swift` | HA-1 | ~200, 4 |
| HA-3 | – | The History button by the transport; the panel follows undo and jumps; its tests | `Sources/HaloApp/HaloHistoryArea.swift`, `Sources/HaloApp/HaloControls.swift`, `Tests/AppSnapshotTests/HaloHistoryAreaTests.swift` | HA-2 | ~140, 3 |
| HA-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/HaloHistorySnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHaloHistoryTests.swift` | HA-3 | ~180, 2 |
| HA-5 | – | Adapter bodies: the jump, the recovery bytes, the recovered project; turns on `HaloRecoveryTests` | `Sources/HaloModel/HaloRecovery+Kernel.swift`, `Tests/HaloModelTests/HaloRecoveryTests.swift`, `Tests/mutations/HaloModel.HaloRecovery+Kernel.json` | HA-1 | ~200, 3 |
| HA-6 | – | The two history specs in the catalog and id list; RJ-H33's job folder | `Sources/HaloModel/HaloCommandCatalog.swift`, `Tests/command-ids/halo.txt`, `Tests/HaloModelTests/HaloHistoryCommandIDTests.swift`, `Tests/RealJobs/halo/history-jump/history-jump.jobs.json`, `Tests/RealJobs/halo/history-jump/input/one-solid.halo` | HA-5 | ~120, 5 |
| HA-7 | – | The journey turned on, on live services | `UITests/HaloJourneyTests+History.swift` | HA-4, HA-6 | ~60, 1 |
| HA-8 | – | `status: built`; `feature-done` | `docs/blueprints/halo/features/autosave-history.wave.json` | HA-7 | ~10, 1 |

## Build waves

- Wave 1: HA-1. Independent in this wave: HA-1 alone.
- Wave 2: HA-2, HA-5. Independent in this wave: both.
- Wave 3: HA-3, HA-6. Independent in this wave: both.
- Wave 4: HA-4. Independent in this wave: HA-4 alone.
- Wave 5: HA-7. Independent in this wave: HA-7 alone.
- Wave 6: HA-8 (`feature-done`, final). Independent in this wave: HA-8 alone.

Longest chain: HA-1 → HA-2 → HA-3 → HA-4 → HA-7 → HA-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| HA-1 | `HaloRecoveryTests` compiles, disabled | – | – (stub) |
| HA-2 | `HaloWindowSnapshots`: the History panel shows on the stubs; Edit > Show History toggles it | the panel or the item is missing | – (UI) |
| HA-3 | `HaloHistoryAreaTests`: a row click emits one jump; the button toggles the panel; the panel follows undo | a jump is doubled or the button is dead | – (UI) |
| HA-4 | `HaloHistorySnapshots`; `RenderBudgetHaloHistoryTests.arrowWalkInThreeBodies` | budget over | – (UI) |
| HA-5 | `HaloRecoveryTests`: a jump to 4 of 10 key edits restores those keys and records nothing; recovery bytes reopen dirty and never saved; damaged bytes throw | a key, a step or the saved mark is wrong | `HaloModel.HaloRecovery+Kernel`: `index + 1` → `.jumpLandsOnIndex`; restored marked saved → `.recoveredIsDirty` |
| HA-6 | `HaloHistoryCommandIDTests`: the two specs listed and run; RJ-H33 passes on Linux | an id is missing | – (registration) |
| HA-7 | `testJumpAndRecover` steps 1 to 3 on live | a step fails | – |
| HA-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: arrow-key walk down 30 steps with the viewer live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHaloHistoryTests.arrowWalkInThreeBodies` |
| One gesture, one step | a jump adds no step | `HaloRecoveryTests.jumpRecordsNothing` |
| No dead controls; keyboard parity | the button and menu item identified; arrows and Return jump | `testJumpAndRecover` |
| Audit | zero new over Halo's baseline | `audit-halo-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): HA-m merged-done with RJ-H33 green in the
Linux job; HA-u's feel gate and `Mac-Finish:`; HA-z's journey on live and
RJ-H23 green in the scoped run. Then `Belt-Contact-Sheet:` with
`halo-history-*`.

## Not in this packet

Render-queue recovery (an interrupted render restarts by hand), history
snapshots.
