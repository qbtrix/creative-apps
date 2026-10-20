# filters-collections lead record

Issue: #1563 · Packet: docs/blueprints/library/features/filters-collections.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 3
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: FC-13 builder opens a draft PR; FC-7 building (stacked on FC-6 #3491); then FC-9, FC-15 (wave 5); when #3424 merges un-draft #3461 (merge dev in first), then #3466 (after a plain scripts/ci --changed on its head), then the FC-6, FC-8, FC-11, FC-13 drafts, then FC-7

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
| FC-3 | FC-a | 1 | collection edits as undo steps on the kernel adapter (recordCollectionsEdit) | Sources/LibraryModel/LibraryUndoAdapter.swift, Tests/LibraryModelTests/LibraryCollectionsHistoryTests.swift, Tests/mutations/LibraryModel.LibraryCollectionsHistory.json | LibraryCollectionsHistoryTests | #3423 | open, macOS build queued |
| FC-4 | FC-a | 2 | menu, bar and area hooks; CollectionsStore stub (UI, macOS) | Sources/LibraryApp/LibraryWindow+Filters.swift, Sources/LibraryApp/Platform/CollectionsStore.swift | builds on macOS | #3461 | open, draft until #3424 merges (stacked) |
| FC-5 | FC-a | 3 | mount bar, sidebar section, menu items (UI, macOS) | Sources/LibraryApp/LibraryWindow.swift, Sources/LibraryApp/LibraryCommands.swift, Sources/LibraryApp/LibraryBrowser.swift | MJ1, FC-a snapshots | #3466 | open, draft until #3461 merges (stacked); gate ran against the FC-4 branch, so rerun against origin/dev before un-drafting |
| FC-6 | FC-b | 4 | filter checks, disabled until FC-7 | LibraryFilterBarTests, LibraryFilterBudgetTests, LibraryFilterSnapshots, LibraryJourneyTests+Filters | compiles, disabled | #3491 | draft, stacked on #3466 |
| FC-8 | FC-c | 4 | collections checks, disabled until FC-9 (J14 step 7: FC-10) | LibraryCollectionsTests, LibraryCollectionsBudgetTests, LibraryCollectionsSnapshots, LibraryJourneyTests+Collections | compiles, disabled | - | building (stacked on FC-5) |
| FC-11 | FC-d | 4 | smart collection checks, disabled until FC-12 | LibrarySmartCollectionTests, LibrarySmartSnapshots, LibraryJourneyTests+Smart | compiles, disabled | #3515 | draft, stacked on #3466 |
| FC-7 | FC-b | 5 | filter methods (not smart); unavailable = nil; enables FC-6 checks | Sources/LibraryModel/LibraryFilter.swift, Tests/mutations/LibraryModel.LibraryFilter.json, FC-6 four files | LibraryFilterBarTests enabled | - | building (stacked on FC-6) |
| FC-9, FC-10, FC-12, FC-14 .. FC-16 | FC-b..FC-e | 5+ | see packet | see packet task table | see packet | - | planned |

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

## Open
- #3520 asks the supervisor to list LibraryFilterBudgetTests, LibraryCollectionsBudgetTests (and the keyword/search suites, plus the load-flaky Catalog/Grid budget suites) in Tests/perf-suites.txt. Open.
- S-L9 #3411 (sidebar drop): FC-10 waits on it. S-L10 #3412 (isRenamable): nothing waits on it.
- Open line:library findings checked 2026-10-20T04:42:28Z: none in this feature's files. dev-red #3386 (macOS, range main..1b33afbb) predates these PRs; not ours.
