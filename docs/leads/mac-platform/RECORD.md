# mac-platform lead record

Issue: #793 (resumes #754) · Packet: docs/blueprints/flare/features/mac-platform.md
Run: act-1a13c789856-0qa9 (first run act-1a13b14336c-tqna) · Session: claude/mac-platform-lead-lxlcta (first: claude/mac-platform-lead-7jx22z) · Started: 2026-10-14T15:43Z, resumed 2026-10-14T22:15Z
Stage: done, re-checking (round budget spent; waiting for a green dev CI run containing 190e45d)
Base: 1098ff2d6c135020391cef770f4de11dfde9465a
Next: watch dev CI runs 706 (1854d6c, in progress) and the one after #888 (96d1ede, Photo and golden budgets as medians). First green run containing 190e45d: edit the Belt-Contact-Sheet comment on #793 (id 6180953518) to point at it. No Flare change pending.

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
| 1 | 38600685744 (5e1870d) | red: macOS swift test, 1 of 1670 failed (AutosaveTests.quitWritesWhenDirty, 76 s vs 60 s window); Linux green; journeys not reached | not measured (journeys did not run) | none run: CI red, fix first | 1 (flaky time window in MP-5 test) | #764 | no |
| re-check | 38657968912 (62395be) | red outside: macOS SnapshotHostTests.appearances only (line:suiteui, #778 lead). Photo latency passed. Linux green. All mac-platform tests green | not measured | - | 0 in feature files | - | no (outside red) |
| 4 | 38654031210 (640d08d) | red outside: macOS PhotoBrushLatencyTests strokeStart 3.9 vs 3.0 ms (#851); GoldenImageTests p95, SnapshotHostTests, FrameProbeTests, ControlInventoryTests (line:suiteui, suite-harness #778). Linux green. All mac-platform tests green; journeys not reached | not measured (journeys did not run) | none: no ui-screens, feature changes no screen | 0 in feature files | - (outside: #851, #778 lead) | no (outside red); budget spent |
| 3b | 38647662189 (190e45d, #806 feature-done) | red outside: Linux PhotoBrushCopyCostTests mouse-up 19.36 vs 16 ms; macOS PhotoBrushLatencyTests strokeStart 3.9 vs 3.0 ms. All mac-platform tests green on both; journeys not reached | not measured (journeys did not run) | none: no ui-screens, feature changes no screen | 0 in feature files | gap #851 (line:photo) | no (outside red) |
| 3 | none yet (1098ff2) | Linux gate red locally: dev's FlareModel no longer builds against creative-core main 98be31a (key commands take owner: LayerOwner, new CommandError cases .invalidTransform, .emptyName) | - | none: build first | 1 (build break, line:flare) | #801 (merged 22:22Z) | no |
| 2 | 38602105363 (4594082) | red: macOS swift test, 1 of 1670 failed, PhotoBrushLatencyTests.aBrushDragEventBecomesAFrameWithinBudget (line:photo timing budget, 8.4 ms vs 3.0; 1.0 ms on the previous run). All mac-platform tests pass. Linux green; journeys not reached | not measured (journeys did not run) | none: no ui-screens, and this feature changes no screen | 0 in feature files | - | no (outside red) |

## Decisions
- Resume (#793): dev moved 4594082 -> 1098ff2 with docs/SuiteUI/Halo merges only, and no CI ran on it. The feature-done PR is a docs-only status update so the lane dispatches the CI run that judges the feature.
- The packet's single chain MP-1..MP-6 exists only because every task edits docs/c4/model.json. MP-1..3 edit flare-model-sources (line 72), MP-4..6 edit flare-app-sources (line 52); 20 lines apart, so the two sub-chains merge cleanly. Real code deps: MP-5 needs MP-2 (autosaveDue, recoveryData), MP-6 needs MP-3 (restoreRecovery). Waves: 1 = MP-1 + MP-4, 2 = MP-2, 3 = MP-3 + MP-5, 4 = MP-6.
- gh CLI has no valid token in this session; builders open PRs and set labels through the GitHub MCP tools.

## Open
- #851 (gap, p1, line:photo): Photo brush timing budgets fail dev CI on shared runners; blocks a green dev run for every feature.
- creative-core main moved under dev (Package.swift tracks branch main, Package.resolved is gitignored): fixed by #801. No one else had an issue or PR for it.
- Feature-done PR #806 (packet Status line, waves.md issue #793) opened 22:25Z on head e3c132f.
- dev-red #763: PhotoBrushLatencyTests budget (line:photo), triaged there; re-run of the failed job gave 403, so the feature waits on the next lane-dispatched CI run.
- Round 1 critic panel skipped: the run stopped at swift test, so no ui-screens or audit exist for this head.
- none
