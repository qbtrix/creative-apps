# snapping lead record

Issue: #1552 · Gaps: SN-a #2152, SN-e #2154, SN-b #2155, SN-c #2156, SN-f #2157 · needs-ui: #2151 · Packet: docs/blueprints/design/features/snapping.md
Run: act-1a159c9b6b4-va3c (resumes act-1a1543ffff8-c9jg and earlier) · Session: claude/design-lead-snapping-gradient-stroke-brepev · Started: 2026-10-20T14:50Z
Stage: 5 (done)
Base: 0dd23d65 (origin/dev); main verified at b3011ab9
Next: nothing; every slice is Belt-Slice-Done and the Belt-Contact-Sheet is posted on #1552. SN-c waits on the Mac finisher (Mac-Finish-Wanted posted).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| SN-a | guide types, modifier, candidates, engine shape and stubs | SN-1, SN-12, SN-9 | MJ12 | design-contracts (built); editor-kernel EK-a | no | 0 | done | – | – |
| SN-e | snap engine: edges/centres, gaps and spacing | SN-2, SN-3 | MJ10 | SN-a | no | 0 | done | – | – |
| SN-b | move, resize, draw snap before whole points; ⌘ off | SN-4, SN-5 | MJ11 | SN-a, SN-e, design-seams, canvas-basics CB-a, select-several SS-b | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39439525908 | – |
| SN-c | smart guides on canvas; View > Snap to Layers | SN-6, SN-7, SN-8 | testSnapAndSmartGuides | SN-a; design-window DW-d, DW-a; canvas-basics CB-c; files-history FH-b | yes | 1 | done | https://github.com/qbtrix/creative-apps/actions/runs/39439525908 | wanted |
| SN-f | live guides and budgets on the live services | SN-10, SN-11 | testSnapAndSmartGuides | SN-b, SN-e, SN-c | no | 0 | done | https://github.com/qbtrix/creative-apps/actions/runs/39439525908 | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| SN-1 | SN-a | 1 | contract on the kernel types (SN-12 folded in): typealiases, .noSnap, defaults key, snapGuides nil, snapCandidates via Snapping.candidates; MJ10 disabled, MJ12 written | Sources/DesignModel/DesignSnapping.swift; DesignSnapCandidateTests, DesignSnapEngineTests; Tests/mutations/DesignModel.DesignSnapping.json | DesignSnapCandidateTests | #3058 | merged 4ff4c7f5 (file is DesignSnapping+Kernel.swift: the adapter name check-dup-logic needs, rule 20) |
| SN-9 | SN-a | 2 | stubs for the screen: snapGuides fake while a drag runs | Sources/DesignModel/DesignSnapping.swift | DesignSnapCandidateTests | #3071 | merged 0cb8bb88 |
| SN-2 | SN-e | 1 | edges and centres: bucketed lines, offset, lines(on:) | Sources/SuiteKernel/Snap/SnapLines.swift; Tests/SuiteKernelTests/SnapLineTests.swift; Tests/mutations/SuiteKernel.SnapLines.json | SnapLineTests | #3066 | merged a86a6b92 |
| SN-3 | SN-e | 3 | distances and equal spacing: gaps(around:), spacingOffset | Sources/DesignModel/DesignSnapGaps.swift | DesignSnapGapTests, DesignSnapEngineTests | #3112 | merged 22026122 |
| SN-6 | SN-c | 1 | journey skeleton, skipped by name | UITests/DesignJourneyTests+Snap.swift | journey (macOS) | #3055 | merged 12008867 |
| SN-8 | SN-c | 3 | View > Snap to Layers, persisted | Sources/DesignModel/DesignIntent.swift, DesignCommands.swift; Tests/AppSnapshotTests/DesignSnapSettingTests.swift | DesignSnapSettingTests | #3282 | merged 8257c513 (feature-done; finish fixes #3326, #3390) |
| SN-4 | SN-b | 4 | move, several move, Option-drag copy snap; engine built at press | DesignCanvasEditing.swift, DesignSnapping.swift | DesignSnapMoveTests, DesignSnapBudgetTests | #3185 | merged |
| SN-5 | SN-b | 5 | resize and draw snap | DesignCanvasEditing.swift | DesignSnapResizeDrawTests | #3204 | merged 0d5e92ea |
| SN-7 | SN-c | 4 | guide overlay in DW-d's slot | DesignSnapGuides+Kernel.swift, DesignCanvasFeedback.swift | DesignSnapGuideSnapshots, RenderBudgetDesignSnapTests | #3246 | merged c5ec57aa |
| SN-10 | SN-f | 6 | integrate: snapIsLive on live routes | UITests/DesignJourneyTests+Snap.swift | journey (macOS) | #3254 | merged deed2777 |
| SN-11 | SN-f | 7 | live render budget | Tests/AppSnapshotTests/RenderBudgetDesignSnapTests.swift | RenderBudgetDesignSnapTests | #3254 | merged deed2777 |

Waves follow the packet's tasks and the `.wave.json` waits; they are not yet checked with `scripts/waves check`.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- 2026-10-20T14:55Z (act-1a159c9b6b4-va3c): SN-8 merged as #3282 and the finish fixes #3326 and #3390 are on dev, so snapping is built. Linux check 39439525908 on 9f880c85 (Linux job green) holds every slice's last PR: Belt-Slice-Done for SN-b, SN-c, SN-f, Mac-Finish-Wanted for SN-c, then Belt-Contact-Sheet on #1552. lead/snapping rebuilt on origin/main b3011ab9 with these two files (brief rule 2). Comments posted via REST get a tool footer appended; removed with the MCP comment edit.
- Lane macOS builds of #3246 (39259521758) and #3254 (39262123853) failed on two test-file errors: SnapGuideMarks needs `import SuiteUI`; `accessibilityValue?()` is ambiguous on AnyObject, read as `Any??`. Fixed on SN-c (eb8b40dd), merged into SN-f; lead fixed it directly (2-line fix, fix round 1 of 2 for SN-c (macOS build green after it)).
- SN-c's PR #3246 holds SN-7 only: CB-9 #3224 was still open at push. SN-8 follows as its own PR in SN-c; the journey keeps its "waits on SN-8" skip until then. File renamed DesignSnapGuides+Kernel.swift (view DesignGuideOverlay) because the duplicate-logic lint rejects another Snap-named file and DesignSnapGuides is a DesignModel typealias.
- SN-f (SN-10 + SN-11) builds now stacked on #3246 without feature-done; feature-done and wave status built ride the feature's last PR (SN-8), since a built status before View > Snap to Layers lands would be false.
- 2026-10-19T12:30Z (act-1a1543ffff8-c9jg): main and the old lead/snapping share no history, so lead/snapping is rebuilt on origin/main 6f9a2b88 with these two files (brief rule 2). PRs still go to dev (CLAUDE.md, the lane retargets main to dev); main only fast-forwards to green dev.
- Rule 22: SN-c ships as one PR (SN-7 then SN-8 in it when CB-9 #3224 has merged; DesignIntent.swift is shared with CB-9), SN-f (SN-10 + SN-11) as one PR stacked on it.
- 2026-10-19 (act-1a1517272b2-vq6l): editor-kernel EK-a and EK-snap are Belt-Slice-Done (#1933), so the kernel snap types and stub engines are on dev. SN-12 folds into SN-1: SN-1 writes DesignSnapping.swift straight on the kernel types (typealiases), so DesignSnapLines.swift and DesignSnapGaps.swift are never added and then removed.
- 2026-10-19: lead/snapping also carries heartbeats from Belt run act-1a14a8f0634-uwzw saying "stage 2, EK-a #1933 still open". This run (act-1a1517272b2-vq6l) builds on EK-a's kernel snap types, which are on dev (Sources/SuiteKernel/Snap/), and its wave 1 PRs are #3058, #3066, #3055. Both runs' timeline lines are kept.
- PR bodies: a REST body edit through the session proxy gets a tool footer appended again; edit bodies only with the GitHub MCP update_pull_request, which keeps them as written.
- SN-2 moves to wave 1: it fills the kernel's SnapLines stub, which exists, and shares no file with SN-1 or SN-6.
- Base is origin/dev (CLAUDE.md); main verified at 349578b8.
- Base: origin/dev (CLAUDE.md), confirmed by the supervisor on #1493.
- Snap engine types live in Sources/SuiteKernel/Snap/ (packet amendment #1898); never in DesignModel (rule 20). SN-1 and SN-12 wait on EK-a (#1933, no lead yet): supervisor decision on #1552, 2026-10-17T06:06Z.
- Filed gap issues per slice (#2152, #2154, #2155, #2156, #2157) and the needs-ui issue #2151.
- Base: a575d0351f2df6c5a0dff97d70eb59e860cc61b9 (origin/dev, a575d03)
- SN-a (SN-1, SN-9) is the only slice with no feature waits; the packet says SN-1 and SN-6 start once design-contracts closes, which it has.
- SN-4 and SN-5 touch DesignCanvasEditing.swift, which design-seams D0-3c also owns. Keep them in separate waves.

## Open
- SN-c: Mac-Finish from the finisher; #2156 and needs-ui #2151 stay open for it.
- design-window (#1494) is closed, so DW-a and DW-d are met; files-history FH-b is done.
