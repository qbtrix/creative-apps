# timeline-keys lead record

Issue: #3780 · Packet: docs/blueprints/suiteui/features/timeline-keys.md
Run: act-1a1620043af-tzh0 · Started: 2026-10-22T05:00Z (resumed from act-1a15fddd101-68r5)
Stage: 3 wave 2
Base: 0dd23d659f4dbd8a0120aa85a321259327518251 (main); dev 8cf02113
Next: build TK-flare (TK-7 + TK-8) as one slice PR off dev; TK-u critic panel once scoped suite run 39721019643 shows its screens; TK-6 waits on AJ-halo, TS-halo, AN-halo

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TK-a | ColorKeyRules/SpanRules stubs, Halo span spec stubs, disabled suites | TK-1, TK-2 | – | frame-rates:FR-a (merged) | false | 0 | done #4183 | 39724795297 | – |
| TK-u | Flare key buttons; TimelineStrip onSlide; Halo timeline on stubs | TK-3, TK-4 | FlareJourneyTests+FillKeys, HaloJourneyTests+Span (skipped) | TK-a, timeline, timeline-select-all | true | 0 | done #4191 | 39724795297 | wanted |
| TK-m | rule bodies; Halo span bodies | TK-5, TK-6 | – | TK-a; TK-6: AE-halo, AJ-halo, TS-halo, AN-halo | false | 0 | TK-5 merged #4185; TK-6 blocked | – | – |
| TK-flare | Flare colour keys on live | TK-7, TK-8 | FJ-TK | TK-5 (#4185), AE-flare (done), TK-u (#4191) | true | 0 | building | – | – |
| TK-z | Halo timeline on live; status built; feature-done | TK-9, TK-10 | HJ-TK, RJ-H51 | TK-m, TK-u, TK-flare | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TK-1 | TK-a | 1 | rules stubs + disabled suites + keys part | Sources/SuiteKernel/Keys/ColorKeyRules.swift, Sources/SuiteKernel/Keys/SpanRules.swift, Tests/SuiteKernelTests/ColorKeyRulesTests.swift, Tests/SuiteKernelTests/SpanRulesTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-keys.json | suites compile, disabled; HaloSpanTests.specsDeclared | #4183 | merged |
| TK-2 | TK-a | 1 | Halo layer.slide/layer.trim specs, runs throw NotBuilt | Sources/HaloModel/HaloSpan+Kernel.swift, Tests/HaloModelTests/HaloSpanTests.swift | compiles, disabled | #4183 | merged |
| TK-3 | TK-u | 2 | Flare fill/stroke key buttons on stubs | Sources/FlareApp/FlareInspectorFill.swift, UITests/FlareJourneyTests+FillKeys.swift | buttons exist with ids | #4191 | merged |
| TK-4 | TK-u | 2 | TimelineStrip onSlide; Halo timeline passes slide/trim | Sources/SuiteUI/TimelineStrip.swift, Sources/SuiteUI/TimelineLaneInput.swift, Sources/HaloApp/HaloTimelineView.swift, UITests/HaloJourneyTests+Span.swift, Tests/AppSnapshotTests/RenderBudgetTimelineSpanTests.swift | RenderBudgetTimelineSpanTests.slideDragInThreeBodies | #4191 | merged |
| TK-5 | TK-m | 2 | ColorKeyRules + SpanRules bodies | Sources/SuiteKernel/Keys/ColorKeyRules.swift, Sources/SuiteKernel/Keys/SpanRules.swift, Tests/SuiteKernelTests/ColorKeyRulesTests.swift, Tests/SuiteKernelTests/SpanRulesTests.swift, Tests/mutations/SuiteKernel.ColorKeyRules.json, Tests/mutations/SuiteKernel.SpanRules.json | ColorKeyRulesTests, SpanRulesTests | #4185 | merged |
| TK-6 | TK-m | – | Halo span bodies, catalog, ledger | Sources/HaloModel/HaloSpan+Kernel.swift, Sources/HaloModel/HaloLayer.swift, Sources/HaloModel/HaloCommandCatalog.swift, Tests/command-ids/halo.txt, Tests/HaloModelTests/HaloSpanTests.swift, Tests/mutations/HaloModel.HaloSpan+Kernel.json | HaloSpanTests | – | blocked |
| TK-7..TK-10 | TK-flare, TK-z | – | see packet | see packet | see packet | – | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PR base is `dev` (CLAUDE.md; the lane retargets `main` to `dev` anyway).
- TK-1 and TK-2 ship as one TK-a slice PR (rule 22).
- TK-m is split: TK-5 (kernel bodies) ships now as its own PR stacked on TK-a, since TK-6 waits on AJ-halo, TS-halo and AN-halo, which are far off; TK-6 follows as the slice's second PR.

- Hand-offs (packet): FG-a, FK-a (FlareInspectorFill), KE-a and CL-probe (HaloTimelineView) are in `planned` features. Open PRs #4055 (2 lines in FlareInspectorFill), #4147 and #4166 (8 lines in HaloTimelineView) touch the same files; their edits are small, so TK-u goes ahead and the lane integrates any conflict.
- Builders build the stacked slices one after another in one worktree; the lead opens the PRs.
- Status channel: this run's brief names `lead/timeline-keys` with `docs/leads/timeline-keys/`; the record is kept there (the suiteui- copy is frozen at 04:44Z).
- TK-5 (#4185) is stacked with base `tk-a-timeline-keys-contract` (115 lines own; 446 against dev, over the cap); retargeted to dev and merged with dev once #4183 lands. TK-u is built on branch `tk-u-timeline-keys-ui` from TK-a and gets the same treatment.
- TK-a deviations (builder): the kernel-keys C4 description stays as is (gate refuses description edits; the new files are owned through `paths`); no locked-layer check (HaloLayer has no lock); signatures use `FlareCore.Color` to avoid clashing with SwiftUI's `Color`.
- Risk for TK-6: `TimelineEditing.trimmed` is in SuiteUI (macOS only), so HaloModel's trim body needs its maths in SuiteKernel.

- TK-u (#4191): stacked on TK-a, 351 lines against it. Flare paint stopwatches are disabled with the TK-7 reason (FlareModel has no paint-key API yet; TK-7 supplies keyState/keyHelp). Halo slide/trim are closures TK-9 wires. The stopwatch is its own FlarePaintKey view to pass the duplicate-view lint; a shared KeyframedSliderRow would be a needs-ui ask. No new mutation entries: SuiteUI can't be mutated on Linux.

- TK-7 is unchained from TK-6 (rule b): it needs only ColorKeyRules (TK-5, merged #4185), AE-flare (slice-done on #1937) and TK-u's stopwatches (#4191). TK-6 is Halo span code TK-7 never calls. TK-flare starts now.

## Open
- TK-6 waits on adjust-everywhere:AJ-halo, text-style:TS-halo, anchor-parenting:AN-halo (and adopt-kernel-easing:AE-halo, AE-h2 open #2842 in that RECORD).
- TK-u: timeline and timeline-select-all are built (#3537 closed); it starts once the TK-a branch is pushed.
