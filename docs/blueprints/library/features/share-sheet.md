# Feature packet: share-sheet

**Feature:** "send these three to my phone". File > **Share ▸** and a Share
button in the grid's and the loupe's toolbars hand the selected photos to the
system share sheet (Mail, Messages, AirDrop, Notes, and any share extension
the Mac has). What is shared is a developed JPEG of each photo at the export
pack's sharing settings (long edge 2048 px, quality 85, **location removed**),
written to a temporary share folder that is emptied at the next launch, so the
originals never leave and no copy lingers (RJ-X07). SuiteUI gets one
`ShareButton` over SwiftUI's `ShareLink`, so the other apps can adopt it later
(suite audit V1 row). The preparing step is a catalog command
(`file.share-prepare`), so an agent can make the same files.
**Line:** `line:library` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/share-sheet`
**Beta:** captain, 2026-10-21 (beta gaps, Library must-haves; blueprint 1.3's
"sharing services" non-goal is re-cut for the system share sheet). Labels
`beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Library must-have "share sheet";
Library audit row 11; RJ-L55 (new).

**Depends on:** export-pack (wave 5: `ExportOptions` with the location-off
policy and the size presets), spine (building). Photo, Design, Flare and Halo
adopt `ShareButton` later; this packet only builds it once.

**Rule 20.** The export is the kernel's `ExportRun` through Library's existing
exporter, no second encoder; the button is SwiftUI's `ShareLink` in one SuiteUI
view (`ShareButton`), no AppKit picker code in the app.

**Privacy.** The share copies carry no GPS, serial or MakerNote (export-pack's
policy, location off); they live in `<support>/Share/` and are deleted at
launch; nothing is uploaded by the app.

**C4:** Library's new files join `c4-planned.json`'s "Export" component (this
PR); `ShareButton.swift` is in `suiteui-sources`.

**Clean-room.** The share sheet is the system's.

Blueprint sections: library.md 1.3 (re-cut), 7 (export).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-library, orientation-crop OC-library-m) also edit `LibraryCommandCatalog.swift` and `Tests/command-ids/library.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SH-a | Library declares the share preparation and its command, and SuiteUI the share button, as stubs, with the checks written and disabled. | SH-1, SH-2 | MJ-SH | – |
| SH-u | File > Share and the grid's and loupe's Share buttons open the system share sheet for the selection on the stubs, within the render budget. | SH-4, SH-4b | LJ-SH | SH-a; spine |
| SH-m | Preparing writes one developed, location-free JPEG per selected photo into an emptied-at-launch share folder through the existing exporter, as a catalog command. | SH-3, SH-3c | MJ-SH | SH-a; export-pack (built options); file-flow:LF-m and catalog-backup:BK-m (the catalog and ledger) |
| SH-z | Sharing runs live end to end, RJ-L55 passes, and the feature is built. | SH-5, SH-6 | LJ-SH, MJ-SH | SH-u, SH-m |

**Screen early.** SH-u builds the menu and buttons on SH-a's stubs, beside SH-m.

## Journey steps

`MJ-SH` on Linux (`LibrarySharePrepTests`), then:
1. Select three photos, click Share in the grid's toolbar: the system share sheet lists three JPEGs; cancel; File > Share ▸ shows the same services (SH-4, SH-5; `LJ-SH`, `LibraryShareJourneyTests.testShareThreePhotos`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L55 | adds, closes with `library/share-sheet` | C | `Tests/RealJobs/library/share-three/`: select three geotagged photos, `file.share-prepare` | three geotagged JPEGs |

Trap: the shared copies keep the GPS position, are full-size originals, or
pile up in a temp folder forever. Assertion: three files, each with long edge
2048 and no GPS, serial or MakerNote; after a simulated relaunch the share
folder is empty. Mutation: `LibraryModel.LibraryShare+Kernel`
(`.shareDropsLocation`). SH-3c writes it.

## Screens and states

`library-grid-share-button`, `library-file-share-menu`.

## Contract slice

```swift
// Sources/LibraryModel/LibraryShare+Kernel.swift (SH-1 stubs, SH-3 bodies)
public enum SharePrep {
    public static let options: ExportOptions            // export-pack's sharing preset: JPEG 85, long edge 2048, location off
    public static func folder(support: String, run: String) -> String   // <support>/Share/<run>
    public static func cleanup(support: String) throws  // at launch
}
// Sources/SuiteUI/ShareButton.swift (SH-2)
public struct ShareButton: View { public init(help: String?, prepare: @escaping () async throws -> [URL]) }
```

| id | title | params | unavailable when |
|---|---|---|---|
| `file.share-prepare` | – (not an undo step) | `{ids?}` → `{files: [path]}` | nothing selected; an export running |

## Pseudocode

- **Prepare.** Run Library's exporter on the selection with `SharePrep.options`
  into a fresh `<support>/Share/<run>/`; return the files in selection order.
- **Share.** `ShareButton` awaits `prepare`, then presents `ShareLink` with the
  URLs; Cancel leaves the folder for the launch cleanup.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SH-1 | – | **Checks first.** `LibrarySharePrepTests` written, disabled (`waits on SH-3`); `SharePrep` (the options from export-pack's sharing preset, the temp folder rule) and the `file.share-prepare` spec in `LibraryShare+Kernel.swift` as stubs | `Sources/LibraryModel/LibraryShare+Kernel.swift`, `Tests/LibraryModelTests/LibrarySharePrepTests.swift` | – | ~130, 2 |
| SH-2 | – | SuiteUI `ShareButton(items: [URL], prepare: () async throws -> [URL])` over `ShareLink`, a progress state while preparing and the reason when it can't; `ShareButtonTests` | `Sources/SuiteUI/ShareButton.swift`, `Tests/SuiteUITests/ShareButtonTests.swift` | SH-1 | ~120, 2 |
| SH-4 | – | **Reachable first.** File > Share ▸ (the system's share menu for the selection) and the toolbar `ShareButton` in the grid and the loupe; each prepares through `file.share-prepare` (unavailable on the stubs with "Sharing arrives with SH-3."); `LibraryShareJourneyTests` written, skipped until SH-5 | `Sources/LibraryApp/LibraryShareItems.swift`, `Sources/LibraryApp/LibraryMenus+Share.swift`, `UITests/LibraryJourneyTests+Share.swift` | SH-2 | ~150, 3 |
| SH-4b | – | Render budget test: open the share sheet for 3 photos | `Tests/AppSnapshotTests/RenderBudgetLibraryShareTests.swift` | SH-4 | ~60, 1 |
| SH-3 | – | `SharePrep` body and `file.share-prepare`: export each selected photo with the sharing preset into `<support>/Share/<run>/`, names unique, location off; the folder emptied at launch; the catalog appends the spec; id in the ledger; turns on `LibrarySharePrepTests` | `Sources/LibraryModel/LibraryShare+Kernel.swift`, `Sources/LibraryModel/LibraryCommandCatalog.swift`, `Tests/command-ids/library.txt`, `Tests/LibraryModelTests/LibrarySharePrepTests.swift`, `Tests/mutations/LibraryModel.LibraryShare+Kernel.json` | SH-1 | ~200, 5 |
| SH-3c | – | RJ-L55's job folder (prepare three photos, read their sizes and metadata) | `Tests/RealJobs/library/share-three/share-three.jobs.json` | SH-3 | ~40, 1 |
| SH-5 | – | The buttons and the menu on live; the journey on (the share sheet appears with three items; the harness cancels it) | `Sources/LibraryApp/LibraryShareItems.swift`, `UITests/LibraryJourneyTests+Share.swift` | SH-4, SH-3 | ~90, 2 |
| SH-6 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/share-sheet.wave.json` | SH-5, SH-3c | ~10, 1 |

## Build waves

- Wave 1: SH-1. Independent in this wave: SH-1 alone.
- Wave 2: SH-2, SH-3. Independent in this wave: both.
- Wave 3: SH-4, SH-3c. Independent in this wave: both.
- Wave 4: SH-4b, SH-5. Independent in this wave: both.
- Wave 5: SH-6. Independent in this wave: SH-6 alone.

Longest chain: SH-1 → SH-2 → SH-4 → SH-5 → SH-6 (5). Chain of 5: the stubs, the button, the menu, the live wiring, the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| SH-1 | compiles, disabled by name | a signature the button calls is missing | – (stubs) |
| SH-2 | `ShareButtonTests`: disabled with the reason when nothing is selected; shows progress while preparing | the button shares nothing silently | – (view) |
| SH-4 | the menu and the buttons carry ids and show the reason with nothing selected | a control has no id or command | – (view; render budget row) |
| SH-4b | `RenderBudgetLibraryShareTests.prepareThreeInTwoBodies` | preparing re-renders the grid per photo | – (budget) |
| SH-3 | `LibrarySharePrepTests`: 3 photos give 3 JPEGs of long edge 2048 with no GPS; two photos named alike get unique names; launch cleanup empties the folder | a shared file keeps its location, or copies pile up | `LibraryModel.LibraryShare+Kernel`: location policy not passed → `.shareDropsLocation`; launch cleanup skipped → `.shareFolderEmptiedAtLaunch` |
| SH-3c | `scripts/jobs check`; RJ-L55 on Linux | the job names a missing command | – (job) |
| SH-5 | `LJ-SH` | the sheet opens with no items | – (window wiring) |
| SH-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: prepare and open the share sheet for 3 photos | ≤ 2 window bodies; prepare under 2 s for three 24 MP photos | `RenderBudgetLibraryShareTests.prepareThreeInTwoBodies` |
| privacy | no location in shared copies; none left after a relaunch | RJ-L55 |
| no dead controls | the menu and the buttons run the command | `CommandPathTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): SH-a and SH-m green on Linux with
`Mutate:` clean; SH-u and SH-z through the feel gate (`mouse`) with their
`Mac-Finish:` lines; RJ-L55 green on Linux. Then `Belt-Contact-Sheet:`.
