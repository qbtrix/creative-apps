# shape-tools (Flare) lead record

Issue: #3451 · Packet: docs/blueprints/flare/features/shape-tools.md
Run: act-1a15b1de023-4xx7 · Started: 2026-10-20T21:05Z (line lead: flare-export #1973, shape-tools #3451, svg-place #3459)
Stage: 3 (wave 1)
Base: 6c2c7b05 (origin/dev)
Next: FS-a slice PR (FS-1, FS-2) and FS-5 (FS-m's first task) building

Loop: v3 (the packet has a `## Slices` table).

Last stage: #3850 (FS-5) macOS build 39538905662 green, waiting on the lane's merge; #3851 (FS-u) held with no-fast-lane; full dev CI 39538921285 (contains #3767) queued for FS-a slice-done

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FS-a | Shape tool, options in the inspector, adapter stubs | FS-1, FS-2 | MJ-FS | suiteui SH-a (merged ddf5b86e) | yes | 0 | in lane (#3767) | | |
| FS-u | draft previews, snapshots, render budget | FS-3, FS-4 | J-FS | FS-a | yes | 0 | gated, PR after FS-5 | | |
| FS-m | drafts on ShapeRules; draw adds one layer as one step | FS-5, FS-6 | MJ-FS | FS-a; gradient-fill:FG-m (FS-6) | no | 0 | building (FS-5); FS-6 blocked on FG-m | | |
| FS-z | journey live; built | FS-7, FS-8 | J-FS | FS-u, FS-m | no | 0 | waiting | | |

## Tasks
| id | slice | wave | PR | state |
|---|---|---|---|---|
| FS-1 | FS-a | 1 | #3767 | in lane |
| FS-2 | FS-a | 1 | #3767 | in lane |
| FS-5 | FS-m | 1 | | ready: CI PASS, mutate 6/6, head 1ddb3f44 on flare/fs-5-live-shapes-kernel; PR opens after #3767 merges (rebased onto dev; with FS-a it is 17 files) |
| FS-3, FS-4 | FS-u | 2 | | ready: CI PASS, mutate FlareModel.FlareDrag 3/3, head da0fbf19 on flare/fs-u-shape-drafts (stacked on FS-5); PR after FS-5; perf-list entry asked in #3781 |
| FS-6 | FS-m | 2+ | | waits gradient-fill FG-m (FlareCommandCatalog.swift, Tests/command-ids/flare.txt); Flare gradient-fill is planned, no lead |
| FS-7 | FS-z | 3 | | waits FS-u, FS-m |
| FS-8 | FS-z | 4 | | feature-done |

## Decisions
- Lead branch is lead/flare-shape-tools: lead/shape-tools is the SuiteUI shape-tools lead's (#3449).
- Base and PR target are dev (CLAUDE.md; the lane retargets main to dev), though the brief names main.
- SuiteKernel's ShapeSpec, ShapeRules.dragged/path and SuiteUI's ShapeToolOptions are on dev, so SH-a, SH-m and SH-u are met.
- FS-5 starts in wave 1 beside FS-a: it touches only LiveShapes and its tests, none of FS-1's files (rule 18).
