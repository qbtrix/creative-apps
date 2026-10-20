# file-flow lead record

Issue: #3480 · Packet: docs/blueprints/suite/features/file-flow.md
Run: act-1a157b72668-0qpi · Session: claude/file-flow-lead-kfs51t · Started: 2026-10-20T05:12Z
Stage: 3 wave 1
Base: 6537a1a02f512db2df50d253384529f1b354b184
Next: build slice SF-a (SF-1 contract stubs and disabled suites, then SF-2 SuiteShell stubs and home drop) as one PR to dev

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SF-a | kernel drop rule and file commands as stubs; SuiteShell menu group, drop modifier, drag source, bridge on the fakes; home takes a drop; checks written, disabled | SF-1, SF-2 | – | targets, home, switching (all built) | yes | 0 | building | – | – |
| SF-u | drop highlight, Open Recent, Open In, drag source views within the render budget; journeys on | SF-3, SF-4 | SJ11, SJ14 | SF-a | yes | 0 | waiting | – | – |
| SF-m | DropPlan routing, file commands bodies, bridge live | SF-5, SF-6, SF-7 | KJ (DropRoutingTests, FileFlowCommandsTests) | SF-a | no | 0 | waiting | – | – |
| SF-z | live drop and drag, fake conforms (RJ-X43), feature built | SF-8, SF-9, SF-10 | SJ11, SJ14, RJ-X43 | SF-u, SF-m; suiteui export-pack XP-z (SF-9); afterglow-cli (built) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SF-1 | SF-a | 1 | DropPlan and FileFlowCommands stubs, suites disabled | Sources/SuiteKernel/Files/DropPlan.swift, Sources/SuiteKernel/Files/FileFlowCommands.swift, Tests/SuiteKernelTests/DropRoutingTests.swift, Tests/SuiteKernelTests/FileFlowCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-files.json | KernelShapeTests, suites compile disabled | – | building |
| SF-2 | SF-a | 1 | SuiteShell file contracts as stubs, home drop | Sources/SuiteShell/OpenInMenu.swift, Sources/SuiteShell/SuiteFileDrop.swift, Sources/SuiteShell/SuiteDragSource.swift, Sources/SuiteShell/SuiteDocumentsBridge.swift, Sources/AfterGlowApp/HomeWindow.swift, docs/c4/parts/creative-apps/suite-shell/shell-documents.json, UITests/SuiteJourneyTests+FileFlow.swift | journey skipped "waits on SF-4" | – | building |
| SF-5 | SF-m | 2 | DropPlan body | Sources/SuiteKernel/Files/DropPlan.swift, Tests/SuiteKernelTests/DropRoutingTests.swift, Tests/mutations/SuiteKernel.DropPlan.json | DropRoutingTests | – | waiting |
| SF-6 | SF-m | 2 | file commands bodies | Sources/SuiteKernel/Files/FileFlowCommands.swift, Tests/SuiteKernelTests/FileFlowCommandsTests.swift, Tests/mutations/SuiteKernel.FileFlowCommands.json | FileFlowCommandsTests | – | waiting |
| SF-7 | SF-m | 2 | bridge live | Sources/SuiteShell/SuiteDocumentsBridge.swift, Tests/AppSnapshotTests/SuiteDocumentsBridgeTests.swift | SuiteDocumentsBridgeTests (macOS) | – | waiting |
| SF-3 | SF-u | 2 | views | Sources/SuiteShell/OpenInMenu.swift, Sources/SuiteShell/SuiteFileDrop.swift, Sources/SuiteShell/SuiteDragSource.swift, Tests/AppSnapshotTests/SuiteFileFlowViewTests.swift | SuiteFileFlowViewTests | – | waiting |
| SF-4 | SF-u | 2 | snapshots, render budget, journey on | Tests/AppSnapshotTests/SuiteFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFileDropTests.swift, UITests/SuiteJourneyTests+FileFlow.swift | RenderBudgetFileDropTests, journeys | – | waiting |
| SF-8 | SF-z | 3 | live drop and drag | Sources/SuiteShell/SuiteFileDrop.swift, Sources/SuiteShell/SuiteDragSource.swift, Tests/AppSnapshotTests/SuiteFileDropLiveTests.swift | SuiteFileDropLiveTests | – | waiting |
| SF-9 | SF-z | 3 | fake conforms to FileFlowTarget | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Tests/SuiteKernelTests/FakeCanvasFileFlowTests.swift, Tests/mutations/SuiteKernel.FakeCanvasDocument.json, Tests/RealJobs/fake/file-flow/ | FakeCanvasFileFlowTests, RJ-X43 | – | blocked (XP-z) |
| SF-10 | SF-z | 3 | C4 parts, wave.json built, feature-done | docs/c4/parts/creative-apps/suite-kernel/kernel-files.json, docs/blueprints/suite/features/file-flow.wave.json | scripts/ci | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target are origin/dev (6537a1a0), not main: the brief names main, but main is 1655 commits behind dev, the packet exists only on dev, CLAUDE.md forbids targeting main and the lane retargets main PRs to dev.
- One PR per slice (SF-a, SF-m, SF-u, SF-z), first commit the failing or disabled test; SF-m and SF-u stack on SF-a.
- SF-9 waits cross-line on suiteui export-pack XP-z (planned) for FakeCanvasDocument.swift; SF-8 and SF-10 do not need it.

## Open
- SF-9 blocked: suiteui export-pack XP-z not merged (export-pack status planned).
