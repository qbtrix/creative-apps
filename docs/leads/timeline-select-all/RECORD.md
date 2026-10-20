# timeline-select-all lead record

Issue: #3537 · Packet: docs/blueprints/suiteui/features/timeline-select-all.md
Run: act-1a158c2e32e-bl3z · Session: claude/suiteui-feature-lead-i2krve · Started: 2026-10-20
Stage: 3 (TSA-a PR open)
Base: dev 11a545e7 (brief main b3011ab9dc5579023722e79f83254e6e2520e612 verified; PRs target dev)
Next: #3591 merged 12:42Z as 3e63a8ee; wait for Linux check 39424989659 on dev 897ccbb2 (contains it) to go green, then Belt-Slice-Done TSA-a, Mac-Finish-Wanted TSA-a, Belt-Contact-Sheet on #3537; critic panel on scoped suiteui run 39424969406 once it shows the screens.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| TSA-a | `TimelineStrip(onSelectAllKeys:)`; while the strip has focus ⌘A and the responder chain's Select All call it; the gallery picks every key from ⌘A or its Select All Keys button; render budget holds | TSA-1, TSA-2 | SJ19f | – | true | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| TSA-1 | TSA-a | 1 | `onSelectAllKeys` parameter, `TimelineSelectAll` focused value and `onCommand(selectAll:)` route; gallery Select All Keys button | Sources/SuiteUI/TimelineStrip.swift, Sources/SuiteUI/TimelineStrip+Keys.swift, Sources/SuiteUI/Gallery/GalleryTimeline.swift, Tests/SuiteUITests/TimelineSelectAllTests.swift, Tests/mutations/SuiteUI.TimelineStrip+Keys.json | TimelineSelectAllTests (focusedRouteWins, noRouteWithoutFocus); mutate plan | – | building |
| TSA-2 | TSA-a | 1 | journey SJ19f, snapshots light/dark, render budget, wave.json built; feature-done | UITests/SuiteJourneyTests+TimelineSelectAll.swift, Tests/AppSnapshotTests/SuiteTimelineSelectAllSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetSuiteTimelineSelectAllTests.swift, docs/blueprints/suiteui/features/timeline-select-all.wave.json | testTimelineSelectsAllKeys; suiteui-timeline-all-picked; selectAllInOneBody | – | building |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-20T10:05:45Z: one slice, so one wave: TSA-1 and TSA-2 ship as one slice PR (rule 22, 150-400 lines). PRs target dev; the brief's main b3011ab9 is behind dev, which the lane requires.
- 2026-10-20T10:05:45Z: API check (apple-docs): `View.onCommand(_:perform:)` is macOS 10.15+, fires only while the view or a descendant has focus; `View.focusedValue(_:_:)` macOS 11+. Both current.

## Open
