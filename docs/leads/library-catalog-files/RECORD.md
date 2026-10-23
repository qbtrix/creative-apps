# catalog-files lead record

Issue: #3786 · Packet: docs/blueprints/library/features/catalog-files.md
Run: act-1a1695ec091-ilfv · Started: 2026-10-23T15:31:23Z
Stage: 3 wave 1
Base: 721168a8 (origin/dev)
Next: (2026-10-23T16:34:40Z) LC-a #4879 open at df5c4fa (fast-lane); LC-u and LC-m builders stacked on feat/library-lc-a; LC-z after both.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LC-a | copy plan, remove and relink rules and specs as stubs, checks written and disabled | LC-1, LC-2 | MJ-LC | cull-finish:DR-m (contract-first met) | no | 0 | #4879 open (fast-lane) | – | – |
| LC-u | import options, Remove from Catalog, missing badge on stubs, render budget | LC-3, LC-4 | LJ-LC | LC-a | yes | 0 | building (wave 2, stacked on #4879) | – | – |
| LC-m | copy on import, remove and relink bodies and commands | LC-5, LC-6 | MJ-LC | LC-a; metadata-more:MD-a, file-flow:LF-m (contract-first met) | no | 0 | building (wave 2, stacked on #4879) | – | – |
| LC-z | live wiring, journeys and jobs on, built | LC-7, LC-8 | LJ-LC, MJ-LC | LC-u, LC-m | yes | 0 | queued | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LC-1 | LC-a | 1 | ImportCopyPlan, CatalogFileRules, specs stubs; tests disabled | ImportCopyPlan.swift, CatalogFileRules.swift, LibraryCatalogFiles+Kernel.swift, LibraryImport.swift, tests | compiles, disabled | #4879 | open at df5c4fa |
| LC-2 | LC-a | 1 | journey skipped, RJ-L50/51/52 jobs disabled | UITests/LibraryJourneyTests+Files.swift, Tests/RealJobs/library/* | – | #4879 | open at df5c4fa |
| LC-3 | LC-u | 2 | import options, remove, missing badge | LibraryApp files | ids | – | queued |
| LC-4 | LC-u | 2 | render budget | RenderBudgetLibraryFilesTests.swift | missingBadgeScroll | – | queued |
| LC-5 | LC-m | 2 | copy plan body, live importer | ImportCopyPlan.swift, LiveImporter.swift | ImportCopyTests | – | queued |
| LC-6 | LC-m | 2 | remove/relink bodies and commands | CatalogFileRules.swift, LibraryCommandCatalog.swift, ledger | CatalogRemoveTests, RelinkTests | – | queued |
| LC-7 | LC-z | 3 | live wiring, journeys and jobs on | – | LJ-LC | – | queued |
| LC-8 | LC-z | 4 | feature-done | catalog-files.wave.json | – | – | queued |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23: the brief says base main; CLAUDE.md and fast-lane.sh (BASE_BRANCH=dev; PRs on main are retargeted) say dev. Slice PRs base and target dev.
- 2026-10-23: rule 12 (#4814, contract-first): cull-finish DR-m, metadata-more MD-a and file-flow LF-m have first slices on dev, so the waits are met; Wire lines record the re-checks.

## Wire
- [ ] cull-finish:DR-m (14/17 on dev): LC-a builds on what DR-m has merged; re-check when DR-m is done.
- [ ] metadata-more:MD-a (#1555 open): LC-5 reads capture dates as they stand; re-check.
- [ ] file-flow:LF-m (7/8 on dev): LC-6 builds on the current ledger and catalog; re-check.

## Open
- 2026-10-23T15:31:23Z: started. Open findings for catalog-files: 0. Open PRs: 0.
- 2026-10-23T16:34:40Z: LC-a #4879 opened (df5c4fa, 14 files +399/-1, CI: PASS). LC-u and LC-m builders launched on it. Record mirrored to lead/library-catalog-files.
