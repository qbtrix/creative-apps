# core-loop lead record

Issue: #1971 · Packet: docs/blueprints/halo/features/core-loop.md
Run: act-1a15f92d2f2-kvrn (from 2026-10-21T18:00Z; before: act-1a15d0eeefb-6z9l from 2026-10-21T05:40Z; before: act-1a15a9f4e8d-hav0) (from 2026-10-20T18:45Z; before: act-1a15728f2a2-zb1o) · Session: claude/halo-feature-lead-run-02scrb · Started: 2026-10-20T02:37Z
Stage: 3 wave 5
Base: 6d5f3a4025ffce3bb843003a158f64bf282020e6
Next: H-J12 panel (journeys 39705462811, 8d08e083) filed #4310 major, #4311-#4314 minor, gap #4315. Open fix PRs #4285 #4286 #4287 #4290 merged dev and passed the gate; waiting on the lane. Then: perf fixers #4274-#4277 after #4285+#4286; #4310-#4312 fixer after #4285+#4290; #4313-#4314 fixer after #4287. Blocked on SuiteUI: #4273 (#4283), #4281 (#4282). Open findings >5, no new feature work

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CL-a | the loop's checks and the HaloRenderJob+Kernel stubs exist before its code | CL-1, CL-2, CL-3 | MJ-CL1 | editor-kernel EK-a (merged, #1933) | false | 0 | merged (#3404, #3408) | | |
| CL-ui | Render… opens SuiteUI ExportSheet on the kernel run; render budget on | CL-4, CL-5 | H-J21 | CL-a | true | 0 | done: #3590 ui1 + #3653 ui2 merged; Belt-Slice-Done + Mac-Finish-Wanted at run 39507877855 (23:50Z) | | |
| CL-run | the render run is ExportRun<HaloRenderSettings>; availability from it | CL-6, CL-7 | – | CL-a | false | 0 | done: #3641, #3812, #3817 merged; Belt-Slice-Done https://github.com/qbtrix/creative-apps/actions/runs/39569221486 | | |
| CL-probe | under -SuitePerfProbe Halo's input sites record series into the window probe | CL-8, CL-9 | H-P1, H-P4 | CL-a; SuiteUI probe recorder #3401 (closed, #3981); key-editing:KE-a (done) | true | 0 | done: Belt-Slice-Done + Mac-Finish-Wanted (run 39670298178) | | |
| CL-measure | H-P1..H-P5 attach series, L3..L5 hold, latency line, journeys live | CL-10, CL-11, CL-12 | H-P1..H-P5 | CL-a; CL-probe (CL-10); switching A-HA-1 #865 (CL-12, open) | false | 0 | done: Belt-Slice-Done run 39682861406 (issuecomment-6328176308) | | |
| CL-z | H-J12 live; shared prose; feature-done | CL-13, CL-14 | H-J12 | CL-ui, CL-run, CL-probe, CL-measure | false | 0 | done: Belt-Slice-Done run 39682861406 (issuecomment-6328176568) | | |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CL-1 | CL-a | 1 | Linux walk of the whole loop on live services (render step disabled until CL-6) | Tests/HaloModelTests (walk) | the walk | #3408 | merged 97bd3f46 |
| CL-2 | CL-a | 1 | kernel-run tests (disabled) + HaloRenderJob+Kernel stubs | Sources/HaloModel/HaloRenderJob+Kernel.swift, tests | kernel-run tests | #3408 | merged 97bd3f46 |
| CL-3 | CL-a | 1 | perf journeys (XCTSkip), L3..L5 layout tests, latency scaffold, two render budget suites (disabled) | UITests/HaloJourneyTests+Perf.swift, Tests/AppSnapshotTests/HaloLayoutTests.swift, HaloViewerLatencyTests.swift, RenderBudgetHaloRenderTests.swift, RenderBudgetHaloProbeTests.swift | – (checks) | #3404 | merged 6537a1a0 |
| CL-4 | CL-ui | 2 | HaloRenderSheet presents SuiteExportSheet on renderRun | Sources/HaloApp/HaloRenderSheet.swift, HaloWindow+Render.swift | snapshots, H-J21 | | pushed 0229c007, PR waits on parents |
| CL-5 | CL-ui | 3 | RenderBudgetHaloRenderTests.bodies on | Tests/AppSnapshotTests/RenderBudgetHaloRenderTests.swift | bodies | | pushed 0229c007 (with CL-4) |
| CL-6 | CL-run | 2 | stored run state goes through ExportRun; old state machine deleted | Sources/HaloModel/HaloRenderJob*.swift | kernel-run tests (4 mutations) | | merged (#3641 run1a, #3812 run1b) |
| CL-7 | CL-run | 3 | render availability reads the kernel run | Sources/HaloModel/Availability (render) | availability tests (2 mutations) | | merged (#3817, 9265b982) |
| CL-8 | CL-probe | – | HaloProbe + input sites record | Sources/HaloApp/HaloProbe.swift + 5 views | CL-9/CL-10 oracles | #4147 | merged a2d1a8d |
| CL-9 | CL-probe | – | RenderBudgetHaloProbeTests.bodies on | Tests/AppSnapshotTests/RenderBudgetHaloProbeTests.swift | bodies | #4147 | merged a2d1a8d |
| CL-10 | CL-measure | – | H-P1..H-P5 journeys on | UITests/HaloJourneyTests+Perf.swift | perf journeys | #4166 | merged cbbb878 |
| CL-11 | CL-measure | 2 | L3..L5 and latency line on | Tests/AppSnapshotTests/HaloLayoutTests.swift, HaloViewerLatencyTests.swift | layout tests | | #3487 merged d9bc0337 |
| CL-12 | CL-measure | – | -HaloFixture → -HaloSample in six journeys | UITests/HaloJourneyTests*.swift | journeys | #4148 | merged 5803475 (with #865) |
| CL-13 | CL-z | – | H-J12 live | UITests/HaloJourneyTests.swift | H-J12 | #4167 | merged 4565e85 |
| CL-14 | CL-z | – | status built, waves.in.md, blueprint prose (feature-done) | core-loop.wave.json, waves.in.md, halo.md | scripts/ci | #4167 | merged 4565e85 (feature-done) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Waves
- W1: CL-a1 = CL-1+CL-2 (~380 lines, 3 files), CL-a2 = CL-3 (~300, 5). Independent: both (disjoint files, CL-3's suites need no CL-2 code).
- W2 (started at once, stacked): CL-run1 = CL-6 on CL-a1 (needs the stubs and the disabled tests); CL-ui = CL-4+CL-5 on CL-a1+CL-a2 (CL-4 needs the stubs, CL-5 the CL-3 suite); CL-11 on CL-a2 (enables CL-3's layout and latency tests).
- W3: CL-run2 = CL-7 on CL-run1 (reads the kernel run CL-6 fills).
- Merged: #4147 (CL-8, CL-9) a2d1a8d; #4148 (#865, CL-12) 5803475. Merged: #4166 (CL-10) cbbb878. Merged: #4167 (CL-13+CL-14, feature-done) 4565e85.

## Decisions
- The server also appends the footer to issue comments (Belt-Slice-Done on #1971) and puts it back after an edit; the trailer lines stay first and parse.
- The PR tool's server appends an attribution footer and puts it back after a body edit; the fast lane strips it from the squash commit (CLAUDE.md), so the lead leaves it.
- Run kvrn: #3401 closed (#3981) and KE-a is done, so CL-probe starts. Supervisor told the lead to take #865 (A-HA-1) on this line; it ships with CL-12 as one CL-measure PR (both edit HaloJourneyTests.swift). CL-10 is a second CL-measure PR stacked on CL-probe.
- Wave 5: CL-10 stacks on CL-probe; CL-z stacks on lead/core-loop-live (CL-13 needs CL-12, same file). CL-z is opened after CL-10 so the lane's oldest-first order lands feature-done last. Record stays on lead/core-loop per the supervisor, though Belt's nudge names lead/halo-core-loop.
- CL-run1 stacks on CL-ui as well as CL-a1: on its own it would break the macOS build (HaloWindow+Render, HaloRenderSheet, HaloRenderSheetSnapshots still call the deleted methods until CL-ui lands). Its PR opens after CL-ui merges.
- Stacked tasks check ancestry against their parent's base, not the wave base (CL-run1 stopped: 533daec not in CL-a1); relaunched on 25a8d9a2.
- CL-ui merged with dev came to 721 lines (HaloRenderSheet.swift deletion 205): split into CL-ui1 (HaloWindow+Render, snapshots; old sheet kept unused) and CL-ui2 (budget, journey, deletion, baselines), stacked.
- CL-a (~680 lines) and CL-run (~450) are over the 400-line cap as one PR each, so each ships as two stacked PRs (CL-a1/CL-a2, CL-run1/CL-run2); CL-ui is one PR (~380).
- Stacked branches are lead/core-loop-<id>; a stacked PR opens once its parent merged and dev is merged in, so the lane's size count is only its own diff.
- Packet's rule 20 search is done in the packet itself: export state is the kernel's ExportRun, the sheet is SuiteExportSheet, the run loop stays HaloRenderRules; no new concept.
- PRs target `dev`, not `main`: CLAUDE.md says never target main, and the lane retargets fast-lane PRs from main to dev. Base is origin/dev.
- Packet issue 3 (re-cut render-out RO-3/RO-8) is not filed: render-out is built (#1505), so CL-4 and CL-6 do the move as the packet says.
- Packet issue 2 narrowed: ExportSheet already has a host options slot (#1989), Reveal, and hides quality for a format without it; host-disabled Export is #3297. Only the verb (title and button "Render") is filed.

- The cloud's GitHub proxy re-appends a `_Generated by [Claude Code]_` footer to every PR body and comment write; it can't be removed from here. The lane strips it from the squash commit and never blocks on it (scripts/fast-lane.sh strip_attribution).

## Open
- Filed at stage 1: needs-ui #3401 (probe recorder), needs-ui #3402 (ExportSheet verb), finding #3403 (adopt-kernel-export has no Halo slice).
- CL-8 (and so CL-9, CL-10, CL-13, CL-14) waits on the SuiteUI probe recorder needs-ui.
- CL-12 (and so CL-13) waits on switching A-HA-1 #865 (open).
- Blocked (rule 19, run act-1a15d0eeefb-6z9l): CL-probe and CL-measure wait on #3401, CL-z on #865; both open with no PR. Said on #1971 with a question for the supervisor: https://github.com/qbtrix/creative-apps/issues/1971#issuecomment-6311966922
- CL-7 note: sheet close while editing uses dismissRender (CL-ui2 already routes act(.close) to cancelRender only while running); `renderRunning` was unused and is dropped in #3817.

- 22:43Z supervisor ruled (issuecomment on #1971, 22:20Z): post slice-done and contact sheet on run 39682861406, naming the unrelated launcher-baseline failure (#3856, fixed by #4217). Done; contact sheet issuecomment-6328176890.


## Critic panel, journeys run 39691305165 (32fcc2c4)

| Finding | Slice | Sev | Lens | Round | State |
|---|---|---|---|---|---|
| #4264 | CL-probe | CI | journey | 1 | PR #4286 (timeline scroll bar strips; hide indicators) |
| #4265 | CL-measure | CI | journey | 1 | PR #4285 (test pressed the empty label cell, not the ruler) |
| #4266 | CL-probe | CI | journey | 1 | PR #4286 |
| #4272 | CL-measure | major | mouse | 1 | PR #4287 (bare transport left at 440 pt; History drops; tight ~8 pt) |
| #4273 | CL-measure | major | clarity | - | waits #4283 |
| #4274 | CL-measure | major | job | - | held |
| #4275 | CL-probe | major | job | - | held |
| #4276 | CL-measure | major | job | - | held |
| #4277 | CL-measure | minor | job | - | held |
| #4278 | CL-ui | minor | clarity | 1 | PR #4290 |
| #4279 | CL-ui | minor | design | 1 | PR #4290 |
| #4280 | CL-ui | minor | design | 1 | PR #4290 |
| #4281 | CL-ui | minor | design | - | waits #4282 |

## Critic panel, journeys run 39705462811 (8d08e083)

| Finding | Sev | Lens | State |
|---|---|---|---|
| #4310 inspector TEXT field stale after Redo | major | journey | round-1 fixer after #4285/#4290 land (UITests overlap) |
| #4311 H-J12 step 9 never checks Undo removed "Hello" | minor | oracle | with #4310 |
| #4312 H-J12 step 7 Space check passes when Space does nothing | minor | oracle | with #4310 |
| #4313 inspector width tracks content (5 pt) | minor | layout | round-1 fixer after #4287 lands (HaloLayoutTests) |
| #4314 text Color row label clipped | minor | layout | with #4313 |
| #4315 easing chips lack identifiers (gap, p2) | – | audit | gap; predates core-loop |
