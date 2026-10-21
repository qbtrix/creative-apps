# pen-paths (Flare) lead record

Issue: #3519 · Packet: docs/blueprints/flare/features/pen-paths.md
Run: act-1a15e10a86f-7bk9 (took over from act-1a15c07caa7-sppq) · Session: claude/feature-lead-playbook-yf71p7 · Started: 2026-10-21T01:10Z (this run 10:40Z)
Stage: 3 wave 2
Base: 11919406886e89e9e02adea13b113b66e852334d
Next: (2026-10-21T20:58Z) FP-a fix round 2 (last allowed): #4198 (Shift-extend oracle) and #4199 (locked-layer help text) on lead/pen-paths-FP-a-fix2. #4200 moves the stand-in converter into SuiteUI, which line:flare can't edit; it waits for the post-round-2 review and then becomes a gap for line:suiteui.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FP-a | adapters as stubs, PathEditTarget conformance, Direct Select anchors via overlay | FP-1, FP-2 | MJ-FP | PN-a (done), shape-tools:FS-a (done) | yes | 1 | done (Belt-Slice-Done 08:56Z; Mac-Finish-Wanted) | #3838 | 08:08Z merged 5a911587 |
| FP-u | snapshots, render budget, journey (skipped) | FP-3, FP-4 | J-FP | FP-a, PN-3 | yes | 0 | waiting | – | – |
| FP-m | Pen on PenRules; path specs in catalog | FP-5, FP-6 | MJ-FP | FP-a (done), PN-5 (done), PN-7, shape-tools:FS-m (unchained for FP-5), file-flow:FL-m | no | 0 | FP-5 merged (#4029, 14:11Z); FP-6 waits on FL-m | #4029 | – |
| FP-e | Direct Select anchor editing; stress budget | FP-7, FP-8 | MJ-FP, RJ-F27 | FP-a, PN-5 (done), PN-6 (done), stage-edit (closed); FlareSelection.swift avoided (AS-flare hand-off, planned) | no | 0 | done: run 39596004859 (only the Library timing flake; supervisor answer 12:04Z); FP-8 waits on test/stress-perf-journeys | #3958 | – |
| FP-z | journey on; status built | FP-9, FP-10 | J-FP | FP-u, FP-m, FP-e, file-flow:FL-z | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FP-1 | FP-a | 1 | adapters as stubs forwarding to today's code; ShapeDraft.pen; anchor selection field; 3 suites written | Sources/FlareModel/FlarePen+Kernel.swift, Sources/FlareModel/FlareAnchors+Kernel.swift, Sources/FlareModel/FlareWorkspace.swift, Tests/mutations/FlareModel.FlareWorkspace.json, Tests/FlareModelTests/FlarePenKernelTests.swift, Tests/FlareModelTests/FlareAnchorEditTests.swift, Tests/FlareModelTests/FlarePathCommandTests.swift | oracle suites unedited | – | building |
| FP-2 | FP-a | 1 | PathEditOverlay on the stage for Direct Select and Pen | Sources/FlareApp/FlareWindow+Stage.swift | FlareAnchorSnapshots.directPicked (FP-u) | – | building |
| FP-3 | FP-u | 2 | snapshots + render budget | Tests/AppSnapshotTests/FlareAnchorSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareAnchorTests.swift | – | – | waiting |
| FP-4 | FP-u | 2 | journey written, skipped | UITests/FlareJourneyTests+Pen.swift | – | – | waiting |
| FP-5 | FP-m | 2 | Pen on PenRules | Sources/FlareModel/FlarePen+Kernel.swift, Sources/FlareModel/Live/LiveShapes.swift, Sources/FlareModel/Fakes/FakeShapes.swift, Sources/FlareModel/Contracts/ShapeContracts.swift, Sources/FlareModel/FlarePenFinish.swift | FlarePenKernelTests | – | building |
| FP-6 | FP-m | 2 | twelve path specs in catalog | Sources/FlareModel/FlareCommandCatalog.swift, Tests/command-ids/flare.txt | FlarePathCommandTests | – | waiting |
| FP-7 | FP-e | 2 | Direct Select anchor editing | Sources/FlareModel/FlareAnchors+Kernel.swift, Sources/FlareModel/FlareDrag.swift, Sources/FlareModel/FlareSelection.swift | FlareAnchorEditTests | #3958 | merged |
| FP-8 | FP-e | 3 | anchor stress budget | Tests/FlareModelTests/FlareAnchorBudgetTests.swift, UITests/FlareJourneyTests+RealPerfAnchors.swift | FlareAnchorBudgetTests | – | waiting |
| FP-9 | FP-z | 4 | journey on | UITests/FlareJourneyTests+Pen.swift | J-FP | – | waiting |
| FP-10 | FP-z | 5 | flare.md + wave.json built (feature-done) | docs/blueprints/flare.md, docs/blueprints/flare/features/pen-paths.wave.json | – | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| FP-a | 39567954958 | 5a911587 | clarity, design, oracle (code only) | #4011 #4012 #4013 (clean: minor only) | 0 |
| FP-a | 39667367345 | 606e8212 | clarity, design, oracle (code only) | #4198 #4199 #4200 (not clean: 3 confirmed, 2 refuted) | 1 |

## Decisions
- FP-a round-2 review runs on code, like round 1, on the first green dev Linux check containing 79e32f25: the overlay has no snapshot before FP-u, so a Flare screens run adds nothing for these lenses, and waiting on one hit 3 identical polls (rule 23: work instead of idling).
- PRs target `dev`, not `main` as the brief says: CLAUDE.md and lead.md rule 4 say base dev, and the lane retargets fast-lane PRs from main anyway.
- This record lives at docs/leads/flare-pen-paths/ on lead/pen-paths: docs/leads/pen-paths/ there belongs to the SuiteUI pen-paths lead (#3518), whose record must not be clobbered.
- One PR per slice (brief rule 8) instead of one per task.
- FP-a starts from dev without waiting for FS-a #3767: FP-1 needs none of FS-a's code, only shares FlareWorkspace.swift (one stored field), which the lane's merge integrates.
- AU-flare done (#3674 merged), so the FlareWorkspace.swift hand-off for FP-1 is clear.

- Run act-1a15e10a86f-7bk9 took this record over at 10:40Z; lead/pen-paths was recreated from main (its old history did not share a root with main).
- FP-5 unchained from shape-tools:FS-m (rule 12): FS-5 (#3850), the only FS task that touches LiveShapes.swift, has merged; FS-6 left in FS-m touches only the catalog, which FP-5 does not.
- FP-a findings, fix round 1: #4012 (mirror copy) folds into FP-5 since FP-5 moves the pen onto PenRules; #4011 and #4013 (pathInEdit guard and locked-layer help) go to fixer branch lead/pen-paths-FP-a-fix1.
- The issue server re-appends a Claude Code footer to every issue body written from this session; stripping it fails (re-added on PATCH). Recorded rather than fought.
- FP-a's critic panel runs code lenses only (clarity, design, oracle): the overlay has no snapshot until FP-u's FlareAnchorSnapshots, so mouse and taste judge it in FP-u's review.

- GitHub MCP issue_write/update_pull_request write bodies without the server footer; use them instead of gh api for bodies from now on.

## Open
- 2026-10-21T20:11Z: fix round 1 #4027 merged 19:52Z (79e32f25); #4011 and #4013 closed. Open findings now 1 (#4012, waits on needs-suite #4030). Round-2 review waits on a run with Flare screens containing 79e32f25 (newest dev runs: scoped photo/suite/suiteui, Linux checks).
- 2026-10-21T18:42:09Z: #4027 macOS build 39645360844 succeeded; waiting on the lane's merge sweep. Open findings for this feature: 3 (#4011-#4013), under the cap of 5. Belt stall nudge 18:41Z answered with this record push.
- FP-e done: rule-23 question at 3/3 (issuecomment-6315361799); supervisor said #4008 fixed Photo and the tenThousandPaths flake doesn't count; Belt-Slice-Done posted (issuecomment-6315821062) on run 39596004859.
- FP-a findings open: #4011, #4013 (fix round 1: PR #4027, head d36c6856, Mutate 6/6 FlareModel.FlareAnchors+Kernel, fast-lane, snapshot flare-select-direct-locked-light.png), #4012 (FP-5 #4029 carries Refs: PenRules.mirror is internal; needs-suite #4030 asks to make it public; Flare copy has a TODO). Count 3 of cap 5.
- shape-tools FS-m: FS-5 merged #3850, FS-6 blocked on gradient-fill FG-m (FP-5 unchained, FP-6 unaffected).
- file-flow FL-m far off (waits on FG-m, FS-m, FK-m, PF-m): FP-6 waits; rule 23 question after 3 identical polls.
- AS-flare waits on stage-edit #1514: FP-7's FlareSelection.swift hand-off waits.
- PN-5 #3738 and PN-6 merged; PN-3a #3770 open; PN-3 stacked behind it; PN-7 waits on PN-5, PN-6, CC-run.
