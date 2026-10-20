# filters-collections lead record

Issue: #1563 · Packet: docs/blueprints/library/features/filters-collections.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 2
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: the wave 2 builder (FC-4, stacked on FC-2b) opens its PR; then wave 3: FC-5, FC-6, FC-8 (FC-11, FC-13 after)

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
| FC-4 | FC-a | 2 | menu, bar and area hooks; CollectionsStore stub (UI, macOS) | Sources/LibraryApp/LibraryWindow+Filters.swift, Sources/LibraryApp/Platform/CollectionsStore.swift | builds on macOS | - | building (stacked on feat/library-fc2b-contract) |
| FC-5 | FC-a | 3 | mount bar, sidebar section, menu items (UI, macOS) | Sources/LibraryApp/LibraryWindow.swift, Sources/LibraryApp/LibraryCommands.swift, Sources/LibraryApp/LibraryBrowser.swift | MJ1, FC-a snapshots | - | planned |
| FC-6 .. FC-16 | FC-b..FC-e | 3+ | see packet | see packet task table | see packet | - | planned |

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

## Open
- S-L9 #3411 (sidebar drop): FC-10 waits on it. S-L10 #3412 (isRenamable): nothing waits on it.
- Open line:library findings: 4 (#3134, #3136, #3324, #3325), none in this feature's files.
