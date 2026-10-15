# Feature packet: files-history

**Feature:** never lose work and always know whether it is saved: the
system Undo and Redo inside text fields, an unsaved-changes dot and a
"Saved" state in the top bar, a close prompt for unsaved changes, the file
codec behind `DocumentFiling`, and a journey for opening bad files.
(Blueprint F5.)
**Line:** `line:design` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/files-history`

**Covers:** #275 (system undo lost in text fields; the close prompt),
#270 (Save stays bright after saving), #288 (part: the File menu and save
status ids). The lead files at stage 1 one `gap` issue, "Design: a journey
for opening bad files" (`gap`, `line:design`, `p1`, `in-progress`;
blueprint 8.1), which FH-6 closes.

**Depends on:** the design-window feature issue (the window's launch
arguments `-DesignFixture`, `-DesignSaveTo`, `-DesignOpenFile` and
`perform`; design-seams' `LiveFiling` stub) and, through it, #778. The top
bar's save status is editor-chrome EC-4 (#339, `EditorSaveStatus`); until
that feature merges, FH-4 shows the state as plain text in the status line
(`design.status.save`) and the lead files a `line:design` follow-up,
"Design: adopt `EditorSaveStatus` in the top bar", with `Depends on:` the
editor-chrome feature issue once it is filed (#339 until then). P4 needs
#330 and #333 (suite-harness). No creative-core issue.

Blueprint sections: 4 (J3, J13, J14, J16, P4; the bad files), 5.4
(`DocumentFiling`), 6 (rule 6, the alerts row, File > Close), 7.1 (QD-S11
screen half), 7.4 (QD-V1), 8.2 (F5), 9 Q4 (no autosave in v1).

## Journey steps

In `UITests/DesignJourneyTests+Files.swift`, class
`DesignFilesJourneyTests`, live services:

1. **J13** `testUndoInTextFieldsAndDirtyState` on `cards` with
   `-DesignSaveTo <tmp>`: select A, type in the X field, press ⌘Z inside
   the field: the field's typing is undone and the document's undo name
   is unchanged (#275); Escape; draw a rectangle: the unsaved dot shows;
   ⌘S: the state reads "Saved", no panel opened (#270).
2. **J14** `testCloseWithUnsavedChanges` on `cards`: draw; ⌘W: the alert
   names the file ("Untitled" for an unsaved fixture); Cancel keeps the
   window; ⌘W; Don't Save closes it. A clean window closes on ⌘W with no
   alert.
3. **J16** `testOpenBadFiles` (`+BadFiles`, class
   `DesignBadFilesJourneyTests`): the test writes the four bad files into its
   temp folder and launches with `-DesignOpenFile` on each: the alert reads
   "It is not a Design file.", "It was made by a newer version of Design
   (file version 99).", "It has no pages.", "It uses the id node-2 more
   than once."; the window stays empty. (Live-only: `FakeFiling` has no
   version check; a fake-mode run skips it with a message naming the
   fake.)
4. **P4** `testOpenLargeFile` (`+PerfFiles`, class
   `DesignPerfFilesJourneyTests`) on `crowd` with `-DesignSaveTo <tmp>`,
   then `-DesignOpenFile <tmp>`: ⌘S; relaunch on the saved file; progress
   within QB-L9, no stall over QB-L12; report-only.

J3 (`testDrawShapesAddTextAndSave`, existing) keeps passing: its save and
reopen now run through `LiveFiling`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Top bar / status save state | no file: nothing shown | a failed save: the state stays unsaved and the status message reads the reason ("There is no file open to save.") | – |
| Unsaved dot | a clean or new file: no dot | – | – |
| Close prompt (system alert) | a clean window: no prompt | Save that fails keeps the window open with the reason | – |
| Open failure (system alert) | – | the four reasons above; the window keeps what it had | opening `crowd` shows the window's progress within 100 ms (QB-L9) |
| Undo in a text field | – | – | – (⌘Z, ⇧⌘Z act on the field's text while it has focus; the menu titles read the field's "Undo Typing") |

## Contract slice

Model, `Sources/DesignModel/DesignHistory.swift`:

```swift
extension DesignWorkspace {
    /// True when the document differs from the last save or open (undoing back to it clears it).
    public var isDirty: Bool { get }
    /// "Saved" after a save, "Edited" with unsaved changes, nil with no file open.
    public var saveStateText: String? { get }
    /// `DesignFile.swift`'s existing `didSave(to:)` also marks the current step as saved
    /// and ends the edit run, so the next nudge starts a new step.
    public mutating func didSave(to url: URL)
    /// Where Edit > Undo and Redo go: the focused text field's own undo, or the document's.
    public func undoTarget(textFieldFocused: Bool) -> DesignUndoTarget   // .field / .document
    /// The close prompt's message, or nil when the window may close at once.
    public var closePrompt: String? { get }   // "Do you want to save the changes you made to “Untitled”?"
}
```

`DocumentFiling` (blueprint 5.4) filled by `Sources/DesignModel/Live/LiveFiling.swift`:
the codec moves there from `DesignFile.swift` (same bytes, sorted keys,
same `DesignFileError` reasons); `DesignFile.swift` keeps the workspace's
`open` and `save` entry points and calls `services.filing`. A new history
entry, a swap (New File, Open) or an undo or redo past the saved step all
update `isDirty` from one saved marker: the serial of the history step that
was current when the file was written. Serials only ever increase (a
counter in `DesignHistory`), so the 100-step cap and an undo followed by a
new edit can never make a dirty document read clean.

## Pseudocode

```
DesignHistory: nextSerial: Int (only increases); Step.serial: Int; savedSerial: Int? = 0
current serial = undo.last?.serial ?? 0          # a fresh history (load, Open) is serial 0, clean
record(step): step.serial = next(); a merge into the top step re-stamps it with next()
  a step with swapsDocument (New File) also sets savedSerial = its serial: an untouched new file is clean
isDirty = isOpen && currentSerial != savedSerial
didSave(url) (DesignFile.swift, existing): documentURL = url; savedSerial = currentSerial; endEditRun()
# no edit to DesignWorkspace.swift: load() already resets `history`, newFile records through record()

closePrompt: isDirty ? "Do you want to save the changes you made to “\(title)”?" : nil
window close (DesignWindow):
  intercept the close; if let prompt: alert Save / Don't Save / Cancel
    Save → save; on success close, on failure show the reason and stay
    Don't Save → close;  Cancel → stay

Undo in text fields (DesignCommands, #275):
  menu Undo / Redo: if a text field has keyboard focus → send the standard undo:/redo: action
                    down the responder chain (the field's own undo manager); else model.undo()
  titles: the field's undo manager's title while it has focus, else the model's
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: files-history`,
`Fast-Check: pass`, `Head:`, and the snapshot PNGs it changes. FH-7 also
carries `feature-done`. Paths drop `Sources/DesignModel/` and
`Sources/DesignApp/`; Model tests are `Tests/DesignModelTests/`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| FH-1 | – | The codec moves into `LiveFiling`; `DesignFile.swift` calls `services.filing`; same bytes | `Live/LiveFiling.swift`, `DesignFile.swift`; tests `DesignFilingTests.swift` | FH-2 | ~260, 3 |
| FH-2 | #270 (Model part), #275 (Model part) | Step serials and the saved marker, `isDirty`, `saveStateText`, `didSave` marking the save, `closePrompt`, `undoTarget` | `DesignHistory.swift`, `DesignFile.swift` (`didSave` only); tests `DesignDirtyTests.swift`, `DesignUndoTargetTests.swift` | – | ~240, 4 |
| FH-3 | #275 (view part) | Edit > Undo and Redo act on a focused text field (`DesignCommands.swift`); the window's close prompt (`DesignWindow.swift`), routed through the Model's `undoTarget` | `DesignCommands.swift`, `DesignWindow.swift`; snapshots `DesignFileMenuSnapshots.swift` | FH-2 | ~280, 3 |
| FH-4 | #270 (view part); #288 (part) | The save state and unsaved dot as plain text in the status line (`design.status.save`) until EC-4; ids on the top bar's New, Open and Save items (`DesignEditor.swift`; the menu bar is FH-3's) | `DesignEditor.swift`; snapshots `DesignFileSnapshots.swift` | FH-2 | ~140, 2 |
| FH-5 | #275, #270 (close both) | J13, J14 | `UITests/DesignJourneyTests+Files.swift` | FH-3, FH-4 | ~250, 1 |
| FH-6 | gap "open bad files journey" (closes) | J16 | `UITests/DesignJourneyTests+BadFiles.swift` | FH-1 | ~120, 1 |
| FH-7 | – | P4; the shared-doc rows for `+BadFiles`: the J16 row of blueprint section 4 reads `+BadFiles`, and files-history's wave-1 owned list in `waves.md` adds `+BadFiles` | `UITests/DesignJourneyTests+PerfFiles.swift`; `docs/blueprints/design.md` (J16 row only), `docs/blueprints/design/features/waves.md` (files-history's owned list only) | FH-1 | ~104, 3; `feature-done` |

FH-1 follows FH-2 because both edit `DesignFile.swift`: FH-2 changes only
`didSave`, so it goes first and FH-1 moves the codec around it. FH-3 and
FH-4 call FH-2's `undoTarget`, `closePrompt`, `isDirty` and
`saveStateText`. FH-5's J13 and J14 need FH-3's menu and close prompt and
FH-4's status text. J16 has its own file (`+BadFiles`) so it does not wait
on J13 and J14; it and P4 open and save through FH-1's `LiveFiling`.
QD-S11's model half is design-seams' `DesignBudgetTests.fileRoundTrip`,
which FH-1 keeps passing through `LiveFiling`.

## Build waves

FH-7, the final task, owns the only shared-doc edits: J16 moved from
`+Files` to `+BadFiles`, so the blueprint's J16 row and files-history's
owned list in `waves.md` name the new file. No build task edits
`docs/c4/model.json`, `docs/design.md`, the blueprint or `waves.md`.
`+BadFiles` is new and only FH-6 owns it, so no wave-1 feature overlaps it.

- Wave 1: FH-2. Independent in this wave: FH-2 alone.
- Wave 2: FH-1, FH-3, FH-4. Independent in this wave: all three.
- Wave 3: FH-5, FH-6, FH-7 (`feature-done`, merged last). Independent in
  this wave: all three.

Longest chain: FH-2 → FH-3 → FH-5 (3); FH-2 → FH-1 → FH-6 and
FH-2 → FH-1 → FH-7 are the same length.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| FH-1 | `DesignFilingTests`: for every fixture, `LiveFiling.encode` equals today's `DesignFile` bytes (a string literal of `empty`'s file pinned in the test) and `decode(encode(f)) == f` (QD-V1); the four bad files give `.unreadable`, `.unsupportedVersion(99)`, `.noPages`, `.duplicateID("node-2")`; a refused open keeps the workspace's pages; `DesignFileTests` and `DesignLoadTests` still pass unchanged | a byte changes, a reason changes, or a refused open replaces the document |
| FH-2 | `DesignDirtyTests`: a new file is clean; one edit is dirty; `didSave` is clean; undo past the save is dirty, redo back is clean; undo past the save then a new edit is dirty; 101 edits after a save (the cap is 100) is dirty; a coalescing run (five nudges) after a save is dirty, and undo once is clean (`didSave` ended the run); `DesignUndoTargetTests`: a focused field gives `.field`, else `.document`; Open is clean; a refused edit leaves it clean; `closePrompt` is nil when clean and names "Untitled" for a fixture and the file's name for a saved file; `saveStateText` reads "Saved", "Edited", nil | a run after a save reads clean, undoing to the save reads dirty, or the prompt names the wrong file |
| FH-3 | `DesignFileMenuSnapshots` adds `design-file-menu-close` (Close ⌘W present); the menu's Undo routing reads the Model's `undoTarget` (tested on Linux in FH-2); J13 and J14 (FH-5) prove the behavior | Undo in a field reaches the document, or a clean window prompts |
| FH-4 | `DesignFileSnapshots` adds `design-file-edited` (the dot and "Edited") and `design-file-saved` ("Saved") | the dot shows on a clean file or hides on a dirty one |
| FH-5 | J13 and J14 pass on the macOS run; J13 fails if ⌘Z in the X field changes the document's undo name; J14 fails if Cancel closes the window or a clean window prompts | a step's state differs |
| FH-6 | J16 passes; it fails if any alert's words differ or the window holds a document after a refused open | a reason differs |
| FH-7 | P4 writes `perf-design-files.json` with the progress mark and the longest main-thread stall (report-only); `git grep -n 'testOpenBadFiles' docs/blueprints/design.md` shows `+BadFiles` | no progress mark is recorded, or a shared doc still names `+Files` for J16 |

## Quality tests

| quality row | budget (device / Linux debug gate; screen half) | test |
|---|---|---|
| QD-S11 open and save `crowd` | decode and encode ≤ 50 ms / ≤ 500 ms; progress within 100 ms (QB-L9); no main-thread stall over 2 refreshes (QB-L12) | `DesignBudgetTests.fileRoundTrip` (design-seams); P4 |
| QD-V1 save is stable | byte equality | `DesignFilingTests.roundTripIsStable` |
| no lost work | a dirty window never closes without a choice | J14, `DesignDirtyTests` |
| text fields keep system Undo | ⌘Z in a field acts on its text | J13 |
| error states named | four reasons word for word | J16, `DesignFilingTests` |

Autosave and crash recovery stay out of v1 (blueprint Q4); the close
prompt covers the common loss.

## Done check

- **Journeys green:** the macOS run on `dev` after the `feature-done` PR is
  green: J13, J14, J16 and P4 new; J3's save and reopen still pass.
- **Audit zero new:** that run's `design` counts are at or under the
  baseline; the alerts are system alerts and add no count.
- **Contact sheet:** the lead comments `Belt-Contact-Sheet: <run link>` on
  the feature issue with one line per journey, the audit counts, and the
  `EditorSaveStatus` follow-up issue number.
