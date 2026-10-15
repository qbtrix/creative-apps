# suite-harness lead record

Issue: #778 · Packet: docs/blueprints/suiteui/features/suite-harness.md (on branch `docs/suiteui-feature-packets` until the packet PR merges)
Run: act-1a13b7e0908-fybz · Session: claude/suite-harness-lead-wwxtgn · Started: 2026-10-14T18:00Z
Stage: 4 round 2
Base: 1854d6c0e4d082dc5564e5ad57e17b21909a6836 (round 2)
Next: wait for r2-b1's PR (feature-done) to merge; round 3 on the CI run it dispatches

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SH-1 | 1 | contract types, EditRun, probe/inventory/golden contracts + Fakes (#773) | Sources/SuiteUI/Contracts/{ContractTypes,FrameProbeRecording,ControlInventorying,GoldenComparing}.swift, Tests/SuiteUITests/{EditRunTests,HarnessFakeTests}.swift | EditRunTests, HarnessFakeTests | #787 | merged |
| SH-2 | 1 | token sheet for waves 2-4 + contrast pairs (#774) | Sources/SuiteUI/Tokens.swift, Tests/SuiteUITests/TokensTests.swift | TokensTests.geometry, .contrast | #786 | merged |
| SH-3 | 2 | secondary text 4.5:1 on light cards/panels (#283) | Tokens.swift, TokensTests.swift | TokensTests.contrast | #850 | merged |
| SH-4 | 2 | SuiteFrameProbe + suite.perf publisher (#330) | Sources/SuiteUI/FrameProbe.swift, Tests/SuiteUITests/FrameProbeTests.swift | FrameProbeTests.referenceTable, .summaryWithinBudget | #867 | merged |
| SH-9 | 2 | GoldenImage compare + recording rule (#331) | Tests/AppSnapshotTests/GoldenImage.swift, GoldenImageTests.swift, Golden/README.md | GoldenImageTests.reference, .compareWithinBudget | #866 | merged |
| SH-5 | 3 | SuiteControlInventory, SuiteEnvironment, ToolbarAction.identifier (#775) | ControlInventory.swift, SuiteEnvironment.swift, ToolbarGroup.swift, EditorTopBar.swift, InspectorAction.swift, EmptyStateView.swift, ControlInventoryTests.swift | ControlInventoryTests | #871 | merged |
| SH-10 | 3 | SnapshotHost at 2x in four appearances (#332) | Tests/AppSnapshotTests/SnapshotHost.swift, SnapshotHostTests.swift, Sources/SuiteUI/Glass.swift | SnapshotHostTests | #869 | merged |
| SH-6 | 4 | gallery, index, six stubs, SuiteWindow hook (#776) | SuiteGallery.swift, Gallery/*.swift, SuiteWindow.swift, SuiteGalleryTests.swift | SuiteGalleryTests | #875 | merged |
| SH-5b | 4 | snapshot of EmptyStateView with an unavailable action (follow-up to #871) | Tests/AppSnapshotTests/SuiteEmptyStateSnapshots.swift | the snapshot | #874 | merged |
| SH-7 | 5 | journey template, SuiteJourneyTests bundle, helpers, SJ0, smoke, suiteui audit key (#333) | project.yml, UITests/Journey.swift, Journey+Input.swift, SuiteJourneyTests.swift, SuiteJourneyTests+Smoke.swift, audit-baseline.json | SJ0, smoke | #877 | merged |
| SH-8 | 6 | SJ25 + journey budget constants (feature-done) | UITests/SuiteJourneyTests.swift, SuiteJourneyTests+Budgets.swift | SJ25 | #878 | merged |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 38654031210 @640d08d | red: macOS scripts/ci, 5 feature tests (FrameProbe budget, ControlInventory nested probes, SnapshotHost IC + glass, GoldenImage p95); Linux green | n/a: journeys didn't run | none (no ui-screens; CI-failure round) | 5 test failures | #881 #883 #884 #885 | no |
| 2 | 38658150595 @1854d6c | red: macOS SnapshotHostTests.appearances (light-ic, dark-ic) only; Photo latency passed; Linux green | n/a: journeys didn't run | none (no ui-screens) | 1 (IC hosts resolve plain tokens) | r2-b1 (wf pending), feature-done | no |

## Decisions
- Round 1: macOS scripts/ci failed before the UI journeys, so no ui-screens/audit exist; the round's findings are the feature's 5 failing tests, fixed in 4 disjoint batches. Critic panel runs once a run has screens.
- Fix PRs don't carry feature-done (four in parallel, unknown merge order); after all merge, one small feature-done PR dispatches the next CI.
- PhotoBrushLatencyTests keeps failing on dev (#763); not this feature's, it alone would keep the done run red.
- The lane runs scripts/fast-lane.sh from main (ee57a15, stuck since 10:14Z while dev is red), which dispatches CI only after a feature-done merge; dev's dispatch-on-UI-merge (#741) isn't live. So no CI ran for waves 2-5. SH-8 carries feature-done as planned, and its merge starts round 1's CI. Later rounds' fix batches carry feature-done on their last PR so each round gets a run.
- #871's checker found EmptyStateView's new disabled-action state had no snapshot; #871 had already merged, so SH-5b adds it in wave 4 (own file, disjoint from SH-6).
- PR bodies opened or edited through the GitHub MCP/proxy get a Claude Code footer re-appended server-side (#869 tried a REST PATCH; it came back). The lane's squash commits are clean, so not reworked.
- Wave 3 starts per task as its dependency merges: SH-10 needs only SH-9 (#866), SH-5 needs SH-4 (#867).
- FlareEasingDragCostTests.handleDragP95UnderBudget flaked twice under agent load (8.6-8.7 ms vs 5 ms); reruns passed. Watch on the macOS job.
- Waves follow the packet's own chain: {SH-1,SH-2} → {SH-3,SH-4,SH-9} → {SH-5,SH-10} → SH-6 → SH-7 → SH-8.
- Packet merged to dev in #788 after wave 1 started; wave 1 read it from `docs/suiteui-feature-packets`.
- The GitHub MCP server appends a Claude Code footer to PR bodies; the lane strips attribution from the squash commit (CLAUDE.md), so wave 1's #786/#787 merged with it. Noted, not reworked.
- Captain questions Q1/Q2/Q3/Q9 built as the packet assumes (its table).

## Open
- RESOLVED by #801: scripts/ci fails on dev 1098ff2 (Linux swift build): creative-core main changed keyframe commands to `owner: LayerOwner`; FlareModel fakes still pass `sceneID:`. line:flare, not ours. Reported on #763 (issuecomment-6179761284); builders commented on #283, #330, #331.
- Wave 2's first run (wf_6a181509-6c9) died in the 18:00Z usage pause with no branch or PR; relaunched as wf_c36a8d40-129 from base 1098ff2.
- Builder branches are `lead/suite-harness-<id>` (a `lead/suite-harness/<id>` ref can't coexist with the lead branch).
- SH-7 edits `project.yml` (not on the protected list) — fine for the lane.
