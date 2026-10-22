# layers-panel lead record

Issue: #1498 · Packet: docs/blueprints/design/features/layers-panel.md
Run: act-1a156589867-ptgh, LP-a only (before: act-1a152e441eb-msob, act-1a14feea7c0-wmv6, act-1a14d32dfd7-u3ff, act-1a149c0c306-8ckd, act-1a1487bf8e3-hwdj) · Session: claude/layers-panel-lead-eyprpb · Started: 2026-10-19T22:50Z
Stage: 3 polling (LP-a done; LP-b fix round 2 #4178 open)
Base: cf120143 (dev; main b3011ab9 verified)
Next: #4178 (P3 finds the list as suite.sidebar, Closes #3307) merges; then Belt-Slice-Done: LP-b on a green design run containing it (gaps: #3307 if P3 stays red), then Belt-Contact-Sheet on #1498

Line lead (rule 19) over #1498 layers-panel, #1497 style-rows and #1496 copy-group.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LP-a | Rename, reorder and nest layers from the Layers panel, and Object > Arrange, each one step. | L-1, L-2, L-4, L-5 | J12 | EK-tree done; DW-a, DW-b merged | yes | 0 | built; waiting on CI containing 94c8fd34 | – | – |
| LP-b | Locking a layer mid text edit keeps the typing, the Layers list scrolls 2,000 expanded rows, and a group row's own eye hides it once SuiteUI's LL-9 lands. | L-3, L-6, L-7 | P3, J12 | LP-a (L-6); design-window DW-a (L-7's P3); SuiteUI LL-9 (L-6) | no | 0 | done (before this run) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| L-3 | LP-b | 1 | A lock commits an open text edit first (#613); `renameNode` / `renamePage` trim the name, a same-name rename records nothing | Sources/DesignModel/DesignWorkspace.swift, Tests/DesignModelTests/DesignLockTextEditTests.swift, Tests/DesignModelTests/DesignRenameTests.swift, Tests/mutations/DesignModel.DesignWorkspace.json | DesignLockTextEditTests, DesignRenameTests + Mutate 2+/n | #2055 | merged |
| L-7 | LP-b | 1 | QD-S10 model budget (`layerRows`, 2,000 expanded rows on `crowd` ≤ 50 ms); P3 written skipped ("waits on design-window D0-5a") | Tests/DesignModelTests/DesignLayersBudgetTests.swift, UITests/DesignJourneyTests+PerfLayers.swift | DesignLayersBudgetTests.layerRows | #2047 | merged |
| L-1 | LP-a | – | `LiveOrdering` over the kernel tree: move with its refusals; arrange | Sources/DesignModel/Live/LiveOrdering.swift, Tests/DesignModelTests/DesignOrderingTests.swift, Tests/mutations/DesignModel.LiveOrdering.json | DesignOrderingTests | – | building (wave 2) |
| L-2 | LP-a | 3 | `layerDrop` and `DesignDropPosition` | Sources/DesignModel/DesignLayerToggles.swift, Tests/DesignModelTests/DesignLayerDropTests.swift | DesignLayerDropTests + Mutate 5/5 | #3114 | merged (2026-10-19T05:16Z, 047303c1) |
| L-4 | LP-a | – | Layers rows: rename, drag to reorder and nest, the empty page state, row ids, the drag check | Sources/DesignApp/DesignLayersPanel.swift, Tests/AppSnapshotTests/DesignLayersSnapshots.swift, Tests/AppSnapshotTests/DesignLayersDragTests.swift | DesignLayersSnapshots, DesignLayersDragTests, DesignLayerDropLineTests + Mutate 9/9 | #3145 | merged (2026-10-19T08:02Z, batch Linux run 39218716050) |
| L-5 | LP-a | 6 | J12; `feature-done` (L-6 shipped); closes gap #1986 | UITests/DesignJourneyTests+Layers.swift, docs/blueprints/design/features/layers-panel.wave.json | J12 | #3370 | merged 94c8fd34 |
| L-6 | LP-b | – | J12's group-row eye step without the skip | UITests/DesignJourneyTests+Layers.swift | J12 | #3195 | merged (09:43Z, 68d4644e); regressed group-row ids, fixed by #3316 |
| L-7b | LP-b | 5 | P3 runs: drop its "waits on design-window D0-5a" skip | UITests/DesignJourneyTests+PerfLayers.swift | P3 | #3181 | merged (09:56Z, 3dbba7d3) |
| F-1 | LP-b | fix 1 | Group rows keep `design.layer.<id>` (`.combine`, #2410); the group eye is clicked at the shared toggle column | Sources/DesignApp/DesignLayersPanel.swift, UITests/DesignJourneyTests+Layers.swift | DesignLayersJourneyTests.testGroupRowEyeHidesGroup + the journeys of #3300-#3304 | #3316 | merged 21:12Z as e794d5fd (lane batch run 39323695277) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| LP-b | 39292729592 (scoped design) | 8f405311 | CI journeys (report-only) | #3300 #3301 #3302 #3303 #3304 (group rows have no id); #3307 watched | 1 (#3316) |

## Decisions
- 01:50Z Still waiting. Scoped: design 39346088549 (1299651e, which contains 94c8fd34) has sat queued since about 00:00Z. Full CI 39346519827 was cancelled, like every full dev run since: each new dev head cancels the one before. No passing run contains 94c8fd34 yet. This is a runner backlog, not a red, and the lead can't dispatch CI. The poll continues with a heartbeat every 19 min.
- 00:21Z Belt nudge: RECORD was current (stage 3, L-5 merged). Both dev runs that contain 94c8fd34 are still waiting: scoped: design 39346088549 (1299651e, queued) and full CI 39346519827 (c7306ee8, pending). The earlier full run 39345113796 was cancelled. The poll continues.
- 00:00Z #3370 merged as 94c8fd34 (macOS build 39338781158 green). Waiting on a full or design-scoped CI run on dev containing it.
- 23:00Z L-5 opened as #3370 (head 62d43b6e, 120+/7-, 2 files, `fast-lane` + `feature-done`, scripts/ci --changed PASS). The first commit is test-only J12. Rename Page… is asserted off pending gap #3148. The remote wave/layers-panel-L-5 held the old run's stale L-4 + J12 (07ebcd12), so it was left as is and the branch was pushed as wave/layers-panel-L-5-j12. This session's GitHub write path appends an attribution footer to PR bodies. A PATCH that stripped it got the footer re-added, so it is noted here and not retried.
- 22:50Z relaunch (run act-1a156589867-ptgh, LP-a only; main b3011ab9 verified, dev cf120143): LP-b was done before this run. L-1, L-2 and L-4 are merged, so LP-a needs only L-5. L-6 shipped, so J12 has no eye step and no skip. The lead branch was recreated from origin/main with only this record (the old branch sat about 1600 dev commits past main), then force-pushed with lease. PRs target dev (CLAUDE.md; the lane retargets main to dev).
- 18:20Z fix round 1: run 39292729592 confirmed the 07:12Z risk. `.contain` on a DisclosureGroup label lost the row id, so expandDesignLayer and every group-row click failed. #3316 reverts the panel file to 68d4644e^ (one comment added). The L-6 journey no longer needs an eye element inside the group row: it clicks Pair's row at E1's eye x. Other Design findings (#3305 #3306 #3308 and older ones) are not LP-b's.
- 08:58Z: `fast-lane` was added to #3195 by hand at 08:55Z, and the lane dispatched its macOS build. The lane's opt-out labels only stop auto-labelling, so I'm reading this as the supervisor releasing the 07:12Z hold, and I removed `no-fast-lane`. The DisclosureGroup `.contain` risk (#589, #2444) is now proved after the merge: the first scoped or full design run that contains #3195 shows whether the Layers journeys hold. If they break, a `finding` is fixed first.
- 08:20Z lead.md rule 22 (#3192, about 08:11Z) landed: one PR per slice, the failing test as the first commit. L-6 was restacked onto dev as test commit 30efe437, then fix 60d211b0, and opened as #3195. #3181 (L-7b) was opened before the rule and stays as it is, since folding it in would restart its queued macOS build. LP-b has no tasks left to stack. Feature-done: L-6 closes #2758. L-5 (J12, gap #1986) is in LP-a and outside this run.
- 07:12Z L-6 is held for macOS proof: it makes every Layers row `.accessibilityElement(children: .contain)` with `design.layer.<id>` (it was `.combine` on the group label). #589 and #2444 both record that `.contain` on a DisclosureGroup label in a macOS sidebar List leaves the row as one checkbox without the id, and LL-9's SJ17 never reached that step. If that happens, expandDesignLayer, J-delete and the Desktop/Pair journeys break. Journeys are report-only in the lane, so a build-only run can't catch it. L-6's PR opens with `no-fast-lane` and asks the supervisor for a scoped app=design run on the branch (or a `Mac-Check:` line) before it takes the lane.
- 2026-10-19T06:30Z relaunch (run act-1a152e441eb-msob, LP-b only, main b7e17ed6 verified, dev 977df193): L-5 (07ebcd12) and L-6 (cf4799ec) were never pushed, so the relaunch lost them. #3145 (L-4) is still in the lane. L-5 is in LP-a and outside this run. L-6 no longer chains on L-5: it adds its own group-eye journey method beside J12 in DesignJourneyTests+Layers.swift, rebuilds after #3145 merges, and closes #2758. If the eye needs DesignLayersPanel.swift (outside LP-b's list), it touches only the group row's toggles. P3's wait on design-window is over, because DesignFixtures has `crowd` and DesignWindow reads `-DesignFixture`. L-7b turns P3 on now.
- 05:31Z: lists-and-layers is done; LL-9 merged (#589 closed 10-18, `onExpand` on dev) and filed its Design follow-up #2758. Per the packet, L-5 carries no `feature-done`; L-6 does and closes #2758 (refs #589), taking in #2758's DesignModel expansion set and window wiring along with the eye step. L-4 opened as #3145 (355 lines, 10 files, 9/9 mutations, 5 Unverified API lines; snapshots design-layers-renaming/-nested/-empty). L-5 builds on L-4's branch.
- 04:28Z L-2 opened as #3114 (5/5 mutations, 147 lines). design-window's RECORD marks DW-a and DW-b done, so L-4 builds now on top of L-2's branch and opens its PR once #3114 merges. Footers that a builder's PR gets on creation are stripped via the MCP update; a REST PATCH re-adds them.
- 2026-10-19T04:05Z resume: L-1 merged as #2880. The 01:46-03:48Z check lines below came from a stale loop that still waited on #1933. That wait was dropped at 16:56Z: EK-tree is done, and #1933's other slices aren't needed. Wave 3 is L-2 on base b48cf6c4. No open layers-panel findings.
- 2026-10-18T16:56Z relaunch (run act-1a14feea7c0-wmv6, main bafd1d38 verified, dev aee9df9d): editor-kernel's RECORD marks EK-tree done and `SuiteKernel/Layers/LayerTree.swift` has move, arrange, rows, group, ungroup and duplicate. The earlier runs waited on all of #1933 closing, but only the tree slice was needed. L-1 is unblocked and starts as wave 2.
- L-1 builds `LiveOrdering` as an adapter over `LayerTree` (rule 20, like PhotoLayers+Kernel and FlareLayers+Kernel): DesignPage.nodes → LayerTree, the kernel's move/arrange, then back. Refusals map from TreeRefusal to DesignRefusal. Any new adapter file is named `DesignNode+Kernel.swift`. adopt-kernel-layers AL-d1 (#1936) also lists LiveOrdering.swift, but it hasn't started (it waits on design-seams-2) and has no PR. When AL-d1 turns DesignPage.nodes into a LayerTree, it keeps L-1's behaviour and tests and drops the adapter. Noted on #1498.
- 13:10Z wave 1 merged (#2047 L-7, #2055 L-3 at 12:41-12:42); scoped design run 39033633296 on 93c2103 is green and contains both. LP-b can't be done until L-6. No open findings. No task of this feature can start: polling.
- 2026-10-17 12:10Z relaunch (run act-1a149c0c306-8ckd, base 0424231 = dev = main): L-3 and L-7 had no PRs; rebuilt on branches wave/layers-panel-L-3, -L-7. EK-tree has not started (editor-kernel's EK-a is in its wave 2), DW-a not merged, so LP-a stays blocked.
- PRs target `dev` (the lane's base; it retargets `main`); builder branches are `wave/<feature>-<task>`.
- Rule 20 and the relaunch note on #1498: the layer tree and parenting are kernel concepts, so L-1 (`LiveOrdering` move and arrange) and L-2 (`layerDrop`) build on SuiteKernel's tree module (editor-kernel EK-tree, #1933) and wait for it. No Design copy. The SuiteKernel target doesn't exist on dev yet (EK-a is the kernel's first slice), so LP-a is blocked today.
- L-3 and L-7 start now: a lock that commits a text edit, name trimming and the row-build budget are Design's own, and `layerRows` and the `crowd` fixture exist. L-7's P3 journey is written skipped by name (`-DesignFixture` arrives with design-window D0-5a, rule 13).
- Filed the packet's stage-1 gap: #1986 ("Design: rename, reorder and nest layers from the panel, and Object > Arrange", p1, in-progress); L-5 closes it.
- Packet wave 1 was L-1, L-3, L-7; L-1 moved out under rule 20. Nothing else unchained.

- 2026-10-18T04:12Z relaunch (run act-1a14d32dfd7-u3ff, main 0965457c verified): SuiteKernel exists on dev but has no Layers module; editor-kernel's RECORD lists EK-tree (EK-11..EK-13) as planned, no open PR. lists-and-layers LL-9 planned, #1510 is needs-human. No task of LP-a or LP-b can start.

## Open
- lists-and-layers LL-9 (#1510) not merged: L-6 waits. If it hasn't landed by L-5, L-5 files "Design: J12 hides a group from its row's eye" and drops L-6 from the wave.json.
- Heartbeats from 2026-10-17T14:04Z to 2026-10-18T16:52Z are in timeline.tsv. Each one said the run was blocked on #1933 or #1510.
- 2026-10-18T17:09:38Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T17:26:18Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T17:43:22Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T18:00:34Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T18:17:17Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T18:34:15Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-18T18:51:41Z check: blocked: #1933 #1510 open; no dev-red; 9 design findings open (new #2900 perf scrub journey, not this feature)
- 2026-10-18T19:08:33Z check: blocked: #1933 #1510 open; no dev-red; 9 design findings open
- 2026-10-18T19:25:15Z check: blocked: #1933 #1510 open; no dev-red; 9 design findings open
- 2026-10-18T19:42:42Z check: blocked: #1933 #1510 open; no dev-red; 9 design findings open
- 2026-10-18T19:59:53Z check: blocked: #1933 #1510 open; no dev-red; 18 design findings open
- 2026-10-18T20:16:38Z check: blocked: #1933 #1510 open; no dev-red; 18 design findings open
- 2026-10-18T20:32:44Z check: blocked: #1933 #1510 open; no dev-red; 18 design findings open
- 2026-10-18T20:49:23Z check: blocked: #1933 #1510 open; no dev-red; 15 design findings open
- 2026-10-18T21:06:31Z check: blocked: #1933 #1510 open; no dev-red; 12 design findings open
- 2026-10-18T21:25:01Z check: blocked: #1933 #1510 open; no dev-red; 12 design findings open
- 2026-10-18T21:42:19Z check: blocked: #1933 #1510 open; no dev-red; 12 design findings open
- 2026-10-18T21:59:09Z check: blocked: #1933 #1510 open; no dev-red; 12 design findings open
- 2026-10-18T22:16:15Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-18T22:34:20Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-18T22:52:27Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-18T23:10:14Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-18T23:27:11Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-18T23:44:36Z check: blocked: #1933 #1510 open; no dev-red; 11 design findings open
- 2026-10-19T00:02:07Z check: blocked: #1933 #1510 open; no dev-red; 14 design findings open (new #3042-#3045 not ours)
- 2026-10-19T00:19:53Z check: blocked: #1933 #1510 open; no dev-red; 15 design findings open (new #3052 not ours)
- 2026-10-19T00:37:35Z check: blocked: #1933 #1510 open; no dev-red; 15 design findings open
- 2026-10-19T00:54:48Z check: blocked: #1933 #1510 open; no dev-red; 16 design findings open
- 2026-10-19T01:11:56Z check: blocked: #1933 #1510 open; no dev-red; 16 design findings open
- 2026-10-19T01:30:08Z check: blocked: #1933 #1510 open; no dev-red; 15 design findings open
- 2026-10-19T01:46:56Z check: blocked: #1933 #1510 open; no dev-red; 10 design findings open
- 2026-10-19T02:04:10Z check: blocked: #1933 #1510 open; no dev-red; 13 design findings open (new #3078-#3081 not ours)
- 2026-10-19T02:20:49Z check: blocked: #1933 #1510 open; no dev-red; 13 design findings open, unchanged
- 2026-10-19T02:37:56Z check: blocked: #1933 #1510 open; no dev-red; 13 design findings open, unchanged
- 2026-10-19T02:55:53Z check: blocked: #1933 #1510 open; no dev-red; 13 design findings open, unchanged
- 2026-10-19T03:13:55Z check: blocked: #1933 #1510 open; no dev-red; 12 design findings open
- 2026-10-19T03:31:30Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open
- 2026-10-19T03:48:17Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open, unchanged
- 2026-10-19T04:05:29Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open, unchanged
- 2026-10-19T04:22:26Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open, unchanged
- 2026-10-19T04:39:43Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open, unchanged
- 2026-10-19T04:56:29Z check: blocked: #1933 #1510 open; no dev-red; 8 design findings open, unchanged
- 2026-10-19T05:13:45Z check: blocked: #1933 #1510 open; no dev-red; 7 design findings open
- 2026-10-19T05:30:09Z check: blocked: #1933 #1510 open; no dev-red; 7 design findings open, unchanged

- 06:01Z L-6 deviations from #2758: there's no SuiteWindow `expanded:`/`onExpand:` wiring because Design's Layers panel is its own DisclosureGroup, which is already bound to the model's expansion set via `.setExpanded`. The set stays `public internal(set)` (only Model code writes it; it is read-only to DesignApp). Ids of deleted groups are kept and ignored, not pruned. Accepted: the behavior #2758 asks for (the group stays open, its own eye hides it) is proved by the J12 step and DesignLayersExpansionUndoTests.

## LP-a fix round 1 (2026-10-20T05:50:05Z)
- Scoped design run 39346088549 FAILED: J12 testLayersRenameReorderNest failed at the reorder drag step. The CI bot filed finding #3427.
- Root cause: the row's DragGesture (simultaneousGesture) inside the macOS List never got the pointer moves, because the table takes the press.
- Fix PR #3510 (wave/layers-panel-LP-a-fix1, head dee188be): the rows use system drag and drop (onDrag plus a DropDelegate). The Model drop rules are unchanged. scripts/ci --changed: PASS. Labelled fast-lane; Closes #3427, Refs #1498.
- Next: once #3510 merges, LP-a is done on the first passing scoped design or full CI run that contains it. Round 2 is the last; after it, open findings become gap issues.
- 2026-10-20T07:50:55Z: #3510 merged into dev as 858a4570 (07:30Z; finding #3427 closes with it). Scoped design run 39387228332 is queued on 858a4570, and full CI 39387926961 is pending on af2977c0, which contains it. LP-a is done on the first of these that completes green with J12 passing.
- 2026-10-20T09:50:53Z: scoped design 39387228332 and CI 39387926961 were both cancelled (superseded), as was every dev CI since. Waiting on CI 39402653640 (36789542, which contains 858a4570) or the next scoped design run.

## LP-a fix round 2 (2026-10-20)

- J12 failed at step 3 in scoped run 39395510111 after round 1 (#3510); finding #3556.
- Round 2 is PR #3595 (head 3e7a21b0): the drop resolves its own line from `info.location.y`. J12 drags with `click(...withVelocity: 200, thenHoldForDuration: 0.5)`, because `press` with velocity drives only the Touch Bar on macOS.
- This is the last round. If J12 is still red in the run that contains the merge, #3556 becomes a `gap` and LP-a closes with `gaps:`.

## Run act-1a15fcdd869-ck2o (2026-10-21T18:55Z)

- Relaunched lead. Every task in the packet's Slices table is on dev: LP-a (L-1 #2880, L-2 #3114, L-4 #3145, L-5 #3370, plus fixes #3510, #3595 and Mac finish #3605) and LP-b (L-3 #2055, L-6 #3195, L-7 #2047/#3181, fix #3316).
- LP-a is done: green ci.yml run 39652451586 (15f7bad1) contains #3595 (897ccbb2) and #3605 (6cb55370). Belt-Slice-Done: LP-a was posted on #1498.
- LP-b is not done yet: P3 (testLayerListScroll) is still red, finding #3307 ("no Layers list (design.layers)"; run 39578070252). Root cause: the Layers List is SuiteWindow's sidebar root view, so the sidebar's outer `suite.sidebar` identifier replaces `design.layers`. Every other Design journey reaches the rows through `suite.sidebar`.
- LP-b fix round 2 (round 1 was #3316): P3 finds the list as `suite.sidebar`. This is test-only, on branch fix/design-p3-sidebar-list. If P3 is still red after this, #3307 becomes a gap and LP-b closes with `gaps:`.

- 2026-10-21T23:22Z: #4178 (LP-b fix round 2, Closes #3307) merged as 8c55f0bf9. Belt-Slice-Done for LP-b waits on a successful design or full ci.yml run that contains it. None is green yet: dev-red #3856.

- 2026-10-22T00:35Z LP-b round 2 (#4178) merged as 8c55f0bf9; done line waits on scoped design run 39693638859 (queued).
