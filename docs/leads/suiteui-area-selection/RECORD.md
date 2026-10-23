# area-selection lead record

Issue: #3752 · Packet: docs/blueprints/suiteui/features/area-selection.md
Run: act-1a1693a4009-hyio (line lead: area-selection, adjust-everywhere, shared-raw) · Session: claude/feature-lead-playbook-fkjibd · Started: 2026-10-23T14:40Z
Stage: 3 wave 1
Base: 35a0b5e7e9520a764f3eabf02968a453082a87cc
Next: check between waves: which of #4842, #4860, #4861, #4876, #4877 merged; retarget #4861 to dev once #4860 merges; post Belt-Slice-Done for AR-r / AR-design once a dev CI run with a green Linux job contains their last PR.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AR-a | kernel recipe, group pick, select.* stubs | AR-1, AR-2 | MJ-AR | – | false | 0 | done | 39632745681 | – |
| AR-m | join modes, lasso, outermost-group pick | AR-3, AR-4 | MJ-AR | AR-a | false | 0 | done | – | – |
| AR-u | SuiteUI ants and area tool options | AR-7, AR-8 | SJ-AR | AR-a | true | 0 | done | – | – |
| AR-r | recipe to CoreRaster mask in SuiteImaging | AR-5, AR-6 | MJ-AR-raster | AR-a, IM-a (met) | false | 0 | building (#4842) | – | – |
| AR-photo-m | Photo selection on the kernel recipe | AR-9, AR-10 | MJ-AR-photo | AR-r | false | 0 | building (#4876, #4877) | – | – |
| AR-photo-u | Photo tools, Select menu, SuiteUI ants | AR-11, AR-12 | PJ-AR | AR-photo-m; adopt-suiteui-chrome:AC-colour | true | 0 | waiting (AC-colour) | – | – |
| AR-design | group click, enter, exit, deep pick | AR-13, AR-14 | DJ-AR | AR-m, AT-design (met) | true | 0 | building (#4860, #4861) | – | – |
| AR-z | Photo copies deleted, C4, RJ-X70/71, built | AR-15, AR-16 | MJ-AR, PJ-AR, DJ-AR | AR-photo-m, AR-photo-u, AR-design; suite-imaging:IM-z | false | 0 | waiting (IM-z) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AR-5+6 | AR-r | 1 | AreaMask: recipe to a CoreRaster mask | Sources/SuiteImaging/Selection/AreaMask.swift, Tests/SuiteImagingTests/AreaMaskTests.swift, Tests/mutations/SuiteImaging.AreaMask.json | AreaMaskTests, Mutate 5/5 | #4842 | open, fast-lane (head 6b9c830) |
| AR-9 | AR-photo-m | 1 | PhotoAreaSelectionTests disabled, RJ-X70 pending | Tests/PhotoModelTests/PhotoAreaSelectionTests.swift, jobs | compiles, disabled | #4876 | open, stacked on #4842 (needs-split until base merges) |
| AR-10 | AR-photo-m | 1 | Photo selection through PhotoArea+Kernel; select.rect bounds params | Sources/PhotoModel/PhotoArea+Kernel.swift and callers | PhotoAreaSelectionTests, Mutate 2/2 | #4877 | open, stacked on #4876 (needs-split) |
| AR-14m | AR-design | 1 | click picks outermost group, ⌘ deep pick, select.* commands | Sources/DesignModel/DesignGroupPick+Kernel.swift, tests | DesignGroupPickTests, Mutate 4/4 | #4860 | open, fast-lane (head 44c5682) |
| AR-14v | AR-design | 1 | Enter/Exit Group menu, double-click, Return, Escape; DJ-AR journey on | Sources/DesignApp/…, UITests/DesignJourneyTests+Select.swift | journey + model test, Mutate 5/5 | #4861 | open, base lead/area-selection-AR-14 (retarget to dev after #4860) |

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
- AR-photo-u waits on adopt-suiteui-chrome AC-colour; AR-z waits on suite-imaging IM-z.
- Open findings for this feature: 0.
