# adopt-kernel-transform lead record

Issue: #1938 · Packet: docs/blueprints/suiteui/features/adopt-kernel-transform.md
Run: act-1a157b2050f-ovpu (resumed from act-1a1543c764c-0mz9) · Session: claude/feature-lead-suiteui-run-336pic · Started: 2026-10-20T05:08Z
Stage: 3 wave 2 (AT-flare, AT-photo done; AT-design blocked on AL-design)
Base: b3011ab9dc5579023722e79f83254e6e2520e612 (main); dev 18464f26
Next: AT-design (AT-d1) starts when adopt-kernel-layers AL-design #3392 merges on dev (open, clean, Head ed7c3c6, waiting on the lane's macOS build); AS-design merged #3385 (2026-10-20T01:39Z). Recheck every heartbeat.

Line lead for #1938, #1937 and #1936 (contract rule 19); this record is the
adopt-kernel-transform part. The brief names `main` at
e01529f43474e4e80489c080e0f598eaa3b05052, verified as `origin/main` and an
ancestor of `origin/dev`; PRs target `dev` per CLAUDE.md (the lane retargets a
fast-lane PR opened against `main` to `dev`).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AT-design | Design transform on `EditorHandle`, `BoxMath`, `HandleHit`, `LayerTransform` behind its API; copy deleted | AT-d1, AT-d2 | MJ-AT-design (`DesignResizeTests`) | editor-kernel:EK-box, adopt-kernel-selection:AS-design, adopt-kernel-layers:AL-design (AT-d1) | false | 0 | blocked | – | – |
| AT-photo | Photo transform on the same kernel types behind its API; copy deleted | AT-p1, AT-p2 | MJ-AT-photo (`PhotoMoveTests`) | editor-kernel:EK-box (AT-p1), met: #2711 | false | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39132122171 | – |
| AT-flare | Flare `BoxGestureMath` takes handle numbering, mirror and zero-size guards from the kernel; copy deleted | AT-f1, AT-f2 | MJ-AT-flare (`BoxGestureMathTests`) | editor-kernel:EK-box (AT-f1), met: #2711 | false | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39131124501 | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AT-d1 | AT-design | 1 | Design adapter: `DesignHandle` = `EditorHandle`, `resized`/`handles`/`handle(at:)`/`scaled` call `BoxMath`/`HandleHit`; `DesignModifiers` = `EditModifiers` | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/Live/LiveTransforming.swift, Sources/DesignModel/DesignCanvasEditing.swift, Tests/DesignModelTests/DesignResizeTests.swift, Tests/DesignModelTests/DesignSeveralTransformTests.swift, Tests/DesignModelTests/DesignCompactSelectionTests.swift, Tests/DesignModelTests/DesignCanvasTests.swift, Tests/mutations/DesignModel.KernelTransformAdapter.json | those four unchanged; `scripts/mutate --plan DesignModel.KernelTransformAdapter` (dropped `endRun()` forward; refusal mapped to success) | – | waiting (EK-box, AS-design, AL-design) |
| AT-d2 | AT-design | 2 | Design delete: box math in `DesignNode.swift`, `scaled`, handle hit; plans repointed | Sources/DesignModel/DesignNode.swift, Sources/DesignModel/Live/LiveTransforming.swift, Sources/DesignModel/DesignCanvasEditing.swift, Tests/mutations/DesignModel.LiveTransforming.json, Tests/mutations/DesignModel.DesignNode.json | same tests; `scripts/mutate --validate` | – | waiting (AT-d1) |
| AT-p1 | AT-photo | 1 | Photo adapter: `TransformHandle` = `EditorHandle`, kernel `LayerTransform`, `handle(at:in:tolerance:)` calls `HandleHit`, `dragged` calls `BoxMath.resized`/`snappedDegrees`; `LiveTransform.applied` stays `NotBuilt` | Sources/PhotoModel/Contracts/LayerContracts.swift, Sources/PhotoModel/Live/LiveTransform.swift, Sources/PhotoModel/Live/LiveTransform+Kernel.swift, Sources/PhotoModel/Live/NotBuilt.swift, Sources/PhotoModel/Fakes/FakeGeometry.swift, Tests/PhotoModelTests/PhotoKernelTransformTests.swift, Tests/PhotoModelTests/PhotoMoveTests.swift, Tests/PhotoModelTests/PhotoDragRoutingTests.swift, Tests/mutations/PhotoModel.KernelTransformAdapter.json | PhotoMoveTests, PhotoDragRoutingTests unchanged; `scripts/mutate --plan PhotoModel.KernelTransformAdapter` | #2756 | merged |
| AT-p2 | AT-photo | 2 | Photo delete: `PhotoTransform.swift` no-op and the handle enum in `PhotoContractTypes.swift`; plans repointed | Sources/PhotoModel/PhotoTransform.swift, Sources/PhotoModel/Live/LiveTransform.swift, Sources/PhotoModel/Contracts/PhotoContractTypes.swift, Tests/mutations/PhotoModel.PhotoTransform.json | same tests; `scripts/mutate --validate` | – | folded (see Decisions) |
| AT-f1 | AT-flare | 1 | Flare adapter: `BoxGestureMath` keeps FlareCore placement and oblique fit, takes handle numbering and guards from `EditorHandle`/`BoxMath` | Sources/FlareModel/Live/BoxGestureMath.swift, Sources/FlareModel/Live/BoxGestureMath+Kernel.swift, Tests/FlareModelTests/BoxGestureMathKernelTests.swift, Tests/FlareModelTests/BoxGestureMathTests.swift, Tests/FlareModelTests/LiveShapesBoxTests.swift, Tests/mutations/FlareModel.KernelTransformAdapter.json | BoxGestureMathTests, LiveShapesBoxTests unchanged; `scripts/mutate --plan FlareModel.KernelTransformAdapter` | #2755 | merged |
| AT-f2 | AT-flare | 2 | Flare delete: handle index arithmetic and guards in `BoxGestureMath.swift`; plans repointed; carries `feature-done` if last | Sources/FlareModel/Live/BoxGestureMath.swift, Tests/mutations/FlareModel.BoxGestureMath.json | same tests; `scripts/mutate --validate` | – | folded (see Decisions) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18T08:35Z: no task can start. Every slice's first task waits on editor-kernel:EK-box. On origin/dev 2202c7c, `Sources/SuiteKernel/Transform/BoxMath.swift` and `HandleHit.swift` are the EK-3 stubs ("Stubs return their input"); EK-19's tests (#2646) are open and disabled and EK-20's bodies are planned for editor-kernel's wave 4. An adapter on the stubs would turn the apps' resize and handle tests red. Recorded on #1938; stopped per lead.md stage 0 step 4.
- Waves once unblocked (the packet's): wave 1 AT-p1, AT-f1 (and AT-d1 once AS-design and AL-design merge); wave 2 the delete tasks, each waiting only on its app's adapter (same files). The last delete to merge carries `feature-done` and `"status": "built"` in the wave.json.
- 2026-10-18T11:00Z: stage 0 waits rechecked: EK-20 merged as #2711 (278362da, 10:31Z); `BoxMath.swift`/`HandleHit.swift` on dev 7bd94d21 have bodies and plans `SuiteKernel.BoxMath.json`/`SuiteKernel.HandleHit.json`. AT-photo and AT-flare can start; AT-design still waits on AS-design and AL-design (both unmerged).
- 2026-10-18T11:00Z: hand-offs checked. AT-photo: photo-seams is `built` (#812). AT-flare: stage-edit (planned, lead at wave 2) owns no slice on `BoxGestureMath.swift` (its SE-0 owns FlareBoxDrag/FlareDrag/FlareSelection), so the packet's hand-off has nothing to wait on.
- 2026-10-18T11:00Z: stage 1/2, packet against code. The packet's AT-p1 files miss where Photo's types live: `TransformHandle` and `LayerTransform` are in `Contracts/LayerContracts.swift`, `NotBuiltTransform` in `Live/NotBuilt.swift`, `FakeTransform` in `Fakes/FakeGeometry.swift`; `PhotoContractTypes.swift` holds only `DragModifiers`. Only built features (photo-seams, live-stage) own them, so AT-p1's files are widened to those plus an adapter `Live/LiveTransform+Kernel.swift` and a new test file; existing test files stay unchanged (quality row "behaviour preserved").
- 2026-10-18T11:00Z: the packet's mutation text for every adapter ("drops the forward to `endRun()`", "refusal mapped to success") fits no transform adapter: none forwards `endRun()` or maps a refusal. Builders plant 2 or more plausible bugs in the adapter instead (wrong handle index mapping, Shift/Option not forwarded to `EditModifiers`, tolerance not passed), each caught, `Mutate:` line in the body (rule 14).
- 2026-10-18T11:00Z: kernel surface: only `BoxMath.resized/scaled/snappedDegrees/handles(of:size:)` and `HandleHit.handle(at:in:tolerance:)/tolerance(screen:zoom:)` are public; `HandleHit.centre` and `BoxMath.sides` are internal. Flare's mirror and zero-size guards (#655/#688/#698) skip a layer, while `BoxMath.resized` clamps to 1 and never mirrors, so AT-f1 takes handle numbering and positions from `EditorHandle`/`BoxMath.handles` and keeps Flare's guards where the kernel has no equal behaviour (tests unchanged decide). Recorded so AT-f2 deletes only what the adapter replaced.
- 2026-10-18T11:00Z: wave 1 = AT-p1, AT-f1 (disjoint files, independent). Two tasks, nothing alongside: one worktree subagent each (lead.md stage 3 step 3); `gh` has no token in this session, so builders open PRs through the GitHub MCP tools.
- All three slices are Model only (`"ui": false`): no critic panel on screens is due; merged-done reads dev's Linux job.
- 2026-10-18T13:45Z: wave 1 merged: AT-f1 #2755 and AT-p1 #2756, each Mutate 5/5 (FlareModel/PhotoModel.KernelTransformAdapter). AT-p1's builder used branch lead/adopt-kernel-transform-AT-p1 (a ref under `lead/adopt-kernel-transform/` can't exist beside that branch); later briefs use the dash form.
- 2026-10-18T13:45Z: between-waves check: wave 2 has nothing left to delete, so AT-p2 and AT-f2 fold into wave 1. AT-p2: `PhotoTransform.transformDrag` is PV-7's no-op that `PhotoDragRoutingTests.aTransformInProgressTakesTheDrag` pins (`model == before`), `PhotoContractTypes.swift` holds only `DragModifiers` (used widely, not a handle enum), and `Tests/mutations/PhotoModel.PhotoTransform.json` doesn't exist. AT-f2: AT-f1 already replaced the handle index arithmetic with `EditorHandle`/`BoxMath.handles`; the #655/#688/#698 guards stay because `BoxMath.resized` clamps to 1 and never mirrors, and `BoxGestureMathTests` pins the skip.
- 2026-10-18T13:45Z: `Belt-Slice-Done: AT-flare` posted on #1938 with scoped flare run 39131124501 (dev ab22e2e2, contains #2755, green). AT-photo waits for a dev run with Photo Model tests containing #2756 (I can't dispatch CI); the full CI runs since have been cancelled by newer ones.
- 2026-10-18T13:45Z: AT-design stays blocked: AS-design and AL-design both sit behind design-seams-2, parked. No `feature-done` until AT-design's delete merges.

- 2026-10-18T14:30Z: AT-photo done: full CI run 39132122171 on dev 4bf67be8 (contains #2756) is green, Photo Model tests and PhotoMoveTests journeys included; Belt-Slice-Done posted on #1938.

## Open
- 2026-10-18T13:45Z: ninth Belt nudge (after a worker restart); wave 1 recorded, wave 2 folded, AT-flare done.
- 2026-10-18T11:00Z: sixth Belt nudge; EK-box unblocked (#2711). Stage 3 wave 1 started on base 7bd94d21.
- 2026-10-18T10:27Z: fifth Belt nudge; rechecked. dev now a80ed944; EK-20 still planned; EK-box bodies still EK-3 stubs; editor-kernel lead relaunched (wo0uruy8p, 10:26Z), still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T09:56Z: fourth Belt nudge; rechecked. dev now 02c20bfb; EK-19 tests #2646 on dev; EK-20 body not started; EK-box bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2 (heartbeat 09:53Z). lead.md gained the `Belt released this run.` stop rule (#2717), noted. Still blocked; stopped again.
- 2026-10-18T09:25Z: third Belt nudge; rechecked. dev now ed52eaa8; EK-19 tests #2646 merged, so EK-20 (the body this feature needs) is now unblocked for editor-kernel's wave 4; EK-box bodies still EK-3 stubs; editor-kernel lead still stage 3 wave 2. Still blocked; stopped again.
- 2026-10-18T08:54Z: second Belt nudge; rechecked. dev now 93b1e91 (one Library perf merge since 2202c7c); EK-box bodies still EK-3 stubs; editor-kernel lead at stage 3 wave 2, waiting on lane batch-20261018081953, wave 4 (bodies) not started. Still blocked; stopped again.
- 2026-10-18T08:23Z: Belt nudge after 30 quiet min; rechecked. dev still 2202c7c (no merges since); EK-box bodies still EK-3 stubs; editor-kernel lead stopped at stage 3 wave 2 on dev-red #2667, wave 4 (bodies) not started. Still blocked; stopped again.
- Blocked on #1933 editor-kernel EK-box (EK-20). AT-design also on adopt-kernel-selection:AS-design (#1934's lead, blocked on EK-sel) and adopt-kernel-layers:AL-design (this run, blocked on EK-tree).

## Decisions (run act-1a1543c764c-0mz9)
- 2026-10-19T13:01:46Z: branch rebuilt as origin/main plus one commit holding only this record and timeline (the old branch carried stray docs/leads/switching changes that conflicted).

## Decisions (run act-1a157b2050f-ovpu)
- 2026-10-20: AS-design is met (#3385 merged). AL-design #3392 is open and owned by another lead (act-1a154b13dec-71tm); not built here (rule: never copy another lead's slice).
- PRs target `dev` (CLAUDE.md, the lane).

## 2026-10-20 ~10:45Z: AT-design unblocked, AT-d1 started

- AL-design merged (#3392, dev 6ace17f2), so DesignNode.swift's hand-off is met; AS-design was met by #3385.
- design-seams-2 (status planned) lists "the beta gap adopts (... transform ...) before S2-a" in its waits_on and owns no active slice on DesignCanvasEditing.swift, so AT-design goes first on that file.
- AT-d1 builder started on lead/adopt-kernel-transform-AT-d1 (adapter test first, mutation plan DesignModel.KernelTransformAdapter with 2+ planted bugs).

## 2026-10-20 10:54Z: AT-d1 opened as #3593; AT-d2 started

- #3593 head f297417d, 262 lines / 5 files, gate PASS, mutate KernelTransformAdapter 5/5, LiveTransforming still 8/8.
- Deviations from the packet: DesignHandle maps both ways onto EditorHandle (10 cases, not a typealias); DesignModifiers forwards Shift/Option only (noSnap stays Design's); a zero-width/height box keeps Design's scaling rule (private `stretched`) because aBoxOfNoWidthNeverDividesByZero pins it.
- AT-d2 builder started stacked on AT-d1 (lead/adopt-kernel-transform-AT-d2); its PR opens once #3593 merges, carrying feature-done and status built.

- 2026-10-20T11:27:49Z: AT-d2 built (head 070f878a, stacked on AT-d1): one `scaled` on BoxMath.scaled with the no-length-axis rule (private `stretched` gone); compact handle hit walks only the corners; DesignNode plan +4 mutations, LiveTransforming repointed +1 (new test aLayerScaledDownStaysAtLeastOnePoint); wave.json status built, feature_issue #1938. Gate PASS; mutate 8/8, 9/9, 5/5. AT-photo and AT-flare are done (Belt-Slice-Done on #1938), so marking built is right. Its PR opens once #3593 merges (merge dev in, gate again), carrying feature-done.
- 2026-10-20T13:16:33Z: AT-d1 #3593 merged. AT-d2 opened as #3604 (head 33fd4388, fast-lane + feature-done), mergeable clean, waiting on the lane's macOS build.

- 2026-10-20T14:18:51Z: AT-d2 #3604 merged 14:14Z as 6fa96843 after macOS build 39429014286 passed; AT-design waits on a run at or after 6fa96843 (39436941980 at 56e73319 predates it).

- 2026-10-20T14:40Z: Full CI 39436941980 cancelled. Full CI 39438701609 at 9f880c85 (contains every slice, incl. 6fa96843) queued; scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:00Z: Full CI 39438701609 (9f880c85) and newer 39442633733 (0dd23d65, also contains every slice) both queued; macOS queue backed up. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:21Z: Full CI 39442633733 (0dd23d65), 39438701609 (9f880c85) and newer 39447117246 (27b67332, pending) all contain every slice; none started. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:41Z: No full or scoped CI run has completed since 15:21Z; 39447117246 (27b67332), 39442633733, 39438701609 and scoped runs at 897ccbb2 still waiting on macOS runners. Slice lines wait.

- 2026-10-20T16:00Z: Still no completed full or scoped CI run since 15:21Z (only a Linux check at 27b67332 finished). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 wait on macOS runners. Slice lines wait.

- 2026-10-20T16:20Z: No completed full or scoped CI run since 15:21Z (only Linux checks at 27b67332 and 47dd9bb8). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 still wait on macOS runners. Slice lines wait.

- 2026-10-20T16:40Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending, 39442633733 and 39438701609 queued; only Linux checks completed (5eceabf7, 47dd9bb8)

- 2026-10-20T17:00Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending; only a Linux check completed (7b45f176)

- 2026-10-20T17:20Z: full CI 39447117246 at 27b67332 cancelled (replaced); new full CI 39464293440 at 39a1c97e pending, contains every slice; no qualifying run completed yet

- 2026-10-20T17:40Z: full CI 39464293440 at 39a1c97e cancelled (replaced while pending); new full CI 39467874733 at 59fe72db pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:00Z: full CI 39467874733 at 59fe72db cancelled (replaced while pending); new full CI 39469318877 at d7f615dc pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:19Z: full CI 39469318877 at d7f615dc still pending (queued since 17:48Z, contains every slice); Linux check 39469631014 at d7f615dc passed (does not count); no qualifying run completed yet

- 2026-10-20T18:39Z: full CI 39469318877 at d7f615dc replaced while pending; new full CI 39475897385 at 875b44d2 pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:58Z: full CI 39475897385 at 875b44d2 still pending (queued since 18:34Z, contains every slice); Linux check 39476966994 at 875b44d2 passed (does not count); no qualifying run completed yet

- 2026-10-20T19:18Z: full CI 39475897385 at 875b44d2 still pending (contains every slice merge); scoped: suite 39479908321 at a48992b7 queued (suite scope, not suiteui); no qualifying run completed yet

- 2026-10-20T19:38Z: full CI 39475897385 at 875b44d2 still pending (contains every slice merge); latest completed runs are Linux checks only; no qualifying run completed yet

- 2026-10-20T19:58Z: full CI 39475897385 at 875b44d2 cancelled (replaced); new pending full CI 39485502739 at 8c90de14 (contains 875b44d2, so every slice merge); no qualifying run completed yet

- 2026-10-20T20:18Z: full CI 39485502739 at 8c90de14 still pending (contains every slice merge); scoped: design 39490030243 at 014da2f1 pending (would cover AC-design and AT-design); no qualifying run completed yet

- 2026-10-20T20:38Z: no qualifying run yet: full CI 39485502739 (8c90de14) and scoped design 39490030243 (014da2f1) still pending; latest completed runs are Linux checks

- 2026-10-20T20:57Z: still no qualifying run completed. Pending: full CI 39485502739 (8c90de14), scoped suiteui 39491489760 (e64cff6b, contains every slice merge), scoped design 39490030243, photo 39492942073, flare 39491495208, halo 39494391226 (all contain the slice merges)
