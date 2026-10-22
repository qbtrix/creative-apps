# design-stroke-style lead record

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a1605b0534-rn47 · Session: claude/feature-leads-stroke-eyedropper-e84htn · Started: 2026-10-21T21:05Z (prior runs act-1a15e909498-4bkk, act-1a15abb305f-lc8g, act-1a159c9b6b4-va3c)
Stage: DK-a done; DK-u waits on shape-tools DS-u (not started); DK-m on DS-m (2026-10-22T06:16Z)
Base: 5bec8089 (origin/dev); main verified at 0dd23d65
Next: DK-u waits shape-tools:DS-u (waits transform DT-u, building: DT-4 behind #4159); DK-m waits shape-tools:DS-m (waits DT-m: #4187 open, DT-6 after DG-m; and eyedropper DY-m). Re-read waits every poll

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section is StrokeEditor on them | DK-1, DK-2 | MJ-DK | SS-a (done) | yes | 2 | merged (3785460f); rounds spent (#3884, #4001); #3865 #3871 #3873 are gap p2 | 39670298178 | wanted (posted) |
| DK-u | canvas strokes dashes, joins, caps; snapshots, budget | DK-3, DK-4 | J-DK | DK-a, shape-tools:DS-u | yes | 0 | waiting | – | – |
| DK-m | DesignStroke is VectorStroke; commands; SVG | DK-5, DK-6, DK-7 | MJ-DK | DK-a, shape-tools:DS-m; SS-d (DK-7) | no | 0 | waiting | – | – |
| DK-z | journey on live; built | DK-8, DK-9 | J-DK | DK-u, DK-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DK-1 | DK-a | 1 | adapter and DesignNode.vectorStroke stubs; DesignStrokeTests disabled | Sources/DesignModel/DesignStroke+Kernel.swift, Tests/DesignModelTests/DesignStrokeTests.swift | DesignStrokeTests | #3690 | merged |
| DK-2 | DK-a | 1 | Stroke section is StrokeEditor (no trim) on the stubs; journey skipped | Sources/DesignApp/DesignInspectorStyle.swift, UITests/DesignJourneyTests+Stroke.swift | DesignInspectorSnapshots | #3690 | merged |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.
- 2026-10-21 run act-1a15e909498-4bkk: the brief names lead/stroke-style as the status branch, but that branch is the SuiteUI stroke-style lead's (#3450, pushed 13:03Z). Rebasing or force-pushing it would destroy their record, so this run keeps lead/design-stroke-style, as the earlier Design runs did.
- #3865 (Join/Cap chips act on nothing) became gap p2 after round 2: Design cannot disable those rows until #4014 (StrokeEditor styleHelp, needs-ui) lands; DK-5 also closes it.

## Open

- Run act-1a1605b0534-rn47: the brief's "rebase lead/eyedropper onto origin/main" was not done: lead/eyedropper is the SuiteUI eyedropper lead's branch (#3448); this lead's status stays on lead/design-*.
