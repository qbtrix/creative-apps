# design-stroke-style lead record

Issue: #3441 · Packet: docs/blueprints/design/features/stroke-style.md
Run: act-1a15abb305f-lc8g · Session: claude/design-feature-lead-run-0oib91 · Started: 2026-10-20T19:15:51Z (prior run act-1a159c9b6b4-va3c opened no PR)
Stage: 3 wave 1 (DK-a merged 00:45Z as 3785460f)
Base: a48992b7c85ded3959e12683f50bd5fe7531b011 (origin/dev); main verified at b3011ab9
Next: DK-a round 1: #3882 d482cdd4, #3883 1981f9c1, #3886 6a22d66f merged 08:48Z; #3884 macOS build red (mutating call in #expect), fixed at 65cd7d9c and back in the lane; round 2 (#3865 #3871 #3873) after #3884 merges. DK-u waits shape-tools:DS-u, DK-m waits shape-tools:DS-m (both wait Design transform DT-a/DT-m)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| DK-a | stroke adapter stubs, vectorStroke, Stroke section is StrokeEditor on them | DK-1, DK-2 | MJ-DK | SS-a (done) | yes | 1 | merged (3785460f); round 1: 3 of 4 fixes merged | – | wanted |
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

## Open
- none
