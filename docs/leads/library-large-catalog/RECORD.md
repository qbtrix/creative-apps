# large-catalog lead record

Issue: #3790 · Packet: docs/blueprints/library/features/large-catalog.md
Run: act-1a15df37b73-k199 · Session: claude/library-line-lead-lqhhp8 · Started: 2026-10-21T10:19Z
Stage: 3 wave 1 (LG-a building)
Base: e2b8aa76 (origin/dev)
Next: LG-a PR (LG-1 fixture and disabled budgets, LG-2 journey, launch flag, RJ-L56 folder); LG-model waits on LG-a, FC-a, MD-e, DR-m; LG-grid on LG-model, FC-c, suiteui shared-thumbnails ST-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LG-a | 10,000-photo fixture and every budget test, disabled | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (met: MD-1..MD-4 on dev) | no | 0 | building | - | - |
| LG-model | load off main with id index, IndexSet selection, one-pass export plan | LG-3, LG-4 | MJ-LG | LG-a; FC-a, MD-e, DR-m | no | 0 | blocked | - | - |
| LG-grid | grid and loupe within budget, jobs, built | LG-5..LG-8 | LJ-LG, MJ-LG | LG-a, LG-model; suiteui shared-thumbnails; FC-c | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LG-1 | LG-a | 1 | LibraryFixtures.large(count:folder:), budget tests disabled | LibraryLargeFixture.swift, LargeCatalogBudgetTests.swift | LargeCatalogBudgetTests | #4006 | in lane |
| LG-2 | LG-a | 1 | large journey (skipped), -LibraryLargeFixture flag, RJ-L56 folder | LibraryJourneyTests+Large.swift, LibraryLaunch.swift, large-catalog.jobs.json | launch flag test, scripts/jobs check | #4006 | in lane |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The record moved to lead/library-large-catalog at docs/leads/library-large-catalog/, where Belt reads it. lead/large-catalog is the old copy.
- Base is dev, not main: the packet's waits are on dev and PRs target dev (CLAUDE.md). The brief named main 0dd23d65.
- LG-1 and LG-2 ship as one LG-a PR (one PR per slice); the packet's wave split is kept by building LG-1 first in it.
- MD-a counts as met: MD-1..MD-4's code (CameraDetails, SidecarContracts, cameras fixture, slots) is on dev though the wave file's status is unset.
- LG-7 edits Tests/perf-suites.txt, a protected path: the supervisor makes that line; LG-7's PR carries only the jobs file.

## Open
- LG-a #4006 at head 95d4c1b8: Fast-Check pass, macOS build green, waiting on the lane batch.
- LG-model waits on FC-a, MD-e and DR-m; it is re-checked at each heartbeat.
- dev-red #3856 open (others' merges).
