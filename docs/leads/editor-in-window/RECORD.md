# editor-in-window lead record

Issue: #1079 · Packet: docs/blueprints/suiteui/features/editor-in-window.md
Run: act-1a149babb21-udz7 (line lead with #1079, #1480, #1596; earlier act-1a1487bf89a-zfq8) · Session: claude/suiteui-feature-lead-t357v5 · Started: 2026-10-16T02:45Z (this run 2026-10-17T06:10Z)
Stage: 4 round 4 (waiting on its run)
Base: 9ba6658425c543613715ebbf34d677a380ef8cc3
Next: #2003 merged d14e765 (macOS build fixed: CGFloat.infinity in SuiteWindowSizeTests; main promoted to it). Round 4 (last) reads scoped suiteui 39034310918 (45a27f35, holds #2003) when it finishes; then gaps for what stays red, and Belt-Contact-Sheet

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| EW-1 | 1 | SuiteWindow sidebar slot, subtitle, documentActions, inspectorWidth, -SuiteWindowSize; sections list moves to SuiteSidebarList | SuiteWindow.swift, SuiteSidebarList.swift, SuiteWindowSizer.swift, SuiteWindowSizeTests, SuiteWindowSlotSnapshots | SuiteWindowSizeTests; slot snapshots | #1289 | merged |
| EW-2 | 1 | EditorDetail + EditorDetailLayout; CanvasViewport ⌘0 reads canvasFitScale | EditorDetail.swift, CanvasViewport.swift, EditorDetailLayoutTests, SuiteEditorDetailSnapshots | EditorDetailLayoutTests | #1288 | merged |
| EW-3 | 1 | SidebarActionRow | SidebarActionRow.swift, SuiteSidebarActionRowSnapshots | dimming + label checks | #1290 | merged |
| EW-4 | 1 | Journey shared steps + ShellGeometry | UITests/Journey.swift, Journey+Geometry.swift, AppAuditTests/ShellGeometry(+Tests).swift | ShellGeometryTests (Linux) | #1293 | merged |
| EW-7 | 1 | AppSwitcher, items, state, placeholder, env value, 4 tokens | AppSwitcher.swift, Tokens.swift, AppSwitcherTests, SuiteAppSwitcherSnapshots | AppSwitcherTests | #1294 | merged |
| EW-8 | 2 | SuiteWindow shows the switcher in a centered toolbar slot | SuiteWindow.swift | Flare/Halo/Library journeys unchanged | #1337 | merged 20:06Z (mac run 38949333875 failed only Design geometry line 72 and Halo testEaseKeys, both red on dev before) |
| EW-5 | 3 | editor-window gallery page + journey steps 1–6 | Gallery/GalleryEditorWindow.swift, SuiteGallery.swift, UITests/SuiteJourneyTests+EditorWindow.swift | the journey on dev | #1611 | merged 20:56Z |
| EW-6 | 3 | parity journey (step 7) | UITests/SuiteJourneyTests+Parity.swift | parity journey on dev | #1402, #1427 | merged; #1427 (16:08Z) fixes the dev red |
| EW-5b | 4 | remove the #933 skip, if any | UITests/SuiteJourneyTests+EditorWindow.swift | journey with no skip | – | only if EW-5 skips |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 4 (last) | 39034310918 (scoped suiteui, 45a27f35) | running | – | journeys + audit | – | – (last round: what stays red becomes gap) | – |
| 3 | 38997835882, then 39001038692 (scoped suiteui, e251c5c5, the newest run reaching the journeys) | red (ours: 2: #1777, #1778) | suiteui 0 on every editor-window screen; parity and hit-size pass | journeys + audit | window 677 on a 674 visible frame (Dock wait didn't help); `suite.canvas` reads the viewport (0.918), not the artboard (1.6) | #2003 (merged d14e765) | no |
| 2 | 38991868071 (scoped suiteui, 124b118a-era, holds #1801 #1802 #1809 #1835) | red (ours: 2) | suiteui 0 on every key for our pages | journeys + audit | parity + hit-size now pass; testEditorWindow 'list not inside suite.sidebar'; dark geometry: window 3 pt over visible frame, region frames read from child elements | #1900 | no |
| 1 | 38981651490 (scoped suiteui, b267d006) | red | suiteui offscreen/contrast/identifier over 0 on editor-window-open | journeys + audit | editor-window title read, dark no viewport, gallery page clips sidebar/status at ~900 pt, toolbar overflow (Fit) on page and Flare at 1024 (parity), timeline 'no lane for Ball' (cause TBD) | #1801 (page), #1802 (switcher), #1809 (parity) | no |
| pre (wave 1) | 38887139934 (9e3c5f8, full) | green | at baseline; suiteui 0 on every key | – | – | – | – |

## Decisions
- Waves as in the packet: wave 1 EW-1, EW-2, EW-3, EW-4, EW-7 (all independent, disjoint files); wave 2 EW-8 (waits EW-1 and EW-7: same SuiteWindow.swift, needs AppSwitcher); wave 3 EW-5 (needs EW-2/3/4/8 code), EW-6 (needs EW-4 helpers and EW-8's switcher); wave 4 EW-5b only if EW-5 skips.
- #933 is closed on dev (#977), so EW-5 is briefed to run its geometric steps without the skip; EW-5b is planned only if the dev run shows them red for #933 reasons.
- Wave 1 runs through build-wave.js (5 independent tasks); builders open PRs with the GitHub MCP since gh is unauthenticated here.
- Depends on #980: merged on dev as f7e4d40, so the feature can start.
- #933 is closed (fixed by #977, the detailInspectorAllowance in SuiteWindow's content frame; #962 is not on dev). Its effect on the sidebar rows is still to be read from the first green macOS dev run's audit.
- Builder branches are named `ew/<task>` (not `lead/editor-in-window/<task>`, which git can't hold beside the `lead/editor-in-window` branch).

- EW-5 and EW-6 build alongside EW-8 (their files are disjoint and compile without it), but their PRs open only after EW-8 merges, so dev never runs the switcher steps without the switcher.
- EW-5 is briefed with no #933 skip (#933 closed by #977); EW-5b stays unplanned unless the dev run is red for #933 reasons.
- PRs target dev, not main as the Belt brief says: CLAUDE.md and the lane put every crew PR on dev, and wave 1 merged there.

- #933 stage-1 check: full run 38887139934 (green, holds all of wave 1) shows offscreen 0 in audit-flare-launch.json; the sidebar rows are no longer offscreen.

- Packet deviation: "centered in the toolbar (midpoint within 1 pt of the window's)" can't hold with `.principal`; the checks assert the row sits between the title and the trailing actions with nothing overflowed. Raised on #1079.

- This run (2026-10-17T06:10Z): the lead is pre-#1302 (started 02:45Z, #1302 merged 04:20Z), so it keeps the v2 loop with the 4-round budget. `lead/editor-in-window` rebuilt on main with the records only, as Belt asked. The round-3 fixer runs as fix-batch.js `batches` (v2 form) beside the timeline wave; SuiteWindow.swift is off limits for it (MAC_GATED), the clamp goes in SuiteWindowSizer.

## Open
- Timeline journeys (testTimelineLooksAndScrubs, testTimelinePicksKeys: "no lane for Ball") are the timeline feature's: its page has no SuiteWindow; the Ball lane lost its identifier in #1680–#1770.
- Dev runs 38965923292 (full) and 38967063787 (scoped suiteui) contain #1611 but their macOS job stopped in unit tests on TimelineStripLayoutTests (#1620, another feature) and ran 0 journeys, though both read success; reported on #1079.
- #1561 (gap, line:design, p1): Design's shell journey asserts the switcher at the window's centre; the toolbar starts `.principal` after the title (measured x 424 / 538), so that last step goes red once #1337 merges. EW-5 step 6 changed the same way (row between the title and the trailing buttons).
- #1425 (gap, line:flare): Flare's open-document inspector needs ~677 pt height, over the runner's 674 pt visible frame; the parity journey expects that one failure until it's fixed.
- Lane refuses #1337: "no completed macOS run on dev could be read" although full run 38908942026 fails only testImportAFolder, the same as #1337's run. Reported on #1079 (comment 6218239530).
- #1337 mac run 38897404951 red: the switcher takes its 480 pt step in the principal slot (ViewThatFits isn't constrained in a toolbar) and pushes Flare's, Halo's and the gallery's trailing actions and suite.inspectorToggle into the overflow. Fixer on ew/EW-8; Library's 13 vs 12 came from the same overflow button. Fix e634d40: SuiteWindow measures its width and picks the widest switcher step (80/64/48/40) whose row fits width − 2·max(leading, trailing); capsule narrows with the step; tested in AppSwitcherTests.
- Worker restart at ~12:10Z interrupted the builders: EW-8 had opened #1337; ew/EW-6 pushed; EW-5 committed locally. Finishers resume both from their worktrees.
- Relaunched 2026-10-16 after a stall: wave 1 had merged (#1288, #1289, #1290, #1293, #1294) while RECORD still read wave 1.
- dev macOS runs 38835566584 and earlier are red (other lines); runs 38841265840 and 38841439320 are in progress.
