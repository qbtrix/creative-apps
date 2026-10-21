# flare stroke-style lead record

Issue: #3452 · Packet: docs/blueprints/flare/features/stroke-style.md
Run: act-1a15cf358c6-wj2q · Session: claude/feature-lead-playbook-lw6pjl · Resumed: 2026-10-21T05:39:14Z (line lead: stroke-style #3452, shape-tools #3451, key-select-all #3538)
Stage: parked (supervisor, #3452 07:20Z)
Base: 709f9283 (origin/dev); main 0dd23d65 verified
Next: parked until FG-2 (#3419, flare/gradient-fill) lands; Belt relaunches stroke-style then. FK-1 built and held (head d239cde7 on flare/fk-1-stroke-adapter, CI PASS, tests disabled until FK-5); the FK-a PR opens once FG-a is on dev (FK-2 edits FlareInspectorFill.swift after FG-2)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| FK-a | The adapter is declared as stubs and STROKE is the shared editor with keyable trim rows. | FK-1, FK-2 | MJ-FK | gradient-fill:FG-a (FK-2); SS-a met | true | 0 | building FK-1; FK-2 blocked on FG-a | – | – |
| FK-u | The stage and PNG stroke the painted path with joins, caps and dashes, and the snapshots and render budget hold. | FK-3, FK-4 | J-FK | FK-a; SS-u (FK-4) | true | 0 | blocked | – | – |
| FK-m | Every stroke command is one step for the selection, trim keys at the playhead when animated, and the commands run from the catalog. | FK-5, FK-6 | MJ-FK | FK-a; gradient-fill:FG-m; shape-tools:FS-m; SS-d and the core bump (FK-5, FK-6) | false | 0 | blocked | – | – |
| FK-z | The journey draws a logo on with trim keys on live services, and the feature is built. | FK-7, FK-8 | J-FK | FK-u, FK-m | true | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| FK-1 | FK-a | 1 | adapter stubs; FlareStrokeTests disabled | Sources/FlareModel/FlareStroke+Kernel.swift, Tests/FlareModelTests/FlareStrokeTests.swift | suite compiles, disabled | – | built, held: head d239cde7, CI PASS; PR with FK-2 |
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
- 2026-10-21 run act-1a15cf358c6-wj2q: FK-1 is built ahead of FG-a (it has no wait; only FK-2 waits on FG-a). Its branch is held without a PR until FK-2 can join it, so the FK-a PR stays one slice.
- Base and PR target is dev (CLAUDE.md, lead.md), not the brief's main: main b3011ab9 is an ancestor of dev and the packet exists only on dev.
- Lead branch is lead/flare-stroke-style, not the packet's lead/stroke-style: that branch is the suiteui stroke-style lead's (#3450, run act-1a157ad4600-c6w5). Same naming as lead/suiteui-gradient-fill.
- v3 loop (the packet has a Slices table); at most 2 fix rounds per slice.
- One PR per slice (rule 22): FK-1+FK-2 as the FK-a PR, its first commit the disabled FlareStrokeTests; FK-5+FK-6 as FK-m; FK-3+FK-4 as FK-u; FK-7+FK-8 as FK-z.
- FK-a also waits on suiteui SS-a, not only FG-a: the contract conforms FlareWorkspace to StrokeTarget and returns VectorStroke, and FK-2 uses StrokeEditor. Neither is on dev (rule 20: no app-local copy).

## Open
- 2026-10-21T13:09Z: resumed on Belt's 30-min nudge; still parked until FG-2 #3419 (open) lands, per the supervisor on #3452.
- 2026-10-21T07:32Z: parked. Supervisor (#3452, 07:20Z): FG-2 belongs to #3419, re-armed and waiting for a Belt slot; don't build it here. No startable FK slice: FK-2 waits FG-2, FK-5 waits SS-d (SS-7 #3823 now needs-fix, SS-9 #3826 open). The run continues for shape-tools and key-select-all, which have PRs in the lane (#3850, #3921).
- FK-5 note from the FK-1 builder: stroke.dash and stroke.trim still throw notBuilt (StrokeRules.waitingCore); FK-5 also needs SS-7 and the core bump with trim tracks.
- 2026-10-21T05:39Z: SS-a, SS-u and SS-m are done (suiteui RECORD); the core bump #3549 is on dev. SS-d still waits (SS-7 #3823, SS-9 #3826 open). FG-a: FG-1 merged, FG-2 waits on GF-2 #3695 (open, fast-lane); #3419 is parked needs-human. FK-1 has no wait, so it builds now; FK-2, FK-5 and FK-6 stay blocked.
- Comments posted from this session get a server-appended attribution footer that an edit can't remove; Belt lines stay first, and comments are kept to the required ones.
- Blocked: FG-a (lead/gradient-fill, #3419) waits on suiteui GF-a (#3421 GF-1 open). SS-a (lead/stroke-style, #3450) waits on GF-a too. No Flare stroke task can start.
