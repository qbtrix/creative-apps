# editor-shell-removal lead record

Issue: #1529 · Packet: docs/blueprints/suiteui/features/editor-shell-removal.md
Run: act-1a1483c0771-g24c · Session: claude/task-52830u · Started: 2026-10-17T06:04Z
Stage: 0 setup
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: parked: the captain's comment on #1529 (2026-10-17 03:08 UTC) takes this feature out of the beta cut ("resumes after beta; finish the slice in flight, then stop") and nothing is in flight; a lead resumes at stage 1 when the supervisor says so

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| ER-1 | 1 | delete EditorShell, EditorTopBar family, `.rail`, their tests and the journey's old launch check | Sources/SuiteUI/EditorShell.swift (deleted), EditorTopBar.swift (deleted), ToolbarGroup.swift, SuiteEnvironment.swift and Tokens.swift (comments), Tests/AppSnapshotTests/SuiteEditorShellSnapshots.swift (deleted), SuiteEditorBarDimmingTests.swift (deleted), Tests/SuiteUITests/EditorShellTests.swift, UITests/Journey.swift | grep finds nothing outside DisabledDim.swift's comment; scripts/ci | – | parked |
| ER-2 | 2 | delete the five tokens; rewrite docs/design.md's Editor shell section; `feature-done` | Sources/SuiteUI/Tokens.swift, Tests/SuiteUITests/TokensTests.swift, docs/design.md | TokensTests; grep on docs/design.md | – | parked |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Parked, not started: the captain's issue comment postdates the feature issue and Belt's brief, and no PR or branch of this feature exists. The lead works editor-kernel (#1933, p1, beta) instead.
- Precondition grep (`grep -rn "EditorShell\|EditorTopBar\|EditorBar\|\.rail" Sources Tests UITests` on 4a86f5f) hits, for the lead that resumes: the packet's files plus two comment-only hits outside its list, `Sources/SuiteUI/SidebarActionRow.swift:4` ("the shape of an icon-only EditorBarItem") and `Tests/AppSnapshotTests/SuiteSidebarActionRowSnapshots.swift:7` (names SuiteEditorBarDimmingTests, "ER-1 deletes that file"), and the allowed `Tests/AppAuditTests/Checks/DisabledDim.swift:7`. The only `style:` call site is `FlareStage.swift:81` (`.floating`), so dropping `ToolbarGroup.Style` needs that one-line edit on Flare's line or a Flare-side follow-up. Both comment hits should be reworded by ER-1 (SidebarActionRow.swift is SuiteUI's) or recorded.

## Open
- Waits on the captain lifting the beta cut.
