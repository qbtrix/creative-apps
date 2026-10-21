# key-editing lead record

Issue: #3536 · Packet: docs/blueprints/halo/features/key-editing.md
Run: act-1a15b98bcea-wygm · Session: claude/task-xjfhws · Started: 2026-10-20T23:47Z
Stage: 3 wave 2
Base: 2cc149f57 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: KE-1 merged (#3813, dbf599ff6). Open KE-2 (KE-a), KE-3 (KE-m), KE-4 (KE-m) once their ci --changed passes.

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
| KE-2 | KE-a | 2 | timeline clicks, Animation menu items, window wiring | Sources/HaloApp/HaloTimelineView.swift, Sources/HaloApp/HaloAnimationMenu.swift, Sources/HaloApp/HaloWindow+Easing.swift | HaloTimelineClickTests | - | built e0d17da91, PR after #3813 |
| KE-3 | KE-m | 2 | pick and select-all bodies | Sources/HaloModel/HaloKeyPick+Kernel.swift, Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift | HaloKeySelectionTests | - | built 9a254bd5c (mutate 10/10, 6/6), PR after #3813 |
| KE-4 | KE-m | 2 | moveKeys and endKeyDrag bodies, RJ move-keys | Sources/HaloModel/HaloKeyMove+Kernel.swift, Tests/HaloModelTests/HaloKeyEditingTests.swift, Tests/RealJobs/halo/move-keys/ | HaloKeyEditingTests, moveFiveThousandKeys | - | built 9d3544ed8; RJ-H13 held until KE-3 lands; PR after #3813 |
| KE-5 | KE-u | 3 | snapshots, journey skipped | see packet | snapshots | - | planned |
| KE-6 | KE-u | 3 | render budget | see packet | RenderBudgetHaloKeyEditingTests | - | planned |
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

## Open
- none
