# key-editing lead record

Issue: #3536 · Packet: docs/blueprints/halo/features/key-editing.md
Run: act-1a15b98bcea-wygm · Session: claude/task-xjfhws · Started: 2026-10-20T23:47Z
Stage: 4 wave 3
Base: 2cc149f57 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: KE-4 #3955 lane sweep; KE-u PRs #4067 (KE-6), #4070 (KE-5) in lane. On merge: RJ-H13 follow-up, KE-m Slice-Done; KE-u critics on a scoped run, then Slice-Done. On needs-fix/needs-rebase: fix that PR.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| KE-a | four key commands with catalog ids and adapter stubs; timeline clicks route through pickLaneKeys | KE-1, KE-2 | - | AC-halo (merged), TSA-a (built) | yes | 0 | building | - | - |
| KE-u | snapshots and journey (skipped); render budget | KE-5, KE-6 | - | KE-a | yes | 0 | planned | - | - |
| KE-m | pick and select-all bodies; move as one undo step per drag, collision refuses whole | KE-3, KE-4 | - | KE-a | no | 0 | building | - | - |
| KE-z | journey live, stress perf; halo.md, built, feature-done | KE-7, KE-8 | HaloKeyEditingJourneyTests | KE-u, KE-m; core-loop:CL-z (KE-8), PR #3499 (KE-7) | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| KE-1 | KE-a | 1 | HaloCommand cases, catalog ids, adapter stubs, HaloKeyEditingTests disabled | Sources/HaloModel/HaloCommand.swift, Sources/HaloModel/Availability/HaloAvailability+Easing.swift, Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Sources/HaloModel/HaloKeyPick+Kernel.swift, Sources/HaloModel/HaloKeyMove+Kernel.swift, Tests/HaloModelTests/HaloKeyEditingTests.swift | HaloCommandTests, HaloCommandCatalogTests | #3813 | in lane (213 lines, 11 files, ci --changed PASS) |
| KE-2 | KE-a | 2 | timeline clicks, Animation menu items, window wiring | Sources/HaloApp/HaloTimelineView.swift, Sources/HaloApp/HaloAnimationMenu.swift, Sources/HaloApp/HaloWindow+Easing.swift | HaloTimelineClickTests | - | merged #3954 (12:15Z) |
| KE-3 | KE-m | 2 | pick and select-all bodies | Sources/HaloModel/HaloKeyPick+Kernel.swift, Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift | HaloKeySelectionTests | - | built 9a254bd5c (mutate 10/10, 6/6), PR after #3813 |
| KE-4 | KE-m | 2 | moveKeys and endKeyDrag bodies, RJ move-keys | Sources/HaloModel/HaloKeyMove+Kernel.swift, Tests/HaloModelTests/HaloKeyEditingTests.swift, Tests/RealJobs/halo/move-keys/ | HaloKeyEditingTests, moveFiveThousandKeys | - | PR #3955 head fb99be903 (merged dev for #4008: Linux check red on PhotoPlace CommandPathTests, not this diff); gate PASS; RJ-H13 follow-up after it lands |
| KE-5 | KE-u | 3 | snapshots, journey skipped | see packet | snapshots | - | PR #4070 head 5650f771b (2 files, 256 lines; 8 PNGs halo-timeline-keys-picked-across, -all-picked, -key-drag, halo-animation-menu-select-all, light+dark) |
| KE-6 | KE-u | 3 | render budget | see packet | RenderBudgetHaloKeyEditingTests | - | PR #4067 head b504f56cb (107 lines); asks supervisor to add RenderBudgetHaloKeyEditingTests/timing to perf-suites |
| KE-7 | KE-z | 4 | journey live, stress perf | see packet | journey | - | planned |
| KE-8 | KE-z | 5 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/key-editing.wave.json | waves render --dry-run | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Record lives on lead/halo-key-editing at docs/leads/halo-key-editing/, matching the other Halo leads' lead/halo-<feature> naming (lead/file-flow and lead/export-pack belong to other leads).
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.
- KE-a ships as two PRs (KE-1 model, KE-2 view): together they are about 480 lines, over the 400 cap.
- Belt reads lead/key-editing; that branch was free, so the record is mirrored there at docs/leads/key-editing/ (lead/halo-key-editing keeps the same file).
- Stacked slices open PRs only once their parent is on dev: a stacked PR against dev would count the parent's lines and break the 400 cap.
- Wave 3 starts once KE-a is on dev, not waiting on KE-m: the packet says KE-u waits only on KE-a (rule 18).

## Open
- none
