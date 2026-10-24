# area-selection lead record

Issue: #3752 · Packet: docs/blueprints/suiteui/features/area-selection.md
Run: act-1a16cae7989-hj12 (line lead: area-selection, shared-codecs, shared-raw) · Session: claude/feature-lead-playbook-bs72fe · Started: 2026-10-24T06:50Z (earlier act-1a1693a4009-hyio, act-1a1693a3ff0-mwrd)
Stage: 3 wave 1
Base: origin/dev 830af22d
Next: wave 2: AR-photo-u (AR-11 tests first, stacked on AR-10) and AR-z build-ahead (Wire suite-imaging:IM-z); restack #4877 on dev + #4876; AR-design done once #4861 lands in a green suiteui/full run.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AR-a | kernel recipe, group pick, select.* stubs | AR-1, AR-2 | MJ-AR | – | false | 0 | done | 39632745681 | – |
| AR-m | join modes, lasso, outermost-group pick | AR-3, AR-4 | MJ-AR | AR-a | false | 0 | done | – | – |
| AR-u | SuiteUI ants and area tool options | AR-7, AR-8 | SJ-AR | AR-a | true | 0 | done | – | – |
| AR-r | recipe to CoreRaster mask in SuiteImaging | AR-5, AR-6 | MJ-AR-raster | AR-a, IM-a (met) | false | 0 | done (Belt-Slice-Done run 40029042081) | – | – |
| AR-photo-m | Photo selection on the kernel recipe | AR-9, AR-10 | MJ-AR-photo | AR-r | false | 0 | building (#4876, #4877) | – | – |
| AR-photo-u | Photo tools, Select menu, SuiteUI ants | AR-11, AR-12 | PJ-AR | AR-photo-m; adopt-suiteui-chrome:AC-colour | true | 0 | startable (AC-colour done; stacks on AR-photo-m) | – | – |
| AR-design | group click, enter, exit, deep pick | AR-13, AR-14 | DJ-AR | AR-m, AT-design (met) | true | 0 | building (#4860 merged, #4861 open) | – | – |
| AR-z | Photo copies deleted, C4, RJ-X70/71, built | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z | false | 0 | startable (contract-first: IM-a merged; Wire IM-z) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AR-5+6 | AR-r | 1 | AreaMask: recipe to a CoreRaster mask | Sources/SuiteImaging/Selection/AreaMask.swift, Tests/SuiteImagingTests/AreaMaskTests.swift, Tests/mutations/SuiteImaging.AreaMask.json | AreaMaskTests, Mutate 5/5 | #4842 → c6090464 | merged |
| AR-9 | AR-photo-m | 1 | PhotoAreaSelectionTests disabled, RJ-X70 pending | Tests/PhotoModelTests/PhotoAreaSelectionTests.swift, jobs | compiles, disabled | #4876 | open, fast-lane, base dev (head 230ce4d) |
| AR-10 | AR-photo-m | 1 | Photo selection through PhotoArea+Kernel; select.rect bounds params | Sources/PhotoModel/PhotoArea+Kernel.swift and callers | PhotoAreaSelectionTests, Mutate 2/2 | #4877 | open, stacked on #4876 (needs-split) |
| AR-14m | AR-design | 1 | click picks outermost group, ⌘ deep pick, select.* commands | Sources/DesignModel/DesignGroupPick+Kernel.swift, tests | DesignGroupPickTests, Mutate 4/4 | #4860 | merged 2026-10-23T21:42Z |
| AR-14v | AR-design | 1 | Enter/Exit Group menu, double-click, Return, Escape; DJ-AR journey on | Sources/DesignApp/…, UITests/DesignJourneyTests+Select.swift | journey + model test, Mutate 5/5 | #4861 | open, fast-lane, base dev (head 1067046) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
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
