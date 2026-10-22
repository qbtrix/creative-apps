# svg-place lead record

Issue: #3459 · Packet: docs/blueprints/flare/features/svg-place.md
Run: act-1a15b1de023-4xx7 · Started: 2026-10-20T21:05Z (line lead: flare-export #1973, shape-tools #3451, svg-place #3459)
Stage: 3 (wave 1)
Base: 6c2c7b05 (origin/dev)
Next: PF-a slice PR (PF-1, PF-2) building

Loop: v3 (the packet has a `## Slices` table).

Last stage: #3768 PF-a waiting in lane bisect of batch-20261021005140 (probe -4 timing retry 3 of 3 running)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PF-a | PlacedImageTarget conformance and report as stubs; checks and RJ-F06 written, disabled | PF-1, PF-2 | MJ-PF | suiteui PL-a (on dev) | no | 0 | in lane (#3768) | | |
| PF-u | Place… and window drop on the stubs; report; snapshots, budget, journey written | PF-3, PF-4 | FJ-P1 | PF-a; key-select-all:KS-a (FlareCommands.swift); adopt-command-catalog AC-flare | yes | 0 | waiting (KS-a planned) | | |
| PF-m | groups as layers, fitted, one undo step; rasters refused; catalog | PF-5, PF-6 | MJ-PF | PF-a; gradient-fill:FG-m (PF-6); PL-7; shape-tools:FS-m; stroke-style:FK-m | no | 0 | waiting | | |
| PF-z | live window and journey; flare.md lists Place | PF-7, PF-8 | FJ-P1 | PF-u, PF-m; gradient-fill:FG-z | no | 0 | waiting | | |

## Decisions
- Base and PR target are dev (CLAUDE.md; the lane retargets main to dev), though the brief names main.
- SuiteKernel's PlacedImageTarget, PlaceRules and PlaceVector are on dev, so PL-a and PL-7 are met.
- PF-u waits on key-select-all KS-a (FlareCommands.swift) and PF-m on gradient-fill FG-m, FS-m, FK-m; all Flare-line features still planned except FS-m (this lead).
