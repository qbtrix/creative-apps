# snapping lead record

Issue: #1552 · Gaps: SN-a #2152, SN-e #2154, SN-b #2155, SN-c #2156, SN-f #2157 · needs-ui: #2151 · Packet: docs/blueprints/design/features/snapping.md
Run: act-1a14a8f0634-uwzw · Session: this session · Started: 2026-10-17T15:40Z (resumes act-1a1465d47db-qxmg)
Stage: 2 plan (waiting on editor-kernel EK-a)
Base: a575d0351f2df6c5a0dff97d70eb59e860cc61b9 (origin/dev, a575d03)
Next: no snapping task starts until editor-kernel EK-a (#1933) merges; then SN-1 and SN-12 (the kernel bridge) as wave 1

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SN-a | guide types, modifier, candidates, engine shape and stubs | SN-1, SN-12, SN-9 | MJ12 | design-contracts (built); editor-kernel EK-a | no | 0 | planned | – | – |
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
- Base: origin/dev (CLAUDE.md), confirmed by the supervisor on #1493.
- Snap engine types live in Sources/SuiteKernel/Snap/ (packet amendment #1898); never in DesignModel (rule 20). SN-1 and SN-12 wait on EK-a (#1933, no lead yet): supervisor decision on #1552, 2026-10-17T06:06Z.
- Filed gap issues per slice (#2152, #2154, #2155, #2156, #2157) and the needs-ui issue #2151.
- Base: a575d0351f2df6c5a0dff97d70eb59e860cc61b9 (origin/dev, a575d03)
- SN-a (SN-1, SN-9) is the only slice with no feature waits; the packet says SN-1 and SN-6 start once design-contracts closes, which it has.
- SN-4 and SN-5 touch DesignCanvasEditing.swift, which design-seams D0-3c also owns. Keep them in separate waves.

## Open
- editor-kernel EK-a (#1933) has no lead yet; every snapping slice waits on it.
