# transform lead record

Issue: #3443 · Packet: docs/blueprints/halo/features/transform.md
Run: act-1a15a9f4eda-rqhh · Session: session_01SEp2gy695K32UTCMdrBDFC · Started: 2026-10-20T18:43Z
Stage: 3 wave 2
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: watch #3682 (HT-a) and #3702 (HT-5, stacked on #3682, 335 lines/7 files vs dev) in the lane; then HT-3 (HT-u)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HT-a | adapter stubs; handles on the selected layer in the viewer | HT-1, HT-2 | MJ-HT | – | yes | 0 | merged-done (landed in #3702, 2a21273a3) | https://github.com/qbtrix/creative-apps/actions/runs/39514893774 | wanted |
| HT-u | handle drags preview live and commit once; snapshots, budget | HT-3, HT-4 | J-HT | HT-a, transform-tools:TT-u (done) | yes | 0 | building (#3811 open, head b6cba72) | – | – |
| HT-m | turn/scale keyed at the playhead as one step; catalog commands | HT-5, HT-6 | MJ-HT | HT-a, transform-tools:TT-m (done), HT-6: autosave-history:HA-m | no | 0 | HT-5 merged (#3702, 2a21273a3); HT-6 waiting | – | – |
| HT-z | journey on live; feature built | HT-7, HT-8 | J-HT | HT-u, HT-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HT-1 | HT-a | 1 | adapter stubs; HaloTransformTests disabled | Sources/HaloModel/HaloTransform+Kernel.swift, Tests/HaloModelTests/HaloTransformTests.swift | compiles, disabled | #3702 | merged (2a21273a3; #3682 closed as superseded) |
| HT-2 | HT-a | 1 | HaloViewerHandles on the stubs; journey skipped | Sources/HaloApp/HaloViewerHandles.swift, Sources/HaloApp/HaloViewer.swift, UITests/HaloJourneyTests+Transform.swift | HaloViewerSnapshots handles | #3702 | merged (2a21273a3) |
| HT-5 | HT-m | 2 | adapter bodies, keyed when animated | Sources/HaloModel/HaloTransform+Kernel.swift, Tests/HaloModelTests/HaloTransformTests.swift, Tests/mutations/HaloModel.HaloTransform+Kernel.json | HaloTransformTests; Mutate | #3702 | merged 22:41Z (2a21273a3, Mutate 3/3) |
| HT-6 | HT-m | 3 | six specs, id list, RJ-H34 | Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloTransformCommandIDTests.swift, Tests/RealJobs/halo/key-turn/* | HaloTransformCommandIDTests; RJ-H34; Mutate 12/12 | #4415 | open (fast-lane) |
| HT-3 | HT-u | 2 | drags preview via HaloLiveEdit, commit once, Escape cancels | Sources/HaloApp/HaloViewerHandles.swift, Tests/AppSnapshotTests/HaloViewerHandlesTests.swift | HaloViewerHandlesTests | #3811 | merged |
| HT-4 | HT-u | 3 | snapshots, render budget | Tests/AppSnapshotTests/HaloTransformSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloTransformTests.swift | knobDragInThreeBodies | #3811 | merged |
| HT-7 | HT-z | 4 | journey on live | UITests/HaloJourneyTests+Transform.swift | testRotateAndScaleInViewer | #4422 | open (stacked on #4415) |
| HT-8 | HT-z | 5 | status built, feature-done | docs/blueprints/halo/features/transform.wave.json | waves render | #4422 | open (feature-done) |

Wave 1: HT-a (HT-1+HT-2, one slice PR), alongside autosave-history HA-a. Wave 2: HT-5 stacked on HT-a; HT-3 once HT-a merges.

Wave 3: HT-m as #4415 on dev 30120a8; HT-z (#4422) stacked on it at once, labelled feature-done.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- #3702 (HT-m) was stacked on HT-a, so its squash landed HT-a too; #3682 was closed as superseded, not rebased.
- Stacked PRs diff against dev with their parent included, so a stacked slice PR opens only when its diff vs dev is within 400 lines and 15 files (in practice once the parent merges); the branch is built and gated at once.
- Base is origin/dev (CLAUDE.md: never branch from main); main b3011ab9 verified at start.
- One PR per slice (rule 22): HT-1 and HT-2 ship together as HT-a, failing test first.
- HT-6 waits on autosave-history HA-6, which waits on gradient-fill HG-m (both own HaloCommandCatalog.swift and Tests/command-ids/halo.txt).

## Open
- HT-5 box under a turned or scaled parent: the parent places the centre only; the box keeps the layer's own size and turn. Check in the critic panel; file a gap if the job needs nested transforms.
- HG-m and HA-m are on dev (autosave-history built, #4397), so HT-6 is unblocked; HT-m is #4415.
