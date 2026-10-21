# Feature packet: autosave-history (Design)

**Feature:** Design stops losing work. A Design window autosaves a recovery
copy a delay after each edit through SuiteUI's `.autosaveRecovery` and
SuiteModel's `RecoveryFolder`, offers it back after a crash or force-quit, and
shows a History panel (View > Show History, or the toolbar's History button)
listing the document's steps from its kernel `History`; a click jumps to any
step. Both are the shared builds: Design adds only its hooks.
**Line:** `line:design` · **Wave:** 3 (`waves.md`) · **Lead branch:** `lead/autosave-history`
**Beta:** captain, 2026-10-20 (the audit's "Design and Halo lose work today"). Labels `beta` and `p0` when filed.

**Covers:** feature map `design/autosave-history` (adopter of S12); real jobs
RJ-D20 (force-quit with unsaved work, relaunch) and RJ-D33 (new: jump back
ten steps, save, reopen).

**Depends on:** `suiteui/autosave-history` **AH-a** (cross-line); DA-5 needs
**AH-m**, DA-2's autosave **AH-z** for the real modifier before DA-7. Same
line: gradient-fill's **DG-m** before DA-6 (both own
`DesignCommandCatalog.swift` and `Tests/command-ids/design.txt`). Built or
earlier: design-window (the window), files-history (save and the kernel
session, AD-design), design-export (its menu items).

**Hand-offs:** `DesignCommands.swift` and `DesignWindow.swift` are also
edited by design-export (DE-u) and design-window; DA-2 adds one menu item and
one modifier line and rebases onto whichever lands first. `design-seams-2`
(p3, cut) now waits on this feature.

**Rule 20.** No Design autosave or history list: the window passes hooks to
the shared modifier, the panel reads `History.listing`, and recovery bytes are
`DesignFile`'s own encoding. The only new Model file is the adapter
`DesignRecovery+Kernel.swift`.

**Render path.** None.

Blueprint sections: design.md 7 (files), 8.2 (menus).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| DA-a | The adapter is declared as stubs and the History panel and the autosave hooks are on the window, reachable from View > Show History. | DA-1, DA-2 | MJ-DA | shell-parity |
| DA-u | The toolbar button toggles the panel, the panel follows undo and jumps, and the snapshots and render budget hold. | DA-3, DA-4 | J-DA | DA-a, shell-parity |
| DA-m | A jump lands on its step without recording one, recovery bytes reopen as a dirty never-saved document, and the history commands run from the catalog. | DA-5, DA-6 | MJ-DA | DA-a, gradient-fill:DG-m |
| DA-z | The journey jumps and recovers after a force-quit on live services, and the feature is built. | DA-7, DA-8 | J-DA | DA-u, DA-m |

DA-u waits only on DA-a (rule 18); DA-m never waits on DA-u. MJ-DA is the
Model walk in `DesignRecoveryTests` (Linux).

## Journey steps

1. Open `card.design`, make 12 edits, click the toolbar's History button
   (DA-2, `DesignHistoryJourneyTests.testJumpAndRecover`): the panel lists
   "Open" and 12 steps.
2. Click step 2: the canvas shows the card after two edits; later rows dim.
3. Make one more edit: the dimmed rows go.
4. Force-quit the app with the edit unsaved, relaunch (DA-7): the alert offers
   "Restore the autosaved changes to “card.design”?"; Restore shows the
   3-step card, marked edited.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-D20 | closes (now `design/autosave-history`) | J | `testJumpAndRecover` step 4: kill the app 2 s after the autosave delay, relaunch, Restore | `card.design` |
| RJ-D33 | adds, closes with `design/autosave-history` | C | `Tests/RealJobs/design/history-jump/history-jump.jobs.json`: `edit.select` one node, 30 `object.nudge {"dx": 1, "dy": 0}`, `history.jump {"index": 20}`, save, reopen | `input/one-card.design` |

Traps: D20, the restored copy is the last save, not the last autosave; D33,
the jump records a step so the saved file has 31 steps' changes, or the save
writes the pre-jump state. Assertion (D33): the reopened node sits where the
20th move left it. Mutation: `DesignModel.DesignRecovery+Kernel.json` (jump
lands on `index + 1` → `.jumpLandsOnIndex`).

## Screens and states

`design-history-panel` (light and dark), `-jumped`, `design-recovery-offer`.

## Contract slice

```swift
// Sources/DesignModel/DesignRecovery+Kernel.swift (DA-1 stubs, DA-5 bodies)
extension DesignWorkspace: HistoryJumping {
    public var historyListing: HistoryListing { get }       // base "Open" or "New Design"
    public mutating func jumpHistory(to index: Int) throws  // DesignHistory's kernel jump
}
extension DesignWorkspace {
    public func recoveryBytes() throws -> Data              // the document as DesignFile writes it
    public static func recovered(from data: Data, name: String?) throws -> DesignWorkspace   // dirty, never saved
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| DA-1 | – | The adapter's signatures as stubs; `DesignRecoveryTests` written, disabled | `Sources/DesignModel/DesignRecovery+Kernel.swift`, `Tests/DesignModelTests/DesignRecoveryTests.swift` | – | ~120, 2 |
| DA-2 | – | The History panel and autosave hooks on the stubs: `DesignHistoryArea` (the trailing panel, `.autosaveRecovery`), one line in the window, View > Show History; the journey written, skipped | `Sources/DesignApp/DesignHistoryArea.swift`, `Sources/DesignApp/DesignWindow.swift`, `Sources/DesignApp/DesignCommands.swift`, `UITests/DesignJourneyTests+History.swift` | DA-1 | ~200, 4 |
| DA-3 | – | The toolbar's History button; the panel follows undo and jumps; its tests | `Sources/DesignApp/DesignHistoryArea.swift`, `Sources/DesignModel/DesignToolbarItems.swift`, `Tests/AppSnapshotTests/DesignHistoryAreaTests.swift` | DA-2 | ~140, 3 |
| DA-4 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/DesignHistorySnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignHistoryTests.swift` | DA-3 | ~180, 2 |
| DA-5 | – | Adapter bodies: the jump, the recovery bytes, the recovered workspace; turns on `DesignRecoveryTests` | `Sources/DesignModel/DesignRecovery+Kernel.swift`, `Tests/DesignModelTests/DesignRecoveryTests.swift`, `Tests/mutations/DesignModel.DesignRecovery+Kernel.json` | DA-1 | ~200, 3 |
| DA-6 | – | The two history specs in the catalog and id list; RJ-D33's job folder | `Sources/DesignModel/DesignCommandCatalog.swift`, `Tests/command-ids/design.txt`, `Tests/DesignModelTests/DesignHistoryCommandTests.swift`, `Tests/RealJobs/design/history-jump/history-jump.jobs.json`, `Tests/RealJobs/design/history-jump/input/one-card.design` | DA-5 | ~120, 5 |
| DA-7 | – | The journey turned on, on live services | `UITests/DesignJourneyTests+History.swift` | DA-4, DA-6 | ~60, 1 |
| DA-8 | – | `status: built`; `feature-done` | `docs/blueprints/design/features/autosave-history.wave.json` | DA-7 | ~10, 1 |

## Build waves

- Wave 1: DA-1. Independent in this wave: DA-1 alone.
- Wave 2: DA-2, DA-5. Independent in this wave: both.
- Wave 3: DA-3, DA-6. Independent in this wave: both.
- Wave 4: DA-4. Independent in this wave: DA-4 alone.
- Wave 5: DA-7. Independent in this wave: DA-7 alone.
- Wave 6: DA-8 (`feature-done`, final). Independent in this wave: DA-8 alone.

Longest chain: DA-1 → DA-2 → DA-3 → DA-4 → DA-7 → DA-8 (6). Chain of 6: the screen needs the stubs, the budget times the screen, the journey runs on the live Model, and the last task is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| DA-1 | `DesignRecoveryTests` compiles, disabled | – | – (stub) |
| DA-2 | `DesignEditorSnapshots`: the History panel shows on the stubs; View > Show History toggles it | the panel or the item is missing | – (UI) |
| DA-3 | `DesignHistoryAreaTests`: a row click emits one jump intent; the toolbar button toggles the panel; the panel follows undo | a jump is doubled or the button is dead | – (UI) |
| DA-4 | `DesignHistorySnapshots`; `RenderBudgetDesignHistoryTests.arrowWalkInThreeBodies` | budget over | – (UI) |
| DA-5 | `DesignRecoveryTests`: a jump to 2 of 12 restores that document and records nothing; recovery bytes reopen as the same nodes, dirty and never saved; damaged bytes throw | a node, a step or the saved mark is wrong | `DesignModel.DesignRecovery+Kernel`: `index + 1` → `.jumpLandsOnIndex`; restored marked saved → `.recoveredIsDirty` |
| DA-6 | `DesignHistoryCommandTests`: the two history specs are listed and run; RJ-D33 passes on Linux | an id is missing | – (registration) |
| DA-7 | `testJumpAndRecover` steps 1 to 4 on live | a step fails | – |
| DA-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: arrow-key walk down 30 steps of the panel with the canvas live | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetDesignHistoryTests.arrowWalkInThreeBodies` |
| One gesture, one step | a jump adds no step | `DesignRecoveryTests.jumpRecordsNothing` |
| Autosave off the main actor | encode and write run detached | `AutosaveDriverTests` (shared) |
| No dead controls; keyboard parity | the button and menu item identified; arrows and Return jump | `testJumpAndRecover` |
| Audit | zero new over Design's baseline | `audit-design-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): DA-m merged-done with RJ-D33 green in the
Linux job; DA-u's feel gate and `Mac-Finish:`; DA-z's journey on live and
RJ-D20 green in the scoped run. Then `Belt-Contact-Sheet:` with
`design-history-*`.

## Not in this packet

History snapshots, an autosave interval setting (Preferences already stores
`autosaveSeconds`; the default 30 s applies), versions browsing.
