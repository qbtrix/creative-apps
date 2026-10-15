# history-files lead record

Issue: #1037 · Packet: docs/blueprints/halo/features/history-files.md
Run: act-1a13e9a2037-pkqb · Session: claude/history-files-lead-j2c6lo · Started: 2026-10-15T08:08Z
Stage: 3 wave 2
Base: 62a857755d8d554b311bb2e056d8562b27dfea26
Next: wait for HF-5 and HF-6 PRs to merge, then start wave 3 (HF-2, HF-3, HF-7, HF-9)

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| HF-1 | 1 | live history rules, LiveProjectHistory, fake wraps rules | Live/HaloHistoryRules, Live/LiveProjectHistory, Fakes/FakeProjectHistory, ProjectHistoryContractTests | ProjectHistoryContractTests [fake, live] | #1042 | merged |
| HF-4 | 1 | .halo envelope in Live/, LiveProjectFiles encode/unwrap, fake wraps it | Live/HaloFileEnvelope, Live/LiveProjectFiles, Fakes/FakeProjectFiles, ProjectFilesContractTests | ProjectFilesContractTests [fake, live] + roundTripEveryFixture | #1043 | merged |
| HF-5 | 2 | content validation + counter raising in live decode | Live/HaloFileValidation, Live/LiveProjectFiles, HaloFileValidationTests | HaloFileValidationTests | | building |
| HF-6 | 2 | HaloFiles.swift: fileData, open/save state, recent, title, status | HaloFiles.swift, HaloFileTests | HaloFileTests | | building |
| HF-2 | 3 | undo/redo/titles, HB-8 | HaloHistory.swift, HaloUndoTests, HaloHistoryBudgetTests | HaloUndoTests | | waits HF-6 |
| HF-3 | 3 | +History availability | Availability/+History, HaloHistoryCommandTests | HaloHistoryCommandTests | | waits HF-6 |
| HF-7 | 3 | +Files availability, HB-10 | Availability/+Files, HaloFilesCommandTests, HaloFilesBudgetTests | HaloFilesCommandTests, budgets | | waits HF-6 |
| HF-9 | 3 | saveTarget/fileName + app Save/Save As, title, halo.file | HaloFiles.swift, HaloSaveTargetTests, HaloDocumentType, HaloWindow+File | HaloSaveTargetTests | | waits HF-6 |
| HF-8 | 4 | app routes .undo/.redo; Edit menu snapshot | HaloWindow+Edit, HaloEditMenuSnapshots | snapshot halo-edit-menu-* | | waits HF-2, HF-3 |
| HF-10 | 4 | app Open/Open Recent/-HaloOpenFile, progress, alerts, recent in UserDefaults | HaloWindow+File, HaloFileSnapshots | snapshots halo-opened-project-*, halo-file-opening-* | | waits HF-9 |
| HF-11 | 5 | journey H-J8 | UITests/HaloJourneyTests+History | H-J8 on dev CI | | waits HF-8 |
| HF-12 | 6 | journeys H-J10, H-J11 (feature-done) | UITests/HaloJourneyTests+Files, +FileErrors | H-J10, H-J11 on dev CI | | waits all |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Brief named base 1dcd1a6; origin/dev had moved one commit (92db316, a SuiteUI perf test, #1039) that is a descendant. Used 92db316.
- Waves taken from the packet unchanged; each wave's dependencies checked against the code (stubs for history and files exist as the packet says).
- Builder branches are lead/history-files-<id> (a ref under lead/history-files/ would collide with the lead branch).

- Builders write PR bodies to their own worktree path, and set the body with the GitHub MCP update_pull_request (gh api appended an attribution footer in wave 1; HF-1 fixed its body by hand).

## Open
- none
