# Feature packet: photo-journey-kit

**Feature:** the shared journey helpers every v2 Photo journey file calls:
`writeTestPhoto(to:)` moved out of `PhotoJourneyTests` (where it is `private
static`) into `UITests/PhotoJourneyTests+Fixtures.swift`, plus one launch
helper for the v2 arguments. Blueprint 4.1 gives this to PV-0; it is its own
feature here because it is the only part of PV-0 that waits on SuiteUI.
**Line:** `line:photo` · **Wave:** 0 (`waves.md`) · **Tier:** p1 by dependency
· **Lead branch:** `lead/photo-journey-kit`

**Covers:** no open issue.

**Depends on:** #333 (QH-4), which suite-harness (#778) closes with its
task SH-7: the journey template then compiles `UITests/<target>*.swift`, so a
second Photo journey file builds. It needs only that task, not the whole of
suite-harness. Today `project.yml` compiles only
`UITests/PhotoJourneyTests.swift`, and this feature never edits `project.yml`
or `UITests/Journey*.swift` (shared-file rule). It does not wait on
photo-seams: it touches no file photo-seams owns and needs none of its code
(the helper only passes argument strings).

Only the journey tasks of the wave-1 features (D-11, D-12, E-9, E-10, CP-5,
CP-7) and of photo-adjustment-layers (AL-8) wait on this feature, since
their journey files call `writeTestPhoto`; their Model and view tasks don't.

## Journey steps

1. **`PhotoJourneyKitTests.testWrittenPhotoOpens`** (new class in
   `+Fixtures`): `writeTestPhoto(to: tmp/beach.png)`; launch with
   `photoArguments(open: that path)`. Assert the window title is
   `beach.png` and the canvas exists. `shot` the window.
2. V1–V12 in `PhotoJourneyTests` run unchanged, now calling the moved helper.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Main window after a launch with a written photo | – | a missing file: today's open error (unchanged) | none |

## Contract slice

```swift
// UITests/PhotoJourneyTests+Fixtures.swift
/// Writes the test photo as a PNG: 800 x 600 by default (sky gradient, sun at (560, 220), r 90);
/// the hitch probe asks for 4000 x 3000. Today's signature and body, unchanged.
func writeTestPhoto(to url: URL, width: Int = 800, height: Int = 600) throws
/// Launch arguments for a Photo journey; nil arguments are left out.
func photoArguments(open file: URL? = nil, saveTo: URL? = nil, exportTo: URL? = nil,
                    fixture: String? = nil, recoveryDir: URL? = nil, windowWidth: Int? = nil) -> [String]
```

## Pseudocode

```
move PhotoJourneyTests.writeTestPhoto (private static) to a top-level internal function, body unchanged
photoArguments: for each non-nil -> ["-PhotoOpenFile", path], ["-PhotoSaveTo", path], ["-PhotoExportTo", path],
  ["-PhotoFixture", name], ["-PhotoRecoveryDir", path], ["-PhotoWindowWidth", "\(w)"]
PhotoJourneyTests: replace its seven Self.writeTestPhoto(...) calls with writeTestPhoto(...) and its
  hand-built argument arrays with photoArguments(...); no step or assertion changes
```

## Tasks

One PR to `dev`, at most 400 lines and 15 files, label `fast-lane` and
`feature-done`, body lines `Belt-Lead:`, `Feature: photo-journey-kit`,
`Fast-Check: pass`, `Head:`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| KT-1 | – | Move `writeTestPhoto`, add `photoArguments`, the smoke journey; `PhotoJourneyTests` calls them | `UITests/PhotoJourneyTests.swift`, `UITests/PhotoJourneyTests+Fixtures.swift` | #333 closed | ~150, 2 |

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| KT-1 | The macOS CI log lists `PhotoJourneyKitTests.testWrittenPhotoOpens` and it passes; V1–V12 pass; `photoArguments(open: u, fixture: "sample")` is `["-PhotoOpenFile", u.path, "-PhotoFixture", "sample"]` (asserted at the top of the smoke test, before launch) | the second file isn't compiled, a v1 journey breaks, or an argument is spelled wrong |

## Quality tests

| quality row | budget | test |
|---|---|---|
| 7.2 audit | no Photo count rises | the app audit of the CI run the PR triggers |
| 4.1 waiting | state is awaited with `waitForExistence` (5 s), never a sleep | `testWrittenPhotoOpens` |

## Done check

- **Journeys green:** the macOS run on `dev` the PR triggers is green, with
  the smoke journey listed.
- **Audit zero new:** no Photo count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  the new shot is the v1 open state.
