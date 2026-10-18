# timeline lead record

Issue: #1480 · Packet: docs/blueprints/suiteui/features/timeline.md
Run: act-1a149babb21-udz7 (line lead with #1079, #1480, #1596; earlier act-1a1487bf89a-zfq8) · Session: claude/suiteui-feature-lead-t357v5 · Started: 2026-10-16T18:10Z (this run 2026-10-17T06:10Z)
Stage: 3 wave 11 (checked)
Base: 9ba6658425c543613715ebbf34d677a380ef8cc3
Next: #2629 (round 1) in the lane; round 2 fixer on #2501/#2503 opens one PR; anything still open after it becomes gap.

TL-a to TL-e are merged-done on full run 39001215720 (bd11faf7, Linux green); their `Belt-Slice-Done:` and `Mac-Finish-Wanted:` lines are on #1480 (2026-10-17T06:3xZ), with `Mutate: macOS pending` per the Q10 decision. TL-f (the 2026-10-17 amendment) is the work left: TL-20 → TL-21 → TL-22 → TL-23 (`feature-done`), one per wave, then the contact sheet.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TL-a | API, contracts and the gallery pages, drawn as today | TL-1, TL-2, TL-3, TL-4 | SJ0 | suite-harness (closed) | true | 0 | done | 39001215720 | wanted |
| TL-b | Lane beds, clips, key states, playhead pill, pinned ruler, hover, 16 pt hits | TL-4b, TL-5, TL-6, TL-7, TL-8, TL-9 | SJ19a, SP3 | TL-a | true | 2 (cap) | done, gaps #1735-#1744 #1782 #1784 | 39001215720 | wanted |
| TL-c | Pick by click/Shift/⌘/right-click, bed clears, ← →, VoiceOver | TL-10, TL-11, TL-12 | SJ19b | TL-a, TL-b | true | 1 (+1 in wave 10: #1783) | done | 39001215720 | wanted |
| TL-d | Group key drag with snapping, clip trim, one step per drag | TL-13, TL-14, TL-15 | SJ19c, SP8 | TL-a, TL-c | true | 0 (+1 in wave 10: #1795 #1796) | done | 39001215720 | wanted |
| TL-e | Zoom, sideways scroll, frames/timecode, work area | TL-16, TL-17, TL-18, TL-8b, TL-19a, TL-19b | SJ19d | TL-a, TL-b, TL-c, TL-d | true | 0 (+1 in wave 10: #1813) | done | 39001215720 | wanted |
| TL-f | Lanes drawn in one AppKit view, a CALayer per lane; pick, key drag and trim on that view at 0 lane bodies | TL-20, TL-21, TL-22, TL-23 | SJ19e | TL-b (TL-20, TL-21), TL-d (TL-22), TL-c (TL-23) | true | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TL-1 | TL-a | 1 | Three timeline contracts and their Fakes | Contracts/TimelineMapping.swift, Contracts/KeyEditing.swift, Contracts/TimelineEditing.swift, Tests/SuiteUITests/TimelineFakeTests.swift | TimelineFakeTests | #1531 | merged 5ecd0ad |
| TL-2 | TL-a | 1 | Cut TimelineStrip.swift into seam files, bodyRuns counters, safe-area guard | TimelineStrip.swift, TimelineLane.swift, TimelineLaneInput.swift, TimelineLaneAccess.swift, TimelineRuler.swift, TimelinePlayhead.swift, TimelineStrip+Keys.swift, TimelineStripSafeAreaTests.swift | existing tests + TimelineStripSafeAreaTests | #1532 | merged 13cb9be |
| TL-3 | TL-a | 2 | Additive API: TimelineKey, shapes, pickedFrames, new inputs and closures | TimelineTrack.swift, TimelineStrip.swift, TimelineTrackTests.swift, mutations TimelineTrack | TimelineTrackTests | #1569 | merged 98414eb |
| TL-4 | TL-a | 3 | Gallery timeline pages over the new API | Gallery/GalleryTimeline.swift | SJ0 | #1602 | merged fce7e9a |
| TL-4b | TL-b | 4 | Drop timeline-long's outer ScrollView; ruler identifier | Gallery/GalleryTimeline.swift | SJ0, SJ19a | #1619 | merged 0529325 |
| TL-5 | TL-b | 3 | TimelineLook rules; SJ19a, SP3, scrub budget skipped | TimelineLook.swift, TimelineLookTests, mutations TimelineLook, UITests +Timeline, ScrubWindowTests | TimelineLookTests | #1605 | merged |
| TL-6 | TL-b | 4 | Lanes: bed, clips, key states/shapes, tween, hover, 16 pt hit | TimelineLane.swift, TimelineLaneInput.swift, TimelineLaneTests, SuiteTimelineSnapshots, mutations Lane, LaneInput | TimelineLaneTests | #1623 | merged 3b59dc5 |
| TL-7 | TL-b | 3 | Pinned ruler over lazy lanes, ideal height, #219 width, QB-S11 | TimelineStrip.swift, TimelineStripLayoutTests, TimelineBudgetTests, mutations Strip | TimelineStripLayoutTests | #1606 | merged ebe0744 |
| TL-8 | TL-b | 5 | Playhead line, pill, grab band, changed-frame scrub; enables SJ19a, SP3 | TimelinePlayhead.swift, TimelineRuler.swift, TimelinePlayheadTests, mutations Playhead, UITests +Timeline, ScrubWindowTests, +Budgets | TimelinePlayheadTests | #1657 | merged 4347bc7 |
| TL-9 | TL-b | 6 | Golden baselines timeline, -clips, -hover | Golden/timeline/ | golden checks | #1756 | merged 3799455 |
| TL-10 | TL-c | 2 | SuiteKeyEditing and pick rule; SJ19b skipped | TimelineKeys.swift, TimelineKeysTests, mutations Keys, UITests +TimelineKeys | TimelineKeysTests | #1571 | merged 5be83d3 |
| TL-11 | TL-c | 5 | Pointer picking on lanes | TimelineLaneInput.swift, TimelineLanePickTests, mutations LaneInput | TimelineLanePickTests | #1647 | merged 1a2f0ef |
| TL-12 | TL-c | 6 | Focus ring, ← →, key a11y children, lane value; enables SJ19b | TimelineLaneAccess.swift, TimelineStrip+Keys.swift, TimelineAccessTests, mutations LaneAccess, Strip+Keys, UITests +TimelineKeys | TimelineAccessTests | #1680 | merged e8a1545 |
| TL-13 | TL-d | 3 | SuiteTimelineEditing snap/trim, drag step rule; SJ19c, SP8, key-drag budget skipped | TimelineEdits.swift, TimelineEditsTests, mutations Edits, UITests +TimelineDrag, KeyDragWindowTests | TimelineEditsTests | #1607 | merged ecd7137 |
| TL-14 | TL-d | 6 | Key drag on lanes; enables key-drag budget | TimelineLaneInput.swift, TimelineKeyDragTests, mutations LaneInput, KeyDragWindowTests | TimelineKeyDragTests | #1681 | merged 7ea9c39 |
| TL-15 | TL-d | 7 | Trim clip ends; enables SJ19c, SP8 | TimelineLaneInput.swift, TimelineTrimTests, mutations LaneInput, UITests +TimelineDrag | TimelineTrimTests | #1770 | merged 96bd5d9 |
| TL-16 | TL-e | 2 | TimelineZoom and TimelineTime rules; SJ19d skipped | TimelineZoom.swift, TimelineTime.swift, TimelineNavTests, mutations Zoom, Time, UITests +TimelineNav | TimelineNavTests | #1575 | merged 287443c |
| TL-17 | TL-e | 4 | Zoom keys, pinch, toolbar row, sideways scroll | TimelineStrip.swift, TimelineToolbar.swift, TimelineToolbarTests, mutations Strip, Toolbar | TimelineToolbarTests | #1620 | merged 5c1742f |
| TL-18 | TL-e | 6 | Units chips, ruler/pill unit text, work area | TimelineToolbar.swift, TimelineRuler.swift, TimelineRulerUnitTests, mutations Toolbar, Ruler | TimelineRulerUnitTests | #1686 | merged 4eff5af |
| TL-8b | TL-e | 7 | Lanes outside the work area dim to 60% | TimelinePlayhead.swift, TimelinePlayheadTests, mutations Playhead | TimelinePlayheadTests | #1707 | merged caa3c66 |
| TL-19a | TL-e | 8 | Toolbar snapshot assertion + enable SJ19d | SuiteTimelineSnapshots, UITests +TimelineNav | SJ19d | #1775 | merged 8fdf407 |
| TL-19b | TL-e | 9 | Toolbar goldens, wave.json built; feature-done | Golden/timeline (4 PNGs), timeline.wave.json | golden checks | #1817 | merged db0495c |
| fix-1800 | TL-c | 9 | Lane and key ids, visible-only key children, journey lookups | TimelineLaneAccess.swift, journeys | SJ19b | #1810 | merged 0637138 |
| fix-1745 | TL-b | 9 | Oracle: fractional rows in TimelinePlayhead.rows | TimelinePlayheadTests, mutations Playhead | TimelinePlayheadTests | #1749 | merged |
| fix-w11 | TL-a, TL-c, TL-d, TL-e (+TL-b gaps) | 10 | CI findings #1781 #1783 #1795 #1796 #1813 (and gaps #1782 #1784, same causes): unlabelled vertical scroller, ScrollView hit point on lane lookups, SP8 page id, drag +4 for +5, ⌘+ focus | journeys, GalleryTimeline.swift, TimelineStrip.swift, TimelineLaneInput.swift (as the batcher groups them) | the journeys on the next scoped run | #2048 | open, dev merged by the lead (f81b5240, gate pass), also Fixes #2059; waits on the lane |
| fix-2002 | TL-f | 11 | #2012 audit scroller on the strip (red-triage blamed #2002; not its cause: same failure before #2002) | TimelineStrip.swift | scoped suiteui journeys | #2049 | merged 45a27f3 (Fixes #2012, Refs #2014: no live probe sink, out of scope) |
| TL-20 | TL-f | 10 | TimelineLaneLayers rules (dirty diff, lane frames, press routing through TimelineLaneInput's classification); SJ19e written and skipped; lanes window budget disabled | TimelineLaneLayers.swift, TimelineLaneLayersTests, mutations LaneLayers, UITests +TimelineLanes, SuiteTimelineLanesWindowTests | TimelineLaneLayersTests | #2002 | merged a639f8c |
| TL-21 | TL-f | 11 | TimelineLanesView (NSView, a CALayer per lane drawn with TimelineLook via CoreGraphics, redraw only dirty lanes) and the TimelineLanes representable; TimelineLane becomes its host | TimelineLanesView.swift, TimelineLane.swift, TimelineLanesViewTests, SuiteTimelineSnapshots, mutations Lane | TimelineLanesViewTests | – | waits TL-20 |
| TL-22 | TL-f | 12 | Pointer input on the view routed to TimelineLaneInput's classification; enables the lanes budget | TimelineLaneInput.swift, TimelineLanesView.swift, TimelineLanesInputTests, mutations LaneInput, SuiteTimelineLanesWindowTests | TimelineLanesInputTests | – | waits TL-21 (TL-15 merged) |
| TL-23 | TL-f | 13 | Key accessibility children on the view; enables SJ19e; lane baselines; feature-done | TimelineLanesView+Access.swift, TimelineLanesAccessTests, UITests +TimelineLanes, Golden/timeline-lanes/, timeline.wave.json | TimelineLanesAccessTests, SJ19e | – | waits TL-22 (TL-12, TL-19 merged) |

Waves 1 to 9 as the earlier record (packet waves checked against dev). Wave 10 (this run): TL-20 alone as a feature task (its five files are new), beside the fix batch for the 7 open CI findings and the TL-a and TL-e critic panels; TL-20's waits (TL-6) are met. TL-21, TL-22 and TL-23 each wait on the previous one's merged code (TimelineLane.swift → TimelineLanesView.swift → TimelineLaneInput.swift chain), so they are one per wave.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| TL-a..TL-d | 38983393903 | 2be6a10 | CI only | #1800 | – |
| TL-b | 38967063787, 38971697983 | 5c1742f, 4347bc7 | CI only | #1659, #1693 | 0, 1 |
| TL-b | 38977886661 | a7c34b4 | CI; clarity, design, layout, taste, oracle | #1728; #1735-#1745 | 2 (cap) |
| TL-a..TL-e | 39001038692 (scoped suiteui, journeys ran) | e251c5c5 | CI findings (ci.yml's Findings step) | #1777 #1778 (editor-in-window); #1781 #1782 #1783 #1784 #1795 #1796 #1813 | – |
| TL-a | 39001038692 | e251c5c5 | clarity, journey, design, layout, controls, oracle, mouse, taste | running (wave 10) | 0 |
| TL-e | 39001038692 | e251c5c5 | clarity, journey, design, layout, controls, oracle, mouse, taste | running (wave 10) | 0 |

## Decisions
- Base is `dev`, not `main`: CLAUDE.md and the lane put every crew PR on dev (fast-lane.sh BASE_BRANCH=dev); the status branches `lead/<feature>` sit on main as Belt asked.
- Builder branches are `lead/timeline/<task>` from the templates; `gh`'s GraphQL is blocked here (403), so agents use the GitHub MCP tools (template copies in the scratchpad carry that note).
- The cloud container had no Swift; `scripts/cloud-setup.sh` installed 6.3.3 so builders can run `scripts/ci --changed`.
- SuiteUI mutation plans run on the Mac (Q10 decision, #1480 2026-10-17T06:06Z): slices are merged-done on the Linux-green run with a `Mutate: macOS pending` line and a `Mac-Finish-Wanted:` line each; the finisher scores them.
- #1782 (SJ19a) and #1784 (SP3) are TL-b journeys and TL-b's rounds are spent, so they are `gap` now; they share a cause with #1783 and #1781, so the wave-10 fix batch still fixes them (Fixes #n on the PR).
- With #1782 and #1784 relabelled, 5 findings stay open (#1781 #1783 #1795 #1796 #1813), so rule 10 lets TL-20 start beside the fixes.
- TL-f joined the record at this check (packet amendment, #1480 comment 2026-10-16T19:52Z); no earlier slice or task id changed. TL-23 carries `feature-done` again, after #1817 already did.
- Reviews: TL-a (SJ0 screens) and TL-e (SJ19d screens) are reviewable on 39001038692 and get their panels now with `ui: true`; TL-c and TL-d get theirs on the first run whose SJ19b and SJ19c screens exist past the failing step.
- Earlier decisions (TL-4b, TL-8b, TL-19 split, #1728 past the cap, the identifier prefix, #63 closure) stand as in the previous record.

## Open
- Mac mutation scores for the 15 SuiteUI timeline plans (Q10): the Mac finisher runs them per slice (Mac-Finish-Wanted lines posted).
- Gaps (TL-b, past its cap): #1735 #1736 #1737 #1739 #1740 #1741 #1742 #1743 #1744 #1782 #1784.
- needs-ui on the strip from other lines: #1842 (key child identifiers, adjacent keys overlap, unlabelled button), #1789 (track names and lanes lost the caller's identifier); the unlabelled button is the same scroller as #1781.
- `suiteui-timeline-long` isn't asserted as a golden.

- 2026-10-17T13:44Z heartbeat: dev moved to d2c4fa2 (GalleryAppMarks.swift conflict, resolved to dev's side; dev dropped that scroll view). #2048 merged dev, gate CI: PASS, pushed head 3c7b9713, Head line moved. Scoped suiteui 39034310918 on 45a27f3 (pre-#2048): the timeline journeys still red as expected; findings updated. Open suiteui findings: 7 (6 close with #2048, leaving #2014). Next: #2048 waits on the lane's macOS build; TL-21 starts once it merges.

- 2026-10-17T14:08Z heartbeat: the lane's macOS build 39038062743 of #2048 (3c7b971) failed: TimelineKeyDragTests.swift:109 called mutating release(atDX:) inside #expect. Fixed by binding a let, merged dev 25b220e, gate CI: PASS, pushed ff00c03f, Head moved. Open suiteui findings: 7 (#2048 closes 6). Next: the lane's macOS build of ff00c03f; TL-21 once #2048 merges.

- 2026-10-17T14:29Z heartbeat: #2048 head ff00c03f is mergeable (clean on dev 25b220e). The lane's Linux check 39039476815 has run, and its macOS build 39040114342 started compiling at 14:29. The needs-rebase label is left over from the old head. TL-21 still held: 7 suiteui findings open.

- 2026-10-17T14:55Z heartbeat: #2048 head ff00c03f is green: the lane's Linux check 39039476815 and its macOS build 39040114342 (14:35) both passed. It still merges cleanly onto the new dev 2c5003b. The needs-rebase label doesn't block it (the lane removes it on merge), so a later sweep merges it; the lane is busy with other PRs. TL-21 still held until it merges.
- 15:18 heartbeat: #2048 (ff00c03f) open, CLEAN; lane sweep 39043553076 marks it eligible (5 checks green, macOS build 39040114342). Waiting for the next batch: batch-20261017145213 is still bisecting. TL-21 is held until it merges (7 open suiteui findings, #2048 closes 6).
- 15:40 heartbeat: #2048 merged 15:24 (closed 6 suiteui findings). 1 open suiteui finding (#2014), at most 5, so wave 12 starts: TL-21 (TL-f) via build-wave.js run wf_08169eaf-dfa on dev dd7ec767. TL-22 waits on TL-21's merge.
- 16:02 heartbeat: scoped suiteui 39044925054 on a81dd8d (#2048 merged) filed new findings. TL-b's rounds are spent, so #2141 (SJ19a) and #2014 (SP3) are now gap p2. TL-d round 2 (#2139 SP8, #2140 SJ19c) and TL-e round 2 (#2142 SJ19d) run as fix-batch.js wf_be3a4e60-622 on a81dd8d, with TL-21's files marked busy. Open suiteui findings: 3. TL-21 (wf_08169eaf-dfa) is still building; no PR yet.
- 2026-10-17T16:14:53Z wave 12: TL-21 (TL-f) opened #2172, head f2812ff8, 4 files, fast-lane; body footer stripped. Fix-batch wf_be3a4e60-622 (#2139, #2140, #2142, TL-d/TL-e round 2) running on a81dd8d. Open suiteui findings: 3. Next: TL-22 once #2172 merges.
- 2026-10-17T16:22:23Z fix round 2 (wf_be3a4e60-622) done: #2174 fixes #2140 (TL-d, head ae8ecc62), #2173 fixes #2142 (TL-e, head d052c3e5); bodies given Slice lines, footers stripped. #2139 (SP8, needs a live ProbeSample sink in SuiteEnvironment, same cause as #2014) moved to gap p2: TL-d round cap.
- 2026-10-17T16:24:55Z lane: macOS build-only runs pending (#2164 39048266848, #2165 39048279341, #2170 39048893207, #2172 39048907052); #2173/#2174 not swept yet. Stripped tooling footers from this run's issue comments (#2014, #2069, #1079, #2137, #2138, #2139, #2141).
- 2026-10-17T16:49:40Z #2172 (TL-21) failed its macOS build (run 39048907052): TimelineLanesViewTests nested a #require inside another. Fixed in d2c14d3, gate passed, Head moved. Fix PRs #2173/#2174 waiting on their macOS builds. Open suiteui findings: 2 (#2140, #2142, fixed by #2174/#2173).
- 2026-10-17T17:11Z heartbeat: macOS builds green on #2172 (TL-21, d2c14d3, run 39051951467), #2173 (TL-e fix, 39049590221), #2174 (TL-d fix, 39049603673); all await a lane batch. Open suiteui findings 2 (#2140, #2142), fixes in #2174/#2173. TL-22 waits on #2172's merge. The lane is running batch Linux checks against dev-red #2191 (Design scrubStep wall-clock flake, Design's, not ours).
- 2026-10-17T17:33Z lane merged #2172 (TL-21), #2173 (fixes #2142, TL-e) and #2174 (fixes #2140, TL-d) at 17:19-17:20 in batch run 39052683567; #2140 and #2142 closed. Open suiteui findings 0. Wave TL-22 (TL-f) launched on base ec0e979b (workflow wf_8a823174-494). Scoped suiteui run 39053741673 on ec0e979b is running; when green it is the Belt-Slice-Done run for TL-d (SJ19c, SP8; gap #2139) and TL-e (SJ19d).
- 2026-10-17T17:59Z heartbeat: scoped suiteui 39053741673 on ec0e979b: SJ19c passes (#2228 closed, it was filed from the older 4cc9e6f4); SJ19d moved past zoom to the pill timecode assert, so #2209 is gap p2 (TL-e cap); SP8, SJ19a and SP3 failures were duplicates of gaps #2139, #2141 and #2014 (closed as dup); editor-window #2204 dup of #2137. Posted Belt-Slice-Done TL-d (gaps #2139) and TL-e (gaps #2209). TL-22 opened #2232 (2923545e, TL-f), lane macOS build 39056045587 queued. Open suiteui findings: 0. Next: TL-23 after #2232 merges.
- 2026-10-17T18:25Z heartbeat: #2232 (TL-22) macOS build fixed in fbce7f21 (TimelineLaneActions required args), Head moved; awaiting lane build+batch. TL-23 waits on #2232. 0 open suiteui findings.
- 2026-10-17T18:49Z heartbeat: #2232 (TL-22) macOS build 39057981504 green, clean, awaiting lane batch; TL-23 waits on it. Scoped 39055931043 findings closed as duplicates of existing gaps (#2251->#2139, #2252->#2141, #2253->#2014, #2254->#2209). 0 open suiteui findings.
- 2026-10-17T19:14Z heartbeat: #2232 (TL-22) merged (batch 39059658677). TL-23 (feature-done) launched (wf_379ba5a4-9f7) on 6ad373ab. 0 open suiteui findings.
- 19:26 heartbeat: TL-23 PR #2279 open (fast-lane, feature-done), footer stripped; awaiting lane macOS build
- 19:38 heartbeat: TL-23 #2279 macOS build 39062438016 green, awaiting lane merge; scoped suiteui 39059622292 (13911964) skips SJ19e, pre-TL-23; closed dup findings #2273-#2278; open suiteui findings 0
- 20:07 heartbeat: TL-23 #2279 got needs-fix: lane Linux run 39062922557 fails only DesignStyleBudgetTests/scrubStep (Design timing gate, 5.06ms>5ms), not ours; dev-red #2303, fix claimed by style-rows lead; standing-down comment posted; will merge dev once fixed. Closed dup findings #2297-#2301,#2304
- 20:34 heartbeat: TL-23 #2279 still blocked on dev-red #2303 (DesignStyleBudgetTests scrubStep); no fix on dev yet. TL-f Slice-Done waits for the merge and SJ19e.
- 21:02 heartbeat: Merged origin/dev (with Design perf fix #2308) into lead/timeline-TL-23 (#2279); scripts/ci --changed running before push.
- 21:10 heartbeat: #2279 (TL-23): merged origin/dev, scripts/ci --changed PASS, pushed e0049ee5, Head moved; lane dropped needs-fix.
- 21:38 heartbeat: Dup findings #2391-#2396 closed. TL-23 #2279 (head e0049ee5, dev merged after #2308) waits on the lane's macOS build; then SJ19e scoped run, Slice-Done TL-f and contact sheet.
- 22:05 heartbeat: TL-23 #2279 merged (bc252a71). Scoped suiteui 39072524910 is on 499d955e, before it; SJ19e proof comes from full CI 39072812111 on 2b08e8fd or the next scoped suiteui run. Then Slice-Done TL-f and contact sheet on #1480.
- 22:32 heartbeat: Scoped suiteui 39074593951 on 178e59db (includes #2279) is in progress; TL-f Slice-Done and the contact sheet follow if SJ19e passes. Dups #2428-#2433 closed.
- 23:01 heartbeat: Scoped suiteui 39074593951 on 178e59db (TL-23 merged): SJ19e (testTimelineLanesDragWithoutBodies) fails with 'no timeline-long page'. The test waits on suite.gallery.timeline instead of suite.gallery.timeline-long, a stale pre-#2048 shape. Finding #2450 is TL-f fix round 1 (wf_5b4383b3-cd1 on 59c435a6, UITests +TimelineLanes only). Closed dups #2447->#2137, #2448->#2138, #2449->#2139, #2451->#2141, #2452->#2014, #2453->#2209. Open suiteui findings: 1. Next: the round-1 PR merges, then a scoped suiteui run, then Slice-Done TL-f and the contact sheet.
- 23:07 heartbeat: TL-f round 1: #2458 (Fixes #2450, head 3486760d, 1 file, +57/-13) opened fast-lane; body clean. Waits on the lane's macOS build, then a dev run with SJ19e.
- 23:27 heartbeat: #2458 merged 23:14 (e26c99f8; #2450 closed). Full CI 39078267798 on e26c99f8 is pending; it is SJ19e's proof run. Open suiteui findings: 0. Next: read it, then Slice-Done TL-f and the contact sheet.
- 00:01 heartbeat: Full CI 39078267798 was cancelled; scoped suiteui 39078610003 on e26c99f8 is the proof. SJ19e passes the page, the key drag and the trim; it fails only 'series key-drag has 0 samples', the cause of gap #2139. Posted Belt-Slice-Done TL-f (gaps #2139) and Belt-Contact-Sheet on #1480; no round 2 (the cause is outside TL-f). Closed dups #2472-#2478. timeline closed out: TL-a to TL-f done.
