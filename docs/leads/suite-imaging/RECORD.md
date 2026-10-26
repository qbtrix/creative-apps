# suite-imaging lead record

Issue: #3715 (#4498 closed) · Packet: docs/blueprints/suiteui/features/suite-imaging.md
Run: act-1a175ea55b7-729d (line lead, line:suiteui; relaunch 2026-10-26) · earlier: act-1a170cfbf58-pshm (resumes act-1a16d523b32-v6tj and earlier) · Started: 2026-10-24
Stage: #5295/#5297/#5299 open (fast lane), #5178 and #5780 (IM-13, Package.swift) await the supervisor
Base: origin/dev 8eff8ab85
Next: IM-13 PR (supervisor merge: Package.swift), then IM-14


## Run act-1a175ea55b7-729d decisions
- Brief rule 1: main checked out at d3323f6a7; main was rewritten, so each lead branch is rebuilt as origin/main plus this record (no merge base with the old branch), pushed --force-with-lease.
- PR base stays `dev` (CLAUDE.md; BASE_BRANCH=dev in scripts/fast-lane.sh; the lane retargets main PRs).
- Stacked PRs whose parent squash-merged carry the parent's commits (size FAIL, dirty): merge origin/dev into each branch, gate, move Head.
- #5148 (f4463d48c), #5151 (5eb2fa737), #5153 (f7c2ab5bb) merged; IM-photo still needs IM-8d (#5295, #5297), IM-library IM-11 (#5154, #5163, #5178).
- 2026-10-26T03:07:58Z: masked-layer cpu op (#5216) merged into IM-8d; liveStack treats any masked layer as unsupported on IM-8d-photo; IM-11a/b take dev (LG-6 decodes ahead kept on the GPU loupe render).
- 2026-10-26T03:30:04Z heartbeat: #5295 #5297 #5299 #5154 #5163 #5178 open and clean; IM-13 after #5163
- 2026-10-26T04:01:17Z heartbeat: #5295..#5299 #5154..#5178 open and clean; ratchet checked; IM-13 after #5163
- 2026-10-26T04:22:59Z heartbeat: all PRs open and clean, no labels; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T04:53:11Z heartbeat: #5154 (IM-11a) merged; #5163 and #5178 merged origin/dev (mutation plan add/add kept ours, a superset), gate PASS, Heads moved
- 2026-10-26T05:15:11Z heartbeat: all open PRs clean, no needs-fix/needs-rebase; #5297/#5299 over the size cap until #5295 lands; dev-red #5321 open (not ours)
- 2026-10-26T05:37:33Z heartbeat: no change: all open PRs clean, no labels to fix; dev-red #5321 open (not ours)
- 2026-10-26T06:00:09Z heartbeat: no change; lane holding (dev-red #5321 open)
- 2026-10-26T06:28:20Z heartbeat: no change; lane holding (dev-red #5321 open)
- 2026-10-26T06:53:25Z heartbeat: no change; lane holding (dev-red #5321 open); drift sweep has filed nothing on this feature yet
- 2026-10-26T07:15:52Z heartbeat: no change; lane holding (dev-red #5321 open); drift sweep filed nothing on this feature
- 2026-10-26T07:34:19Z heartbeat: #5295/#5297/#5299/#5163/#5374 clean, fast-lane queue; #5178 supervisor
- 2026-10-26T07:56:21Z heartbeat: #5295/#5297/#5299/#5163/#5374 clean, fast-lane queue; #5178 supervisor; new drift issues none on suite-imaging
- 2026-10-26T08:22:21Z heartbeat: no merges; dev-red #5321 (macos) holds code batches; PRs clean
- 2026-10-26T08:42:54Z heartbeat: no merges; #5297/#5299 lost fast-lane (over cap only while stacked on #5295): restack and relabel when #5295 merges
- 2026-10-26T09:03:26Z heartbeat: no merges; #5297 relabelled fast-lane by lane, #5299 waits on #5295 restack
- 2026-10-26T09:22:44Z heartbeat: no merges; dev-red holds code batches; #5297/#5299 wait on #5295 restack
- 2026-10-26T10:03:23Z heartbeat: #5297 merged dev (resolved: dispatcher-route kept bases from dev's Move fix now live in LiveCompositeCache), gate pass, head e27f0956d; #5299 restacked, head 1dbc6c5e4
- 10:26 heartbeat: #5163 merged; #5178 with supervisor; IM-13 started (ST-a done)
- 10:47 heartbeat: IM-13 built (Library develop steps from SuiteImaging, Metal rule with no baseline); gate rerun, PR next
- 11:32 heartbeat: #5297/#5299 restacked on dev (PhotoCompositeCache alias over LiveCompositeCache for dev's Curves histogram cache); IM-13 PR #5780 opened
- 2026-10-26T12:00:09Z heartbeat: all PRs open and clean; #5780 needs captain review (Package.swift); batches held while dev-red #5321 is open (not ours)
- 2026-10-26T12:33:28Z heartbeat: no change: all PRs open and clean, no needs-fix/needs-rebase; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T13:09:30Z heartbeat: no change: all PRs open and clean; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T13:38:34Z heartbeat: no change: all PRs open and clean; batches held while dev-red #5321 is open (not ours)
- 2026-10-26T14:12:29Z heartbeat: no change: all PRs open and clean; #5780 back on fast-lane; dev-red #5321 open (not ours)
- 2026-10-26T14:32:38Z heartbeat: no change: all PRs open and clean; dev-red #5321 open (not ours)
- 2026-10-26T14:52:37Z heartbeat: #5780 (IM-13) merged 14:35Z as f86f72f79; IM-z waits on #5299 (IM-12), then IM-14
- 2026-10-26T15:18:44Z heartbeat: no change: open PRs clean, no needs-fix/needs-rebase; dev-red #5321 open (not ours)
- 2026-10-26T15:38:29Z heartbeat: no change: open PRs clean, no needs-fix/needs-rebase; dev-red #5321 open (not ours)
- 2026-10-26T16:09:52Z heartbeat: #5299 (IM-12) needs-fix from the Mac pre-screen (ambiguous ?? in LiveLayerRoute); fix committed, gate running
- 2026-10-26T16:41:43Z heartbeat: #5299 (IM-12) fix pushed as 11d1608e1 (typed stacks instead of an ambiguous ??), needs-fix dropped; its size note counts the unmerged parent #5297 (stack #5295 -> #5297 -> #5299)
- 2026-10-26T17:01:58Z heartbeat: #5295 clean in the lane, held by macOS dev-red #5321; #5297 and #5299 wait on it (their diffs carry the parent); #5178 waits on the supervisor; full CI 40357785665 running at 527676af6
- 2026-10-26T17:22:45Z heartbeat: #5295 eligible (marker plus local-ci/prescreen), waiting on a lane sweep; full CI 40366795361 running on dev at df48c0bac
- 2026-10-26T17:43:15Z heartbeat: #5295 eligible, #5297/#5299 stacked; #5178 with supervisor; dev-red #5321 holds code batches

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| IM-a | SuiteImaging target + live dependency rule; stubs | IM-1, IM-2 | MJ-IM | – | no | 0 | done | 39811900368 | – |
| IM-m | values, one step list, wide working space, live surface | IM-3, IM-4, IM-5, IM-15 | MJ-IM | IM-a | no | 0 | done | 39939121278 | – |
| IM-photo | Photo adjustments are SuiteImaging values; canvas on the shared route; PhotoLiveTone deleted | IM-6, IM-7, IM-8, IM-8d | MJ-IM-photo, PJ-IM | EP-z (IM-8d) | yes | 0 | building | – | – |
| IM-library | Library develop values are SuiteImaging values; loupe on the GPU route | IM-9, IM-10, IM-11 | MJ-IM-library, LJ-IM | – | yes | 0 | building | – | – |
| IM-z | copies deleted, rule with no baseline, feature built | IM-12, IM-13, IM-14 | MJ-IM, PJ-IM, LJ-IM | IM-photo, IM-library, ST-a | no | 0 | planned | – | – |

## Tasks
| id | slice | behavior | PR | state |
|---|---|---|---|---|
| IM-1, IM-2 | IM-a | target, boundary rule, stubs | #4028 | merged |
| IM-3 | IM-m | AdjustSettings clamp + keys | #4390 | merged |
| IM-4 | IM-m | one step list | #4393 | merged |
| IM-15 | IM-m | wide working space, display steps | #4389 | merged |
| IM-5 | IM-m | LiveToneSurface | #4590 | merged |
| IM-6, IM-7 | IM-photo | Photo adjustments through SuiteImaging | #4593 | merged |
| IM-17 | IM-photo | layered live tone base | #4620 | merged |
| IM-16 | IM-photo | ImagingGPU system backend, one-pass display | #4851 | merged |
| IM-8s | IM-photo | dispatcher route runs ImagingProgram's steps | #4856 | merged |
| IM-8a | IM-photo | Photo canvas files off Metal (ImagingGPU.Target, SuiteUI residentTarget) | #5148 | open (fast-lane, Fast-Check c0b53be) |
| IM-8b | IM-photo | live route's program from ImagingProgram (output levels) | #5151 | open (fast-lane, Fast-Check, mutate 5/5) |
| IM-8d | IM-photo | live route into SuiteImaging (LiveLayerRoute); Photo adapter; PhotoLiveTone deleted | #5295, #5297 | open (Fast-Check, mutate 6/6 + 5/5; stacked on #5151) |
| IM-9 | IM-library | Library imaging tests | #4591 | merged |
| IM-10 p1 | IM-library | develop levels/curve points are SuiteImaging's | #4886 | merged 5270bc4bc (11:36Z) |
| IM-10b | IM-library | LiveDevelop on the shared list | #5153 | open, clean at 001f38939, needs-rebase dropped by the lane (Fast-Check 001f389, mutate 8/8 + 4/4) |
| IM-11a | IM-library | loupe GPU frame (Model): LiveDevelop.steps, LiveLoupeImaging.gpuFrame, histogram from the CPU-developed preview | #5154 | open (fast-lane, Fast-Check 4d753ae, mutate 4/4; stacked on #5153) |
| IM-11b | IM-library | loupe view writes the GPU frame (ImagingGPU.display into the CanvasHost resident texture); LibraryDevelopLatencyTests on the GPU route | #5163 | open; the lane dropped fast-lane (869 lines against dev while stacked) and its Belt-Lead sweep re-adds it once #4886, #5153 and #5154 merge; mutate 7/7, CI: PASS at 805e3850e |
| IM-11c | IM-library | perf-suites line for LibraryDevelopLatencyTests; drop .disabled (supervisor-approved 6384762237) | #5178 | open, no-fast-lane (protected path), supervisor lands; stacked on #5163; CI: PASS |
| IM-12 | IM-z | delete Photo's copies (HueSaturation; GammaTrack and PhotoLevelsFormat stay: slider track and label format, not image math) | #5299 | open (Fast-Check, mutate 4/4; stacked on #5297) |
| IM-13 | IM-z | no-baseline rule, Photo's Metal link removed | – | wave 8 (ST merged; Package.swift: supervisor merge) |
| IM-14 | IM-z | feature-done | – | last |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-25T06:34Z: IM-12 keeps GammaTrack.swift and PhotoLevelsFormat.swift: they are the inspector's slider track and label formatting, which no shared module holds; only HueSaturation (image math) duplicated core. IM-13 starts after #5151 and #5163 merge: it would stack on two chains and edits Package.swift (supervisor merge).
- 2026-10-25T05:43Z: IM-8d re-cut. The 02:11Z builder found the task impossible while SuiteImaging route edits were off limits. SuiteImaging is this feature's own target, so the next builder moves Photo's live route into Sources/SuiteImaging/Route (Linux-safe, generic over ToneRendering/ResidentSurfaces, a write closure in place of MTLTexture). Photo adapts and PhotoLiveTone.swift is deleted. Split into two PRs if over 400 lines.
- 2026-10-25T02:11Z: IM-8d is more than a delete: on #5151's head PhotoTileUpdate still calls liveStack/liveRegion and PhotoRenderRoute holds PhotoCompositeCache, so the builder repoints them onto LayeredToneBase/LiveToneSurface. IM-13 needs both stacks (IM-8 Photo Metal gone, IM-11 Library loupe) and Package.swift, so it starts once #5151 and #5163 merge, not stacked across two chains. Open findings #5093-#5095 are fill-heal's, not ours.
- 2026-10-25T02:10Z: relaunch act-1a170cfbf58-pshm after the 16-hour limit. The brief names main as integration branch; PRs keep base dev (CLAUDE.md: main only takes dev SHAs that passed full CI). lead/suite-imaging rebased onto main. IM-8d's EP-z wait is met contract-first (EP-m Belt-Slice-Done on #3723, run 40077009798); IM-13's ST-a wait is met (shared-thumbnails #4950, #4951, #5102 merged).
- 2026-10-24: relaunch act-1a16d523b32-v6tj. IM-a and IM-m done (Belt-Slice-Done on 39939121278). IM-8 cut: IM-8a moves Photo's three canvas files off Metal through SuiteImaging (ImagingGPU.backend/Target, CanvasHostView.residentTarget), baseline down to Package.swift only; IM-8b moves the live route.
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
