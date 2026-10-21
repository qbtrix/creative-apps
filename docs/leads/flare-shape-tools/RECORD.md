# shape-tools (Flare) lead record

Issue: #3451 · Packet: docs/blueprints/flare/features/shape-tools.md
Run: act-1a15cf358c6-wj2q · Resumed: 2026-10-21T05:39:14Z (line lead: stroke-style #3452, shape-tools #3451, key-select-all #3538)
Stage: 3 (wave 2)
Base: 0865916d (origin/dev); main 0dd23d65 verified
Next: #3850 (FS-5) merges in the lane; then FS-u re-opens as its own PR off dev (#3851 was 426 lines with FS-5 inside: needs-split) and #3851 closes

Loop: v3 (the packet has a `## Slices` table).

Last stage: FS-a merged-done: Belt-Slice-Done posted on #3451 for run 39538921285 (Linux green at dccfa541, contains #3767). #3850 macOS build green, mergeable, in the lane sweep. #3851 labelled needs-split by the supervisor sentinel.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FS-a | Shape tool, options in the inspector, adapter stubs | FS-1, FS-2 | MJ-FS | suiteui SH-a (merged ddf5b86e) | yes | 0 | done: Belt-Slice-Done (run 39538921285) | | |
| FS-u | draft previews, snapshots, render budget | FS-3, FS-4 | J-FS | FS-a | yes | 0 | gated, PR after FS-5 | | |
| FS-m | drafts on ShapeRules; draw adds one layer as one step | FS-5, FS-6 | MJ-FS | FS-a; gradient-fill:FG-m (FS-6) | no | 0 | building (FS-5); FS-6 blocked on FG-m | | |
| FS-z | journey live; built | FS-7, FS-8 | J-FS | FS-u, FS-m | no | 0 | waiting | | |

## Tasks
| id | slice | wave | PR | state |
|---|---|---|---|---|
| FS-1 | FS-a | 1 | #3767 | merged bd419110 |
| FS-2 | FS-a | 1 | #3767 | merged bd419110 |
| FS-5 | FS-m | 1 | | ready: CI PASS, mutate 6/6, head 1ddb3f44 on flare/fs-5-live-shapes-kernel; PR opens after #3767 merges (rebased onto dev; with FS-a it is 17 files) |
| FS-3, FS-4 | FS-u | 2 | | ready: CI PASS, mutate FlareModel.FlareDrag 3/3, head da0fbf19 on flare/fs-u-shape-drafts (stacked on FS-5); PR after FS-5; perf-list entry asked in #3781 |
| FS-6 | FS-m | 2+ | | waits gradient-fill FG-m (FlareCommandCatalog.swift, Tests/command-ids/flare.txt); Flare gradient-fill is planned, no lead |
| FS-7 | FS-z | 3 | | waits FS-u, FS-m |
| FS-8 | FS-z | 4 | | feature-done |

## Decisions
- 2026-10-21 run act-1a15cf358c6-wj2q: #3851 is not hand-merged or widened. Once #3850 merges, FS-3+FS-4 go up again as one PR off dev (about 305 lines, 10 files) and #3851 closes, as the sentinel asked.
- FS-6 stays blocked on FG-m, which waits on KS-a (key-select-all, building in this run) and on FG-a.
- Lead branch is lead/flare-shape-tools: lead/shape-tools is the SuiteUI shape-tools lead's (#3449).
- Base and PR target are dev (CLAUDE.md; the lane retargets main to dev), though the brief names main.
- SuiteKernel's ShapeSpec, ShapeRules.dragged/path and SuiteUI's ShapeToolOptions are on dev, so SH-a, SH-m and SH-u are met.
- FS-5 starts in wave 1 beside FS-a: it touches only LiveShapes and its tests, none of FS-1's files (rule 18).
