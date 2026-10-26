# filters-collections lead record

Issue: #1563 · Packet: docs/blueprints/library/features/filters-collections.md
Run: act-1a147b718fd-n1ee · Session: unknown · Started: 2026-10-17T02:30Z
Stage: 3 wave 2 (FC-2 part 1 in review)
Base: 06371387 (origin/dev at setup; the brief's main 37d99630 is an ancestor, CLAUDE.md says dev)
Next: FC-2 part 2: stub the catalog methods and FilterBar/collection APIs, and add MJ1 disabled until FC-7 (rule 13); then FC-3

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
| FC-1 | FC-a | 1 | RatingRule and LibraryFilter value types: admits, title, matches, summary | Sources/LibraryModel/LibraryFilter.swift, Tests/LibraryModelTests/LibraryFilterTests.swift, Tests/mutations/LibraryModel.LibraryFilter.json | LibraryFilterTests (12 tests) | #1976 | merged to dev by the lane (268 lines, 5 files, macOS build green); mutate 11/11 |
| FC-2 | FC-a | 2 | stored filter and collection state, catalog methods with stub bodies, refreshShown | LibraryCatalog.swift, LibraryOrder.swift, LibraryCollections.swift | LibraryRefreshShownTests (part 1); MJ1 (LibraryCollectionsSeamTests) and the stubs are part 2 | (PR open, part 1) | part 1 in review: state, UserCollection, refreshShown; mutate 5/5; ci --changed PASS |
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
- 2026-10-26T03:13:58Z Heartbeat: UP-photo #5088, UP-flare #5089, UP-halo #5091, UP-z #5231 all fast-lane, no needs-fix, waiting on the lane batch.
- 2026-10-26T03:30:20Z Blocked on lane: dev-red #5321 (macos) is open, so no code batch forms. Bisect/triage name #5112 (reverted in #5349) and #5044, not ours. All 8 run PRs (#5040 #5088 #5089 #5091 #5231 #5244 #5263 #5266) are gated, fast-lane, no needs-fix/needs-rebase. Waiting; will not fix dev-red in our PRs.
- 2026-10-26T03:48:06Z Heartbeat: dev-red #5321 still open; dev unmoved; our 8 PRs clean (no needs-fix/needs-rebase). Waiting on the lane.
- 2026-10-26T04:08:24Z Check-in: dev-red #5321 still open; our 7 open PRs clean (no needs-fix/needs-rebase).
- 2026-10-26T04:27:32Z Check-in: dev-red #5321 still open (latest run red on linux, range to d0859e01, not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T04:46:45Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:07:56Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:27:48Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T05:48:49Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T06:19:47Z Check-in: dev-red #5321 still open (not ours); 7 open PRs clean, no needs-fix/needs-rebase.
- 2026-10-26T06:53:46Z Check-in: #5244 (OC-photo-m) merged 06:37 as 798f1f0a. Restacked #5263 (OC-photo-u) on dev: the dev merge put image.flip back in PhotoCatalog noMenu, fixed in 79ed59ec, gate PASS, Head moved. dev-red #5321 still open (not ours). 6 open PRs, none needs-fix or needs-rebase.
- 2026-10-26T07:18:31Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, #5263 head 79ed59ec unchanged; OC-photo-m waits on a green dev run.
- 2026-10-26T07:38:15Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T07:59:44Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T08:24:05Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T08:43:49Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:04:17Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:23:42Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T09:43:41Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
- 2026-10-26T10:04:38Z Check-in: dev-red #5321 still open (not ours); 6 open PRs clean, none merged; OC-photo-m waits on a green dev run.
