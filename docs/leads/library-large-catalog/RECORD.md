# large-catalog lead record

Issue: #3790 · Packet: docs/blueprints/library/features/large-catalog.md
Run: act-1a16c627c84-u86z · Session: claude/large-catalog-lead-jhxt1n (earlier act-1a1693fbf6d-ap2g, act-1a15df37b73-k199) · Started: 2026-10-21T10:19Z (resumed 2026-10-23T14:20Z, 2026-10-24T05:10Z)
Stage: 3 wave 3 (LG-grid: LG-6 building first on the supervisor's answer; LG-5 waits on ST-a #4840)
Base: 8021b0f56a45a59540cd4ea0ff99651c5fb8dc2a (origin/dev)
Next: LG-6 PR (RenderQueue neighbour lane, far-decode drop; 2 commits on claude/large-catalog-lead-jhxt1n, Mutate 4/4, gate running); LG-5 on ST-a fakes with `Wire: shared-thumbnails:ST-a` once #4840 merges, stacked on LG-6

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LG-a | 10,000-photo fixture and every budget test, disabled | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (met) | no | 1 | done #4006, fix #4073 (c5801375) | 39601343733 | - |
| LG-model | load off main with id index, IndexSet selection, one-pass export plan | LG-3, LG-4 | MJ-LG | LG-a; FC-a (met: filters-collections built), MD-e, DR-m (stubs, supervisor's answer b) | no | 0 | done (#4847, afb9cbed; run 40029034328) | - | - |
| LG-grid | grid and loupe within budget, jobs, built | LG-5..LG-8 | LJ-LG, MJ-LG | LG-model; suiteui shared-thumbnails ST-m; FC-c (met) | yes | 0 | building (LG-6) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LG-1 | LG-a | 1 | LibraryFixtures.large(count:folder:), budget tests disabled | LibraryLargeFixture.swift, LargeCatalogBudgetTests.swift | LargeCatalogBudgetTests | #4006 | merged |
| LG-2 | LG-a | 1 | large journey (skipped), -LibraryLargeFixture flag, RJ-L56 folder | LibraryJourneyTests+Large.swift, LibraryLaunch.swift, large-catalog.jobs.json | launch flag test, scripts/jobs check | #4006 | merged |
| LG-3 | LG-model | 2 | direct select all, cheap can-export check | LibrarySelectionAdapter.swift, LibraryActions.swift, LibraryExport.swift, LargeCatalogEquivalenceTests.swift, mutations | LargeCatalogEquivalenceTests | #4847 | merged |
| LG-4 | LG-model | 2 | one-pass export names (stems parsed once, one taken set) | Contracts/ExportNaming+Kernel.swift, Live/LiveExporter.swift, LargeCatalogEquivalenceTests.swift, mutations | LargeCatalogEquivalenceTests | #4847 | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The record is at docs/leads/large-catalog/ on lead/large-catalog, the path this run's brief names; lead/library-large-catalog keeps the earlier run's copy.
- Base and PR target are dev, not main (CLAUDE.md). The brief named main cb79cbb6.
- LG-1 and LG-2 shipped as one LG-a PR. LG-3 and LG-4 ship as one LG-model PR (one PR per slice).
- LG-model starts now on the supervisor's answer (b) on #3790 (2026-10-21 13:44Z): build on what dev has, parts that need FC-a, MD-e, DR-m behind stubs declared in the contract (rule 18). filters-collections is built on dev, so FC-a and FC-c are met.
- LG-7's Tests/perf-suites.txt line is the supervisor's (protected).
- LG-6 before LG-5: supervisor's answer on #3790 (comment 6380089356, 2026-10-24T04:55Z). LG-5 builds on ST-a's fakes with a `Wire: shared-thumbnails:ST-a` line once #4840 merges.
- LG-6 scope: neighbour prefetch already exists but runs beside the render, unbounded per step; LG-6 queues the neighbours behind the render in RenderQueue and drops a superseded step's pending decodes, so stale prefetches never evict the focus's decodes.

## Open
- 2026-10-23T23:17Z: LG-grid wait re-read: contract-first (supervisor 15:13Z) makes it met when ST-a #4840 merges; #4840 needs-fix since 19:15Z. Rule 23 question posted on #3790 proposing LG-6 (loupe, no thumbnail store) ahead of LG-5.
- 2026-10-23T15:53Z: #4847 opened (238 lines, 10 files; CI: PASS on 9f19aa0a; Mutate 17/17). Fixes #3213 #3214; Refs #3110 #1650 #4835.
- 2026-10-23T15:44Z: LG-model measured. Release, suite run in parallel: plan, load, shift-range, beginExport pass; select all 12.0 ms vs 5 ms on 10,000. Release alone (--no-parallel, best of 10): select all 5.0 ms, of which SuiteKernel Selection.unique is 4.6 ms (Set(order) is 1.4 ms). Kernel is line:suite: filed #4835 (needs-suite) for a fast path when ids are already unique. The timed suite LargeCatalogModelBudgetTests stays disabled until LG-7 lists it in perf-suites, so the gate does not depend on #4835. Debug before/after: plan 191 ms to under 50, beginExport 52.7 ms to under 10, select all 2.14 to 0.885 ms (1,000).
- Belt reads lead/library-large-catalog; this record is mirrored there at docs/leads/library-large-catalog/ from 2026-10-23T15:44Z on.
- LG-grid needs suiteui shared-thumbnails ST-m (wave file planned, no slice status on 2026-10-23); re-checked each heartbeat.
