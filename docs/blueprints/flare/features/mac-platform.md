# Feature packet: mac-platform

**Feature:** never lose work, and play and draw at full quality on the Mac:
autosave with a recovery file, Open Recent, a display-link playback clock, and
the one conversion from FlareCore paths and colors to CoreGraphics.
**Line:** `line:flare` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/mac-platform`

**Covers:** #739 (LM-1b), #373 (LA-3), #372 (LA-2), #370 (LA-0). Each closes
through the task PR that names it in the table below.

**Depends on:** nothing open. #356 (LM-1), #360 (LM-7) and #314 (LM-0a1) have
merged; no creative-core issue is needed.

This is the platform feature of the wave: it owns `docs/c4/model.json` in
wave 1, so no other wave-1 feature edits it. Blueprint sections it builds on:
2 (FlareApp platform files), 3.3 (recovery offer), 7.5 (LM-1, LA-0, LA-2,
LA-3).

**Building blind.** MP-3 to MP-6 are in `Sources/FlareApp/` and
`Tests/AppSnapshotTests/`, which the Linux gate never compiles. The macOS job
compiles them on `dev` after the lane merges. So: no SwiftUI in these files,
every API checked with the `apple-docs` MCP before use (say so in the PR),
each file copies the import and style of a FlareApp file that already builds,
and all decisions that can be pure are pure Model code (MP-1, MP-2) tested on
Linux.

## Journey steps

The journeys these parts serve are J26 (Open Recent), J28 (save failure and
recovery), J10 and P4 (playback) and every stage golden (curves). Their UI
tasks (F17a #205, F17c #393, F7b #376, F3a #12) are not built yet, so this
feature proves the steps in Model tests and in macOS unit tests:

1. Open a file, then save it: it is first in Open Recent. (MP-1)
2. Edit, wait 30 s: autosave is due and the recovery bytes decode to the
   edited document. (MP-2)
3. The autosave writer writes those bytes to the recovery file off the main
   thread; a clean save removes the file. (MP-5)
4. On the next launch a recovery file is found and offered with its time;
   Restore loads it, Discard deletes it. (MP-6)
5. Press play: the display link calls `advance(elapsed:)` with the link's
   target-timestamp step; pause stops the link. (MP-4)
6. A rectangle with a corner radius, an ellipse and a pen curve reach
   CoreGraphics as one `addCurve` per FlareCore cubic. (MP-3)

`Tests/FlareModelTests/MacPlatformJourneyTests.swift` (MP-2) walks steps 1–2
through `FlareWorkspace`; MP-5 and MP-6 walk 3–4 in their own tests.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| File > Open Recent | `recent` is empty: the menu shows its system "No recent files" state (F17a builds the menu) | a recent entry that no longer opens fails like any open (`loadState = .failed`, section 3.3 text) and leaves the list as it was | none (open shows its own progress) |
| Recovery offer (section 3.3) | no recovery file: no offer, launch as usual | an unreadable recovery file: no offer, the file is deleted, nothing else changes | the recovery file is read and decoded off the main thread before the offer shows |
| Playback (transport) | no document or a 0-frame timeline: `canPlay` is false and the link never starts | none | none |
| Stage drawing | an empty draw list: an empty `CGPath` | a non-finite coordinate is skipped (never a crash), counted in the test | none |

## Contract slice

Model (`Sources/FlareModel/FlareFiles.swift`, extension on `FlareWorkspace`;
`FlareWorkspace.swift` itself is not edited, its `recent` property exists):

```swift
public static let recentLimit = 10                      // most recent first
public mutating func clearRecent()
// finishOpen(.success, named:) and didSave(_:named:) put `name` first in `recent`.
public static let autosaveDelay: Double = 30             // seconds after the last edit
/// The app keeps the time of the last edit; due only while the document is dirty.
public func autosaveDue(lastEdit: Double?, now: Double) -> Bool
/// The encoded document while dirty, nil when clean or empty.
public func recoveryData() -> Data?
```

App (macOS, no SwiftUI):

```swift
// Sources/FlareApp/StagePath.swift
enum StagePath {
    static func cgPath(_ path: FlarePath, transform: Matrix) -> CGPath
    static func cgColor(_ color: FlareColor) -> CGColor   // CGColor(srgbRed:green:blue:alpha:)
}
// Sources/FlareApp/PlaybackDriver.swift
struct PlaybackTicker { mutating func tick(targetTimestamp: Double) -> Double?; mutating func reset() }
@MainActor final class PlaybackDriver: NSObject {
    init(onAdvance: @escaping @MainActor (Double) -> Void)
    func start(on screen: NSScreen)   // NSScreen.displayLink(target:selector:)
    func stop()
}
// Sources/FlareApp/FlareAutosave.swift
struct RecoveryFile { let url: URL; func write(_ data: Data) async throws; func read() async -> (Data, Date)?; func remove() }
```

## Pseudocode

```
noteRecent(name):                      # MP-1, called on a good open and a good save
  recent = [name] + recent.filter { $0 != name }
  recent = Array(recent.prefix(recentLimit))

autosaveDue(lastEdit, now):            # MP-2
  guard isDirty, let lastEdit, now.isFinite, lastEdit.isFinite else false
  return now - lastEdit >= autosaveDelay

recoveryData():
  guard isDirty, let document else nil
  return try? FlareFormat.encode(document)

PlaybackTicker.tick(t):                # MP-4: link time only, never Date()
  defer { last = t }
  guard let last, t > last else nil    # first tick after start or reset
  return t - last

driver.linkFired(link):
  if let dt = ticker.tick(link.targetTimestamp) { onAdvance(dt) }
window: onAdvance = { model.advance(elapsed: $0); if !model.isPlaying { driver.stop() } }

FlareAutosave (MP-5): every second on the main actor
  if model.autosaveDue(lastEdit, now), let data = model.recoveryData():
    Task.detached { try await recovery.write(data) }   # atomic write, off main
  after didSave: recovery.remove()
  on quit: write once more if recoveryData() != nil

launch (MP-6):
  if let (data, date) = await recovery.read():
    switch FlareWorkspace.decodeFile(data):
      .success(doc): offer "Restore the unsaved animation from <date>?"  Restore -> finishOpen; Discard -> remove
      .failure: remove()                                # no offer for a damaged file
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: mac-platform`, `Fast-Check:
pass`, `Head:`. The last PR merged also carries `feature-done`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| MP-1 | #739 (part) | Open Recent list: `noteRecent` on a good open and a good save, the limit, `clearRecent` | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareRecentTests.swift` | – |
| MP-2 | #739 (closes) | Autosave due time and `recoveryData()`; the model journey test | `Sources/FlareModel/FlareFiles.swift`, `Tests/FlareModelTests/FlareAutosaveDueTests.swift`, `Tests/FlareModelTests/MacPlatformJourneyTests.swift` | MP-1 |
| MP-3 | #370 (closes) | `StagePath`: path and matrix to `CGPath`, colors to `CGColor(srgbRed:…)` | `Sources/FlareApp/StagePath.swift`, `Tests/AppSnapshotTests/StagePathTests.swift` | – |
| MP-4 | #372 (closes) | `PlaybackTicker` and `PlaybackDriver` on the display link | `Sources/FlareApp/PlaybackDriver.swift`, `Tests/AppSnapshotTests/PlaybackDriverTests.swift` | – |
| MP-5 | #373 (part) | `RecoveryFile` and the autosave writer: due-time polling, off-main atomic write, remove after a clean save, write on quit | `Sources/FlareApp/FlareAutosave.swift`, `Tests/AppSnapshotTests/AutosaveTests.swift` | MP-2 |
| MP-6 | #373 (closes) | Recovery on launch: read off main, decode, the offer's text and date, Restore and Discard, a damaged file removed | `Sources/FlareApp/FlareAutosave.swift`, `Tests/AppSnapshotTests/AutosaveRecoveryTests.swift` | MP-5 |
| MP-7 | – | C4: `flare-app-sources` names StagePath, PlaybackDriver and FlareAutosave; `flare-model-sources` names Open Recent and the autosave due time | `docs/c4/model.json` | MP-2, MP-3, MP-4, MP-6 |

MP-7 is its own PR only if the earlier PRs did not already carry their
description lines; CLAUDE.md wants each PR to update the description it
outgrows, so the preferred path is that MP-2, MP-3, MP-4 and MP-6 each edit
their own sentence and MP-7 is dropped. Either way only this feature edits
`docs/c4/model.json` in wave 1.

MP-3 and MP-4 have no dependency on the others and can run in parallel with
MP-1. The window does not call `PlaybackDriver` or `FlareAutosave` yet: that
wiring belongs to F7b (#376), F17c (#393) and IN-2 (#385).

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| MP-1 | `FlareRecentTests`: open A, B, then A gives `[A, B]`; 11 distinct opens keep 10 with the oldest gone; a failed open keeps the list; a save as C puts C first; `clearRecent` empties it | the list is not most-recent-first, grows past 10, or changes on a failed open |
| MP-2 | `FlareAutosaveDueTests`: an edit at 0 is not due at 29.9 and due at 30.0; clean is never due; after `didSave` not due; undo back to the saved document not due; NaN times not due; `recoveryData()` decodes to `document`, nil when clean. `MacPlatformJourneyTests` runs steps 1–2 on `bounce` | due early, due while clean, or the bytes don't round-trip |
| MP-3 | `StagePathTests`: for an ellipse (4 cubics) and a pen path with 2 cubics and 1 line, `CGPath.applyWithBlock` counts exactly 4 and 2 `addCurveToPoint` and 1 `addLineToPoint`; a translate-by-(10, 20) matrix moves `boundingBoxOfPath` by (10, 20); `cgColor` of (1, 0.5, 0, 0.25) has those sRGB components; a NaN point is skipped | a cubic is flattened, an element is lost, the matrix is ignored or a color is converted in the wrong space |
| MP-4 | `PlaybackDriverTests`: ticks at 10.0, 10.0 + 1/60, 10.0 + 2/60 give nil, 1/60, 1/60 (exact to 1e-12) whatever the wall clock; `reset()` then a tick 5 s later gives nil, not 5; a non-increasing timestamp gives nil; `stop()` invalidates the link | elapsed comes from wall time, a pause gap is counted, or the link keeps running |
| MP-5 | `AutosaveTests` (temp folder): a due model writes the recovery file once; a clean model writes nothing; the write is atomic (no partial file after a thrown write); `remove()` after a clean save leaves no file; a quit-time write happens when dirty | no write when due, a write when clean, or the file outlives a clean save |
| MP-6 | `AutosaveRecoveryTests`: a recovery file of `bounce` gives the offer text "Restore the unsaved animation from <time>?" with the file's date; Restore lands `bounce` and leaves the window dirty; Discard deletes the file; a damaged file is deleted with no offer | an offer for a damaged file, a lost restore, or a file left behind after Discard |
| MP-7 | `scripts/ci` C4 check passes and the descriptions name every new file | – (docs only; the check fails on a missing path) |

## Quality tests

| quality row | budget | test |
|---|---|---|
| no data loss (section 7.5, LA-3) | a kill after the due time loses no edit | `AutosaveTests.dueModelWritesRecovery`, `AutosaveRecoveryTests.restoreLandsTheDocument` |
| QB-L4 hook | elapsed from the link's target timestamp, so P4 can hold 0 dropped frames | `PlaybackDriverTests.usesTargetTimestamps` (P4 itself runs after IN-2) |
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
