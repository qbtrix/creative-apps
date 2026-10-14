# Feature packet: mac-platform

**Feature:** never lose work, and draw at full quality on the Mac: autosave
with a recovery file and a restore offer, Open Recent, and the one
conversion from FlareCore paths and colors to CoreGraphics. (The display-link
playback clock, LA-2 #372, shipped in #751 while this packet was written.)
**Line:** `line:flare` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/mac-platform`

**Covers:** #739 (LM-1b), #373 (LA-3), #370 (LA-0). Each closes
through the task PR that names it in the table below.

**Depends on:** nothing open. #356 (LM-1) and #314 (LM-0a1) have
merged; no creative-core issue is needed.

This is the platform feature of the wave: it owns `docs/c4/model.json` in
wave 1, so no other wave-1 feature edits it. Blueprint sections it builds on:
2 (FlareApp platform files), 3.3 (recovery offer), 7.5 (LM-1, LA-0, LA-3).

**Building blind.** MP-4 to MP-6 are in `Sources/FlareApp/` and
`Tests/AppSnapshotTests/`, which the Linux gate never compiles. The macOS job
compiles them on `dev` after the lane merges. So: no SwiftUI in these files,
every API checked with the `apple-docs` MCP before use (say so in the PR),
each file copies the import and style of a FlareApp file that already builds,
and every decision that can be pure is Model code (MP-1 to MP-3) tested on
Linux.

**C4 rule.** Every task adds something the C4 descriptions don't mention
yet, so each PR edits its own sentence in `docs/c4/model.json`
(`flare-model-sources` for MP-1 to MP-3, `flare-app-sources` for MP-4 to
MP-6). That makes `docs/c4/model.json` part of every task, so the six
tasks form one chain, MP-1 → MP-6, each rebased on the one before.

## Journey steps

The journeys these parts serve are J26 (Open Recent), J28 (save failure and
recovery) and every stage golden (curves). Their UI tasks (F17a #205, F17c
#393, F3a #12) are not built yet, so this
feature proves the steps in Model tests and in macOS unit tests:

1. Open a file, then save as another: the app calls `noteRecent` with each
   path and the list is most recent first. (MP-1)
2. Edit, wait 30 s: autosave is due and the recovery bytes decode to the
   edited document. (MP-2)
3. Restore a recovered document: it lands as unsaved work, with no file name
   and the dirty dot on, and stays out of Open Recent. (MP-3)
4. The autosave writer writes the recovery bytes off the main thread; a clean
   save removes the file. (MP-5)
5. On the next launch a recovery file is found and offered with its time;
   Restore lands it through MP-3, Discard deletes it. (MP-6)
6. Hand-built paths with cubics and lines (an ellipse as four cubics, a pen
   path) reach CoreGraphics as one `addCurve` per FlareCore cubic. (MP-4)

`Tests/FlareModelTests/MacPlatformJourneyTests.swift` (MP-3) walks steps 1–3
through `FlareWorkspace`; MP-5 and MP-6 walk 4–5 in their own tests.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| File > Open Recent | `recent` is empty: the menu shows its system "No recent files" state (F17a builds the menu) | a recent path that no longer opens fails like any open (`loadState = .failed`, section 3.3 text); the app does not call `noteRecent`, so the list stays as it was | none (open shows its own progress) |
| Recovery offer (section 3.3) | no recovery file: no offer, launch as usual | an unreadable or damaged recovery file: no offer, the file is deleted, nothing else changes | the recovery file is read and decoded off the main thread before the offer shows |
| Stage drawing | an empty path: an empty `CGPath` | a non-finite coordinate is skipped (never a crash), counted in the test | none |

## Contract slice

Model (`Sources/FlareModel/FlareFiles.swift`, extension on `FlareWorkspace`;
`FlareWorkspace.swift` itself is not edited, its `recent` and
`savedDocument` properties exist):

```swift
public static let recentLimit = 10
/// The app calls this after a successful open or save, with the file's path (not its display name),
/// so two files with one name in different folders stay two entries and the menu can reopen each.
public mutating func noteRecent(_ path: String)
public mutating func clearRecent()
public static let autosaveDelay: Double = 30             // seconds after the last edit
/// The app keeps the time of the last edit; due only while the document is dirty.
public func autosaveDue(lastEdit: Double?, now: Double) -> Bool
/// The encoded document while dirty, nil when clean or when there is no document.
public func recoveryData() -> Data?
/// Lands a recovered document as unsaved work: `load`, then no saved document and no file name,
/// so `isDirty` is true and `title` reads "Untitled"; `recent` is untouched.
public mutating func restoreRecovery(_ document: Document)
```

App (macOS, no SwiftUI):

```swift
// Sources/FlareApp/StagePath.swift
enum StagePath {
    static func cgPath(_ path: FlarePath, transform: Matrix) -> CGPath
    static func cgColor(_ color: FlareColor) -> CGColor   // CGColor(srgbRed:green:blue:alpha:)
}
// Sources/FlareApp/FlareAutosave.swift
struct RecoveryFile { let url: URL; func write(_ data: Data) async throws; func read() async -> (Data, Date)?; func remove() }
```

## Pseudocode

```
noteRecent(path):                      # MP-1
  recent = [path] + recent.filter { $0 != path }
  recent = Array(recent.prefix(recentLimit))

autosaveDue(lastEdit, now):            # MP-2
  guard isDirty, let lastEdit, now.isFinite, lastEdit.isFinite else false
  return now - lastEdit >= autosaveDelay

recoveryData():
  guard isDirty, let document else nil
  return try? FlareFormat.encode(document)

restoreRecovery(doc):                  # MP-3
  load(doc); savedDocument = nil; fileName = nil      # dirty, untitled, recent unchanged

FlareAutosave (MP-5): every second on the main actor
  if model.autosaveDue(lastEdit, now), let data = model.recoveryData():
    Task.detached { try await recovery.write(data) }   # atomic write, off main
  after didSave: recovery.remove()
  on quit: write once more if recoveryData() != nil

launch (MP-6):
  if let (data, date) = await recovery.read():
    switch FlareWorkspace.decodeFile(data):
      .success(doc): offer "Restore the unsaved animation from <date>?"  Restore -> restoreRecovery(doc); Discard -> remove
      .failure: remove()                                # no offer for a damaged file
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: mac-platform`, `Fast-Check:
pass`, `Head:`. MP-6 also carries `feature-done`. Every task also owns
`docs/c4/model.json` (its own description sentence), which is why they chain.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| MP-1 | #739 (part) | Open Recent list: `noteRecent(path)`, the limit, `clearRecent` | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareRecentTests.swift`, `docs/c4/model.json` | – |
| MP-2 | #739 (closes) | Autosave due time and `recoveryData()` | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareAutosaveDueTests.swift`, `docs/c4/model.json` | MP-1 |
| MP-3 | #373 (part) | `restoreRecovery`; the model journey test (steps 1–3) | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareRecoveryRestoreTests.swift`, `Tests/FlareModelTests/MacPlatformJourneyTests.swift`, `docs/c4/model.json` | MP-2 |
| MP-4 | #370 (closes) | `StagePath`: path and matrix to `CGPath`, colors to `CGColor(srgbRed:…)` | `Sources/FlareApp/StagePath.swift`, `Tests/AppSnapshotTests/StagePathTests.swift`, `docs/c4/model.json` | MP-3 |
| MP-5 | #373 (part) | `RecoveryFile` and the autosave writer: due-time polling, off-main atomic write, remove after a clean save, write on quit | `Sources/FlareApp/FlareAutosave.swift`, `Tests/AppSnapshotTests/AutosaveTests.swift`, `docs/c4/model.json` | MP-4 |
| MP-6 | #373 (closes) | Recovery on launch: read off main, decode, the offer's text and date, Restore through `restoreRecovery`, Discard, a damaged file removed | `Sources/FlareApp/FlareAutosave.swift`, `Tests/AppSnapshotTests/AutosaveRecoveryTests.swift`, `docs/c4/model.json` | MP-5 |

MP-1 to MP-3 share `FlareFiles.swift` and MP-5 and MP-6 share
`FlareAutosave.swift`; the chain covers both. The window does not call
`FlareAutosave` yet: that wiring belongs to F17c (#393). #739 owns one test file in its first draft;
the packet splits the tests per task and the issue body says so.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| MP-1 | `FlareRecentTests`: `noteRecent` A, B, then A gives `[A, B]`; 11 distinct paths keep 10 with the oldest gone; `/x/a.flare` and `/y/a.flare` stay two entries; `clearRecent` empties it; a new document leaves `recent` as it was | the list is not most-recent-first, grows past 10, merges two folders' files, or a new document clears it |
| MP-2 | `FlareAutosaveDueTests`: an edit at 0 is not due at 29.9 and due at 30.0; clean is never due; after `didSave` not due; undo back to the saved document not due; NaN times not due; `recoveryData()` decodes to `document`, nil when clean | due early, due while clean, or the bytes don't round-trip |
| MP-3 | `FlareRecoveryRestoreTests`: `restoreRecovery(bounce)` gives `document == bounce`, `isDirty == true`, `fileName == nil`, `title == "Untitled"`, and `recent` unchanged; `canUndo` is false. `MacPlatformJourneyTests` runs steps 1–3 on `bounce` | the restore comes back clean or named, or touches Open Recent |
| MP-4 | `StagePathTests`: for an ellipse built by hand as 4 cubics and a pen path with 2 cubics and 1 line, `CGPath.applyWithBlock` counts exactly 4 and 2 `addCurveToPoint` and 1 `addLineToPoint`; a translate-by-(10, 20) matrix moves `boundingBoxOfPath` by (10, 20); `cgColor` of (1, 0.5, 0, 0.25) has those sRGB components; a NaN point is skipped | a cubic is flattened, an element is lost, the matrix is ignored or a color is converted in the wrong space |
| MP-5 | `AutosaveTests` (temp folder): a due model writes the recovery file once; a clean model writes nothing; the write is atomic (no partial file after a thrown write); `remove()` after a clean save leaves no file; a quit-time write happens when dirty | no write when due, a write when clean, or the file outlives a clean save |
| MP-6 | `AutosaveRecoveryTests`: a recovery file of `bounce` gives the offer text "Restore the unsaved animation from <time>?" with the file's date; Restore lands `bounce` dirty and untitled (through `restoreRecovery`); Discard deletes the file; a damaged file is deleted with no offer | an offer for a damaged file, a lost or clean restore, or a file left behind after Discard |

## Quality tests

| quality row | budget | test |
|---|---|---|
| no data loss (section 7.5, LA-3) | a kill after the due time loses no edit | `AutosaveTests.dueModelWritesRecovery`, `AutosaveRecoveryTests.restoreLandsTheDocument` |
| QB-V1 | each FlareCore `cubic` is one `addCurve` | `StagePathTests.cubicsStayCurves` |
| QB-L12 hook | recovery read and decode never run on the main thread | `AutosaveRecoveryTests.readsOffMain` (asserts `!Thread.isMainThread` inside the read) |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR is green, `FlareJourneyTests` included (they must not regress, since
  nothing here is wired into the window yet).
- **Audit zero new:** that run's app audit adds no Flare count over
  `UITests/audit-baseline.json`; this feature never raises a baseline.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>` for that run, and notes that this feature
  changes no screen (the sheet must match the previous one for Flare).
