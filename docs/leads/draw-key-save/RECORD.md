# draw-key-save lead record

Issue: #1365 · Packet: docs/blueprints/flare/features/draw-key-save.md
Run: act-1a14a13ca4f-74rv (line lead for draw-key-save, layers-files, inspector-timeline; earlier runs act-1a1487603d9-vrd4, act-1a145e74c0e-upy8) · Session: session_01NXMovyJtKvANXKD2WWypB3 · Started: 2026-10-16T18:10Z (resumed 2026-10-17T06:05Z)
Stage: done
Base: 4a86f5fcff2f2cc18748a93e39f1491c6ae5c745
Next: none. Contact sheet posted (https://github.com/qbtrix/creative-apps/issues/1365#issuecomment-6234618001); open findings relabelled gap

Loop: v2 (the packet has no `## Slices` table), started after #1302 merged
(2026-10-16T04:20Z), so the findings queue and the 2-round cap apply.

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| DK-1 | 1 | FlareLaunch parses launch flags; FlareWorkspace(launch:) | Sources/FlareModel/FlareLaunch.swift, Tests/FlareModelTests/FlareLaunchTests.swift | FlareLaunchTests | #1525 | merged |
| DK-2a | 1 | FlareIntent enum, Area, area, identifier | Sources/FlareModel/FlareIntent.swift, Tests/FlareModelTests/FlareIntentTests.swift | FlareIntentTests | #1524 | merged |
| DK-4 | 1 | stageList, stageMarks | Sources/FlareModel/FlareStageRead.swift, Tests/FlareModelTests/FlareStageReadTests.swift | FlareStageReadTests | #1543 | merged |
| DK-5 | 1 | timelineRows, timelineEmptyText, selectedTimelineRowID | Sources/FlareModel/FlareTimelineRead.swift, Tests/FlareModelTests/FlareTimelineReadTests.swift | FlareTimelineReadTests | #1544 | merged |
| DK-2b | 2 | FlareIntent.title, section 3.4 table | Sources/FlareModel/FlareIntent+Titles.swift, Tests/FlareModelTests/FlareIntentTitleTests.swift | FlareIntentTitleTests | #1580 | merged |
| DK-3 | 2 | FlareServices.built; launch default .built | Sources/FlareModel/FlareServicesBuilt.swift, Sources/FlareModel/FlareLaunch.swift, Tests/FlareModelTests/FlareServicesBuiltTests.swift | FlareServicesBuiltTests | #1581 | merged |
| DK-6a | 2 | new stub files: FlareStage, FlareTimeline, FlareInspector, Library, Recording, FilePanels, NewSheet, OpenStatus, Recovery | 9 new files from lead/draw-key-save-DK-6 | scripts/ci + macOS build | #1597 | merged |
| DK-6b | 2b | FlareApp split: FlareWindow on SuiteWindow, FlareToolItems, snapshots, J0 | FlareApp.swift, FlareWindow.swift, FlareToolItems.swift, FlareWindowSnapshots.swift, FlareJourneyTests.swift | FlareWindowSnapshots, J0 | #1608 | merged |
| DK-7 | 3 | router, area files, intents on toolbar and sidebar | packet DK-7 row (15 files) | J0 extended | #1627 | merged |
| DK-8 | 4 | stage canvas, overlay, palette, drags | packet DK-8 row | FlareStageSnapshots, FlareToolsTests | #1649 | merged |
| DK-10 | 4 | timeline strip, scrub, readouts, transport stub | packet DK-10 row | FlareTimelineSnapshots, J9 slice | #1644 | merged |
| DK-12 | 4 | open/save panels, flags, title and dot, recent, alerts | packet DK-12 row | testSaveAndReopen | #1658 | merged |
| DK-13 | 4 | menu bar from intents, keys | packet DK-13 row | J1, J29, testKeys | #1673 | merged |
| DK-13f | 5 | after #1658 and #1673: J0 table rows for Open (enabled, nil) and Save ("Open or create an animation first."); +File routes .file(.openSample(name:)) so Bounce, Character, Button act; every-control list expects flare.timeline.step.back/.forward (DK-11) | UITests/FlareJourneyTests.swift, Sources/FlareApp/FlareWindow+File.swift | J0, J1 | #1690 | merged |
| DK-9 | 5 | tools, finishPath, Escape/Return | packet DK-9 row | FlarePenFinishTests, J3 slice | #1691 | merged |
| DK-11 | 5 | transport and PlaybackDriver | packet DK-11 row | FlareTransportSnapshots, J10 slice | #1676 | merged |
| DK-14 | 6 | recording ring, J6 slice | packet DK-14 row | FlareRecordingSnapshots, J6 slice | #1695 | merged |
| F1731 | fix | new shape keys position at 0 on .built (finding #1731) | Sources/FlareModel/Live/*, FlareModelTests, mutation plan; Loop wrappers if #1738 merged | FlareModelTests on .built | #1748 | merged |
| F1731b | fix | remove the #1731 XCTExpectFailure wrappers in +Loop.swift; rule sentence in flare.md section 2 | UITests/FlareJourneyTests+Loop.swift, docs/blueprints/flare.md | J26 | #1776 | merged |
| DK-15 | 7 | J26 un-skipped on .built; shared docs; feature-done | packet DK-15 row | J26 testDrawKeyAndSave | #1738 | merged |

Wave 1: DK-1, DK-2a, DK-4, DK-5, all independent (disjoint new files).
Wave 2: DK-2b (waits DK-2a: extends its enum), DK-3 (waits DK-1: edits FlareLaunch.swift), DK-6 (waits DK-1: launch flags); independent of each other.
Wave 3: DK-7 alone (waits DK-2a, DK-2b, DK-6).
Wave 4: DK-8, DK-10, DK-12, DK-13, independent of each other.
Wave 5: DK-9 (waits DK-8), DK-11 (waits DK-10).
Wave 6: DK-14 (waits DK-9, DK-10). Wave 7: DK-15 (waits all).

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | scoped flare 38988929676 (7ac0a31) | red: 10 of 11 Flare journeys fail (frame readout unreadable, save check, sidebar scene, step back, audit) | over: contrast 4/0, identifier 31/12, unnamed 3/0, offscreen 4/0, overlap 1/0 | clarity, journey, design, mouse: 19 confirmed, 5 refuted | #1792 (fixed by #1799, #1819), #1836-#1841, panel #1844-#1863 (18 issues; 2 blockers #1849 #1862) | #1843 (merged; #1836, #1837), #1864 (#1841, #1840 part), #1875 (#1839) merged; #1876 (#1838) closed on a conflict, #1838 moved to round 2 | no |
| 2 | scoped flare 39001036689 (e251c5c5) | workflow success; macOS (flare) job red: 11 journeys still fail (frame readout nil after a scrub in 4; identifier, contrast, unnamed audits; Scene 1 keeps Ball selected) | over: contrast 5/0, identifier 18/12 | same panel on full dev run 39032323316 (d14e765b): 9 confirmed, 12 refuted | #2088-#2095 | #1885 (#1846 #1848 #1851), #1886 (#1847 #1853 #1861), #1889 (#1844 #1859), #1890 (#1845), #1892 (#1854 #1857), #1893 (#1862 #1863, #1850 part), #1896 (#1856), #1897 (#1858); #1849 closed (fixed by #1843); not fixed: #1838 (SuiteUI #1867, journey), #1840 (#1852, #1148), #1860 (#1888) | |

## Decisions
- Base and PR target are `dev`, not `main` as the launch brief says: CLAUDE.md and lead.md rule 4 say never branch from or target `main`, and the packet exists only on `dev` (main is 74 commits behind).
- #798, #799, #800 are closed, so DK-3's task-level wait is met; it runs in wave 2 with DK-2b and DK-6 (it still needs DK-1's FlareLaunch.swift).
- Builder branches are `lead/draw-key-save-<id>`: a `lead/draw-key-save/<id>` ref can't sit beside `lead/draw-key-save`.
- PRs are opened with the REST API (`gh api .../pulls`): GraphQL, which `gh pr create` uses, is refused from cloud sessions.

- The PR service appends a "Generated by Claude Code" footer to PR bodies after the agent's text; the lane strips it from the squash commit (CLAUDE.md), so builders don't fight it.

- DK-6 came to 559 lines (moved code counts twice), so it splits: DK-6a the new stub files, DK-6b the FlareApp split (waits DK-6a: it uses the stubs).
- DK-7 notes from DK-6b: FlareInspector(model:tab:perform:easing:) takes the easing view; FlareCanvas stays as content (AppSnapshotTests.swift calls FlareCanvas(model:)); keep FlareWindow.bodyRuns (RenderBudgetFlareTests); perform/help(for:) are inline in FlareWindow.swift to move into +Router; sidebar calls the model directly (route via +Layers); toolbar has no identifiers yet; use FlareIntent.title/toolbarTitle from #1580.
- Wave-4 router notes from DK-7: router in FlareWindow+Router.swift is exhaustive; each task fills only its FlareWindow+<Area>.swift (replace its default: branches), never the router. +Tools has toolKey(_:) -> .ignored for DK-9. +File routes only .new; +Timeline only .toggleAutoKey. Menu Undo/Redo already perform(.edit); newSample still calls the model (route .file(.openSample) in DK-13). J0's static toolbar table in FlareJourneyTests.swift lists ids and reasons: a task that enables Open, Save or Auto-key at launch updates it.
- Wave 4: DK-13 alone edits FlareJourneyTests.swift (J0's toolbar table); DK-12 reports in its body if Open or Save become enabled at launch, and DK-13 or a fixer updates the row.
- DK-11 started as soon as DK-10 merged instead of waiting for all of wave 4: it waits only on DK-10 (builders never wait).
- DK-13f added: DK-12 enables Open at launch and changes Save's reason, and DK-13 leaves Bounce/Character/Button samples disabled because .openSample lives in DK-12's +File; one small follow-up fixes both once both merge.
- DK-9 also edited FlareWindow.swift (4 lines: FlareCanvas never passed onKey to FlareStage, so toolKey could not fire).
- DK-14 started before DK-9 merged: its ring and J6 need only DK-8's Select drag and DK-7's Auto-key, not finishPath or Escape.
- DK-15 notes from DK-14: artboard is suite.canvas (scene point = top-left + p * frame.width / scene width); palette tools share id flare.tools.choose, pick by label in suite.tools; Undo item reads "Undo Move" (match BEGINSWITH 'Undo'); copy DK-14's keys(_:_:) lane helper from +Animate.swift; check flare.recording, not Auto-key's isSelected (#1621); a new shape's first drag writes key 0.
- #1731 was filed as `gap` by DK-15's builder; relabelled `finding` (contract rule 10: a confirmed defect is fixed in a round, gaps come only after the 2-round cap). It breaks the core loop (draw, key, play), so its fix starts now beside DK-15.
- Round 1 has no screens: the scoped Flare run stops at RenderBudgetFlareTests before the journeys, so the panel waits for the run after #1792's fix. The workflow run reads 'success' while its macOS (flare) job is red: judge by the job.
- #1799 raised the report-only canvas p95 budget from 1 ms to 20 ms (the old 1 ms measured a drag that did nothing); the Mac run re-measures it.

## Decisions (resume, 2026-10-17T06Z)
- Resumed as a line lead (rule 19) with flare-export (#1973); each feature keeps its own branch and record.
- lead/draw-key-save recreated on origin/dev (Belt: 200 commits behind main) with the same record files; it only ever carried docs/leads.
- Round 2's fixes (#1885 #1886 #1889 #1890 #1892 #1893 #1897, #1896 reverted by #1965) all merged; e251c5c5 is the first scoped flare run holding them, so its screens are round 2's review. After it, the cap (rule 11) turns every open finding into a gap.

## Open
- #1850 needs the UI test runner granted Accessibility (post events) in .github/ (protected): supervisor. #1888 (needs-ui): SuiteWindow title accessory for the recording dot; #1895 (needs-ui): ToolbarGroup capsule clips a toggle.
- needs-ui filed by round-1 fixers: #1842 (TimelineStrip key ids, overlap, unlabelled button), #1852 (sidebar row ids), #1855 (curve well arrow keys), #1867 (SidebarRow title click doesn't select); #1148 (chip ids) already open.
- Ellipse ignores Shift in the Model (DK-9 report): J3 drags a square box, so it passes without proving the constraint. Raise in the Anatomy round if critics confirm.
- #1675 (needs-ui): ToolbarGroup can't set one button's accessibility value, so the Play button's "Playing" reads as selected in testPlayAndStep until it lands.
- #1621 (needs-ui, line:suiteui): SuiteWindow ignores ToolbarAction.isSelected, so J0's Auto-key-selected check is a non-strict XCTExpectFailure until it lands.
- #1589 (needs-ui, line:suiteui): the parity journey clicks Flare's toolbar New Sample Animation, which DK-6b removes.

- Round cap reached after round 2 (rule 11): 23 open findings relabelled gap. Full run 39032323316: Linux green, main promoted; macOS journeys red (all 7 feature journeys fail; flare contrast 5, identifier 18). Contact sheet says so.

## Rebase (run act-1a14c3ffa03-yyt3)
- Lead branch rebuilt on origin/main 59c435a6 with this record only (brief rule 2). Stage stays done.
