# filters-collections lead record

Issue: #1563 · Packet: docs/blueprints/library/features/filters-collections.md
Run: act-1a147b718fd-n1ee · Session: unknown · Started: 2026-10-17T02:30Z
Stage: 3 wave 1 (FC-1 in review, FC-2 next)
Base: 06371387 (origin/dev at setup; the brief's main 37d99630 is an ancestor, CLAUDE.md says dev)
Next: FC-2 (contract slice) on LibraryCatalog.swift, LibraryOrder.swift and LibraryCollections.swift, with MJ1 disabled until FC-7 (rule 13)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FC-a | no-filter Library unchanged; contract, bar, sidebar section and menus exist disabled | FC-1, FC-2, FC-3, FC-4, FC-5 | MJ1 | cull, persist, thumbnails, import, status-and-layout, export | yes | 0 | building | - | - |
| FC-b | filter bar narrows by flag, rating, hide rejects; N of M; Clear Filter | FC-6, FC-7 | J13 | FC-a | no | 0 | building | - | - |
| FC-c | New Collection, add/remove/rename/delete as undo steps; sidebar drop | FC-8, FC-9, FC-10 | J14 | FC-a; S-L9 (FC-10) | yes | 0 | building | - | - |
| FC-d | smart collection from filter; rules edited as undo steps | FC-11, FC-12 | J15 | FC-a; FC-b (FC-12) | no | 0 | building | - | - |
| FC-e | collections, rules, filter and selection survive relaunch; damaged file set aside | FC-13, FC-14, FC-15, FC-16 | J16 | FC-a; FC-c; FC-b, FC-d (FC-16) | yes | 0 | building | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FC-1 | FC-a | 1 | RatingRule and LibraryFilter value types: admits, title, matches, summary | Sources/LibraryModel/LibraryFilter.swift, Tests/LibraryModelTests/LibraryFilterTests.swift, Tests/mutations/LibraryModel.LibraryFilter.json | LibraryFilterTests (12 tests) | #1976 | PR open, fast-lane; mutate 11/11; scripts/ci --changed PASS on 01ce599b |
| FC-2 | FC-a | 2 | stored filter and collection state, catalog methods with stub bodies, refreshShown | LibraryCatalog.swift, LibraryOrder.swift, LibraryCollections.swift | LibraryCollectionsSeamTests (MJ1) | - | planned |
| FC-3 | FC-a | 2 | undo steps for collection edits (CatalogHistory) | CatalogHistory.swift | LibraryCollectionsHistoryTests | - | planned |
| FC-4 | FC-a | 3 | menu, bar and area hooks, CollectionsStore stub (UI, macOS) | LibraryWindow+Filters.swift, Platform/CollectionsStore.swift | compiles on macOS only | - | planned |
| FC-5 | FC-a | 3 | mount bar, sidebar section, menu items (UI, macOS) | LibraryWindow.swift, LibraryCommands.swift, LibraryBrowser.swift | MJ1, FC-a snapshots | - | planned |
| FC-6 .. FC-16 | FC-b..FC-e | 4+ | see packet | see wave.json | see packet | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- Base is origin/dev, not main: CLAUDE.md says branch from dev and never target main. The brief named main, and its SHA is an ancestor of dev.
- FC-1 was made on the designated branch claude/filters-collections-lead-0jzcl8 (based on main), then cherry-picked onto this branch (711d58b4). The designated branch still has 8ecde8c1.
- No PR opened: nobody asked for one. FC-1 is not on dev until a PR merges.
- The Workflow templates (build-wave.js, critic-panel.js, fix-batch.js) were not run: the Workflow tool needs an explicit opt-in, and none was given. Builders and critics have not started.
- Swift 6.3.3 (CI's pin) is installed in the scratchpad, so Model tests and mutate run locally. macOS UI tasks can't compile here.

## Open
- S-L9 and S-L10 (SuiteUI issues from the packet) are not filed. FC-10 waits on S-L9.
- Feature issue #1563: not read or commented on; GitHub GraphQL returned 403 from the CLI.
- FC-2 is the shared spine: it adds stored state and stubs to LibraryCatalog.swift, which every later task reads. The packet's MJ1 seam test needs `shownItems` and `recount` changed, which is FC-7 behavior, so FC-2 can't finish its own test without a decision. Asked below.
- Questions for the supervisor: (1) open FC-1 as a fast-lane PR now, or wait for FC-2? (2) may builders and critics run as Workflow fan-outs, given the opt-in rule? (3) file the S-L9/S-L10 issues on this repo? (4) for FC-2: may the MJ1 seam test go in as a disabled `@Test(.disabled("waits on FC-7"))` until FC-7 lands, as contract rule 13 allows?
