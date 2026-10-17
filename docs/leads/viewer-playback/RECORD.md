# viewer-playback lead record

Issue: #1035 · Packet: docs/blueprints/halo/features/viewer-playback.md
Run: act-1a1429c87eb-3ecm (resumed 2026-10-16T02:50Z; first run act-1a13ed44a75-delk) · Session: claude/viewer-playback-np89e8 · Started: 2026-10-15T09:05Z
Stage: done
Base: 2b06454 (#1685 feature-done merged)
Next: nothing. Done: #1685 merged, dev CI runs green (journeys report-only), Belt-Contact-Sheet posted (issuecomment-6226965853). The supervisor drops the H-J13 quarantine entry; SuiteUI fixes #1789.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| VP-1 | 1 | draw-list rule in HaloDrawRules; LiveFrameDrawing(placing:) over it; FakeFrameDrawing thin wrapper; drawnSummary, worldBox(of:) | Live/HaloDrawRules.swift, Live/LiveFrameDrawing.swift, Fakes/FakeFrameDrawing.swift, FrameDrawingContractTests | FrameDrawingContractTests (fake + live) | #1090 | merged |
| VP-2 | 1 | LivePlaybackClock on Timeline.playbackFrame; FakePlaybackClock thin wrapper | Live/LivePlaybackClock.swift, Fakes/FakePlaybackClock.swift, PlaybackClockContractTests | PlaybackClockContractTests (fake + live) | – | building |
| VP-4a | 1 | outlines (rect, four-cubic ellipse) through HaloMatrix.apply, flattened; axis-aligned mask pick | Live/HaloOutlines.swift, HaloOutlinesTests | HaloOutlinesTests | #1069 | merged |
| VP-3 | 2 | playback workspace methods, never a step | HaloPlayback.swift, HaloPlaybackTests | HaloPlaybackTests | #1087 | merged |
| VP-4b | 2 | LiveFrameRendering solids + shapes; FrameRenderer onto it; nulls never count (#457) | Live/LiveFrameRendering.swift, FrameRenderer.swift, 4 test files | LiveFrameRenderingTests, FrameRenderingContractTests, HaloRenderTests | #1098 | merged |
| VP-7 | 2 | playback availability on | Availability/HaloAvailability+Playback.swift, HaloPlaybackAvailabilityTests | HaloPlaybackAvailabilityTests | #1085 | merged |
| VP-8 | 2 | HaloViewerCanvas draws viewerDrawList; preview snapshots | HaloViewerCanvas.swift, HaloWindow+Viewer.swift, HaloPreviewSnapshots | halo-preview-*.png | #1099 | merged |
| VP-5 | 3 | text pixels in LiveFrameRendering | Live/HaloTextPlacement.swift, Live/LiveFrameRendering.swift, LiveFrameRenderingTextTests | LiveFrameRenderingTextTests | #1111 | merged |
| VP-6 | 3 | budgets HB-2, HB-5, HB-11 | HaloViewerBudgetTests | HaloViewerBudgetTests | #1101 | merged |
| VP-10 | 3 | transport, display-link driver, playback routes | HaloTransport.swift, HaloPlaybackDriver.swift, HaloWindow+Playback.swift, 2 snapshot tests | HaloPlaybackDriverTests, halo-transport-*.png | #1097 | merged |
| VP-9 | 4 | HF-1 canvas equals render | HaloViewerFidelityTests | HaloViewerFidelityTests | #1125 | merged |
| VP-11 | 4 | H-J3 extended | UITests/HaloJourneyTests.swift | H-J3 on dev CI | #1102 | merged |
| VP-12 | 5 | H-J2, H-J4; feature-done | UITests/HaloJourneyTests+Viewer.swift, +Playback.swift | H-J2, H-J4 on dev CI | #1124 | merged |

Waves (packet's, checked against dev 2fc9b59): W1 VP-1, VP-2, VP-4a (all independent); W2 VP-3, VP-4b, VP-7, VP-8 (all independent); W3 VP-5, VP-6, VP-10 (all independent); W4 VP-9, VP-11 (both independent); W5 VP-12 alone.

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 4 (close) | 38952256967 scoped halo (1e91d349) | compile + Model green; H-J2, H-J3, H-J4, H-J13 PASS; only failure testEaseKeys (easing feature, not ours) | ours at or under baseline (no audit failure in our journeys) | journeys (budget spent: no new critics) | 1 (H-J13 play-once timing) | #1280, #1590 | yes for this feature |
| 4 | 38823367271 (f3b8987) | Linux red on PhotoEditBudgetTests (#851, not ours); macOS scripts/ci green; H-J2, H-J3 PASS; H-J4 + History FAIL: round 3 pills (#1258, #1260) push the transport and layer count past the content column at 1000 pt | ours: transport/layers off-column | journeys (panel skipped: regression first) | 2 (status bar overflow; then #1264 broke HaloTransportFitTests width bound, run 38829075229) | #1264, #1268, #1277 (run 38835566584: H-J2, H-J4, History PASS; H-J3 steps pass but audit unnamed 6>5 from inspector scroller, #1178; every-control judged Next by launch state) | no |
| 3 | 38808325928 (75492b1) | macOS scripts/ci green; H-J2, H-J3, H-J4 PASS; fidelity + driver suites pass; every-control: Loop changed nothing (pre-#1247) | viewer/playback/scrub screens add none; over-baseline overlap/unnamed from inspector keys + layer rows (other features) | clarity, journey, design, layout, controls | 9 (2 major transport hit size, 1 major H-J4 loop-wrap timing; minors: frame in readout, readout emphasis, no Go-to-Start shot, selection box, playhead pill, clip blocks) | #1258, #1259, #1260; #1257 needs-ui; #273 comment | no |
| 2 | 38799320916 (3dc283e) | macOS scripts/ci green; H-J3 PASS; H-J2 fails on new solid name (Solid 2 vs packet's Solid 1); H-J4 Space doesn't start play after lane click | offscreen still over (#1178, not ours) | journeys + every-control (panel next round) | 3 (H-J4 step-5 timing; H-J2 name; Loop state invisible) | #1246, #1247 | no |
| 1 | 38767265986 (d95c756) | macOS scripts/ci green; ui-test red: H-J2/H-J3/H-J4 fail reading artboard value (empty, #262); halo offscreen 21 vs 8 and transport offscreen from inspector overflow (#1178, not ours) | over baseline (offscreen, overlap) | journeys + audit (panel deferred: journeys stop at step 1) | 3 (summaries unreadable by value; overflow pushes transport off; H-J3 shots raise offscreen) | #1211; #1178 comment | no |
| 0g | 38762922782 (a476a74) | red: only keyedFrame6, canvas [124,60,55] vs render [160,65,56] at (260,0); no hang (buffered output) | n/a | – | ImageRenderer mixes in sRGB | #1194 | no (not counted) |
| 0f | 38757068610 (111c440) | red: only keyedFrame6 (40000 px, opacity 0.5) still; HaloPlaybackDriverTests passed (207 s) | n/a | – | opacity mismatch persists after #1163 | #1189 (diagnostics) | no (not counted) |
| 0e | 38748468768 (3d42e80) | red: LibraryApp compile error (not this feature), fixed by #1175 | n/a | – | – | – | no (not counted) |
| 0d | 38743186679 (8e83ac0) | red: driver tests still over 60 s (185 s main-actor queueing), keyedFrame6 (pre-#1163) | n/a | – | queueing | #1171 | no (not counted) |
| 0c | 38738075349 (79bd068) | red: 5 driver tests over 60 s (main actor starved by HaloViewerFidelityTests ~5 min) + keyedFrame6 opacity diff | n/a | – | starvation, opacity | #1157 (disable), #1160, #1161 | no (not counted) |
| 0b | 38734211999 (35a875b) | red: macOS swift test stopped mid-run, HaloPlaybackDriverTests started a real CADisplayLink | n/a | – | hang | #1145 | no (not counted) |
| 0 | 38731305776 (7f61259) | red: AppSnapshotTests compile error, no journeys ran | n/a | – | build break | #1136 | no (not counted) |

## Decisions
- The lane refused #1590's first head (UITests/quarantine.json is protected). Its quarantine edit was reverted (head 04ba091) and the supervisor was asked on #1035 to drop the entry.
- 2026-10-16 restart: the session container restarted and lost about 15 h. #1280 (inspector scroller unnamed) merged at 03:34Z. Run 38841265840 was red on Linux on #851 only (Photo).
- Supervisor (15:57Z): the done check uses a `scoped: halo` run, not full dev CI; #1296 is out of scope (it's closed anyway, fixed by #1458). Supervisor (18:13Z): CI blocks only on compile and Model tests; journeys report.
- Belt (18:09Z): lead/viewer-playback had no merge base with main; rebuilt it as one commit on origin/main carrying only docs/leads/viewer-playback (history kept in timeline.tsv).
- H-J13 Play: the app is right. End then Loop (neither undoable) leave the playhead on the last frame with Loop off, so Play runs one 2 s pass from 0 and stops on 47 again before XCUITest's idle wait returns. Fix: the test resets to frame 0 with halo.transport.start after each control; the same PR drops the #1035 quarantine entry (#1590). Start and Previous stay judged disabled-with-reason at frame 0, as they already were at launch.
- Round 4 fix batch adds the H-J3 audit finding (inspector scroller unnamed, #1178 comment): fixer hides the inspector ScrollView's indicators as Photo's inspector tabs do; PR unlabelled until run 38841265840 reads, then fast-lane + feature-done.
- Deps: #777 and #333 both closed on 2026-10-15; no wait.
- Waves kept as the packet gives them; every wait is a real call or file edit (packet "Tasks" notes). LiveLayerPlacing already landed (#1054), so LiveFrameDrawing() draws keyed layers on .live from VP-1.
- LiveFrameRendering's W0 stub names render-out (#451) as its owner; the packet gives it to VP-4b/VP-5 and wins.
- gh CLI token is invalid in this container; builders open PRs and add labels through the GitHub MCP tools.
- VP-1 also edits Tests/HaloModelTests/HaloViewerNoticeTests.swift: its W0 test asserts the stub's help, which VP-1 removes by spec.
- VP-1 worldBox(of: Badge) is (0,0,240,240) on three-layers as shipped; the packet's (860,440,200,200) is the default box, so the test clears Badge's rect first.
- The GitHub MCP server appends a footer line to PR bodies; the lane strips it from the squash commit and merged #1069/#1072 with it.
- The container had no Swift; installed swift 6.3.3 (the CI image's version) under /opt/swift.

- VP-6 uses W0's haloP95 (3 rounds of 100, quietest p95) instead of the packet's "200 runs": the shared budget rule wins; accepted.
- Lead error: removed the worktree under the running VP-11 builder; the builder finished anyway and opened #1102 at cd386f6. Never prune worktrees while a workflow runs.

- Dev CI run 38721434364 (c7e5c17, before VP-10) failed 6 journeys. Ours: testEveryControlActsOrSaysWhy, "halo.transport.end is enabled but clicking it changed nothing": VP-7 turned the command on before VP-10 routed it; #1097 routes goToEnd, so expect it fixed on the next run. The other 5 (timeline layout, files, history, layers, SuiteUI sidebar id) are outside this feature's files and belong to dev-red #763.

- VP-12 built alongside VP-9 but opened without labels; the lead adds fast-lane + feature-done after VP-9 merges, so its CI run holds every task.

- VP-12 journeys launch at 1000x640 like every Halo journey (fits CI's 1024x768 display); the transport shows there (run 739 clicked it).

- Supervisor: dev didn't compile on macOS (run 38732179619): HaloPlaybackDriverTests.swift:18 untyped lazy var whose closure reads itself (circular reference), from #1097. Fixed in #1136 (typed property), commented on #763. Lesson: AppSnapshotTests never compile on Linux; builders must typecheck macOS-only test patterns by hand.

- Supervisor: run 38734211999 died in swift test with HaloPlaybackDriverTests in flight. #1145 puts the driver behind an injected HaloRefreshLink (default HaloScreenLink), tests fire a FakeLink, suite .timeLimit(1 min); feature-done so its merge dispatches CI. Commented on #763.

- Run 38738075349: HaloViewerFidelityTests (@MainActor, 1920x1080 renders) held the main actor 13:08:18-13:14:03; Flare's driver test took 314 s and ours hit 60 s. #1157 disabled the 5 (supervisor), #1155 filed, #1160 moves fidelity work off the main actor and re-enables them. keyedFrame6 (opacity 0.5) is a real HF-1 finding: #1161, fixer running.

- Supervisor read run 38762922782 as a fidelity hang and asked to disable keyedFrame6 as one. The log shows the test finished (failed compare after 49.9 s, run summary printed, exit 1), so #1194 fixes the cause (renderer colorMode) instead; explained on #763. 1-min limit not used: keyedFrame6 alone takes ~50 s.

- Round 1 critic panel deferred: every viewer-playback journey stops at its first read, so the screens show only step 1; journeys and audit were the findings this round.

## Open
- #1789 (needs-ui, line:suiteui, p1): the SuiteUI timeline rework dropped `halo.timeline.track` from track names and lanes; Halo journeys find no lane in scoped run 38972763400 (findings #1696–#1705).
- H-J13 quarantine entry (owner #1035, expires 2026-10-18) is the supervisor's to drop: UITests/quarantine.json is protected.
- none
- VP-10 started ahead of wave 3: its deps VP-3 (#1087) and VP-7 (#1085) merged; it needs nothing from VP-1.
