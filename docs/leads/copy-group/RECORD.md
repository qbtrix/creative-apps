# copy-group lead record

Issue: #1496 · Packet: docs/blueprints/design/features/copy-group.md
Run: act-1a14a88d756-rnok · Session: claude/design-feature-lead-7saqm8 · Started: 2026-10-17T15:46Z
Stage: 3 wave 1
Base: dd7ec767cc0afab91b35ff4f208351dd866028d8
Next: wave 1 builds C-2; C-1 (and C-3 after it) waits on design-seams merging D0-3c

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CG-a | duplicate and Option-drag copy, group and ungroup, cut copy paste also between files | C-1, C-2, C-3, C-4, C-5 | J7, J8, J9 | design-seams (C-1, C-5); design-window DW-a (C-4, C-5), DW-b (C-4) | no ("ui_slice": "none") | 0 | building | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| C-2 | CG-a | 1 | LiveGrouping: group, ungroup, names, refusals | Sources/DesignModel/Live/LiveGrouping.swift; Tests/DesignModelTests/DesignGroupTests.swift; Tests/mutations/DesignModel.LiveGrouping.json | DesignGroupTests | – | building |
| C-1 | CG-a | 2 | LiveDuplicating: duplicate, Option-drag one step | Sources/DesignModel/Live/LiveDuplicating.swift; Tests/DesignModelTests/DesignDuplicateTests.swift; Tests/mutations/DesignModel.LiveDuplicating.json | DesignDuplicateTests | – | waits design-seams |
| C-3 | CG-a | 3 | LiveClipboard and LayerPayload v1 | Sources/DesignModel/Live/LiveClipboard.swift; Tests/DesignModelTests/DesignPasteboardTests.swift; Tests/mutations/DesignModel.LiveClipboard.json | DesignPasteboardTests | – | waits C-1 (copySubtree) |
| C-4 | CG-a | 4 | duplicate, group, paste snapshots; Option-drag check | Tests/AppSnapshotTests/DesignDuplicateSnapshots.swift, DesignGroupSnapshots.swift, DesignPasteboardSnapshots.swift, DesignArrangeDragTests.swift | the snapshots | – | waits C-1..C-3, DW-a, DW-b |
| C-5 | CG-a | 5 | J7, J8, J9; feature-done; closes #414 #415 #416 | UITests/DesignJourneyTests+Arrange.swift | J7, J8, J9 | – | waits C-1..C-3, design-seams, DW-a |

C-2 has no waits: it runs in wave 1 beside design-window D0-5a and D0-5b (disjoint files).

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main (CLAUDE.md). main verified at 2c5003b.
- CG-a is Model and tests only (no UI slice), so its review is a Model walk; no critic panel on screens until C-4's snapshots.
- Builder branches are lead/copy-group-<task>.

## Open
- C-1 and C-5 wait on design-seams (#1493), which has not built wave 1 (D0-3c); its RECORD stalls on a missing Swift toolchain.
