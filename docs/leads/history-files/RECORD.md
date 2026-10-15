# history-files lead record

Issue: #1037 · Packet: docs/blueprints/halo/features/history-files.md
Run: act-1a13e9a2037-pkqb · Session: claude/history-files-lead-j2c6lo · Started: 2026-10-15T08:08Z
Stage: 3 wave 3
Base: 064ca8d450d6402405174929223a2fcd1bdede5d
Next: wait for the build-wave workflow (HF-2, HF-3, HF-7, HF-9) PRs to merge, then wave 4 (HF-8, HF-10)

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| HF-1 | 1 | live history rules, LiveProjectHistory, fake wraps rules | Live/HaloHistoryRules, Live/LiveProjectHistory, Fakes/FakeProjectHistory, ProjectHistoryContractTests | ProjectHistoryContractTests [fake, live] | #1042 | merged |
| HF-4 | 1 | .halo envelope in Live/, LiveProjectFiles encode/unwrap, fake wraps it | Live/HaloFileEnvelope, Live/LiveProjectFiles, Fakes/FakeProjectFiles, ProjectFilesContractTests | ProjectFilesContractTests [fake, live] + roundTripEveryFixture | #1043 | merged |
| HF-5 | 2 | content validation + counter raising in live decode | Live/HaloFileValidation, Live/LiveProjectFiles, HaloFileValidationTests | HaloFileValidationTests | #1048 | merged |
| HF-6 | 2 | HaloFiles.swift: fileData, open/save state, recent, title, status | HaloFiles.swift, HaloFileTests | HaloFileTests | #1046 | merged |
| HF-2 | 3 | undo/redo/titles, HB-8 | HaloHistory.swift, HaloUndoTests, HaloHistoryBudgetTests | HaloUndoTests | | building |
| HF-3 | 3 | +History availability | Availability/+History, HaloHistoryCommandTests | HaloHistoryCommandTests | | building |
| HF-7 | 3 | +Files availability, HB-10 | Availability/+Files, HaloFilesCommandTests, HaloFilesBudgetTests | HaloFilesCommandTests, budgets | | building |
| HF-9 | 3 | saveTarget/fileName + app Save/Save As, title, halo.file | HaloFiles.swift, HaloSaveTargetTests, HaloDocumentType, HaloWindow+File | HaloSaveTargetTests | | building |
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
- HF-6: W0 HaloFileState.opening is a Bool, so the pending open rides at the head of file.recent until finishOpen; views must read project.recent, not file.recent (HF-10 / HaloFileMenu note).
- Wave 3 runs through docs/factory/workflows/build-wave.js (4 independent tasks), with branch names and PR-opening steps adapted.

## Open
- none
