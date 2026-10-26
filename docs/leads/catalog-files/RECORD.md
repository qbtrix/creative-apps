# catalog-files lead record

Issue: #3786 · Packet: docs/blueprints/library/features/catalog-files.md
Run: act-1a175fe2de5-qdc7 · Started: 2026-10-23T15:31:23Z (this run 2026-10-26T02:20Z)
Stage: 3 polling
Base: 8987427d (origin/dev); main d3323f6a
Next: wait for the lane to land #4924 (LC-u) and #4937 (LC-5); then merge origin/dev into feat/library-lc-m6, retarget #4938 to dev, rerun scripts/ci --changed, move Head:; same for #4949 (LC-z) once #4938 and #4924 merge.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LC-a | copy plan, remove and relink rules and specs as stubs, checks written and disabled | LC-1, LC-2 | MJ-LC | cull-finish:DR-m (contract-first met) | no | 0 | done | 40129102226 | – |
| LC-u | import options, Remove from Catalog, missing badge on stubs, render budget | LC-3, LC-4 | LJ-LC | LC-a | yes | 0 | building: #4924 eligible, in lane queue | – | – |
| LC-m | copy on import, remove and relink bodies and commands | LC-5, LC-6 | MJ-LC | LC-a; metadata-more:MD-a, file-flow:LF-m (contract-first met) | no | 0 | building: #4937 eligible in lane queue; #4938 stacked on it | – | – |
| LC-z | live wiring, journeys and jobs on, built | LC-7, LC-8 | LJ-LC, MJ-LC | LC-u, LC-m | yes | 0 | building: #4949 stacked on lc-mu | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LC-1 | LC-a | 1 | ImportCopyPlan, CatalogFileRules, specs stubs; tests disabled | ImportCopyPlan.swift, CatalogFileRules.swift, LibraryCatalogFiles+Kernel.swift, LibraryImport.swift, tests | compiles, disabled | #4879 | merged 095e65e1 |
| LC-2 | LC-a | 1 | journey skipped, RJ-L50/51/52 jobs disabled | UITests/LibraryJourneyTests+Files.swift, Tests/RealJobs/library/* | – | #4879 | merged 095e65e1 |
| LC-3 | LC-u | 2 | import options, remove, missing badge | LibraryApp files | ids | #4924 | open at f1fc4a65, prescreen green, eligible |
| LC-4 | LC-u | 2 | render budget | RenderBudgetLibraryFilesTests.swift | missingBadgeScroll | #4924 | open at f1fc4a65 |
| LC-5 | LC-m | 2 | copy plan body, live importer | ImportCopyPlan.swift, LiveImporter.swift | ImportCopyTests | #4937 | open at 5adfdbfc, prescreen green, eligible; Mutate 3/3 |
| LC-6 | LC-m | 2 | remove/relink bodies and commands | CatalogFileRules.swift, LibraryCommandCatalog.swift, ledger | CatalogRemoveTests, RelinkTests | #4938 | open at e300c574, base lc-m5; Mutate 2/2 |
| LC-7 | LC-z | 3 | live wiring, journeys and jobs on | LibraryLaunch etc. | LJ-LC | #4949 | open at 650cc5ff, base lc-mu; Mutate 3/3 |
| LC-8 | LC-z | 3 | feature-done | catalog-files.wave.json | – | #4949 | open (folded into LC-7's PR) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23: the brief says base main; CLAUDE.md and fast-lane.sh (BASE_BRANCH=dev; PRs on main are retargeted) say dev. Slice PRs base and target dev.
- 2026-10-23: rule 12 (#4814, contract-first): cull-finish DR-m, metadata-more MD-a and file-flow LF-m have first slices on dev, so the waits are met; Wire lines record the re-checks.
- 2026-10-26: origin/main shares no history with the old lead branch (rewritten), so lead/catalog-files was rebuilt as origin/main plus this record and the timeline.
- 2026-10-26: #4938 and #4949 stay on their stacked bases until their parents squash-merge; retargeting now would carry the parents' diffs and break the 400/15 cap (as #4924 and #4937 did on 10-24).

## Wire
- [ ] cull-finish:DR-m (14/17 on dev): LC-a builds on what DR-m has merged; re-check when DR-m is done.
- [ ] metadata-more:MD-a: LC-5 reads capture dates as they stand; re-check.
- [ ] file-flow:LF-m (7/8 on dev): LC-6 builds on the current ledger and catalog; re-check.

## Open
- 2026-10-24T21:02:20Z: Belt-Slice-Done: LC-a on run 40129102226.
- 2026-10-26T02:20Z: run act-1a175fe2de5-qdc7 resumed. Lane (LANE_VERIFY_AFTER=1) lists #4924 and #4937 eligible (Fast-Check marker + local-ci/prescreen green) among 107 eligible PRs; batches of one at a time. dev-red #5321 (macOS, not ours) open. Open findings for catalog-files: 0.
- 2026-10-26T02:40Z: probe merge of origin/dev into feat/library-lc-m6 conflicts in LibraryCommandCatalog.swift, its test, library.txt and the list-commands golden: dev added image.* and crop.* (LibraryCropDocument.specs). Resolution when #4937 lands: keep both sides (catalogFileSpecs after LibraryCropDocument.specs order per dev, ids appended, golden regenerated sorted).
- Candidate gaps after LC-z: relinked id keeps the old path; re-importing a folder with copy makes new copies.
