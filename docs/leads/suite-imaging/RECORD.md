# suite-imaging lead record

Issue: #3715 (#4498 closed) · Packet: docs/blueprints/suiteui/features/suite-imaging.md
Run: act-1a164d620b2-ve0e (resumes act-1a1647fe637-pfga, act-1a16308fb6c-s1cb, act-1a15fe5ef7c-rszn, act-1a15e10a9c3-kwzx) · Started: 2026-10-21T10:20Z
Stage: 3 wave 5 (re-cut)
Base: e16b985268c0d3a275134f6277fe495bb8028517
Next: docs PR re-cuts IM-8 (SuiteImaging GPU entry points + layered base first) and IM-10 (catalog adapter now; LiveDevelop on the shared list after the supervisor rules on curve/levels order); then wave 6 builds the buildable halves. #4389 #4390 #4591 #4593 wait on the lane's macOS batch gate. IM-8d waits EP-z, IM-13 waits ST-a.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| IM-a | SuiteImaging target + live dependency rule; adjust values/program/route/live surface as stubs with disabled tests | IM-1, IM-2 | MJ-IM | suite-harness, editor-kernel (built) | no | 0 | done | 39811900368 | – |
| IM-m | values clamp/round-trip, one step list for CPU+GPU, wide working space, live surface one write per step | IM-3, IM-4, IM-5, IM-15 | MJ-IM | IM-a | no | 0 | building | – | – |
| IM-photo | Photo adjustments are SuiteImaging values; canvas on the shared route; PhotoLiveTone deleted | IM-6, IM-7, IM-8, IM-8d | MJ-IM-photo, PJ-IM | IM-a, IM-m, EP-z (IM-8d), photo #3144 (IM-8) | yes | 0 | building | – | – |
| IM-library | Library develop values are SuiteImaging values; loupe on the GPU route | IM-9, IM-10, IM-11 | MJ-IM-library, LJ-IM | IM-a, IM-m, library spine feature-done | yes | 0 | building | – | – |
| IM-z | copies deleted, rule with no baseline, feature built | IM-12, IM-13, IM-14 | MJ-IM, PJ-IM, LJ-IM | IM-photo, IM-library, shared-thumbnails:ST-a | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| IM-1 | IM-a | 1 | SuiteImaging target + Metal boundary rule (supervisor merge) | Package.swift, project.yml, Sources/SuiteImaging/SuiteImaging.swift, Tests/SuiteImagingTests/ImagingBoundaryTests.swift, Tests/metal-boundary-baseline.txt, docs/c4/parts/creative-apps/suite-imaging/container.json, docs/c4/parts/creative-apps/suite-imaging/imaging-adjust.json, docs/c4/parts/creative-apps/suite-imaging/imaging-route.json, Tests/mutations/SuiteImaging.ImagingBoundary.json | ImagingBoundaryTests | #4028 | merged 45fc0fb |
| IM-2 | IM-a | 2 | stubs + disabled tests | Sources/SuiteImaging/Adjust/AdjustSettings.swift, Sources/SuiteImaging/Adjust/ImagingProgram.swift, Sources/SuiteImaging/Route/ImagingRoute.swift, Sources/SuiteImaging/Route/LiveToneSurface.swift, Tests/SuiteImagingTests/AdjustSettingsTests.swift, Tests/SuiteImagingTests/ImagingProgramTests.swift | AdjustSettingsTests, ImagingProgramTests (disabled) | #4028 | merged |
| IM-3 | IM-m | 3 | AdjustSettings clamp + round-trip | Sources/SuiteImaging/Adjust/AdjustSettings.swift, Tests/SuiteImagingTests/AdjustSettingsTests.swift, Tests/mutations/SuiteImaging.AdjustSettings.json | AdjustSettingsTests | #4390 | open |
| IM-4 | IM-m | 3 | ImagingProgram one step list | Sources/SuiteImaging/Adjust/ImagingProgram.swift, Sources/SuiteImaging/Route/ImagingRoute.swift, Tests/SuiteImagingTests/ImagingProgramTests.swift, Tests/mutations/SuiteImaging.ImagingProgram.json | ImagingProgramTests | – | merged 1c510dc |
| IM-15 | IM-m | 3 | wide working space | Sources/SuiteImaging/Color/ImagingColor.swift, Tests/SuiteImagingTests/WideGamutTests.swift, Tests/mutations/SuiteImaging.ImagingColor.json | WideGamutTests | #4389 | open |
| IM-5 | IM-m | 4 | LiveToneSurface | Sources/SuiteImaging/Route/LiveToneSurface.swift, Tests/SuiteImagingTests/LiveToneSurfaceTests.swift, Tests/mutations/SuiteImaging.LiveToneSurface.json | LiveToneSurfaceTests | #4590 | merged 1fe5b53 |
| IM-6 | IM-photo | 3 | Photo imaging tests first | Tests/PhotoModelTests/PhotoImagingTests.swift, Tests/PhotoModelTests/Fixtures/adjust-legacy.ora | PhotoImagingTests | #4593 (with IM-7) | open |
| IM-7 | IM-photo | 4 | Photo adjustments through SuiteImaging | Sources/PhotoModel/PhotoAdjust+Imaging.swift, Sources/PhotoModel/AdjustmentSettings.swift, Sources/PhotoModel/PhotoRender.swift | PhotoImagingTests | #4593 | open |
| IM-8 | IM-photo | 5 | Photo canvas on the shared route | Sources/PhotoApp/CanvasRenderer.swift, Sources/PhotoApp/PhotoRendering.swift, Sources/PhotoApp/TileCanvas.swift, Sources/PhotoModel/PhotoRenderRoute.swift, Tests/metal-boundary-baseline.txt | – | – | blocked: re-cut (see Decisions 18:50Z) |
| IM-8d | IM-photo | 6 | delete PhotoLiveTone | Sources/PhotoModel/PhotoLiveTone.swift, Tests/PhotoModelTests/PhotoLiveToneTests.swift, Tests/canonical-baseline.txt | – | – | planned |
| IM-9 | IM-library | 3 | Library imaging tests first | Tests/LibraryModelTests/LibraryImagingTests.swift, Tests/AppSnapshotTests/LibraryDevelopLatencyTests.swift | LibraryImagingTests | #4591 | open |
| IM-10 | IM-library | 4 | Library develop through SuiteImaging | Sources/LibraryModel/LibraryDevelop+Imaging.swift, Sources/LibraryModel/Contracts/DevelopValues.swift, Sources/LibraryModel/Live/LiveDevelop.swift | LibraryImagingTests | – | blocked: re-cut (see Decisions 18:50Z) |
| IM-11 | IM-library | 5 | Library loupe on the GPU route | Sources/LibraryApp/LibraryLoupe.swift, Sources/LibraryApp/LibraryWindow+Loupe.swift, Sources/LibraryModel/Live/LiveLoupeImaging.swift | LibraryDevelopLatencyTests | – | planned |
| IM-12 | IM-z | 7 | delete Photo's copies | Sources/PhotoModel/GammaTrack.swift, Sources/PhotoModel/PhotoLevelsFormat.swift, Sources/PhotoModel/HueSaturation.swift, Tests/canonical-baseline.txt | – | – | planned |
| IM-13 | IM-z | 6 | no-baseline rule; Photo's Metal link removed | Sources/LibraryModel/Contracts/DevelopValues.swift, Sources/LibraryModel/Live/LiveDevelop.swift, Package.swift, Tests/metal-boundary-baseline.txt, Tests/SuiteImagingTests/ImagingBoundaryTests.swift | ImagingBoundaryTests | – | planned |
| IM-14 | IM-z | 8 | feature-done | docs/c4/parts/creative-apps/suite-imaging/imaging-route.json, docs/blueprints/suiteui/features/suite-imaging.wave.json | – | – | planned |

Waves: combined with shared-codecs (see its RECORD). Wave 1 = IM-1 beside SC-13 and SC-1 (disjoint files). Wave 2 = IM-2 (waits IM-1: needs the target). SC-2 waits IM-1 (Package.swift chain).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-22T18:40Z: relaunch act-1a164d620b2-ve0e on #3715 (#4498 closed). Base is dev e16b985 (main 0dd23d6 lacks the packet). Library spine #1044 closed, photo #3144 merged, so IM-8 and IM-10 start now, stacked (rule 22) on their open predecessors. IM-8d (EP-z planned) and IM-13 (ST-a planned) stay blocked.
- 2026-10-22T17:30Z: wave 4 done (wf_13e8c7bf-e3f). Contract checks: IM-5 clean; IM-7's only miss is the server-appended 'Generated by' footer, which a PATCH can't remove (as on earlier PRs), so I accept it; IM-10's builder shipped IM-9 alone as #4591 because IM-10 needs IM-3's Library key decoding (#4390, not on dev). IM-9 is a valid test-first task, so #4591 stays open as IM-9 and IM-10 waits on #4390.
- 2026-10-22T16:50Z: relaunch act-1a1647fe637-pfga, feature issue #4498. IM-a is done: Belt-Slice-Done posted (comment 6346186910; dev run 39811900368 at 7e9f260 contains 1c510dce). Wave 4 runs build-wave wf_13e8c7bf-e3f on dev 3578eae: IM-5 (IM-m), IM-6+IM-7 (IM-photo; split into two PRs if over 400 lines), IM-9+IM-10 (IM-library; ships IM-9 only if a library spine PR holds DevelopValues/LiveDevelop). A fixer agent brings #4390/#4389 up to dev and drops needs-split.
- 2026-10-22T10:00Z: relaunched after #4028 merged (09:53Z). IM-2 restacked as a cherry-pick of 775148e onto dev (IM-1 was squashed).
- Base is origin/dev (1191940), not main: the packets live on dev.
- One PR per task (rule 22). IM-2 is built stacked on IM-1 now; its PR opens once IM-1 merges.
- IM-1 edits Package.swift and project.yml as the packet says; it is a supervisor merge, off the fast lane.
- 2026-10-22T18:50Z: wave 5 builders both stopped, no PR. IM-8: needs `ImagingColor.displaySteps` (IM-15, unstacked), SuiteImaging has no GPU backend factory or presenter-texture write, LiveToneSurface takes one flattened buffer while Photo's live route composites resident layer tiles with adjustment-layer passes, `PhotoTileUpdate.swift` and `ImagingBoundaryTests.swift` (count == 4) are outside the file list. IM-10: Library's existing tests pin curve-before-levels (shared list runs levels then curve), expect Saturation to throw its waiting reason, and need a failable, end-pinned `ToneCurve` that `AdjustCurve` can't replace. Re-cut in a docs PR. Also: the restart lost the Swift toolchain; reinstalled with scripts/cloud-setup.sh. The 18:40Z relaunch stamps were written early (real ~18:22Z). The lane now gates code PRs per batch on macOS (LANE_MAC_PER_PR off).

## Open
- IM-photo waits adopt-kernel-eyedropper-photo EP-z (blocked) and photo #3144; IM-library waits library spine feature-done; IM-13 waits shared-thumbnails ST-a.
- 2026-10-21T19:24Z: #4028 approved by the supervisor, queued on the Mac gate (18:06Z); body moved to this run id.
- 2026-10-21T20:10Z: IM-2 rebased onto IM-1 head 5b40c257, clean.
- 2026-10-21T20:26Z: IM-2 775148e3 gated CI: PASS and pushed to lead/suite-imaging-IM-2; PR opens once #4028 merges.
- 2026-10-21T20:49Z: check-in: #4028 (IM-1, Package.swift) still on the supervisor's Mac gate. IM-2 gated on lead/suite-imaging-IM-2.
- 2026-10-21T21:11Z: check-in: #4028 still open (supervisor merge; lane re-labels it each sweep). IM-2 gated.
- 2026-10-21T21:33Z: check-in: #4028 still open on the supervisor's Mac gate. IM-2 gated.
- 2026-10-21T21:56Z: #4028 (IM-1) still waiting for the supervisor merge (Package.swift). IM-2 is ready on lead/suite-imaging-IM-2 (775148e3).
- 2026-10-21T22:18Z: #4028 (IM-1) still waiting for the supervisor merge. IM-2 is held.
- 2026-10-21T22:48Z: #4028 (IM-1) still waiting for the supervisor merge. IM-2 is held.
- 2026-10-21T23:12Z: IM-1 #4028 still waits on supervisor merge (Package.swift); IM-2 gated (head 775148e3), PR opens once IM-1 lands.
- 2026-10-21T23:35Z: IM-1 #4028 still waits on supervisor merge; IM-2 ready (775148e3).
- 2026-10-22T00:00Z: IM-1 #4028 still waits on supervisor merge; IM-2 ready (775148e3).
- 2026-10-22T00:22Z: IM-1 #4028 still waits on the supervisor (Package.swift). IM-2 is gated on lead/suite-imaging-IM-2 (775148e3), and its PR opens once #4028 is on dev.
- 2026-10-22T00:44Z: IM-1 #4028 now has dev merged in (head c5ab15b) and still waits on the supervisor. IM-2 is merged onto that head and pushed (26ba4c88); the scripts/ci --changed re-gate is running.
- 2026-10-22T00:55Z: IM-2 re-gate on IM-1 c5ab15b: CI FAIL only on dev's red FormatListRatchetTests (fixed by #4258, not IM-2's). Merge dev and re-gate once #4258 and #4028 land, then open the PR.
- 2026-10-22T01:06Z: IM-1 #4028 still waits on the supervisor; IM-2 holds at 26ba4c88 until #4028 and #4258 land.
- 2026-10-22T01:28Z: IM-1 #4028 still waits on the supervisor; IM-2 holds at 26ba4c88.
- 2026-10-22T01:35Z: IM-2 ready on 26ba4c888, waits for IM-1 #4028 (supervisor merge, Package.swift).
- 2026-10-22T01:50Z: IM-1 #4028 still open (supervisor merge); IM-2 ready on 26ba4c888.
- 2026-10-22T02:10Z: IM-1 #4028 still open (supervisor merge); IM-2 ready on 26ba4c888.
- 2026-10-22T02:30Z: IM-1 #4028 still open (supervisor merge); IM-2 ready on 26ba4c888.
- 2026-10-22T02:43Z: IM-1 #4028 is still open (head 4c8262db). It edits a protected path, so it needs a supervisor merge; the lane relabels it on every sweep. IM-2 is ready on 26ba4c888 and opens after IM-1 merges.
- 2026-10-22T03:04Z: Rule 23: IM-1 #4028 has been unchanged for three polls (mergeable and clean, head 4c8262dbb). I posted a Question for the supervisor on #3715 (comment 6331661077). IM-2 is still ready on 26ba4c888.
- 2026-10-22T03:24Z: No supervisor reply yet on #3715. IM-1 #4028 is still open (clean, head 4c8262dbb). IM-2 is held.
- 2026-10-22T03:45Z: Unchanged. No reply on #3715, #4028 is still open, and dev is still at b5a6e7e0a. IM-2 is held.
- 2026-10-22T04:06Z: Unchanged. No reply on #3715, and #4028 is still open. IM-2 is held.
- 2026-10-22T04:23Z: Supervisor answered on #3715 at 03:06Z. #4028 is 4th in the local Mac gate queue, and they merge it once it passes. No pushes to it in the meantime. IM-2 is held until it merges.
- 2026-10-22T04:44Z: #4028 is still open. Its head moved to e48f3225 (not my push; base is now dev 8a1d65345), and it is in the supervisor's Mac gate queue. IM-2 is held until it merges.
- 2026-10-22T05:05Z: #4028 is still open on head e48f3225, in the supervisor's Mac gate queue. IM-2 is held.
- 2026-10-22T05:25Z: #4028 is still open, clean on head e48f3225, in the supervisor's Mac gate queue. IM-2 is held.
- 2026-10-22T05:47Z: #4028 (IM-1) open and clean at e48f3225, in the supervisor's Mac gate queue; IM-2 waits on its merge.
