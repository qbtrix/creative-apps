# suite-harness lead record

Issue: #778 · Packet: docs/blueprints/suiteui/features/suite-harness.md (on branch `docs/suiteui-feature-packets` until the packet PR merges)
Run: act-1a13b7e0908-fybz · Session: claude/suite-harness-lead-wwxtgn · Started: 2026-10-14T18:00Z
Stage: 3 wave 1
Base: 52928d1dbbdd72b849f7fdb6363991f35b1adbeb
Next: wait for wave 1 PRs (SH-1, SH-2), then lane merge; workflow run wf_14cd7949-cae

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| SH-1 | 1 | contract types, EditRun, probe/inventory/golden contracts + Fakes (#773) | Sources/SuiteUI/Contracts/{ContractTypes,FrameProbeRecording,ControlInventorying,GoldenComparing}.swift, Tests/SuiteUITests/{EditRunTests,HarnessFakeTests}.swift | EditRunTests, HarnessFakeTests | | todo |
| SH-2 | 1 | token sheet for waves 2-4 + contrast pairs (#774) | Sources/SuiteUI/Tokens.swift, Tests/SuiteUITests/TokensTests.swift | TokensTests.geometry, .contrast | | todo |
| SH-3 | 2 | secondary text 4.5:1 on light cards/panels (#283) | Tokens.swift, TokensTests.swift | TokensTests.contrast | | todo |
| SH-4 | 2 | SuiteFrameProbe + suite.perf publisher (#330) | Sources/SuiteUI/FrameProbe.swift, Tests/SuiteUITests/FrameProbeTests.swift | FrameProbeTests.referenceTable, .summaryWithinBudget | | todo |
| SH-9 | 2 | GoldenImage compare + recording rule (#331) | Tests/AppSnapshotTests/GoldenImage.swift, GoldenImageTests.swift, Golden/README.md | GoldenImageTests.reference, .compareWithinBudget | | todo |
| SH-5 | 3 | SuiteControlInventory, SuiteEnvironment, ToolbarAction.identifier (#775) | ControlInventory.swift, SuiteEnvironment.swift, ToolbarGroup.swift, EditorTopBar.swift, InspectorAction.swift, EmptyStateView.swift, ControlInventoryTests.swift | ControlInventoryTests | | todo |
| SH-10 | 3 | SnapshotHost at 2x in four appearances (#332) | Tests/AppSnapshotTests/SnapshotHost.swift, SnapshotHostTests.swift, Sources/SuiteUI/Glass.swift | SnapshotHostTests | | todo |
| SH-6 | 4 | gallery, index, six stubs, SuiteWindow hook (#776) | SuiteGallery.swift, Gallery/*.swift, SuiteWindow.swift, SuiteGalleryTests.swift | SuiteGalleryTests | | todo |
| SH-7 | 5 | journey template, SuiteJourneyTests bundle, helpers, SJ0, smoke, suiteui audit key (#333) | project.yml, UITests/Journey.swift, Journey+Input.swift, SuiteJourneyTests.swift, SuiteJourneyTests+Smoke.swift, audit-baseline.json | SJ0, smoke | | todo |
| SH-8 | 6 | SJ25 + journey budget constants (feature-done) | UITests/SuiteJourneyTests.swift, SuiteJourneyTests+Budgets.swift | SJ25 | | todo |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|

## Decisions
- Waves follow the packet's own chain: {SH-1,SH-2} → {SH-3,SH-4,SH-9} → {SH-5,SH-10} → SH-6 → SH-7 → SH-8.
- Packet PR is not open yet; builders read the packet and contracts from `origin/docs/suiteui-feature-packets`.
- Captain questions Q1/Q2/Q3/Q9 built as the packet assumes (its table).

## Open
- SH-7 edits `project.yml` (not on the protected list) — fine for the lane.
