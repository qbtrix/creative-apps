# key-editing lead record

Issue: #3536 · Packet: docs/blueprints/halo/features/key-editing.md
Run: act-1a15f807d0b-78hh (resumed from act-1a15b98bcea-wygm) · Session: claude/key-editing-lead-o3yyj5 · Started: 2026-10-20T23:47Z
Stage: 3 wave 4
Base: 1a7e0d866 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: #4141 (KE-9) merges on the next sweep (macOS build 39647703725 green); then KE-m Belt-Slice-Done on a green Linux run holding it. Finding #4150 (KE-u macOS tests red) in fix round 1 (branch lead/halo-key-editing-F4150). KE-a/KE-u critic panel on journeys run 39651139451 (after scoped halo 39635764704) once its ui-screens land. KE-7 waits on #3499; KE-8 on core-loop CL-z.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| KE-a | four key commands, catalog ids, adapter stubs; timeline picks, drags, Select All Keys | KE-1, KE-2 | MJ-KE | AC-halo, TSA-a (met) | yes | 0 | done | 39632745681 | wanted |
| KE-u | snapshots, journey (skipped), render budget | KE-5, KE-6, F4150 | HJ-K1 | KE-a | yes | 1 | done (per Belt brief); finding #4150 open | 39635764704 | wanted |
| KE-m | cross-layer picks, select all, move as one step or refuse whole | KE-3, KE-4, KE-9 | MJ-KE | KE-a | no | 0 | merged (RJ-H13 job owed: KE-9) | - | - |
| KE-z | journey live, stress perf; halo.md, built, feature-done | KE-9, KE-7, KE-8 | HJ-K1 | KE-u, KE-m; PR #3499 (KE-7); core-loop:CL-z (KE-8) | yes | 0 | building | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| KE-1 | KE-a | 1 | HaloCommand cases, catalog ids, adapter stubs | see packet | HaloCommandTests, HaloCommandCatalogTests | #3813 | merged |
| KE-2 | KE-a | 2 | timeline clicks and drags, menus | Sources/HaloApp/HaloTimelineView.swift, Sources/HaloApp/HaloAnimationMenu.swift, Sources/HaloApp/HaloWindow+Easing.swift | HaloTimelineClickTests | #3954 | merged |
| KE-3 | KE-m | 2 | pick and select-all bodies | Sources/HaloModel/HaloKeyPick+Kernel.swift, Sources/HaloModel/HaloKeySelection.swift, Tests/HaloModelTests/HaloKeySelectionTests.swift | HaloKeySelectionTests | #3951 | merged |
| KE-4 | KE-m | 2 | move bodies, one step per drag | Sources/HaloModel/HaloKeyMove+Kernel.swift, Tests/HaloModelTests/HaloKeyEditingTests.swift | HaloKeyEditingTests | #3955 | merged |
| KE-5 | KE-u | 3 | snapshots, journey skipped | Tests/AppSnapshotTests/HaloKeyEditingSnapshots.swift, UITests/HaloJourneyTests+KeyEditing.swift | snapshots | #4070 | merged |
| KE-6 | KE-u | 3 | render budget | Tests/AppSnapshotTests/RenderBudgetHaloKeyEditingTests.swift | RenderBudgetHaloKeyEditingTests | #4067 | merged |
| KE-9 | KE-m, KE-z | 4 | RJ-H13 move-keys real job; journey turned on (KE-7's first half) | Tests/RealJobs/halo/move-keys/move-keys.jobs.json, Tests/RealJobs/halo/move-keys/input/bounce.halo, UITests/HaloJourneyTests+KeyEditing.swift | RealJobsTests, HaloKeyEditingJourneyTests | #4141 | in lane (head ddee6da1a) |
| KE-7 | KE-z | 5 | stress journey gains ⌘A and move-keys | UITests/HaloJourneyTests+StressPerf.swift | HaloStressPerfJourneyTests | - | waits #3499 |
| KE-8 | KE-z | 6 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/key-editing.wave.json | waves render --dry-run | - | waits CL-z |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.
- KE-a shipped as two PRs (KE-1 model, KE-2 view): together about 480 lines, over the 400 cap.
- The record lives on both lead/halo-key-editing (docs/leads/halo-key-editing/, the branch Belt watches) and lead/key-editing (docs/leads/key-editing/); every stage pushes both. The mirror here lapsed 13:42Z-18:31Z and was caught up from lead/key-editing.
- KE-7 split: turning the journey on needs only KE-3/KE-4/KE-5 (merged), not #3499, so it ships now with the RJ-H13 job (KE-9); the stress gestures stay in KE-7, waiting on #3499.
- KE-9 folds two sub-50-line changes into one PR (rule 22), Slice: KE-m, KE-z.
- KE-m's Slice-Done waits for the RJ-H13 job on dev (packet Done check), though rule 21 alone wouldn't gate on a missing check.

## Open
- Finding #4150: aKeyDragShowsTheTimePill red since #4070; RenderBudgetHaloKeyEditingTests drag 9 bodies and selectAll unrouted (scoped halo 39635764704). Fix round 1 started 18:30Z.
- HaloViewerSnapshots.shapeButton red on macOS too: not this feature's file.
- PR #3499 (stress journeys) open: KE-7 waits on it.
- core-loop #1971 CL-z not built: KE-8 waits on it.
- #4141 body: the session's GitHub proxy re-appends an attribution footer on every body write (tried to strip it 17:59Z; it came back). The lane strips it from the squash commit and holds nothing on it.
