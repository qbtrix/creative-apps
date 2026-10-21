# core-loop lead record

Issue: #1971 · Packet: docs/blueprints/halo/features/core-loop.md
Run: act-1a15d0eeefb-6z9l (from 2026-10-21T05:40Z; before: act-1a15a9f4e8d-hav0) (from 2026-10-20T18:45Z; before: act-1a15728f2a2-zb1o) · Session: claude/halo-feature-lead-run-02scrb · Started: 2026-10-20T02:37Z
Stage: 3 wave 2
Base: 6537a1a02f512db2df50d253384529f1b354b184
Next: CL-probe and CL-measure wait on #3401 (needs-ui), CL-12 on #865; CL-z after them

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CL-a | the loop's checks and the HaloRenderJob+Kernel stubs exist before its code | CL-1, CL-2, CL-3 | MJ-CL1 | editor-kernel EK-a (merged, #1933) | false | 0 | merged (#3404, #3408) | | |
| CL-ui | Render… opens SuiteUI ExportSheet on the kernel run; render budget on | CL-4, CL-5 | H-J21 | CL-a | true | 0 | done: #3590 ui1 + #3653 ui2 merged; Belt-Slice-Done + Mac-Finish-Wanted at run 39507877855 (23:50Z) | | |
| CL-run | the render run is ExportRun<HaloRenderSettings>; availability from it | CL-6, CL-7 | – | CL-a | false | 0 | done: #3641, #3812, #3817 merged; Belt-Slice-Done https://github.com/qbtrix/creative-apps/actions/runs/39569221486 | | |
| CL-probe | under -SuitePerfProbe Halo's input sites record series into the window probe | CL-8, CL-9 | H-P1, H-P4 | CL-a; SuiteUI probe recorder needs-ui #3401 | true | 0 | blocked | | |
| CL-measure | H-P1..H-P5 attach series, L3..L5 hold, latency line, journeys live | CL-10, CL-11, CL-12 | H-P1..H-P5 | CL-a; CL-probe (CL-10); switching A-HA-1 #865 (CL-12, open) | false | 0 | blocked (CL-11 merged; CL-10, CL-12 wait) | | |
| CL-z | H-J12 live; shared prose; feature-done | CL-13, CL-14 | H-J12 | CL-ui, CL-run, CL-probe, CL-measure | false | 0 | blocked | | |

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
| CL-8 | CL-probe | – | HaloProbe + input sites record | Sources/HaloApp/HaloProbe.swift + 5 views | CL-9/CL-10 oracles | | blocked (needs-ui) |
| CL-9 | CL-probe | – | RenderBudgetHaloProbeTests.bodies on | Tests/AppSnapshotTests/RenderBudgetHaloProbeTests.swift | bodies | | blocked |
| CL-10 | CL-measure | – | H-P1..H-P5 journeys on | UITests/HaloJourneyTests+Perf.swift | perf journeys | | blocked |
| CL-11 | CL-measure | 2 | L3..L5 and latency line on | Tests/AppSnapshotTests/HaloLayoutTests.swift, HaloViewerLatencyTests.swift | layout tests | | #3487 merged d9bc0337 |
| CL-12 | CL-measure | – | -HaloFixture → -HaloSample in six journeys | UITests/HaloJourneyTests*.swift | journeys | | blocked (#865) |
| CL-13 | CL-z | – | H-J12 live | UITests/HaloJourneyTests.swift | H-J12 | | blocked |
| CL-14 | CL-z | – | status built, waves.in.md, blueprint prose (feature-done) | core-loop.wave.json, waves.in.md, halo.md | scripts/ci | | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Waves
- W1: CL-a1 = CL-1+CL-2 (~380 lines, 3 files), CL-a2 = CL-3 (~300, 5). Independent: both (disjoint files, CL-3's suites need no CL-2 code).
- W2 (started at once, stacked): CL-run1 = CL-6 on CL-a1 (needs the stubs and the disabled tests); CL-ui = CL-4+CL-5 on CL-a1+CL-a2 (CL-4 needs the stubs, CL-5 the CL-3 suite); CL-11 on CL-a2 (enables CL-3's layout and latency tests).
- W3: CL-run2 = CL-7 on CL-run1 (reads the kernel run CL-6 fills).
- Blocked: CL-8, CL-9, CL-10 on needs-ui #3401; CL-12, CL-13 on #865; CL-14 last.

## Decisions
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
