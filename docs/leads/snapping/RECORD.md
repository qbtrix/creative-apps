# snapping lead record

Issue: (feature issue not filed by this lead yet; gap and needs-ui issues not filed) · Packet: docs/blueprints/design/features/snapping.md
Run: act-1a1465d47db-qxmg · Session: this session · Started: 2026-10-16T20:49Z
Stage: 1 packet
Base: 1d68b2288cfe9c31e6b7cea460f5eb1ada5ddd18 (origin/dev, 1d68b22)
Next: plan wave 1 (SN-1, the contract) once a Swift toolchain is available; file the gap and needs-ui issues after the supervisor confirms

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SN-a | guide types, modifier, candidates, engine shape and stubs | SN-1, SN-9 | MJ12 | design-contracts (built) | no | 0 | planned | – | – |
| SN-e | snap engine: edges/centres, gaps and spacing | SN-2, SN-3 | MJ10 | SN-a | no | 0 | planned | – | – |
| SN-b | move, resize, draw snap before whole points; ⌘ off | SN-4, SN-5 | MJ11 | SN-a, SN-e, design-seams, canvas-basics CB-a, select-several SS-b | no | 0 | waiting | – | – |
| SN-c | smart guides on canvas; View > Snap to Layers | SN-6, SN-7, SN-8 | testSnapAndSmartGuides | SN-a; design-window DW-d, DW-a; canvas-basics CB-c; files-history FH-b | yes | 0 | waiting | – | – |
| SN-f | live guides and budgets on the live services | SN-10, SN-11 | testSnapAndSmartGuides | SN-b, SN-e, SN-c | no | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SN-1 | SN-a | 1 | contract: guide types, snapCandidates, stub engines; MJ10 disabled, MJ12 written | Sources/DesignModel/DesignSnapping.swift, DesignSnapLines.swift, DesignSnapGaps.swift; DesignSnapCandidateTests, DesignSnapEngineTests | DesignSnapCandidateTests | – | planned |
| SN-9 | SN-a | 2 | stubs for the screen: snapGuides fake while a drag runs | Sources/DesignModel/DesignSnapping.swift | DesignSnapCandidateTests | – | planned (after SN-1) |
| SN-2 | SN-e | 2 | edges and centres: bucketed lines, offset, lines(on:) | Sources/DesignModel/DesignSnapLines.swift | DesignSnapLineTests | – | planned (after SN-1) |
| SN-3 | SN-e | 3 | distances and equal spacing: gaps(around:), spacingOffset | Sources/DesignModel/DesignSnapGaps.swift | DesignSnapGapTests, DesignSnapEngineTests | – | planned (after SN-2) |
| SN-6 | SN-c | 2 | journey skeleton, skipped by name | UITests/DesignJourneyTests+Snap.swift | journey (macOS) | – | planned (after SN-1) |
| SN-8 | SN-c | 3 | View > Snap to Layers, persisted | Sources/DesignModel/DesignIntent.swift, DesignCommands.swift; Tests/AppSnapshotTests/DesignSnapSettingTests.swift | DesignSnapSettingTests | – | waiting (design-window DW-a, canvas-basics CB-c, files-history FH-b) |
| SN-4 | SN-b | 4 | move, several move, Option-drag copy snap; engine built at press | DesignCanvasEditing.swift, DesignSnapping.swift | DesignSnapMoveTests, DesignSnapBudgetTests | – | waiting (SN-2, SN-3, SN-9; design-seams; CB-a; SS-b) |
| SN-5 | SN-b | 5 | resize and draw snap | DesignCanvasEditing.swift | DesignSnapResizeDrawTests | – | waiting (SN-4) |
| SN-7 | SN-c | 4 | guide overlay in DW-d's slot | DesignSnapGuides.swift, DesignCanvasFeedback.swift | DesignSnapGuideSnapshots, RenderBudgetDesignSnapTests | – | waiting (SN-6, SN-8, SN-9; DW-d) |
| SN-10 | SN-f | 6 | integrate: snapIsLive on live routes | UITests/DesignJourneyTests+Snap.swift | journey (macOS) | – | waiting (SN-5, SN-7) |
| SN-11 | SN-f | 7 | live render budget; carries feature-done | Tests/AppSnapshotTests/RenderBudgetDesignSnapTests.swift | RenderBudgetDesignSnapTests | – | waiting (SN-10) |

Waves follow the packet's tasks and the `.wave.json` waits; they are not yet checked with `scripts/waves check`.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Base: origin/dev (see design-seams RECORD).
- SN-a (SN-1, SN-9) is the only slice with no feature waits; the packet says SN-1 and SN-6 start once design-contracts closes, which it has.
- SN-4 and SN-5 touch DesignCanvasEditing.swift, which design-seams D0-3c also owns. Keep them in separate waves.

## Open
- File the one needs-ui issue (SuiteUI smart-guide marks with distance labels, labels needs-ui and line:suiteui) and one gap issue per slice (labels gap, line:design, p1). Not filed: waiting for supervisor OK, since these are GitHub writes.
- No Swift toolchain on PATH, so scripts/ci --changed cannot run here.
