# svg-place lead record

Issue: #3459 · Packet: docs/blueprints/flare/features/svg-place.md
Run: act-1a1615504d4-d9p4 (resumed 2026-10-22; prior run act-1a15b1de023-4xx7, started 2026-10-20T21:05Z) (line lead: flare-export #1973, shape-tools #3451, svg-place #3459)
Stage: 3 (wave 2)
Base: e9933116 (origin/dev)
Next: wave 2 builders: PF-u slice PR (PF-3, PF-4) and PF-m slice PR (PF-5 only)

Loop: v3 (the packet has a `## Slices` table).

Last stage: PF-a done (#3768 merged 3471e810; scoped flare run 39540755137 green, slice-done posted)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PF-a | PlacedImageTarget conformance and report as stubs; checks and RJ-F06 written, disabled | PF-1, PF-2 | MJ-PF | suiteui PL-a (on dev) | no | 0 | done (#3768, 3471e810) | https://github.com/qbtrix/creative-apps/actions/runs/39540755137 | |
| PF-u | Place… and window drop on the stubs; report; snapshots, budget, journey written | PF-3, PF-4 | FJ-P1 | PF-a; key-select-all:KS-a (FlareCommands.swift); adopt-command-catalog AC-flare | yes | 0 | building (wave 2) | | |
| PF-m | groups as layers, fitted, one undo step; rasters refused; catalog | PF-5, PF-6 | MJ-PF | PF-a; gradient-fill:FG-m (PF-6); PL-7; shape-tools:FS-m; stroke-style:FK-m | no | 0 | PF-5 building (wave 2); PF-6 waits on FS-6, FK-m | | |
| PF-z | live window and journey; flare.md lists Place | PF-7, PF-8 | FJ-P1 | PF-u, PF-m; gradient-fill:FG-z | no | 0 | waiting | | |

## Decisions
- Base and PR target are dev (CLAUDE.md; the lane retargets main to dev), though the brief names main.
- SuiteKernel's PlacedImageTarget, PlaceRules and PlaceVector are on dev, so PL-a and PL-7 are met.
- PF-u waits on key-select-all KS-a (FlareCommands.swift) and PF-m on gradient-fill FG-m, FS-m, FK-m; all Flare-line features still planned except FS-m (this lead).
- 2026-10-22 resume: KS-a (#3921) and AC-flare are on dev, so PF-u starts. FG-m is merged, so PF-6's gradient wait is met.
- PF-5 is unchained from shape-tools FS-m and stroke-style FK-m: it owns only FlarePlace+Kernel.swift, its tests and its mutation plan, none of which those slices touch. PF-6 shares FlareCommandCatalog.swift and Tests/command-ids/flare.txt with them, so it keeps waiting on FS-6 and FK-m and ships as its own PR.
- A stray `lead/flare-svg-place` branch left by Belt is ignored; this record lives on `lead/svg-place`.
- The packet wants "Flare places SVG files." for a PNG, but PlaceCommands refuses an off-format file with the generic PlaceRules.formatHelp. PF-5 must produce Flare's sentence on the Flare side (rasterSize / insertPlaced) without editing SuiteKernel.
