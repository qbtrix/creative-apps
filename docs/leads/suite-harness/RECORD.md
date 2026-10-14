# suite-harness lead record

Issue: #778 · Packet: docs/blueprints/suiteui/features/suite-harness.md (on branch `docs/suiteui-feature-packets` until the packet PR merges)
Run: act-1a13b7e0908-fybz · Session: claude/suite-harness-lead-wwxtgn · Started: 2026-10-14T18:00Z
Stage: 3 wave 3 (SH-10 building; SH-5 waits on #867)
Base: 7c080729 (SH-10); SH-5 starts on the dev SHA that contains #867
Next: when #867 (SH-4) merges, start SH-5 on that dev SHA; wait for SH-10's PR (wf_390e2b07-a27); then wave 4 (SH-6)

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SH-1 | 1 | contract types, EditRun, probe/inventory/golden contracts + Fakes (#773) | Sources/SuiteUI/Contracts/{ContractTypes,FrameProbeRecording,ControlInventorying,GoldenComparing}.swift, Tests/SuiteUITests/{EditRunTests,HarnessFakeTests}.swift | EditRunTests, HarnessFakeTests | #787 | merged |
| SH-2 | 1 | token sheet for waves 2-4 + contrast pairs (#774) | Sources/SuiteUI/Tokens.swift, Tests/SuiteUITests/TokensTests.swift | TokensTests.geometry, .contrast | #786 | merged |
| SH-3 | 2 | secondary text 4.5:1 on light cards/panels (#283) | Tokens.swift, TokensTests.swift | TokensTests.contrast | #850 | merged |
| SH-4 | 2 | SuiteFrameProbe + suite.perf publisher (#330) | Sources/SuiteUI/FrameProbe.swift, Tests/SuiteUITests/FrameProbeTests.swift | FrameProbeTests.referenceTable, .summaryWithinBudget | #867 | open, gate pass @feab7cc |
| SH-9 | 2 | GoldenImage compare + recording rule (#331) | Tests/AppSnapshotTests/GoldenImage.swift, GoldenImageTests.swift, Golden/README.md | GoldenImageTests.reference, .compareWithinBudget | #866 | merged |
| SH-5 | 3 | SuiteControlInventory, SuiteEnvironment, ToolbarAction.identifier (#775) | ControlInventory.swift, SuiteEnvironment.swift, ToolbarGroup.swift, EditorTopBar.swift, InspectorAction.swift, EmptyStateView.swift, ControlInventoryTests.swift | ControlInventoryTests | | todo |
| SH-10 | 3 | SnapshotHost at 2x in four appearances (#332) | Tests/AppSnapshotTests/SnapshotHost.swift, SnapshotHostTests.swift, Sources/SuiteUI/Glass.swift | SnapshotHostTests | | building (wf_390e2b07-a27) |
| SH-6 | 4 | gallery, index, six stubs, SuiteWindow hook (#776) | SuiteGallery.swift, Gallery/*.swift, SuiteWindow.swift, SuiteGalleryTests.swift | SuiteGalleryTests | | todo |
| SH-7 | 5 | journey template, SuiteJourneyTests bundle, helpers, SJ0, smoke, suiteui audit key (#333) | project.yml, UITests/Journey.swift, Journey+Input.swift, SuiteJourneyTests.swift, SuiteJourneyTests+Smoke.swift, audit-baseline.json | SJ0, smoke | | todo |
| SH-8 | 6 | SJ25 + journey budget constants (feature-done) | UITests/SuiteJourneyTests.swift, SuiteJourneyTests+Budgets.swift | SJ25 | | todo |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
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
