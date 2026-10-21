# Feature packet: autosave-history

**Feature:** one autosave, crash recovery and History panel for the suite.
SuiteKernel gets `AutosaveSchedule`, the timing Photo's `PhotoAutosave` and
Flare's `FlareAutosave` each wrote (one write per edit, a delay after it, a
write that lands after a save removed again), and `HistoryCommands`: a
`HistoryListing` read from the kernel `History` every app already runs on
(#3022, #3139, AU-photo), with `history.read` and `history.jump`. SuiteModel
gets `RecoveryFolder`, the recovery files over the suite store's atomic
`FileStore`. SuiteUI gets `HistoryPanel` (the steps, the current one marked,
click to jump) and the `.autosaveRecovery` modifier (ticks while dirty, writes
off the main actor, offers `RecoveryOffer.prompt` at launch).
**Line:** `line:suiteui` · **Wave:** 4 (`waves.md`) · **Lead branch:** `lead/autosave-history`
**Beta:** captain, 2026-10-20 ("everyday tools, built once and shared"). Labels `beta` and `p0` when filed.

**Covers:** feature map S12 (autosave, crash recovery, History panel; the
re-cut of Photo's PV-4 History); real job RJ-X31 (new). The adopts are
`design/autosave-history`, `halo/autosave-history` and
`photo/history-panel`, each waiting on this packet's AH-a. RJ-X24 (kill -9 in
every app) closes with S12 once the three adopts land.

**Depends on:** editor-kernel (built): `History` with `steps`, `index` and
`jump(to:)`, `DocumentSession`, `RecoveryOffer`. SuiteModel's `FileStore`
(built). In this folder: gradient-fill's **GF-a** before AH-1 (both own
`Tests/canonical-concepts.txt`) and its **GF-z** before AH-9 (both own
`FakeCanvasDocument.swift` and its plan). No creative-core issue.

**Rule 20.** Two app copies of the autosave timing exist today
(`PhotoApp/PhotoAutosave.swift`, `FlareApp/FlareAutosave.swift`). AH-1 adds
`Autosave: Autosave` to `Tests/canonical-concepts.txt` and grandfathers both
files with `scripts/check-dup-logic --update-baseline --allow-increase`
(`Allow-Dup: Autosave grandfathering the two copies this packet replaces`), so
no third copy can land. `photo/history-panel` deletes Photo's copy and drops
its baseline line; Flare's moves later (see Adopted later). The history list
is the kernel `History`'s own `steps` and `index`: no app keeps a second list.
Recovery bytes are each app's native file encoding, so no new format.

**Render path.** None: a list and an alert.

**C4:** `kernel-history.json` gains `HistoryCommands.swift`,
`kernel-export-session.json` gains `AutosaveSchedule.swift`, `suite-store.json`
gains `RecoveryFolder.swift` (AH-1). `HistoryPanel.swift` and
`AutosaveRecovery.swift` are new files under `Sources/SuiteUI/`, covered by
`suiteui-sources`.

**Clean-room.** The panel follows the HIG's list and selection rules; the
autosave rules come from Photo's and Flare's own tests. No task reads another
product's code.

Blueprint sections: suiteui.md 2.2 (components), 7.1 (budgets); suite.md 1.5
(commands), 2.6 (the store).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AH-a | The kernel's schedule and history commands and the recovery folder are declared as stubs, the gallery's history-panel page is in the index, and the checks are written, disabled. | AH-1, AH-2 | SJ0 | gradient-fill:GF-a (AH-1); editor-kernel, suite-harness (built) |
| AH-u | On the gallery page the panel lists the states, marks the current one, dims the undone ones and jumps on a click or arrows and Return, every row identified, within the render budget. | AH-3, AH-4 | HJ1 | AH-a |
| AH-m | The schedule writes once per edit a delay after it and deletes a write a save overtook, a jump lands on its index without recording a step, and the folder keeps the newest recovery files and drops damaged ones. | AH-5, AH-6, AH-7 | KJ-history | AH-a |
| AH-z | The modifier autosaves and offers recovery on the live schedule and folder, the gallery jumps on a live history, the fake app jumps so RJ-X31 runs on the CLI, and the feature is built. | AH-8, AH-9, AH-10 | HJ1, KJ-history | AH-u, AH-m; gradient-fill:GF-z (AH-9) |

AH-u waits only on AH-a (rule 18); AH-m never waits on AH-u. KJ-history is the
kernel and store walk in `SuiteKernelTests` and `SuiteModelTests` (Linux).

## Journey steps

1. Open the gallery index, click `history-panel` (AH-2, SJ0): the panel lists
   "Open" and eleven steps, the eighth current, the three after it dimmed.
2. Click the fourth step (AH-3, `SuiteHistoryJourneyTests.testHistoryPanelJumps`):
   it is current, every step after it dims; the page's log shows one
   `history.jump {"index": 4}`.
3. Press Down twice, then Return: the sixth step is current (one more
   `history.jump`). Up past "Open" stays on "Open".
4. Click "Open": nothing is applied, every step dims, the log shows index 0.
5. On live (AH-8) the same clicks run `HistoryCommands` on a local target with
   a kernel `History`, and the page's Undo button then undoes from the jumped
   state. VoiceOver reads a row as "Step 6 of 11, Move, applied" (AH-4).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X31 | adds, closes with S12 | C | `Tests/RealJobs/fake/history-jump/history-jump.jobs.json`: 30 `rect.move`, `history.jump {"index": 20}`, `history.read`, one more `rect.move`, `history.read`; the saved rects | `input/one.fake` (one free rect) |

Trap: the jump records a step of its own (so Undo goes back to step 30), or
the redo steps survive the new edit. Assertion: after the jump the listing
reads 30 steps at index 20 and the rect sits where the 20th move left it;
after the new move it reads 21 steps at index 21. Mutations:
`SuiteKernel.HistoryCommands.json` (the jump records a step → `.jumpRecordsNoStep`;
`index - 1` jumped → `.jumpLandsOnIndex`).

## Screens and states

`suiteui-history-panel` (light and dark: current row, dimmed undone rows),
`-saved` (the saved step's dot), `-empty` ("Open" alone, "No changes yet."),
`suiteui-recovery-alert` (the offer naming the document and its time).

## Contract slice

```swift
// Sources/SuiteKernel/Session/AutosaveSchedule.swift (AH-1 stub, AH-5 body). Times in the caller's clock.
/// When an open document writes its recovery copy: once per edit, `delay` after it, never twice for one
/// edit, and a write that finishes after a save or a discard is deleted again.
public struct AutosaveSchedule: Hashable, Sendable {
    public struct Ticket: Hashable, Sendable { public let edit: Double }
    public enum Finish: Hashable, Sendable { case keep, discard, retryOnNextEdit }
    public init(delay: Double)
    public var isWritten: Bool { get }                         // the newest edit's bytes are on disk
    public mutating func noteEdit(at time: Double)
    public mutating func begin(now: Double, dirty: Bool) -> Ticket?   // nil unless a write is due
    public mutating func finish(_ ticket: Ticket, wrote: Bool) -> Finish
    public mutating func didSave(stillDirty: Bool)              // an edit made during the save stays due
    public mutating func didDiscard()
}
// Sources/SuiteKernel/History/HistoryCommands.swift (AH-1 specs with ids, schemas and availability, runs throwing
// `HistoryCommands.notBuilt`; AH-6 bodies)
public struct HistoryListing: Hashable, Sendable, Codable {
    public var base: String          // "Open", "New Image": the state before the first step
    public var steps: [String]       // every step's name, oldest first, undone ones included
    public var index: Int            // how many steps are applied, 0...steps.count
    public var savedIndex: Int?      // the applied count at the last save; nil when no listed state is saved
}
extension History { public func listing(base: String) -> HistoryListing }
public protocol HistoryJumping: Sendable {
    var historyListing: HistoryListing { get }
    /// Undoes or redoes until `index` steps are applied: no new step, the open run ended.
    mutating func jumpHistory(to index: Int) throws
}
public enum HistoryCommands {
    public static func specs<T: HistoryJumping>(_ target: T.Type) -> [CommandSpec<T>]
}
// Sources/SuiteModel/Store/RecoveryFolder.swift (AH-1 stub throwing `.notBuilt`, AH-7 body)
public struct RecoveryItem: Hashable, Sendable {
    public var window: String, name: String?, savedAt: Double, data: Data
}
public struct RecoveryFolder: Sendable {
    public init(store: FileStore, ext: String)                  // files under "Recovery/" in the store's folder
    public func write(_ data: Data, window: String, name: String?, at: Double) throws(SuiteError)
    public func leftBehind() throws(SuiteError) -> [RecoveryItem]   // newest first; a damaged pair is dropped
    public func discard(window: String) throws(SuiteError)
    public func discardAll() throws(SuiteError)
}
// Sources/SuiteUI/HistoryPanel.swift (AH-2 placeholder, AH-3 view)
public struct HistoryPanel: View {
    public init(listing: HistoryListing, onJump: @escaping @MainActor (Int) -> Void)
}
// Sources/SuiteUI/AutosaveRecovery.swift (AH-2 stub that never writes or offers, AH-8 body)
public struct AutosaveHooks {
    public var window: String
    public var documentName: @MainActor () -> String?
    public var isDirty: @MainActor () -> Bool
    public var encoder: @MainActor () -> (@Sendable () throws -> Data)?   // copies the value on main, encodes off it
    public var restore: @MainActor (Data) async throws -> Void
}
extension View {
    /// `edits` changes on every edit (the history's current step id). `folder` nil turns autosave off
    /// (the journeys' `-ApplePersistenceIgnoreState` launch).
    public func autosaveRecovery(_ hooks: AutosaveHooks, folder: RecoveryFolder?, delay: Double, edits: Int) -> some View
}
```

Commands (ids go in each adopter's `Tests/command-ids/<app>.txt`):

| id | title | kind | params | unavailable when |
|---|---|---|---|---|
| `history.read` | – | query | – → `{base, steps, index, savedIndex?}` | never |
| `history.jump` | Jump in History | view (like `edit.undo`) | `{index}` | no steps ("There are no steps yet."); an index outside `0...steps.count` throws "There is no step <n>." |

An app adds both with `+ HistoryCommands.specs(<X>Workspace.self)` and its
`<X>Recovery+Kernel.swift` conformance (a one-line `jumpHistory` over the
`History.jump(to:)` its undo adapter already wraps).

## Pseudocode

- **begin.** Due when `dirty`, `lastEdit` is set, `lastEdit != writtenEdit`
  and `now - lastEdit >= delay` (a non-finite or negative delay never is).
  Taking a ticket sets `writtenEdit = lastEdit`, so one edit writes once.
- **finish.** A save or discard since the ticket (a counter, as Photo's
  `resets`) → `.discard` when it wrote; a failed write keeps `writtenEdit`
  and returns `.retryOnNextEdit` (the next edit, not the next tick, tries
  again, so a failing disk isn't hammered every second); else `.keep`.
- **listing.** `steps` is `History.steps`, `index` is `History.index`;
  `savedIndex` is the position whose id is `savedStepID` (nil when it rolled
  past the limit).
- **jump.** Clamp nothing: an index outside the range throws. Equal to the
  current index is a no-op. Otherwise the target's `History.jump(to:)`, the
  open run ended first so the jump never folds into it.
- **RecoveryFolder.** Two files per window: `Recovery/<window>.<ext>` (raw,
  `FileStore.writeData`, atomic) and `Recovery/<window>.json` (`{name,
  savedAt}`, written second). `leftBehind` pairs them, drops a pair whose
  JSON is missing or damaged (and deletes it), sorts newest first.
- **Modifier.** A one-second task while `isDirty()`; each tick
  `schedule.begin` → if a ticket, `encoder()` on main, encode and
  `folder.write` in one detached task, `finish` on main. A clean document
  discards. On appear, `leftBehind` off main; the newest item becomes a
  `RecoveryOffer(name:savedAt:)` alert: Restore → `restore(data)`, then keep
  the file until the next save; Discard → `discard(window:)`.
- **View.** One `List` row per state ("Open", then each step), the current
  row selected, rows after it at secondary opacity, the saved state with a
  small dot. Arrows move the selection, Return or a click jumps.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AH-1 | – | The contract as stubs: `AutosaveSchedule`, `HistoryListing`, `HistoryJumping`, the two specs with ids, schemas and availability, `RecoveryFolder`; the `Autosave` concept line and the two grandfathered files; the C4 parts' paths; the three suites written, disabled by name | `Sources/SuiteKernel/Session/AutosaveSchedule.swift`, `Sources/SuiteKernel/History/HistoryCommands.swift`, `Sources/SuiteModel/Store/RecoveryFolder.swift`, `Tests/SuiteKernelTests/AutosaveScheduleTests.swift`, `Tests/SuiteKernelTests/HistoryCommandsTests.swift`, `Tests/SuiteModelTests/RecoveryFolderTests.swift`, `Tests/canonical-concepts.txt`, `Tests/canonical-baseline.txt`, `docs/c4/parts/creative-apps/suite-kernel/kernel-history.json`, `docs/c4/parts/creative-apps/suite-kernel/kernel-export-session.json`, `docs/c4/parts/creative-apps/suite-model/suite-store.json` | – | ~330, 11 |
| AH-2 | – | The placeholder `HistoryPanel` and the `.autosaveRecovery` stub; the gallery's `history-panel` page in `GalleryLists.pages` on a local listing; the journey written and skipped (`XCTSkip("waits on AH-4")`) | `Sources/SuiteUI/HistoryPanel.swift`, `Sources/SuiteUI/AutosaveRecovery.swift`, `Sources/SuiteUI/Gallery/GalleryHistoryPanel.swift`, `Sources/SuiteUI/Gallery/GalleryLists.swift`, `UITests/SuiteJourneyTests+History.swift` | AH-1 | ~200, 5 |
| AH-3 | – | The panel: one row per state, the current one selected, later ones dimmed, the saved dot, click and arrow-and-Return jumps, identifiers `suite.history.row.<n>` | `Sources/SuiteUI/HistoryPanel.swift`, `Tests/SuiteUITests/HistoryPanelTests.swift` | AH-2 | ~220, 2 |
| AH-4 | – | Snapshots, the render budget test, the journey turned on | `Tests/AppSnapshotTests/SuiteHistoryPanelSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetHistoryPanelTests.swift`, `UITests/SuiteJourneyTests+History.swift` | AH-3 | ~200, 3 |
| AH-5 | – | `AutosaveSchedule` body; turns on `AutosaveScheduleTests` | `Sources/SuiteKernel/Session/AutosaveSchedule.swift`, `Tests/SuiteKernelTests/AutosaveScheduleTests.swift`, `Tests/mutations/SuiteKernel.AutosaveSchedule.json` | AH-1 | ~200, 3 |
| AH-6 | – | `History.listing`, the two spec bodies; turns on `HistoryCommandsTests` on a test target | `Sources/SuiteKernel/History/HistoryCommands.swift`, `Tests/SuiteKernelTests/HistoryCommandsTests.swift`, `Tests/mutations/SuiteKernel.HistoryCommands.json` | AH-1 | ~220, 3 |
| AH-7 | – | `RecoveryFolder` body over `FileStore`; turns on `RecoveryFolderTests` | `Sources/SuiteModel/Store/RecoveryFolder.swift`, `Tests/SuiteModelTests/RecoveryFolderTests.swift`, `Tests/mutations/SuiteModel.RecoveryFolder.json` | AH-1 | ~200, 3 |
| AH-8 | – | The modifier's body (`AutosaveDriver` on the schedule and the folder, the recovery alert); the gallery page jumps through `HistoryCommands` on a local target with a kernel `History`; the driver tests | `Sources/SuiteUI/AutosaveRecovery.swift`, `Sources/SuiteUI/Gallery/GalleryHistoryPanel.swift`, `Tests/SuiteUITests/AutosaveDriverTests.swift` | AH-4, AH-5, AH-6, AH-7 | ~300, 3 |
| AH-9 | – | The fake app conforms to `HistoryJumping` and lists the two specs; RJ-X31's job folder | `Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift`, `Tests/SuiteKernelTests/FakeHistoryTests.swift`, `Tests/mutations/SuiteKernel.FakeCanvasDocument.json`, `Tests/RealJobs/fake/history-jump/history-jump.jobs.json`, `Tests/RealJobs/fake/history-jump/input/one.fake` | AH-6 | ~160, 5 |
| AH-10 | – | The C4 parts name the commands, the panel and the modifier; `status: built`; `feature-done` | `docs/c4/parts/creative-apps/suite-kernel/kernel-history.json`, `docs/blueprints/suiteui/features/autosave-history.wave.json` | AH-8, AH-9 | ~20, 2 |

AH-1 declares every type and spec so AH-5, AH-6 and AH-7 each fill one file.

## Build waves

- Wave 1: AH-1. Independent in this wave: AH-1 alone.
- Wave 2: AH-2, AH-5, AH-6, AH-7. Independent in this wave: all 4.
- Wave 3: AH-3, AH-9. Independent in this wave: both.
- Wave 4: AH-4. Independent in this wave: AH-4 alone.
- Wave 5: AH-8. Independent in this wave: AH-8 alone.
- Wave 6: AH-10 (`feature-done`, final). Independent in this wave: AH-10 alone.

Longest chain: AH-1 → AH-2 → AH-3 → AH-4 → AH-8 → AH-10 (6). Chain of 6: the page needs the module's types, the view fills the placeholder, the budget and journey time the view, the live page runs the commands under the journey, and AH-10 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AH-1 | the three suites compile, disabled by name; `KernelShapeTests.importsOnlyFoundationAndFlareCore` passes; `check-dup-logic` passes with the concept line and the two grandfathered files | the kernel imports past Foundation, or a third Autosave file exists | – (stubs) |
| AH-2 | SJ0: the index lists `history-panel`; the page opens; the journey is written, skipped | the page is missing | – (UI) |
| AH-3 | `HistoryPanelTests`: a click on row 4 calls `onJump(4)` once; Down, Down, Return calls it with 6; Up on "Open" stays at 0; rows past `index` read as not applied | a jump is doubled, missed or off by one | – (UI) |
| AH-4 | `SuiteHistoryPanelSnapshots`; `RenderBudgetHistoryPanelTests.arrowWalkInThreeBodies`; `testHistoryPanelJumps` steps 1 to 4 | budget over, or a step fails | – (UI) |
| AH-5 | `AutosaveScheduleTests`: no ticket before `delay`; one ticket per edit; a save during the write gives `.discard`; a failed write gives `.retryOnNextEdit` and no ticket until the next edit; NaN delay never due | a write is doubled, kept after a save, or retried every tick | `SuiteKernel.AutosaveSchedule`: `>` for `>=` on the delay → `.dueExactlyAtDelay`; resets not compared → `.saveDuringWriteDiscards`; `writtenEdit` cleared on failure → `.failedWriteWaitsForEdit` |
| AH-6 | `HistoryCommandsTests`: `history.read` of 5 steps with 2 undone reads index 3; `history.jump` to 1 undoes two and records nothing; out of range throws its sentence; a jump ends the open run | a jump records a step or lands one off | `SuiteKernel.HistoryCommands`: the jump records a step → `.jumpRecordsNoStep`; `index - 1` jumped → `.jumpLandsOnIndex`; run not ended → `.jumpEndsRun` |
| AH-7 | `RecoveryFolderTests` (a temp folder): write then `leftBehind` returns it; two windows newest first; a missing JSON drops and deletes the pair; `discard` removes both files | an item is lost, ordered wrong, or a damaged pair survives | `SuiteModel.RecoveryFolder`: sorted oldest first → `.newestFirst`; damaged pair kept → `.damagedPairDropped` |
| AH-8 | `AutosaveDriverTests` (a fake clock and a temp folder): an edit writes once after the delay; a save removes the file; a launch with a left-behind file offers it and Restore hands its bytes back; `testHistoryPanelJumps` step 5 on live | the driver writes twice, keeps a saved file or offers nothing | – (UI) |
| AH-9 | `FakeHistoryTests`: the fake lists `history.read` and `history.jump`; RJ-X31 passes on Linux | a jump records a step on the fake | `SuiteKernel.FakeCanvasDocument`: `jumpHistory` records → `.fakeJumpRecordsNothing`; base named "" → `.fakeBaseIsOpen` |
| AH-10 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: arrow-key walk down 50 steps of the panel | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHistoryPanelTests.arrowWalkInThreeBodies` |
| render: 120-sample hover across rows | ≤ 3 window bodies; p95 ≤ 8 ms | `RenderBudgetHistoryPanelTests.hoverInThreeBodies` |
| One gesture, one step | a jump adds no step; Undo after a jump undoes the step before it | `HistoryCommandsTests.jumpRecordsNoStep` |
| Autosave stays off the main actor | the encode and write run in a detached task; main does only the copy | `AutosaveDriverTests.encodesOffMain` |
| No dead controls; keyboard and VoiceOver | every row identified `suite.history.row.<n>`, Tab reaches the list, rows read "Step n of m, name, applied" | `testHistoryPanelJumps` |
| Audit | zero new over the SuiteUI baseline | `audit-suiteui-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): AH-m merged-done on the Linux job with
`Mutate:` scores clean; AH-u's feel gate (`mouse`, `taste`, `job` lenses) and
its `Mac-Finish:` line; AH-z's journey on live and RJ-X31 green in the Linux
job. Then `Belt-Contact-Sheet:` with `suiteui-history-panel-*`.

## Adopted by

`design/autosave-history` (Design loses work today: autosave, recovery, the
panel; RJ-D20, RJ-D33), `halo/autosave-history` (the same for Halo; RJ-H23,
RJ-H33), `photo/history-panel` (Photo's History tab, PV-4's re-cut, and
`PhotoAutosave` onto the schedule; RJ-P28). Each waits on AH-a.

## Adopted later

Flare: `FlareAutosave`'s timing onto `AutosaveSchedule` and `FlareRecovery`
onto the modifier, deleting its baseline line (one small adopt after the
beta). Library has no document to recover. A Settings field for the autosave
interval (Preferences already stores `autosaveSeconds`).

## Not in this packet

A history snapshot ("New Snapshot"), branching history, history that survives
a relaunch, per-layer history, a non-linear history brush.
