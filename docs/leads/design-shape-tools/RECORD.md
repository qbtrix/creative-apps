# design-shape-tools lead record

Issue: #3440 · Packet: docs/blueprints/design/features/shape-tools.md
Run: act-1a15abb305f-lc8g · Session: claude/design-feature-lead-run-0oib91 · Started: 2026-10-20T19:16:13Z
Stage: 3 wave 1 (DS-a #3857 merged 08:34Z as 24202fb1; DT-a merged 03:57Z as e6430cfa, DY-a merged as 6f9c8928)
Base: a48992b7c85ded3959e12683f50bd5fe7531b011 (origin/dev); main verified at b3011ab9
Next: Belt-Slice-Done DS-a + Mac-Finish-Wanted DS-a after the first dev CI past #3980 (DY-a anchor fix) with a green Linux job; critics on DS-a once a scoped design run at or after 24202fb1 shows screens; DS-u once transform DT-u merges, DS-m once DT-m and DY-m merge (transform lead active, DT-a done 08:47Z)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DS-a | .shape node and tool, ShapeTarget stubs, Shape tool on the palette | DS-1, DS-2 | MJ-DS | transform:DT-a, eyedropper:DY-a; SH-a (done) | yes | 0 | merged (24202fb1) | – | – |
| DS-u | canvas paints the path; snapshots, budget | DS-3, DS-4 | J-DS | DS-a, transform:DT-u; SH-u (done) | yes | 0 | waiting | – | – |
| DS-m | adapter bodies, ShapeRules.dragged; SVG path, catalog, RJ-D35 | DS-5, DS-6 | MJ-DS | DS-a, transform:DT-m, eyedropper:DY-m; SH-m (done) | no | 0 | waiting | – | – |
| DS-z | journey on live; built | DS-7, DS-8 | J-DS | DS-u, DS-m | yes | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| DS-1 | DS-a | – | contract stubs; DesignShapeTests disabled | DesignNode.swift, DesignWorkspace.swift, DesignShape+Kernel.swift, Tests/DesignModelTests/DesignShapeTests.swift | DesignShapeTests | #3857 | merged |
| DS-2 | DS-a | – | Shape tool (U) and options | DesignIntent.swift, DesignShapeOptions.swift, DesignInspector.swift, UITests/DesignJourneyTests+Shapes.swift | DesignToolPaletteSnapshots | #3857 | merged |

## Critic reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Status branch is lead/design-<feature> (record docs/leads/design-<feature>/): lead/<feature> belongs to the SuiteUI lead of the same feature name.
- PRs target dev, not main (CLAUDE.md, lead.md); main b3011ab9 is an ancestor of dev and only fast-forwards to green dev.
- Rule 22: one PR per slice; each slice's PR opens with its failing test commit.
- One lead (this run) holds stroke-style, shape-tools and eyedropper; one wave plan across the three.
- (corrected) Design transform (#3436) is led; DT-a #3751 merged 03:57Z. Earlier note: Design transform (#3436) has no lead running (no lead/design-transform branch, wave.json planned); its DT-a needs gradient-fill:DG-a (building in run act-1a15a9a4e8b-kn6a). shape-tools DS-a and eyedropper DY-m wait on it; this lead does not build another feature's tasks.

## Open
- transform:DT-a/DT-u/DT-m: Design transform #3436 has no running lead; shape-tools cannot start until one builds DT-a.

- 04:35Z DS-a #3857 (220 lines, 15 files): the contract check flagged plan drift, accepted by the lead. Exhaustive-switch `.shape` cases in 7 unplanned files. Options inline in DesignInspector, no DesignShapeOptions.swift (check-dup-views). Shape suite in DesignNodeTests.swift; DS-5 moves it to DesignShapeTests.swift. The journey file is left to DS-7.
