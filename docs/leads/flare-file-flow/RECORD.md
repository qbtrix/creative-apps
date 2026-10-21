# file-flow (Flare) lead record

Issue: #3482 · Packet: docs/blueprints/flare/features/file-flow.md
Run: act-1a15c47678d-i2ih · Session: session_01KmedgAV8daBEtcQfR1LURr · Started: 2026-10-21T02:26Z (line lead: stage-edit #1514, file-flow #3482, export-pack #3481)
Stage: 3 wave 1
Base: 2ab0eb96 (origin/dev)
Next: FL-1 (adapter stubs and the disabled FlareFileFlowTests) building, then the FL-a slice PR. FL-2 starts once svg-place:PF-u has merged.

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FL-a | SuiteDocumentHost and FileFlowTarget on stubs; .suiteApp, Open Recent, Open In and the drop on the fakes | FL-1, FL-2 | MFL | SF-a (on dev); svg-place:PF-u (FL-2) | yes | 0 | building FL-1 | | |
| FL-u | menu and drop mark snapshots, render budget, journey written | FL-5, FL-6 | FLJ1 | FL-a | yes | 0 | waiting | | |
| FL-m | hand-offs accepted, old recents imported once, suite list, opens and saves noted | FL-3, FL-4 | MFL | FL-a; SF-5, SF-6, SF-7 (on dev); gradient-fill:FG-m; shape-tools:FS-m, stroke-style:FK-m, svg-place:PF-m (FL-3) | yes | 0 | waiting | | |
| FL-z | live drop, Open Recent, Open In; journey passes; built | FL-7, FL-8 | FLJ1 | FL-u, FL-m; SF-8; export-pack:FV-z; svg-place:PF-z | no | 0 | waiting | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FL-1 | FL-a | 1 | adapter as stubs, tests disabled | Sources/FlareModel/FlareFileFlow+Kernel.swift, Tests/FlareModelTests/FlareFileFlowTests.swift | compiles; FlareFileFlowTests disabled | – | building |
| FL-2 | FL-a | 2 | .suiteApp, SuiteFileCommands, .suiteFileDrop | FlareApp.swift, FlareCommands.swift, FlareStage.swift | FlareFileFlowSnapshots.menu | – | waits svg-place:PF-u |

## Decisions
- Belt watches lead/file-flow, which the suite file-flow lead (#3480) also uses for docs/leads/file-flow and docs/leads/suite-file-flow. This record lives at docs/leads/flare-file-flow/ on that branch so neither lead overwrites the other.
- PRs target dev (CLAUDE.md; the lane retargets main to dev), though the brief names main as the integration branch. Slice done is judged on a green run whose SHA is on main.
- The SF-a, SF-5, SF-6 and SF-7 types are on dev (DropPlan, FileFlowCommands, SuiteFileDrop, SuiteDocumentsBridge, SuiteAppModifier). PhotoFileFlow+Kernel.swift is the shape to copy (rule 20).
- FL-1 ships ahead of FL-2 as the first FL-a PR, because FL-2 shares FlareCommands.swift with svg-place PF-u and key-select-all KS-a, which are still planned.

## Open
- FL-2 waits on svg-place:PF-u, which waits on key-select-all KS-a (planned).
- FL-3 waits on gradient-fill:FG-m, shape-tools:FS-m, stroke-style:FK-m and svg-place:PF-m, all planned.
- FL-8 waits on export-pack:FV-z, which is blocked on shell-media.
