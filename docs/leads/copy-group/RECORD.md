# copy-group lead record

Issue: #1496 · Packet: docs/blueprints/design/features/copy-group.md
Run: act-1a14d32dfd7-u3ff (before: act-1a14a88d756-rnok) · Session: claude/layers-panel-style-rows-copy-group-x5zrpm · Started: 2026-10-17T15:46Z
Stage: 3 polling
Base: 6bb1f3f6072b1873c4827a682b9c1a750dac8f70
Next: wait for a completed, successful ci.yml run on dev (scoped design or full) that contains #2558 (6bb1f3f6); then re-post Belt-Slice-Done CG-a and Belt-Contact-Sheet on #1496 with that run

Line lead (rule 19) over #1498 layers-panel, #1497 style-rows and #1496 copy-group.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CG-a | duplicate and Option-drag copy, group and ungroup, cut copy paste also between files | C-1, C-2, C-3, C-4, C-5, built | J7, J8, J9 | design-seams (C-1, C-5); design-window DW-a (C-4, C-5), DW-b (C-4) | no ("ui_slice": "none") | 0 | merged | 39093416270 (in progress, lacks #2558) | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| C-2 | CG-a | 1 | LiveGrouping: group, ungroup, names, refusals | Sources/DesignModel/Live/LiveGrouping.swift; Tests/DesignModelTests/DesignGroupTests.swift; Tests/mutations/DesignModel.LiveGrouping.json | DesignGroupTests | #2166 | merged |
| C-1 | CG-a | 2 | LiveDuplicating: duplicate, Option-drag one step | Sources/DesignModel/Live/LiveDuplicating.swift; Tests/DesignModelTests/DesignDuplicateTests.swift; Tests/mutations/DesignModel.LiveDuplicating.json | DesignDuplicateTests | #2230 | merged |
| C-3 | CG-a | 3 | LiveClipboard and LayerPayload v1 | Sources/DesignModel/Live/LiveClipboard.swift; Tests/DesignModelTests/DesignPasteboardTests.swift; Tests/mutations/DesignModel.LiveClipboard.json | DesignPasteboardTests | #2255 | merged |
| C-4 | CG-a | 4 | duplicate, group, paste snapshots; Option-drag check | Tests/AppSnapshotTests/DesignDuplicateSnapshots.swift, DesignGroupSnapshots.swift, DesignPasteboardSnapshots.swift, DesignArrangeDragTests.swift | the snapshots | #2389 | merged |
| C-5 | CG-a | 5 | J7, J8, J9; closes #414 #415 #416 | UITests/DesignJourneyTests+Arrange.swift | J7, J8, J9 | #2470, #2479 | merged |
| built | CG-a | 6 | copy-group.wave.json status built; feature-done | docs/blueprints/design/features/copy-group.wave.json | scripts/ci | #2558 | merged (6bb1f3f6) |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-18T04:11Z relaunch (run act-1a14d32dfd7-u3ff): lead/copy-group rebuilt as one record commit on origin/main 0965457c (brief rule 2); the old branch carried 1140 heartbeat and integration commits, so its records were carried over instead of replaying them.
- The brief counts a slice done only on a completed, successful ci.yml run. The 03:53Z Belt-Slice-Done and Belt-Contact-Sheet cite 39093416270, still in progress and on 0965457c, which lacks the slice's last PR #2558. Both get re-posted on a run that holds 6bb1f3f6.
- PRs target `dev`: the fast lane's base (CLAUDE.md, scripts/fast-lane.sh); main is a promoted dev SHA.
- CG-a is Model and tests only (no UI slice): no critic panel on screens.

## Open
- None blocking. Waiting on a design scoped or full run that contains #2558.
