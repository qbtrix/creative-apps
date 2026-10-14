# Feature packet: history-files

**Feature:** Undo, redo, save and open. The live `ProjectHistory` (100
whole-document steps, coalescing, every record clears redo) and the live
`ProjectFiles` (the `.halo` JSON envelope, a 64 MiB limit, full content
validation) replace their W0 stubs. `HaloHistory.swift` and `HaloFiles.swift`
give the window Undo and Redo, Save, Save As…, Open… and Open Recent, and
the Edit and File menus turn on.
**Line:** `line:halo` · **Wave:** W1 (`waves.md`) · **Lead branch:** `lead/history-files`

**Covers:** #208 (Undo and Redo) and #209 (save and open a project file).
#208 closes through HF-8 and #209 through HF-10. The rest of the tasks have
no issue of their own; they close through the history-files feature issue's
`feature-done` PR. It also closes the gap #127 left: Delete Composition
becomes one undo step that brings the composition back with its layers.

**Depends on:** the foundation feature issue (#777) and SuiteUI QH-4 (#333).
The feature issue is filed only once both are closed, and its one
`Depends on:` line names whichever closed last. Only HF-11 and HF-12 (the
journey files `UITests/HaloJourneyTests+<Area>.swift`, which `project.yml`
does not compile until #333 lands) need #333, but the issue waits for it
anyway so the lead can build every task. No creative-core issue is needed:
the history and the file format are pure Swift over W0's `Codable` values.

Blueprint sections it builds on: 2 (one undo step, the stored-property
table, launch arguments `-HaloSaveTo` and `-HaloOpenFile`, fixtures), 4
(H-J8, H-J10, H-J11 and their states), 5 (`ProjectHistory`, `ProjectFiles`,
the workspace methods of `HaloHistory.swift` and `HaloFiles.swift`, the
fakes and proof tests), 6 (Alerts, the File and Edit menus, the History and
Files rows of the command table), 7.1 (HB-8, HB-10, HB-U5), 7.4 (HF-6), 8.3
(this feature's owned files). The packet wins over the blueprint and over
the issue bodies where they differ; see "Review notes folded in".

**Building blind.** HF-8 to HF-12 are in `Sources/HaloApp/`,
`Tests/AppSnapshotTests/` and `UITests/`, which the Linux gate never
compiles; the macOS job compiles them on `dev` after the lane merges. Copy
the import and shape of `Sources/DesignApp/DesignWindow.swift`, which
already saves, opens, honors `-DesignSaveTo` and `-DesignOpenFile` and shows
a file alert. Every decision that can be pure is in HaloModel (HF-1 to
HF-7): titles, availability, the recent list, validation and the error
text. Checked with the `apple-docs` MCP for this packet (2026-10-14):
`UTType(exportedAs:conformingTo:)` asserts that the app owns and declares
the type, and `UTType(filenameExtension:conformingTo:)` "may provide a
dynamic type" when nothing declares the extension; `fileExporter(isPresented:document:contentType:defaultFilename:onCompletion:)`
takes a `FileDocument`; `fileImporter(isPresented:allowedContentTypes:onCompletion:)`
returns a URL. Each app task checks again before use and says so in its PR.

**Shared-file rule.** This feature owns only the files in its task rows. It
never edits `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift`, `docs/c4/model.json`,
`docs/design.md`, or the W0 files `HaloProject.swift`, `HaloCommand.swift`,
`HaloWindow.swift`, `HaloCommands.swift`, `HaloEditMenu.swift`,
`HaloFileMenu.swift` and `HaloLaunch.swift`. It reaches the window through
the routes and slots FD-14 and FD-16 made: `perform(_:)` routes `.undo` and
`.redo` to `HaloWindow+Edit.swift` and the files area to
`HaloWindow+File.swift`; the window's title and its file modifiers
(exporter, importer, alerts, launch-file task) come from that file too.

## Journey steps

1. **H-J8** `testUndoRedoEveryEdit` (`UITests/HaloJourneyTests+History.swift`)
   on `-HaloSample empty`: Layer > New > Solid; rename the composition
   "Intro"; Composition > Delete is disabled (one left); Composition > New,
   Create; select Intro; Composition > Delete; ⌘Z; ⌘Z; ⇧⌘Z. After each edit
   the Edit menu's first item reads "Undo New Layer", "Undo Rename
   Composition", "Undo New Composition", "Undo Delete Composition". The
   first ⌘Z brings Intro back first in the sidebar, selected, with Solid 1
   (`layerSummary` "1 layer"); the second removes Comp 2; ⇧⌘Z brings it
   back and Edit reads "Undo New Composition". Scrubbing the timeline in
   between adds no step (the title doesn't change). Only composition and
   new-layer edits: nothing here depends on another W1 feature. (HF-11)
2. **H-J10** `testSaveAndReopen` (`UITests/HaloJourneyTests+Files.swift`) on
   `-HaloSample two-comps -HaloSaveTo <tmp>/Spot.halo`: ⌘S; the window
   title reads "Spot" and `halo.file` reads "Saved". Quit; relaunch with
   `-HaloOpenFile <tmp>/Spot.halo`: Intro and Outro are back with their
   layers, Ball's keys in Outro (`viewerSummary` and the layer readout
   match the fixture), and Edit > Undo is disabled with help "Nothing to
   undo.". New Composition…, Create: `halo.file` reads "Edited". File > Open
   Recent > Spot (first entry); the unsaved-changes alert; Don't Save; the
   file reopens from its saved path. Quit; launch on `-HaloSample huge
   -HaloSaveTo <tmp>/Huge.halo`, ⌘S, quit, relaunch with `-HaloOpenFile
   <tmp>/Huge.halo`: the shot right after launch has `halo.file.progress`
   ("Opening Huge…"; it appears at `beginOpen`, whatever the decode time),
   then the readout "2000 layers". (HF-12)
3. **H-J11** `testOpenBadFiles` (`UITests/HaloJourneyTests+FileErrors.swift`),
   no fixture, one launch per file with `-HaloOpenFile`: the test writes
   four files in its temp folder (`not json`; `{"format":"halo","version":2}`;
   `{"format":"halo","version":1,"project":{"compositions":[{"id":"a"}]}}`;
   64 MiB + 1 byte of spaces). Each alert reads "This file isn't a Halo
   project.", "This project was saved by a newer Halo (format 2). Update
   Halo to open it.", text starting "This project is damaged: " with a
   non-empty reason, and "This project is larger than Halo can open (64
   MB)."; after OK the "No Composition" empty state stays. (HF-12)

The Model half of every step runs on Linux first: `HaloUndoTests`,
`HaloFileTests`, `HaloFileValidationTests` and the two contract suites on
`[fake, live]`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Edit menu | nothing to undo: "Undo" disabled, help "Nothing to undo."; "Redo" disabled, "Nothing to redo." | none | while a file opens both read "A project is opening." |
| File menu | no composition: Save and Save As… disabled with "Create a composition first."; Open Recent with no entries disabled with "No recent projects." | none | while a file opens, Open…, Open Recent, Save and Save As… read "A project is opening." |
| Window title and `halo.file` | "Halo" with no composition and no file; "Untitled Project" until the first save; then the file's name ("Spot"); `halo.file` value "Untitled", "Saved", "Edited" or "Not saved" | a failed save: `halo.file` "Not saved" (`stateError` caption beside the title per `docs/design.md`) and a system `.alert` with "Spot.halo can't be saved. <reason>" | none |
| Open | – | a system `.alert` with `HaloFileError.message`; the project stays as it was | `halo.file.progress`: a system `ProgressView` and "Opening <name>…" over the window content from `beginOpen` until `finishOpen` |
| Unsaved changes | – | Open…, Open Recent or closing the window with unsaved changes: a system `.alert` "Save changes to <title>?" with Save, Don't Save, Cancel | none |

## Contract slice

The protocols, `HaloHistory`, `HaloHistoryEntry`, `HaloFileError` and the
fakes are W0's (blueprint 5.1, 5.2, 5.5). What this feature adds:

```swift
// Live/HaloHistoryRules.swift (HF-1): the one copy of the stack rules,
// called by LiveProjectHistory and FakeProjectHistory.
enum HaloHistoryRules {
    static func record(_ name: String, before: HaloDocumentState, coalesceKey: String?,
                       limit: Int, in history: inout HaloHistory)
    static func endCoalescing(in history: inout HaloHistory)
    static func step(_ current: HaloDocumentState, from: inout [HaloHistoryEntry],
                     to: inout [HaloHistoryEntry]) -> HaloDocumentState?
}
// Live/LiveProjectHistory.swift: limit 100, unavailableHelp nil.
// ponytail: whole-document snapshots (#208, D2); commands replace them once
// creative-core has a Halo document engine (blueprint 8.4).

// Live/HaloFileEnvelope.swift (HF-4): moved out of the fake.
struct HaloFileEnvelope: Codable { var format: String; var version: Int; var project: HaloDocumentState? }
enum HaloFileFormat {
    static let maxBytes = 64 * 1024 * 1024
    static func encode(_ state: HaloDocumentState) throws -> Data      // sorted keys
    static func unwrap(_ data: Data) throws -> HaloDocumentState      // size, format, version, project
    static func reason(_ error: DecodingError) -> String              // "it is missing name in compositions[0]"
}
// Live/HaloFileValidation.swift (HF-5)
enum HaloFileValidation {
    static func check(_ state: HaloDocumentState) throws               // HaloFileError.damaged(reason)
    static func raisingCounters(_ state: HaloDocumentState) -> HaloDocumentState
}

// HaloHistory.swift (HF-2)
extension HaloProject {
    public mutating func undo()
    public mutating func redo()
    public var undoTitle: String? { get }     // history.undoTitle
    public var redoTitle: String? { get }
}

// HaloFiles.swift (HF-6)
extension HaloProject {
    public func fileData() throws -> Data
    public mutating func beginOpen(name: String, path: String)
    public mutating func finishOpen(_ result: Result<HaloDocumentState, HaloFileError>)
    public mutating func didSave(name: String, path: String)
    public mutating func didFailSave(_ message: String)
    public var recent: [HaloRecentFile] { get }     // newest first, 10 at most
    public mutating func setRecent(_ files: [HaloRecentFile])
    public var windowTitle: String { get }          // "Halo", "Untitled Project", "Spot"
    public var saveStatus: String { get }           // "Untitled", "Saved", "Edited", "Not saved"
}
```

`HaloFileState` and `HaloRecentFile` are W0's (FD-8); this feature only
fills them. The packet reads `file.opening` as the pending `HaloRecentFile?`
and `file.error` as the last save or open message (`String?`); if FD-8 gave
them another shape, HF-6 adapts to it without editing `HaloProject.swift`.

## Pseudocode

```
record(name, before, key, limit, &h):              # HF-1
  h.redo = []                                      # always, even when coalescing
  if key != nil && h.undo.last?.coalesceKey == key { return }
  h.undo.append(Entry(name, before, key)); if h.undo.count > limit { h.undo.removeFirst() }
step(current, &from, &to):  guard let s = from.popLast() else nil
                            to.append(Entry(s.name, current)); return s.before

undo():                                            # HF-2; redo() mirrors it
  guard let back = services.history.undo(document, in: &history) else return
  document = back; refusal = nil; file.unsaved = true
  # selection rides in the document; the playhead lives in each composition.
  # Selection, scrubbing and playback never call edit, so they are never steps.

decode(data):                                      # HF-4, HF-5 (live)
  state = HaloFileFormat.unwrap(data)              # tooLarge before parsing; notAHaloFile;
                                                   # newerVersion(v); damaged("it has no project")
  HaloFileValidation.check(state)                  # damaged(reason), first failure only:
    composition ids unique; names unique by NameKey; size in CompositionSettings.sizeRange;
    rate in CompositionSettings.frameRates; duration 1 ... maxDurationSeconds × rate;
    layer ids unique; in and out obey the rule inPointAfterOut enforces; every track's
    frames strictly increasing; every key value, color and rect finite; parentID names
    a layer of the same composition; no parent cycle; selection ids exist or are nil
  return raisingCounters(state)                    # next numbers past the highest id (#209)

fileData():  try services.files.encode(document)   # HF-6
beginOpen(name, path):  file.opening = HaloRecentFile(name, path); file.error = nil
finishOpen(.success(s)): document = s; history = HaloHistory()      # opening clears history
                         file = name/path of opening, unsaved false, opening nil, error nil
                         pushRecent(opening)
finishOpen(.failure(e)): file.opening = nil; file.error = e.message  # document unchanged
didSave(name, path):     file.name/path; unsaved false; error nil; pushRecent
didFailSave(m):          file.error = m                              # unsaved stays true
pushRecent(f):           recent = [f] + recent.filter { $0.path != f.path }, first 10
windowTitle:             file.name ?? (compositions.isEmpty ? "Halo" : "Untitled Project")
saveStatus:              unsaved && error != nil ? "Not saved" : unsaved ? "Edited"
                         : file.path == nil ? "Untitled" : "Saved"

HaloWindow+File (app):                             # HF-9, HF-10
  save:   url = -HaloSaveTo ?? file.path ?? (fileExporter, HaloProjectDocument(data))
          write fileData() atomically; didSave(name w/o ".halo", path) | didFailSave(reason)
  open:   unsaved ? alert(Save, Don't Save, Cancel) : go
          go: beginOpen; Task.detached { try services.files.decode(Data(contentsOf:)) }
              then on the main actor finishOpen(result); an unreadable file → .damaged(reason)
  launch: -HaloOpenFile → open; setRecent(UserDefaults "HaloRecentFiles"); write it back
          on every change of model.recent
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: history-files`,
`Fast-Check: pass`, `Head:`. HF-12 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| HF-1 | #208 (part) | Live history: `HaloHistoryRules` (record, coalescing, step), `LiveProjectHistory` (limit 100, `ponytail:`), `FakeProjectHistory` becomes a thin wrapper; the suite runs on `[fake, live]` | `Sources/HaloModel/Live/HaloHistoryRules.swift`, `Sources/HaloModel/Live/LiveProjectHistory.swift`, `Sources/HaloModel/Fakes/FakeProjectHistory.swift`, `Tests/HaloModelTests/ProjectHistoryContractTests.swift` | – | ~200 |
| HF-2 | #208 (part) | `undo()`, `redo()`, `undoTitle`, `redoTitle`; undo and redo set `file.unsaved`; HB-8 | `Sources/HaloModel/HaloHistory.swift`, `Tests/HaloModelTests/HaloUndoTests.swift`, `Tests/HaloModelTests/HaloHistoryBudgetTests.swift` | HF-1 | ~300 |
| HF-3 | – | `+History` turns Undo and Redo on: the service's help, "A project is opening.", "Nothing to undo." / "Nothing to redo." | `Sources/HaloModel/Availability/HaloAvailability+History.swift`, `Tests/HaloModelTests/HaloHistoryCommandTests.swift` | HF-2 | ~110 |
| HF-4 | #209 (part) | The envelope: `HaloFileEnvelope` and `HaloFileFormat` move to `Live/`; `LiveProjectFiles` encodes and unwraps through them; `FakeProjectFiles` becomes a thin wrapper that skips content checks; the suite runs on `[fake, live]`; HF-6 | `Sources/HaloModel/Live/HaloFileEnvelope.swift`, `Sources/HaloModel/Live/LiveProjectFiles.swift`, `Sources/HaloModel/Fakes/FakeProjectFiles.swift`, `Tests/HaloModelTests/ProjectFilesContractTests.swift` | – | ~260 |
| HF-5 | #209 (part) | Content validation and counter raising in `LiveProjectFiles.decode` | `Sources/HaloModel/Live/HaloFileValidation.swift`, `Sources/HaloModel/Live/LiveProjectFiles.swift`, `Tests/HaloModelTests/HaloFileValidationTests.swift` | HF-4 | ~320 |
| HF-6 | #209 (part) | `HaloFiles.swift`: `fileData`, `beginOpen`, `finishOpen` (clears history), `didSave`, `didFailSave`, `recent`, `setRecent`, `windowTitle`, `saveStatus` | `Sources/HaloModel/HaloFiles.swift`, `Tests/HaloModelTests/HaloFileTests.swift` | HF-2, HF-5 | ~340 |
| HF-7 | – | `+Files` turns Open…, Open Recent, Save and Save As… on; HB-10 on `crowd`; `huge` opens on live | `Sources/HaloModel/Availability/HaloAvailability+Files.swift`, `Tests/HaloModelTests/HaloFilesCommandTests.swift`, `Tests/HaloModelTests/HaloFilesBudgetTests.swift` | HF-6 | ~230 |
| HF-8 | #208 (closes) | App: `HaloWindow+Edit.swift` routes `.undo` and `.redo` to `undo()` and `redo()`; the Edit menu snapshot | `Sources/HaloApp/HaloWindow+Edit.swift`, `Tests/AppSnapshotTests/HaloEditMenuSnapshots.swift` | HF-3 | ~120 |
| HF-9 | – | App: `HaloDocumentType.swift` (the `.halo` type and `HaloProjectDocument: FileDocument` for the exporter); Save and Save As… (`-HaloSaveTo` skips the panel); the window title from `windowTitle`; `halo.file` carries `saveStatus`; the failed-save alert | `Sources/HaloApp/HaloDocumentType.swift`, `Sources/HaloApp/HaloWindow+File.swift` | HF-7 | ~240 |
| HF-10 | #209 (closes) | App: Open… (`fileImporter`), Open Recent, `-HaloOpenFile`, the detached decode between `beginOpen` and `finishOpen`, the progress row, the open-error alert, the unsaved-changes alert, the recent list in `UserDefaults`; snapshots | `Sources/HaloApp/HaloWindow+File.swift`, `Tests/AppSnapshotTests/HaloFileSnapshots.swift` | HF-9 | ~300 |
| HF-11 | – | Journey H-J8 on `-HaloSample empty` | `UITests/HaloJourneyTests+History.swift` | HF-8, #333 | ~150 |
| HF-12 | – (`feature-done`) | Journeys H-J10 and H-J11 on live services | `UITests/HaloJourneyTests+Files.swift`, `UITests/HaloJourneyTests+FileErrors.swift` | HF-10, HF-11, #333 | ~280 |

The Model chains are HF-1 → HF-2 → HF-3 and HF-4 → HF-5, joining at HF-6 →
HF-7; HF-1 and HF-4 start together. The app chain is HF-8 (after HF-3) and
HF-9 → HF-10 (after HF-7). Both live types land in HF-1 and HF-4, before
any journey, so every journey is written on `-HaloSample` from its first PR.
`edit`, `endCoalescing` and the step names are W0's (FD-10); this feature
never adds a mutator.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| HF-1 | `ProjectHistoryContractTests` on `[fake, live]`: the proof test `fakeHistoryCoalescesEndsAndClearsRedo`; three records with key "rot" are one entry keeping the first `before`; `endCoalescing` makes the fourth a new entry; a coalesced record after an undo still empties redo; the 101st record drops the oldest (`undo.first.name` is the 2nd step's); `undo` then `redo` returns the current state exactly; both return nil on empty stacks; `LiveProjectHistory().unavailableHelp == nil` | coalescing keeps redo, the cap is not 100, or fake and live disagree |
| HF-2 | `HaloUndoTests` on `.live`: on `empty`, New Layer then `undo()` removes Solid 1 and restores `selectedLayerID` to nil; on `two-comps` with Outro selected, Delete Composition then `undo()` restores `compositions` (Outro back at index 1 with Ball and its keys), `selectedCompositionID` and `selectedLayerID` exactly (#127); `redo()` deletes it again; `undoTitle` "Undo Delete Composition" and `redoTitle` nil after redo; selecting a layer and `scrub(to: 30)` leave `history.undo.count` unchanged; 101 New Layers keep 100 steps; `undo()` after `didSave` sets `file.unsaved` | a step restores less than the whole document, selection or scrub records a step, or undo leaves the file "Saved" |
| HF-3 | `HaloHistoryCommandTests`: on `.live` `empty`, `.undo` reads "Nothing to undo." and `.redo` "Nothing to redo."; after New Layer `.undo` is enabled and `title(for: .undo)` is "Undo New Layer"; after `beginOpen` both read "A project is opening."; with a services whose history is the W0 stub, its help shows | Undo is enabled with nothing to undo, or disabled with no help |
| HF-4 | `ProjectFilesContractTests` on `[fake, live]`: `fakeFilesRoundTripAndRefuse`; the file starts `{"format":"halo","project":` (sorted keys) and has `"version":1`; 64 MiB + 1 byte throws `.tooLarge`, exactly 64 MiB of a valid file pads open; HF-6: for every fixture but `huge`, `encode(decode(encode(f)))` equals `encode(f)` byte for byte and the decoded document equals `f` | the envelope differs between fake and live, or a fixture changes on a round trip |
| HF-5 | `HaloFileValidationTests` (live), one mutated `two-comps` per rule: two compositions with id "comp-1"; Intro and "intro"; width 0 and 8193; 23 fps; a layer with in 50 and out 10; a track with frames [0, 24, 24]; a key value of `.infinity`; Ball's parent is Floor and Floor's is Ball; a parent id from the other composition; `selectedLayerID` "nope". Each throws `.damaged` whose reason names the item ("two compositions share the id comp-1", …). A file whose `nextCompositionNumber` is 2 with ids comp-1 and comp-5 decodes with 6. The H-J11 file `{"compositions":[{"id":"a"}]}` throws `.damaged` with a non-empty reason that names a key | a damaged file opens, a valid one is refused, or a new composition after open reuses an id |
| HF-6 | `HaloFileTests` on `.live`: `two-comps` `fileData()`, `beginOpen(name: "Spot", path: "/t/Spot.halo")`, `finishOpen(.success(decoded))`: the document equals the fixture, `history` is empty, `windowTitle` "Spot", `saveStatus` "Saved", `recent.first` is Spot at that path; `finishOpen(.failure(.newerVersion(2)))` leaves document and history equal and `file.error` the message; New Layer after `didSave` reads "Edited"; `didFailSave("…")` reads "Not saved" and keeps the title; 11 saves to distinct paths keep 10, newest first; saving the 3rd path again moves it first with no duplicate; `windowTitle` is "Halo" on `HaloProject()` and "Untitled Project" on `empty` | opening keeps old history, a failed open changes the project, the recent list grows past 10 or repeats a path |
| HF-7 | `HaloFilesCommandTests`: on `.live` `HaloProject()` Save and Save As… read "Create a composition first." and Open Recent "No recent projects."; on `empty` Save and Open… are enabled; after `beginOpen` all four read "A project is opening.". `HaloFilesBudgetTests.hugeOpensOnLive`: `huge` encodes to at most 48 MiB and decodes on `LiveProjectFiles` to 2,000 layers without `.tooLarge` | a file command is dead or acts during an open, or `huge` can't open |
| HF-8 | Snapshot `HaloEditMenuSnapshots` (macOS): the Undo and Redo items drawn as buttons after New Layer: "Undo New Layer" enabled, "Redo" disabled (`halo-edit-menu-light.png`, `halo-edit-menu-dark.png`); H-J8 (HF-11) presses ⌘Z through the real menu | ⌘Z doesn't reach `undo()` or the title is wrong |
| HF-9 | H-J10's first steps (HF-12): ⌘S with `-HaloSaveTo` writes the file without a panel, title "Spot", `halo.file` "Saved". A save into a folder the test makes read-only shows the alert and "Not saved" (H-J10 extra step) | Save shows a panel under `-HaloSaveTo`, or a failed save reads "Saved" |
| HF-10 | Snapshots `HaloFileSnapshots`: `HaloViewer` after `finishOpen` of `two-comps` (`halo-opened-project-light.png`, `-dark.png`, as #209 names them) and the progress row after `beginOpen` (`halo-file-opening-light.png`, `-dark.png`); H-J10 and H-J11 (HF-12) | an open runs on the main actor with no progress row, or an error alert is missing |
| HF-11 | H-J8 on the `dev` CI run | any step's assert |
| HF-12 | H-J10 and H-J11 on the `dev` CI run | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-8 Undo, Redo | one `undo()` or `redo()` on `crowd` ≤ 2 ms device, ≤ 20 ms debug CI | `HaloHistoryBudgetTests.undoStep` (HF-2) |
| HB-10 Save, Open | `fileData()`; `services.files.decode` plus `finishOpen(_:)` on `crowd`, live, ≤ 50 ms each device, ≤ 500 ms debug CI | `HaloFilesBudgetTests.saveCrowd`, `.openCrowd` (HF-7) |
| HB-U5 Open to progress shown | ≤ 100 ms (QB-L9) | the probe's progress mark in H-J10, report-only until #330; meanwhile the row exists in the first shot after launch (HF-12) |
| HF-6 Round trip | byte for byte, and equal | `ProjectFilesContractTests.roundTripEveryFixture` (HF-4) |
| QB-F1 No dead controls | Undo, Redo and the four file commands act or say why | `HaloHistoryCommandTests`, `HaloFilesCommandTests` (HF-3, HF-7); H-J13 keeps passing |
| QB-F3 One gesture, one named step | Undo names the last step | `HaloUndoTests`, H-J8 |
| Audit | no `halo` count over `UITests/audit-baseline.json` | `audit-halo-*.json` on the `feature-done` run; the alerts and progress row are system components with names |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by HF-12's
  `feature-done` PR is green, with H-J8, H-J10 and H-J11 passing, H-J0,
  H-J1, H-J13 and `testEveryMenuOpens` unchanged, and every other app's
  journeys unchanged.
- **Audit zero new:** no `halo` count over the baseline; the PR bodies of
  HF-9 and HF-10 state the counts they expect (0 new).
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per journey and the audit
  counts. Expected new shots: the Edit menu with each step name, the window
  titled "Spot", the progress row on `huge`, the four error alerts and the
  unsaved-changes alert.

## Review notes folded in

From the review of the blueprint PR (#767), and differences from the issue
bodies:

- **`huge` can't hit `tooLarge`.** W0 keeps `huge` at most 48 MiB with
  whole-number values (FD-9 asserts it), so H-J10's large-file step tests
  the progress row and a large open, never the limit. H-J11's 64 MiB + 1
  byte file is the only `tooLarge` check; HF-7 asserts `huge` opens on live
  and HB-10 stays on `crowd`.
- **Progress row timing.** H-J10's row appears at `beginOpen`, before the
  detached decode starts, so the first shot has it however fast the decode.
- **H-J8 scope.** layer-panel's H-J9 no longer presses ⌘Z (undo isn't built
  until this feature); its "Delete Layer then ⌘Z brings it back" assert
  moves to core-loop (W3). H-J8 stays on `empty` and uses only composition
  and New Layer edits, so it waits on no sibling feature.
- **One copy of each rule.** Coalescing moves to `Live/HaloHistoryRules.swift`
  and the envelope to `Live/HaloFileEnvelope.swift`; both fakes call them
  (the duplicate-code gate). `FakeProjectFiles` still skips content
  validation on purpose, as blueprint 5.5 says.
- **Names differ from the issues.** #208 names `HaloEditCommands.swift` and
  `undoActionName`; the menu is W0's `HaloEditMenu.swift`, titled by
  `title(for:)`, and routing is `HaloWindow+Edit.swift`. #209 names
  `HaloFile.swift`, `HaloFileCommands.swift` and `open(_ data:)`; the packet
  uses `HaloFiles.swift`, `HaloWindow+File.swift` and `beginOpen` /
  `finishOpen` with the decode off the main actor. #209's "sizes and fps
  above 0" becomes 1–8192 and the four shipped rates. The test names #208
  and #209 give (`HaloUndoTests`, `HaloFileTests`, `HaloEditMenuSnapshots`,
  `HaloFileSnapshots`) and their PNG names are kept.
- **`restore` is not in W0's slice.** Blueprint section 2 says `document` is
  written by `HaloProject.swift` "through `edit` and `restore`"; FD-10 has
  no `restore`. `HaloHistory.swift` (undo, redo) and `HaloFiles.swift`
  (`finishOpen`) write `document` directly through `internal(set)`, each in
  one place, and nothing else does.
- **Who sets `unsaved`.** The blueprint lists `HaloFiles.swift` as the only
  writer of `file`, but every edit must mark the project unsaved and edits
  run through W0's `edit`. This packet needs FD-10's `edit` to set
  `file.unsaved = true` when it records a step (one line in
  `HaloProject.swift`). HF-6's "New Layer after `didSave` reads Edited"
  test fails if it doesn't; the lead then comments on the foundation issue
  and stops HF-6 rather than editing a W0 file.
- **The `.halo` type.** #209 asks for a type conforming to JSON. An exported
  type only maps the extension when the bundle's Info.plist declares it,
  and that plist is written by `scripts/bundle-apps` and `project.yml`
  (protected and shared). So `HaloDocumentType.swift` uses
  `UTType(filenameExtension: "halo", conformingTo: .json)` (a dynamic type
  when undeclared) for both panels, the way `DesignWindow` handles
  `.design`, and HF-9 files an issue asking for the declaration. Journeys
  use `-HaloSaveTo` and `-HaloOpenFile` and never depend on it.
- **Closing with unsaved changes.** SwiftUI owns the window's delegate, so
  HF-10 checks with `apple-docs` for a supported close hook. If there is
  none, the alert guards Open… and Open Recent only, and HF-10 files a
  `needs-ui` issue (`line:suiteui`) for a close guard on `SuiteWindow`.
