# catalog-files lead record

Issue: #3786 · Packet: docs/blueprints/library/features/catalog-files.md
Run: act-1a1695ec091-ilfv · Started: 2026-10-23T15:31:23Z
Stage: 3 wave 3
Base: 721168a8 (origin/dev)
Next: (2026-10-23T17:39:52Z) #4879 LC-a, #4924 LC-u, #4937 LC-5, #4938 LC-6 wait on the lane; LC-z builder (LC-7, LC-8) running on lc-m6 + lc-u.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LC-a | copy plan, remove and relink rules and specs as stubs, checks written and disabled | LC-1, LC-2 | MJ-LC | cull-finish:DR-m (contract-first met) | no | 0 | #4879 open (fast-lane) | – | – |
| LC-u | import options, Remove from Catalog, missing badge on stubs, render budget | LC-3, LC-4 | LJ-LC | LC-a | yes | 0 | #4924 open at 006a476 (stacked on #4879) | – | – |
| LC-m | copy on import, remove and relink bodies and commands | LC-5, LC-6 | MJ-LC | LC-a; metadata-more:MD-a, file-flow:LF-m (contract-first met) | no | 0 | #4937 (LC-5) + #4938 (LC-6) open, stacked on #4879 | – | – |
| LC-z | live wiring, journeys and jobs on, built | LC-7, LC-8 | LJ-LC, MJ-LC | LC-u, LC-m | yes | 0 | building (wave 3, on lc-m6 + lc-u) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LC-1 | LC-a | 1 | ImportCopyPlan, CatalogFileRules, specs stubs; tests disabled | ImportCopyPlan.swift, CatalogFileRules.swift, LibraryCatalogFiles+Kernel.swift, LibraryImport.swift, tests | compiles, disabled | #4879 | open at df5c4fa |
| LC-2 | LC-a | 1 | journey skipped, RJ-L50/51/52 jobs disabled | UITests/LibraryJourneyTests+Files.swift, Tests/RealJobs/library/* | – | #4879 | open at df5c4fa |
| LC-3 | LC-u | 2 | import options, remove, missing badge | LibraryApp files | ids | #4924 | open at 006a476 |
| LC-4 | LC-u | 2 | render budget | RenderBudgetLibraryFilesTests.swift | missingBadgeScroll | #4924 | open at 006a476 |
| LC-5 | LC-m | 2 | copy plan body, live importer | ImportCopyPlan.swift, LiveImporter.swift | ImportCopyTests | #4937 | open at 5376128, Mutate 3/3 ImportCopyPlan |
| LC-6 | LC-m | 2 | remove/relink bodies and commands | CatalogFileRules.swift, LibraryCommandCatalog.swift, ledger | CatalogRemoveTests, RelinkTests | #4938 | open at 58cadbb, Mutate 2/2 CatalogFileRules |
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
- 2026-10-23T17:29:30Z: LC-u #4924 opened (006a476, 12 files +390, CI: PASS), base feat/library-lc-a. SuiteUI ask #4914 (grid cell badge + context menu). Open findings: 0.
- 2026-10-23T17:39:52Z: LC-m split over the 15-file cap: #4937 LC-5 (5376128, 9 files +188/-21) on lc-a, #4938 LC-6 (58cadbb, 11 files +178/-44) on lc-m5; both CI: PASS. LC-z builder launched. Open: relinked id keeps the old path; re-importing a folder with copy makes new copies (candidate gaps after LC-z).
- 2026-10-23T17:51:06Z: heartbeat: #4879,#4924,#4937,#4938 open, no needs-fix; dev Linux check 39997290881 (8a54f64) running; findings 0.
- 2026-10-23T18:07:23Z: LC-z PR #4949 opened (fast-lane, feature-done), base feat/library-lc-mu = merge of #4938 and #4924; retarget to dev after both merge. Mutate 3/3 LibraryModel.LibraryLaunch. RJ-L50/L52 pending #3741. UI not compiled yet (batch macOS gate). Next: all four slices built; wait for lane, then scoped library run and critics.
- 2026-10-23T18:15:01Z: heartbeat: #4879,#4924,#4937,#4938,#4949 open, clean, no needs-fix; dev Linux check 40000080882 (98589662) running; findings for this feature 0. PR bodies carry a server-added attribution footer that a PATCH cannot remove; the lane strips it from the squash commit.
- 2026-10-23T18:37:22Z: heartbeat: #4879,#4924,#4937,#4938,#4949 ready and clean; lane busy bisecting batch 20261023174522 (not ours), 60 ready PRs queued behind it. Nothing to fix.
- 2026-10-23T18:59:21Z: #4879 got needs-rebase (conflict in LibraryImport.swift with cull-finish DR-6). Merged origin/dev, kept both sides; gate running, then push and move Head:.
- 2026-10-23T19:23:23Z: #4879 integrated with dev at c131cf6383805ea79efebc2c743792d8be48e1b5 (CI: PASS), Head: moved. Stacked children still target the parent branch; retarget to dev once it merges.
- 2026-10-23T19:45:33Z: heartbeat: lane dropped needs-rebase; #4879,#4924,#4937,#4938,#4949 ready, waiting for a batch. No needs-fix, findings 0.
- 2026-10-23T20:07:26Z: heartbeat: #4879,#4924,#4937,#4938,#4949 ready and clean, waiting for a lane batch.
- 2026-10-23T20:29:20Z: heartbeat: #4879,#4924,#4937,#4938,#4949 ready and clean; lane bisecting another batch without them. Waiting.
- 2026-10-23T20:52:18Z: heartbeat: #4879,#4924,#4937,#4938,#4949 open, clean, unmerged; lane batch 20261023204921 in flight without them; scoped library run 40018964074 in progress at 61c481df; 27 open library findings, so no new feature task (none left to start).
- 2026-10-23T21:13:50Z: heartbeat: #4879,#4924,#4937,#4938,#4949 unchanged (open, clean); lane batch 20261023204921 still in flight; scoped library run 40018964074 in progress, dev CI 40024093736 queued at 61c481df.
