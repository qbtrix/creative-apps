# file-flow lead record

Issue: #3480 · Packet: docs/blueprints/suite/features/file-flow.md
Run: act-1a157b72668-0qpi · Session: claude/file-flow-lead-kfs51t · Started: 2026-10-20T05:12Z
Stage: 3 wave 2
Base: 6537a1a02f512db2df50d253384529f1b354b184
Next: SF-8 (live drop and Open In) stacked on SF-4; merge dev into the stacked branches once #3488 merges, then label them fast-lane

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SF-a | kernel drop rule and file commands as stubs; SuiteShell menu group, drop modifier, drag source, bridge on the fakes; home takes a drop; checks written, disabled | SF-1, SF-2 | – | targets, home, switching (all built) | yes | 0 | PR #3488 + #3489 | – | – |
| SF-u | drop highlight, Open Recent, Open In, drag source views within the render budget; journeys on | SF-3, SF-4 | SJ11, SJ14 | SF-a | yes | 0 | PRs #3514 (SF-3), #3522 (SF-4) | – | – |
| SF-m | DropPlan routing, file commands bodies, bridge live | SF-5, SF-6, SF-7 | KJ (DropRoutingTests, FileFlowCommandsTests) | SF-a | no | 0 | PR #3493 + #3507 | – | – |
| SF-z | live drop and drag, fake conforms (RJ-X43), feature built | SF-8, SF-9, SF-10 | SJ11, SJ14, RJ-X43 | SF-u, SF-m; suiteui export-pack XP-z (SF-9); afterglow-cli (built) | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SF-1 | SF-a | 1 | DropPlan and FileFlowCommands stubs, suites disabled | Sources/SuiteKernel/Files/DropPlan.swift, Sources/SuiteKernel/Files/FileFlowCommands.swift, Tests/SuiteKernelTests/DropRoutingTests.swift, Tests/SuiteKernelTests/FileFlowCommandsTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-files.json | KernelShapeTests, suites compile disabled | #3488 | PR open |
| SF-2 | SF-a | 1 | SuiteShell file contracts as stubs, home drop | Sources/SuiteShell/OpenInMenu.swift, Sources/SuiteShell/SuiteFileDrop.swift, Sources/SuiteShell/SuiteDragSource.swift, Sources/SuiteShell/SuiteDocumentsBridge.swift, Sources/AfterGlowApp/HomeWindow.swift, docs/c4/parts/creative-apps/suite-shell/shell-documents.json, UITests/AfterGlowJourneyTests+FileFlow.swift | journey skipped "waits on SF-4" | #3489 | PR open (stacked) |
| SF-5 | SF-m | 2 | DropPlan body | Sources/SuiteKernel/Files/DropPlan.swift, Tests/SuiteKernelTests/DropRoutingTests.swift, Tests/mutations/SuiteKernel.DropPlan.json | DropRoutingTests | #3493 | PR open (stacked on SF-1), Mutate 5/5 |
| SF-6 | SF-m | 2 | file commands bodies | Sources/SuiteKernel/Files/FileFlowCommands.swift, Tests/SuiteKernelTests/FileFlowCommandsTests.swift, Tests/mutations/SuiteKernel.FileFlowCommands.json | FileFlowCommandsTests | #3493 | PR open (stacked on SF-1), Mutate 4/4 |
| SF-7 | SF-m | 2 | bridge live | Sources/SuiteShell/SuiteDocumentsBridge.swift, Tests/AppSnapshotTests/SuiteDocumentsBridgeTests.swift | SuiteDocumentsBridgeTests (macOS) | #3507 | PR open (stacked on SF-2) |
| SF-3 | SF-u | 2 | views | Sources/SuiteShell/OpenInMenu.swift, Sources/SuiteShell/SuiteFileDrop.swift, Sources/SuiteShell/SuiteDragSource.swift, Tests/AppSnapshotTests/SuiteFileFlowViewTests.swift | SuiteFileFlowViewTests | – | PR #3514 |
| SF-4 | SF-u | 2 | snapshots, render budget, journey on | Tests/AppSnapshotTests/SuiteFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFileDropTests.swift, UITests/AfterGlowJourneyTests+FileFlow.swift | RenderBudgetFileDropTests, SuiteFileFlowSnapshots, journey | #3522 | PR open (stacked) |
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

- The journey lives in UITests/AfterGlowJourneyTests+FileFlow.swift (class SuiteFileFlowJourneyTests): SuiteHarness compiles only into the launcher's journey bundle; SuiteJourneyTests is SuiteUI's gallery bundle.
- The launcher keeps its own Open Recent (LauncherCommandsHome); SuiteFileCommands is for adopting apps, so File has no second Open Recent.
- SF-a split into two PRs (#3488 SF-1 302 lines, #3489 SF-2 239 lines, stacked on branch claude/file-flow-lead-kfs51t-sf2): together 539 lines, over the lane's 400 cap.
- SF-m ships as two PRs: #3493 (SF-5 + SF-6, kernel, on SF-1) and #3507 (SF-7, shell, on SF-2), since SF-7 needs SF-2's bridge.
- Own type in the drop rule is "this app is the only reader" (readers == [app]), so .png in Photo still places into an open document.
- SF-7 has no mutation plan: SuiteShell builds only on macOS and rule 14 covers Model code.
- The GitHub MCP appends an attribution footer on PR create; every PR body is rewritten with update_pull_request right after to drop it.
- Drop rule order: own type (owner == app) opens first, then place (document open and ext in places), then open if this app reads it, then hand off to the first reader, else refuse. The packet's test ownTypeOpensEvenWithADocumentOpen needs own type before place.
- SF-3: SuiteFileMenu is the value Open Recent and Open In show; SuiteFileCommands takes an optional open document (off with "Open a document first." without one, else the routing slot's sentence).
- SF-3: the drop modifier moved from dropDestination to onDrop(of:delegate:), since only DropDelegate sees the hovering files (DropSession carries no item data); the mark is planned once on enter and cleared on exit. Hover loading on macOS is proven only by SF-4's journey.
- SF-4: the mark is a SuiteDropHover (session counter drops stale plans; lingers 3 s after a drop so a refusal is read). The journey drags from a floating NSPanel in the test runner; whether the runner's synthesized drag starts a real drag session is unproven until the first scoped run.

- SF-8 (#3529): bridge.perform(_:host:) sends open/place to the app's SuiteDocumentHost and hand-offs to the reader; suiteFileDrop(host:) performs live; suiteDraggable writes every PasteboardCoding representation. Home keeps its handOff call (already live). SF-z still needs SF-9 (blocked) and SF-10.

## Open
- #3489, #3493, #3507, #3514, #3522, #3529 show combined diffs until #3488 (and #3489 for #3507) merge; then merge origin/dev into each branch, rerun the gate, move Head, add fast-lane. #3488's macOS build: actions run 39375669624.
- SF-9 blocked: suiteui export-pack XP-z not merged (export-pack status planned).
