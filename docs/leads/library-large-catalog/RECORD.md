# large-catalog lead record

Issue: #3790 · Packet: docs/blueprints/library/features/large-catalog.md
Run: act-1a15df37b73-k199 · Session: claude/library-line-lead-lqhhp8 · Started: 2026-10-21T10:19Z
Stage: 3 wave 1 done (LG-a done on 39601343733; #4073 hardening open); LG-model waits on FC-a, MD-e, DR-m
Base: e2b8aa76 (origin/dev)
Next: Belt-Slice-Done for LG-a; LG-model waits on FC-a, MD-e, DR-m; LG-grid on LG-model, FC-c, suiteui shared-thumbnails ST-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LG-a | 10,000-photo fixture and every budget test, disabled | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (met: MD-1..MD-4 on dev) | no | 0 | merged | - | - |
| LG-model | load off main with id index, IndexSet selection, one-pass export plan | LG-3, LG-4 | MJ-LG | LG-a; FC-a, MD-e, DR-m | no | 0 | blocked | - | - |
| LG-grid | grid and loupe within budget, jobs, built | LG-5..LG-8 | LJ-LG, MJ-LG | LG-a, LG-model; suiteui shared-thumbnails; FC-c | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LG-1 | LG-a | 1 | LibraryFixtures.large(count:folder:), budget tests disabled | LibraryLargeFixture.swift, LargeCatalogBudgetTests.swift | LargeCatalogBudgetTests | #4006 | merged |
| LG-2 | LG-a | 1 | large journey (skipped), -LibraryLargeFixture flag, RJ-L56 folder | LibraryJourneyTests+Large.swift, LibraryLaunch.swift, large-catalog.jobs.json | launch flag test, scripts/jobs check | #4006 | merged |

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
- LG-a #4006 merged at 11:52Z as c2aa3391. dev Linux check 39596004859 on c2aa3391 went red only on LibraryFoldersTests.tenThousandPaths (31.6 ms vs 20 ms; folder tree #3961, a timing budget, not LG-a). Waiting on 39598650564 (76d0c892); Belt-Slice-Done is posted once its Linux job is green. dev-red #3856 is a PhotoApp CommandPath failure whose fix, #4008, is below c2aa3391.
- LG-model waits on FC-a, MD-e and DR-m; it is re-checked at each heartbeat.
- dev-red #3856 open (others' merges).

- 12:45Z: dev Linux check 39598650564 (76d0c892) red on our LargeCatalogBudgetTests.fixtureBuildsTenThousandDeterministically (6.45 s vs 5 s wall clock at line 25), plus the not-ours LibraryFoldersTests.tenThousandPaths. Decision: LG-a fix round 1. The fixture test keeps determinism only; the 5 s budget moves to its own disabled suite LargeCatalogFixtureBudgetTests, and the supervisor is asked to list it in Tests/perf-suites.txt (protected).

- 13:05Z: Linux 39601343733 (737541328, contains c2aa3391) red only on LibraryFoldersTests.tenThousandPaths (28.4 ms, #3961, not ours); LG-a tests green. Posted Belt-Slice-Done: LG-a (LG-a is not a UI slice, so no Mac-Finish-Wanted). #4073 (fix round 1) stays open to take the timing assert out of the gate. Asked the supervisor on #3790 to list LibraryFoldersTests/tenThousandPaths in perf-suites, since it has been red in 3 checks in a row.
