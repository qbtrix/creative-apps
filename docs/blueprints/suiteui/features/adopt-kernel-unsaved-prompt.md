# Feature packet: adopt-kernel-unsaved-prompt

**Feature:** every editor asks the same question the same way before it
throws away unsaved work. The words and answers are already the kernel's
(`UnsavedPrompt`, `DocumentSession`); what is copied four times is the
asking: Design's `DesignClosePrompt` window-delegate guard, Photo's own
`windowShouldClose` interposer and `PhotoUnsavedPrompt`, Flare's `NSAlert` in
`FlareFilePanels`, and Halo's SwiftUI `.alert` (Open and New only; Halo has
no close guard, so Command-W on a dirty Halo project closes it today). One
SuiteUI `UnsavedGuard` does the asking for close, Open, New and Quit, and
every editor shows its save state with SuiteUI's `EditorSaveStatus`.
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/adopt-kernel-unsaved-prompt`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 15). Labels `beta` and `p1` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #15; feature map row `suiteui/adopt-kernel-unsaved-prompt`; real job
RJ-X48 (new).

**Depends on:** adopt-kernel-session (built: every app's dirty rule is
`DocumentSession`). editor-kernel (built: `UnsavedPrompt`). SuiteUI's
`EditorSaveStatus` (built).

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **UP-design:** `DesignWindow.swift` and `DesignSaveStatus.swift` are
  design/design-window DW-a's and files-history FH-b's (both planned);
  `DesignWindow.swift` is also autosave-history DA-a's, file-flow DF-a's and
  others'. UP-6 rebases onto whichever has merged.
- **UP-photo:** `PhotoWindow+File.swift` is photo/history-panel PH-m's and
  file-flow PF-m's.
- **UP-halo:** `HaloWindow+File.swift` is halo/file-flow HF-m's;
  `HaloWindow.swift` halo/autosave-history HA-a's.

**Rule 20.** One asker (`UnsavedGuard`), one set of words (`UnsavedPrompt`),
one dirty rule (`DocumentSession`), one status view (`EditorSaveStatus`).
Each app passes its hooks (name, dirty, save) and keeps its button ids
(`design.close.*`, `photo.close.*`), so the journeys don't change.

**Deleted app-local files:** `Sources/DesignApp/DesignClosePrompt.swift` and
`Sources/PhotoModel/PhotoUnsavedPrompt.swift` (UP-13), and the interposer and
`ask()` in `PhotoWindow+File.swift` (UP-8). UP-13 runs
`scripts/check-dup-logic --update-baseline` in the same PR so
`Tests/canonical-baseline.txt` drops their lines (#3642's "Unsaved prompt"
concept). `FlareSaveStatus.swift` stays (its one property feeds
`EditorSaveStatus`).

**C4:** `Sources/SuiteUI/UnsavedGuard.swift` is covered by `suiteui-sources`.

**Clean-room.** The HIG's "unsaved changes" alert; the rules come from
Design's and Photo's own tests.

Blueprint sections: suiteui.md 2.2 (components); each app's blueprint
section on closing and saving.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| UP-a | `UnsavedGuard` and `.unsavedChangesGuard` are declared as stubs, and the guard's tests and the four-editor journey are written, disabled or skipped. | UP-1, UP-2 | SJ-UP | adopt-kernel-session, editor-kernel (built, `depends`) |
| UP-u | The guard asks Save, Don't Save or Cancel as a sheet with the kernel's words before a dirty window closes, a document is replaced or the app quits, closes only after a save succeeds, and stays within the render budget. | UP-3, UP-4 | SJ-UP | UP-a |
| UP-design | Design's window asks through the guard with its `design.close.*` ids and shows `EditorSaveStatus`. | UP-5, UP-6 | DJ-UP | UP-u (UP-6); adopt-suiteui-chrome:AC-zoom (UP-6, `DesignWindow.swift`); design hand-offs |
| UP-photo | Photo's close and Quit ask through the guard with its `photo.close.*` ids, and its own interposer and alert are gone. | UP-7, UP-8 | PJ-UP | UP-u (UP-8); UP-design (UP-8, the shared journey file); shared-thumbnails:ST-z (UP-8, `PhotoWindow+File.swift`, A/C first); photo hand-offs |
| UP-flare | Flare asks through the guard before close, Open and New, and shows a failed save with `EditorSaveStatus`. | UP-9, UP-10 | FJ-UP | UP-u (UP-10); UP-photo (UP-10, the shared journey file); adopt-kernel-autosave:AK-flare (UP-10, `FlareWindow.swift`) |
| UP-halo | A dirty Halo project asks before its window closes, as well as before Open and New, and shows `EditorSaveStatus`. | UP-11, UP-12 | HJ-UP | UP-u (UP-12); UP-flare (UP-12, the shared journey file); halo hand-offs |
| UP-z | Design's and Photo's prompt files are deleted with the baseline shrunk, the four-editor journey passes on live, and the feature is built. | UP-13, UP-14 | SJ-UP | the four app slices; shared-codecs:SC-z (UP-13, `canonical-baseline.txt`, A/C first) |

UP-u waits only on UP-a (rule 18) and runs on the gallery's fake document;
the app slices adopt the finished guard, so their second tasks wait on UP-u.

**Shared-file chains:** `Tests/canonical-baseline.txt`: shared-codecs SC-z →
UP-13 → adopt-kernel-eyedropper-photo EP-z. `PhotoWindow+File.swift`:
adopt-kernel-autosave AK-8 → shared-thumbnails ST-7 → UP-8.
`FlareWindow.swift`: AK-4 → UP-10.

## Journey steps

`SJ-UP` (`SuiteUnsavedJourneyTests.testEveryEditorAsksBeforeClosing`, UP-2
writes it, each app's leg skipped until its slice): in each of Design,
Photo, Flare and Halo, make one edit and press Command-W:
1. A sheet reads "Do you want to save the changes made to the document
   “<name>”?" with Save, Don't Save and Cancel.
2. Cancel (Escape): the window stays, still dirty.
3. Command-W again, Don't Save (Command-D): the window closes.
4. A new edit, File > New: the same sheet; Save on an untitled document opens
   the Save panel, and cancelling the panel keeps the document.
Existing per-app journeys stay green: `DJ-UP`
(`DesignFilesJourneyTests.testCloseWithUnsavedChanges`), `PJ-UP`
(`PhotoDocumentsJourneyTests.testUnsavedPromptAndOpenRecent`), `FJ-UP`
(`FlareFileJourneys.testSaveAndReopen`), `HJ-UP`
(`HaloFilesJourneyTests.testSaveAndReopen`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X48 | adds, closes with `suiteui/adopt-kernel-unsaved-prompt` | J | `SuiteUnsavedJourneyTests.testEveryEditorAsksBeforeClosing` (UP-2) | a new document per app |

Trap: one editor closes a dirty window without asking (Halo today), or one
asks with different words or button order, or Cancel still closes.
Assertion: in all four the sheet's message, buttons and default match
`UnsavedPrompt` exactly, Cancel keeps the window, Don't Save closes it, and
a failed save keeps it open. A journey, because the outcome is the
interaction itself.

## Screens and states

`suiteui-unsaved-sheet` (light and dark, on the gallery's fake document),
and one `<app>-unsaved-sheet` per editor from the journey.

## Contract slice

```swift
// Sources/SuiteUI/UnsavedGuard.swift (UP-1 stubs: the modifier returns the view, `proceed` returns true; UP-3 bodies)
public struct UnsavedHooks {
    public var idPrefix: String                               // "design" → `design.close.save`, …
    public var documentName: @MainActor () -> String?         // nil: nothing to ask
    public var isDirty: @MainActor () -> Bool                 // the app's DocumentSession
    public var save: @MainActor () async -> Bool              // true only when the save landed
    public init(idPrefix: String, documentName: @escaping @MainActor () -> String?,
                isDirty: @escaping @MainActor () -> Bool, save: @escaping @MainActor () async -> Bool)
}
public enum UnsavedGuard {
    /// Before Open, New or Quit replaces the document: true when it may go on.
    @MainActor public static func proceed(_ hooks: UnsavedHooks, in window: NSWindow?) async -> Bool
}
extension View {
    /// Puts the guard in front of the hosting window's delegate, so close, Command-W and the close button ask.
    public func unsavedChangesGuard(_ hooks: UnsavedHooks) -> some View
}
```

## Pseudocode

- **Ask.** Clean, or `documentName()` nil → go on. Else a warning `NSAlert`
  as a sheet: message `UnsavedPrompt.message(for:)`, informative text, the
  buttons in `UnsavedPrompt.answers` order with ids `<prefix>.close.<answer>`
  (an `NSAlert`, because SwiftUI drops button ids). Save → `await save()`;
  go on only when it returns true. Don't Save → go on. Cancel → stop.
- **Close.** A delegate proxy forwards everything to the window's delegate
  and answers `windowShouldClose` false while asking, then calls
  `performClose` once the answer allows (Design's and Photo's proven
  pattern, now in one place). One sheet at a time per window.
- **Quit.** Each app's `applicationShouldTerminate` walks its dirty windows
  through `proceed` in turn (Photo's `PhotoUnsavedFlow.quit` rule).

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| UP-1 | – | **Tests first.** `UnsavedGuardTests` written, disabled (`waits on UP-3`); `UnsavedGuard.swift` as stubs | `Sources/SuiteUI/UnsavedGuard.swift`, `Tests/SuiteUITests/UnsavedGuardTests.swift` | – | ~220, 2 |
| UP-2 | – | RJ-X48's check: `SuiteUnsavedJourneyTests.testEveryEditorAsksBeforeClosing`, each app's leg skipped (`XCTSkip("waits on UP-6")` …) | `UITests/SuiteJourneyTests+Unsaved.swift` | UP-1 | ~220, 1 |
| UP-3 | – | The guard's body: the delegate proxy, the sheet, `proceed`; turns on `UnsavedGuardTests` | `Sources/SuiteUI/UnsavedGuard.swift`, `Tests/SuiteUITests/UnsavedGuardTests.swift` | UP-1 | ~300, 2 |
| UP-4 | – | Snapshots of the sheet and the render budget test | `Tests/AppSnapshotTests/SuiteUnsavedSheetSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetUnsavedGuardTests.swift`, `Tests/mutations/SuiteUI.UnsavedGuard.json` | UP-3 | ~180, 3 |
| UP-5 | – | **Design, test first.** `DesignUnsavedGuardTests` (macOS), disabled: Design's hooks read its name and `DocumentSession`, Save runs File > Save | `Tests/AppSnapshotTests/DesignUnsavedGuardTests.swift` | UP-1 | ~150, 1 |
| UP-6 | – | Design's window uses `.unsavedChangesGuard` (ids `design.close.*`) instead of `DesignClosePrompt`; `DesignSaveStatus` shows `EditorSaveStatus`; turns on the test and Design's leg of `SJ-UP` | `Sources/DesignApp/DesignWindow.swift`, `Sources/DesignApp/DesignCommands.swift`, `Sources/DesignApp/DesignSaveStatus.swift`, `Tests/AppSnapshotTests/DesignUnsavedGuardTests.swift`, `UITests/SuiteJourneyTests+Unsaved.swift` | UP-5, UP-3 | ~200, 5 |
| UP-7 | – | **Photo, test first.** `PhotoUnsavedGuardTests` (macOS), disabled: close and Quit with two dirty windows ask in turn | `Tests/AppSnapshotTests/PhotoUnsavedGuardTests.swift` | UP-1 | ~150, 1 |
| UP-8 | – | Photo's window and Quit go through the guard (ids `photo.close.*`); the interposer and `ask()` in `PhotoWindow+File` go; turns on the test and Photo's leg | `Sources/PhotoApp/PhotoWindow+File.swift`, `Sources/PhotoApp/PhotoApp.swift`, `Tests/AppSnapshotTests/PhotoUnsavedGuardTests.swift`, `UITests/SuiteJourneyTests+Unsaved.swift` | UP-7, UP-3, UP-6 | ~250, 4 |
| UP-9 | – | **Flare, test first.** `FlareUnsavedGuardTests` (macOS), disabled | `Tests/AppSnapshotTests/FlareUnsavedGuardTests.swift` | UP-1 | ~150, 1 |
| UP-10 | – | Flare's `FlareFilePanels` asks through `proceed` and its window through the guard; the failed-save status is `EditorSaveStatus`; turns on the test and Flare's leg | `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareWindow.swift`, `Tests/AppSnapshotTests/FlareUnsavedGuardTests.swift`, `UITests/SuiteJourneyTests+Unsaved.swift` | UP-9, UP-3, UP-8 | ~200, 5 |
| UP-11 | – | **Halo, test first.** `HaloUnsavedGuardTests` (macOS), disabled: Command-W on a dirty project asks | `Tests/AppSnapshotTests/HaloUnsavedGuardTests.swift` | UP-1 | ~150, 1 |
| UP-12 | – | Halo gains the close guard; its Open/New `.alert` becomes `proceed`; its save state shows `EditorSaveStatus`; turns on the test and Halo's leg | `Sources/HaloApp/HaloWindow+File.swift`, `Sources/HaloApp/HaloWindow.swift`, `Tests/AppSnapshotTests/HaloUnsavedGuardTests.swift`, `UITests/SuiteJourneyTests+Unsaved.swift` | UP-11, UP-3, UP-10 | ~220, 5 |
| UP-13 | – | **Delete.** `DesignClosePrompt.swift` and `PhotoUnsavedPrompt.swift` (Photo's ids move into its hooks); repoints plans; `scripts/check-dup-logic --update-baseline` drops their lines | `Sources/DesignApp/DesignClosePrompt.swift`, `Sources/PhotoModel/PhotoUnsavedPrompt.swift`, `Tests/PhotoModelTests/PhotoUnsavedPromptTextTests.swift`, `Tests/canonical-baseline.txt` | UP-6, UP-8 | ~200, 4 |
| UP-14 | – | `SJ-UP` with no skipped leg; `status: built`; `feature-done` | `UITests/SuiteJourneyTests+Unsaved.swift`, `docs/blueprints/suiteui/features/adopt-kernel-unsaved-prompt.wave.json` | UP-12, UP-13, UP-4 | ~40, 2 |

UP-6, UP-8, UP-10 and UP-12 each turn on one leg of the shared journey
file, so they chain through it (one file, four one-line edits); the
alternative, four journey files, would split one job's check.

## Build waves

- Wave 1: UP-1. Independent in this wave: UP-1 alone.
- Wave 2: UP-2, UP-3, UP-5, UP-7, UP-9, UP-11. Independent in this wave: all.
- Wave 3: UP-4, UP-6. Independent in this wave: both.
- Wave 4: UP-8. Independent in this wave: UP-8 alone.
- Wave 5: UP-10, UP-13. Independent in this wave: both.
- Wave 6: UP-12. Independent in this wave: UP-12 alone.
- Wave 7: UP-14. Independent in this wave: UP-14 alone.

Longest chain: UP-1 → UP-5 → UP-6 → UP-8 → UP-10 → UP-12 → UP-14 (7). Chain of 7: the stub before Design's test, then each app's leg of the one shared journey file in turn (Design, Photo, Flare, Halo), and the journey with no skips last. The shared file is the only link between the app tasks.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| UP-1 | compiles, disabled by name | – | – (stubs) |
| UP-2 | compiles; every leg skipped by name | – | – (UI) |
| UP-3 | `UnsavedGuardTests` (an offscreen window and a fake save): Cancel keeps it; Don't Save closes; Save closes only when `save` returns true; a clean window closes without a sheet; a second Command-W while asking adds no sheet | a dirty window closes unasked, or a failed save closes it | – (UI; `scripts/mutate --plan SuiteUI.UnsavedGuard` on the Mac, Q10: Save ignores the result → `.failedSaveKeepsWindow`) |
| UP-4 | `SuiteUnsavedSheetSnapshots`; `RenderBudgetUnsavedGuardTests.askAndCancelInTwoBodies` | budget over | – (UI) |
| UP-5 | compiles, disabled | – | – (test) |
| UP-6 | `DJ-UP` unchanged; `SJ-UP` Design leg | Design's journey needs editing | – (App) |
| UP-7 | compiles, disabled | – | – (test) |
| UP-8 | `PJ-UP` unchanged; `SJ-UP` Photo leg | Quit skips a dirty window | – (App) |
| UP-9 | compiles, disabled | – | – (test) |
| UP-10 | `FJ-UP`; `SJ-UP` Flare leg | Open or New replaces a dirty animation unasked | – (App) |
| UP-11 | compiles, disabled | – | – (test) |
| UP-12 | `HJ-UP`; `SJ-UP` Halo leg | a dirty Halo project closes unasked | – (App) |
| UP-13 | both apps' tests; `scripts/check-dup-logic`; `scripts/mutate --validate` | a deleted symbol is referenced, or the baseline names a gone file | – (deletion) |
| UP-14 | `SJ-UP` green for all four on the scoped run; `scripts/waves render --dry-run` | a leg still skips | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: Command-W, the sheet, Cancel | ≤ 2 window bodies | `RenderBudgetUnsavedGuardTests.askAndCancelInTwoBodies` |
| no lost work | no dirty window closes or is replaced unasked in any editor | `SJ-UP` |
| keyboard | Return saves, Escape cancels, Command-D is Don't Save | `UnsavedGuardTests.keys` |
| VoiceOver | the sheet reads its message and three buttons by title | `SJ-UP` (accessibility tree) |
| same words | every editor's sheet text equals `UnsavedPrompt`'s | `SJ-UP` |

## Done check

Per slice: UP-u through the feel gate with its `Mac-Finish:` line; each app
slice with its existing journey unchanged and its `SJ-UP` leg green; UP-z
with `SJ-UP` green for all four editors (RJ-X48) and the baseline shrunk.
Then `Belt-Contact-Sheet:` with `suiteui-unsaved-sheet` and the four app
sheets.
