# filters-collections lead record

Issue: #1563 · Packet: docs/blueprints/library/features/filters-collections.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 3
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: FC-9 #3546 (draft on FC-8 #3490; FC-3 merged); FC-10 blocked on S-L9 #3411 (open); FC-15 #3539 (draft on FC-13 #3521); FC-12 #3551 (draft on FC-7 #3534 + FC-11 #3515; expect a conflict with FC-9 #3546 in LibraryCollections.swift and the seam test); FC-4 #3461 (head cad6bfe1) ready for the lane, waits on its macOS build; when #3461 merges un-draft #3466 (after a plain scripts/ci --changed on its head), then the FC-6, FC-8, FC-11, FC-13 drafts, then FC-7 #3534, FC-9 #3546

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FC-a | no-filter Library unchanged; contract, bar, sidebar section and menus exist disabled | FC-1, FC-2, FC-3, FC-4, FC-5 | MJ1 | cull, persist, thumbnails, import, status-and-layout, export (all on dev) | yes | 0 | building | - | - |
| FC-b | filter bar narrows by flag, rating, hide rejects; N of M; Clear Filter | FC-6, FC-7 | J13 | FC-a | no | 0 | planned | - | - |
| FC-c | New Collection, add/remove/rename/delete as undo steps; sidebar drop | FC-8, FC-9, FC-10 | J14 | FC-a; S-L9 #3411 (FC-10) | yes | 0 | planned | - | - |
| FC-d | smart collection from filter; rules edited as undo steps | FC-11, FC-12 | J15 | FC-a; FC-b (FC-12) | no | 0 | planned | - | - |
| FC-e | collections, rules, filter and selection survive relaunch; damaged file set aside | FC-13, FC-14, FC-15, FC-16 | J16 | FC-a; FC-c; FC-b, FC-d (FC-16) | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FC-1 | FC-a | done | RatingRule and LibraryFilter value types | Sources/LibraryModel/LibraryFilter.swift, Tests/LibraryModelTests/LibraryFilterTests.swift, Tests/mutations/LibraryModel.LibraryFilter.json | LibraryFilterTests | #1976 | merged |
| FC-2a | FC-a | done | stored filter/collection state, UserCollection, refreshShown | Sources/LibraryModel/LibraryCatalog.swift, Sources/LibraryModel/LibraryCollections.swift | LibraryRefreshShownTests | #1999 | merged |
| FC-2b | FC-a | 1 | contract: catalog method stubs, shownItems through activeFilter and user collections, recount rows, editCanReorder, LibraryEmptyCollection, MJ1 seam test, plans | Sources/LibraryModel/LibraryCatalog.swift, Sources/LibraryModel/LibraryOrder.swift, Sources/LibraryModel/LibraryCollections.swift, Sources/LibraryModel/LibraryFilter.swift, Sources/LibraryModel/LibraryEmptyCollection.swift, Tests/LibraryModelTests/LibraryCollectionsSeamTests.swift, Tests/mutations/LibraryModel.LibraryCatalog.json, Tests/mutations/LibraryModel.LibraryOrder.json | LibraryCollectionsSeamTests (MJ1) | #3424 | open, macOS build queued |
| FC-3 | FC-a | 1 | collection edits as undo steps on the kernel adapter (recordCollectionsEdit) | Sources/LibraryModel/LibraryUndoAdapter.swift, Tests/LibraryModelTests/LibraryCollectionsHistoryTests.swift, Tests/mutations/LibraryModel.LibraryCollectionsHistory.json | LibraryCollectionsHistoryTests | #3423 | merged 07:29Z |
| FC-4 | FC-a | 2 | menu, bar and area hooks; CollectionsStore stub (UI, macOS) | Sources/LibraryApp/LibraryWindow+Filters.swift, Sources/LibraryApp/Platform/CollectionsStore.swift | builds on macOS | #3461 | open, draft until #3424 merges (stacked) |
| FC-5 | FC-a | 3 | mount bar, sidebar section, menu items (UI, macOS) | Sources/LibraryApp/LibraryWindow.swift, Sources/LibraryApp/LibraryCommands.swift, Sources/LibraryApp/LibraryBrowser.swift | MJ1, FC-a snapshots | #3466 | open, draft until #3461 merges (stacked); gate ran against the FC-4 branch, so rerun against origin/dev before un-drafting |
| FC-6 | FC-b | 4 | filter checks, disabled until FC-7 | LibraryFilterBarTests, LibraryFilterBudgetTests, LibraryFilterSnapshots, LibraryJourneyTests+Filters | compiles, disabled | #3491 | draft, stacked on #3466 |
| FC-8 | FC-c | 4 | collections checks, disabled until FC-9 (J14 step 7: FC-10) | LibraryCollectionsTests, LibraryCollectionsBudgetTests, LibraryCollectionsSnapshots, LibraryJourneyTests+Collections | compiles, disabled | #3490 | draft (stacked on FC-5) |
| FC-11 | FC-d | 4 | smart collection checks, disabled until FC-12 | LibrarySmartCollectionTests, LibrarySmartSnapshots, LibraryJourneyTests+Smart | compiles, disabled | #3515 | draft, stacked on #3466 |
| FC-13 | FC-e | 4 | collections file checks, disabled until FC-14/FC-15 | LibraryCollectionsFileTests, LibraryCollectionsStoreTests, LibraryCollectionsNoticeSnapshots, LibraryJourneyTests+CollectionsFile | compiles, disabled | #3521 | draft, stacked on #3466 |
| FC-7 | FC-b | 5 | filter methods (not smart); unavailable = nil; enables FC-6 checks | Sources/LibraryModel/LibraryFilter.swift, Tests/mutations/LibraryModel.LibraryFilter.json, FC-6 four files | LibraryFilterBarTests enabled | #3534 | draft, stacked on #3491 |
| FC-9 | FC-c | 5 | new/add/remove/rename/delete, help; unavailable = nil; enables FC-8 checks but J14 step 7 | Sources/LibraryModel/LibraryCollections.swift, Tests/mutations/LibraryModel.LibraryCollections.json, FC-8 four files | LibraryCollectionsTests enabled | #3546 | draft on #3490 + #3423 |
| FC-15 | FC-e | 5 | CollectionsStore: folder, atomic write, writeNow, set aside; enables its store test | Sources/LibraryApp/Platform/CollectionsStore.swift, Tests/AppSnapshotTests/LibraryCollectionsStoreTests.swift | LibraryCollectionsStoreTests | #3539 | draft, stacked on #3521 |
| FC-12 | FC-d | 5 | newSmartCollection, smart rule edits as undo steps, smartUnavailable = nil | Sources/LibraryModel/LibraryFilter.swift (+LibraryCollections.swift, seam test one line each) | LibrarySmartCollectionTests enabled | #3551 | draft on #3534 + #3515 |
| FC-10, FC-14, FC-16 | FC-b, FC-e | 5+ | see packet | see packet task table | see packet | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- This run (act-1a15749e510-0ox5) resumes the earlier run's record. FC-1 (#1976) and FC-2 part 1 (#1999) are on dev.
- Base is origin/dev, and PRs target dev. CLAUDE.md says so, and the lane retargets main. The brief's main b3011ab9 is an ancestor of dev.
- I rebuilt lead/filters-collections from main b3011ab9, which addresses Belt's "595 commits behind" note.
- FC-3 now runs in wave 1, beside FC-2b, instead of after it. AU-library (#3384) moved CatalogHistory into LibraryUndoAdapter.swift. FC-3 needs only the stored userCollections state, which is on dev already, and its files are disjoint from FC-2b's.
- MJ1 asserts that the no-filter Library is unchanged, so it runs enabled in FC-2b. Any assertion that needs FC-7 behaviour is `@Test(.disabled("waits on FC-7"))` (rule 13).
- Builders run as Agent subagents with worktree isolation, at most 3 at once (the session's small-workflow guideline).
- The wave 1 PR bodies got the session's attribution footer, and the lane flagged it. I removed it from #3422, #3423 and #3424. Builder prompts now say: no footer.
- FC-4 and FC-5 together are about 550 lines, over the 400 cap, so FC-a ships as more than one PR. The cap wins over rule 22.
- Open PR #3396 (AD-l1) also edits the library-model-sources C4 part. The lane integrates any conflict.

- Stacked PRs stay draft until their parent merges. The lane skips drafts before its size check, so a stacked PR over the cap keeps its fast-lane label (scripts/fast-lane.sh: draft skip comes before the "too big" reason that drops the label).
- FC-5 (#3466) changed FC-4's LibraryWindow+Filters.swift: bar controls go through .libraryControl, and LibraryFiltersMenu takes activeFilter and selectedCollectionID. It adds six menu items to LibraryJourneyTests. It leaves out the Collections + button and filed needs-ui #3464. It redrew library-layout-1280/1440/1920.png. The No Matching Photos snapshot comes with FC-7.
- FC-8 (#3490): J14 step 1 doesn't check that All Photos is selected after undo, and step 6 doesn't check the All Photos selection. The Model tests cover both. Left out to stay under the line cap.
- FC-6 (#3491): J13 skips as a whole test, following the PerfExport journey's pattern. The three snapshot states are one test, to stay under the line cap. The PR body asks for LibraryFilterBudgetTests to be added to Tests/perf-suites.txt (protected, the supervisor's) before FC-7 enables it.
- FC-13 (#3521): golden JSON written from Linux JSONEncoder output for the planned records; FC-14 replaces it if real output differs. CollectionsStore.setAside() returns a path but tests pass the name collections.json.bad to failRestoreCollections(setAsideAs:); FC-14 and FC-15 must agree. Checks merged into fewer tests to stay at +399.
- FC-7 (#3534): own diff 7 files +71/-30, Mutate 17/17 LibraryModel.LibraryFilter. Also edited LibraryCollectionsSeamTests (FC-2's stub check expected unavailable filter methods; enabled theBarHidesRejectsThroughItsToggle). The packet's refreshShown-without-loupe mutation already lives in LibraryCollections.json, so FC-7 mutates setFilter's loupe check instead. Smart 'Edit Rules' left to FC-12; C4 prose left to FC-16.
- FC-15 (#3539): CollectionsStore mirrors CatalogStore (folder, atomic write, set aside). setAside() returns the full path ending collections.json.bad, so FC-14's notice must show only the file name. No mutation plan: app-target I/O, macOS only. J16 stays skipped until FC-14.
- FC-9 (#3546, head 547631b1): own diff 10 files +166/-45; Mutate 11/11 LibraryModel.LibraryCollections and 11/11 LibraryModel.KernelUndoAdapter. It edited FC-3's LibraryUndoAdapter (undo steps remember selectedBefore, so undoing a Delete reselects the collection) and FC-2's seam test (built actions no longer unavailable). J14 step 7 still waits on FC-10.

## Open
- #3520 asks the supervisor to list LibraryFilterBudgetTests, LibraryCollectionsBudgetTests (and the keyword/search suites, plus the load-flaky Catalog/Grid budget suites) in Tests/perf-suites.txt. Open.
- S-L9 #3411 (sidebar drop): FC-10 waits on it. S-L10 #3412 (isRenamable): nothing waits on it.
- Open line:library findings checked 2026-10-20T04:42:28Z: none in this feature's files. dev-red #3386 (macOS, range main..1b33afbb) predates these PRs; not ours.
- 06:04Z: the lane's macOS build-only runs are still queued (#3423 run 39366083753 and #3424 run 39366318428 since 03:47Z; #3460 run 39377907664 since 06:00Z). This is runner backlog, not these PRs. Building continues on stacked drafts.
- 06:26Z check-in: #3423, #3424, #3460 unmerged; their lane macOS build-only runs (39366083753, 39366318428, 39377907664) still queued. Open line:library findings: only #3453 (export fidelity, not this feature's files). Building ahead on stacked drafts.
- 06:48Z check-in: #3423, #3424, #3460 still unmerged; lane macOS builds still queued (39366083753 for 3h). No new findings since 06:20Z. Builders: FC-9, MD-19, MD-6.
- 06:57Z: #3423's lane macOS build 39366083753 succeeded; the lane merges it on its next sweep.

- 07:15Z check-in: #3423 and #3460 macOS builds green, not yet merged by the lane; #3424 build 39366318428 still queued (since 03:49Z). No new line:library findings in these features' files. Builders: MD-7, MD-10, FC-12; FC-10 blocked on S-L9 #3411.
- 07:29Z: FC-3 #3423 merged. No PR waited on it alone (FC-9 #3546 still waits on #3490, FC-12 carries FC-3 already). FC-a closes when FC-2b #3424 merges.
- 07:37Z check-in: #3423 and #3460 merged (07:29Z); #3424 lane macOS build 39366318428 still queued since 03:49Z (runner backlog). No new line:library findings. Builders: MD-8, MD-10, FC-12 in their gates; MD-7 #3548 drafted. Fixer for #3465/#3473 dev merge waits for a free slot.
- FC-12 (#3551, head b05e5828): 7 files +47/-27 over its merge base; Mutate 21/21 LibraryModel.LibraryFilter (4 new). newSmartCollection() saves the filter as smart-<n>, one undo step via FC-3; setFilter on a selected smart collection edits its rules as one "Edit Rules" step. Also sets smartUnavailable = nil in LibraryCollections.swift and updates the seam test expectation; both lines neighbour FC-9 edits, so the second of #3546/#3551 to merge gets a dev merge with that conflict. Help text for "smart collection selected" chosen by the builder.
- 07:59Z check-in: #3424 still open, mergeable clean; lane macOS build 39366318428 still queued (4h10m, runner backlog). No new line:library findings. Running: MD-10 (gate), MD-11 (building on MD-9), fixer for #3465/#3473. Drafts recorded: MD-8 #3550, FC-12 #3551.
- 08:21Z check-in: #3424 still open (clean; lane macOS build 39366318428 still queued). #3465 and #3473 ready, clean, waiting on their lane macOS builds. New line:library CI findings #3560-#3565 from dev run 39349878829 (develop, export, export presets, inspector-develop unlabeled button): other features' journeys, none in this feature's files. Running: MD-10, MD-11, MD-15.

- Check-in 2026-10-20T08:43Z: #3424, #3465, #3473 still open (clean, fast-lane); #3424 lane macOS build 39366318428 still queued since 03:49Z (macOS runner backlog). No merges to cascade. No new line:library findings since 08:15Z. Running builders: MD-10, MD-16, MD-17.
- Check-in 2026-10-20T09:05Z: no dev merges since 08:40Z; #3424 macOS build 39366318428 still queued (5h15m). #3424, #3465, #3473 open and clean. No new line:library findings. Running: MD-10, MD-16. MD-17 drafted (#3579).
- 09:28Z check-in: #3424 lane macOS build 39366318428 still queued (since 03:49Z); stack unchanged; no new findings.
- 09:41Z: #3424 FC-2b lane macOS build 39366318428 succeeded; PR clean, lane merges it on its next sweep. Then cascade per Next.
- 09:51Z check-in: #3424 FC-2b macOS build green, waiting on the lane's merge sweep. No new line:library findings in this feature's files (open ones are export journeys and #3565, not ours).
- 10:02Z: FC-2b #3424 merged to dev. Fixer merging dev into FC-4 #3461 and un-drafting. FC-a closes after FC-4 #3461 and FC-5 #3466 merge and a green library run.
- 10:10Z: FC-4 #3461 un-drafted, dev merged in without conflicts, head cad6bfe1, own diff 3 files +278/-1; gate pass (lints and build, no test scope).
