# copy-group lead record

Issue: #1496 · Packet: docs/blueprints/design/features/copy-group.md
Run: act-1a14644dd70-3gpr · Session: unknown · Started: 2026-10-16T19:53Z
Stage: 2 plan (blocked)
Base: origin/dev 98414eb83d8f326ece464f1637a61c30450a1372 (the brief names main 8b414fc; CLAUDE.md says dev is the only integration base, so PRs target dev)
Next: wait for design-seams (C-1, C-5) and design-window DW-a/DW-b (C-4, C-5) to merge; then run C-4 and C-5

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CG-a | duplicate, Option-drag, group/ungroup, cut/copy/paste | C-1..C-5 | J7, J8, J9 | design-seams; design-window DW-a, DW-b | none | 0 | building | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| C-1 | CG-a | 1 | LiveDuplicating | Live/LiveDuplicating.swift; DesignDuplicateTests.swift | DesignDuplicateTests | - | file present on dev, tests not verified (no Swift toolchain here); waits design-seams |
| C-2 | CG-a | 1 | LiveGrouping | Live/LiveGrouping.swift; DesignGroupTests.swift | DesignGroupTests | - | file present on dev, tests not verified; unblocked by design-contracts |
| C-3 | CG-a | 2 | LiveClipboard | Live/LiveClipboard.swift; DesignPasteboardTests.swift | DesignPasteboardTests | - | file present on dev, tests not verified; waits C-1 |
| C-4 | CG-a | 3 | three snapshots + Option-drag check | AppSnapshotTests/Design{Duplicate,Group,Pasteboard}Snapshots.swift, DesignArrangeDragTests.swift | snapshots | - | waiting: C-1..C-3, DW-a, DW-b |
| C-5 | CG-a | 3 | J7, J8, J9 | UITests/DesignJourneyTests+Arrange.swift | journeys | - | waiting: C-1..C-3, design-seams, DW-a; carries feature-done |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base is origin/dev, not main: CLAUDE.md forbids targeting main and the brief's "integration branch: main" conflicts with it.
- Lead status is recorded on the designated branch claude/design-line-lead-nq14ye, not on lead/copy-group, because the session may only push to its designated branch.
- No builder swarm started this run: the Model files already exist on dev, no Swift toolchain is installed here to run scripts/ci, and every remaining task waits on an unbuilt packet.

## Open
- design-seams and design-window (DW-a, DW-b) show status "planned" in their wave.json; not verified on dev.
- No fix or review yet. No Belt-Slice-Done lines posted.
