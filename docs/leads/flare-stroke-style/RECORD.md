# flare stroke-style lead record

Issue: #3452 · Packet: docs/blueprints/flare/features/stroke-style.md
Run: act-1a157ad4612-4xcw · Session: claude/feature-lead-playbook-dp4pbl · Started: 2026-10-20T05:03Z
Stage: 3 polling (every slice blocked)
Base: 18464f26b93c6826d069e0107545d7aacfac033c
Next: wait for suiteui gradient-fill GF-a (#3421 GF-1, then GF-2) and flare gradient-fill FG-a (FG-1, FG-2) on origin/dev, and suiteui stroke-style SS-a (SS-1 VectorStroke/StrokeTarget); then wave 1: the FK-a PR (FK-1 stubs, FK-2 STROKE on the stubs)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FK-a | The adapter is declared as stubs and STROKE is the shared editor with keyable trim rows. | FK-1, FK-2 | MJ-FK | gradient-fill:FG-a; suiteui stroke-style:SS-a | true | 0 | blocked | – | – |
| FK-u | The stage and PNG stroke the painted path with joins, caps and dashes, and the snapshots and render budget hold. | FK-3, FK-4 | J-FK | FK-a; SS-u (FK-4) | true | 0 | blocked | – | – |
| FK-m | Every stroke command is one step for the selection, trim keys at the playhead when animated, and the commands run from the catalog. | FK-5, FK-6 | MJ-FK | FK-a; gradient-fill:FG-m; shape-tools:FS-m; SS-d and the core bump (FK-5, FK-6) | false | 0 | blocked | – | – |
| FK-z | The journey draws a logo on with trim keys on live services, and the feature is built. | FK-7, FK-8 | J-FK | FK-u, FK-m | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FK-1 | FK-a | 1 | adapter stubs; FlareStrokeTests disabled | Sources/FlareModel/FlareStroke+Kernel.swift, Tests/FlareModelTests/FlareStrokeTests.swift | suite compiles, disabled | – | waiting FG-a, SS-a |
| FK-2 | FK-a | 1 | STROKE is StrokeEditor with trim key diamonds on the stubs; journey written, skipped | Sources/FlareApp/FlareInspectorFill.swift, UITests/FlareJourneyTests+Stroke.swift | FlareInspectorSnapshots | – | waiting FK-1 |
| FK-3 | FK-u | 2 | stage and PNG stroke StrokeRules.paintedPath | Sources/FlareApp/StagePath.swift, Sources/FlareApp/StageRasterizer.swift, Tests/AppSnapshotTests/FlareStrokePaintTests.swift | FlareStrokePaintTests | – | waiting FK-a |
| FK-4 | FK-u | 3 | snapshots and render budget | Tests/AppSnapshotTests/FlareStrokeSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetFlareStrokeTests.swift | RenderBudgetFlareStrokeTests.trimScrubInThreeBodies | – | waiting FK-3 |
| FK-5 | FK-m | 2 | adapter bodies through shape.setStroke; trim keys when animated | Sources/FlareModel/FlareStroke+Kernel.swift, Tests/FlareModelTests/FlareStrokeTests.swift, Tests/mutations/FlareModel.FlareStroke+Kernel.json | FlareStrokeTests | – | waiting FK-a, SS-d, core bump |
| FK-6 | FK-m | 3 | nine specs in the catalog; RJ-F02 | Sources/FlareModel/FlareCommandCatalog.swift, Tests/command-ids/flare.txt, Tests/FlareModelTests/FlareStrokeCommandIDTests.swift, Tests/RealJobs/flare/trim-draw-on/* | RJ-F02 on Linux | – | waiting FK-5, FG-m, FS-m |
| FK-7 | FK-z | 4 | journey on live | UITests/FlareJourneyTests+Stroke.swift | testTrimDrawOn | – | waiting FK-4, FK-6 |
| FK-8 | FK-z | 5 | status built; feature-done | docs/blueprints/flare/features/stroke-style.wave.json | scripts/waves render --dry-run | – | waiting FK-7 |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Base and PR target is dev (CLAUDE.md, lead.md), not the brief's main: main b3011ab9 is an ancestor of dev and the packet exists only on dev.
- Lead branch is lead/flare-stroke-style, not the packet's lead/stroke-style: that branch is the suiteui stroke-style lead's (#3450, run act-1a157ad4600-c6w5). Same naming as lead/suiteui-gradient-fill.
- v3 loop (the packet has a Slices table); at most 2 fix rounds per slice.
- One PR per slice (rule 22): FK-1+FK-2 as the FK-a PR, its first commit the disabled FlareStrokeTests; FK-5+FK-6 as FK-m; FK-3+FK-4 as FK-u; FK-7+FK-8 as FK-z.
- FK-a also waits on suiteui SS-a, not only FG-a: the contract conforms FlareWorkspace to StrokeTarget and returns VectorStroke, and FK-2 uses StrokeEditor. Neither is on dev (rule 20: no app-local copy).

## Open
- Blocked: FG-a (lead/gradient-fill, #3419) waits on suiteui GF-a (#3421 GF-1 open). SS-a (lead/stroke-style, #3450) waits on GF-a too. No Flare stroke task can start.
