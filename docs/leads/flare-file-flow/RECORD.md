# file-flow (Flare) lead record

Issue: #3482 · Packet: docs/blueprints/flare/features/file-flow.md
Run: act-1a15d4ed024-1wsg · Session: claude/feature-lead-playbook-ahxuto · Started: 2026-10-21T02:26Z (line lead: gradient-fill #3419, file-flow #3482, export-pack #3481; resumed from act-1a15c47678d-i2ih)
Stage: 3 wave 1
Base: b64cbb8c (origin/dev)
Next: FL-1 is in the lane as #3843 (eligible, macOS build green). KS-a is open as #3921; FL-2 starts once svg-place PF-u (waits on KS-a) has merged, then FL-u (FL-5, FL-6) stacks on FL-a.

Loop: v3 (the packet has a `## Slices` table).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FL-a | SuiteDocumentHost and FileFlowTarget on stubs; .suiteApp, Open Recent, Open In and the drop on the fakes | FL-1, FL-2 | MFL | SF-a (on dev); svg-place:PF-u (FL-2) | yes | 0 | FL-1 in lane (#3843) | | |
| FL-u | menu and drop mark snapshots, render budget, journey written | FL-5, FL-6 | FLJ1 | FL-a | yes | 0 | waiting | | |
| FL-m | hand-offs accepted, old recents imported once, suite list, opens and saves noted | FL-3, FL-4 | MFL | FL-a; SF-5, SF-6, SF-7 (on dev); gradient-fill:FG-m; shape-tools:FS-m, stroke-style:FK-m, svg-place:PF-m (FL-3) | yes | 0 | waiting | | |
| FL-z | live drop, Open Recent, Open In; journey passes; built | FL-7, FL-8 | FLJ1 | FL-u, FL-m; SF-8; export-pack:FV-z; svg-place:PF-z | no | 0 | waiting | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FL-1 | FL-a | 1 | adapter as stubs, tests disabled | Sources/FlareModel/FlareFileFlow+Kernel.swift, Tests/FlareModelTests/FlareFileFlowTests.swift | compiles; FlareFileFlowTests disabled | – | #3843 3c7abf91, CI: PASS (--changed) |
| FL-2 | FL-a | 2 | .suiteApp, SuiteFileCommands, .suiteFileDrop | FlareApp.swift, FlareCommands.swift, FlareStage.swift | FlareFileFlowSnapshots.menu | – | waits svg-place:PF-u |

## Decisions
- 2026-10-21T07Z (act-1a15d4ed024-1wsg): resumed. FL-1 #3843 still open in the lane (head 3c7abf91); KS-a #3921 open.
- Belt watches lead/file-flow, which the suite file-flow lead (#3480) also uses for docs/leads/file-flow and docs/leads/suite-file-flow. This record lives at docs/leads/flare-file-flow/ on that branch so neither lead overwrites the other.
- PRs target dev (CLAUDE.md; the lane retargets main to dev), though the brief names main as the integration branch. Slice done is judged on a green run whose SHA is on main.
- The SF-a, SF-5, SF-6 and SF-7 types are on dev (DropPlan, FileFlowCommands, SuiteFileDrop, SuiteDocumentsBridge, SuiteAppModifier). PhotoFileFlow+Kernel.swift is the shape to copy (rule 20).
- FL-1 ships ahead of FL-2 as the first FL-a PR, because FL-2 shares FlareCommands.swift with svg-place PF-u and key-select-all KS-a, which are still planned.

## Open
- FL-2 waits on svg-place:PF-u, which waits on key-select-all KS-a (planned).
- FL-3 waits on gradient-fill:FG-m, shape-tools:FS-m, stroke-style:FK-m and svg-place:PF-m, all planned.
- FL-8 waits on export-pack:FV-z, which is blocked on shell-media.
- 2026-10-21T08:17Z: Supervisor running a Linux check for #3843. No FL task can start: FL-2 waits on svg-place PF-u (no PF PR open; PF-u waits on KS-a #3921); FL-m on FG-m and other m-slices.
- 2026-10-21T08:38Z: FL-1 #3843 merged 08:33Z. FL-2 (rest of FL-a) still waits on svg-place PF-u (no PF PR open; KS-a #3921 open).
- 2026-10-21T08:58Z: FL-2 still waits on svg-place PF-u (no PF PR open; KS-a #3921 open).
- 2026-10-21T09:18Z: FL-2 still waits on svg-place PF-u (no PF PR open; KS-a #3921 open).
- 2026-10-21T09:39Z: FL-2 still waits on svg-place PF-u (no PF PR open; KS-a #3921 open).
- 2026-10-21T10:00Z: FL-2 still waits on svg-place PF-u (no PF PR open; KS-a #3921 open).
- 10:20Z: Heartbeat: FL-2 still blocked on svg-place PF-u; no PF PRs open.
- 10:40Z: Heartbeat: FL-2 still blocked on svg-place PF-u; no PF PRs open.
- 11:00Z: Heartbeat: FL-2 still blocked on svg-place PF-u; no PF PRs open.
- 11:19Z: Heartbeat: FL-2 still blocked on svg-place PF-u; no PF PRs open.
- 11:40Z: FL-2 blocked on svg-place PF-u: no PF PRs open.
- 12:00Z: FL-2 blocked on svg-place PF-u: no PF PRs open.
- 12:26Z: FL-2 blocked on svg-place PF-u: no PF PRs open.
- 12:46Z: No svg-place PF PRs yet; FL-2 still blocked.
- 13:08Z: No svg-place PF PRs; FL-2 blocked.
- 13:28Z: No svg-place PF PRs; FL-2 blocked.
- 14:45Z: Records moved to lead/flare-file-flow. FL-2 still blocked: no svg-place PF PRs yet.
- 15:06Z: No svg-place PF PRs yet; FL-2 still blocked.
- 15:26Z: No svg-place PF PRs yet; FL-2 still blocked.
- 15:46Z: No svg-place PF PRs yet; FL-2 still blocked.
- 16:09Z: No svg-place PF PRs yet; FL-2 still blocked.
