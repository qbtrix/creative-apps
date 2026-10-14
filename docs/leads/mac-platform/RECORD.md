# mac-platform lead record

Issue: #754 · Packet: docs/blueprints/flare/features/mac-platform.md
Run: act-1a13b14336c-tqna · Session: claude/mac-platform-lead-7jx22z · Started: 2026-10-14T15:43Z
Stage: 4 round 1
Base: 5e1870dd5c64fe959238d708539ca45843accf95
Next: wait for the r1 fix PR (AutosaveTests.quitWritesWhenDirty, feature-done) to merge, then round 2 on the CI run it triggers

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| MP-1 | 1 | Open Recent: noteRecent(path), recentLimit 10, clearRecent | FlareFiles.swift, FlareRecentTests.swift, c4 flare-model-sources | FlareRecentTests | #757 | merged |
| MP-4 | 1 | StagePath: FlarePath+Matrix to CGPath (one addCurve per cubic), cgColor sRGB | Sources/FlareApp/StagePath.swift, Tests/AppSnapshotTests/StagePathTests.swift, c4 flare-app-sources | StagePathTests (macOS) | #756 | merged |
| MP-2 | 2 | autosaveDelay 30, autosaveDue(lastEdit:now:), recoveryData() | FlareFiles.swift, FlareAutosaveDueTests.swift, c4 flare-model-sources | FlareAutosaveDueTests | #759 | merged |
| MP-3 | 3 | restoreRecovery(_:); model journey steps 1-3 | FlareFiles.swift, FlareRecoveryRestoreTests.swift, MacPlatformJourneyTests.swift, c4 flare-model-sources | FlareRecoveryRestoreTests, MacPlatformJourneyTests | #760 | merged |
| MP-5 | 3 | RecoveryFile + autosave writer (poll, off-main atomic write, remove after save, quit write) | Sources/FlareApp/FlareAutosave.swift, Tests/AppSnapshotTests/AutosaveTests.swift, c4 flare-app-sources | AutosaveTests (macOS) | #761 | merged |
| MP-6 | 4 | Recovery on launch: read off main, decode, offer text, Restore, Discard, damaged removed (feature-done) | Sources/FlareApp/FlareAutosave.swift, Tests/AppSnapshotTests/AutosaveRecoveryTests.swift, c4 flare-app-sources | AutosaveRecoveryTests (macOS) | #762 | merged |

## Journeys (packet)
1. Open then save-as: noteRecent with each path, most recent first (MP-1)
2. Edit, wait 30 s: autosave due, recovery bytes decode to the edit (MP-2)
3. Restore: unsaved, untitled, dirty, Open Recent untouched (MP-3)
4. Writer writes off main; clean save removes the file (MP-5)
5. Next launch offers the recovery with its time; Restore / Discard (MP-6)
6. Ellipse as 4 cubics and pen path reach CG as one addCurve per cubic (MP-4)

## Quality bars
- No data loss: AutosaveTests.dueModelWritesRecovery, AutosaveRecoveryTests.restoreLandsTheDocument
- QB-V1: StagePathTests.cubicsStayCurves
- QB-L12 hook: AutosaveRecoveryTests.readsOffMain

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38600685744 (5e1870d) | red: macOS swift test, 1 of 1670 failed (AutosaveTests.quitWritesWhenDirty, 76 s vs 60 s window); Linux green; journeys not reached | not measured (journeys did not run) | none run: CI red, fix first | 1 (flaky time window in MP-5 test) | r1 fix PR | no |

## Decisions
- The packet's single chain MP-1..MP-6 exists only because every task edits docs/c4/model.json. MP-1..3 edit flare-model-sources (line 72), MP-4..6 edit flare-app-sources (line 52); 20 lines apart, so the two sub-chains merge cleanly. Real code deps: MP-5 needs MP-2 (autosaveDue, recoveryData), MP-6 needs MP-3 (restoreRecovery). Waves: 1 = MP-1 + MP-4, 2 = MP-2, 3 = MP-3 + MP-5, 4 = MP-6.
- gh CLI has no valid token in this session; builders open PRs and set labels through the GitHub MCP tools.

## Open
- Round 1 critic panel skipped: the run stopped at swift test, so no ui-screens or audit exist for this head.
- none
