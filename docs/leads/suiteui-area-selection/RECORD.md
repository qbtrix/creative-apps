# area-selection lead record

Issue: #3752 · Packet: docs/blueprints/suiteui/features/area-selection.md
Run: act-1a17bed1eba-upw1 (line lead: area-selection, fill-heal, adjust-everywhere; resumed 2026-10-27T05:58Z on main fef52e66) · earlier: act-1a1786024b0-c5o9 (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26T13:26Z) · earlier: act-1a175f7cb67-l7rh (line lead: clipboard-interop, area-selection, fill-heal; resumed 2026-10-26) · earlier: act-1a1702c56e8-b6cq (line lead: shared-raw, area-selection, fill-heal) · Session: claude/suiteui-feature-lead-run-8ka39r · Started: 2026-10-24T22:40Z (earlier act-1a16cae7989-hj12, act-1a16cae79dd-mtf2)
Stage: 3 wave 2 (wave-2 PRs open, gated; stacks in the lane)
Base: main fef52e66 (verified) / dev 5e4a0922
Next: #5096 (AR-photo-u) re-integrated at 4d85628f (merged origin/dev, scripts/ci --changed PASS, Head moved); waiting on the lane batch. When it merges retarget #5103, then #5254, #5256; Belt-Slice-Done on a green main run that contains the last AR-photo-u/AR-z PR.
Polled: 2026-10-27T20:02Z

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AR-a | kernel recipe, group pick, select.* stubs | AR-1, AR-2 | MJ-AR | – | false | 0 | done | 39632745681 | – |
| AR-m | join modes, lasso, outermost-group pick | AR-3, AR-4 | MJ-AR | AR-a | false | 0 | done | – | – |
| AR-u | SuiteUI ants and area tool options | AR-7, AR-8 | SJ-AR | AR-a | true | 0 | done | – | – |
| AR-r | recipe to CoreRaster mask in SuiteImaging | AR-5, AR-6 | MJ-AR-raster | AR-a, IM-a (met) | false | 0 | done (Belt-Slice-Done run 40029042081) | – | – |
| AR-photo-m | Photo selection on the kernel recipe | AR-9, AR-10 | MJ-AR-photo | AR-r | false | 0 | done (Belt-Slice-Done 40179648854) | – | – |
| AR-photo-u | Photo tools, Select menu, SuiteUI ants | AR-11, AR-12 | PJ-AR | AR-photo-m; adopt-suiteui-chrome:AC-colour | true | 0 | building (#5096 on #4877, #5103 on #5096) | – | – |
| AR-design | group click, enter, exit, deep pick | AR-13, AR-14 | DJ-AR | AR-m, AT-design (met) | true | 0 | done (Belt-Slice-Done posted) | 40129856269 | wanted (Mac-Finish-Wanted posted) |
| AR-z | Photo copies deleted, C4, RJ-X70/71, built | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z | false | 0 | startable (contract-first: IM-a merged; Wire IM-z) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AR-5+6 | AR-r | 1 | AreaMask: recipe to a CoreRaster mask | Sources/SuiteImaging/Selection/AreaMask.swift, Tests/SuiteImagingTests/AreaMaskTests.swift, Tests/mutations/SuiteImaging.AreaMask.json | AreaMaskTests, Mutate 5/5 | #4842 → c6090464 | merged |
| AR-9 | AR-photo-m | 1 | PhotoAreaSelectionTests disabled, RJ-X70 pending | Tests/PhotoModelTests/PhotoAreaSelectionTests.swift, jobs | compiles, disabled | #4876 | merged (7114d06f) |
| AR-10 | AR-photo-m | 1 | Photo selection through PhotoArea+Kernel; select.rect bounds params | Sources/PhotoModel/PhotoArea+Kernel.swift and callers | PhotoAreaSelectionTests, Mutate 2/2 | #4877 | merged (ee8ccd61a) |
| AR-14m | AR-design | 1 | click picks outermost group, ⌘ deep pick, select.* commands | Sources/DesignModel/DesignGroupPick+Kernel.swift, tests | DesignGroupPickTests, Mutate 4/4 | #4860 | merged 2026-10-23T21:42Z |
| AR-14v | AR-design | 1 | Enter/Exit Group menu, double-click, Return, Escape; DJ-AR journey on | Sources/DesignApp/…, UITests/DesignJourneyTests+Select.swift | journey + model test, Mutate 5/5 | #4861 | merged (4e48ef19, green full run 40129856269) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-26T02:14Z: Run act-1a175f7cb67-l7rh resumed. #5096 got needs-rebase (photo.list-commands.json conflict); fixing by merging origin/dev and regenerating the golden from `afterglow photo list-commands`.
- 2026-10-25T05:20Z: #5096 lost fast-lane at 578 lines after #4877 squash-merged; merged origin/dev (PhotoStroke/PhotoWorkspace both-sides fields, setArea kept, golden union by id), scripts/ci --changed PASS, pushed 7c7f27654, body Head moved and footer stripped, fast-lane re-added.
- 2026-10-25T04:45Z: #4877 merged; retargeted #5096 to dev (REST PATCH base=dev).
- 2026-10-25T02:50Z: Opened #5268 (docs-only C4, kernel-selection names AreaShape/AreaRecipe/GroupPick, head b0022ba4, CI: PASS, fast-lane). The 01:45Z stamps above were written at about 02:45Z.
- 2026-10-25T01:45Z: AR-z opened as #5254 (AR-15, 145 lines/15 files, head fb70b0ab) and #5256 (AR-16, feature-done, 94 lines/4 files, head ea17435d), both CI: PASS. The kernel-selection C4 description goes in a separate docs-only PR (check-c4-descriptions refuses it alongside code).
- 2026-10-25T01:15Z: wave 2: AR-z (AR-15+AR-16) building on AR-11-ui (Wire suite-imaging:IM-z); 0 open findings.
- 2026-10-25T01:20Z: replay done: #4877 (AR-10, 15 files), #5096 (AR-11, 11 files +387), #5103 (AR-11 ui, 12 files +281), all CI: PASS and fast-lane; AR-5/6 and AR-9 already on dev and dropped.
- 2026-10-24T23:20Z: dev was rewritten to a new root (4f00afb8, #5150); old slice branches share no history with it, so fixers replay each PR's own commits onto the new dev, split to the 400-line/15-file cap, re-gate and force-with-lease push the lead/* branches (same PR numbers).
- Status branch is lead/suiteui-area-selection (the name Belt reads); lead/area-selection kept as a mirror.
- Slice branches use dashes (lead/area-selection-AR-5 ...) since a ref lead/area-selection exists.
- AR-photo-m split into #4876 (tests) + #4877 (code): 17 files as one was over the 15-file cap.
- AR-design split into #4860 (Model) + #4861 (view): over 15 files as one.
- #4877 leaves the marquee's Shift/Option modes and ellipse out (not AR-10); RJ-X70 fills black (no brush-colour command yet).

## Open
- AR-photo-u: AC-colour done; only AR-photo-m (internal) remains, so it stacks on #4877.
- Wire: suite-imaging:IM-z [ ] (AR-z builds ahead on IM-a's merged contract; swap and tick once IM-z's Belt-Slice-Done lands)
- Open findings for this feature: 0.
- 2026-10-24T07:05Z: run act-1a16cae7989-hj12 resumes on dev 830af22d. Server-added footers removed from #4848, #4859, #4865, #4872 bodies so Head: is the last line again (#4828, #4861, #4875, #4876 already clean). Contract-first waits (rule 12) applied to the slice table.

- 2026-10-25T09:42Z: dev-red #5316 names #4877 in range; failures are Suite Home/Onboarding model timeouts, not Photo selection. AR-photo-m waits for a green full or scoped run containing #4877.
- 2026-10-25T10:06Z: AR-photo-m merged-done per lead.md rule 6 (newest dev CI containing #4877, 40179648854, Linux green); Belt-Slice-Done posted on #3752. ui:false, no Mac-Finish-Wanted.

## Packet-Review 2 (7e13ba02, 05:56Z)

Answered on #3752: both amendments (AreaSelectTarget Sendable with areaHelp and a mutating setter; AreaRecipe init() and isEmpty) are already on dev c480d848. Only the packet text is stale; AR-photo-u and AR-z need no change.

- 2026-10-27T06:02Z: dev-red #5818 is SuiteUI home/grid/tabs snapshots, not this feature; main holds at fef52e66. #5096 (AR-photo-u) clean and ready; #5103/#5254/#5256 stacked, conflict until #5096 lands.
- 2026-10-27T19:38Z 2026-10-27T19:38Z poll: dev 15ff48a3, main fef52e66, dev-red #5818 open (not ours); no lead PR merged; lane dropped needs-rebase on #5096; all parent PRs clean with fast-lane, waiting on local-ci/prescreen. AJ children dirty until their parents land.
- 2026-10-27T20:02Z 2026-10-27T20:02Z poll: dev still 15ff48a3 (no lane merge since 19:12), main fef52e66, dev-red #5818 open (not ours); all lead PRs clean with fast-lane, waiting on local-ci/prescreen (supervisor). AJ children dirty until parents land.
