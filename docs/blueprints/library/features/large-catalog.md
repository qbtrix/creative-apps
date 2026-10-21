# Feature packet: large-catalog

**Feature:** a weekly shooter's catalog doesn't feel slow. Six findings are
open on a large catalog: grid scroll (#3108), the loupe step (#3109), launch
(#3110), grid selection p95 at 2 to 3 times its 33 ms target (#1650), the export
plan for 1,000 photos (#3213) and `beginExport` on 10,000 (#3214). This packet
measures first: a deterministic 10,000-photo fixture catalog (with tiny real
JPEGs and their thumbnails) and one budget test per finding, written failing.
Then each slice fixes one area against its test: the catalog loads once off the
main thread and indexes by id; selection is index-set arithmetic, not array
scans; the grid asks for thumbnails only for visible rows plus two screens and
reuses cells by id; the loupe keeps its neighbours decoded; and the export plan
is one pass. No new feature and no new control.
**Line:** `line:library` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/large-catalog`
**Beta:** captain, 2026-10-21 (beta gaps, Library must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Library must-have "speed on
10,000 photos"; Library audit row 12; #3108, #3109, #3110, #1650, #3213, #3214
(each closed by its slice); RJ-L07 (re-pointed here) and RJ-L56 (new).

**Depends on:** spine (building), thumbnails, loupe-viewport and export
(built). Cross-line: suiteui **shared-thumbnails** gives the disk tier the grid
reads after a relaunch; LG-grid starts after its ST-m.

**Rule 20.** Fixes go where each concept lives: thumbnails through
shared-thumbnails' store, selection through the kernel's `Selection` adapter
(`LibrarySelectionAdapter`), the export plan in Library's exporter. No cache
of Library's own beside the shared one.

**C4:** the fixture file joins `c4-planned.json`'s "Fixtures and launch"
component (this PR).

**Clean-room.** Nothing external is read.

Blueprint sections: library.md 9 (budgets).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (orientation-crop OC-library-u) also edit `LibraryGrid.swift`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LG-a | A 10,000-photo fixture catalog exists and every finding has a budget test on it, written and disabled by the slice that fixes it. | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (`LibraryLaunch.swift`) |
| LG-model | The catalog loads off the main thread with an id index, selection is index-set arithmetic, and the export plan is one pass, each within its budget on 10,000 photos (#3110, #1650, #3213, #3214). | LG-3, LG-4 | MJ-LG | LG-a; filters-collections:FC-a, metadata-more:MD-e, cull-finish:DR-m (`LibraryCatalog.swift`) |
| LG-grid | The grid scrolls 10,000 photos within budget through the shared thumbnail store and the loupe steps within budget (#3108, #3109), RJ-L07 and RJ-L56 pass, and the feature is built. | LG-5, LG-6, LG-7, LG-8 | LJ-LG, MJ-LG | LG-a, LG-model, LG-model; suiteui shared-thumbnails (cross-line); filters-collections:FC-c (`LibraryWindow.swift`) |

**Measure first.** LG-a lands every budget test before any fix, each disabled
by the slice that turns it on, so each fix PR shows its own before and after.
`Tests/perf-suites.txt` is a supervisor-managed list (LG-7 is off the fast
lane).

## Journey steps

`MJ-LG` on Linux (`LargeCatalogBudgetTests`), then:
1. Launch Library with `-LibraryLargeFixture 10000`; the grid paints within 1.5 s; scroll 120 rows; select all; shift-click a range; open the loupe and step 20 times (LG-5, LG-6; `LJ-LG`, `LibraryLargeCatalogJourneyTests.testTenThousandPhotos`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L07 | closes (re-pointed to `library/large-catalog`; `needs` keep `library/thumbnails`) | J | its existing check, on the 10,000-photo fixture | `-LibraryLargeFixture 10000` |
| RJ-L56 | adds, closes with `library/large-catalog` | C | `Tests/RealJobs/library/large-catalog/`: open the 10,000 catalog headless, `select.all`, `photo.rate` 3 on all, export plan for 1,000 | the fixture |

Trap: the app is fine at 200 photos and stalls at 10,000 (an O(n²) scan in
select or plan). Assertion: open ≤ 400 ms, rate-all one step ≤ 200 ms, plan
≤ 50 ms debug, on the Linux job's timing. Mutation:
`LibraryModel.LiveExporter` (`.uniqueNamesInOnePass`). LG-2 writes it.

## Screens and states

None new. Library's grid and loupe snapshots must not change.

## Contract slice

```swift
// Sources/LibraryModel/LibraryLargeFixture.swift (LG-1). Linux-safe.
extension LibraryFixtures {
    /// A deterministic catalog of `count` photos with generated 64 px JPEGs under `folder`.
    public static func large(count: Int, folder: String) throws -> LibraryCatalog
}
```

No new commands. Budgets (release unless marked): load 10,000 ≤ 400 ms; select
all ≤ 5 ms; shift-range 5,000 ≤ 10 ms; export plan 1,000 ≤ 50 ms (debug);
`beginExport` 10,000 ≤ 10 ms (debug); first grid paint ≤ 1.5 s; scroll p95 ≤
16 ms; loupe step p95 ≤ 50 ms.

## Pseudocode

- **Load.** Decode the catalog on a detached task; build `[id: index]` once;
  publish to the main actor in one assignment.
- **Select.** The grid's order is an array of indices; selection is an
  `IndexSet` over it; ids are looked up through the map only at the edges
  (commands, persistence).
- **Grid.** The visible row range from the scroll offset; request thumbnails
  for it plus two screens either side; cancel requests that leave that window.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LG-1 | – | `LibraryFixtures.large(count:)`: a deterministic catalog of `count` photos (64 px JPEGs generated once into the test's temp folder, varied ratings, dates and folders); `LargeCatalogBudgetTests` with the Model budgets (load, select all, shift-range, export plan, beginExport), each disabled until its slice | `Sources/LibraryModel/LibraryLargeFixture.swift`, `Tests/LibraryModelTests/LargeCatalogBudgetTests.swift` | – | ~200, 2 |
| LG-2 | – | `LibraryLargeCatalogJourneyTests` (launch on the fixture, scroll the grid 120 rows, select all, step the loupe 20 times) written with the window budgets, skipped until LG-grid; `-LibraryLargeFixture` launch flag; RJ-L56's job folder | `UITests/LibraryJourneyTests+Large.swift`, `Sources/LibraryModel/LibraryLaunch.swift`, `Tests/RealJobs/library/large-catalog/large-catalog.jobs.json` | LG-1 | ~150, 3 |
| LG-3 | – | Load and select: the catalog decodes once on a background task and builds an id → index map; selection, select all and shift-range use `IndexSet` through `LibrarySelectionAdapter`; turns on the load and selection budgets (#3110, #1650) | `Sources/LibraryModel/LibraryCatalog.swift`, `Sources/LibraryModel/LibrarySelectionAdapter.swift`, `Tests/LibraryModelTests/LargeCatalogBudgetTests.swift`, `Tests/mutations/LibraryModel.LibrarySelectionAdapter.json` | LG-1 | ~220, 4 |
| LG-4 | – | Export plan in one pass: names and destinations computed with one dictionary of taken names, not a scan per photo; `beginExport` reads the selection's index set; turns on the export budgets (#3213, #3214) | `Sources/LibraryModel/Live/LiveExporter.swift`, `Sources/LibraryModel/LibraryExport.swift`, `Tests/mutations/LibraryModel.LiveExporter.json` | LG-1 | ~150, 3 |
| LG-5 | – | Grid: visible-range thumbnail requests with a two-screen prefetch and cancellation, cells keyed by photo id, no per-cell model lookups by scan; turns on the journey's scroll and launch steps (#3108, #3110 window half) | `Sources/LibraryApp/LibraryGrid.swift`, `Sources/LibraryModel/LibraryThumbnails.swift`, `Tests/mutations/LibraryModel.LibraryThumbnails.json`, `UITests/LibraryJourneyTests+Large.swift` | LG-3, LG-2 | ~200, 4 |
| LG-6 | – | Loupe: decode the next and previous photos at fit size after each step, drop farther ones; turns on the loupe step (#3109) | `Sources/LibraryModel/LoupeState.swift`, `Sources/LibraryModel/RenderQueue.swift`, `Tests/mutations/LibraryModel.RenderQueue.json` | LG-5 | ~140, 3 |
| LG-7 | – | RJ-L07 re-pointed and RJ-L56 enabled; the perf list names the new budget tests | `Tests/RealJobs/library/large-catalog/large-catalog.jobs.json`, `Tests/perf-suites.txt` | LG-6, LG-4 | ~30, 2 |
| LG-8 | – | `status: built`; `feature-done` | `docs/blueprints/library/features/large-catalog.wave.json` | LG-7 | ~10, 1 |

## Build waves

- Wave 1: LG-1. Independent in this wave: LG-1 alone.
- Wave 2: LG-2, LG-3, LG-4. Independent in this wave: all.
- Wave 3: LG-5. Independent in this wave: LG-5 alone.
- Wave 4: LG-6. Independent in this wave: LG-6 alone.
- Wave 5: LG-7. Independent in this wave: LG-7 alone.
- Wave 6: LG-8. Independent in this wave: LG-8 alone.

Longest chain: LG-1 → LG-3 → LG-5 → LG-6 → LG-7 → LG-8 (6). Chain of 6: the fixture, the model fixes, the grid and loupe, the jobs and the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LG-1 | the fixture builds 10,000 photos under 5 s; the suite compiles with every budget disabled by name | the fixture is non-deterministic | – (fixture and tests) |
| LG-2 | compiles, skipped by name; `scripts/jobs check` | the journey can't load the fixture | – (tests) |
| LG-3 | `LargeCatalogBudgetTests`: load 10,000 ≤ 400 ms release; select all ≤ 5 ms; shift-range of 5,000 ≤ 10 ms; selection results equal the old path's on 100 random cases | a budget is missed or the selection differs | `LibraryModel.LibrarySelectionAdapter`: range end off by one → `.shiftRangeInclusive`; select all skips filtered-out photos wrongly → `.selectAllRespectsFilter` |
| LG-4 | `LargeCatalogBudgetTests`: plan for 1,000 ≤ 50 ms debug; `beginExport` of 10,000 ≤ 10 ms debug; the plan's names equal the old plan's on the fixture | a budget is missed or two files get one name | `LibraryModel.LiveExporter`: taken names not updated per photo → `.uniqueNamesInOnePass` |
| LG-5 | `LJ-LG` scroll: 120-row scroll p95 ≤ 16 ms, ≤ 3 window bodies; first grid paint ≤ 1.5 s after launch | the scroll or launch misses its budget | `LibraryModel.LibraryThumbnails`: prefetch window not cancelled on scroll → `.cancelsOffscreen` |
| LG-6 | `LJ-LG` loupe: 20 steps, p95 ≤ 50 ms to a sharp fit image | a step waits on a decode it could have done earlier | `LibraryModel.RenderQueue`: neighbours not queued → `.prefetchesNeighbours`; old decodes kept → `.dropsFarDecodes` |
| LG-7 | RJ-L56 on Linux; RJ-L07 in the scoped run | a budget regresses | – (jobs) |
| LG-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: 120-row grid scroll at 10,000 photos | ≤ 3 window bodies; p95 ≤ 16 ms | `LibraryLargeCatalogJourneyTests` (perf list) |
| render: loupe step | p95 ≤ 50 ms | `LibraryLargeCatalogJourneyTests` |
| model budgets | as in the contract | `LargeCatalogBudgetTests` |
| behaviour preserved | selection and export plans equal the old path's | `LargeCatalogBudgetTests` |

## Done check

Per slice (rules 6, 15, 17, 21, 22): LG-a and LG-model green on Linux with
`Mutate:` clean and their budgets met; LG-grid through the feel gate (`perf`:
scroll and step on the fixture, release build) with its `Mac-Finish:` line;
RJ-L56 green on Linux and RJ-L07 in the scoped run. Each fix PR closes its
finding (`Fixes #n`).
