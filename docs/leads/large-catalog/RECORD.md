# large-catalog lead record

Issue: #3790 · Packet: docs/blueprints/library/features/large-catalog.md
Run: act-1a1693fbf6d-ap2g · Session: claude/large-catalog-share-sheet-2tdm4i (earlier act-1a15df37b73-k199) · Started: 2026-10-21T10:19Z (resumed 2026-10-23T14:20Z)
Stage: 3 wave 2 (LG-model building on rule-18 stubs)
Base: 8021b0f56a45a59540cd4ea0ff99651c5fb8dc2a (origin/dev)
Next: LG-model PR (LG-3 load and IndexSet selection, LG-4 one-pass export plan, budgets on, mutations); LG-grid waits on LG-model and suiteui shared-thumbnails ST-m (planned, no slice status)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LG-a | 10,000-photo fixture and every budget test, disabled | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (met) | no | 1 | done #4006, fix #4073 (c5801375) | 39601343733 | - |
| LG-model | load off main with id index, IndexSet selection, one-pass export plan | LG-3, LG-4 | MJ-LG | LG-a; FC-a (met: filters-collections built), MD-e, DR-m (stubs, supervisor's answer b) | no | 0 | building | - | - |
| LG-grid | grid and loupe within budget, jobs, built | LG-5..LG-8 | LJ-LG, MJ-LG | LG-model; suiteui shared-thumbnails ST-m; FC-c (met) | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LG-1 | LG-a | 1 | LibraryFixtures.large(count:folder:), budget tests disabled | LibraryLargeFixture.swift, LargeCatalogBudgetTests.swift | LargeCatalogBudgetTests | #4006 | merged |
| LG-2 | LG-a | 1 | large journey (skipped), -LibraryLargeFixture flag, RJ-L56 folder | LibraryJourneyTests+Large.swift, LibraryLaunch.swift, large-catalog.jobs.json | launch flag test, scripts/jobs check | #4006 | merged |
| LG-3 | LG-model | 2 | id index, IndexSet selection through LibrarySelectionAdapter, load and select budgets on | LibraryCatalog.swift, LibrarySelectionAdapter.swift, LargeCatalogBudgetTests.swift, mutations | LargeCatalogBudgetTests | - | building |
| LG-4 | LG-model | 2 | one-pass export plan, beginExport on the index set, export budgets on | Live/LiveExporter.swift, LibraryExport.swift, mutations | LargeCatalogBudgetTests | - | building |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The record is at docs/leads/large-catalog/ on lead/large-catalog, the path this run's brief names; lead/library-large-catalog keeps the earlier run's copy.
- Base and PR target are dev, not main (CLAUDE.md). The brief named main cb79cbb6.
- LG-1 and LG-2 shipped as one LG-a PR. LG-3 and LG-4 ship as one LG-model PR (one PR per slice).
- LG-model starts now on the supervisor's answer (b) on #3790 (2026-10-21 13:44Z): build on what dev has, parts that need FC-a, MD-e, DR-m behind stubs declared in the contract (rule 18). filters-collections is built on dev, so FC-a and FC-c are met.
- LG-7's Tests/perf-suites.txt line is the supervisor's (protected).

## Open
- LG-grid needs suiteui shared-thumbnails ST-m (wave file planned, no slice status on 2026-10-23); re-checked each heartbeat.
