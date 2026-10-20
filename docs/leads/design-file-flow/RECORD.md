# file-flow lead record

Issue: #3469 · Packet: docs/blueprints/design/features/file-flow.md
Run: act-1a15ac70747-ky1f · Session: line lead (design) · Started: 2026-10-20T19:27Z
Stage: 3 wave 1
Base: a48992b7c85ded3959e12683f50bd5fe7531b011
Next: DF-1 (adapter stubs + disabled DesignFileFlowTests, Model only) is building; DF-2 joins the slice once design-export (#3684), DA-a (#3686) and PD-u merge.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DF-a | SuiteDocumentHost and FileFlowTarget stubs; scene adopts .suiteApp; File menu and window use the suite's Open Recent, Open In and drop | DF-1, DF-2 | MDF | SF-a (merged #3488/#3489); design-export (#3684 open); DA-a (#3686 open); PD-u | yes | 0 | building | – | – |
| DF-u | menu and drop mark snapshots, render budget, journey written | DF-5, DF-6 | DFJ1 | DF-a | yes | 0 | waiting | – | – |
| DF-m | hand-offs, recents, Open In refusal, open/save notes, drag-out | DF-3, DF-4 | MDF | DF-a; SF-5, SF-6, SF-7; DG-m; DA-m; DT-m; DY-m; DS-m; DK-m; PD-m | yes | 0 | waiting | – | – |
| DF-z | live drop, Open Recent, Open In; feature built | DF-7, DF-8 | DFJ1 | DF-u, DF-m; DX-z; PD-z | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DF-1 | DF-a | 1 | adapter stubs, tests disabled | Sources/DesignModel/DesignFileFlow+Kernel.swift, Tests/DesignModelTests/DesignFileFlowTests.swift | compiles; DesignFileFlowTests disabled | – | building |
| DF-2 | DF-a | 2 | .suiteApp, SuiteFileCommands, .suiteFileDrop | Sources/DesignApp/DesignApp.swift, Sources/DesignApp/DesignCommands.swift, Sources/DesignApp/DesignWindow.swift | DesignFileFlowSnapshots.menu | – | waiting |
| DF-3 | DF-m | 3 | adapter bodies, specs, RJ-D42 | Sources/DesignModel/DesignFileFlow+Kernel.swift, Sources/DesignModel/DesignCommandCatalog.swift, Tests/command-ids/design.txt, Tests/DesignModelTests/DesignFileFlowTests.swift, Tests/mutations/DesignModel.DesignFileFlow+Kernel.json, Tests/RealJobs/design/open-recent/ | DesignFileFlowTests, RJ-D42 | – | waiting |
| DF-4 | DF-m | 3 | bridge notes, drag-out | Sources/DesignApp/DesignWindow+Files.swift, Sources/DesignApp/DesignPasteboardBridge.swift, Tests/AppSnapshotTests/DesignFileFlowLiveTests.swift | DesignFileFlowLiveTests | – | waiting |
| DF-5 | DF-u | 3 | snapshots, budget | Tests/AppSnapshotTests/DesignFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetDesignFileDropTests.swift | DesignFileFlowSnapshots | – | waiting |
| DF-6 | DF-u | 3 | journey skipped | UITests/DesignJourneyTests+FileFlow.swift | compiles, skipped | – | waiting |
| DF-7 | DF-z | 4 | journey on live | UITests/DesignJourneyTests+FileFlow.swift | testOpenRecentAndDrop | – | waiting |
| DF-8 | DF-z | 5 | design.md, status built | docs/blueprints/design.md, docs/blueprints/design/features/file-flow.wave.json | scripts/waves render --dry-run | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target dev (CLAUDE.md); brief's main HEAD b3011ab9 verified, work branches from origin/dev a48992b7.
- DF-1 starts now: its task row depends only on SF-a (merged), and it owns two new DesignModel files no other feature touches. The slice wait on design-export, DA-a and PD-u is for DF-2's DesignApp files, so DF-a ships as two PRs (DF-1 now, DF-2 when those merge) rather than idling (rules 12, 22).

## Open
- DF-2 waits on design-export (#3684 open), autosave-history DA-a (#3686 open) and placed-images PD-u.
