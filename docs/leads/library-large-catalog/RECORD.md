# large-catalog lead record

Issue: #3790 · Packet: docs/blueprints/library/features/large-catalog.md
Run: act-1a16c627c84-u86z · Session: claude/large-catalog-lead-jhxt1n (earlier act-1a1693fbf6d-ap2g, act-1a15df37b73-k199) · Started: 2026-10-21T10:19Z (resumed 2026-10-23T14:20Z, 2026-10-24T05:10Z)
Stage: 3 wave 3 (LG-grid: LG-6 #5042 and LG-5 #5050 open)
Base: 8021b0f56a45a59540cd4ea0ff99651c5fb8dc2a (origin/dev)
Next: watch #5042 #5050 #5054 to merge and the supervisor to land #5114 (perf-suites); then LG-8 (status built, feature-done), then Belt-Slice-Done LG-grid

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LG-a | 10,000-photo fixture and every budget test, disabled | LG-1, LG-2 | MJ-LG | metadata-more:MD-a (met) | no | 1 | done #4006, fix #4073 (c5801375) | 39601343733 | - |
| LG-model | load off main with id index, IndexSet selection, one-pass export plan | LG-3, LG-4 | MJ-LG | LG-a; FC-a (met: filters-collections built), MD-e, DR-m (stubs, supervisor's answer b) | no | 0 | done (#4847, afb9cbed; run 40029034328) | - | - |
| LG-grid | grid and loupe within budget, jobs, built | LG-5..LG-8 | LJ-LG, MJ-LG | LG-model; suiteui shared-thumbnails ST-m; FC-c (met) | yes | 0 | building (LG-5, LG-6) | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LG-1 | LG-a | 1 | LibraryFixtures.large(count:folder:), budget tests disabled | LibraryLargeFixture.swift, LargeCatalogBudgetTests.swift | LargeCatalogBudgetTests | #4006 | merged |
| LG-2 | LG-a | 1 | large journey (skipped), -LibraryLargeFixture flag, RJ-L56 folder | LibraryJourneyTests+Large.swift, LibraryLaunch.swift, large-catalog.jobs.json | launch flag test, scripts/jobs check | #4006 | merged |
| LG-3 | LG-model | 2 | direct select all, cheap can-export check | LibrarySelectionAdapter.swift, LibraryActions.swift, LibraryExport.swift, LargeCatalogEquivalenceTests.swift, mutations | LargeCatalogEquivalenceTests | #4847 | merged |
| LG-4 | LG-model | 2 | one-pass export names (stems parsed once, one taken set) | Contracts/ExportNaming+Kernel.swift, Live/LiveExporter.swift, LargeCatalogEquivalenceTests.swift, mutations | LargeCatalogEquivalenceTests | #4847 | merged |
| LG-5 | LG-grid | 3 | visible-first pass, two screens prefetched nearest first, off-window requests cancelled (decode stops), photo lookup by id | LibraryThumbnails.swift, LibraryWindow+Thumbnails.swift, Live/LiveThumbnails.swift, LibraryThumbnailPrefetchTests.swift, mutations | LibraryThumbnailPrefetchTests, aCancelledRequestDecodesNothing | #5050 | open |
| LG-7 | LG-grid | 4 | RJ-L56 on the 10,000 fixture's .library (sha256 of the rated catalog), journey's skip dropped (RJ-L07) | large-catalog.jobs.json, input/large.library, LibraryJourneyTests+Large.swift | RealJobsTests (RJ-L56) | – | #5054 open |
| LG-6 | LG-grid | 3 | loupe neighbours decode behind the render, superseded step's dropped | RenderQueue.swift, LibraryWindow+Loupe.swift, LibraryRenderQueueAheadTests.swift, mutations | LibraryRenderQueueAheadTests | #5042 | open |

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
- LG-5 does not use ST-a: it is the grid's visible-range pass, cancellation and id lookup in LibraryThumbnailCache. The shared store's disk tier arrives with shared-thumbnails ST-6, so LG-5 goes from dev now (supervisor 6380369203: full capacity) without a `Wire:` line, on branch claude/large-catalog-lead-jhxt1n-lg5.
- LG-7: RJ-L07 already needs and closes with library/large-catalog in jobs.json (done in LG-a), so re-pointing means turning its journey on. RJ-L56 checks the catalog by sha256 (inline JSON would be 3 MB); its 1,000-photo export plan stays in LargeCatalogModelBudgetTests, since the PNG export waits on image-codecs. LargeCatalogModelBudgetTests stays .disabled until the supervisor lists it in Tests/perf-suites.txt (asked on #3790, comment 6380909327).
- LG-6 scope: neighbour prefetch already exists but runs beside the render, unbounded per step; LG-6 queues the neighbours behind the render in RenderQueue and drops a superseded step's pending decodes, so stale prefetches never evict the focus's decodes.

## Open
- 14:39Z: poll: #5042/#5050/#5054 still queued in lane (fast-lane, no needs-fix/needs-rebase); #5114 awaits supervisor; no answer yet on beta question (6384907277).
- 14:18Z: poll: no change; LG-grid PRs queued, #5114 awaits supervisor, no answer yet to the beta-priority question.
- 13:59Z: poll: no change; LG-grid PRs queued, #5114 awaits supervisor, no answer yet to the beta-priority question.
- 13:40Z: poll: LG-grid PRs still queued; lane idle since 12:18Z with 155 fast-lane PRs open, ours behind them. Asked the supervisor on #3790 whether the PRs should get beta priority. Removed the auto-added attribution footers from both #3790 comments.
- 13:20Z: poll: #5042/#5050/#5054 still queued in fast lane, no needs-fix/needs-rebase; #5114 awaits supervisor; #3790 unchanged.
- 13:00Z: poll: #5042/#5050/#5054 still queued in fast lane, no needs-fix/needs-rebase; #5114 awaits supervisor; #3790 unchanged.
- 12:41Z: poll: #5042/#5050/#5054 still queued (lane landed #4911 at 12:18, oldest first); #5114 awaits supervisor; #3790 unchanged.
- 12:21Z: poll: #5042/#5050/#5054 open, fast-lane, no needs-fix/needs-rebase; #5114 awaits supervisor; #3790 unchanged (17 comments).
- 12:01Z: poll: no change; #5042 #5050 #5054 queued, #5114 awaits supervisor; no new #3790 comments
- 11:42Z: poll: no change; #5042 #5050 #5054 queued, #5114 awaits supervisor; no new #3790 comments
- 11:24Z: poll: no change; #5042 #5050 #5054 queued, #5114 awaits supervisor; no new #3790 comments
- 11:06Z: poll: lane moving again (#4616 #5150 #4617 merged since 10:42); #5042 #5050 #5054 still queued, #5114 awaits supervisor; no new #3790 comments
- 10:49Z: poll: dev-red #5113 closed 10:38 (green dev run); lane should resume; #5042 #5050 #5054 #5114 still open, no needs-fix; no new #3790 comments
- 10:29Z: poll: no change; #5042 #5050 #5054 #5114 open; dev-red #5113 open, lane stalled; no new #3790 comments
- 10:09Z: poll: #5042 #5050 #5054 #5114 unchanged, open; dev-red #5113 open, lane stalled on batch 20261024081307 since ~08:30 (noted on #5113 for the supervisor); no new #3790 comments
- 09:47Z: poll: #5042 #5050 #5054 open queued (fast-lane), #5114 open awaiting supervisor; dev-red #5113 still open (lottie-oracle setup, not ours); no new #3790 comments
- 09:27Z: poll: dev-red #5113 still open (a second macOS run 40079902621 red, same range); #5042 #5050 #5054 #5114 open, no new labels or comments; #3790 nothing new
- 09:08Z: poll: dev-red #5113 open (macOS setup: lottie-oracle cache hit skips meson install, from #4132; .github/scripts fix for the supervisor, not ours); it holds macOS batch gates, so #5042 #5050 #5054 wait; #5114 open (no-fast-lane); #3790 nothing new
- 08:49Z: supervisor approved the perf-suites line (#3790 6382106137); opened #5114 (perf-suites line + drop .disabled, no-fast-lane, supervisor lands); #5042 #5050 #5054 still queued; no dev-red
- 08:23Z: poll: #5042 #5050 #5054 open, mergeable clean, in the lane queue (127 open fast-lane PRs); #3790 no supervisor answer; no open dev-red
- 08:04Z: poll: #5042 #5050 #5054 open (fast-lane, no needs-fix/rebase); #3790 no supervisor answer yet; no open dev-red; lane batch merged #4836..#5053 at 08:03Z
- 07:45Z: poll: #5042 #5050 #5054 open (fast-lane, no needs-fix/rebase); #3790 no supervisor answer yet; no open dev-red; lane merged #4132 at 07:43Z
- 2026-10-24T07:25Z: poll: #5042 #5050 #5054 still queued, no labels changed; no dev merges since 06:58Z (a batch in its gate); no dev-red; no supervisor answer yet.
- 2026-10-24T07:08Z: poll: #5042 #5050 #5054 still queued (lane landing older PRs, #4906..#4987 merged 06:58Z); no dev-red; no supervisor answer on perf-suites yet.
- 2026-10-24T06:49Z: poll: #5042 #5050 #5054 open, no needs-fix/needs-rebase, no open dev-red; supervisor has not answered the perf-suites line yet. Lane flagged AI attribution footers: removed from the three PR bodies and the #3790 question.
- 2026-10-24T06:31Z: LG-7 PR #5054 open (fast-lane, line:library; Fast-Check on 151645e4; 4 files +6/-20). #5042, #5050, #5054 wait for a batch.
- 2026-10-24T06:45Z: LG-7 built on claude/large-catalog-lead-jhxt1n-lg7 (RJ-L56 passes on Linux in 1.1 s debug); scripts/ci --changed running. #5042 and #5050 clean, waiting for a batch.
- 2026-10-24T06:30Z: #5050 opened (LG-5; 255+/21-, 6 files; CI: PASS on 5b84195d; Mutate 18/18). LibraryWindow+Thumbnails.swift and Live/LiveThumbnails.swift are outside the owned list.
- 2026-10-24T06:08Z: #5042 opened (LG-6; 187+/26-, 4 files; CI: PASS on 8c7721cf; Mutate 4/4). LibraryWindow+Loupe.swift is outside the owned list (one call site).
- 2026-10-23T23:17Z: LG-grid wait re-read: contract-first (supervisor 15:13Z) makes it met when ST-a #4840 merges; #4840 needs-fix since 19:15Z. Rule 23 question posted on #3790 proposing LG-6 (loupe, no thumbnail store) ahead of LG-5.
- 2026-10-23T15:53Z: #4847 opened (238 lines, 10 files; CI: PASS on 9f19aa0a; Mutate 17/17). Fixes #3213 #3214; Refs #3110 #1650 #4835.
- 2026-10-23T15:44Z: LG-model measured. Release, suite run in parallel: plan, load, shift-range, beginExport pass; select all 12.0 ms vs 5 ms on 10,000. Release alone (--no-parallel, best of 10): select all 5.0 ms, of which SuiteKernel Selection.unique is 4.6 ms (Set(order) is 1.4 ms). Kernel is line:suite: filed #4835 (needs-suite) for a fast path when ids are already unique. The timed suite LargeCatalogModelBudgetTests stays disabled until LG-7 lists it in perf-suites, so the gate does not depend on #4835. Debug before/after: plan 191 ms to under 50, beginExport 52.7 ms to under 10, select all 2.14 to 0.885 ms (1,000).
- Belt reads lead/library-large-catalog; this record is mirrored there at docs/leads/library-large-catalog/ from 2026-10-23T15:44Z on.
- LG-grid needs suiteui shared-thumbnails ST-m (wave file planned, no slice status on 2026-10-23); re-checked each heartbeat.
