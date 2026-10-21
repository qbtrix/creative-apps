# folders lead record

Issue: #3787 · Packet: docs/blueprints/library/features/folders.md
Run: act-1a15d1c39b2-vvii · Session: cse_01Frm5sedPTzoQ8Smui9DRCb · Started: 2026-10-21T06:20:32Z
Stage: 3 wave 1
Base: 0865916d47ed5b21be2f827768d2aa92b7d200bb
Next: read wave 1 results (FO-a PR); then wave 2 stacks FO-u and FO-4 on it

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FO-a | tree and filter as stubs, checks disabled | FO-1, FO-2 | MJ-FO | – | no | 0 | building | – | – |
| FO-u | FOLDERS section on stubs, ids, render budget | FO-3, FO-3b | LJ-FO | FO-a; FC-a (merged) | yes | 0 | waits FO-a PR | – | – |
| FO-m | tree from paths, folder filter, commands | FO-4, FO-5 | MJ-FO | FO-a; FC-d, LF-m, LC-m (not merged) | no | 0 | FO-4 next wave; FO-5 blocked | – | – |
| FO-z | live, RJ-L53, built | FO-6, FO-7 | LJ-FO, MJ-FO | FO-u, FO-m | yes | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FO-1 | FO-a | 1 | FolderNode, tree stub, command specs NotBuilt, tests disabled | LibraryFolders.swift, LibraryFolders+Kernel.swift, LibraryFoldersTests.swift | compiles, disabled | – | building |
| FO-2 | FO-a | 1 | journey skipped, RJ-L53 disabled | UITests/LibraryJourneyTests+Folders.swift, Tests/RealJobs/library/browse-folders/ | scripts/jobs check | – | building (same PR) |
| FO-3 | FO-u | 2 | FOLDERS section | LibraryBrowser.swift, LibraryFoldersSection.swift | ids, menu toggles | – | planned |
| FO-3b | FO-u | 2 | render budget | RenderBudgetLibraryFoldersTests.swift | expandFolderInTwoBodies | – | planned |
| FO-4 | FO-m | 2 | tree body | LibraryFolders.swift, LibraryFoldersTests.swift, Tests/mutations/LibraryModel.LibraryFolders.json | LibraryFoldersTests | – | planned |
| FO-5 | FO-m | – | filter case, command bodies | LibraryFilter.swift, LibraryFolders+Kernel.swift, LibraryCommandCatalog.swift, ... | LibraryFoldersTests.filter | – | blocked: FC-d, LF-m, LC-m |
| FO-6 | FO-z | – | live | ... | LJ-FO | – | blocked |
| FO-7 | FO-z | – | feature-done | folders.wave.json | – | – | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are dev, not main (packets live on dev; the lane merges into dev).
- FO-u's wait on filters-collections:FC-a is met (FC-2 #3424, FC-4 #3461, FC-5 #3466 merged).

## Open
- FO-5 waits on filters-collections:FC-d, file-flow:LF-m (LF-3 blocked) and catalog-files:LC-m; none merged.
