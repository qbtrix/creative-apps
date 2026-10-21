# design-autosave-history lead record

Issue: #3434 · Packet: docs/blueprints/design/features/autosave-history.md
Run: act-1a15a9a4e8b-kn6a · Session: claude/feature-lead-playbook-y5rnbx · Started: 2026-10-20T18:42:31Z
Stage: 3 wave 2 (DA-a, DA-m done; DA-u #3726 open at local Mac gate)
Base: 875b44d22d79dcfb782d7276af76dfc72a23f11a (origin/dev); main verified at b3011ab9
Next: Belt-Slice-Done DA-u once merged-done; DA-a critics on journeys design 39545087913 ui-screens (scoped design 39548305565 also running); DA-6 waits DG-m (SuiteUI #3677, GF-6 #3742); DA-z waits DA-6

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DA-a | adapter stubs; History panel and autosave hooks on the window; View > Show History | DA-1, DA-2 | MJ-DA | shell-parity (built) | yes | 0 | done | 39520241285 | – |
| DA-u | toolbar History button; panel follows undo and jumps; snapshots and budget | DA-3, DA-4 | J-DA | DA-a | yes | 0 | #3726 open (head f2d0c703, base DA-a branch, Mutate 2/2) | – | – |
| DA-m | jump records no step; recovery bytes reopen dirty; history commands in the catalog | DA-5, DA-6 | MJ-DA | DA-a; gradient-fill:DG-m (DA-6) | no | 0 | DA-5 #3710 open (head c2d68a99, base DA-a branch, Mutate 3/3); DA-6 waits DG-m | – | – |
| DA-z | journey jumps and recovers on live; built | DA-7, DA-8 | J-DA | DA-u, DA-m; suiteui autosave-history AH-z (AH-8 #3629) | yes | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DA-1 | DA-a | 1 | adapter signatures as stubs; DesignRecoveryTests disabled | Sources/DesignModel/DesignRecovery+Kernel.swift, Tests/DesignModelTests/DesignRecoveryTests.swift | compiles, disabled | #3686 | open (5a79039a) |
| DA-2 | DA-a | 1 | DesignHistoryArea (trailing panel, .autosaveRecovery), one window line, View > Show History, journey skipped | Sources/DesignApp/DesignHistoryArea.swift, DesignWindow.swift, DesignCommands.swift, UITests/DesignJourneyTests+History.swift | DesignEditorSnapshots history panel | #3686 | open (5a79039a; ships as DesignHistoryArea+Kernel.swift) |
| DA-3 | DA-u | 2 | toolbar History button, panel follows undo | Sources/DesignApp/DesignHistoryArea.swift, Sources/DesignModel/DesignToolbarItems.swift, Tests/AppSnapshotTests/DesignHistoryAreaTests.swift | DesignHistoryAreaTests | #3726 | open, stacked on #3686 |
| DA-4 | DA-u | 3 | snapshots, render budget | Tests/AppSnapshotTests/DesignHistorySnapshots.swift, RenderBudgetDesignHistoryTests.swift | arrowWalkInThreeBodies | #3726 | open, stacked on #3686 |
| DA-5 | DA-m | 2 | adapter bodies; tests on; plan | Sources/DesignModel/DesignRecovery+Kernel.swift, Tests/DesignModelTests/DesignRecoveryTests.swift, Tests/mutations/DesignModel.DesignRecovery+Kernel.json | DesignRecoveryTests, Mutate | #3710 | open, stacked on #3686 |
| DA-6 | DA-m | – | history specs in catalog and id list; RJ-D33 | DesignCommandCatalog.swift, Tests/command-ids/design.txt, DesignHistoryCommandTests.swift, Tests/RealJobs/design/history-jump/* | DesignHistoryCommandTests | – | waits gradient-fill:DG-m |
| DA-7 | DA-z | – | journey on live | UITests/DesignJourneyTests+History.swift | testJumpAndRecover | – | waits DA-4, DA-6, AH-z |
| DA-8 | DA-z | last | status built, feature-done | autosave-history.wave.json | waves render --dry-run | – | waits DA-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Status branch is `lead/design-autosave-history` (record `docs/leads/design-autosave-history/`): `lead/autosave-history` belongs to the SuiteUI lead (#3444).
- PRs target dev, not main (CLAUDE.md).
- On dev: AH-1, AH-2 (HistoryPanel, AutosaveRecovery), AH-3, AH-4, AH-6 (History.jumpEndingRun); AH-8 (#3629) open.

## Open
- DA-6 waits on gradient-fill:DG-m, which waits on suiteui GF-6 (not on dev): both own DesignCommandCatalog.swift and Tests/command-ids/design.txt.
- Wave 2 (wf widwznsim): DA-u (DA-3 + DA-4) and DA-5 open as PRs based on #3686's branch (lead/design-autosave-history-DA-a); the lane skips a non-dev base, and the lead retargets each to dev once #3686 merges. DA-m ships as two PRs (DA-5 now, DA-6 after gradient-fill DG-m), since DA-6 is blocked across features.
- 2026-10-21T00:05:02Z: #3686 needs-fix (CommandPathTests: Show History Button not built from a spec) fixed by DesignMenuState.windowSpecs view.history and MenuCommand(spec, on:); mutate 7/7.
- Belt's 00:0xZ nudge names lead/gradient-fill and lead/autosave-history; those hold other runs' records (flare pe5i, suiteui c6w5), left untouched. This run's records are lead/design-*.
- 2026-10-21T00:27:40Z: DA-a merged as 07f754f7. DA-m and DA-u merge origin/dev (add/add conflicts on DA-a's files resolved to the branch side; dev's copies equal 509907a6), so their diffs against dev are their own slices only.
- 2026-10-21T00:36:54Z: Belt-Slice-Done DA-a (6305025272, run 39520241285). #3710 retargeted to dev at 4d5d8826 (--changed PASS). Supervisor told on #3415 and #3434 that Belt watches other runs' branches.
- 2026-10-21T00:43Z: DA-u #3726 retargeted to dev at 7a01cb92 (dev merged in, --changed PASS); answered the supervisor needs-split sentinel (count predates retarget; now 373+/20-, 9 files). DA-m #3710 in the lane at 4d5d8826.
- 2026-10-21T01:05Z: heartbeat. #3710 macOS build 39522457598 in progress, #3726 macOS build 39523611270 queued; needs-split on #3726 still set (answered). SuiteUI #3629 (AH-8) merged at 0506808e, so DA-z now waits only on DA-6. #3677 open. scoped: design 39490030243 still pending.
- 2026-10-21T01:20Z: Belt stall check. #3710 macOS build 39522457598 green, waiting for a lane batch; #3726 build 39523611270 still queued. Dev Linux red on LibrarySidecarPlanTests.planWithinBudget (timing, Library line, dev-red #3386), not this feature.
- 2026-10-21T01:49Z: heartbeat. No change on #3710/#3726. macOS backlog: 17 macOS builds and 7 scoped runs queued, two dev CI runs in progress since 2026-10-20 14:48Z; lane batch 20261021005140-4 probing. SuiteUI GF-6 (feat/suiteui-gradient-gf-6) in the lane, which leads to DG-m and then DA-6.
- 2026-10-21T02:33Z: heartbeat. Still no batch for #3710 and no build for #3726 (23 runs queued). Reported the macOS queue stall to the supervisor on #3434 (comment 6306556075). GF-6 #3742 and #3677 open.
- 2026-10-21T06:40Z (run act-1a15d1af4b1-45qq): DA-5 #3710 merged 05:07:59Z. DA-u #3726's macOS build was cancelled; the new head merges dev and drops `object_setClass` (dev's isa-swizzle lint) for `RenderBudgetWindow(..., keyCapable: true)`. DA-6 still waits on DG-m (GF-6 #3742 open). Layer-styles blocked; supervisor asked on #3858.
- 2026-10-21T06:55Z: #3726 pushed at 1c9eb1fc (--changed PASS), Head: and Belt-Lead: moved to this run. The cloud proxy re-appends a "Generated by" footer to the body on every write; the lane strips it from the squash (scripts/fast-lane.sh land), so it holds nothing. DA-a critics wait on journeys 39550379326 (queued).
- 2026-10-21T06:59Z: Belt stall check. DA-u macOS build 39556740686 failed: `#expect(model.openFixture("cards"))` calls a mutating method inside the macro (three test files; Linux never compiles AppSnapshotTests). Fixed as `let opened = ...; #expect(opened)`, the idiom DesignEditorSnapshots uses (d58dec2b); gate rerunning, then push and move Head:. DA-a critic panel running (wf_b9f281d0-90c) over journeys 39550379326 (green) and the design-history-panel snapshots.
- 2026-10-21T07:00Z: DA-u #3726 at d58dec2b (--changed PASS), Head: moved; the lane builds it on macOS next. DA-a critic panel (wf_b9f281d0-90c; clarity, mouse, taste, job; journeys 39550379326 + design-history-panel snapshots): 8 confirmed, 2 refuted, filed #3945 (no panel title, major), #3946 (base row 'New Design' with saved dot), #3947 (identical rows, no position; SuiteUI HistoryPanelRow), #3948 (View menu snapshot lacks Show History), #3949 (snapshot layout broken, major), #3950 (no journey opens the panel, major). 6 open findings, over 5, so no new feature wave. Fix round 1 for DA-a: fix-batch wf_bdbedf4e-253 on dev b64cbb8c, with DA-u's files busy (findings on them wait for #3726).
- 2026-10-21T07:16Z: Fix round 1 for DA-a done (wf_bdbedf4e-253). PR #3956 (lead/autosave-history-r-b1, 71892d02, --changed PASS, mutate 5/5, 6 files +81/-13) fixes #3946, #3948 and #3950. Its snapshot and journey changes compile only on macOS; the lane builds them. #3953 (r-b2) fixed #3947 by editing Sources/SuiteUI/HistoryPanel.swift, which the line rule forbids, so I closed it and filed needs-ui #3957 (line:suiteui), linking its branch; #3947 waits on #3957. Fixed the doubled "Slice: Slice: DA-a" line on #3956. Deferred to round 2: #3945 and #3949, whose files are busy in #3726. Open DA-a findings: #3945, #3947, #3949, plus the three #3956 closes.
- 2026-10-21T07:39Z: heartbeat. DA-u #3726 macOS build green at d58dec2b, clean, waiting for a lane sweep. #3956 macOS build at 71892d02 in progress. #3957 (needs-ui) open. GF-6 #3742 open, so DA-6 still waits.
- 2026-10-21T07:45Z: DA-u #3726 merged at 07:44:24Z as 962c760f. Belt-Slice-Done DA-u waits for a dev CI run that contains it to show a green Linux job (none yet). DA-a fix round 1, second batch: fix-batch wf_e53ae567-999 for #3945 and #3949 on dev c8d94796, with #3956's files busy.
- 2026-10-21T07:46Z: wf_e53ae567-999 deferred #3945 and #3949 again: both touch Tests/AppSnapshotTests/DesignEditorSnapshots.swift, busy in #3956. They run once #3956 merges. The first dev run with DA-u (39564216401, scoped: suite) has no Linux job, so the slice-done line still waits.
