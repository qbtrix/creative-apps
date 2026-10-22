# autosave-history (Halo) lead record

Issue: #3442 · Packet: docs/blueprints/halo/features/autosave-history.md
Run: act-1a15a9f4eda-rqhh · Session: session_01SEp2gy695K32UTCMdrBDFC · Started: 2026-10-20T18:43Z
Stage: 3 wave 2 (HA-7b #4371 open, HA-6 #4342 open)
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: when #4371 merges, HA-8 (wave.json status built, feature-done); Belt-Slice-Done for HA-m once its scoped run shows the screens

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HA-a | adapter stubs; History panel and autosave hooks on the window, reachable by a visible control | HA-1, HA-2 (+ HA-3's History button) | MJ-HA | – | yes | 0 | merged-done (#3683, 66c13ce1c) | https://github.com/qbtrix/creative-apps/actions/runs/39514893774 | wanted |
| HA-u | panel follows undo and jumps; Edit > Show History; snapshots, budget | HA-3, HA-4 | J-HA | HA-a; menu item: adopt-command-catalog AC-halo | yes | 0 | building (#3810 open, head cb45e2f) | – | – |
| HA-m | jump lands without a step; recovery reopens dirty; catalog commands | HA-5, HA-6 | MJ-HA | HA-a; HA-6: gradient-fill:HG-m | no | 0 | building (#3701 open, dev merged in) | – | – |
| HA-z | journey jumps and recovers on live; feature built | HA-7, HA-8 | J-HA | HA-u, HA-m, suiteui AH-z | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HA-1 | HA-a | 1 | adapter stubs; HaloRecoveryTests disabled | Sources/HaloModel/HaloRecovery+Kernel.swift, Tests/HaloModelTests/HaloRecoveryTests.swift | compiles, disabled | #3683 | merged (66c13ce1c) |
| HA-2 | HA-a | 1 | HaloHistoryArea + autosave hooks on the window, History button by the transport; journey skipped | Sources/HaloApp/HaloHistoryArea.swift, Sources/HaloApp/HaloWindow.swift, Sources/HaloApp/HaloControls.swift, UITests/HaloJourneyTests+History.swift | HaloWindowSnapshots panel | #3683 | merged (66c13ce1c) |
| HA-5 | HA-m | 2 | adapter bodies: jump, recovery bytes, recovered project | Sources/HaloModel/HaloRecovery+Kernel.swift, Tests/HaloModelTests/HaloRecoveryTests.swift, Tests/mutations/HaloModel.HaloRecovery+Kernel.json | HaloRecoveryTests; Mutate | #3701 | open: needs-rebase fixed by merging dev, head fe1a0d9 (Mutate 3/3) |
| HA-6 | HA-m | 3 | two specs, id list, RJ-H33 | Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloHistoryCommandIDTests.swift, Tests/RealJobs/halo/history-jump/* | HaloHistoryCommandIDTests | – | waiting (HG-m) |
| HA-3 | HA-u | 2 | panel follows undo and jumps; Edit > Show History once AC-halo is done | Sources/HaloApp/HaloHistoryArea.swift, Sources/HaloApp/HaloEditMenu.swift, Tests/AppSnapshotTests/HaloHistoryAreaTests.swift | HaloHistoryAreaTests | #3810 | open |
| HA-4 | HA-u | 3 | snapshots, render budget | Tests/AppSnapshotTests/HaloHistorySnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloHistoryTests.swift | arrowWalkInThreeBodies | #3810 | open |
| HA-7 | HA-z | 4 | journey on live | UITests/HaloJourneyTests+History.swift | testJumpAndRecover | – | waiting |
| HA-8 | HA-z | 5 | status built, feature-done | docs/blueprints/halo/features/autosave-history.wave.json | waves render | – | waiting |

Wave 1: HA-a (one slice PR), alongside transform HT-a. Wave 2: HA-5 stacked on HA-a; HA-3 once HA-a merges.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Stacked PRs diff against dev with their parent included, so a stacked slice PR opens only when its diff vs dev is within 400 lines and 15 files (in practice once the parent merges); the branch is built and gated at once.
- Lead branch is lead/halo-autosave-history: lead/autosave-history belongs to the suiteui lead.
- Base is origin/dev; main b3011ab9 verified at start.
- HaloEditMenu.swift is AC-halo's until its Belt-Slice-Done (#2999 has none; AC-h3 waits on CC-u). So HA-a makes the panel reachable from the History button by the transport (moved from HA-3 into HA-a, same feature, HaloControls.swift), and Edit > Show History moves to HA-u once AC-halo is done.

## Open
- AC-halo (#2999) not done: holds the Edit > Show History item.
- HG-m (gradient-fill #3417) blocked on GF-6: holds HA-6.
- HA-7 waits on suiteui autosave-history AH-z.

## Run act-1a162462636-ft6b (2026-10-22T06:25Z)

- Base: origin/dev bdd92b41 (PRs target dev; the lane retargets main).
- Status branch stays lead/halo-autosave-history: lead/autosave-history is the SuiteUI lead's.
- HA-5 is merged on dev (HaloRecovery+Kernel.swift bodies, HaloRecoveryTests on), so HA-m needs only HA-6. HG-m is built, so HA-6 is unblocked.
- Wave 1: HA-6 (catalog specs history.jump and the second history spec, halo.txt, HaloHistoryCommandIDTests, RJ-H33 job folder).
- Wave 2: HA-7 once suiteui AH-z's live recovery wiring is on dev; then HA-8 feature-done.
- 2026-10-22T08:15Z wave 1 PRs: HA-6 #4342 (slice HA-m; Mutate HaloModel.HaloCommandCatalog 10/10) and HA-7 #4335 (slice HA-z). Both have the fast lane macOS builds dispatched. The attribution footers were removed from both bodies.
- HA-7 gap: on dev, Sources/HaloApp/HaloHistoryArea.swift still passes folder: nil, and its restore hook throws HaloNotBuilt. So step 3 (force-quit and Restore) sits behind recoveryIsLive = false. A new task, HA-7b (HaloApp: a recovery folder from -SuiteSupportDir under <support>/Halo/Recovery, restore via HaloProject.recovered, and recoveryIsLive set to true), is added to HA-z as wave 2 and stacks on HA-7. HA-8 follows it.
- 2026-10-22T09:43Z HA-7 #4335 merged (06d331b0). HA-7b #4371 opened (wave 2, slice HA-z; Mutate HaloRecoveryStore 7/7, HaloRecovery+Kernel 3/3). The lane gave it needs-rebase for UITests/HaloJourneyTests+History.swift; the lead merged origin/dev, kept HA-7b's live step 3 (no recoveryIsLive skip), CI: PASS, head a3a05044, Head line moved, attribution footer removed. HA-6 #4342 waits on its macOS build (run 39738543906).
- 2026-10-22T10:19Z HA-6 #4342 compiled on macOS (run 39738543906) and is clean; HA-7b #4371 waits on the lane at a3a05044. HA-8 opens once both are on dev (it adds feature-done, which starts full CI).
- 2026-10-22T10:28Z HA-6 #4342 merged (ba8009b05). Slice HA-m is done once its critic panel has screens (no UI in HA-6; the catalog and RJ-H33 are Linux-proved). HA-z waits on HA-7b #4371.
- 2026-10-22T10:53Z HA-7b #4371 is mergeable and clean at a3a05044, waiting on the lane's batch. HA-8 (status built, feature-done) opens after it merges.
